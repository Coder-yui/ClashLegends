"""Narrow stock correction contracts; original resource-process guard unchanged."""
from datetime import datetime
import argparse
import json
import resource_artifacts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['static', 'capabilities', 'compile-runtime', 'runtime', 'scheduler', 'failures'], default='static')
    args = parser.parse_args()
    folder = resource_artifacts.ROOT / 'ClashLegends-开发素材库/04-中间产物/构建与验证/model-inventory' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    script = 'tools/maintenance/model_refill_schedule_contract.gd' if args.mode == 'scheduler' else 'tools/maintenance/model_inventory_revision_contract.gd'
    if args.mode == 'failures': script = 'tools/maintenance/model_failure_contract.gd'
    resource_artifacts.guarded_engine(script, ['--output=' + str(folder), '--mode=' + args.mode], folder)
    result = json.loads((folder / 'result.json').read_text())
    print(json.dumps(dict(output=str(folder), passed=result['passed'], checks=result['checks'], failures=result['failures']), ensure_ascii=False))
    return int(not result['passed'])


if __name__ == '__main__':
    raise SystemExit(main())
