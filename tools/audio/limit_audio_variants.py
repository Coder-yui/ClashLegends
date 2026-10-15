"""Limit independent runtime pools to three sounds and archive unused variants.

Default is a read-only plan. --apply requires a new material-library backup.
Keep current order for normal pools; preserve random-layer coverage for numbered
two-layer combinations. Never merge events, forms, teams or attack segments.
"""
import argparse
import collections
import json
import re
import shutil
from pathlib import Path

from consolidate_audio import manifest_destination

ROOT = Path(__file__).resolve().parents[2]
LIMIT = 3
POOL = re.compile(r'\[\s*"res://assets/audio/[^"\n]+"(?:\s*,\s*"res://assets/audio/[^"\n]+")*\s*,?\s*\]')
PATH = re.compile(r'"(res://assets/audio/[^"\n]+)"')


def select_variants(paths):
    paths = list(dict.fromkeys(paths))
    if len(paths) <= LIMIT:
        return paths
    groups = collections.OrderedDict()
    for path in paths:
        match = re.search(r'_(\d+)_(\d+)\.wav$', path)
        if match is None:
            return paths[:LIMIT]
        groups.setdefault(match.group(1), []).append(path)
    if len(groups) == LIMIT:
        return [group[index % len(group)] for index, group in enumerate(groups.values())]
    return paths[:LIMIT]


def cap_text(text):
    changes = []
    def replace(match):
        before = PATH.findall(match.group(0))
        if len(before) <= LIMIT:
            return match.group(0)
        after = select_variants(before)
        changes.append(dict(line=text.count('\n', 0, match.start()) + 1, before=before, after=after))
        original = match.group(0)
        if '\n' not in original:
            return json.dumps(after, ensure_ascii=False)
        indent = re.search(r'\n([ \t]*)"', original).group(1)
        closing = re.search(r'\n([ \t]*)\]$', original).group(1)
        return '[\n' + ',\n'.join(indent + json.dumps(path) for path in after) + '\n' + closing + ']'
    return POOL.sub(replace, text), changes


def prune_manifest(value, path, root, removed):
    if isinstance(value, dict):
        return {key: child if key == 'equivalent_sources' else prune_manifest(child, path, root, removed)
                for key, child in value.items()}
    if not isinstance(value, list):
        return value
    result = []
    for row in value:
        if isinstance(row, dict) and any(manifest_destination(row.get(key), path, root) in removed
                                         for key in ['file', 'path', 'output']):
            continue
        result.append(prune_manifest(row, path, root, removed))
    return result


def plan(root):
    files = sorted((root / 'scripts/data/cards').glob('*.gd')) + [
        root / 'scripts/data/world_audio.gd', root / 'scripts/data/match_audio.gd']
    contents, changes, replacements = {}, [], {}
    for path in files:
        updated, pools = cap_text(path.read_text())
        if pools:
            contents[path] = updated
            for pool in pools:
                changes.append(dict(file=path.relative_to(root).as_posix(), **pool))
                for old in pool['before']:
                    if old not in pool['after']:
                        replacements.setdefault(old[6:], pool['after'][0][6:])
    referenced = {path[6:] for file in files for path in PATH.findall(contents.get(file, file.read_text()))}
    existing = {p.relative_to(root).as_posix() for p in (root / 'assets/audio').rglob('*')
                if p.suffix in ['.wav', '.ogg', '.mp3']}
    removed = sorted(existing - referenced)
    if any(path not in replacements for path in removed):
        raise ValueError('Unreferenced resources outside the variant selection; review separately')
    return contents, dict(pools=changes, removed=removed,
                          replacements={path: replacements[path] for path in removed},
                          files_before=len(existing), files_after=len(existing) - len(removed))


def apply(root, contents, report, backup):
    if not backup.resolve().is_relative_to((root / 'ClashLegends-开发素材库').resolve()):
        raise ValueError('Backup must be inside the development material library')
    backup.mkdir(parents=True, exist_ok=False)
    removed = set(report['removed'])
    for path in (root / 'assets/audio').rglob('*.json'):
        original = json.loads(path.read_text())
        updated = prune_manifest(original, path, root, removed)
        if original != updated:
            contents[path] = json.dumps(updated, ensure_ascii=False, indent=2) + '\n'
    # Repair current listening links, preserving the original manifests in backup.
    for path in list((root / 'docs').rglob('*.md')) + list((root / 'assets/audio').rglob('*.md')):
        text = path.read_text()
        updated = text
        for old, kept in report['replacements'].items():
            updated = updated.replace(old, kept)
            if path.parent == (root / old).parent:
                updated = updated.replace(Path(old).name, Path(kept).name)
        if updated != text:
            contents[path] = updated
    for path in contents:
        destination = backup / 'before' / path.relative_to(root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    report['removed_audio_bytes'] = 0
    for relative in removed:
        path = root / relative
        report['removed_audio_bytes'] += path.stat().st_size
        for source in [path, Path(str(path) + '.import')]:
            destination = backup / 'removed' / source.relative_to(root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
    report['changed_files'] = [p.relative_to(root).as_posix() for p in contents]
    (backup / 'restore-map.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for path, text in contents.items():
        path.write_text(text)
    for relative in removed:
        (root / relative).unlink()
        Path(str(root / relative) + '.import').unlink()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--backup', type=Path)
    args = parser.parse_args()
    contents, report = plan(ROOT)
    if args.apply:
        if args.backup is None:
            parser.error('--apply requires --backup')
        report = apply(ROOT, contents, report, args.backup)
    print(json.dumps(dict(changed_pools=len(report['pools']), removed_files=len(report['removed']),
                          files_before=report['files_before'], files_after=report['files_after']), indent=2))


if __name__ == '__main__':
    main()
