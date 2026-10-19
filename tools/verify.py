"""Run traceable repository checks; an exit code alone never establishes success."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.tool_paths import godot as find_godot

ROOT = Path(__file__).resolve().parents[1]
RESULT_PREFIX = '[MECHANICS_RESULT] '
ERROR_PATTERN = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|ERROR\s|Traceback \(most recent call last\):)')


def identity(root: Path) -> dict:
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root)
    paths = sorted(set(git('ls-files', '-z').split(b'\0') +
                       git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0')) - {b''})
    digest = hashlib.sha256()
    files = {}
    for raw in paths:
        path = root / os.fsdecode(raw)
        digest.update(raw + b'\0')
        file_digest = hashlib.sha256()
        if path.is_file():
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
                    file_digest.update(chunk)
            files[os.fsdecode(raw)] = file_digest.hexdigest()
        else:
            digest.update(b'<deleted>')
            files[os.fsdecode(raw)] = None
        digest.update(b'\0')
    status = git('status', '--porcelain=v1').decode()
    return {'commit': git('rev-parse', 'HEAD').decode().strip(), 'dirty': bool(status),
            'status': status, 'content_sha256': digest.hexdigest(), 'file_count': len(paths), 'files_sha256': files}


def expected_suites(source: str, selected: list[str] | None = None, groups: list[str] | None = None) -> list[str]:
    catalog = json.loads(source)
    names = [entry['id'] for entry in catalog]
    if len(names) != len(set(names)) or not names:
        raise ValueError('Invalid or duplicate suite catalog')
    if selected and set(selected) - set(names):
        raise ValueError('Unknown suites: ' + ', '.join(sorted(set(selected) - set(names))))
    known_groups = {entry.get('group') for entry in catalog}
    if groups and set(groups) - known_groups:
        raise ValueError('Unknown groups: ' + ', '.join(sorted(set(groups) - known_groups)))
    # Suite and group selectors form a union, emitted once in catalog order.
    return [entry['id'] for entry in catalog
            if not (selected or groups) or entry['id'] in (selected or [])
            or entry.get('group') in (groups or [])]



def changed_paths(root: Path) -> list[str]:
    """HEAD includes both index/worktree edits; no-renames preserves both endpoints."""
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root).split(b'\0')
    return sorted({os.fsdecode(p) for p in
                   git('diff', 'HEAD', '--name-only', '--no-renames', '-z') +
                   git('ls-files', '--others', '--exclude-standard', '-z') if p})


def verification_plan(root: Path, source: str, paths: list[str], *, full: bool = False,
                      suites: list[str] | None = None, groups: list[str] | None = None) -> dict:
    """Risk routes select catalog entries, never register another suite list.

    Script stems/groups resolve through the sole suite_catalog.json. Direct class
    consumers supplement routes; ubiquitous Main/Unit/CardDB use explicit domains.
    Unknown paths stop automatic execution rather than silently claiming coverage.
    """
    catalog = json.loads(source)
    all_suites = expected_suites(source, suites, groups)
    explicit = bool(suites or groups)
    chosen, tools, unknown, reasons = set(), set(), [], []
    card_facts = full
    effects = full
    requires_import = full
    cache = root / '.godot/global_script_class_cache.cfg'
    cache_text = cache.read_text(errors='replace') if cache.is_file() else ''
    stems = {Path(e.get('script', '')).stem: e['id'] for e in catalog}
    # A script can expose multiple catalog methods (maintenance is one example).
    def add_stems(*names):
        chosen.update(e['id'] for e in catalog if Path(e.get('script', '')).stem in names)
    def add_groups(*names):
        chosen.update(e['id'] for e in catalog if e.get('group') in names)
    python_tests = sorted(root.glob('tools/maintenance/test_*.py')) + sorted(root.glob('tools/tests/test_*.py'))
    if full:
        chosen.update(all_suites)
        tools.update(str(p.relative_to(root)) for p in python_tests)
    normalized = []
    for raw in paths:
        path = Path(raw)
        if path.is_absolute():
            try:
                path = path.relative_to(root.resolve())
            except ValueError:
                raise ValueError('Changed path is outside the repository: ' + raw)
        if '..' in path.parts:
            raise ValueError('Changed path must stay inside the repository: ' + raw)
        normalized.append(path.as_posix().removeprefix('./'))
    for path in sorted(set(normalized)):
        before = set(chosen)
        matched = True
        domain = 'local'
        effective = path.removesuffix('.uid').removesuffix('.import')
        stem = Path(effective).stem
        if effective.startswith(('assets/', 'scenes/')) or effective == 'project.godot':
            requires_import = True
        if effective.endswith('.md') or effective.startswith(('docs/', '需求文档/')):
            domain = 'documentation'
        elif effective in ('tests/suite_catalog.json', 'tests/mechanics_check.gd', 'tests/suites/battle_suite.gd'):
            # Changes to shared harness/registration require an explicit milestone scope.
            matched = full or explicit
            domain = 'shared-test-harness: explicit scope required'
        elif effective.startswith('tests/suites/'):
            resolved_stem = stem
            add_stems(resolved_stem)
            matched = resolved_stem in stems
            if stem in ('network_integration_suite', 'network_boundary_suite'):
                add_groups('network')
                matched = True
                domain = 'network-fixture: real three-peer checks require explicit network flags'
        elif effective.startswith('tests/fixtures/'):
            if stem == 'projectile_view_checks':
                add_stems('projectile_suite')
            elif stem.startswith('network_'):
                add_groups('network')
                domain = 'network-fixture'
            elif stem.startswith('void_gate_'):
                add_stems('void_gate_suite', 'spell_projection_suite', 'spell_warmup_suite')
            elif stem == 'native_path_search':
                add_stems('navigation_collision_suite', 'arena_deployment_suite')
            else:
                matched = False
        elif effective.startswith(('scripts/data/', 'scripts/unit')):
            card_facts = True
            add_stems('card_db_validation_suite', 'content_contract_suite', 'maintenance_suite')
            if '/cards/' in effective:
                add_groups('deployment')
                add_stems('deck_builder_suite', 'spell_warmup_suite')
                # Definitions and their direct tests, including form/family aliases.
                family = stem.split('_')[0]
                for entry in catalog:
                    test_stem = Path(entry.get('script', '')).stem
                    if test_stem.startswith(family) or ('minion' in stem and test_stem == 'minion_squad_suite'):
                        chosen.add(entry['id'])
            else:
                add_groups('combat', 'status', 'deployment', 'network', 'ui')
            domain = 'card-definition' if '/cards/' in effective else 'shared-data/entity'
        elif effective == 'scripts/main.gd' or effective in ('project.godot', 'godot-version.txt') or effective.startswith('scenes/'):
            add_groups('contracts', 'network', 'combat', 'status', 'deployment', 'ui', 'presentation')
            domain = 'lifecycle/cross-domain'
        elif effective.startswith('scripts/battle/'):
            if stem.startswith('network_') or stem in ('match_session', 'client_input_state'):
                add_groups('network')
                add_stems('projectile_suite', 'terminal_audio_suite', 'maintenance_suite', 'deck_builder_suite')
                domain = 'protocol/session'
            elif stem in ('fixed_step_clock', 'battle_simulation', 'battle_context', 'match_lifecycle', 'match_rules', 'match_runtime'):
                add_groups('network', 'combat', 'deployment', 'status')
                add_stems('workbench_suite', 'animation_state_suite', 'terminal_audio_suite')
                domain = '20Hz/lifecycle'
            elif stem == 'projectile_system':
                add_stems('projectile_suite', 'numeric_system_suite', 'network_lifecycle_suite',
                          'terminal_state_suite', 'kayle_suite', 'anivia_suite', 'gwen_suite',
                          'jinx_suite', 'corki_suite', 'voidfish_ranged_suite', 'nocturne_suite',
                          'spell_projection_suite', 'spell_warmup_suite')
            elif stem in ('match_card_growth', 'active_skill_roster'):
                add_stems('maintenance_suite', 'session_suite', 'kayn_suite', 'deck_builder_suite', 'active_skill_suite')
            else:
                add_groups('combat', 'status', 'deployment')
                add_stems('network_lifecycle_suite')
        elif effective.startswith('scripts/ui/'):
            add_groups('ui')
            if stem in ('deck_builder', 'card_details', 'card_hand', 'card_info'):
                add_stems('session_suite', 'card_db_validation_suite')
        elif effective.startswith('scripts/presentation/'):
            if 'projectile' in stem or stem in ('anivia_effect_3d', 'gwen_tristana_effect_3d', 'voidfish_effect_3d'):
                add_stems('projectile_suite')
            elif stem in ('match_resources', 'match_resource_plan', 'match_model_pool', 'effect_resource_manifest'):
                add_stems('deck_builder_suite', 'spell_warmup_suite', 'dependency_header_suite', 'presentation_suite')
                effects = True
            else:
                add_groups('presentation')
                add_stems('workbench_suite')
        elif effective.startswith('scripts/audio/') or effective == 'default_bus_layout.tres':
            add_stems('audio_presentation_suite', 'terminal_audio_suite', 'terminal_state_suite', 'spell_warmup_suite')
            tools.update(str(p.relative_to(root)) for p in python_tests if 'audio' in p.name or 'gain' in p.name)
        elif effective.startswith('assets/'):
            add_stems('presentation_suite', 'spell_warmup_suite', 'animation_state_suite')
            if effective.startswith('assets/effects/'):
                effects = True
                add_stems('dependency_header_suite', 'spell_projection_suite')
            for part in Path(effective).parts[2:-1]:
                if len(part) > 2:
                    chosen.update(e['id'] for e in catalog if Path(e.get('script', '')).stem.startswith(part + '_'))
            domain = 'resource: actual render/listen acceptance remains manual'
        elif effective.startswith('tools/'):
            candidates = [p for p in python_tests if p.relative_to(root).as_posix() == effective or p.stem == 'test_' + stem or
                          effective in p.read_text().split('\nclass ', 1)[0] or
                          (effective.startswith('tools/performance/') and p.stem == 'test_safe_probe') or
                          (effective.startswith(('tools/lib/', 'tools/viewers/', 'tools/dev', 'tools/stage')) and p.stem == 'test_reusable_tools')]
            tools.update(str(p.relative_to(root)) for p in candidates)
            if stem in ('effect_dependencies', 'test_effect_dependencies', 'export_card_facts', 'check_card_facts', 'test_card_facts'):
                effects |= 'effect' in stem
                card_facts |= 'card_facts' in stem
                if card_facts:
                    add_stems('card_db_validation_suite', 'content_contract_suite')
            matched = bool(candidates) or stem in ('export_card_facts', 'effect_dependencies', 'check_card_facts')
            domain = 'tool-module'
        elif effective in ('.gitignore', '.gitattributes', 'export_presets.cfg'):
            tools.update(str(p.relative_to(root)) for p in python_tests if p.stem in ('test_audit_project', 'test_reusable_tools'))
            domain = 'repository/export-configuration'
        else:
            matched = False
        # Include tests directly reading the changed class/path. This is deliberately
        # one edge, not a transitive walk through Main that expands every local edit.
        runtime = root / effective
        if effective.startswith('scripts/') and runtime.is_file():
            text = runtime.read_text(errors='replace')
            match = re.search(r'^class_name\s+(\w+)', text, re.M)
            token = match.group(1) if match else None
            if token and not re.search(r'\b' + re.escape(token) + r'\b', cache_text):
                requires_import = True
            for entry in catalog:
                test = root / entry.get('script', '').removeprefix('res://')
                if not test.is_file():
                    continue
                contents = test.read_text(errors='replace')
                if effective in contents or (token and token not in ('Main', 'Unit', 'CardDB') and
                                             re.search(r'\b' + re.escape(token) + r'\b', contents)):
                    chosen.add(entry['id'])
        if not matched:
            unknown.append(path)
        reasons.append({'path': path, 'risk': domain, 'suites': [e['id'] for e in catalog if e['id'] in chosen - before]})
    if effects:
        tools.update(str(p.relative_to(root)) for p in python_tests if p.name == 'test_effect_dependencies.py')
    if card_facts:
        tools.update(str(p.relative_to(root)) for p in python_tests if p.name == 'test_card_facts.py')
    if explicit:
        chosen = set(all_suites)
    selected = [e['id'] for e in catalog if e['id'] in chosen]
    broad = (len(selected) >= max(12, (len(catalog) * 3 + 4) // 5) or
             any(r['risk'] in ('lifecycle/cross-domain', 'shared-data/entity') for r in reasons))
    requires_scope = not (full or explicit) and (bool(unknown) or broad)
    return {'schema': 1, 'mode': 'full' if full else 'explicit' if explicit else 'changed',
            'changed_paths': sorted(set(normalized)), 'suites': selected,
            'suite_count': len(selected), 'catalog_suite_count': len(catalog),
            'python_tests': sorted(tools), 'card_facts': card_facts, 'effect_dependencies': effects,
            'requires_import': requires_import,
            'import_policy': 'Import only for --full/--import, resources/scenes/project settings, or missing global class cache; cached script edits reuse imports',
            'unknown_paths': unknown, 'blocked': requires_scope, 'requires_explicit_scope': requires_scope,
            'scope_reason': ('Unrecognized paths need an explicit scope' if unknown else
                             'Automatic selection is broad (shared lifecycle/data or at least 60% of the catalog); narrow --changed or use --suite/--group/--full' if broad else ''),
            'reasons': reasons, 'network': 'Only when --network/--network-boundaries/--network-render is explicitly supplied',
            'manual_acceptance': 'Actual rendering/audio/performance acceptance is separate; this plan does not establish it'}


def planned_commands(plan: dict, godot: str | None, output: Path, reverse: bool = False,
                     network: bool = False) -> list[tuple[str, list[str]]]:
    commands = [('audit', [sys.executable, 'tools/maintenance/audit_project.py'])]
    for directory, label in [('tools/maintenance', 'verifier-tests'), ('tools/tests', 'tool-tests')]:
        tests = [p for p in plan['python_tests'] if str(Path(p).parent) == directory]
        if tests:
            # Discovery supplies each test directory's import context. Several
            # maintenance tests import sibling modules by their local names.
            # Only an explicit full plan discovers the whole directory.
            patterns = ['test_*.py'] if plan['mode'] == 'full' else [Path(p).name for p in tests]
            for pattern in patterns:
                name = label if len(patterns) == 1 else label + '-' + Path(pattern).stem
                commands.append((name, [sys.executable, '-m', 'unittest', 'discover',
                                        '-s', directory, '-p', pattern]))
    if plan['effect_dependencies']:
        commands.append(('effect-dependencies', [sys.executable, 'tools/maintenance/effect_dependencies.py', '--check']))
    if plan['requires_import'] and (plan['suites'] or network or plan['card_facts']):
        commands.append(('import', [godot or '<Godot>', '--headless', '--path', '.', '--editor', '--import', '--quit']))
    if plan['card_facts']:
        commands.extend([
            ('card-facts-export', [godot or '<Godot>', '--headless', '--path', '.', '--script', 'tools/maintenance/export_card_facts.gd', '--', str(output / 'card-facts.json')]),
            ('card-facts-check', [sys.executable, 'tools/maintenance/check_card_facts.py', str(output / 'card-facts.json')])])
    if plan['suites']:
        commands.append(('mechanics', [godot or '<Godot>', '--headless', '--path', '.', '--script', 'tests/mechanics_check.gd', '--',
                                      *['--suite=' + name for name in plan['suites']],
                                      *(['--reverse-suites'] if reverse else [])]))
    commands.append(('diff-check', ['git', 'diff', '--check']))
    return commands

def validate_mechanics(log: str, expected: list[str]) -> tuple[dict | None, list[str]]:
    errors = []
    markers = [line[len(RESULT_PREFIX):] for line in log.splitlines() if line.startswith(RESULT_PREFIX)]
    if len(markers) != 1:
        return None, ['Expected exactly one structured mechanics result']
    try:
        result = json.loads(markers[0])
        if not isinstance(result, dict) or result.get('schema') != 1:
            raise ValueError('unsupported result schema')
        if type(result.get('checks')) is not int or result['checks'] <= 0:
            errors.append('No valid assertions completed')
        if type(result.get('failed')) is not int or result['failed'] != 0:
            errors.append('Mechanics assertions failed or failure count is invalid')
        completed = result.get('completed_suites')
        if not isinstance(completed, list) or any(not isinstance(x, str) for x in completed):
            errors.append('Invalid suite completion list')
        elif not expected or Counter(completed) != Counter(expected):
            errors.append('Suite completion does not match the current runner')
    except (ValueError, TypeError) as exc:
        return None, [f'Invalid structured result: {exc}']
    if '[机制检查] 全部通过' not in log:
        errors.append('Missing final human-readable success summary')
    if ERROR_PATTERN.search(log):
        errors.append('Unexpected runtime/script error in mechanics log')
    return result, errors


def run_engine(*args, **kwargs):
    from verification_guard import run_engine as guarded
    return guarded(*args, **kwargs)


def run_step(name: str, command: list[str], output: Path, timeout: float, suites: list[str] | None = None, guard_profile: str | None = None) -> dict:
    if guard_profile and name in {'import', 'card-facts-export'}:
        raise ValueError('authority-logic does not cover import/card-facts; protected step refused')
    if guard_profile and name == 'mechanics':
        guarded_output = output / (name + '-guard')
        supervision = run_engine(command, guarded_output, timeout, profile=guard_profile, heartbeat=True)
        path = output / f'{name}.log'
        log_file = guarded_output / 'engine.log'
        log = log_file.read_text(errors='replace') if log_file.exists() else ''
        path.write_text(log)
        errors = [] if supervision['passed'] else ['Supervisor: ' + supervision['reason']]
        if ERROR_PATTERN.search(log): errors.append('Unexpected error in log')
        step = dict(name=name, command=command, exit_code=supervision.get('exit_code'),
                    seconds=supervision.get('seconds', 0), log=str(path), errors=errors,
                    supervision=supervision)
        if name == 'mechanics':
            result, validation_errors = validate_mechanics(log, expected_suites((ROOT / 'tests/suite_catalog.json').read_text(), suites))
            step['result'] = result
            errors.extend(validation_errors)
        step['passed'] = not errors
        print(f"[{name}] {'PASS' if step['passed'] else 'FAIL'} — {path}", flush=True)
        return step
    path = output / f'{name}.log'
    started = time.monotonic()
    timed_out = False
    with path.open('w') as stream:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            # A child may ignore TERM even after its parent has exited.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            code = process.returncode
    log = path.read_text(errors='replace')
    errors = []
    if timed_out:
        errors.append('Timed out or interrupted; process group terminated')
    if code != 0:
        errors.append(f'Process exited {code}')
    if ERROR_PATTERN.search(log):
        errors.append('Unexpected error in log')
    step = {'name': name, 'command': command, 'exit_code': code, 'seconds': time.monotonic() - started,
            'log': str(path), 'errors': errors}
    if name == 'mechanics':
        result, validation_errors = validate_mechanics(log, expected_suites((ROOT / 'tests/suite_catalog.json').read_text(), suites))
        step['result'] = result
        errors.extend(validation_errors)
    step['passed'] = not errors
    print(f"[{name}] {'PASS' if step['passed'] else 'FAIL'} — {path}", flush=True)
    return step


def validate_network(logs: dict[str, str]) -> tuple[dict, list[str]]:
    results = {}
    errors = []
    for role, log in logs.items():
        markers = [line[len('[NETWORK_RESULT] '):] for line in log.splitlines() if line.startswith('[NETWORK_RESULT] ')]
        try:
            if len(markers) != 1:
                raise ValueError('expected exactly one result')
            result = json.loads(markers[0])
            if not isinstance(result, dict) or result.get('schema') != 1 or result.get('passed') is not True or result.get('role') != role:
                raise ValueError('invalid/failed result')
            required = ['session_id', 'final_tick', 'winner_team', 'reason', 'tower_hp', 'units', 'audio_stopped', 'remote_elixir', 'tower_shields', 'tower_controls']
            if not all(field in result for field in required) or not result['session_id'] or result['audio_stopped'] is not True:
                raise ValueError('incomplete terminal state')
            results[role] = result
        except (ValueError, TypeError) as exc:
            errors.append(f'{role}: {exc}')
        if ERROR_PATTERN.search(log):
            errors.append(f'{role}: unexpected runtime error')
    if set(results) != {'server', 'client0', 'client1'}:
        errors.append('Server and both clients must complete')
    elif any(results['server'][field] != results[client][field] for client in ['client0', 'client1'] for field in required if field != 'remote_elixir'):
        errors.append('Server and clients terminal entity/tower/result states differ')
    if set(results) == {'server', 'client0', 'client1'}:
        private = results['server'].get('player_states')
        if not isinstance(private, list) or len(private) != 2 or any(
                results[f'client{team}'].get('player_state') != private[team] for team in [0, 1]):
            errors.append('Recipient private state differs from authoritative player state')
    return results, errors


def validate_network_boundary(logs: dict[str, str], scenario: str) -> tuple[dict, list[str]]:
    results = {}
    errors = []
    prefix = '[NETWORK_BOUNDARY_RESULT] '
    for role, log in logs.items():
        markers = [line[len(prefix):] for line in log.splitlines() if line.startswith(prefix)]
        try:
            if len(markers) != 1:
                raise ValueError('expected exactly one boundary result')
            result = json.loads(markers[0])
            if not isinstance(result, dict) or result.get('schema') != 1 or result.get('passed') is not True or result.get('role') != role or result.get('case') != scenario or not result.get('session_id'):
                raise ValueError('invalid/failed boundary result')
            results[role] = result
        except (ValueError, TypeError) as exc:
            errors.append(f'{role}: {exc}')
        if ERROR_PATTERN.search(log):
            errors.append(f'{role}: unexpected runtime error')
    if set(results) != {'server', 'client0', 'client1'}:
        errors.append('All three boundary peers must complete')
    elif any(results['server']['session_id'] != results[client]['session_id'] for client in ['client0', 'client1']):
        errors.append('Boundary peers disagree on session identity')
    return results, errors


def run_network(godot: str, output: Path, timeout: float, port: int = 0, rendered: bool = False, scenario: str = "") -> dict:
    if not port:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
    processes = []
    streams = []
    commands = []
    failures = []
    started = time.monotonic()
    roles = [('server', 'server'), ('client0', 'join'), ('client1', 'join')]
    try:
        for role, mode in roles:
            stream = (output / f'network-{role}.log').open('w')
            streams.append(stream)
            command = [godot, *([] if rendered and role != 'server' else ['--headless']), '--path', '.', '--script', 'tests/mechanics_check.gd', '--',
                       '--network-smoke', '--auto-test', f'--mode={mode}', '--ip=127.0.0.1', f'--port={port}']
            if scenario == "impaired":
                command.append("--network-impaired")
            elif scenario:
                command.append(f"--network-case={scenario}")
            if rendered:
                command.append(f'--network-render-dir={output}')
            commands.append(command)
            processes.append(subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True))
            if role in ['server', 'client0']:
                # Wait for actual listening state, not a fixed startup delay.
                deadline = time.monotonic() + min(timeout, 20)
                marker = '服务器已启动，端口' if role == 'server' else '玩家 0 已绑定'
                while marker not in (output / 'network-server.log').read_text(errors='replace'):
                    if processes[0].poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError('Server did not reach expected connection state')
                    time.sleep(0.1)
        for process in processes:
            process.wait(timeout=max(0.01, timeout - (time.monotonic() - started)))
        if any(process.returncode != 0 for process in processes):
            failures.append('Network child process exited nonzero')
    except (OSError, RuntimeError, subprocess.TimeoutExpired, KeyboardInterrupt) as exc:
        failures.append(f'Network run interrupted/failed: {exc}')
    finally:
        for process in processes:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        for stream in streams:
            stream.close()
    logs = {role: (output / f'network-{role}.log').read_text(errors='replace') if (output / f'network-{role}.log').exists() else '' for role, _ in roles}
    results, errors = validate_network_boundary(logs, scenario) if scenario and scenario != "impaired" else validate_network(logs)
    failures.extend(errors)
    result = {'name': 'network-' + scenario if scenario else 'network', 'passed': not failures, 'errors': failures, 'commands': commands,
              'port': port, 'seconds': time.monotonic() - started, 'results': results,
              'logs': [str(output / f'network-{role}.log') for role, _ in roles]}
    print(f"[network] {'PASS' if result['passed'] else 'FAIL'} — {output}", flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--changed', action='append', nargs='+', metavar='PATH', help='Replace git changes with explicit repository paths; repeatable')
    parser.add_argument('--full', action='store_true', help='Explicit milestone: all catalog suites and safe Python checks; no implicit three-peer network')
    parser.add_argument('--import', dest='prepare_import', action='store_true', help='Explicitly rebuild Godot import/global-class cache before engine checks')
    parser.add_argument('--plan', action='store_true', help='Print read-only JSON selection/commands; do not create output or start Godot')
    parser.add_argument('--group', action='append', help='Select a catalog group; repeat or combine with --suite (union)')
    parser.add_argument('--list-suites', action='store_true', help='List suite IDs by group without running checks')
    parser.add_argument('--suite', action='append', help='Run only a named mechanics suite; repeat to select several')
    parser.add_argument('--reverse-suites', action='store_true', help='Run selected suites in reverse order to check isolation')
    parser.add_argument('--network-boundaries', action='store_true', help='Also run protocol/content mismatch, slow loading and disconnect cases')
    parser.add_argument('--network', action='store_true', help='Run one-server/two-client terminal-state integration')
    parser.add_argument('--network-port', type=int, default=0, help='0 chooses a free local UDP port')
    parser.add_argument('--network-render', action='store_true', help='Run network integration with visible rendering and capture final frames')
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--timeout', type=float, help='Per-step timeout: ordinary default 600s; authority-logic default 20s, explicit values must be <=20s')
    parser.add_argument('--guard-profile', choices=['authority-logic'], help='Explicit Mac-only supervision for reviewed lightweight logic/injection suites; no import/network/loading')
    args = parser.parse_args()
    args.timeout = args.timeout if args.timeout is not None else (20 if args.guard_profile else 600)
    if args.network_port and not 1024 <= args.network_port <= 65535:
        parser.error('--network-port must be 0 or 1024..65535')
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    if args.full and (args.suite or args.group):
        parser.error('--full cannot be combined with --suite/--group')
    try:
        source = (ROOT / 'tests/suite_catalog.json').read_text()
        selection = expected_suites(source, args.suite, args.group)
        if args.list_suites:
            for entry in json.loads(source):
                if entry['id'] in selection:
                    print(f"{entry['group']:14} {entry['id']}")
            return 0
        paths = [p for batch in args.changed for p in batch] if args.changed else ([] if args.suite or args.group or args.full else changed_paths(ROOT))
        plan = verification_plan(ROOT, source, paths, full=args.full, suites=args.suite, groups=args.group)
        args.suite = plan['suites']
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        parser.error(str(exc))
    wants_network = args.network or args.network_render or args.network_boundaries
    needs_engine = bool(plan['suites'] or plan['card_facts'] or wants_network)
    plan['requires_import'] |= args.prepare_import or (needs_engine and not (ROOT / '.godot/global_script_class_cache.cfg').is_file())
    preview = planned_commands(plan, args.godot, Path('<output>'), args.reverse_suites, wants_network)
    if args.guard_profile:
        from verification_guard import AUTHORITY_SUITES, policy
        try:
            plan['supervision'] = policy(args.guard_profile, args.timeout)
            if not args.plan and sys.platform != 'darwin':
                raise ValueError('authority-logic supervision supports macOS only; protected run refused')
            if not plan['suites'] or set(plan['suites']) - AUTHORITY_SUITES or wants_network or plan['requires_import'] or plan['card_facts']:
                raise ValueError('authority-logic only supports reviewed lightweight logic/injection suites with existing imports; import/card-facts/network/other suites require a separately reviewed policy')
        except ValueError as exc:
            parser.error(str(exc))
    else:
        plan['supervision'] = {'profile': None, 'wall_seconds_per_step': args.timeout,
                               'scope': 'Legacy timeout/process-group handling; no new RSS/system-pressure/heartbeat guarantee'}
    plan['steps'] = [{'name': name, 'command': command} for name, command in preview]
    plan['explicit_network'] = bool(wants_network)
    plan['network_cases'] = (['normal'] if wants_network else []) + (
        ['protocol', 'content', 'slow', 'slow_second_client', 'load_disconnect', 'load_timeout',
         'disconnect', 'restart', 'buildings', 'impaired'] if args.network_boundaries else [])
    if args.plan or plan['blocked']:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        if plan['blocked'] and not args.plan:
            print('Execution blocked: choose a narrower --changed scope, explicit --suite/--group, or --full.', file=sys.stderr)
        return 2 if plan['blocked'] else 0
    godot = (args.godot or find_godot()) if needs_engine else None
    output = (args.output or ROOT / 'ClashLegends-开发素材库/04-中间产物/构建与验证/verification' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {'schema': 1, 'started_at': datetime.now(timezone.utc).isoformat(), 'workspace': str(ROOT),
              'identity_before': identity(ROOT), 'plan': plan, 'steps': [], 'manual_acceptance': 'Not performed'}
    try:
        if needs_engine:
            if not godot:
                raise RuntimeError('Godot executable not found; set --godot or GODOT_BIN')
            report['engine'] = subprocess.check_output([godot, '--version'], text=True, timeout=15).strip()
            required_engine = (ROOT / "godot-version.txt").read_text().strip()
            if report["engine"] != required_engine:
                raise RuntimeError(f"Engine mismatch: expected {required_engine}, got {report['engine']}")
        commands = planned_commands(plan, godot, output, args.reverse_suites, wants_network)
        for name, command in commands:
            if args.guard_profile:
                step = run_step(name, command, output, args.timeout, args.suite, guard_profile=args.guard_profile)
            else:
                step = run_step(name, command, output, args.timeout, args.suite)
            report['steps'].append(step)
            if not step['passed']:
                break
        report['passed'] = len(report['steps']) == len(commands) and all(s['passed'] for s in report['steps'])
        if report['passed'] and (args.network or args.network_render or args.network_boundaries):
            network = run_network(godot, output, args.timeout, args.network_port, args.network_render)
            report['steps'].append(network)
            report['passed'] = network['passed']
        if report['passed'] and args.network_boundaries:
            for scenario in ['protocol', 'content', 'slow', 'slow_second_client', 'load_disconnect', 'load_timeout', 'disconnect', 'restart', 'buildings', 'impaired']:
                case_output = output / scenario
                case_output.mkdir()
                network = run_network(godot, case_output, args.timeout, scenario=scenario)
                report['steps'].append(network)
                if not network['passed']:
                    report['passed'] = False
                    break
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        report['error'] = str(exc)
        report['passed'] = False
    report['identity_after'] = identity(ROOT)
    report['workspace_changed_during_run'] = report['identity_before']['content_sha256'] != report['identity_after']['content_sha256']
    if report['workspace_changed_during_run']:
        report['passed'] = False
        report['error'] = 'Workspace contents changed during verification; rerun against a stable workspace'
    (output / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {output / 'result.json'}")
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
