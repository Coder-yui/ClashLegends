"""Small fixtures/mocks only. Never invokes Godot or the full project sources."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import compact_samples
import effect_dependencies
import resource_artifacts as artifacts
import resource_offline_worker as worker
import resource_process as processes


NORMAL = dict(physical_bytes=16 * 1024**3, pressure_level=1, available_percent=53,
              available_estimate_bytes=16 * 1024**3 * 53 // 100)
LOW = dict(NORMAL, available_percent=49, available_estimate_bytes=16 * 1024**3 * 49 // 100)


class ResourceProcessTests(unittest.TestCase):
    def test_atomic_json_and_copy_preserve_old_destination_on_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); target = root / 'existing.json'; target.write_bytes(b'old')
            with self.assertRaises(ValueError): processes.atomic_json(target, {'bad': float('nan')})
            self.assertEqual(target.read_bytes(), b'old')
            with patch.object(processes.os, 'replace', side_effect=OSError('replace failed')):
                with self.assertRaises(OSError): processes.atomic_json(target, {'valid': True})
            self.assertEqual(target.read_bytes(), b'old')
            source = root / 'source'; source.write_bytes(b'new')
            with patch.object(processes.os, 'replace', side_effect=OSError('replace failed')):
                with self.assertRaises(OSError): processes.atomic_copy(source, target)
            self.assertEqual(target.read_bytes(), b'old')
            self.assertEqual(list(root.glob('.*.tmp-*')), [])
            processes.atomic_copy(source, target)
            self.assertEqual(target.read_bytes(), b'new')

    def test_startup_rejection_persists_actual_numbers_before_no_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with patch.object(processes, 'memory_state', return_value=LOW), \
                 patch.object(processes, 'process_rss', return_value=123456), \
                 patch.object(processes, 'run_guarded') as launch:
                with self.assertRaisesRegex(RuntimeError, 'Insufficient'): processes.guarded_process(['not-launched'], folder, phase='offline')
            launch.assert_not_called()
            record = json.loads((folder / 'rejection.json').read_text())
            self.assertEqual(record['observation']['memory'], LOW)
            self.assertEqual(record['observation']['parent_rss_bytes'], 123456)
            self.assertEqual(record['observation']['thresholds']['startup_available_bytes'], 8 * 1024**3)
            self.assertTrue(record['observation']['utc'])
            self.assertFalse(record['child_started'])

    def test_unavailable_observation_is_null_and_error_never_zero_or_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with patch.object(processes, 'memory_state', side_effect=ValueError('unreadable pressure')), \
                 patch.object(processes, 'process_rss', return_value=42), \
                 patch.object(processes, 'run_guarded') as launch:
                with self.assertRaisesRegex(RuntimeError, 'unavailable'): processes.guarded_process(['no'], folder, phase='offline')
            launch.assert_not_called()
            record = json.loads((folder / 'rejection.json').read_text())['observation']
            self.assertIsNone(record['memory'])
            self.assertEqual(record['observation_errors']['memory'], 'unreadable pressure')

    def test_existing_noneditor_and_version_check_fail_before_launch_with_state(self):
        for reason in ['existing', 'version']:
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                preflight = lambda: (_ for _ in ()).throw(ValueError('version actual=A expected=B'))
                rows = '42 /Applications/Godot.app/Contents/MacOS/Godot --path project' if reason == 'existing' else ''
                with patch.object(processes, 'memory_state', return_value=NORMAL), \
                     patch.object(processes, 'process_rss', return_value=123), \
                     patch.object(processes, 'command', return_value=rows), \
                     patch.object(processes, 'run_guarded') as launch:
                    with self.assertRaises((ValueError, RuntimeError)):
                        processes.guarded_process(['no'], folder, phase='godot', preflight=preflight)
                launch.assert_not_called()
                record = json.loads((folder / 'rejection.json').read_text())
                self.assertEqual(record['observation']['memory'], NORMAL)
                self.assertIn('non-editor' if reason == 'existing' else 'actual=A', record['reason'])

    def test_runtime_pressure_rejection_records_triggering_sample(self):
        runtime_low = dict(LOW, available_estimate_bytes=3 * 1024**3)
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            def run(_command, _folder, **kwargs):
                with self.assertRaisesRegex(ValueError, 'headroom'): kwargs['rss_reader'](999)
                self.assertTrue((folder / 'rejection.json').is_file())
                return dict(passed=False, reason='supervisor_error_or_interruption', pid=999, cleanup={'confirmed': True})
            with patch.object(processes, 'memory_state', side_effect=[NORMAL, runtime_low]), \
                 patch.object(processes, 'process_rss', return_value=456), \
                 patch.object(processes, 'group_rss_bytes', return_value=789), \
                 patch.object(processes, 'command', return_value=''), \
                 patch.object(processes, 'run_guarded', side_effect=run):
                with self.assertRaises(RuntimeError): processes.guarded_process(['fixture'], folder, phase='offline')
            record = json.loads((folder / 'rejection.json').read_text())
            self.assertEqual(record['observation']['memory'], runtime_low)
            self.assertEqual(record['observation']['parent_rss_bytes'], 456)
            self.assertEqual(record['rss_observation']['group_rss_bytes'], 789)
            self.assertEqual(record['rss_observation']['system_observation']['memory'], runtime_low)

    def test_rss_or_wall_failure_keeps_last_actual_rss_and_original_limits(self):
        for reason in ['rss_limit', 'total_wall_timeout']:
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                def run(_command, _folder, **kwargs):
                    self.assertEqual(kwargs['limits'].rss_bytes, 1024**3)
                    self.assertEqual(kwargs['limits'].wall_seconds, 20)
                    self.assertEqual(kwargs['limits'].heartbeat_seconds, 2)
                    kwargs['rss_reader'](999)
                    return dict(passed=False, reason=reason, pid=999, cleanup={'confirmed': True})
                with patch.object(processes, 'memory_state', return_value=NORMAL), \
                     patch.object(processes, 'process_rss', return_value=456), \
                     patch.object(processes, 'group_rss_bytes', return_value=1024**3 + 1), \
                     patch.object(processes, 'command', return_value=''), \
                     patch.object(processes, 'run_guarded', side_effect=run):
                    with self.assertRaises(RuntimeError): processes.guarded_process(['fixture'], folder, phase='offline')
                record = json.loads((folder / 'rejection.json').read_text())
                self.assertEqual(record['reason'], reason)
                self.assertEqual(record['rss_observation']['group_rss_bytes'], 1024**3 + 1)
                self.assertEqual(record['last_system_observation']['memory'], NORMAL)

    def test_cleanup_unconfirmed_cannot_be_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with patch.object(processes, 'memory_state', return_value=NORMAL), \
                 patch.object(processes, 'process_rss', return_value=456), \
                 patch.object(processes, 'command', return_value=''), \
                 patch.object(processes, 'run_guarded', return_value=dict(passed=True, pid=123, cleanup={'confirmed': False})):
                with self.assertRaisesRegex(RuntimeError, 'cleanup unconfirmed'):
                    processes.guarded_process(['fixture'], folder, phase='offline')
            self.assertTrue((folder / 'rejection.json').exists())



if __name__ == '__main__': unittest.main()
