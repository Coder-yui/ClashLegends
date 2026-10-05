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
import unicodedata
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
TEXT_SUFFIXES = {'.gd', '.tscn', '.tres', '.gdshader', '.py', '.md', '.json', '.txt', '.godot'}
RESOURCE_SUFFIXES = {'.gd', '.tscn', '.tres', '.gdshader', '.png', '.jpg', '.webp', '.glb', '.wav', '.ogg', '.ttf', '.json'}
EXTERNAL = ('ClashLegends-promo-materials', 'ClashLegends-开发素材库')


def tool_output_reference(text: str, target: str) -> bool:
    """New output files may be absent; a load of that path still requires it."""
    literal = re.escape('res://' + target)
    names = re.findall(r'^\s*(?:const|var)\s+(\w+).*?["\']' + literal + r'["\']', text, re.M)
    inputs = r'\b(?:preload|load|load_threaded_request|load_from_file)\s*\(\s*'
    if re.search(inputs + r'["\']' + literal + r'["\']', text):
        return False
    if any(re.search(inputs + re.escape(name) + r'\b', text) for name in names):
        return False
    output_names = {name for name in names if re.search(r'(?:^|_)(?:out|output|dest|destination)(?:_|$)', name, re.I)}
    lines = [line for line in text.splitlines() if 'res://' + target in line]
    return bool(lines) and all(
        any(word in line for word in ('save_', 'OUTPUT', 'output', 'DEST', 'destination'))
        or any(re.search(r'\b' + re.escape(name) + r'\b', line) for name in output_names)
        for line in lines
    )


def markdown_anchors(text: str) -> set[str]:
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    anchors = set(re.findall(r'<(?:a|[a-z]+)\s+[^>]*(?:id|name)=["\']([^"\']+)', text))
    counts = Counter()
    for heading in re.findall(r'^ {0,3}#{1,6}\s+(.+?)(?:\s+#+)?$', text, re.M):
        heading = re.sub(r'<[^>]+>', '', heading)
        heading = re.sub(r'\[([^]]+)\]\([^)]+\)', r'\1', heading)
        slug = ''.join(c for c in heading.lower() if c in '-_ ' or unicodedata.category(c)[0] in 'LN').replace(' ', '-')
        index = counts[slug]
        counts[slug] += 1
        anchors.add(slug + (f'-{index}' if index else ''))
    return anchors


def local_links(path: Path, text: str):
    prose = re.sub(r'```.*?```', '', text, flags=re.S)
    for raw in re.findall(r'\]\(([^\n)]+)\)', prose):
        raw = unquote(raw.strip('<>'))
        target, _, anchor = raw.partition('#')
        if ':' in target or target.startswith('/'):
            continue
        yield (path.parent / target).resolve() if target else path.resolve(), anchor, raw


def audit_navigation(root: Path, texts: dict, errors: list) -> dict:
    manifest = root / 'docs/navigation.json'
    if not manifest.exists(): return {}
    try:
        config = json.loads(manifest.read_text())
    except (ValueError, OSError) as exc:
        errors.append(f'docs/navigation.json: invalid navigation manifest: {exc}')
        return {}
    historical = ('docs/archive/', 'docs/issues/', 'docs/deliveries/')
    graph = {p.resolve(): [dest for dest, _, _ in local_links(p, text)] for p, text in texts.items() if p.suffix == '.md'}
    visited = set()
    pending = [(root / config.get('entry', 'AGENTS.md')).resolve()]
    while pending:
        path = pending.pop()
        if path in visited: continue
        visited.add(path)
        if path.is_relative_to(root) and path.relative_to(root).as_posix().startswith(historical): continue
        pending.extend(graph.get(path, []))
    required = config.get('current', []) + [page for route in config.get('routes', {}).values() for page in route]
    for name in set(required):
        path = (root / name).resolve()
        if name.startswith(historical):
            errors.append(f'docs/navigation.json: historical page marked required: {name}')
        elif not path.is_file() or path not in visited:
            errors.append(f'docs/navigation.json: current page unreachable: {name}')
    for path, text in texts.items():
        relative = path.relative_to(root).as_posix()
        if path.suffix != '.md' or relative.startswith(historical): continue
        for source, constant, value in re.findall(r'<!-- current-fact: ([^ ]+) ([A-Z_]+) -->\s*(\d+)', text):
            source_path = root / source
            code = source_path.read_text() if source_path.is_file() else ''
            actual = re.search(r'^const ' + re.escape(constant) + r'\s*:?=\s*(\d+)\b', code, re.M)
            if not actual or int(actual[1]) != int(value):
                errors.append(f'{relative}: current fact mismatch: {source}::{constant}={value}')
    return config.get('card_documents', {})

def audit_suite_catalog(root: Path, errors: list) -> None:
    """Every automatic suite has one catalog entry per public entry point."""
    manifest = root / 'tests/suite_catalog.json'
    if not manifest.exists(): return
    try:
        entries = json.loads(manifest.read_text())
        if not isinstance(entries, list) or not entries:
            raise ValueError('expected a nonempty list')
        ids, calls, scripts = set(), set(), set()
        for entry in entries:
            name, script, method, scene, group = (entry[key] for key in ('id', 'script', 'method', 'scene', 'group'))
            if not all(isinstance(value, str) and value for value in (name, script, method, scene, group)):
                raise ValueError('fields must be nonempty strings')
            path = root / script.removeprefix('res://')
            if name in ids or (script, method) in calls:
                errors.append(f'tests/suite_catalog.json: duplicate suite or entry point: {name}')
            ids.add(name); calls.add((script, method)); scripts.add(path.resolve())
            if scene not in ('none', 'menu', 'battle') or group != path.parent.name:
                errors.append(f'tests/suite_catalog.json: invalid scene/group: {name}')
            if not script.startswith('res://tests/suites/') or not path.is_file():
                errors.append(f'tests/suite_catalog.json: missing suite script: {script}')
            elif not re.search(r'^func ' + re.escape(method) + r'\(', path.read_text(), re.M):
                errors.append(f'tests/suite_catalog.json: missing method: {name}.{method}')
        # These two are selected by the runner's two-process mode, not the single-process catalog.
        external = {'network_integration_suite.gd', 'network_boundary_suite.gd'}
        for path in (root / 'tests/suites').glob('*/*_suite.gd'):
            if path.name not in external and path.resolve() not in scripts:
                errors.append(f'tests/suite_catalog.json: unregistered suite: {path.relative_to(root)}')
    except (ValueError, KeyError, TypeError) as exc:
        errors.append(f'tests/suite_catalog.json: invalid catalog: {exc}')


def audit_state_ownership(root: Path, errors: list) -> None:
    """Small explicit guard for the state objects whose Unit writes were consolidated."""
    for name in ('dash_strike_state', 'terrain_traversal_state', 'death_form_state'):
        path = root / f'scripts/battle/{name}.gd'
        if not path.exists():
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            code = line.split('#', 1)[0]
            if re.search(r'\b(?:unit|source)\.\w+\s*(?:=(?!=)|[+*/-]=)', code) or re.search(r'\b(?:unit|source)\.(?:_apply_form|_die)\(', code) or re.search(r'\b(?:unit|source)\.(?:active_skill_cast_locks|_path)\.(?:clear|append)\(', code):
                errors.append(f'{path.relative_to(root)}:{number}: state bypasses Unit transition owner')


def audit(root: Path, inventory: bool = False) -> dict:
    root = root.resolve()
    errors = []
    audit_suite_catalog(root, errors)
    audit_state_ownership(root, errors)
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
        if relative.startswith('scripts/') and path.suffix == '.gd':
            if re.search(r'\b(?:shroud_radius|_shroud_active|net_shroud_active|U_SHROUD|is_hidden_from|is_hidden_from_position|_is_shroud_blocked)\b', text):
                errors.append(f'{relative}: retired production mechanism')
            if re.search(r'_commands\._(?:card_commands|skill_commands|pre_deployments|impacts|next_pre_deploy_id)\b', text):
                errors.append(f'{relative}: command schedule private state access')
        if path.suffix == '.py':
            try:
                ast.parse(text, filename=relative)
            except SyntaxError as exc:
                errors.append(f'{relative}:{exc.lineno}: {exc.msg}')
        if path.suffix == '.md':
            for destination, anchor, target in local_links(path, text):
                if not destination.exists():
                    errors.append(f'{relative}: broken link: {target}')
                elif anchor and destination.suffix == '.md' and anchor not in markdown_anchors(destination.read_text()):
                    errors.append(f'{relative}: broken anchor: {target}')
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
                # Capture outputs need not pre-exist; required input resources still do.
                if not relative.startswith('tools/') or not tool_output_reference(text, target):
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
    mappings = audit_navigation(root.resolve(), texts, errors)
    expected_docs = set()
    for card_id in ids:
        pages = mappings.get(card_id, [card_id])
        expected_docs.update(pages)
        definition = (root / 'scripts/data/cards' / (card_id + '.gd')).read_text() if card_id in definitions else ''
        if '"transformed_stats"' in definition and len(pages) < 2:
            errors.append(f'card form/document mapping missing: {card_id}')
    for card_id in mappings.keys() - ids:
        errors.append(f'unknown card document mapping: {card_id}')
    for card_id in sorted(ids ^ definitions):
        errors.append(f'card registry/definition mismatch: {card_id}')
    for card_id in sorted(expected_docs ^ docs):
        errors.append(f'card registry/document mismatch: {card_id}')
    coverage = root / 'docs/reference/UNIT_DOC_COVERAGE.md'
    if coverage.is_file():
        covered = set(re.findall(r'^\| `[^|]*\[[^]]+\]\(\.\./units/([a-z0-9_]+)\.md\)', coverage.read_text(), re.M))
        for page in sorted(expected_docs ^ covered):
            errors.append(f'card coverage table mismatch: {page}')
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
