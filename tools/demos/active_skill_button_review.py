#!/usr/bin/env python3
"""有界主动技能按钮专项：复用现有监督器，不启动正式比赛或全库预热。"""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from verification_guard import sample_memory, existing_engines
from performance.match_loading import command, budget, GIB
from performance.safe_probe import Limits, run_guarded, group_rss_bytes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['tests', 'render'], required=True)
    parser.add_argument('--suite', action='append', choices=['ActiveSkillButtonSuite', 'UnitBarLayoutSuite', 'ActiveSkillInputSuite'], help='测试模式显式套件；默认仅按钮专项')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    materials = (ROOT / 'ClashLegends-开发素材库/04-中间产物').resolve()
    if not output.is_relative_to(materials):
        parser.error('--output须位于开发素材库/04-中间产物内的新目录')
    output.mkdir(parents=True, exist_ok=False)
    engine = '/Applications/Godot.app/Contents/MacOS/Godot'
    report = dict(passed=False, reason='preflight_failed')
    try:
        state = sample_memory()
        cap = min(768 * 1024 * 1024, budget(state))
        engines = existing_engines(command('/bin/ps', '-ww', '-axo', 'pid=,args=', timeout=0.2), engine)
        if any(not item['editor'] for item in engines):
            raise ValueError('Existing non-editor Godot; no launch')
        files = ['scripts/ui/active_skill_bar.gd', 'scripts/ui/active_skill_button.gd',
                 'scripts/ui/skill_lock_mark.gd', 'scripts/ui/skill_icon_circle.gdshader',
                 'scripts/main.gd', 'scripts/unit.gd', 'scripts/battle/network_snapshot_system.gd',
                 'scripts/battle/match_session.gd', 'tests/suite_catalog.json',
                 'tests/suites/ui/active_skill_button_suite.gd',
                 'tests/suites/network/session_suite.gd',
                 'tools/demos/active_skill_button_review.py']
        if args.mode == 'render': files.append('tools/demos/active_skill_button_review.gd')
        suites = args.suite or ['ActiveSkillButtonSuite']

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
                    raise ValueError('Memory pressure/headroom stop')
            return group_rss_bytes(pgid)

        argv = [engine, '--path', str(ROOT), '--audio-driver', 'Dummy']
        if args.mode == 'tests':
            argv += ['--headless', '--script', 'tests/mechanics_check.gd', '--',
                     '--verbose-checks'] + ['--suite=' + name for name in suites]
        else:
            argv += ['--rendering-method', 'gl_compatibility', '--script',
                     'tools/demos/active_skill_button_review.gd', '--', '--output=' + str(output)]
        report = run_guarded(argv, output, limits=Limits(rss_bytes=cap), rss_reader=rss)
        report.update(memory_samples=samples, existing_engines=engines,
                      files_sha256_before=before, files_sha256_after=identity())
        log = (output / 'engine.log').read_text()
        valid = 'ERROR:' not in log and before == identity()
        if args.mode == 'tests':
            markers = [line.removeprefix('[MECHANICS_RESULT] ') for line in log.splitlines()
                       if line.startswith('[MECHANICS_RESULT] ')]
            result = json.loads(markers[0]) if len(markers) == 1 else {}
            valid = valid and result.get('failed') == 0 and set(result.get('completed_suites', [])) == set(suites)
            report['checks'] = result
        else:
            valid = valid and '[ACTIVE_SKILL_BUTTON_RENDER] completed' in log
            valid = valid and all((output / (name + '.png')).is_file()
                                  for name in ['01-states', '02-cooldown', '03-layout-720', '04-layout-480', '05-layout-wide'])
            valid = valid and (output / 'render-inputs.json').is_file()
        if not valid:
            report.update(passed=False, result_valid=False,
                          reason='script_error_missing_result_or_identity_changed' if report.get('passed') else report.get('reason'))
    except Exception as error:
        report.update(passed=False, error=str(error))
    (output / 'watchdog.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: report.get(key) for key in
                      ['passed', 'reason', 'error', 'seconds', 'peak_rss_bytes', 'cleanup', 'checks']}, indent=2))
    print('Evidence:', output)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
