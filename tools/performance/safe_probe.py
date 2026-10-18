#!/usr/bin/env python3
"""Short, locally supervised probes. A lost chat connection must not be the timeout."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
MIB = 1024 * 1024
DEFAULT_ROOT = ROOT / 'ClashLegends-开发素材库/04-中间产物/architecture_refactor/batch2b'


@dataclass(frozen=True)
class Limits:
    wall_seconds: float = 20.0
    startup_grace_seconds: float = 6.0
    heartbeat_seconds: float = 2.0
    rss_bytes: int = 1024 * MIB
    rss_growth_bytes: int = 256 * MIB
    poll_seconds: float = 0.1
    terminate_grace_seconds: float = 0.5

    def __post_init__(self):
        bounds = {'wall_seconds': 20, 'startup_grace_seconds': 6,
                  'heartbeat_seconds': 2, 'rss_bytes': 1024 * MIB,
                  'rss_growth_bytes': 256 * MIB, 'poll_seconds': 0.1,
                  'terminate_grace_seconds': 0.5}
        for name, maximum in bounds.items():
            value = getattr(self, name)
            if not 0 < value <= maximum:
                raise ValueError(f'{name} must be positive and <= {maximum}')
        if self.startup_grace_seconds > self.wall_seconds:
            raise ValueError('startup grace must fit inside total wall budget')


def group_rss_bytes(pgid: int) -> int:
    """Sum this owned group's RSS; monitoring failure aborts rather than running blind."""
    result = subprocess.run(['/bin/ps', '-axo', 'pgid=,rss='], text=True,
                            capture_output=True, timeout=0.25, check=True)
    return sum(int(row.split()[1]) * 1024 for row in result.stdout.splitlines()
               if len(row.split()) == 2 and int(row.split()[0]) == pgid)


def live_group_members(pgid: int) -> list[int]:
    """Only this PGID; zombies are already dead and cannot be signalled/reaped by us."""
    result = subprocess.run(['/bin/ps', '-axo', 'pid=,pgid=,stat='], text=True,
                            capture_output=True, timeout=0.25, check=True)
    members = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) != 3:
            raise ValueError('unreadable process status row')
        if int(fields[1]) == pgid and not fields[2].startswith('Z'):
            members.append(int(fields[0]))
    return members


def _rss_sample(reader, pgid):
    value = reader(pgid)
    if type(value) is not int or value < 0:
        raise ValueError('RSS monitor must return nonnegative integer bytes')
    return value


def _stop_group(process: subprocess.Popen, pgid: int, grace: float) -> dict:
    # start_new_session made PID == PGID; never signal the caller's group.
    if pgid != process.pid or pgid == os.getpgrp():
        return {'confirmed': False, 'error': 'owned group identity mismatch'}
    sent = []
    errors = []
    for number, label, wait_seconds in [(signal.SIGTERM, 'TERM', grace),
                                         (signal.SIGKILL, 'KILL', 0.5)]:
        try:
            os.killpg(pgid, number)
            sent.append(label)
        except ProcessLookupError:
            pass
        except OSError as error:
            errors.append(str(error))
        deadline = time.monotonic() + wait_seconds
        while time.monotonic() < deadline:
            process.poll()
            try:
                if not live_group_members(pgid):
                    process.wait(timeout=0.5)
                    return {'confirmed': not errors, 'signals': sent, 'errors': errors,
                            'remaining_live_pids': [], 'leader_exit_code': process.returncode,
                            'scope': 'owned process group has no live members; zombies excluded; not an OS/GPU recovery guarantee'}
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                errors.append(str(error))
                break  # still attempt KILL; inability to verify is never success
            time.sleep(0.02)
    try:
        process.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        errors.append('leader did not exit')
    try:
        remaining = live_group_members(pgid)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        remaining = None
        errors.append(str(error))
    return {'confirmed': remaining == [] and not errors, 'signals': sent,
            'remaining_live_pids': remaining, 'errors': errors,
            'leader_exit_code': process.returncode}


def _guarded_command(command: list[str], max_fps: int = 30) -> list[str]:
    if max_fps not in (30, 60):
        raise ValueError("guarded frame cap must be 30 or 60")
    command = list(command)
    # Detect an engine script invocation independently of the executable filename.
    if '--script' not in command:
        return command
    split = command.index('--') if '--' in command else len(command)
    options = command[:split]
    if any(item.startswith('--max-fps=') for item in options):
        raise ValueError('use a single --max-fps 30 argument pair')
    if options.count('--max-fps') > 1:
        raise ValueError('duplicate --max-fps flags')
    if '--max-fps' in options:
        index = options.index('--max-fps')
        if index + 1 >= split or command[index + 1] != str(max_fps):
            raise ValueError(f'guarded Godot probes require --max-fps {max_fps}')
    else:
        command[split:split] = ['--max-fps', str(max_fps)]
    return command


class Cancelled(Exception):
    pass


@contextmanager
def _interruption_handlers():
    previous = {}
    if threading.current_thread() is threading.main_thread():
        def cancel(number, _frame):
            raise Cancelled(f'signal {number}')
        for number in [signal.SIGTERM, signal.SIGINT, signal.SIGHUP]:
            previous[number] = signal.signal(number, cancel)
    try:
        yield
    finally:
        for number, handler in previous.items():
            signal.signal(number, handler)


def _heartbeat(path: Path, token: str, pid: int, previous: int):
    try:
        status = path.stat()
        if status.st_size > 4096:
            return None
        value = json.loads(path.read_text())
        if not isinstance(value, dict):
            return None
        if (value.get('token') != token or value.get('pid') != pid
                or type(value.get('sequence')) is not int or value['sequence'] <= previous
                or type(value.get('ready')) is not bool):
            return None
        # A previously unread but old pulse cannot refresh responsiveness to now.
        value['_file_age_seconds'] = max(0.0, time.time() - status.st_mtime)
        return value
    except (OSError, ValueError, TypeError):
        return None


def run_guarded(command: list[str], output: Path, *, env: dict | None = None,
                limits: Limits = Limits(), rss_reader=group_rss_bytes,
                lock_path: Path | None = None, require_heartbeat: bool = True, max_fps: int = 30) -> dict:
    """One owned process group. The caller must also bound its workload in the script."""
    command = _guarded_command(command, max_fps)
    engine_options = command[:command.index('--')] if '--' in command else command
    if not require_heartbeat and '--headless' not in engine_options:
        raise ValueError('heartbeat opt-out is restricted to explicit --headless correctness')
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    lock_path = lock_path or DEFAULT_ROOT / '.safe-probe.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    report = {'schema': 1, 'passed': False, 'reason': 'not_started', 'pid': None,
              'pgid': None, 'limits': asdict(limits), 'peak_rss_bytes': 0,
              'heartbeat_seen': False, 'ready_seen': False, 'cleanup': None,
              'scope': ('main-thread heartbeat + wall + RSS' if require_heartbeat else
                        'headless correctness: wall+RSS only, no responsiveness guarantee')}
    process = None
    started = time.monotonic()
    with lock_path.open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            report['reason'] = 'another_safe_probe_is_running'
            return report
        heartbeat_path = output / 'heartbeat.json'
        token = uuid.uuid4().hex
        child_env = dict(os.environ if env is None else env)
        child_env.update(CLASH_SAFE_PROBE_TOKEN=token,
                         CLASH_SAFE_PROBE_HEARTBEAT=str(heartbeat_path),
                         CLASH_SAFE_PROBE_PARENT_PID=str(os.getpid()))
        report['command'] = command
        sequence = -1
        last_heartbeat = started
        ready_since = None
        baseline_candidates = []
        baseline = None
        try:
            # Verify both monitors before creating any engine process.
            try:
                _rss_sample(rss_reader, os.getpgrp())
                live_group_members(os.getpgrp())
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                report.update(reason='rss_monitor_unavailable_before_launch', monitor_error=str(error))
                return report
            with _interruption_handlers(), (output / 'engine.log').open('x') as log:
                if time.monotonic() - started >= limits.wall_seconds:
                    report['reason'] = 'total_wall_timeout_before_launch'
                    return report
                process = subprocess.Popen(command, cwd=ROOT, env=child_env, stdin=subprocess.DEVNULL,
                                           stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                pgid = os.getpgid(process.pid)
                if pgid != process.pid:
                    raise RuntimeError('new private process group was not created')
                report.update(pid=process.pid, pgid=pgid)
                (output / 'launched.json').write_text(json.dumps(report, indent=2) + '\n')
                while True:
                    now = time.monotonic()
                    pulse = _heartbeat(heartbeat_path, token, process.pid, sequence)
                    if pulse:
                        sequence = pulse['sequence']
                        last_heartbeat = now - pulse['_file_age_seconds']
                        report.update(heartbeat_seen=True, last_sequence=sequence, last_phase=pulse.get('phase', ''))
                        if pulse['ready'] and ready_since is None:
                            ready_since = now
                            report['ready_seen'] = True
                    if now - started >= limits.wall_seconds:
                        report['reason'] = 'total_wall_timeout'
                        break
                    if require_heartbeat and not report['heartbeat_seen'] and now - started >= limits.startup_grace_seconds:
                        report['reason'] = 'startup_heartbeat_timeout'
                        break
                    if require_heartbeat and report['heartbeat_seen'] and now - last_heartbeat >= limits.heartbeat_seconds:
                        report['reason'] = 'main_thread_heartbeat_timeout'
                        break
                    code = process.poll()
                    if code is not None:
                        report['reason'] = 'completed' if code == 0 and (report['ready_seen'] or not require_heartbeat) else 'child_failed_or_no_ready_heartbeat'
                        report['passed'] = report['reason'] == 'completed'
                        break
                    try:
                        rss = _rss_sample(rss_reader, pgid)
                    except (OSError, ValueError, subprocess.SubprocessError) as error:
                        report.update(reason='rss_monitor_unavailable', monitor_error=str(error))
                        break
                    report['peak_rss_bytes'] = max(report['peak_rss_bytes'], rss)
                    cap = min(limits.rss_bytes, baseline + limits.rss_growth_bytes) if baseline is not None else limits.rss_bytes
                    report['active_rss_cap_bytes'] = cap
                    if rss > cap:
                        report['reason'] = 'rss_limit'
                        break
                    if ready_since is not None and baseline is None:
                        baseline_candidates.append(rss)
                        baseline_candidates = baseline_candidates[-3:]
                        if len(baseline_candidates) == 3 and max(baseline_candidates) - min(baseline_candidates) <= max(8 * MIB, min(baseline_candidates) * 0.05):
                            baseline = min(baseline_candidates)
                            report['stable_ready_rss_bytes'] = baseline
                        elif now - ready_since > 1.0:
                            report['reason'] = 'rss_baseline_unstable'
                            break
                    if (output / 'engine.log').stat().st_size > 4 * MIB:
                        report['reason'] = 'log_size_limit'
                        break
                    time.sleep(limits.poll_seconds)
        except (OSError, ValueError, RuntimeError, Cancelled, KeyboardInterrupt) as error:
            report.update(reason='supervisor_error_or_interruption', error=str(error))
        finally:
            if process is not None:
                report['cleanup'] = _stop_group(process, process.pid, limits.terminate_grace_seconds)
                report['exit_code'] = process.returncode
                if not report['cleanup']['confirmed']:
                    report['passed'] = False
            report['seconds'] = time.monotonic() - started
            (output / 'watchdog.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--probe', choices=['geometry', 'particle'], default='geometry')
    parser.add_argument('--mode', choices=['contracts', 'capture', 'timing'], default='contracts')
    parser.add_argument('--total', type=int, choices=[12, 24], default=12)
    parser.add_argument('--samples', type=int, choices=[1, 2, 3], default=2)
    parser.add_argument('--seconds', type=float, default=20)
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if not 0 < args.seconds <= 20:
        parser.error('seconds must be positive and <=20, including startup and preparation')
    if args.probe == 'particle' and args.mode == 'timing':
        parser.error('particle supports contracts/capture with fixed low-load CPU diagnostics')
    reference = args.reference or DEFAULT_ROOT / ('reference/scripts/presentation' if args.probe == 'geometry' else 'reference/void_spawn_player.gd')
    output = (args.output or DEFAULT_ROOT / ('safe-' + args.probe) / datetime.now().strftime('%Y%m%d-%H%M%S-%f')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    probe_output = output if args.probe == 'geometry' else output / 'probe'
    script = 'projectile_geometry_check.gd' if args.probe == 'geometry' else 'particle_birth_probe.gd'
    arguments = ['--reference=' + str(reference.resolve()), '--output=' + str(probe_output)]
    if args.probe == 'geometry':
        arguments += ['--mode=' + args.mode, '--total=' + str(args.total), '--samples=' + str(args.samples)]
    else:
        arguments += ['--counts=1,8', '--rounds=1', '--samples=2']
        if args.mode == 'capture': arguments += ['--render']
    command = [args.godot, *(['--headless'] if args.mode == 'contracts' else []), '--path', str(ROOT),
               '--rendering-method', 'gl_compatibility', '--log-file', str(output / 'godot.log'),
               '--script', 'tools/performance/' + script, '--', *arguments]
    components = [Path(__file__), ROOT / 'tools/performance/safe_probe_heartbeat.gd', ROOT / 'tools/performance' / script]
    if args.probe == 'geometry':
        components += [ROOT / 'scripts/presentation' / name for name in ['jinx_projectile_effect.gd', 'corki_projectile_effect.gd']]
        components += [ROOT / 'assets/effects' / name for name in ['jinx/rocket_geometry.gd', 'corki/missile_geometry.gd']]
        components += [reference / name for name in ['jinx_projectile_effect.gd', 'corki_projectile_effect.gd']]
    else:
        components += [ROOT / 'assets/effects/void_spawn/player.gd', reference]
    def component_identity():
        return {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in components}
    try:
        before = component_identity()
    except OSError as error:
        print('STOP before engine launch: ' + str(error))
        return 1
    report = run_guarded(command, output, limits=Limits(wall_seconds=args.seconds, startup_grace_seconds=min(6, args.seconds)))
    report['component_sha256_before'] = before
    try:
        report['component_sha256_after'] = component_identity()
        if before != report['component_sha256_after']:
            report.update(passed=False, reason='component_source_changed')
    except OSError as error:
        report.update(passed=False, reason='component_source_unreadable_after', error=str(error))
    if report['passed']:
        try:
            metrics = json.loads((probe_output / ('metrics.json' if args.probe == 'geometry' else 'result.json')).read_text())
            log = (output / 'engine.log').read_text(errors='replace')
            marker = '[PROJECTILE_GEOMETRY_RESULT]' if args.probe == 'geometry' else '[PARTICLE_BIRTH_RESULT]'
            report['passed'] = (not metrics['failures'] and (args.probe != 'geometry' or metrics['mode'] == args.mode)
                                and marker in log
                                and 'ERROR:' not in log and 'SCRIPT ERROR:' not in log)
            if not report['passed']: report['reason'] = 'invalid_or_failed_probe_result'
        except (OSError, ValueError, KeyError):
            report.update(passed=False, reason='missing_probe_result')
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(('PASS: ' if report['passed'] else 'STOP: ') + str(output / 'result.json'))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
