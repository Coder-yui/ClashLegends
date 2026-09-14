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
import shutil
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
RESULT_PREFIX = '[MECHANICS_RESULT] '
ERROR_PATTERN = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|ERROR\s|Traceback \(most recent call last\):)')


def identity(root: Path) -> dict:
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root)
    paths = sorted(set(git('ls-files', '-z').split(b'\0') +
                       git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0')) - {b''})
    digest = hashlib.sha256()
    for raw in paths:
        path = root / os.fsdecode(raw)
        digest.update(raw + b'\0')
        if path.is_file():
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
        else:
            digest.update(b'<deleted>')
        digest.update(b'\0')
    status = git('status', '--porcelain=v1').decode()
    return {'commit': git('rev-parse', 'HEAD').decode().strip(), 'dirty': bool(status),
            'status': status, 'content_sha256': digest.hexdigest(), 'file_count': len(paths)}


def expected_suites(source: str, selected: list[str] | None = None) -> list[str]:
    catalog = json.loads(source)
    names = [entry['id'] for entry in catalog]
    if len(names) != len(set(names)) or not names:
        raise ValueError('Invalid or duplicate suite catalog')
    if selected and set(selected) - set(names):
        raise ValueError('Unknown suites: ' + ', '.join(sorted(set(selected) - set(names))))
    return [name for name in names if not selected or name in selected]


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


def run_step(name: str, command: list[str], output: Path, timeout: float, suites: list[str] | None = None) -> dict:
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
            required = ['session_id', 'final_tick', 'winner_team', 'reason', 'tower_hp', 'units', 'audio_stopped', 'remote_elixir', 'tower_shields']
            if not all(field in result for field in required) or not result['session_id'] or result['audio_stopped'] is not True:
                raise ValueError('incomplete terminal state')
            results[role] = result
        except (ValueError, TypeError) as exc:
            errors.append(f'{role}: {exc}')
        if ERROR_PATTERN.search(log):
            errors.append(f'{role}: unexpected runtime error')
    if set(results) != {'host', 'client'}:
        errors.append('Both host and client must complete')
    elif any(results['host'][field] != results['client'][field] for field in required):
        errors.append('Host and client terminal entity/tower/result states differ')
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
    if set(results) != {'host', 'client'}:
        errors.append('Both boundary peers must complete')
    elif results['host']['session_id'] != results['client']['session_id']:
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
    roles = [('host', 'host'), ('client', 'join')]
    try:
        for role, mode in roles:
            stream = (output / f'network-{role}.log').open('w')
            streams.append(stream)
            command = [godot, *([] if rendered else ['--headless']), '--path', '.', '--script', 'tests/mechanics_check.gd', '--',
                       '--network-smoke', '--auto-test', f'--mode={mode}', '--ip=127.0.0.1', f'--port={port}']
            if scenario:
                command.append(f"--network-case={scenario}")
            if rendered:
                command.append(f'--network-render-dir={output}')
            commands.append(command)
            processes.append(subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True))
            if role == 'host':
                # Wait for actual listening state, not a fixed startup delay.
                deadline = time.monotonic() + min(timeout, 20)
                while '房间已创建，端口' not in (output / 'network-host.log').read_text(errors='replace'):
                    if processes[0].poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError('Host did not reach listening state')
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
    results, errors = validate_network_boundary(logs, scenario) if scenario else validate_network(logs)
    failures.extend(errors)
    result = {'name': 'network-' + scenario if scenario else 'network', 'passed': not failures, 'errors': failures, 'commands': commands,
              'port': port, 'seconds': time.monotonic() - started, 'results': results,
              'logs': [str(output / f'network-{role}.log') for role, _ in roles]}
    print(f"[network] {'PASS' if result['passed'] else 'FAIL'} — {output}", flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', action='append', help='Run only a named mechanics suite; repeat to select several')
    parser.add_argument('--reverse-suites', action='store_true', help='Run selected suites in reverse order to check isolation')
    parser.add_argument('--network-boundaries', action='store_true', help='Also run protocol/content mismatch, slow loading and disconnect cases')
    parser.add_argument('--network', action='store_true', help='Run two-process terminal-state integration')
    parser.add_argument('--network-port', type=int, default=0, help='0 chooses a free local UDP port')
    parser.add_argument('--network-render', action='store_true', help='Run network integration with visible rendering and capture final frames')
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--timeout', type=float, default=600, help='Timeout in seconds per step')
    args = parser.parse_args()
    if args.network_port and not 1024 <= args.network_port <= 65535:
        parser.error('--network-port must be 0 or 1024..65535')
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    try:
        expected_suites((ROOT / 'tests/suite_catalog.json').read_text(), args.suite)
    except ValueError as exc:
        parser.error(str(exc))
    godot = args.godot or shutil.which('godot') or shutil.which('Godot')
    if not godot and Path('/Applications/Godot.app/Contents/MacOS/Godot').exists():
        godot = '/Applications/Godot.app/Contents/MacOS/Godot'
    output = (args.output or ROOT / 'ClashLegends-开发素材库/04-中间产物/构建与验证/verification' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {'schema': 1, 'started_at': datetime.now(timezone.utc).isoformat(), 'workspace': str(ROOT),
              'identity_before': identity(ROOT), 'steps': [], 'manual_acceptance': 'Not performed'}
    try:
        if not godot:
            raise RuntimeError('Godot executable not found; set --godot or GODOT_BIN')
        report['engine'] = subprocess.check_output([godot, '--version'], text=True, timeout=15).strip()
        required_engine = (ROOT / "godot-version.txt").read_text().strip()
        if report["engine"] != required_engine:
            raise RuntimeError(f"Engine mismatch: expected {required_engine}, got {report['engine']}")
        commands = [
            ('audit', [sys.executable, 'tools/maintenance/audit_project.py']),
            ('verifier-tests', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tools/maintenance', '-p', 'test_*.py']),
            ('import', [godot, '--headless', '--path', '.', '--editor', '--import', '--quit']),
            ('mechanics', [godot, '--headless', '--path', '.', '--script', 'tests/mechanics_check.gd', '--',
                           *['--suite=' + name for name in (args.suite or [])],
                           *(['--reverse-suites'] if args.reverse_suites else [])]),
            ('diff-check', ['git', 'diff', '--check']),
        ]
        for name, command in commands:
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
            for scenario in ['protocol', 'content', 'slow', 'disconnect', 'restart', 'buildings']:
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
