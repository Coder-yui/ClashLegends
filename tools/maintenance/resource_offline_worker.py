"""Execute explicit dirty sampled-resource jobs; never publish live resources."""
import argparse
import hashlib
import json
import os
from pathlib import Path

import compact_samples
import effect_dependencies
import resource_build_records as records
from resource_process import MainThreadPulse, atomic_json, atomic_bytes


def prepare(root, folder, plan, *, pulse):
    root, folder = Path(root), Path(folder)
    if plan.get('schema') != 1: raise ValueError('Unknown offline job plan')
    products, files, actions = {}, {}, {}
    job = plan['compact']
    desired = job['spec']
    output = desired['output']
    compact_path = root / output
    if job['action'] == 'build':
        source = root / records.COMPACT_SOURCE
        data, source_sha, source_bytes = compact_samples.read_document(source, progress=pulse)
        if source_sha != desired['sources'][records.COMPACT_SOURCE]: raise ValueError('Compact input changed')
        packed = compact_samples.encode_document(data, 'res://' + records.COMPACT_SOURCE, source_sha, progress=pulse)
        validation = compact_samples.verify_document(data, source_sha, source_bytes, packed, progress=pulse)
        compact_path = folder / 'products/sampled.clps'
        atomic_bytes(compact_path, packed)
        products[output] = records.complete(desired, compact_path, validation)
        files[output] = str(compact_path.relative_to(folder))
        del packed, data
        actions[output] = 'build'
    elif job['action'] in ['reuse', 'migrate']:
        valid, reason = records.reusable(root, desired, job['record'])
        if not valid: raise ValueError('Compact reuse changed: ' + reason)
        products[output] = job['record']
        actions[output] = job['action']
    else:
        raise ValueError('Unknown compact action')
    compact_sha = products[output]['product']['sha256']
    for job in plan['projections']:
        source_name = job['source']
        source = root / source_name
        desired = records.projection_spec(plan['snapshot'], source_name, compact_sha)
        output = desired['output']
        valid, _ = records.reusable(root, desired, job.get('record'))
        if valid:
            products[output] = job['record']; actions[output] = 'reuse'
            continue
        if source_name == records.COMPACT_SOURCE:
            pulse('projection:authenticated-clps-header')
            entry = effect_dependencies.project_compact_header(compact_samples.read_header(compact_path), source, root,
                                                              desired['sources'][source_name])
        else:
            pulse('projection:read:' + source_name)
            raw = source.read_bytes()
            source_sha = hashlib.sha256(raw).hexdigest()
            data = json.loads(raw); del raw
            if source_sha != desired['sources'][source_name]: raise ValueError('Projection input changed')
            entry = effect_dependencies.project_document(data, source, root, source_sha, progress=pulse)
            del data
        staged = folder / 'products' / Path(output).name
        atomic_bytes(staged, effect_dependencies.encode_projection(entry))
        products[output] = records.complete(desired, staged, {'source_sha256': entry['source_sha256'],
                                            'metadata_sha256': records.key(entry['data']),
                                            'mode': desired['options']['mode']})
        del entry
        files[output] = str(staged.relative_to(folder))
        actions[output] = 'build'
    result = {'schema': 2, 'kind': 'resource-offline-v2', 'worker_pid': os.getpid(),
              'records': products, 'files': files, 'actions': actions}
    atomic_json(folder / 'report.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    args = parser.parse_args()
    pulse = MainThreadPulse()
    try:
        prepare(args.root.resolve(), args.output.resolve(), json.loads(args.plan.read_text()), pulse=pulse.update)
    except Exception as error:
        atomic_json(args.output / 'failure.json', {'pid': os.getpid(), 'error': str(error)})
        raise
    pulse.update('offline:done', ready=True, force=True)
    return 0


if __name__ == '__main__': raise SystemExit(main())
