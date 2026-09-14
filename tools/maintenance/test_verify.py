"""Failure-path fixtures: even an engine exit of zero must not hide broken suites."""
import importlib.util
import json
from pathlib import Path
import unittest
import sys
import tempfile
import subprocess

spec = importlib.util.spec_from_file_location('verify', Path(__file__).resolve().parents[1] / 'verify.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerifyTests(unittest.TestCase):
    def log(self, **updates):
        result = dict(schema=1, checks=12, failed=0, completed_suites=['a', 'b'])
        result.update(updates)
        return '[机制检查] 全部通过（12 项断言）\n' + verify.RESULT_PREFIX + json.dumps(result)

    def test_selected_catalog_and_unknown_suite(self):
        catalog = json.dumps([{'id': 'a'}, {'id': 'b'}, {'id': 'c'}])
        self.assertEqual(verify.expected_suites(catalog), ['a', 'b', 'c'])
        self.assertEqual(verify.expected_suites(catalog, ['c', 'a']), ['a', 'c'])
        with self.assertRaises(ValueError):
            verify.expected_suites(catalog, ['typo'])
        with self.assertRaises(ValueError):
            verify.expected_suites('[{"id":"a"},{"id":"a"}]')

    def test_selected_result_cannot_hide_missing_or_extra_suites(self):
        self.assertEqual(verify.validate_mechanics(self.log(completed_suites=['b']), ['b'])[1], [])
        self.assertTrue(verify.validate_mechanics(self.log(completed_suites=['a']), ['b'])[1])
        self.assertTrue(verify.validate_mechanics(self.log(), ['b'])[1])

    def test_complete(self):
        self.assertEqual(verify.validate_mechanics(self.log(), ['a', 'b'])[1], [])

    def test_silent_runtime_error(self):
        self.assertTrue(verify.validate_mechanics('SCRIPT ERROR: invalid call\n' + self.log(), ['a', 'b'])[1])

    def test_incomplete_or_duplicate_suite(self):
        for completed in [['a'], ['a', 'a', 'b'], None, [None]]:
            self.assertTrue(verify.validate_mechanics(self.log(completed_suites=completed), ['a', 'b'])[1])

    def test_invalid_or_missing_summary(self):
        for log in ['', self.log() + '\n' + self.log(), verify.RESULT_PREFIX + '{}', verify.RESULT_PREFIX + 'null']:
            self.assertTrue(verify.validate_mechanics(log, ['a', 'b'])[1])

    def test_exit_zero_with_script_error_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            result = verify.run_step('fixture', [sys.executable, '-c',
                                     'print("SCRIPT ERROR: injected")'], Path(folder), 5)
        self.assertEqual(result['exit_code'], 0)
        self.assertFalse(result['passed'])

    def test_process_timeout_fails_and_cleans_up(self):
        with tempfile.TemporaryDirectory() as folder:
            result = verify.run_step('timeout', [sys.executable, '-c',
                                     'import time; time.sleep(30)'], Path(folder), 0.05)
        self.assertFalse(result['passed'])
        self.assertLess(result['seconds'], 6)

    def test_identity_tracks_uncommitted_and_untracked_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(['git', 'init', '-q', folder], check=True)
            subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                            'commit', '--allow-empty', '-qm', 'baseline'], cwd=root, check=True)
            before = verify.identity(root)
            (root / 'new.txt').write_text('one')
            first = verify.identity(root)
            (root / 'new.txt').write_text('two')
            second = verify.identity(root)
        self.assertFalse(before['dirty'])
        self.assertTrue(first['dirty'])
        self.assertNotEqual(first['content_sha256'], second['content_sha256'])
        self.assertEqual(before['commit'], second['commit'])

    def test_nonzero_exit_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            result = verify.run_step('fixture', [sys.executable, '-c', 'raise SystemExit(3)'], Path(folder), 5)
        self.assertFalse(result['passed'])
        self.assertEqual(result['exit_code'], 3)

    def test_assertion_failures(self):
        self.assertTrue(verify.validate_mechanics(self.log(failed=1), ['a', 'b'])[1])
        self.assertTrue(verify.validate_mechanics(self.log(checks=0), ['a', 'b'])[1])

    def network_logs(self, **client_updates):
        state = dict(schema=1, passed=True, session_id='fixture', final_tick=65,
                     winner_team=0, reason='nexus', tower_hp=[3600, 0],
                     units=[[1, 'gnar', 100, 50, 60]], audio_stopped=True, remote_elixir=1, tower_shields=[[1, 0.1], [0, 0]])
        return {role: '[NETWORK_RESULT] ' + json.dumps(dict(
            state, role=role, **(client_updates if role == 'client' else {})))
                for role in ['host', 'client']}

    def test_network_complete(self):
        self.assertEqual(verify.validate_network(self.network_logs())[1], [])

    def test_network_mismatched_terminal_state(self):
        for field, value in [('final_tick', 64), ('session_id', 'old'),
                             ('tower_hp', [3600, 10]), ('units', [])]:
            self.assertTrue(verify.validate_network(self.network_logs(**{field: value}))[1])

    def test_network_missing_duplicate_or_failed_result(self):
        for value in ['', '[NETWORK_RESULT] null', '[NETWORK_RESULT] {}']:
            logs = self.network_logs()
            logs['client'] = value
            self.assertTrue(verify.validate_network(logs)[1])
        logs = self.network_logs()
        logs['client'] += '\n' + logs['client']
        self.assertTrue(verify.validate_network(logs)[1])
        self.assertTrue(verify.validate_network(self.network_logs(passed=False))[1])
        self.assertTrue(verify.validate_network(self.network_logs(audio_stopped=False))[1])

    def test_network_runtime_error_despite_success(self):
        logs = self.network_logs()
        logs['client'] += '\nSCRIPT ERROR: injected'
        self.assertTrue(verify.validate_network(logs)[1])

    def test_network_boundary_results(self):
        logs = {role: '[NETWORK_BOUNDARY_RESULT] ' + json.dumps(dict(
            schema=1, role=role, passed=True, case='slow', session_id='epoch'))
                for role in ['host', 'client']}
        self.assertEqual(verify.validate_network_boundary(logs, 'slow')[1], [])
        self.assertTrue(verify.validate_network_boundary(logs, 'disconnect')[1])
        for broken in ['', logs['client'] + '\n' + logs['client'],
                       logs['client'].replace('epoch', 'other'),
                       logs['client'].replace('true', 'false'),
                       logs['client'] + '\nSCRIPT ERROR: injected']:
            self.assertTrue(verify.validate_network_boundary(dict(logs, client=broken), 'slow')[1])


if __name__ == '__main__':
    unittest.main()
