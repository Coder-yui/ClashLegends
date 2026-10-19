"""Resource-build process boundaries; same safe_probe limits, never relax guards."""
from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/performance'))
from safe_probe import Limits, run_guarded, group_rss_bytes
from match_loading import memory_state, budget, command


@contextmanager
def atomic_output(path, *, binary=False):
    """A single same-directory replace, not an all-artifact transaction."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='wb' if binary else 'w', dir=path.parent,
                                         prefix='.' + path.name + '.tmp-', delete=False,
                                         **({} if binary else {'encoding': 'utf-8'})) as stream:
            temporary = Path(stream.name)
            yield stream
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists(): temporary.unlink()


def atomic_json(path, value):
    with atomic_output(path) as stream:
        json.dump(value, stream, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)
        stream.write('\n')


def atomic_bytes(path, value):
    with atomic_output(path, binary=True) as stream: stream.write(value)


def atomic_copy(source, destination):
    with Path(source).open('rb') as source_stream, atomic_output(destination, binary=True) as target:
        while chunk := source_stream.read(1024 * 1024): target.write(chunk)


def process_rss(pid):
    value = command('/bin/ps', '-o', 'rss=', '-p', str(pid)).strip()
    if not value.isdecimal(): raise ValueError('Unreadable process RSS')
    return int(value) * 1024


def observation(phase):
    value = {'phase': phase, 'utc': datetime.now(timezone.utc).isoformat(),
             'monotonic': time.monotonic(), 'pid': os.getpid()}
    errors = {}
    for name, read in [('memory', memory_state), ('parent_rss_bytes', lambda: process_rss(os.getpid()))]:
        try: value[name] = read()
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            value[name] = None
            errors[name] = str(error)
    if errors: value['observation_errors'] = errors
    return value


def guarded_process(arguments, folder, *, phase, preflight=None):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    state = observation(phase + ':before-launch')
    state.update(command=arguments, child_started=False, thresholds={
        'startup_pressure_level': 1, 'startup_available_bytes': 8 * 1024**3,
        'runtime_pressure_level': 1, 'runtime_available_bytes': 4 * 1024**3})
    # Persist actual readings BEFORE budget/version/process checks can reject.
    atomic_json(folder / 'preflight.json', state)
    try:
        if state.get('observation_errors'): raise RuntimeError('Protection observation unavailable')
        budget(state['memory'])
        engines = [line for line in command('/bin/ps', '-axo', 'pid=,comm=,args=').splitlines()
                   if re.match(r'^\s*\d+\s+.*?/godot[^/\s]*\s', line, re.I)]
        state['existing_engines'] = engines
        atomic_json(folder / 'preflight.json', state)
        if any(' --editor' not in line for line in engines): raise RuntimeError('Existing non-editor Godot; phase not started')
        if preflight is not None: state.update(preflight())
        atomic_json(folder / 'preflight.json', state)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        atomic_json(folder / 'rejection.json', {'reason': str(error), 'observation': state, 'child_started': False})
        raise
    health = []
    last_system = [state]
    last_refresh = [0.0]
    def monitored(pgid):
        now = time.monotonic()
        if now - last_refresh[0] >= 1:
            last_system[0] = observation(phase + ':runtime')
            last_refresh[0] = now
            health.append(last_system[0])
            atomic_json(folder / 'health.json', {'samples': health})
        rss = group_rss_bytes(pgid)
        rss_observation = {'utc': datetime.now(timezone.utc).isoformat(),
                    'monotonic': now, 'process_group': pgid, 'group_rss_bytes': rss,
                    'system_observation': last_system[0]}
        atomic_json(folder / 'last-rss.json', rss_observation)
        current = last_system[0]
        if current.get('observation_errors'): raise ValueError('System observation unavailable')
        if current['memory']['pressure_level'] != 1 or current['memory']['available_estimate_bytes'] < 4 * 1024**3:
            atomic_json(folder / 'rejection.json', {'reason': 'System pressure/headroom stop',
                        'observation': current, 'rss_observation': rss_observation, 'process_group': pgid})
            raise ValueError('System pressure/headroom stop')
        return rss
    try:
        result = run_guarded(arguments, folder, limits=Limits(), rss_reader=monitored)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        atomic_json(folder / 'rejection.json', {'reason': str(error), 'last_system_observation': last_system[0]})
        raise
    atomic_json(folder / 'guard.json', {'guard': result, 'health': health})
    if not result['passed']:
        if not (folder / 'rejection.json').exists():
            atomic_json(folder / 'rejection.json', {'reason': result['reason'], 'guard': result,
                        'last_system_observation': last_system[0],
                        'rss_observation': json.loads((folder / 'last-rss.json').read_text()) if (folder / 'last-rss.json').exists() else None})
        raise RuntimeError('Protected resource phase failed: ' + str(folder))
    if not result.get('cleanup', {}).get('confirmed'):
        atomic_json(folder / 'rejection.json', {'reason': 'Resource phase cleanup unconfirmed',
                    'guard': result, 'last_system_observation': last_system[0]})
        raise RuntimeError('Resource phase cleanup unconfirmed: ' + str(folder))
    return result


class MainThreadPulse:
    """Worker progress only; no timer thread masking blocked parsing/processing."""
    def __init__(self):
        self.path = Path(os.environ['CLASH_SAFE_PROBE_HEARTBEAT'])
        self.token = os.environ['CLASH_SAFE_PROBE_TOKEN']
        if not os.environ.get('CLASH_SAFE_PROBE_PARENT_PID'): raise ValueError('Worker requires supervisor')
        self.sequence = 0
        self.last = -1.0
        self.phase = None
        self.update('offline:starting', force=True)

    def update(self, phase, *, ready=False, force=False):
        now = time.monotonic()
        if not force and not ready and phase == self.phase and now - self.last < 0.2: return
        self.last = now
        self.phase = phase
        self.sequence += 1
        atomic_json(self.path, {'token': self.token, 'pid': os.getpid(), 'sequence': self.sequence,
                    'ready': ready, 'phase': phase})
