"""Failure-path fixtures: even an engine exit of zero must not hide broken suites."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import unittest
import sys
import tempfile
import subprocess
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('verify', Path(__file__).resolve().parents[1] / 'verify.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerifyTests(unittest.TestCase):
    def test_plan_reports_explicit_load_and_timeout_policy(self):
        for extra, expected in [([], 600), (['--guard-profile', 'authority-logic'], 20)]:
            output = io.StringIO()
            with patch.object(sys, 'argv', ['verify', '--plan', '--suite', 'GrowthSpatialSuite', *extra]), contextlib.redirect_stdout(output):
                self.assertEqual(verify.main(), 0)
            supervision = json.loads(output.getvalue())['supervision']
            self.assertEqual(supervision.get('wall_seconds', supervision.get('wall_seconds_per_step')), expected)

    def test_lightweight_boundary_scope_is_explicit_and_keeps_heavy_suites_out(self):
        for selected in ['LightweightContractSuite', 'StartupNetworkBoundary', 'WorldOwnershipSuite', 'RuntimeOwnershipSuite', 'UnitMutationSuite', 'StrictContractSuite']:
            output = io.StringIO()
            with patch.object(sys, 'argv', ['verify', '--plan', '--guard-profile', 'authority-logic',
                                           '--suite', selected]), contextlib.redirect_stdout(output):
                self.assertEqual(verify.main(), 0)
            plan = json.loads(output.getvalue())
            self.assertEqual(plan['suites'], [selected])
            self.assertFalse(plan['requires_import'])
            self.assertFalse(plan['card_facts'])
        for heavy in ['PresentationSuite', 'AUDIO_PRESENTATION_SUITE_SCRIPT', 'CardDBValidationSuite']:
            with patch.object(sys, 'argv', ['verify', '--plan', '--guard-profile', 'authority-logic',
                                           '--suite', heavy]), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit): verify.main()

    def test_protected_cli_rejects_scope_timeout_and_unsupported_platform(self):
        cases = [(['--suite', 'JinxSuite'], 'darwin'),
                 (['--suite', 'GrowthSpatialSuite', '--timeout', '60'], 'darwin'),
                 (['--suite', 'GrowthSpatialSuite'], 'linux')]
        for options, platform in cases:
            with patch.object(sys, 'argv', ['verify', '--guard-profile', 'authority-logic', *options]), patch.object(sys, 'platform', platform), patch.object(verify, 'find_godot') as find, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error: verify.main()
                self.assertEqual(error.exception.code, 2)
                find.assert_not_called()

    def test_explicit_engine_step_fails_closed_through_supervisor(self):
        for name in ['mechanics']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                with patch.object(verify, 'run_engine', return_value=dict(passed=False, reason='monitor_unavailable')) as guard, patch.object(verify.subprocess, 'Popen') as spawn:
                    result = verify.run_step(name, ['fake-engine', '--headless'], Path(folder), 20, ['GrowthSpatialSuite'], guard_profile='authority-logic')
                guard.assert_called_once()
                spawn.assert_not_called()
                self.assertFalse(result['passed'])
                self.assertIn('Supervisor: monitor_unavailable', result['errors'])

    def test_protected_import_is_refused_without_legacy_fallback(self):
        for name in ['import', 'card-facts-export']:
            with tempfile.TemporaryDirectory() as folder, patch.object(verify.subprocess, 'Popen') as spawn:
                with self.assertRaises(ValueError):
                    verify.run_step(name, ['fake-engine'], Path(folder), 20, guard_profile='authority-logic')
                spawn.assert_not_called()

    def test_ordinary_mechanics_keeps_explicit_timeout_without_mac_monitor(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(verify, 'run_engine') as guard:
            result = verify.run_step('import', [sys.executable, '-c', 'print("tiny fixture")'], Path(folder), 0.75)
        self.assertTrue(result['passed'])
        guard.assert_not_called()

    def test_default_verification_runs_safe_tools_gate_and_stops_on_failure(self):
        for tool_passed in [True, False]:
            with self.subTest(tool_passed=tool_passed), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / 'tests').mkdir()
                (root / 'tests/suite_catalog.json').write_text('[{"id":"a","group":"contracts"}]')
                (root / 'godot-version.txt').write_text('fixture-engine')
                (root / 'tools/maintenance').mkdir(parents=True)
                (root / 'tools/tests').mkdir()
                (root / 'tools/maintenance/test_fixture.py').touch()
                (root / 'tools/tests/test_fixture.py').touch()
                commands = []
                def step(name, command, *_args):
                    commands.append((name, command))
                    return {'passed': name != 'tool-tests' or tool_passed}
                with patch.object(verify, 'ROOT', root), \
                     patch.object(verify, 'identity', return_value={'content_sha256': 'fixed'}), \
                     patch.object(verify.subprocess, 'check_output', return_value='fixture-engine'), \
                     patch.object(verify, 'run_step', side_effect=step), \
                     patch.object(sys, 'argv', ['verify', '--full', '--changed', 'README.md', '--godot', 'fixture', '--output', str(root / 'output')]):
                    self.assertEqual(verify.main(), 0 if tool_passed else 1)
                names = [name for name, _ in commands]
                self.assertEqual(names[:3], ['audit', 'verifier-tests', 'tool-tests'])
                self.assertEqual(commands[2][1][1:], ['-m', 'unittest', 'discover', '-s', 'tools/tests', '-p', 'test_*.py'])
                self.assertEqual('import' in names, tool_passed)

    def test_stale_effect_dependencies_stop_before_engine_import(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            (root / 'tests/suite_catalog.json').write_text('[{"id":"a","group":"contracts"}]')
            (root / 'godot-version.txt').write_text('fixture-engine')
            names = []
            commands = {}
            def step(name, command, *_args):
                names.append(name)
                commands[name] = command
                return {'passed': name != 'effect-dependencies'}
            with patch.object(verify, 'ROOT', root), \
                 patch.object(verify, 'identity', return_value={'content_sha256': 'fixed'}), \
                 patch.object(verify.subprocess, 'check_output', return_value='fixture-engine'), \
                 patch.object(verify, 'run_step', side_effect=step), \
                 patch.object(sys, 'argv', ['verify', '--full', '--changed', 'README.md', '--godot', 'fixture', '--output', str(root / 'output')]):
                self.assertEqual(verify.main(), 1)
            self.assertIn('effect-dependencies', names)
            self.assertEqual(commands['effect-dependencies'][1:],
                             ['tools/maintenance/effect_dependencies.py', '--check'])
            self.assertNotIn('import', names)

    def real_plan(self, *paths, **options):
        return verify.verification_plan(verify.ROOT, (verify.ROOT / 'tests/suite_catalog.json').read_text(), list(paths), **options)

    def test_docs_and_clean_plans_have_no_engine_or_python_test_gate(self):
        for paths in [(), ('README.md', 'docs/reference/NETWORK_PROTOCOL.md', 'docs/navigation.json')]:
            plan = self.real_plan(*paths)
            self.assertFalse(plan['blocked'])
            self.assertEqual(plan['suites'], [])
            self.assertEqual(plan['python_tests'], [])
            self.assertEqual([x[0] for x in verify.planned_commands(plan, None, Path('unused'))], ['audit', 'diff-check'])

    def test_protocol_expands_consumers_but_does_not_select_all_cards(self):
        plan = self.real_plan('scripts/battle/network_snapshot_system.gd')
        self.assertFalse(plan['blocked'])
        self.assertIn('network_lifecycle_suite', plan['suites'])
        self.assertIn('terminal_state_suite', plan['suites'])
        self.assertIn('ProjectileSuite', plan['suites'])
        self.assertIn('TerminalAudioSuite', plan['suites'])
        self.assertLess(plan['suite_count'], plan['catalog_suite_count'])
        self.assertNotIn('SionSuite', plan['suites'])
        self.assertEqual(plan['python_tests'], [])

    def test_projectile_view_child_routes_to_existing_owner_suite(self):
        plan = self.real_plan('tests/fixtures/projectile_view_checks.gd')
        self.assertEqual(plan['suites'], ['ProjectileSuite'])
        self.assertNotIn('ProjectileViewSuite', plan['suites'])
        combined = self.real_plan('tests/suites/combat/projectile_suite.gd',
                                  'tests/fixtures/projectile_view_checks.gd',
                                  'tests/fixtures/projectile_view_checks.gd.uid')
        self.assertEqual(combined['suites'], ['ProjectileSuite'])
        self.assertEqual(combined['unknown_paths'], [])
        self.assertFalse(combined['blocked'])
        for consumer in ['jinx_projectile_effect', 'corki_projectile_effect', 'anivia_effect_3d',
                         'gwen_tristana_effect_3d', 'voidfish_effect_3d', 'kayle_projectile_visuals']:
            with self.subTest(consumer=consumer):
                self.assertIn('ProjectileSuite', self.real_plan('scripts/presentation/' + consumer + '.gd')['suites'])

    def test_ui_local_selects_direct_session_consumer(self):
        plan = self.real_plan('scripts/ui/deck_builder.gd')
        self.assertIn('DeckBuilderSuite', plan['suites'])
        self.assertIn('session_suite', plan['suites'])
        self.assertNotIn('ProjectileSuite', plan['suites'])
        self.assertFalse(plan['blocked'])

    def test_timing_and_lifecycle_expand_domains(self):
        for path in ['scripts/battle/match_runtime.gd', 'scripts/battle/fixed_step_clock.gd', 'scripts/main.gd']:
            plan = self.real_plan(path)
            for suite in ['network_lifecycle_suite', 'numeric_system_suite', 'ArenaDeploymentSuite', 'StatusBoundarySuite']:
                self.assertIn(suite, plan['suites'])
            self.assertLess(plan['suite_count'], plan['catalog_suite_count'])

    def test_unknown_or_wide_automatic_plan_requires_explicit_scope(self):
        unknown = self.real_plan('unexpected/runtime.py')
        self.assertEqual(unknown['unknown_paths'], ['unexpected/runtime.py'])
        self.assertTrue(unknown['requires_explicit_scope'])
        mixed = self.real_plan('README.md', 'unexpected/runtime.py')
        self.assertTrue(mixed['blocked'])
        wide = self.real_plan('scripts/main.gd', 'scripts/unit.gd')
        self.assertTrue(wide['requires_explicit_scope'])
        explicit = self.real_plan('unexpected/runtime.py', suites=['ProjectileSuite'])
        self.assertFalse(explicit['blocked'])
        self.assertEqual(explicit['suites'], ['ProjectileSuite'])
        self.assertEqual(explicit['unknown_paths'], ['unexpected/runtime.py'])

    def test_full_reads_single_catalog_and_keeps_network_explicit(self):
        plan = self.real_plan(full=True)
        self.assertEqual(plan['suites'], verify.expected_suites((verify.ROOT / 'tests/suite_catalog.json').read_text()))
        names = [x[0] for x in verify.planned_commands(plan, 'fixture', Path('unused'))]
        self.assertNotIn('network', names)
        self.assertTrue(plan['effect_dependencies'])
        self.assertTrue(plan['card_facts'])
        self.assertIn('tools/tests/test_safe_probe.py', plan['python_tests'])
        command = next(command for name, command in verify.planned_commands(plan, 'fixture', Path('unused')) if name == 'mechanics')
        self.assertEqual(sum(arg.startswith('--suite=') for arg in command), plan['catalog_suite_count'])

    def test_cached_script_scope_skips_import_but_resource_or_full_requires_it(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / '.godot').mkdir()
            (root / '.godot/global_script_class_cache.cfg').write_text('class CachedProbe')
            source = json.dumps([{'id': 'ProjectileSuite', 'script': 'res://tests/suites/combat/projectile_suite.gd', 'group': 'combat'}])
            plan = verify.verification_plan(root, source, [], suites=['ProjectileSuite'])
            self.assertNotIn('import', [name for name, _ in verify.planned_commands(plan, 'fixture', Path('unused'))])
            (root / 'scripts/battle').mkdir(parents=True)
            (root / 'scripts/battle/new_probe.gd').write_text('class_name NewProbe')
            new_class = verify.verification_plan(root, source, ['scripts/battle/new_probe.gd'])
            self.assertTrue(new_class['requires_import'])
            resource = verify.verification_plan(root, source, ['assets/texture.png'], suites=['ProjectileSuite'])
            self.assertIn('import', [name for name, _ in verify.planned_commands(resource, 'fixture', Path('unused'))])
            full = verify.verification_plan(root, source, [], full=True)
            self.assertTrue(full['requires_import'])

    def test_tools_gate_selects_modules_and_never_import_recipes(self):
        plan = self.real_plan('tools/performance/safe_probe.py')
        self.assertEqual(plan['python_tests'], ['tools/tests/test_safe_probe.py'])
        self.assertEqual(plan['suites'], [])
        own = self.real_plan('tools/maintenance/test_verify.py')
        self.assertEqual(own['python_tests'], ['tools/maintenance/test_verify.py'])
        effect = self.real_plan('tools/maintenance/effect_dependencies.py')
        self.assertEqual(effect['python_tests'], ['tools/maintenance/test_effect_dependencies.py'])
        commands = verify.planned_commands(effect, None, Path('unused'))
        self.assertIn(('effect-dependencies', [sys.executable, 'tools/maintenance/effect_dependencies.py', '--check']), commands)
        self.assertFalse(any('--write' in command or 'audio-import' in command for _, command in commands))
        self.assertNotIn('import', [name for name, _ in commands])

    def test_selected_maintenance_files_run_in_real_subprocess_import_context(self):
        # Exercise real sibling imports, not a mocked run_step or this test's
        # already populated sys.path. Never recurse into test_verify/full gates.
        for filename in ['test_audit_project.py', 'test_effect_dependencies.py', 'test_card_facts.py']:
            with self.subTest(filename=filename):
                plan = self.real_plan()
                plan['python_tests'] = ['tools/maintenance/' + filename]
                commands = verify.planned_commands(plan, None, Path('unused'))
                selected = [(name, command) for name, command in commands if name.startswith('verifier-tests')]
                self.assertEqual(len(selected), 1)
                command = selected[0][1]
                self.assertEqual(command[1:], ['-m', 'unittest', 'discover', '-s', 'tools/maintenance', '-p', filename])
                result = subprocess.run(command, cwd=verify.ROOT, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('Ran ', result.stderr)
                self.assertIn('\nOK', result.stderr)

    def test_git_changed_includes_index_worktree_deleted_and_untracked(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(['git', 'init', '-q', folder], check=True)
            for name in ['staged.py', 'worktree.py', 'rename.py']:
                (root / name).write_text('before')
            subprocess.run(['git', 'add', '.'], cwd=root, check=True)
            subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'baseline'], cwd=root, check=True)
            (root / 'staged.py').write_text('after')
            subprocess.run(['git', 'add', 'staged.py'], cwd=root, check=True)
            (root / 'worktree.py').write_text('after')
            subprocess.run(['git', 'mv', 'rename.py', 'renamed.py'], cwd=root, check=True)
            (root / 'new.py').write_text('new')
            self.assertEqual(verify.changed_paths(root), ['new.py', 'rename.py', 'renamed.py', 'staged.py', 'worktree.py'])

    def test_changed_paths_cannot_escape_repository(self):
        for value in ['../escape.gd', '/outside/repo.gd']:
            with self.assertRaises(ValueError):
                self.real_plan(value)

    def test_plan_is_read_only_and_never_resolves_engine(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'must-not-exist'
            with patch.object(sys, 'argv', ['verify', '--plan', '--changed', 'README.md', '--output', str(output)]), \
                 patch.object(verify, 'find_godot', side_effect=AssertionError('must not locate engine')), \
                 patch.object(verify, 'run_step', side_effect=AssertionError('must not run checks')), \
                 patch.object(verify, 'identity', side_effect=AssertionError('must not hash workspace')):
                self.assertEqual(verify.main(), 0)
            self.assertFalse(output.exists())

    def test_explicit_suite_ignores_unrelated_dirty_worktree_without_changed(self):
        with patch.object(sys, 'argv', ['verify', '--plan', '--suite', 'ProjectileSuite']), \
             patch.object(verify, 'changed_paths', side_effect=AssertionError('explicit scope must not inherit unrelated dirty files')):
            self.assertEqual(verify.main(), 0)

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

    def test_group_union_is_deduplicated_and_rejects_unknown(self):
        catalog = json.dumps([{'id': 'a', 'group': 'combat'},
                              {'id': 'b', 'group': 'combat'},
                              {'id': 'c', 'group': 'ui'}])
        self.assertEqual(verify.expected_suites(catalog, ['a', 'c'], ['combat']), ['a', 'b', 'c'])
        self.assertEqual(verify.expected_suites(catalog, groups=['combat', 'combat']), ['a', 'b'])
        with self.assertRaises(ValueError):
            verify.expected_suites(catalog, groups=['typo'])

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
        self.assertEqual(first['files_sha256']['new.txt'], verify.hashlib.sha256(b'one').hexdigest())
        self.assertEqual(second['files_sha256']['new.txt'], verify.hashlib.sha256(b'two').hexdigest())
        self.assertEqual(before['files_sha256'], {})
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
                     units=[[1, 'gnar', 100, 50, 60]], audio_stopped=True, remote_elixir=1, tower_shields=[[1, 0.1], [0, 0]], tower_controls=[[False, False], [False, False]])
        return {role: '[NETWORK_RESULT] ' + json.dumps(dict(
            state, role=role, player_states=[{'coins': 1}, {'coins': 2}], player_state={'coins': 1 if role == 'client0' else 2}, **(client_updates if role == 'client1' else {})))
                for role in ['server', 'client0', 'client1']}

    def test_network_complete(self):
        self.assertEqual(verify.validate_network(self.network_logs())[1], [])

    def test_network_mismatched_terminal_state(self):
        for field, value in [('final_tick', 64), ('session_id', 'old'),
                             ('tower_hp', [3600, 10]), ('tower_controls', [[True, False], [False, False]]), ('units', [])]:
            self.assertTrue(verify.validate_network(self.network_logs(**{field: value}))[1])

    def test_network_missing_duplicate_or_failed_result(self):
        for value in ['', '[NETWORK_RESULT] null', '[NETWORK_RESULT] {}']:
            logs = self.network_logs()
            logs['client1'] = value
            self.assertTrue(verify.validate_network(logs)[1])
        logs = self.network_logs()
        logs['client1'] += '\n' + logs['client1']
        self.assertTrue(verify.validate_network(logs)[1])
        self.assertTrue(verify.validate_network(self.network_logs(passed=False))[1])
        self.assertTrue(verify.validate_network(self.network_logs(audio_stopped=False))[1])

    def test_network_runtime_error_despite_success(self):
        logs = self.network_logs()
        logs['client1'] += '\nSCRIPT ERROR: injected'
        self.assertTrue(verify.validate_network(logs)[1])

    def test_network_boundary_results(self):
        logs = {role: '[NETWORK_BOUNDARY_RESULT] ' + json.dumps(dict(
            schema=1, role=role, passed=True, case='slow', session_id='epoch'))
                for role in ['server', 'client0', 'client1']}
        self.assertEqual(verify.validate_network_boundary(logs, 'slow')[1], [])
        self.assertTrue(verify.validate_network_boundary(logs, 'disconnect')[1])
        for broken in ['', logs['client1'] + '\n' + logs['client1'],
                       logs['client1'].replace('epoch', 'other'),
                       logs['client1'].replace('true', 'false'),
                       logs['client1'] + '\nSCRIPT ERROR: injected']:
            self.assertTrue(verify.validate_network_boundary(dict(logs, client1=broken), 'slow')[1])


if __name__ == '__main__':
    unittest.main()
