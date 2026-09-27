"""Check marked human-readable values against Godot's compiled card data."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
# Initial coverage is deliberately bounded; adding a card requires all eight core facts.
COVERED_CARDS = ('sion', 'kayn', 'pantheon')
CORE_FIELDS = ('cost', 'hp', 'damage', 'interval', 'deploy_time',
               'active_skills.0.cost', 'active_skills.0.max_uses', 'active_skills.0.cooldown')
MARKER = re.compile(r'<!-- card-fact: ([a-z0-9_]+) ([a-z0-9_.]+) -->\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))')


def check_documents(documents: dict[str, str], payload: dict, required=None) -> list[str]:
    errors = []
    if payload.get('schema') != 1 or not isinstance(payload.get('cards'), dict):
        return ['Invalid compiled card facts schema']
    cards = payload['cards']
    seen = set()
    for path, text in documents.items():
        matches = list(MARKER.finditer(text))
        if text.count('<!-- card-fact:') != len(matches):
            errors.append(f'{path}: malformed card-fact marker or missing numeric value')
        for match in matches:
            card, field, value = match.groups()
            actual = cards.get(card, {}).get(field)
            seen.add((card, field))
            if type(actual) not in (int, float) or not math.isfinite(actual) or not math.isclose(float(value), actual, rel_tol=0, abs_tol=1e-6):
                errors.append(f'{path}: {card}.{field}: document={value}, compiled={actual}')
    required = required if required is not None else {(card, field) for card in COVERED_CARDS for field in CORE_FIELDS}
    for card, field in sorted(required - seen):
        errors.append(f'Missing required card fact: {card}.{field}')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('facts', type=Path)
    args = parser.parse_args()
    documents = {str(p.relative_to(ROOT)): p.read_text() for p in (ROOT / 'docs/units').glob('*.md')}
    errors = check_documents(documents, json.loads(args.facts.read_text()))
    for error in errors:
        print('ERROR:', error)
    print(f'Card facts: {len(COVERED_CARDS)} required cards, {len(errors)} errors')
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
