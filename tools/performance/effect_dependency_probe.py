"""Pair large effect dependency parsing, retaining the full original player data."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import verify
from lib.tool_paths import godot as find_godot
from safe_probe import Limits, run_guarded


def run(godot, folder, arguments, timeout, render=False):
    folder.mkdir(parents=True, exist_ok=False)
    command = [godot, '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
               '--path', str(ROOT), '--log-file', str(folder / 'godot.log'),
               '--script', 'tools/performance/effect_dependency_probe.gd', '--',
               '--output=' + str(folder), *arguments]
    if not render:
        command.insert(1, '--headless')
    guard = run_guarded(command, folder, limits=Limits(wall_seconds=min(timeout, 20), startup_grace_seconds=min(timeout, 6)))
    log_path = folder / 'engine.log'
    log = log_path.read_text(errors='replace') if log_path.is_file() else ''
    metrics_path = folder / 'metrics.json'
    metrics = json.loads(metrics_path.read_text()) if metrics_path.is_file() else {}
    passed = guard.get('passed') is True and not verify.ERROR_PATTERN.search(log) and metrics.get('passed') is True
    result = {'command': command, 'guard': guard, 'metrics': metrics, 'passed': passed}
    (folder / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=find_godot())
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rounds', type=int, default=1)
    parser.add_argument('--samples', type=int, default=1)
    parser.add_argument('--timeout', type=float, default=20)
    parser.add_argument('--phase', choices=['all', 'paired', 'cold'], default='paired')
    parser.add_argument('--kind', choices=['typical', 'pressure', 'all'], default='typical')
    parser.add_argument('--render', action='store_true', help='Opt in to guarded Compatibility; default is guarded headless CPU only.')
    args = parser.parse_args()
    if not 1 <= args.rounds <= 3 or not 1 <= args.samples <= 3:
        parser.error('Diagnostic rounds/samples must each be in 1..3.')
    if not 0 < args.timeout <= 20:
        parser.error('Timeout must be greater than zero and at most 20 seconds.')
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    reference = ROOT / 'ClashLegends-开发素材库/04-中间产物/architecture_refactor/batch2b/reference/scripts/presentation/effect_resource_manifest.gd'
    report = {'identity_before': verify.identity(ROOT), 'reference_sha256': hashlib.sha256(reference.read_bytes()).hexdigest(),
              'engine': None, 'steps': []}
    def record(folder, arguments):
        step = run(args.godot, folder, arguments, args.timeout, args.render)
        report['steps'].append(step)
        if not step['passed']:
            raise ValueError('Probe stopped or failed: ' + str(step['guard'].get('reason')))
    try:
        report['engine'] = subprocess.check_output([args.godot, '--version'], text=True, timeout=2).strip()
        if report['engine'] != (ROOT / 'godot-version.txt').read_text().strip():
            raise ValueError('Godot version mismatch')
        if args.phase in ['all', 'paired']:
            record(out / 'paired', ['--phase=paired', '--kind=' + args.kind, '--rounds=' + str(args.rounds), '--samples=' + str(args.samples)])
        if args.phase in ['all', 'cold']:
            for kind in (['typical', 'pressure'] if args.kind == 'all' else [args.kind]):
                for side in ['old', 'current']:
                    record(out / f'cold-{kind}-{side}', ['--phase=cold', '--kind=' + kind, '--side=' + side])
            cold = [step['metrics']['results'][0] for step in report['steps'] if step['metrics'].get('phase') == 'cold']
            for index in range(0, len(cold), 2):
                old, current = cold[index:index + 2]
                if old['resource_count'] != current['resource_count'] or old['resource_paths_sha256'] != current['resource_paths_sha256']:
                    raise ValueError('Cold preparation resource closure mismatch')
    except Exception as error:
        report['error'] = str(error)
    report['identity_after'] = verify.identity(ROOT)
    report['passed'] = not report.get('error') and all(step['passed'] for step in report['steps']) and bool(report['steps']) and report['identity_before']['content_sha256'] == report['identity_after']['content_sha256']
    (out / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {out / 'result.json'}")
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
