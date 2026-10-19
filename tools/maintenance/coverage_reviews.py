"""Explicit development review pins. Dependency generation never writes these records."""
import hashlib
import json
import re
from pathlib import Path

RECORD = Path('tools/maintenance/effect_coverage_reviews.json')
STRATEGY = 'static-untextured-primitives-v1'
FIXED = 'sampled-fixed-layers-v1'
COMMON = {'scripts/presentation/effect_warmup_coverage.gd',
          'scripts/presentation/spell_effect_warmup.gd', 'godot-version.txt'}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def sample_digest(sample):
    return hashlib.sha256((json.dumps(sample, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':'), allow_nan=False) + '\n').encode()).hexdigest()


def read(root):
    value = json.loads((root / RECORD).read_text())
    if not isinstance(value, dict) or value.get('schema') != 1 or not isinstance(value.get('reviews'), list):
        raise ValueError('Invalid coverage review registry')
    records = {}
    for entry in value['reviews']:
        if not isinstance(entry, dict) or not isinstance(entry.get('provider'), str) or not isinstance(entry.get('variant'), str):
            raise ValueError('Invalid coverage review identity')
        key = (entry['provider'], entry['variant'])
        if key in records or not entry.get('evidence') or not entry.get('limitations') or not isinstance(entry.get('inputs'), dict):
            raise ValueError('Incomplete/duplicate coverage review: ' + str(key))
        for name, sha in {**entry['inputs'], '_sample': entry.get('sample_sha256')}.items():
            if not isinstance(sha, str) or len(sha) != 64 or any(c not in '0123456789abcdef' for c in sha):
                raise ValueError('Invalid coverage review digest: ' + name)
            if name != '_sample' and (Path(name).is_absolute() or '..' in Path(name).parts):
                raise ValueError('Invalid coverage review path: ' + name)
        required = COMMON | {entry['provider'].removeprefix('res://')}
        if not required <= entry['inputs'].keys():
            raise ValueError('Coverage review omits required inputs: ' + str(key))
        records[key] = entry
    return records


def check_sources(root):
    errors = []
    try:
        for key, entry in read(root).items():
            for name, sha in entry['inputs'].items():
                if not (root / name).is_file() or digest(root / name) != sha:
                    errors.append('Coverage review stale; inspect/revalidate and explicitly renew %s %s: %s' % (*key, name))
    except (OSError, ValueError, TypeError) as error:
        errors.append(str(error))
    return errors


def check_entries(root, entries):
    errors = check_sources(root)
    if errors:
        return errors
    records = read(root)
    used = set()
    for entry in entries:
        sample = entry.get('selection', {}).get('sample', {})
        coverage = sample.get('coverage', {})
        if coverage.get('strategy') not in (STRATEGY, FIXED):
            continue
        key = (entry['provider'], entry['variant'])
        used.add(key)
        if key not in records:
            errors.append('Coverage has no explicit review: ' + str(key))
            continue
        review = records[key]
        required = {sample['player'].removeprefix('res://')}
        if coverage['strategy'] == FIXED:
            required.update(state['signature']['shader'].removeprefix('res://') for state in coverage['layers'])
            required.update(['scripts/presentation/sampled_effect_coverage.gd',
                             'tools/maintenance/sampled_coverage_builder.gd', 'tools/maintenance/sampled_shader_contract.gd',
                             'tools/maintenance/generate_effect_artifacts.gd'])
            required.update(p.removeprefix('res://') for p in entry['selection'].get('json', []))
            # Shader includes and authored meshes/textures are semantic inputs too.
            required.update(p.removeprefix('res://') for p in entry.get('resources', []) + entry.get('raw', []))
            required.update(p.removeprefix('res://') + '.import' for p in entry.get('resources', [])
                            if (root / (p.removeprefix('res://') + '.import')).is_file())
            required.update(shader_closure(root, [state['signature']['shader'].removeprefix('res://') for state in coverage['layers']]))
        else:
            required.update(state['shader'].removeprefix('res://') for state in coverage['states'])
        if not required <= review['inputs'].keys() or sample_digest(sample) != review['sample_sha256']:
            errors.append('Coverage declaration/setup differs from explicit review: ' + str(key))
    for key in records.keys() - used:
        errors.append('Coverage review no longer matches a declared opt-in: ' + str(key))
    return errors


def shader_closure(root, names):
    """Includes are shader semantics, not optional dependency-discovery strings."""
    result = set()
    pending = list(names)
    while pending:
        name = pending.pop()
        if name in result: continue
        if Path(name).is_absolute() or '..' in Path(name).parts:
            raise ValueError('Invalid shader include path: ' + name)
        result.add(name)
        for include in re.findall(r'#include\s+"([^"]+)"', (root / name).read_text()):
            pending.append(include.removeprefix('res://') if include.startswith('res://') else (Path(name).parent / include).as_posix())
    return result
