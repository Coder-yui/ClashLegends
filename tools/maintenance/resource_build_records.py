"""Per-product identities for the existing resource-artifacts pipeline.

No scheduler, filesystem discovery framework or runtime dependency. Callers
provide the complete source/producer closure; reuse authenticates product bytes.
"""
from compression import zstd
import hashlib
import json
from pathlib import Path
import sys

COMPACT_SOURCE = 'tools/source_assets/void_summoning/sampled.json'
COMPACT_OUTPUT = 'assets/effects/void_summoning/sampled.clps'
PROJECTION_DIR = 'tools/generated/effect_projections'
MODEL_PRODUCERS = ['tools/maintenance/model_template_builder.gd',
                   'tools/maintenance/model_animation_ops.gd',
                   'scripts/presentation/model_animation_copy.gd',
                   'scripts/presentation/model_visual_template.gd',
                   'scripts/presentation/model_visual_resources.gd',
                   'scripts/presentation/presentation_config.gd',
                   'scripts/data/card_db.gd', 'scripts/data/card_schema.gd',
                   'scripts/data/card_definition_compiler.gd',
                   'scripts/data/card_validator.gd', 'godot-version.txt']
MANIFEST_PRODUCERS = ['tools/maintenance/effect_manifest_builder.gd',
                      'tools/maintenance/resource_artifacts.py', 'tools/maintenance/resource_build_records.py',
                      'scripts/presentation/effect_resource_manifest.gd',
                      'scripts/presentation/effect_warmup_coverage.gd',
                      'scripts/presentation/sampled_effect_coverage.gd',
                      'tools/maintenance/sampled_coverage_builder.gd', 'tools/maintenance/sampled_shader_contract.gd',
                      'tools/maintenance/generate_effect_artifacts.gd']


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n'


def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def key(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def closure(snapshot, names):
    names = sorted(set(names))
    if not names or any(name not in snapshot for name in names):
        raise ValueError('Missing declared product input: ' + str([n for n in names if n not in snapshot]))
    return {name: snapshot[name] for name in names}


def spec(kind, output, sources, producer, options, contract):
    if not sources or not producer or Path(output).is_absolute() or '..' in Path(output).parts:
        raise ValueError('Incomplete/invalid product closure')
    return dict(kind=kind, output=output, sources=sources, producer=producer,
                options=options, validation_contract=contract)


def complete(desired, path, validation, *, origin='built', evidence=None):
    if not isinstance(validation, dict) or not validation:
        raise ValueError('Missing completed product validation')
    return dict(schema=1, spec=desired, build_key=key(desired), origin=origin,
                product={'sha256': digest(path), 'bytes': path.stat().st_size},
                validation={'contract': desired['validation_contract'], 'result': validation},
                evidence=evidence or {})


def reusable(root, desired, record, *, path=None):
    if not isinstance(record, dict) or record.get('schema') != 1 or record.get('spec') != desired:
        return False, 'missing-or-changed-product-inputs'
    if record.get('build_key') != key(desired): return False, 'invalid-build-key'
    validation = record.get('validation', {})
    if (not isinstance(validation, dict) or validation.get('contract') != desired['validation_contract']
            or not isinstance(validation.get('result'), dict) or not validation['result']):
        return False, 'missing-completed-validation'
    product = record.get('product', {})
    path = path or root / desired['output']
    if not isinstance(product, dict) or not path.is_file(): return False, 'missing-product'
    if product.get('bytes') != path.stat().st_size or product.get('sha256') != digest(path):
        return False, 'changed-product-content'
    return True, 'matching-inputs-and-authenticated-content'


def compact_spec(snapshot):
    return spec('compact', COMPACT_OUTPUT, closure(snapshot, [COMPACT_SOURCE]),
                closure(snapshot, ['tools/maintenance/compact_samples.py']),
                {'format': 'CLPS0002', 'numeric': 'int64-float64-soa-v2', 'compression': 'zstd-level9',
                 'python': sys.version.split()[0], 'zstd': zstd.zstd_version}, 'compact-exact-bits-v1')


def projection_path(source):
    return PROJECTION_DIR + '/' + hashlib.sha256(source.encode()).hexdigest() + '.json'


def projection_spec(snapshot, source, compact_sha=None):
    sources = closure(snapshot, [source])
    producers = ['tools/maintenance/effect_dependencies.py']
    mode = 'source-json'
    if source == COMPACT_SOURCE:
        if not compact_sha: raise ValueError('Compact projection requires authenticated upstream SHA')
        sources = {**sources, COMPACT_OUTPUT: compact_sha}
        producers.append('tools/maintenance/compact_samples.py')
        mode = 'authenticated-clps-header'
    return spec('projection', projection_path(source), sources, closure(snapshot, producers),
                {'format': 'sample-metadata-v1', 'mode': mode, 'python': sys.version.split()[0]},
                'sample-numeric-shape-and-metadata-v1')


def model_specs(root, snapshot):
    result = {}
    for path in sorted((root / 'tools/source_assets/model_recipes').glob('*.json')):
        recipe = json.loads(path.read_text())
        source = root / recipe['source'].removeprefix('res://')
        names = [path.relative_to(root).as_posix(), 'project.godot']
        names += [p.relative_to(root).as_posix() for p in source.parent.rglob('*') if p.is_file()]
        names += ['scripts/data/cards/' + card + '.gd' for card in recipe.get('cards', [])]
        output = recipe['output'].removeprefix('res://')
        result[path.name] = spec('model', output, closure(snapshot, names), closure(snapshot, MODEL_PRODUCERS),
                                 {'format': 'model-visual-template-v1', 'recipe': path.name},
                                 'recipe-clip-and-mesh-v1')
    return result


def manifest_spec(snapshot, output, entry):
    selection = entry['selection']
    names = selection.get('json', []) + selection.get('dependency_json', []) + [entry['provider']]
    names += selection.get('shader_providers', [])
    if selection.get('emitter_source'): names.append(selection['emitter_source'])
    if selection.get('sample', {}).get('player'): names.append(selection['sample']['player'])
    sources = closure(snapshot, [p.removeprefix('res://') for p in names])
    # The declarations are freshly resolved after ANY global input change. Their
    # complete value is the serialization input, so dynamic helpers cannot make a
    # stale result eligible merely because a narrow script list was unchanged.
    declaration = {k: entry[k] for k in ['provider', 'variant', 'selection', 'resources', 'raw']}
    return spec('manifest', output, sources, closure(snapshot, MANIFEST_PRODUCERS),
                {'format': 'effect-files-v1', 'declaration': declaration}, 'resolved-file-closure-v1')
