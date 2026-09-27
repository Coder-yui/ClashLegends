#!/usr/bin/env python3
"""Validate Pantheon's arrival package and optionally export its layer/dependency catalog.

No runtime files are rewritten. --source points at the local original BIN text
export directory; these files are evidence, never executed as build scripts.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = Path('assets/units/pantheon')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect(root, source=None):
    package = root / PACKAGE
    systems = json.loads((package / 'r_original/systems.json').read_text())
    profile = json.loads((package / 'arrival/integration.json').read_text())
    manifest = json.loads((package / 'r_original/source_manifest.json').read_text())
    errors, rows, used = [], [], set()
    if profile.get('version') != 1 or profile.get('sample_hz') != 120:
        errors.append('Unsupported profile version/sample rate')
    landing = {'Spear_Impact', 'update_missile', 'Update_Impact', 'Sliding_Comet', 'Damage_Mis', 'Ending_Shockwave', 'Spear_Landing'}
    if profile.get('scope') != 'landing_only' or set(systems) != landing:
        errors.append('Only the seven landing systems are allowed; caster/jump/channel systems must stay outside runtime')
    if set(profile.get('excluded_systems', {})) & set(systems):
        errors.append('Excluded takeoff/unused systems entered runtime')
    if set(systems) != set(profile['systems']):
        errors.append('Phase names do not match source systems')
    seen = set()
    for system, emitters in systems.items():
        phase = profile['systems'][system]
        if 'enabled' in phase and not isinstance(phase['enabled'], bool):
            errors.append(f'{system}: enabled must be boolean')
        if not 0 <= phase['start'] < phase['stop'] <= 2.3:
            errors.append(f'{system}: invalid visual lifetime')
        if phase['frame'] not in ('ground', 'flight', 'slide', 'ending', 'spear'):
            errors.append(f'{system}: unknown coordinate frame')
        if phase['anchor'] not in ('destination', 'landing', 'comet', 'spear', 'parent_death') or phase['owner'] not in ('pre_deploy', 'unit_deploy'):
            errors.append(f'{system}: invalid anchor/owner')
        source_path = source / f'Pantheon_Base_R_{system}.txt' if source else None
        source_text = source_path.read_text() if source_path and source_path.exists() else ''
        if source_path and not source_text:
            errors.append(f'Missing original definition: {source_path}')
        for emitter in emitters:
            key = system + '/' + emitter['name']
            if key in seen:
                errors.append(f'Duplicate layer: {key}')
            seen.add(key)
            layer = profile['layers'].get(key)
            if layer is None:
                errors.append(f'Missing adaptation: {key}')
                continue
            if layer['orientation'] not in ('authored', 'ground', 'ground_front', 'ground_exit', 'impact_front') or layer['role'] not in ('attached', 'free', 'ground', 'wake'):
                errors.append(f'{key}: invalid adaptation')
            if 'enabled' in layer and not isinstance(layer['enabled'], bool):
                errors.append(f'{key}: enabled must be boolean')
            if 'anchor_bone' in layer:
                errors.append(f'{key}: bone placement overrides are no longer supported')
            if 'offset_override' in layer and (len(layer['offset_override']) != 3 or not all(isinstance(v, (int, float)) for v in layer['offset_override'])):
                errors.append(f'{key}: invalid offset')
            if source_path and f'emitterName: string = "{emitter["name"]}"' not in source_text:
                errors.append(f'{key}: not found in original definition')
            refs = [emitter.get(k, '') for k in ('texture', 'mult', 'erosion', 'mesh')]
            used.update(ref for ref in refs if ref)
            rows.append(dict(layer=key, enabled=phase.get('enabled', True) and layer.get('enabled', True), role=layer['role'], start=phase['start'], stop=phase['stop'],
                             anchor=phase['anchor'], frame=phase['frame'], orientation=layer['orientation'],
                             offset_override=layer.get('offset_override', ''), center_mesh_z=layer['center_mesh_z'],
                             texture=refs[0], multiply=refs[1], erosion=refs[2], mesh=refs[3],
                             source_sha256=sha(source_path) if source_text else ''))
    if source:
        from pantheon_arrival_metadata import enrich
        refreshed = enrich(json.loads(json.dumps(systems)), source)
        if refreshed != systems:
            errors.append('Supported source metadata is stale; regenerate with pantheon_arrival_metadata.py')
    if seen != set(profile['layers']):
        errors.append('Orphaned layer adaptations: ' + str(set(profile['layers']) - seen))
    # Independent spear, animated silhouette and its glTF material dependencies.
    used.update('res://' + str(PACKAGE / 'r_original' / name) for name in (
        'pantheon_base_q_hold_spear.mesh.json', 'pantheon_base_tx_cm.png',
        'pantheon_r_proxy.glb', 'kassadin_skin05_i_starrybackdrop.png'))
    entries = {entry['output']: entry for entry in manifest}
    for ref in used:
        target = root / ref.removeprefix('res://')
        if not target.is_file():
            errors.append(f'Missing resource: {ref}')
        if ref not in entries:
            errors.append(f'No source provenance: {ref}')
    for ref, entry in entries.items():
        target = root / ref.removeprefix('res://')
        if not target.is_file() or sha(target) != entry['sha256']:
            errors.append(f'Asset hash mismatch: {ref}')
    composition = json.loads((package / 'arrival/native_composition.json').read_text())
    for system, proxy in composition['proxies'].items():
        if system not in ('update_missile', 'Sliding_Comet') or len(proxy['offset']) != 3 or len(proxy['rotation']) != 3 or proxy['uniform_scale'] <= 0 or proxy['life'] <= 0:
            errors.append(f'Invalid native proxy: {system}')
    handoff = composition['handoff']
    parent = next(e for e in systems[handoff['system']] if e['name'] == handoff['emitter'])
    expected_start = profile['systems'][handoff['system']]['start'] + parent['life']['base']
    if abs(profile['systems'][handoff['child']]['start'] - expected_start) > 1e-6:
        errors.append('Child timing does not match original parent lifetime')
    if source:
        from pantheon_arrival_native import extract
        if composition != extract(source): errors.append('Native proxy/child metadata is stale')
    return errors, rows, dict(systems=len(systems), layers=len(rows), manifest_resources=len(entries),
                              direct_dependencies=len(used), systems_sha256=sha(package / 'r_original/systems.json'),
                              profile_sha256=sha(package / 'arrival/integration.json'),
                              unsupported=profile['unsupported'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--output', type=Path, help='Local development-library output directory')
    args = parser.parse_args()
    errors, rows, summary = inspect(args.project, args.source)
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        with (args.output / 'layers.csv').open('w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
        (args.output / 'audit.json').write_text(json.dumps(dict(summary, errors=errors), ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(summary, errors=errors), ensure_ascii=False, indent=2))
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
