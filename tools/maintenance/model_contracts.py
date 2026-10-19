"""Scoped model contracts using the existing protected resource runner."""
from datetime import datetime
import argparse
import json
from pathlib import Path
import resource_artifacts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--render', action='store_true')
    mode.add_argument('--compile-render', action='store_true', help='Compile the dedicated probe only; do not rerun model checks')
    parser.add_argument('--remaining', action='store_true')
    parser.add_argument('--consumers-only', action='store_true')
    parser.add_argument('--baseline', default='')
    parser.add_argument('--select', default='')
    parser.add_argument('--batch2', action='store_true', help='Surface-template/material-reachability contracts')
    parser.add_argument('--materials-only', action='store_true')
    parser.add_argument('--strict-materials', action='store_true')
    parser.add_argument('--stasis-only', action='store_true')
    args = parser.parse_args()
    if args.remaining and args.render and args.select not in ['', 'void_gate', 'yorick', 'gnar_mega']:
        parser.error('This batch renders only VoidGate/Yorick/Gnar representatives; Pantheon is retained pending review')
    folder = resource_artifacts.ROOT / 'ClashLegends-开发素材库/04-中间产物/构建与验证/model-ownership' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    script = 'tools/maintenance/model_template_render.gd' if args.render else 'tools/maintenance/model_ownership_contract.gd'
    if args.batch2: script = 'tools/maintenance/model_material_render.gd' if args.render else 'tools/maintenance/model_material_contract.gd'
    if args.strict_materials: script = 'tools/maintenance/model_material_render.gd' if args.render else 'tools/maintenance/model_material_plan_contract.gd'
    if args.remaining: script = 'tools/maintenance/model_remaining_render.gd' if args.render else 'tools/maintenance/model_remaining_contract.gd'
    arguments = ['--output=' + str(folder)]
    if args.baseline: arguments.append('--baseline=' + args.baseline)
    if args.consumers_only: arguments.append('--consumers-only')
    if args.select: arguments.append('--select=' + args.select)
    if args.materials_only: arguments.append('--materials-only')
    if args.strict_materials and args.render: arguments.append('--strict-plan')
    if args.stasis_only: arguments.append('--stasis-only')
    if args.compile_render: arguments.append('--compile-render')
    resource_artifacts.guarded_engine(script, arguments, folder, render=args.render)
    result = json.loads((folder / 'result.json').read_text())
    print(json.dumps(dict(passed=result['passed'], checks=result['checks'], failures=result['failures'], output=str(folder)), ensure_ascii=False))
    return int(not result['passed'])


if __name__ == '__main__':
    raise SystemExit(main())
