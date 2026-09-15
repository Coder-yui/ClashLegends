"""Read-only repository hygiene audit; run from any directory with Python 3.
Checks local Markdown links, literal runtime resources, card docs, UID companions,
Python syntax and external-queue import pollution. Asset inventory is advisory:
dynamic loading, GLB dependencies, source files and provenance prevent safe automatic deletion.
"""
from __future__ import annotations
import argparse
import ast
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
TEXT_SUFFIXES = {'.gd', '.tscn', '.tres', '.gdshader', '.py', '.md', '.json', '.txt', '.godot'}
RESOURCE_SUFFIXES = {'.gd', '.tscn', '.tres', '.gdshader', '.png', '.jpg', '.webp', '.glb', '.wav', '.ogg', '.ttf', '.json'}
EXTERNAL = ('ClashLegends-promo-materials', 'ClashLegends-开发素材库')


def audit(root: Path, inventory: bool = False) -> dict:
    errors = []
    for forbidden in ['assets/archive', 'assets/audio/auditions', 'assets/audio/workbench_auditions.json', '待开发卡牌美术素材', 'builds']:
        if (root / forbidden).exists():
            errors.append(f'{forbidden}: development content belongs in ClashLegends-开发素材库')
    files = [p for folder in ('scripts', 'scenes', 'tests', 'tools', 'docs', 'assets')
             for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    files += [p for name in ('README.md', 'AGENTS.md', 'project.godot') if (p := root / name).exists()]
    texts = {p: p.read_text(encoding='utf-8') for p in files if p.suffix in TEXT_SUFFIXES}
    references = set()
    for path, text in texts.items():
        relative = path.relative_to(root).as_posix()
        if path.suffix == '.py':
            try:
                ast.parse(text, filename=relative)
            except SyntaxError as exc:
                errors.append(f'{relative}:{exc.lineno}: {exc.msg}')
        if path.suffix == '.md':
            # Fenced examples are templates, not navigable document links.
            prose = re.sub(r'```.*?```', '', text, flags=re.S)
            for target in re.findall(r'\]\(([^\n)]+)\)', prose):
                target = unquote(target.strip('<>').split('#', 1)[0])
                if not target or ':' in target or target.startswith('/'):
                    continue
                if not (path.parent / target).exists():
                    errors.append(f'{relative}: broken link: {target}')
        for target in re.findall(r'["\']res://([^"\'\n]+)["\']', text):
            if relative.startswith(('docs/archive/', 'assets/archive/')) or path.suffix not in {'.gd', '.tscn', '.tres', '.godot', '.gdshader'}:
                continue
            # Formatted paths and directory prefixes are resolved by Godot's content contracts.
            if any(c in target for c in ('%', '*', '{')) or Path(target).suffix not in RESOURCE_SUFFIXES:
                continue
            if relative.startswith(('scripts/', 'scenes/', 'assets/')) and (target.split('/')[0] in EXTERNAL or target.startswith('assets/archive/')):
                errors.append(f'{relative}: non-runtime resource: {target}')
            if relative.startswith('tests/') and target == 'missing.wav':
                continue  # Intentional invalid-resource fixture in validator tests.
            if relative.startswith('tools/capture/') and target == 'assets/arena/rift_arena/rift_arena.tscn':
                continue  # Available only in the external integration preview created by tools/dev.py stage.
            if not (root / target).exists():
                # Capture tools intentionally write new images under builds/ and res://.
                lines = [line for line in text.splitlines() if 'res://' + target in line]
                if not relative.startswith('tools/') or not any(any(word in line for word in ('save_', 'OUTPUT', 'output', 'DEST', 'destination')) for line in lines):
                    errors.append(f'{relative}: missing resource: {target}')
            else:
                references.add(target)
    for path in files:
        if path.suffix == '.uid' and not path.with_suffix('').exists():
            errors.append(f'{path.relative_to(root)}: orphan UID')
    registry = (root / 'scripts/data/card_db.gd').read_text()
    ids = set(re.findall(r'cards/([a-z0-9_]+)\.gd', registry))
    definitions = {p.stem for p in (root / 'scripts/data/cards').glob('*.gd')}
    docs = {p.stem for p in (root / 'docs/units').glob('*.md')} - {'README', 'arena', 'nexus', 'princess_tower', 'training_dummy'}
    expected_docs = (ids - {'gnar'}) | ({'gnar_small', 'gnar_mega'} if 'gnar' in ids else set())
    for card_id in sorted(ids ^ definitions):
        errors.append(f'card registry/definition mismatch: {card_id}')
    for card_id in sorted(expected_docs ^ docs):
        errors.append(f'card registry/document mismatch: {card_id}')
    for folder in EXTERNAL:
        base = root / folder
        if base.exists() and not (base / '.gdignore').exists():
            errors.append(f'{folder}: missing .gdignore')
        # Ignored development projects may own import sidecars; production must not reference them.
    report = {'errors': sorted(set(errors)), 'cards': len(ids), 'files': len(files),
              'literal_resource_references': len(references),
              'files_by_area': dict(sorted(Counter(p.relative_to(root).parts[0] for p in files).items()))}
    if inventory:
        assets = [p for p in files if p.is_relative_to(root / 'assets') and p.suffix not in {'.uid', '.import', '.md', '.json'} and not p.name.startswith('.')]
        groups = defaultdict(list)
        for path in assets:
            groups[hashlib.sha256(path.read_bytes()).hexdigest()].append(path.relative_to(root).as_posix())
        report['identical_asset_groups'] = [paths for paths in groups.values() if len(paths) > 1]
        report['assets_without_literal_reference'] = sorted(p.relative_to(root).as_posix() for p in assets if p.relative_to(root).as_posix() not in references)
        report['inventory_note'] = 'Candidates only: preserve dynamic CardArt, model textures, editable sources, auditions and manifest provenance; do not auto-delete.'
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', action='store_true', help='Include asset hashes and advisory reference inventory')
    parser.add_argument('--output', type=Path, help='Write JSON report outside runtime assets')
    args = parser.parse_args()
    report = audit(ROOT, args.inventory)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for error in report['errors']:
        print('ERROR:', error)
    print(f"Audit: {report['cards']} cards, {report['files']} files, {len(report['errors'])} errors")
    return 1 if report['errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
