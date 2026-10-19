#!/usr/bin/env python3
"""One fixed provider, supervised contracts OR one real-render comparison. No retry/batch."""
from datetime import datetime
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import time
from safe_probe import ROOT, Limits, run_guarded, group_rss_bytes
from match_loading import memory_state, budget, command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--family', choices=['sand', 'beam', 'sampled'], default='sand')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = args.output or ROOT / 'ClashLegends-开发素材库/04-中间产物/构建与验证/effect-coverage' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(ROOT / 'tools'))
    from lib.tool_paths import godot
    version = command(godot(), '--version').strip()
    if version != (ROOT / 'godot-version.txt').read_text().strip():
        raise ValueError('Godot version mismatch')
    state = memory_state()
    budget(state)  # Same normal pressure / >=8GiB startup headroom, no expanded limits.
    engines = [line for line in command('/bin/ps', '-axo', 'pid=,comm=,args=').splitlines()
               if re.match(r'^\s*\d+\s+.*?/godot[^/\s]*\s', line, re.I)]
    if any(' --editor' not in line for line in engines):
        raise RuntimeError('Existing non-editor Godot: no engine started')
    (output / 'preflight.json').write_text(json.dumps(dict(memory=state, existing_engines=engines), indent=2))
    paths = command('git', 'ls-files', '-z', '-c', '-o', '--exclude-standard').split('\0')
    def identity():
        return {p: hashlib.file_digest((ROOT / p).open('rb'), 'sha256').hexdigest()
                for p in sorted(set(paths)) if p and (ROOT / p).is_file()}
    before = identity()
    (output / 'workspace-before.json').write_text(json.dumps(before, indent=2))
    health = [0.0]
    samples = []
    def monitored(pgid):
        if time.monotonic() - health[0] >= 1:
            current = memory_state(); samples.append(current); health[0] = time.monotonic()
            if current['pressure_level'] != 1 or current['available_estimate_bytes'] < 4 * 1024**3:
                raise ValueError('System pressure/headroom stop')
        return group_rss_bytes(pgid)
    result = run_guarded([godot(), *([] if args.render else ['--headless']), '--audio-driver', 'Dummy',
                          '--path', str(ROOT), '--rendering-method', 'gl_compatibility',
                          '--script', ({'beam': 'tools/performance/beam_coverage_probe.gd', 'sampled': 'tools/performance/sampled_coverage_probe.gd'}.get(args.family, 'tools/performance/effect_coverage_probe.gd')), '--',
                          '--output=' + str(output), *(['--targeted'] if args.render and args.family == 'sampled' else []), *([] if args.render else ['--contracts'])],
                         output, limits=Limits(), rss_reader=monitored)
    after = identity()
    (output / 'workspace-after.json').write_text(json.dumps(after, indent=2))
    log = (output / 'engine.log').read_text(errors='replace') if (output / 'engine.log').exists() else ''
    if before != after or re.search(r'(SCRIPT ERROR:|ERROR:)', log):
        result.update(passed=False, validation_error='source changed or engine error; inspect log')
    if result['passed']:
        measured = json.loads((output / 'result.json').read_text())
        result['passed'] = measured['passed']
    (output / 'guard.json').write_text(json.dumps(dict(guard=result, health=samples), indent=2))
    print(json.dumps(dict(passed=result['passed'], reason=result['reason'], output=str(output)), ensure_ascii=False))
    return int(not result['passed'])


if __name__ == '__main__':
    raise SystemExit(main())
