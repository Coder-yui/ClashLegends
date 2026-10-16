#!/usr/bin/env python3
"""Paired CPU measurements of removed repeated work; never a rendered FPS result."""
import argparse
from datetime import datetime
import hashlib
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
DEFAULT_REFERENCE = ROOT / 'ClashLegends-开发素材库/04-中间产物/architecture_refactor/batch2a/reference'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--reference', type=Path, default=DEFAULT_REFERENCE)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--counts', default='32,64,128')
    parser.add_argument('--rounds', type=int, default=5)
    parser.add_argument('--samples', type=int, default=20)
    parser.add_argument('--timeout', type=float, default=240)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--network-trace', choices=['normal', 'impaired'], help='Capture real three-process playback operations; replay separately for queue memory')
    modes.add_argument('--replay-trace', type=Path, help='Replay one captured client .bin with independent old/new queues')
    args = parser.parse_args()
    try:
        counts = [int(value) for value in args.counts.split(',')]
    except ValueError:
        parser.error('counts must be comma-separated integers')
    if not counts or any(value < 1 or value > 256 for value in counts) or args.rounds < 1 or args.samples < 1 or args.timeout <= 0:
        parser.error('counts must be 1..256; rounds, samples and timeout must be positive')
    reference = args.reference.resolve()
    files = ['network_snapshot_system.gd', 'network_playback.gd', 'match_card_growth.gd', 'active_skill_roster.gd', 'main.gd']
    if not args.network_trace and any(not (reference / name).is_file() for name in files):
        parser.error('reference must contain all five archived source files')
    trace = args.replay_trace.resolve() if args.replay_trace else None
    if trace and not trace.is_file():
        parser.error('replay trace does not exist')
    output = (args.output or DEFAULT_REFERENCE.parent / 'repeated-work' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    engine = subprocess.check_output([args.godot, '--version'], text=True, timeout=15).strip()
    if engine != (ROOT / 'godot-version.txt').read_text().strip():
        parser.error('Godot version differs from project declaration')
    command = [args.godot, '--headless', '--log-file', str(output / 'godot.log'), '--path', str(ROOT),
               '--script', 'tools/performance/repeated_work.gd', '--', '--counts=' + args.counts,
               '--rounds=' + str(args.rounds), '--samples=' + str(args.samples),
               '--reference=' + str(reference), '--output=' + str(output)]
    if trace:
        command.append('--replay-trace=' + str(trace))
    report = {'schema': 1, 'engine': engine, 'platform': platform.platform(),
              'identity_before': verify.identity(ROOT), 'command': command,
              'reference': str(reference), 'reference_sha256': {name: hashlib.sha256((reference / name).read_bytes()).hexdigest() for name in files if (reference / name).is_file()},
              'note': 'CPU microbenchmarks, not simulation frames or FPS. RSS peak includes deliberate decoded-queue stress.'}
    if trace:
        report['replay_trace'] = str(trace)
        report['replay_trace_sha256'] = hashlib.sha256(trace.read_bytes()).hexdigest()
    for key in ['hw.memsize', 'machdep.cpu.brand_string']:
        report[key] = subprocess.check_output(['sysctl', '-n', key], text=True).strip()
    started = time.monotonic()
    process = None
    peak_rss = 0
    try:
        if args.network_trace:
            trace_dir = output / 'queue-trace'
            previous = os.environ.get('CLASH_QUEUE_TRACE_DIR')
            try:
                os.environ['CLASH_QUEUE_TRACE_DIR'] = str(trace_dir)
                network = verify.run_network(args.godot, output, args.timeout,
                                             scenario='impaired' if args.network_trace == 'impaired' else '')
            finally:
                if previous is None:
                    os.environ.pop('CLASH_QUEUE_TRACE_DIR', None)
                else:
                    os.environ['CLASH_QUEUE_TRACE_DIR'] = previous
            report['command'] = network['commands']
            report['network_trace'] = args.network_trace
            report['network'] = network
            report['queue_traces'] = []
            for team in [0, 1]:
                path = trace_dir / f'client{team}.bin'
                summary = json.loads(Path(str(path) + '.json').read_text())
                if summary['context']['team'] != team or summary['context']['game_over'] is not True or summary['summary']['queue_rejected'] != 0 or summary['summary']['packet_count'] < 1:
                    raise RuntimeError('incomplete, rejected, or failed queue trace')
                report['queue_traces'].append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), **summary})
            if not network['passed']:
                raise RuntimeError('three-process network trace failed; see peer logs')
            report['note'] = 'Real adaptive playback trace. Event-weighted occupancy; probe stores compressed inputs and events. Use isolated replay for memory; capture RSS is not a queue-memory result.'
        else:
            with (output / 'engine.log').open('w') as log:
                process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                while process.poll() is None:
                    if time.monotonic() - started > args.timeout:
                        raise RuntimeError('measurement timed out')
                    text = (output / 'engine.log').read_text(errors='replace')
                    if verify.ERROR_PATTERN.search(text):
                        raise RuntimeError('engine error; see engine.log')
                    rss = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)], capture_output=True, text=True)
                    if rss.stdout.strip().isdigit():
                        peak_rss = max(peak_rss, int(rss.stdout.strip()))
                    time.sleep(0.1)
            text = (output / 'engine.log').read_text(errors='replace')
            if process.returncode or verify.ERROR_PATTERN.search(text):
                raise RuntimeError('engine failed; see engine.log')
            metrics = json.loads((output / 'metrics.json').read_text())
            expected_results = 1 if trace else len(counts)
            if metrics.get('failures') or len(metrics.get('results', [])) != expected_results or text.count('[REPEATED_WORK_RESULT] ') != 1:
                raise RuntimeError('incomplete or failed measurements')
            report['metrics'] = metrics
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, KeyboardInterrupt) as error:
        report['error'] = str(error)
    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
    report['seconds'] = time.monotonic() - started
    report['peak_rss_kib'] = None if args.network_trace else peak_rss
    report['identity_after'] = verify.identity(ROOT)
    report['valid'] = 'error' not in report and report['identity_before']['content_sha256'] == report['identity_after']['content_sha256']
    (output / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(('PASS: ' if report['valid'] else 'FAIL: ') + str(output / 'result.json'))
    return 0 if report['valid'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
