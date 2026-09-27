#!/usr/bin/env python3
"""Extract original animated emitter composition and the one supported death child."""
import argparse
import json
from pathlib import Path
from pantheon_arrival_metadata import emitters, fields, value, nums


def extract(source):
    result = {'proxies': {}, 'handoff': {}}
    for system, name in [('update_missile', 'Temp_Mesh4'), ('Sliding_Comet', 'PantheonSllide')]:
        definition = dict(emitters((source / f'Pantheon_Base_R_{system}.txt').read_text()))[name]
        mesh = fields(fields(definition['primitive'])['mMesh'])
        assert definition['isUniformScale'] == 'true'
        result['proxies'][system] = {
            'emitter': name,
            'animation': Path(mesh['mAnimationName'].strip('"')).stem.lower(),
            'offset': nums(fields(definition['SpawnShape'])['emitOffset']),
            'rotation': value(definition['birthRotation0'], [0, 0, 0])['base'],
            'uniform_scale': value(definition['birthScale0'], [1, 1, 1])['base'][0],
            'color': value(definition['Color'], [1, 1, 1, 1]),
            'life': value(definition.get('particleLifetime', ''), 1)['base'],
            'uv_offset': value(definition['birthUVOffset'], [0, 0])['base'],
            'pass': int(definition.get('pass', '0')),
        }
    definition = dict(emitters((source / 'Pantheon_Base_R_Damage_Mis.txt').read_text()))['Temp_Mesh1']
    child = fields(definition['childParticleSetDefinition'])
    assert child['childEmitOnDeath'] == 'true'
    assert '"Pantheon_R_Ending_Shockwave"' in child['childrenIdentifiers']
    result['handoff'] = {'system': 'Damage_Mis', 'emitter': 'Temp_Mesh1', 'child': 'Ending_Shockwave', 'event': 'childEmitOnDeath'}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(extract(args.source), ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
