#!/usr/bin/env python3
"""Build and smoke-test the pinned, ad-hoc signed universal Mac application."""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('verify', ROOT / 'tools/verify.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    output = ROOT / 'builds/macos' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    output.mkdir(parents=True)
    app = output / 'Clash Legends.app'
    report = {'schema': 1, 'identity_before': verify.identity(ROOT), 'steps': [],
              'target': 'current M5 Mac tested / universal binary / local testing / ad-hoc signing', 'app': str(app)}
    try:
        engine = subprocess.check_output([args.godot, '--version'], text=True, timeout=15).strip()
        report['engine'] = engine
        if engine != (ROOT / 'godot-version.txt').read_text().strip():
            raise RuntimeError('Engine does not match godot-version.txt')
        template_dir = Path.home() / 'Library/Application Support/Godot/export_templates/4.7.1.stable'
        if (template_dir / 'version.txt').read_text().strip() != '4.7.1.stable':
            raise RuntimeError('Export template version mismatch')
        report['template_sha256'] = sha256(template_dir / 'macos.zip')
        steps = [
            ('import', [args.godot, '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'], 600),
            ('export', [args.godot, '--headless', '--path', str(ROOT), '--export-release', 'macOS Local', str(app)], 600),
        ]
        for name, command, timeout in steps:
            step = verify.run_step(name, command, output, timeout)
            report['steps'].append(step)
            if not step['passed']: raise RuntimeError(name + ' failed')
        executables = list((app / 'Contents/MacOS').iterdir())
        if len(executables) != 1: raise RuntimeError('Expected exactly one app executable')
        executable = executables[0]
        for name, command, timeout in [
            ('codesign', ['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], 60),
            ('menu-smoke', [str(executable), '--headless', '--', '--release-smoke=menu'], 90),
            ('match-smoke', [str(executable), '--headless', '--', '--release-smoke=match'], 90),
        ]:
            step = verify.run_step(name, command, output, timeout)
            report['steps'].append(step)
            if not step['passed']: raise RuntimeError(name + ' failed')
            if name.endswith('-smoke'):
                markers = [line.removeprefix('[RELEASE_SMOKE] ') for line in Path(step['log']).read_text().splitlines() if line.startswith('[RELEASE_SMOKE] ')]
                if len(markers) != 1:
                    raise RuntimeError('Missing release smoke result')
                result = json.loads(markers[0])
                if result.get('passed') is not True or result.get('exported') is not True or result.get('case') != name.removesuffix('-smoke'):
                    raise RuntimeError('Invalid release smoke result')
                step['result'] = result
        report['artifacts'] = {str(p.relative_to(app)): {'bytes': p.stat().st_size, 'sha256': sha256(p)}
                               for p in sorted(app.rglob('*')) if p.is_file()}
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        report['error'] = str(exc)
    report['identity_after'] = verify.identity(ROOT)
    report['passed'] = 'error' not in report and len(report['steps']) == 5 and report['identity_before']['content_sha256'] == report['identity_after']['content_sha256']
    (output / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(('PASS: ' if report['passed'] else 'FAIL: ') + str(output / 'result.json'))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
