#!/usr/bin/env python3
"""One real match startup, with a machine-derived budget; never a stress loop."""
from dataclasses import dataclass
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import time
try:
    from .safe_probe import Limits, MIB, ROOT, group_rss_bytes, run_guarded
except ImportError:  # Direct CLI invocation.
    from safe_probe import Limits, MIB, ROOT, group_rss_bytes, run_guarded

GIB = 1024 * MIB

@dataclass(frozen=True)
class MatchLimits(Limits):
    """Separate policy: does not relax the legacy geometry/particle probe limits."""
    wall_seconds: float = 60.0
    rss_bytes: int = 3 * GIB
    rss_growth_bytes: int = 256 * MIB
    poll_seconds: float = 0.25

    def __post_init__(self):
        bounds = dict(wall_seconds=60, startup_grace_seconds=6, heartbeat_seconds=2,
                      rss_bytes=3 * GIB, rss_growth_bytes=256 * MIB,
                      poll_seconds=0.25, terminate_grace_seconds=0.5)
        for key, maximum in bounds.items():
            if not 0 < getattr(self, key) <= maximum:
                raise ValueError(key + ' outside match startup policy')


def command(*args, timeout=2):
    return subprocess.run(args, text=True, errors='replace', capture_output=True, check=True, timeout=timeout).stdout


def memory_state(*, read=None):
    read = read or command
    physical = int(read('/usr/sbin/sysctl', '-n', 'hw.memsize').strip())
    pressure = int(read('/usr/sbin/sysctl', '-n', 'kern.memorystatus_vm_pressure_level').strip())
    query = read('/usr/bin/memory_pressure', '-Q')
    match = re.search(r'free percentage: (\d+)%', query)
    if match is None:
        raise ValueError('Unreadable system memory availability')
    percent = int(match[1])
    if physical <= 0 or not 0 <= percent <= 100:
        raise ValueError('Invalid system memory reading')
    return dict(physical_bytes=physical, pressure_level=pressure, available_percent=percent,
                available_estimate_bytes=physical * percent // 100)


def budget(state):
    # At least 6 GiB of currently available capacity stays outside the child budget.
    if state['pressure_level'] != 1 or state['available_estimate_bytes'] < 8 * GIB:
        raise RuntimeError('Insufficient normal-pressure system headroom before launch')
    return min(3 * GIB, state['available_estimate_bytes'] - 6 * GIB)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--profile', choices=['representative', 'heavy', 'summon', 'diverse'], default='representative')
    parser.add_argument('--inventory', action='store_true', help='Collect definitions only; no models, audio or GPU draw')
    parser.add_argument('--diagnostic', action='store_true', help='One A-only observation, at most 20s; never a completed loading baseline')
    parser.add_argument('--observe', action='store_true', help='Formal one-profile loading with A-equivalent observation and the original 60s limit')
    args = parser.parse_args()
    if args.observe and (args.inventory or args.diagnostic or args.profile == 'representative'):
        parser.error('observe requires one fixed profile and cannot combine with inventory/diagnostic')
    if args.diagnostic and (args.profile != 'heavy' or args.inventory):
        parser.error('diagnostic requires --profile heavy and cannot be inventory')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    state = memory_state()
    processes = command('/bin/ps', '-axo', 'pid=,pgid=,rss=,comm=')
    engine_args = [line for line in command('/bin/ps', '-axo', 'pid=,comm=,args=').splitlines() if re.match(r'^\s*\d+\s+.*?/godot[^/\s]*\s', line, re.IGNORECASE)]
    if any(' --editor' not in line for line in engine_args):
        raise RuntimeError('Existing Godot process: no second instance launched')
    cap = budget(state)
    (output / 'preflight.json').write_text(json.dumps(dict(memory=state, rss_budget_bytes=cap,
        reserve_bytes=6 * GIB, rationale='One standard match; cap <=3GiB, initial available minus 6GiB; pressure level 1 only; stop below 4GiB available. RSS excludes GPU allocations.',
        existing_engine_args=engine_args, processes="\n".join(sorted(processes.splitlines(), key=lambda row: -int(row.split()[2]))[:20])), indent=2))
    health = [0.0]
    health_samples = []
    def monitored_rss(pgid):
        if time.monotonic() - health[0] >= 1:
            current = memory_state()
            health_samples.append(current)
            health[0] = time.monotonic()
            if current['pressure_level'] != 1 or current['available_estimate_bytes'] < 4 * GIB:
                raise ValueError('System memory pressure/headroom stop')
        return group_rss_bytes(pgid)
    inputs = [ROOT / name for name in ('scripts/main.gd', 'scripts/presentation/match_model_pool.gd',
              'scripts/presentation/spell_effect_warmup.gd', 'tools/performance/match_loading.gd',
              'tools/performance/match_loading.py', 'tools/performance/safe_probe.py',
              'tools/performance/match_loading_plan.gd', 'tools/performance/match_resource_audit.gd',
              'scripts/presentation/compact_particle_samples.gd', 'assets/effects/void_summoning/player.gd',
              'assets/effects/void_summoning/sampled.clps', 'assets/units/aatrox/aatrox_view.gd',
              'scripts/ui/card_art.gd')]
    def identity():
        return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs}
    def workspace_identity():
        paths = subprocess.check_output(['git', 'ls-files', '-z', '-c', '-o', '--exclude-standard'], cwd=ROOT).split(b'\0')
        return {name.decode(): hashlib.file_digest((ROOT / name.decode()).open('rb'), 'sha256').hexdigest()
                for name in sorted(set(paths)) if name and (ROOT / name.decode()).is_file()}
    full_before = workspace_identity()
    (output / 'workspace-before.json').write_text(json.dumps(full_before, indent=2))
    (output / 'measurement-tool.diff').write_text(command('git', 'diff', '--', 'tools/performance/match_loading.py', 'tools/performance/match_loading.gd', 'tools/performance/match_loading_plan.gd'))
    before = identity()
    argv = ['/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(ROOT),
            '--rendering-method', 'gl_compatibility', '--log-file', str(output / 'godot.log'),
            '--script', ('tools/performance/match_loading_plan.gd' if args.inventory else 'tools/performance/match_loading.gd'), '--', '--output=' + str(output), '--profile=' + args.profile]
    if args.inventory: argv.insert(1, '--headless')
    if args.diagnostic: argv.append('--diagnostic')
    if args.observe: argv.append('--observe')
    report = run_guarded(argv, output, limits=MatchLimits(rss_bytes=cap, wall_seconds=20 if args.diagnostic else 60), rss_reader=monitored_rss, max_fps=60)
    full_after = workspace_identity()
    (output / 'workspace-after.json').write_text(json.dumps(full_after, indent=2))
    report['workspace_unchanged'] = full_before == full_after
    report['production_commit'] = command('git', 'rev-parse', 'HEAD').strip()
    if full_before != full_after: report.update(passed=False, reason='workspace_changed')
    report['memory_samples'] = health_samples
    report['component_sha256_before'] = before
    report['component_sha256_after'] = identity()
    if before != report['component_sha256_after']:
        report.update(passed=False, reason='measured_component_changed')
    if args.diagnostic:
        report['diagnostic_mode'] = True
        report['loading_completed'] = bool(report.get('ready_seen') and (output / 'loading.json').exists())
        diagnostic_file = output / 'diagnostic-result.json'
        if diagnostic_file.exists(): report['diagnostic_observation'] = json.loads(diagnostic_file.read_text())
    if report['passed'] and not args.inventory and not args.diagnostic:
        try:
            data = json.loads((output / 'loading.json').read_text())
            log = (output / 'engine.log').read_text()
            if (data['errors'] or 'ERROR:' in log or '[MATCH_LOADING_RESULT]' not in log
                    or data['main']['threaded_requests'] <= 0 or data['effect_draws'] <= 0):
                report.update(passed=False, reason='invalid_match_result')
        except (OSError, ValueError, KeyError) as error:
            report.update(passed=False, reason='missing_match_result', error=str(error))
    (output / 'result.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
