"""Share identical WAV resources without removing distinct sounds or event slots.

Default is a read-only plan. --apply requires a new backup directory inside the
development material library. Run again after audio imports to avoid recreating
copies. Original event recipes remain in each canonical manifest row's
equivalent_sources; runtime files and pools use only canonical paths.
"""
import argparse
import collections
import hashlib
import json
import re
import shutil
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def audio_signature(path):
    with wave.open(str(path), 'rb') as stream:
        pcm = stream.readframes(stream.getnframes())
        return (stream.getnchannels(), stream.getsampwidth(), stream.getframerate(),
                hashlib.sha256(pcm).hexdigest())


def sharing_plan(root):
    groups = collections.defaultdict(list)
    for path in sorted((root / 'assets/audio').rglob('*.wav')):
        sidecar = Path(str(path) + '.import')
        if not sidecar.exists():
            raise ValueError(f'Missing import settings: {path}')
        settings = sidecar.read_text().split('[params]', 1)[1].strip()
        groups[(audio_signature(path), settings)].append(path.relative_to(root).as_posix())
    return {removed: paths[0] for paths in groups.values() for removed in paths[1:]}


def dedupe_pools(text):
    pattern = r'\[\s*"res://assets/audio/[^"\n]+"(?:\s*,\s*"res://assets/audio/[^"\n]+")*\s*,?\s*\]'
    def replace(match):
        seen = set()
        def member(item):
            path = item.group(1)
            if path in seen:
                return ''
            seen.add(path)
            return item.group(0)
        updated = re.sub(r'"(res://assets/audio/[^"\n]+)"\s*,?', member, match.group(0))
        return re.sub(r',(\s*\])', r'\1', updated) if updated != match.group(0) else updated
    return re.sub(pattern, replace, text)


def rewrite_text(text, path, root, aliases):
    for old, kept in aliases.items():
        text = text.replace(old, kept)
        # Same-directory README links and event manifests use bare filenames.
        if path.parent == (root / old).parent:
            text = text.replace(Path(old).name, Path(kept).name)
    return dedupe_pools(text) if path.suffix == '.gd' else text


def manifest_destination(value, path, root):
    if not isinstance(value, str):
        return None
    if value.startswith('res://assets/audio/'):
        return value[6:]
    if value.startswith('assets/audio/'):
        return value
    candidate = path.parent / value
    if candidate.is_relative_to(root / 'assets/audio'):
        return candidate.relative_to(root).as_posix()
    return None


def rewrite_manifest(value, path, root, aliases):
    if isinstance(value, dict):
        return {key: rewrite_manifest(child, path, root, aliases) for key, child in value.items()}
    if not isinstance(value, list):
        return value
    rows = []
    destinations = {}
    # Keep the existing canonical row first; preserve the other source recipes.
    def destination_field(row):
        return next((key for key in ('file', 'path', 'output')
                     if manifest_destination(row.get(key), path, root) is not None), None)
    preferred = {}
    for candidate in value:
        if isinstance(candidate, dict):
            relative = manifest_destination(candidate.get(destination_field(candidate)), path, root)
            if relative in aliases.values():
                preferred[relative] = candidate
    for original in value:
        if not isinstance(original, dict):
            rows.append(rewrite_manifest(original, path, root, aliases))
            continue
        field = destination_field(original)
        relative = manifest_destination(original.get(field), path, root)
        canonical = aliases.get(relative, relative)
        if relative is None or canonical not in aliases.values():
            rows.append(rewrite_manifest(original, path, root, aliases))
            continue
        if canonical in destinations:
            if original is preferred.get(canonical):
                continue
            source = dict(original)
            source['former_filename'] = Path(relative).name
            source.pop(field, None)
            destinations[canonical].setdefault('equivalent_sources', []).append(source)
            continue
        chosen = preferred.get(canonical, original)
        row = dict(chosen)
        field = destination_field(chosen)
        prefix = 'res://' if str(row[field]).startswith('res://') else ''
        row[field] = prefix + canonical if str(row[field]).startswith(('res://', 'assets/')) else Path(canonical).name
        if original is not chosen or relative != canonical:
            source = dict(original)
            source['former_filename'] = Path(relative).name
            source.pop(destination_field(original), None)
            row.setdefault('equivalent_sources', []).append(source)
        if 'sha256' in row:
            row['sha256'] = hashlib.sha256((root / canonical).read_bytes()).hexdigest()
        rows.append(row)
        destinations[canonical] = row
    return rows


def apply_plan(root, aliases, backup):
    library = root / 'ClashLegends-开发素材库'
    if not backup.resolve().is_relative_to(library.resolve()):
        raise ValueError('Backup must be inside the development material library')
    backup.mkdir(parents=True, exist_ok=False)
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    changes = []
    for relative in tracked:
        path = root / relative
        if not path.is_file() or path.suffix not in {'.gd', '.py', '.md', '.json', '.tscn', '.tres'}:
            continue
        if relative.startswith('docs/archive/') and path.suffix != '.md':
            continue  # Preserve historical audit data; repair only live links.
        before = path.read_text()
        if path.suffix == '.json' and path.is_relative_to(root / 'assets/audio'):
            data = json.loads(before)
            updated = rewrite_manifest(data, path, root, aliases)
            after = before if updated == data else json.dumps(updated, ensure_ascii=False, indent=2) + '\n'
        else:
            after = rewrite_text(before, path, root, aliases)
        if after != before:
            destination = backup / 'before' / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
            changes.append((path, after))
    # Back up every original and sidecar before replacing references or removing files.
    removed_bytes = 0
    for old in aliases:
        for path in [root / old, Path(str(root / old) + '.import')]:
            destination = backup / 'removed' / path.relative_to(root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
        removed_bytes += (root / old).stat().st_size
    report = dict(aliases=aliases, changed_files=[p.relative_to(root).as_posix() for p, _ in changes],
                  removed_files=len(aliases), removed_audio_bytes=removed_bytes)
    (backup / 'restore-map.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for path, text in changes:
        path.write_text(text)
    for old in aliases:
        (root / old).unlink()
        Path(str(root / old) + '.import').unlink()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--backup', type=Path)
    args = parser.parse_args()
    aliases = sharing_plan(ROOT)
    if args.apply:
        if args.backup is None:
            parser.error('--apply requires --backup')
        result = apply_plan(ROOT, aliases, args.backup)
    else:
        result = dict(duplicate_files=len(aliases), aliases=aliases)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
