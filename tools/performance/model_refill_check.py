"""One guarded small model-pool lifecycle; no whole-match loading or stress loop."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from verification_guard import sample_memory, existing_engines
from performance.match_loading import budget, command, GIB
from performance.safe_probe import Limits, group_rss_bytes, run_guarded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = dict(passed=False, reason='preflight_failed', pid=None)
    try:
        state = sample_memory()
        # Preserve >=8GiB initial / 6GiB reserve policy; stricter small-child cap.
        cap = min(768 * 1024 * 1024, budget(state))
        engine = '/Applications/Godot.app/Contents/MacOS/Godot'
        engines = existing_engines(command('/bin/ps', '-ww', '-axo', 'pid=,args=', timeout=0.2), engine)
        if any(not item['editor'] for item in engines):
            raise ValueError('Existing non-editor Godot: no engine launched')
        files = ['scripts/presentation/' + name + '.gd' for name in
                 ['match_model_pool', 'match_model_demand', 'model_refill_scheduler',
                  'match_resource_plan', 'model_visual_resources', 'unit_model_3d']]
        files += ['tools/maintenance/model_refill_schedule_contract.gd',
                  'tests/suites/presentation/match_loading_suite.gd',
                  'tools/performance/model_refill_check.py']
        def identity():
            return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files}
        before = identity()
        samples, last = [state], [0.0]
        def rss(pgid):
            if time.monotonic() - last[0] >= 1:
                current = sample_memory()
                samples.append(current)
                last[0] = time.monotonic()
                if current['pressure_level'] != 1 or current['available_estimate_bytes'] < 4 * GIB:
                    raise ValueError('System memory pressure/headroom stop')
            return group_rss_bytes(pgid)
        argv = [engine, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
                '--script', 'tools/maintenance/model_refill_schedule_contract.gd',
                '--', '--output=' + str(output)]
        report = run_guarded(argv, output, limits=Limits(rss_bytes=cap), rss_reader=rss)
        report.update(memory_samples=samples, existing_engines=engines,
                      files_sha256_before=before, files_sha256_after=identity())
        result = output / 'checks.json'
        checks = json.loads(result.read_text()) if result.exists() else {}
        log = (output / 'engine.log').read_text() if (output / 'engine.log').exists() else ''
        if not (checks.get('passed') is True and '[REFILL_SCHEDULER]' in log
                and 'ERROR:' not in log and before == identity()):
            report.update(passed=False, guard_reason=report.get('reason'), reason='missing_failed_or_changed_checks')
    except Exception as error:
        report.update(passed=False, error=str(error))
    (output / 'watchdog.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
