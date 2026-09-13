#!/usr/bin/env python3
"""Read-only source browsing, selected extraction and explicit conversion to a staging folder."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.tool_paths import DEFAULT_SOURCE, PROJECT, executable, run

KINDS = {
    'all': r'.',
    'model': r'\.(skn|skl|anm|tex|dds|png|bin)$',
    'audio': r'\.(bnk|wpk|wem|txtp|wav|bin)$',
    'effects': r'particles|effects|\.bin$|\.sco$|\.scb$',
    'card-art': r'(loadscreen|loading|splash|champion-splashes).*\.(tex|dds|png|jpg|jpeg|webp)$',
}


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def safe_relative(value):
    p = PurePosixPath(value)
    if not value or p.is_absolute() or '..' in p.parts or '\\' in value or ':' in value:
        raise ValueError(f'Unsafe archive path: {value}')
    return p


def staging_path(path, source):
    path = path.expanduser().resolve()
    if path == source or path.is_relative_to(source):
        raise ValueError('Output must not be inside the read-only source library.')
    for folder in ['assets', 'scripts', 'scenes', 'docs', 'tests', 'tools', '.git', '.godot']:
        protected = PROJECT / folder
        if path == protected or path.is_relative_to(protected):
            raise ValueError('Use builds/ or an external staging directory; do not overwrite project content.')
    if path == PROJECT:
        raise ValueError('Use a dedicated staging directory.')
    if path.exists():
        raise ValueError(f'Output already exists; choose a new output: {path}')
    return path


def package_path(source, value):
    candidate = Path(value).expanduser()
    if not candidate.is_absolute():
        candidate = source / candidate
    if candidate.is_file() and candidate.resolve().is_relative_to(source):
        return candidate.resolve()
    # Convenient exact package basename, e.g. Garen or Garen.zh_CN.
    name = value if value.endswith(('.wad', '.wad.client')) else value + '.wad.client'
    matches = [p for p in source.rglob(name) if p.is_file()]
    if len(matches) != 1:
        raise ValueError(f'Package must resolve uniquely inside source root: {value} ({len(matches)} matches)')
    return matches[0].resolve()


def list_chunks(package):
    output = run('wadtools', 'list', '-i', package, '-F', 'json')
    # Installed versions can prefix JSON with diagnostic log lines.
    start = output.find('{')
    if start < 0:
        raise ValueError('wadtools did not return JSON')
    payload = json.JSONDecoder().raw_decode(output[start:])[0]
    return payload['chunks']


def select_chunks(chunks, kind, pattern=None, paths=None):
    wanted = set(paths or [])
    matcher = re.compile(pattern or '.', re.I)
    kind_matcher = re.compile(KINDS[kind], re.I)
    selected = []
    for item in chunks:
        path = item.get('path') or ''
        if wanted:
            if path not in wanted:
                continue
        elif not (kind_matcher.search(path) and matcher.search(path)):
            continue
        safe_relative(path)
        selected.append(item)
    missing = wanted - {x['path'] for x in selected}
    if missing:
        raise ValueError('Paths not found: ' + ', '.join(sorted(missing)))
    if not selected:
        raise ValueError('No matching source files; inspect the package first.')
    return selected


def extract(package, selected, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    # Extract in a sibling temporary directory; a failure leaves no partial output.
    with tempfile.TemporaryDirectory(prefix='.lol-extract-', dir=output.parent) as tmp:
        stage = Path(tmp)
        for offset in range(0, len(selected), 100):
            hashes = [x['hash'] for x in selected[offset:offset + 100]]
            run('wadtools', 'extract', '-i', package, '-o', stage, '--hash', *hashes, '--stats=false')
        records = []
        for item in selected:
            path = stage / safe_relative(item['path'])
            if not path.is_file():
                raise ValueError(f'Extractor did not produce resolved file: {item["path"]}')
            records.append({'path': item['path'], 'wad_hash': item['hash'], 'size': path.stat().st_size, 'sha256': digest(path)})
        manifest = {'package': str(package), 'package_sha256': digest(package), 'files': records,
                    'note': 'Staged source assets only. Model materials and particle dependencies must be verified before project integration.'}
        (stage / 'source_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        stage.rename(output)
    print(f'Extracted {len(records)} files to {output}')


def convert(args, source):
    output = staging_path(args.output, source)
    expected = {"model": ".glb", "texture": ".png", "bin": ".ritobin", "audio": ".wav"}
    if output.suffix.lower() != expected[args.format]:
        raise ValueError(f"Output extension must be {expected[args.format]}")
    inputs = [args.input.expanduser().resolve()]
    if not inputs[0].is_file():
        raise ValueError('Input file does not exist')
    extra = []
    tool = ''
    if args.format == 'model':
        if not args.skeleton:
            raise ValueError('Model conversion requires --skeleton and explicit material/texture mapping where applicable.')
        skeleton = args.skeleton.expanduser().resolve()
        if not skeleton.is_file(): raise ValueError('Skeleton does not exist')
        inputs.append(skeleton)
        tool = 'lol2gltf'
        extra = ['skn2gltf', '-m', inputs[0], '-s', skeleton]
        if args.animations:
            animations = args.animations.expanduser().resolve()
            if not animations.is_dir(): raise ValueError('Animations directory does not exist')
            extra += ['-a', animations]
            inputs += sorted(animations.rglob('*.anm'))
        materials, textures = [], []
        for pair in args.texture:
            material, sep, texture = pair.partition('=')
            if not sep or not material: raise ValueError('--texture requires MaterialName=/path/to/texture.png')
            tex = Path(texture).expanduser().resolve()
            if not tex.is_file(): raise ValueError(f'Texture does not exist: {tex}')
            materials.append(material); textures.append(tex); inputs.append(tex)
        if materials: extra += ['--materials', *materials, '--textures', *textures]
        extra += ['-g']
    elif args.format == 'texture': tool, extra = 'ltk-tex-utils', ['decode', inputs[0], '-o']
    elif args.format == 'bin': tool, extra = 'ritobin-tools', ['convert', inputs[0], '-o']
    elif args.format == 'audio': tool, extra = 'vgmstream-cli', ['-o']
    executable(tool)
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest = output.with_name(output.name + '.source.json')
    if manifest.exists(): raise ValueError('Provenance output already exists')
    with tempfile.TemporaryDirectory(prefix='.lol-convert-', dir=output.parent) as tmp:
        generated = Path(tmp) / output.name
        command = [*extra, generated]
        if args.format == 'audio': command.append(inputs[0])
        run(tool, *command)
        if not generated.is_file() or generated.stat().st_size == 0:
            raise ValueError('Converter did not produce a nonempty output')
        generated.rename(output)
    manifest.write_text(json.dumps({'tool': tool, 'arguments': [str(x) for x in extra], 'inputs': [{'path': str(x), 'sha256': digest(x)} for x in inputs],
                                   'output': str(output), 'sha256': digest(output)}, ensure_ascii=False, indent=2) + '\n')
    print(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    sub = parser.add_subparsers(dest='command', required=True)
    packs = sub.add_parser('packages', help='Find package files by name')
    packs.add_argument('--query', default='')
    for name in ['inspect', 'extract']:
        p = sub.add_parser(name)
        p.add_argument('--package', required=True)
        p.add_argument('--kind', choices=KINDS, default='all')
        p.add_argument('--pattern', help='Case-insensitive regex for resolved paths')
        p.add_argument('--path', action='append', help='Exact resolved file path, repeatable')
        if name == 'extract':
            p.add_argument('--output', type=Path, required=True)
            p.add_argument('--write', action='store_true', help='Actually extract; otherwise show selection only')
    c = sub.add_parser('convert')
    c.add_argument('--format', choices=['model', 'texture', 'bin', 'audio'], required=True)
    c.add_argument('--input', type=Path, required=True)
    c.add_argument('--output', type=Path, required=True)
    c.add_argument('--skeleton', type=Path)
    c.add_argument('--animations', type=Path)
    c.add_argument('--texture', action='append', default=[])
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    try:
        if not source.is_dir(): raise ValueError(f'Source directory does not exist: {source}')
        if args.command == 'packages':
            paths = [str(p.relative_to(source)) for p in source.rglob('*') if p.is_file() and p.name.endswith(('.wad', '.wad.client')) and args.query.lower() in p.name.lower()]
            print('\n'.join(sorted(paths)))
        elif args.command == 'convert': convert(args, source)
        else:
            package = package_path(source, args.package)
            selected = select_chunks(list_chunks(package), args.kind, args.pattern, args.path)
            if args.command == 'inspect' or not args.write:
                print(json.dumps({'package': str(package), 'count': len(selected), 'files': selected}, ensure_ascii=False, indent=2))
            else:
                if not args.pattern and not args.path: raise ValueError('Extraction requires --pattern or --path; select a bounded set explicitly.')
                extract(package, selected, staging_path(args.output, source))
    except (ValueError, OSError, re.error) as error:
        parser.exit(2, f'{error}\n')

if __name__ == '__main__': main()
