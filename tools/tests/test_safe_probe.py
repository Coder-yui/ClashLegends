"""Supervisor failures are exercised with tiny Python processes, never Godot/GPU."""
from pathlib import Path
import fcntl
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'performance'))
import safe_probe as guard

PULSE = '''
import json,os,pathlib,time
path=pathlib.Path(os.environ['CLASH_SAFE_PROBE_HEARTBEAT'])
def pulse(sequence,ready=True):
    tmp=path.with_suffix('.tmp')
    tmp.write_text(json.dumps(dict(token=os.environ['CLASH_SAFE_PROBE_TOKEN'],pid=os.getpid(),sequence=sequence,ready=ready)))
    tmp.replace(path)
'''


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.limits = guard.Limits(wall_seconds=1.2, startup_grace_seconds=.3,
                                  heartbeat_seconds=.16, poll_seconds=.02,
                                  terminate_grace_seconds=.08)

    def tearDown(self):
        self.temp.cleanup()

    def run_child(self, body, **kwargs):
        return guard.run_guarded([sys.executable, '-c', PULSE + body], self.base / 'output',
                                 limits=kwargs.pop('limits', self.limits),
                                 lock_path=self.base / 'lock', **kwargs)

    def assert_clean(self, result):
        self.assertTrue(result['cleanup']['confirmed'], result)
        self.assertEqual(guard.live_group_members(result['pgid']), [])

    def test_healthy_heartbeat_and_whole_group_cleanup(self):
        result = self.run_child('\nfor i in range(8): pulse(i); time.sleep(.04)\n')
        self.assertTrue(result['passed'], result)
        self.assertTrue(result['ready_seen'])
        self.assert_clean(result)

    def test_monitor_unavailable_prevents_process_creation(self):
        def unavailable(_): raise PermissionError('no process visibility')
        with patch.object(guard.subprocess, 'Popen') as spawn:
            result = self.run_child('pulse(1)', rss_reader=unavailable)
        spawn.assert_not_called()
        self.assertEqual(result['reason'], 'rss_monitor_unavailable_before_launch')
        self.assertIsNone(result['pid'])
        self.assertFalse(result['passed'])
        self.assertTrue((self.base / 'output/watchdog.json').is_file())

    def test_cleanup_monitor_unavailable_prevents_process_creation(self):
        with patch.object(guard, 'live_group_members', side_effect=PermissionError('no group visibility')), patch.object(guard.subprocess, 'Popen') as spawn:
            result = self.run_child('pulse(1)', rss_reader=lambda _: 0)
        spawn.assert_not_called()
        self.assertIsNone(result['pid'])

    def test_monitor_loss_after_launch_stops_child(self):
        calls = 0
        def reader(_):
            nonlocal calls
            calls += 1
            if calls > 2: raise PermissionError('process visibility lost')
            return 100 * guard.MIB
        result = self.run_child('pulse(1); time.sleep(10)', rss_reader=reader)
        self.assertEqual(result['reason'], 'rss_monitor_unavailable', result)
        self.assert_clean(result)

    def test_cleanup_visibility_loss_cannot_report_confirmed(self):
        original = guard.live_group_members
        calls = 0
        def members(pgid):
            nonlocal calls
            calls += 1
            if calls > 1: raise PermissionError('cleanup visibility lost')
            return original(pgid)
        with patch.object(guard, 'live_group_members', side_effect=members):
            result = self.run_child('pulse(1); time.sleep(.12)')
        self.assertFalse(result['passed'], result)
        self.assertFalse(result['cleanup']['confirmed'])
        self.assertEqual(original(result['pgid']), [])

    def test_concurrent_lock_prevents_process_creation(self):
        with (self.base / 'lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with patch.object(guard.subprocess, 'Popen') as spawn:
                result = self.run_child('pulse(1)')
        spawn.assert_not_called()
        self.assertEqual(result['reason'], 'another_safe_probe_is_running')

    def test_frozen_heartbeat_forces_termination(self):
        result = self.run_child('pulse(1)\ntime.sleep(10)')
        self.assertEqual(result['reason'], 'main_thread_heartbeat_timeout', result)
        self.assertFalse(result['passed'])
        self.assert_clean(result)

    def test_missing_heartbeat_has_bounded_startup_grace(self):
        result = self.run_child('time.sleep(10)')
        self.assertEqual(result['reason'], 'startup_heartbeat_timeout', result)
        self.assert_clean(result)

    def test_healthy_heartbeat_cannot_extend_total_budget(self):
        limits = guard.Limits(wall_seconds=.45, startup_grace_seconds=.2,
                             heartbeat_seconds=.16, poll_seconds=.02,
                             terminate_grace_seconds=.08)
        result = self.run_child('\nfor i in range(100): pulse(i); time.sleep(.025)\n', limits=limits)
        self.assertEqual(result['reason'], 'total_wall_timeout', result)
        self.assert_clean(result)

    def test_absolute_rss_limit(self):
        result = self.run_child('\nfor i in range(100): pulse(i); time.sleep(.02)\n', rss_reader=lambda _: 1025 * guard.MIB)
        self.assertEqual(result['reason'], 'rss_limit', result)
        self.assert_clean(result)

    def test_growth_after_stable_ready_baseline(self):
        values = iter([100 * guard.MIB] * 8 + [400 * guard.MIB] * 100)
        result = self.run_child('\nfor i in range(100): pulse(i); time.sleep(.02)\n', rss_reader=lambda _: next(values))
        self.assertEqual(result['reason'], 'rss_limit', result)
        self.assertEqual(result['stable_ready_rss_bytes'], 100 * guard.MIB)
        self.assertEqual(result['active_rss_cap_bytes'], 356 * guard.MIB)
        self.assert_clean(result)

    def test_term_ignoring_leader_and_child_are_killed(self):
        body = '''
import signal
signal.signal(signal.SIGTERM,signal.SIG_IGN)
child=os.fork()
if child==0:
    time.sleep(10)
    os._exit(0)
pulse(1)
time.sleep(10)
'''
        result = self.run_child(body)
        self.assertEqual(result['reason'], 'main_thread_heartbeat_timeout', result)
        self.assertIn('KILL', result['cleanup']['signals'])
        self.assertEqual(result['exit_code'], -9)
        self.assert_clean(result)

    def test_exited_leader_does_not_hide_surviving_child(self):
        body = '''
import signal
child=os.fork()
if child==0:
    signal.signal(signal.SIGTERM,signal.SIG_IGN)
    time.sleep(10)
    os._exit(0)
for i in range(4): pulse(i); time.sleep(.04)
'''
        result = self.run_child(body)
        self.assertTrue(result['passed'], result)
        self.assertIn('KILL', result['cleanup']['signals'])
        self.assert_clean(result)

    def test_headless_opt_out_is_explicit_and_has_limited_scope(self):
        with self.assertRaises(ValueError):
            self.run_child('pass', require_heartbeat=False)
        result = guard.run_guarded([sys.executable, '-c', 'import time; time.sleep(.15)', '--headless'],
                                   self.base / 'headless', limits=self.limits,
                                   lock_path=self.base / 'lock', require_heartbeat=False)
        self.assertTrue(result['passed'], result)
        self.assertIn('no responsiveness guarantee', result['scope'])
        self.assertNotIn('stable_ready_rss_bytes', result)
        self.assertEqual(result['active_rss_cap_bytes'], 1024 * guard.MIB)
        self.assert_clean(result)

    def test_headless_no_ready_uses_absolute_cap_during_loading(self):
        values = iter([50 * guard.MIB] * 5 + [500 * guard.MIB] * 100)
        result = guard.run_guarded([sys.executable, '-c', 'import time; time.sleep(.25)', '--headless'],
                                   self.base / 'headless', limits=self.limits,
                                   lock_path=self.base / 'lock', require_heartbeat=False,
                                   rss_reader=lambda _: next(values))
        self.assertTrue(result['passed'], result)
        self.assertNotIn('stable_ready_rss_bytes', result)
        self.assertEqual(result['active_rss_cap_bytes'], 1024 * guard.MIB)
        self.assert_clean(result)

    def test_budgets_cannot_be_enlarged(self):
        for argument in [dict(wall_seconds=21), dict(heartbeat_seconds=3),
                         dict(rss_bytes=1025*guard.MIB), dict(startup_grace_seconds=7)]:
            with self.assertRaises(ValueError): guard.Limits(**argument)

    def test_fps_enforcement_independent_of_binary_name(self):
        self.assertEqual(guard._guarded_command(['custom-engine', '--script', 'a.gd', '--', '--x=1']),
                         ['custom-engine', '--script', 'a.gd', '--max-fps', '30', '--', '--x=1'])
        for options in [['--max-fps','60'], ['--max-fps'], ['--max-fps=60'],
                        ['--max-fps','30','--max-fps','30']]:
            with self.assertRaises(ValueError): guard._guarded_command(['custom', '--script', 'x', *options, '--'])

    def test_explicit_match_frame_cap_keeps_default_policy(self):
        argv = ['custom', '--script', 'x', '--']
        self.assertIn('60', guard._guarded_command(argv, 60))
        for cap in (0, 31, 120):
            with self.assertRaises(ValueError): guard._guarded_command(argv, cap)
        with self.assertRaises(ValueError):
            guard._guarded_command(['custom', '--script', 'x', '--max-fps', '30'], 60)

    def test_old_large_cli_workload_rejected_without_engine(self):
        result = subprocess.run([sys.executable, str(Path(guard.__file__)), '--total', '160'],
                                capture_output=True, text=True, timeout=2)
        self.assertEqual(result.returncode, 2)
        self.assertIn('invalid choice', result.stderr)


if __name__ == '__main__':
    unittest.main()
