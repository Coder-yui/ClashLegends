"""Versioned effect dependency artifacts. --write is supervised declarations only;
--check is Python-only and content-based, used by development and export gates.
"""
from __future__ import annotations
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import coverage_reviews
import compact_samples
import effect_dependencies
import resource_build_records as records
from resource_process import atomic_json, atomic_copy, guarded_process

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = Path('assets/generated/effect_dependencies')
INDEX = Path('tools/generated/effect_artifacts.json')
SCHEMA = 1
POLICY = 'effect-files-v1'
GENERATOR = 'effect-artifacts-v1'
GENERATOR_FILES = ['tools/maintenance/resource_artifacts.py', 'tools/maintenance/effect_dependencies.py',
                   'tools/maintenance/effect_manifest_builder.gd', 'tools/maintenance/generate_effect_artifacts.gd',
                   'tools/maintenance/compact_samples.py', 'tools/maintenance/coverage_reviews.py',
                   'tools/maintenance/effect_coverage_reviews.json', 'tools/maintenance/model_template_builder.gd',
                   'tools/maintenance/model_animation_ops.gd', 'tools/maintenance/sampled_coverage_builder.gd', 'tools/maintenance/sampled_shader_contract.gd',
                   'tools/maintenance/resource_process.py', 'tools/maintenance/resource_offline_worker.py']
GENERATOR_FILES += ['tools/maintenance/resource_build_records.py', 'tools/maintenance/compact_legacy_review.py']


def model_inputs(root):
    # Recipes name their source; hash its scoped source folder, including textures
    # and import settings. Never hash .godot caches as portable build inputs.
    paths = {root / 'project.godot'} if (root / 'project.godot').exists() else set()
    for path in (root / 'tools/source_assets/model_recipes').glob('*.json'):
        recipe = json.loads(path.read_text())
        source = root / recipe['source'].removeprefix('res://')
        if not source.is_file(): raise ValueError('Missing model source: ' + str(source))
        paths.update(p for p in source.parent.rglob('*') if p.is_file())
    return paths


def check_model_imports(root, *, require_cache=True):
    # --write must not stamp an old import as a product of a new source. The
    # editor owns import; require its source MD5 sidecar before consuming cache.
    errors = []
    for path in (root / 'tools/source_assets/model_recipes').glob('*.json'):
        recipe = json.loads(path.read_text())
        settings = root / (recipe['source'].removeprefix('res://') + '.import')
        if not settings.is_file() or digest(settings) != recipe.get('import_settings_sha256'):
            errors.append('Model import settings changed; reimport and explicitly review recipe pin: ' + str(path.relative_to(root)))
    for source in sorted(model_inputs(root)):
        settings = Path(str(source) + '.import')
        if not settings.is_file(): continue
        match = re.search(r'^dest_files=(\[.*\])$', settings.read_text(), re.M)
        if not match: errors.append('Missing imported model destinations: ' + str(source)); continue
        names = json.loads(match[1])
        if not isinstance(names, list) or not names or any(not isinstance(n, str) or not n.startswith('res://.godot/imported/') or '..' in Path(n).parts for n in names):
            errors.append('Invalid model import destinations: ' + str(source)); continue
        imported = [root / n.removeprefix('res://') for n in names]
        resource_path = 'res://' + source.relative_to(root).as_posix()
        sidecar = root / '.godot/imported' / (source.name + '-' + hashlib.md5(resource_path.encode()).hexdigest() + '.md5')
        # check remains usable before any editor import on a clean checkout.
        # If cache is present, validate its complete destination set; write always requires it.
        if not require_cache and not sidecar.exists() and not any(p.exists() for p in imported): continue
        stamps = sidecar.read_text() if sidecar.is_file() else ''
        stamp = re.search(r'^source_md5="([0-9a-f]{32})"$', stamps, re.M)
        with source.open('rb') as stream: actual = hashlib.file_digest(stream, 'md5').hexdigest()
        if not all(p.is_file() for p in imported) or stamp is None or stamp[1] != actual:
            errors.append('Model input needs Godot editor reimport before resources --write: ' + str(source.relative_to(root)))
            continue
        destination_stamp = re.search(r'^dest_md5="([0-9a-f]{32})"$', stamps, re.M)
        # Godot dest_md5 hashes destination bytes concatenated in dest_files order,
        # including all declared texture formats, not their hex digest strings.
        destination_digest = hashlib.md5()
        for path in imported:
            with path.open('rb') as stream:
                while chunk := stream.read(1024 * 1024): destination_digest.update(chunk)
        if destination_stamp is None or destination_digest.hexdigest() != destination_stamp[1]:
            errors.append('Model imported cache dest_md5 mismatch; reimport before generation/check: ' + str(source.relative_to(root)))
    return errors


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n'


def inputs(root):
    # Conservative development-only policy closure. New files also invalidate.
    paths = set()
    for pattern in ['scripts/**/*.gd', 'assets/**/*.gd', 'assets/**/*.gdshader', 'assets/**/*.gdshaderinc', 'assets/effects/**/*.import', 'assets/effects/**/*.json',
                    'assets/units/**/*.json', 'tools/source_assets/**/*.json']:
        paths.update(root.glob(pattern))
    paths.update(root / name for name in GENERATOR_FILES + ['godot-version.txt'])
    paths.update(model_inputs(root))
    return {p.relative_to(root).as_posix(): digest(p) for p in sorted(paths)
            if p.is_file() and not p.name.endswith('.dependencies.json')}


def policy_digest(snapshot):
    return hashlib.sha256(canonical(snapshot).encode()).hexdigest()


def check(root=ROOT):
    errors = coverage_reviews.check_sources(root)
    try:
        index = json.loads((root / INDEX).read_text())
        if not isinstance(index, dict): raise ValueError('Artifact index must be a dictionary')
        if index.get('schema') != SCHEMA or index.get('policy') != POLICY or index.get('generator') != GENERATOR:
            raise ValueError('Artifact index schema/policy mismatch')
        old_headers = list((root / 'assets/effects').rglob('*.dependencies.json'))
        if old_headers: errors.append('Obsolete dependency headers remain: ' + ', '.join(str(p.relative_to(root)) for p in old_headers))
        current = inputs(root)
        errors.extend(check_model_imports(root, require_cache=False))
        if current != index['inputs']:
            changes = sorted(k for k in current.keys() | index['inputs'].keys() if current.get(k) != index['inputs'].get(k))
            errors.append('Stale resource artifacts (source/layer/shader/generator changed): ' + ', '.join(changes))
        if index['policy_sha256'] != policy_digest(index['inputs']):
            errors.append('Artifact index policy digest mismatch')
        expected = set(index['artifacts'])
        actual = {p.relative_to(root).as_posix() for p in (root / DIRECTORY).glob('*.json')}
        if expected != actual: errors.append('Missing/orphan dependency artifacts')
        for name, sha in index['artifacts'].items():
            path = root / name
            if not path.is_file() or digest(path) != sha:
                errors.append('Missing/changed generated artifact: ' + name)
        if not errors:
            errors.extend(coverage_reviews.check_entries(root, [json.loads((root / name).read_text()) for name in index['artifacts']]))
        for name, sha in index['binary_artifacts'].items():
            if not (root / name).is_file() or digest(root / name) != sha:
                errors.append('Missing/changed compact artifact: ' + name)
        model_artifacts = index.get('model_artifacts', {})
        expected_models = {json.loads(p.read_text())['output'].removeprefix('res://')
                           for p in (root / 'tools/source_assets/model_recipes').glob('*.json')}
        actual_models = {p.relative_to(root).as_posix() for p in (root / 'assets/generated/model_templates').glob('*.res')}
        if set(model_artifacts) != expected_models or actual_models != expected_models:
            errors.append('Missing/orphan model template artifacts')
        for name, sha in model_artifacts.items():
            if not (root / name).is_file() or digest(root / name) != sha:
                errors.append('Missing/changed generated model template: ' + name)
        for path in index['runtime_raw']:
            if not (root / path.removeprefix('res://')).is_file(): errors.append('Missing runtime raw dependency: ' + path)
        if any('/tools/' in p or p.endswith('.dependencies.json') for p in index['runtime_raw']):
            errors.append('Development-only file leaked into runtime closure')
        errors.extend(validate_build_records(root, index, current))
        errors.extend(check_export_filters(root, index))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(str(exc))
    return errors


def check_export_filters(root, index):
    import fnmatch
    text = (root / 'export_presets.cfg').read_text()
    include = re.search(r'^include_filter="(.*)"$', text, re.M).group(1).split(',')
    exclude = re.search(r'^exclude_filter="(.*)"$', text, re.M).group(1).split(',')
    # Godot glob filters match recursively. Test full path and each ancestor.
    def matches(path, patterns):
        return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)
    errors = []
    for raw in index['runtime_raw']:
        path = raw.removeprefix('res://')
        if not matches(path, include) or matches(path, exclude):
            errors.append('Raw dependency excluded/not explicitly included for export: ' + path)
    source = 'tools/source_assets/void_summoning/sampled.json'
    if not matches(source, exclude): errors.append('Editable compact source is not excluded from export')
    return errors


def guarded_engine(script, arguments, folder, *, main_pack=None, project_path=None, render=False):
    sys.path.insert(0, str(ROOT / 'tools'))
    from lib.tool_paths import godot
    executable = godot()
    def engine_preflight():
        version = subprocess.check_output([executable, '--version'], text=True, timeout=2).strip()
        expected = (ROOT / 'godot-version.txt').read_text().strip()
        if version != expected: raise ValueError(f'Godot version mismatch: actual={version} expected={expected}')
        return {'godot_version': version}
    result = guarded_process([executable, *([] if render else ['--headless']), '--audio-driver', 'Dummy',
                              '--path', str(project_path or ROOT), *(['--main-pack', str(main_pack)] if main_pack else []),
                              '--script', script, '--', *arguments], folder, phase='godot', preflight=engine_preflight)
    log = (folder / 'engine.log').read_text(errors='replace') if (folder / 'engine.log').exists() else ''
    if re.search(r'(SCRIPT ERROR:|ERROR:)', log):
        atomic_json(folder / 'validation-error.json', {'reason': 'Engine error log; do not publish', 'guard': result})
        raise RuntimeError('Guarded declaration/contract failed: ' + str(folder))
    return result


def offline_sources(root):
    return sorted((root / 'assets/effects').rglob('sampled.json')) + [root / records.COMPACT_SOURCE]


def read_index(root):
    path = root / INDEX
    if not path.exists(): return None
    value = json.loads(path.read_text())
    if not isinstance(value, dict): raise ValueError('Artifact index must be a dictionary')
    return value


def offline_plan(root, before, old):
    previous = (old or {}).get('build_records', {})
    if not isinstance(previous, dict): raise ValueError('Invalid per-product records')
    desired = records.compact_spec(before)
    record = previous.get(records.COMPACT_OUTPUT)
    valid, reason = records.reusable(root, desired, record)
    action = 'reuse' if valid else 'build'
    if not valid and records.COMPACT_OUTPUT not in previous and old is not None and old.get('build_records_schema') is None:
        import compact_legacy_review
        migrated = compact_legacy_review.migrate(root, before, desired, old)
        if migrated is not None: record, action, reason = migrated, 'migrate', 'explicit-reviewed-legacy-receipt'
    compact = dict(spec=desired, record=record, action=action, reason=reason)
    projections = []
    compact_sha = record['product']['sha256'] if action != 'build' else None
    for source in offline_sources(root):
        name = source.relative_to(root).as_posix()
        output = records.projection_path(name)
        record = previous.get(output)
        valid = False
        if name != records.COMPACT_SOURCE or compact_sha:
            valid, _ = records.reusable(root, records.projection_spec(before, name, compact_sha), record)
        projections.append(dict(source=name, output=output, record=record, action='reuse' if valid else 'build'))
    return dict(schema=1, snapshot=before, compact=compact, projections=projections)


def compact_validation(root, record, path):
    value = record['validation']['result']
    fields = {'rows', 'float64_values_compared', 'frames', 'layers', 'width', 'packed_bytes', 'decoded_typed_bytes', 'source_bytes'}
    if set(value) != fields or any(type(value[k]) is not int or value[k] <= 0 for k in fields):
        raise ValueError('Invalid compact full-bit validation receipt')
    header = compact_samples.read_header(path)
    if (not 4 <= value['width'] <= 256 or value['float64_values_compared'] != value['rows'] * (value['width'] - 1)
            or value['decoded_typed_bytes'] != (value['frames'] * value['layers'] + 1 + value['rows'] * value['width']) * 8
            or value['packed_bytes'] != path.stat().st_size
            or value['source_bytes'] != (root / records.COMPACT_SOURCE).stat().st_size
            or header['source_sha256'] != record['spec']['sources'][records.COMPACT_SOURCE]
            or header['source'] != 'res://' + records.COMPACT_SOURCE
            or any(header[k] != value[k] for k in ['rows', 'frames', 'layers', 'width'])
            or header['payload_bytes'] != value['decoded_typed_bytes']):
        raise ValueError('Inconsistent compact full-bit validation receipt')
    return value


def staged_path(root, folder, result, output):
    relative = result['files'].get(output)
    if relative is None: return root / output
    path = Path(relative)
    if path.is_absolute() or '..' in path.parts or not relative.startswith('products/'):
        raise ValueError('Invalid staged output path')
    return folder / path


def offline_report(root, folder, before, child_pid, plan):
    path = folder / 'report.json'
    if not path.is_file() or path.stat().st_size > 1048576: raise ValueError('Missing/oversized offline completion report')
    result = json.loads(path.read_text())
    if (result.get('schema') != 2 or result.get('kind') != 'resource-offline-v2'
            or result.get('worker_pid') != child_pid): raise ValueError('Offline completion identity mismatch')
    compact = result['records'][records.COMPACT_OUTPUT]
    desired = records.compact_spec(before)
    expected = {records.COMPACT_OUTPUT: desired}
    for job in plan['projections']:
        expected[job['output']] = records.projection_spec(before, job['source'], compact['product']['sha256'])
    if set(result['records']) != set(expected) or set(result['actions']) != set(expected):
        raise ValueError('Incomplete offline product set')
    if set(result['files']) != {p for p, action in result['actions'].items() if action == 'build'}:
        raise ValueError('Offline output/action mismatch')
    if result['actions'][records.COMPACT_OUTPUT] != plan['compact']['action']:
        raise ValueError('Offline compact action differs from plan')
    for output, desired in expected.items():
        action = result['actions'][output]
        if action not in ['build', 'reuse', 'migrate']: raise ValueError('Unknown offline action')
        if action == 'migrate' and output != records.COMPACT_OUTPUT: raise ValueError('Unexpected migration')
        valid, reason = records.reusable(root, desired, result['records'][output],
                                          path=staged_path(root, folder, result, output))
        if not valid: raise ValueError('Offline output identity: ' + output + ': ' + reason)
    compact_validation(root, compact, staged_path(root, folder, result, records.COMPACT_OUTPUT))
    return result


def assemble_projections(root, folder, result, plan, destination):
    data = {}
    for job in plan['projections']:
        output, source = job['output'], job['source']
        path = staged_path(root, folder, result, output)
        if path.stat().st_size > 4194304: raise ValueError('Oversized metadata-only projection')
        entry = json.loads(path.read_text())
        validation = result['records'][output]['validation']['result']
        if (entry.get('schema') != 1 or entry.get('source') != 'res://' + source
                or entry.get('source_sha256') != plan['snapshot'][source]
                or not isinstance(entry.get('data'), dict) or 'frames' in entry['data']
                or records.key(entry['data']) != validation.get('metadata_sha256')):
            raise ValueError('Projection metadata receipt differs: ' + source)
        data[entry['source']] = entry['data']
    # Bounded metadata only (currently 3.66MB), never a numeric source graph.
    atomic_json(destination, data)


def prepare_offline(root, output, before, old):
    folder = output / 'offline'
    plan = offline_plan(root, before, old)
    atomic_json(output / 'offline-plan.json', plan)
    dirty = plan['compact']['action'] == 'build' or any(j['action'] == 'build' for j in plan['projections'])
    if dirty:
        guard = guarded_process([sys.executable, str(ROOT / 'tools/maintenance/resource_offline_worker.py'),
                                 '--root', str(root), '--output', str(folder), '--plan', str(output / 'offline-plan.json')],
                                folder, phase='offline')
        result = offline_report(root, folder, before, guard['pid'], plan)
    else:
        products = {records.COMPACT_OUTPUT: plan['compact']['record']}
        products.update({job['output']: job['record'] for job in plan['projections']})
        result = dict(records=products, files={}, actions={p: 'reuse' for p in products}, worker_pid=None)
        result['actions'][records.COMPACT_OUTPUT] = plan['compact']['action']
        compact_validation(root, products[records.COMPACT_OUTPUT], root / records.COMPACT_OUTPUT)
        atomic_json(output / 'offline-skipped.json', {'reason': 'no dirty offline products', 'actions': result['actions']})
    if inputs(root) != before: raise ValueError('Inputs changed during offline processing')
    assemble_projections(root, folder, result, plan, output / 'projections.json')
    return result


def validate_build_records(root, index, snapshot):
    if index.get('build_records_schema') != 1 or not isinstance(index.get('build_records'), dict):
        return ['Missing versioned per-product build records; regenerate explicitly']
    previous = index['build_records']
    expected = {records.COMPACT_OUTPUT: records.compact_spec(snapshot)}
    compact_sha = index['binary_artifacts'][records.COMPACT_OUTPUT]
    for source in offline_sources(root):
        desired = records.projection_spec(snapshot, source.relative_to(root).as_posix(), compact_sha)
        expected[desired['output']] = desired
    expected.update({s['output']: s for s in records.model_specs(root, snapshot).values()})
    for output in index['artifacts']:
        expected[output] = records.manifest_spec(snapshot, output, json.loads((root / output).read_text()))
    errors = []
    if set(expected) != set(previous): errors.append('Missing/orphan per-product build records')
    for output, desired in expected.items():
        valid, reason = records.reusable(root, desired, previous.get(output))
        if not valid: errors.append('Stale/invalid product record: ' + output + ': ' + reason)
    projection_outputs = {p for p, s in expected.items() if s['kind'] == 'projection'}
    actual = {p.relative_to(root).as_posix() for p in (root / records.PROJECTION_DIR).glob('*.json')}
    if actual != projection_outputs: errors.append('Missing/orphan metadata projection products')
    if records.COMPACT_OUTPUT in previous:
        try:
            compact_validation(root, previous[records.COMPACT_OUTPUT], root / records.COMPACT_OUTPUT)
        except (OSError, ValueError, KeyError, TypeError) as error:
            errors.append('Invalid compact validation receipt: ' + str(error))
        if previous[records.COMPACT_OUTPUT].get('validation', {}).get('result') != index.get('compact_validation'):
            errors.append('Aggregate/per-product compact validation differ')
    for field in ['artifacts', 'binary_artifacts', 'model_artifacts']:
        for output, sha in index.get(field, {}).items():
            if previous.get(output, {}).get('product', {}).get('sha256') != sha:
                errors.append('Aggregate/per-product content identity differ: ' + output)
    return errors


def generate(root=ROOT):
    review_errors = coverage_reviews.check_sources(root)
    if review_errors: raise ValueError('\n'.join(review_errors))
    import_errors = check_model_imports(root)
    if import_errors: raise ValueError('\n'.join(import_errors))
    before, old = inputs(root), read_index(root)
    output = root / 'ClashLegends-开发素材库/04-中间产物/构建与验证/resource-artifacts' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    output.mkdir(parents=True)
    if (old and before == old.get('inputs') and old.get('schema') == SCHEMA and old.get('policy') == POLICY
            and old.get('generator') == GENERATOR and old.get('policy_sha256') == policy_digest(before)
            and not validate_build_records(root, old, before)):
        atomic_json(output / 'actions.json', {'noop': True, 'actions': {p: 'reuse' for p in old['build_records']}})
        print('Resource generation no-op: all product inputs and contents match; evidence ' + str(output))
        return
    offline = prepare_offline(root, output, before, old)
    previous = (old or {}).get('build_records', {})
    model_specs = records.model_specs(root, before)
    dirty_models = [name for name, desired in model_specs.items()
                    if not records.reusable(root, desired, previous.get(desired['output']))[0]]
    atomic_json(output / 'engine-jobs.json', {'models': dirty_models})
    declarations = output / 'declarations.json'
    guarded_engine('tools/maintenance/generate_effect_artifacts.gd',
                   [str(output / 'projections.json'), str(declarations), str(output / 'engine-jobs.json')], output / 'guard')
    snapshot = inputs(root)
    if snapshot != before: raise ValueError('Inputs changed during generation; no index published')
    result = json.loads(declarations.read_text())
    built_models = result['model_templates']
    if set(built_models['models']) != set(dirty_models): raise ValueError('Engine built unexpected/missing model recipes')
    products = dict(offline['records'])
    actions = dict(offline['actions'])
    models, model_artifacts = {}, {}
    for name, desired in model_specs.items():
        path = root / desired['output']
        if name in dirty_models:
            report = built_models['models'][name]
            if built_models['artifacts'].get(desired['output']) != digest(path): raise ValueError('Model output digest differs')
            record = records.complete(desired, path, {'clips': report['clips'], 'meshes': report['meshes']})
            actions[desired['output']] = 'build'
        else:
            report = old['model_templates'][name]
            record = previous[desired['output']]
            actions[desired['output']] = 'reuse'
        products[desired['output']] = record
        models[name], model_artifacts[desired['output']] = report, record['product']['sha256']
    review_errors = coverage_reviews.check_entries(root, result['entries'].values())
    if review_errors: raise ValueError('\n'.join(review_errors))
    # Offline products remain staged until engine validation and input checks pass.
    for name in offline['files']:
        atomic_copy(staged_path(root, output / 'offline', offline, name), root / name)
        if digest(root / name) != products[name]['product']['sha256']: raise ValueError('Published offline product differs: ' + name)
    artifacts, runtime_raw, providers, dependency_changes = {}, set(), set(), []
    destination = root / DIRECTORY
    destination.mkdir(parents=True, exist_ok=True)
    for filename, entry in sorted(result['entries'].items()):
        entry['resources'] = sorted(set(entry['resources'])); entry['raw'] = sorted(set(entry['raw']))
        for path in entry['resources'] + entry['raw']:
            if not (root / path.removeprefix('res://')).is_file(): raise ValueError('Missing dependency: ' + path)
        name = (DIRECTORY / filename).as_posix()
        desired = records.manifest_spec(snapshot, name, entry)
        entry.update(schema=SCHEMA, generator=GENERATOR, policy=POLICY, policy_sha256=records.key(desired))
        entry['source_identity'] = {'res://' + p: sha for p, sha in desired['sources'].items()}
        path = root / name
        if path.exists():
            old_entry = json.loads(path.read_text())
            if any(old_entry.get(k) != entry[k] for k in ['resources', 'raw', 'selection']): dependency_changes.append(name)
        valid, _ = records.reusable(root, desired, previous.get(name))
        if valid:
            record = previous[name]; actions[name] = 'reuse'
        else:
            atomic_json(path, entry)
            record = records.complete(desired, path, {'resources': len(entry['resources']), 'raw': len(entry['raw'])})
            actions[name] = 'build'
        products[name] = record
        artifacts[name] = record['product']['sha256']
        runtime_raw.update(entry['raw']); runtime_raw.add('res://' + name); providers.add(entry['provider'])
    for directory, expected in [(destination, set(artifacts)), (root / 'assets/generated/model_templates', set(model_artifacts)),
                                 (root / records.PROJECTION_DIR, {p for p in products if products[p]['spec']['kind'] == 'projection'})]:
        for path in directory.glob('*.res' if directory.name == 'model_templates' else '*.json'):
            if path.relative_to(root).as_posix() not in expected: path.unlink()
    index = dict(schema=SCHEMA, generator=GENERATOR, policy=POLICY, policy_sha256=policy_digest(snapshot), inputs=snapshot,
                 artifacts=artifacts, definitions=result['definitions'], providers=len(providers), variants=len(artifacts),
                 binary_artifacts={records.COMPACT_OUTPUT: products[records.COMPACT_OUTPUT]['product']['sha256']},
                 model_artifacts=model_artifacts, model_templates=models, runtime_raw=sorted(runtime_raw),
                 compact_validation=products[records.COMPACT_OUTPUT]['validation']['result'],
                 compact_validation_origin=products[records.COMPACT_OUTPUT]['origin'], build_records_schema=1, build_records=products)
    errors = check_export_filters(root, index) + validate_build_records(root, index, snapshot)
    if errors: raise ValueError('\n'.join(errors))
    atomic_json(output / 'actions.json', {'noop': False, 'actions': actions, 'dependency_changes': dependency_changes})
    atomic_json(root / INDEX, index) # Single aggregate receipt published LAST.
    print(f'Generated: {result["definitions"]} definitions / {len(providers)} providers / {len(artifacts)} variants; '
          f'build={list(actions.values()).count("build")} reuse={list(actions.values()).count("reuse")} '
          f'migrate={list(actions.values()).count("migrate")}; evidence {output}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        if args.write: generate()
        errors = check()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        errors = [str(exc)]
    for error in errors: print(error)
    print(f'Resource artifacts: {len(errors)} errors; regenerate with python3 tools/dev.py resources --write')
    return int(bool(errors))


if __name__ == '__main__': raise SystemExit(main())
