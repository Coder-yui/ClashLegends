"""Explicit Mac-only policy for reviewed small logic and injected boundary suites.

LightweightContractSuite: no UI/models/prewarm/ports; only three ~367 KiB total
imported Yorick clips for headless player properties, never a heavy suite.
StartupNetworkBoundary selects only state injection in the same script: no resources
loaded, no ports, no scene reload, and no full-batch execution.
WorldOwnershipSuite, RuntimeOwnershipSuite and UnitMutationSuite use authority_battle without assets, UI, models, audio or ports.
"""
from dataclasses import asdict, dataclass
import json
import os
import shlex
import shutil
import subprocess
import sys
import time

MIB = 1024 * 1024
GIB = 1024 * MIB
PROFILE = 'authority-logic'
AUTHORITY_SUITES = frozenset({'GrowthSpatialSuite', 'StructureRewardSuite', 'AuthorityTimingSuite', 'LightweightContractSuite', 'StartupNetworkBoundary', 'WorldOwnershipSuite', 'RuntimeOwnershipSuite', 'UnitMutationSuite', 'StrictContractSuite'})
RESERVE = 2 * GIB
MIN_RSS_BUDGET = 512 * MIB
MAX_RSS_BUDGET = 768 * MIB
MAX_SECONDS = 20.0
SAMPLE_SECONDS = 0.2


def sample_memory(*, read=None, clock=time.monotonic):
    from performance.match_loading import command, memory_state
    read = read or command
    deadline = clock() + SAMPLE_SECONDS

    def limited(*args):
        remaining = deadline - clock()
        if remaining <= 0: raise ValueError('Memory sample common deadline exceeded')
        value = read(*args, timeout=remaining)
        if clock() >= deadline: raise ValueError('Memory sample common deadline exceeded')
        return value

    return memory_state(read=limited)


def existing_engines(rows, selected):
    """Read-only argv/canonical-path identity checks; never signal these processes."""
    selected = shutil.which(selected) or selected
    paths = {selected, os.path.realpath(selected)}
    found = []
    for row in rows.splitlines():
        fields = row.strip().split(None, 1)
        if len(fields) != 2 or not fields[0].isdigit(): raise ValueError('Unreadable process identity row')
        pid, argv = fields
        executable = next((p for p in sorted(paths, key=len, reverse=True) if argv == p or argv.startswith(p + ' ')), None)
        if executable is None:
            executable = shlex.split(argv)[0] if argv.startswith(('"', "'")) else argv.split(None, 1)[0]
        canonical = os.path.realpath(shutil.which(executable) or executable)
        if canonical not in paths and os.path.basename(executable).lower() not in {'godot', 'godot4'}: continue
        tail = argv[len(executable):] if argv.startswith(executable) else ' '.join(shlex.split(argv)[1:])
        options = shlex.split(tail)
        if '--' in options: options = options[:options.index('--')]
        editor = bool({'--editor', '-e'} & set(options))
        found.append(dict(pid=int(pid), executable=executable, canonical=canonical, editor=editor))
    return found


@dataclass(frozen=True)
class LogicLimits:
    wall_seconds: float
    rss_bytes: int
    startup_grace_seconds: float = 6.0
    heartbeat_seconds: float = 2.0
    poll_seconds: float = 0.1
    terminate_grace_seconds: float = 0.5

    @property
    def rss_growth_bytes(self):
        # The absolute logic cap is sufficient; no extra ready+256MiB restriction.
        return self.rss_bytes


def logic_budget(state):
    available = state['available_estimate_bytes']
    physical = state['physical_bytes']
    if physical <= 0 or not 0 <= available <= physical:
        raise ValueError('Invalid physical/available memory reading')
    if state['pressure_level'] != 1 or available < RESERVE + MIN_RSS_BUDGET:
        raise ValueError('Authority logic needs normal pressure and >=2.5GiB available (2GiB reserve + 512MiB child)')
    return min(MAX_RSS_BUDGET, available - RESERVE)


def policy(profile, timeout):
    if profile != PROFILE:
        raise ValueError('Unsupported protected profile: ' + str(profile))
    if not 0 < timeout <= MAX_SECONDS:
        raise ValueError('authority-logic timeout must be explicit within (0, 20] seconds')
    return dict(profile=profile, platform='darwin', wall_seconds=timeout,
                minimum_available_bytes=RESERVE + MIN_RSS_BUDGET, reserve_bytes=RESERVE,
                max_rss_bytes=MAX_RSS_BUDGET, runtime_available_floor_bytes=RESERVE,
                rss_growth_policy='absolute RSS cap only; no separate ready growth cap')


def run_engine(command_line, output, timeout, *, profile, heartbeat,
               state_reader=None, rss_reader=None, process_reader=None, platform_name=None):
    output.mkdir(parents=True, exist_ok=True)
    try:
        selected = policy(profile, timeout)
        if (platform_name or sys.platform) != 'darwin':
            raise ValueError('authority-logic supervision supports macOS only; protected run refused')
        # Lazy imports keep ordinary cross-platform verify independent of Mac/fcntl.
        from performance.match_loading import command
        from performance.safe_probe import group_rss_bytes, run_guarded
        state_reader = state_reader or sample_memory
        rss_reader = rss_reader or group_rss_bytes
        process_reader = process_reader or (lambda *args: command(*args, timeout=SAMPLE_SECONDS))
        state = state_reader()
        cap = logic_budget(state)
        engines = existing_engines(process_reader('/bin/ps', '-ww', '-axo', 'pid=,args='), command_line[0])
        if any(not engine['editor'] for engine in engines):
            raise ValueError('Existing non-editor Godot process; no second engine launched')
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        report = dict(passed=False, reason='verification_preflight_failed', error=str(error), pid=None)
        (output / 'watchdog.json').write_text(json.dumps(report, indent=2))
        return report
    samples = [state]
    last = [0.0]

    def monitored_rss(pgid):
        if time.monotonic() - last[0] >= 1.0:
            current = state_reader()
            samples.append(current)
            last[0] = time.monotonic()
            if current['pressure_level'] != 1 or current['available_estimate_bytes'] < RESERVE:
                raise ValueError('System memory pressure/headroom stop')
        return rss_reader(pgid)

    limits = LogicLimits(wall_seconds=timeout, startup_grace_seconds=min(timeout, 6), rss_bytes=cap)
    report = run_guarded(command_line, output, limits=limits,
                         rss_reader=monitored_rss, require_heartbeat=heartbeat)
    report.update(memory_samples=samples, existing_engines=engines, policy=selected)
    # safe_probe serializes dataclass fields; expose the computed property as well.
    report['limits'] = dict(asdict(limits), rss_growth_bytes=limits.rss_growth_bytes)
    (output / 'watchdog.json').write_text(json.dumps(report, indent=2))
    return report
