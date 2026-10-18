"""Only tiny owned Python processes; no game, models, or GPU."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verification_guard as guard
from performance import safe_probe


class VerificationGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.output = Path(self.temp.name) / 'run'
        self.state = dict(physical_bytes=16 * guard.GIB, pressure_level=1,
                          available_estimate_bytes=9 * guard.GIB, available_percent=56)

    def tearDown(self):
        self.temp.cleanup()

    def run_child(self, body='import time; time.sleep(.15)', **kwargs):
        return guard.run_engine([sys.executable, '-c', body, '--headless'], self.output, 2,
                                profile=guard.PROFILE, heartbeat=False, state_reader=kwargs.pop('state_reader', lambda: self.state),
                                process_reader=lambda *args: '', **kwargs)

    def test_normal_exit_uses_machine_budget_and_confirms_cleanup(self):
        result = self.run_child()
        self.assertTrue(result['passed'], result)
        self.assertEqual(result['limits']['rss_bytes'], 768 * guard.MIB)
        self.assertTrue(result['cleanup']['confirmed'])

    def test_failed_memory_monitor_prevents_launch(self):
        with patch.object(safe_probe.subprocess, 'Popen') as spawn:
            result = self.run_child(state_reader=lambda: (_ for _ in ()).throw(PermissionError('blocked')))
        spawn.assert_not_called()
        self.assertEqual(result['reason'], 'verification_preflight_failed')

    def test_low_headroom_prevents_launch(self):
        self.state['available_estimate_bytes'] = 2 * guard.GIB
        with patch.object(safe_probe.subprocess, 'Popen') as spawn:
            result = self.run_child()
        spawn.assert_not_called()
        self.assertFalse(result['passed'])

    def test_rss_over_budget_stops_owned_process(self):
        result = self.run_child('import time; time.sleep(10)', rss_reader=lambda _: 4 * guard.GIB)
        self.assertEqual(result['reason'], 'rss_limit', result)
        self.assertTrue(result['cleanup']['confirmed'])

    def test_pressure_change_after_launch_stops_group(self):
        states = iter([self.state, self.state, dict(self.state, pressure_level=2)])
        result = self.run_child('import time; time.sleep(10)', state_reader=lambda: next(states))
        self.assertEqual(result['reason'], 'rss_monitor_unavailable', result)
        self.assertIn('pressure', result['monitor_error'])
        self.assertTrue(result['cleanup']['confirmed'])

    def test_light_policy_accepts_eight_gib_machine(self):
        state = dict(self.state, physical_bytes=8 * guard.GIB, available_estimate_bytes=3 * guard.GIB)
        self.assertEqual(guard.logic_budget(state), 768 * guard.MIB)
        state['available_estimate_bytes'] = int(2.5 * guard.GIB)
        self.assertEqual(guard.logic_budget(state), 512 * guard.MIB)

    def test_profile_and_timeout_are_explicit(self):
        self.assertEqual(guard.policy(guard.PROFILE, .2)['wall_seconds'], .2)
        for profile, timeout in [('loading', 20), (guard.PROFILE, 60), (guard.PROFILE, 0)]:
            with self.assertRaises(ValueError): guard.policy(profile, timeout)
        self.assertEqual(guard.LogicLimits(.2, 512 * guard.MIB).rss_growth_bytes, 512 * guard.MIB)

    def test_unsupported_platform_rejects_before_monitor_or_child(self):
        with patch.object(safe_probe.subprocess, 'Popen') as spawn:
            result = guard.run_engine([sys.executable, '--headless'], self.output, 2,
                profile=guard.PROFILE, heartbeat=False, platform_name='linux',
                state_reader=lambda: self.fail('must not sample on unsupported platform'))
        spawn.assert_not_called()
        self.assertIsNone(result['pid'])
        self.assertIn('macOS only', result['error'])

    def test_short_supervised_timeout_is_not_silently_enlarged(self):
        result = guard.run_engine([sys.executable, '-c', 'import time; time.sleep(10)', '--headless'],
            self.output, .15, profile=guard.PROFILE, heartbeat=False,
            state_reader=lambda: self.state, process_reader=lambda *args: '')
        self.assertEqual(result['reason'], 'total_wall_timeout', result)
        self.assertEqual(result['limits']['wall_seconds'], .15)
        self.assertTrue(result['cleanup']['confirmed'])

    def test_memory_commands_share_one_short_deadline(self):
        now = [0.0]
        remaining = []
        replies = iter([str(8 * guard.GIB), '1', 'free percentage: 50%'])
        def slow(*args, timeout):
            remaining.append(timeout)
            now[0] += .09
            return next(replies)
        with self.assertRaisesRegex(ValueError, 'common deadline'):
            guard.sample_memory(read=slow, clock=lambda: now[0])
        self.assertEqual(len(remaining), 3)
        self.assertGreater(remaining[0], remaining[1])
        self.assertLess(remaining[2], .03)

    def test_actual_slow_query_times_out_before_engine_launch(self):
        import subprocess
        def slow(*args, timeout):
            return subprocess.run([sys.executable, '-c', 'import time; time.sleep(10)'],
                                  capture_output=True, text=True, timeout=timeout).stdout
        result = self.run_child(state_reader=lambda: guard.sample_memory(read=slow))
        self.assertIsNone(result['pid'])
        self.assertEqual(result['reason'], 'verification_preflight_failed')
        self.assertIn('timed out', result['error'])

    def test_selected_and_lowercase_engine_identity(self):
        rows = '12 /tmp/custom-engine --path game\n13 /opt/homebrew/bin/godot --editor\n14 /Applications/Godot.app/Contents/MacOS/Godot --path game\n15 /tmp/helper --name godot\n'
        engines = guard.existing_engines(rows, '/tmp/custom-engine')
        self.assertEqual([e['pid'] for e in engines], [12, 13, 14])
        self.assertEqual([e['editor'] for e in engines], [False, True, False])
        quoted = guard.existing_engines('16 "/tmp/Custom Engine" --editor', '/tmp/Custom Engine')
        self.assertTrue(quoted[0]['editor'])
        game = guard.existing_engines('17 /tmp/custom-engine -- --editor', '/tmp/custom-engine')
        self.assertFalse(game[0]['editor'])

    def test_other_running_selected_engine_refuses_new_launch(self):
        with patch.object(safe_probe.subprocess, 'Popen') as spawn:
            result = guard.run_engine(['/tmp/engine'], self.output, 2, profile=guard.PROFILE,
                heartbeat=False, state_reader=lambda: self.state,
                process_reader=lambda *args: '32 /tmp/engine --path game')
        spawn.assert_not_called()
        self.assertIsNone(result['pid'])
        self.assertIn('non-editor', result['error'])

    def test_grandchild_cleaned_after_leader_exits(self):
        body = '''import os,signal,time
child=os.fork()
if child==0:
    signal.signal(signal.SIGTERM,signal.SIG_IGN)
    time.sleep(10)
    os._exit(0)
time.sleep(.15)
'''
        result = self.run_child(body)
        self.assertTrue(result['passed'], result)
        self.assertIn('KILL', result['cleanup']['signals'])
        self.assertTrue(result['cleanup']['confirmed'])


if __name__ == '__main__':
    unittest.main()
