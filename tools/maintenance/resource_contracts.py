"""Two small supervised CPU contracts; no player/model instances or draw."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import compact_samples
import resource_artifacts as artifacts


def make_pack(path, files):
    """Native plain V3 fixture; accepted by the real engine in the narrow probe."""
    data = bytearray(b'GDPC' + struct.pack('<5I', 3, 4, 7, 1, 2) + struct.pack('<2Q', 104, 0) + b'\0' * 64)
    directory = []
    for name, payload in files.items():
        directory.append((name, len(data) - 104, payload))
        data += payload
    struct.pack_into('<Q', data, 32, len(data))
    data += struct.pack('<I', len(files))
    for name, offset, payload in directory:
        name = name.encode(); name += b'\0' * (-len(name) % 4)
        data += struct.pack('<I', len(name)) + name + struct.pack('<2Q', offset, len(payload)) + hashlib.md5(payload).digest() + struct.pack('<I', 0)
    path.write_bytes(data)


def main():
    root = artifacts.ROOT
    output = root / 'ClashLegends-开发素材库/04-中间产物/构建与验证/resource-artifacts' / ('contracts-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    artifacts.guarded_engine('tools/maintenance/check_resource_contracts.gd', [], output / 'format')
    with tempfile.TemporaryDirectory(prefix='clash-resource-pack-') as temporary:
        folder = Path(temporary)
        source = folder / 'tools/source_assets/void_summoning/sampled.json'
        source.parent.mkdir(parents=True)
        source.write_text(json.dumps(dict(fps=30, duration=1, emitters=[{}], frames=[[[[7, 1.0, 2.0, 3.0]]]])))
        binary = compact_samples.encode(source, folder)
        request = dict(provider='res://fixture.gd', variant='fixture')
        name = hashlib.sha256((request['provider'] + '\n' + request['variant']).encode()).hexdigest() + '.json'
        artifact = dict(schema=1, generator=artifacts.GENERATOR, policy=artifacts.POLICY, policy_sha256='a'*64, **request,
                        source_identity={'res://tools/source_assets/void_summoning/sampled.json': 'b'*64},
                        selection={}, resources=[], raw=['res://fixture.clps'])
        files = {'project.godot': b'config_version=5\n[application]\nconfig/name="Resource pack contract"\n',
                 'fixture.clps': binary,
                 str(artifacts.DIRECTORY / name): artifacts.canonical(artifact).encode()}
        for path in ['tools/maintenance/resource_pack_contract.gd', 'tools/performance/safe_probe_heartbeat.gd',
                     'scripts/presentation/compact_particle_samples.gd', 'scripts/presentation/effect_resource_manifest.gd']:
            files[path] = (root / path).read_bytes()
        pack = output / 'fixture.pck'
        make_pack(pack, files)
        isolated = output / 'isolated'
        isolated.mkdir()
        artifacts.guarded_engine('res://tools/maintenance/resource_pack_contract.gd', [], output / 'pack', main_pack=pack, project_path=isolated)
        import sys
        sys.path.insert(0, str(root / 'tools/release'))
        from pck_audit import entries
        native = entries(pack)
        assert not any(p.startswith('tools/source_assets/') for p in native)
        (output / 'pck-directory.json').write_text(artifacts.canonical(native))
    print('Resource format + isolated native PCK contracts passed: ' + str(output))


if __name__ == '__main__': main()
