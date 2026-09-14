#!/usr/bin/env python3
"""Repeatable Mac/headless benchmark; archive measurements, not an automatic FPS claim."""
import argparse
from datetime import datetime
import importlib.util
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('verify', ROOT / 'tools/verify.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


def stop(process):
    if process is None or process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=['load', 'burst', 'match', 'effects'], default='load')
    parser.add_argument('--counts', default='32,64,128')
    parser.add_argument('--seconds', type=float, default=12)
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--record-audio', action='store_true', help='Record Master mix; excluded from comparison runs')
    parser.add_argument('--visual', choices=['on', 'off'], default='on')
    parser.add_argument('--audio', choices=['on', 'off'], default='on')
    parser.add_argument('--timeout', type=float, default=450)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    counts = [int(n) for n in args.counts.split(',')]
    if any(n <= 0 or n > 256 for n in counts) or args.seconds <= 0:
        parser.error('counts must be 1..256 and seconds positive')
    if args.case == 'burst' and args.seconds < 12:
        parser.error('burst requires at least 12 seconds')
    out = ROOT / 'ClashLegends-开发素材库/04-中间产物/构建与验证/performance' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    out.mkdir(parents=True)
    report = {'schema': 1, 'identity_before': verify.identity(ROOT), 'runs': [],
              'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
              'platform': platform.platform(), 'target': 'current Mac; 60 render FPS / 20 simulation Hz',
              'budgets_ms': {'render_frame': 1000/60, 'simulation_tick': 50}}
    for key in ['hw.memsize', 'machdep.cpu.brand_string']:
        report[key] = subprocess.check_output(['sysctl', '-n', key], text=True).strip()
    process = None
    try:
        for count in counts:
            folder = out / str(count)
            folder.mkdir()
            command = [args.godot, *([] if args.render else ['--headless']), '--path', str(ROOT),
                       '--script', 'tools/performance/benchmark.gd', '--', '--perf-case=' + args.case,
                       '--perf-count=' + str(count), '--perf-seconds=' + str(args.seconds),
                       '--perf-visual=' + args.visual, '--perf-audio=' + args.audio,
                       '--perf-output=' + str(folder), *(['--perf-record'] if args.record_audio else [])]
            started = time.monotonic()
            peak_rss_kib = 0
            with (folder / 'engine.log').open('w') as log:
                process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                while process.poll() is None:
                    if time.monotonic() - started > args.timeout:
                        stop(process)
                        raise RuntimeError('Benchmark timed out')
                    with (folder / 'engine.log').open('rb') as probe:
                        probe.seek(max(0, probe.seek(0, 2) - 16384))
                        if verify.ERROR_PATTERN.search(probe.read().decode(errors='replace')):
                            stop(process)
                            raise RuntimeError('Engine script error: ' + str(folder / 'engine.log'))
                    rss = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)], capture_output=True, text=True)
                    if rss.stdout.strip().isdigit(): peak_rss_kib = max(peak_rss_kib, int(rss.stdout.strip()))
                    time.sleep(0.25)
            text = (folder / 'engine.log').read_text(errors='replace')
            if process.returncode or verify.ERROR_PATTERN.search(text):
                raise RuntimeError('Engine failure: ' + str(folder / 'engine.log'))
            metrics = json.loads((folder / 'metrics.json').read_text())
            if not metrics.get('completed') or metrics.get('frame_ms', {}).get('samples', 0) <= 0:
                raise RuntimeError('Incomplete metrics: ' + str(folder))
            report['runs'].append({'command': command, 'seconds': time.monotonic() - started,
                                   'peak_rss_kib': peak_rss_kib, 'metrics': metrics, 'folder': str(folder)})
            print(f"[PERF] {args.case} n={count} tick_p99={metrics['tick_ms']['p99']:.2f}ms frame_p99={metrics['frame_ms']['p99']:.2f}ms peak_RSS={peak_rss_kib/1024:.0f}MiB", flush=True)
    except (OSError, RuntimeError, ValueError, KeyboardInterrupt) as exc:
        stop(process)
        report['error'] = str(exc)
    report['identity_after'] = verify.identity(ROOT)
    report['valid'] = 'error' not in report and report['identity_before']['content_sha256'] == report['identity_after']['content_sha256']
    (out / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(str(out / 'result.json'), flush=True)
    return 0 if report['valid'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
