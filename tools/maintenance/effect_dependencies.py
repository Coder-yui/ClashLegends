"""Generate/check small, source-hashed headers for large sampled effect JSON.

This never changes sampled sources. Runtime checks the complete source hash and
falls back to the source on a missing/stale header; verify checks exact generation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIN_BYTES = 1024 * 1024
SUFFIX = '.dependencies.json'


def numeric_frames(value):
    if isinstance(value, list):
        return all(numeric_frames(child) for child in value)
    return type(value) in (int, float) and math.isfinite(value)


def project(source: Path, root: Path) -> dict:
    raw = source.read_bytes()
    data = json.loads(raw)
    if (not isinstance(data, dict) or not isinstance(data.get('emitters'), list)
            or not isinstance(data.get('frames'), list) or not numeric_frames(data['frames'])):
        raise ValueError(f'Unsupported sampled frame shape: {source}')
    # Only numeric frame samples are omitted. Every emitter field, nested
    # resource reference, shader discriminator and layer name stays identical.
    header = {key: value for key, value in data.items() if key != 'frames'}
    return {'schema': 1, 'source': 'res://' + source.relative_to(root).as_posix(),
            'source_sha256': hashlib.sha256(raw).hexdigest(), 'data': header}


def header_path(source: Path) -> Path:
    return source.with_name(source.stem + SUFFIX)


def process(root: Path, write: bool = False) -> list[str]:
    sources = sorted(source for source in (root / 'assets/effects').rglob('sampled.json')
                     if source.stat().st_size >= MIN_BYTES)
    errors = []
    expected_paths = {header_path(source) for source in sources}
    for source in sources:
        target = header_path(source)
        try:
            expected = project(source, root)
            text = json.dumps(expected, ensure_ascii=False, separators=(',', ':'), allow_nan=False) + '\n'
            if write:
                target.write_text(text, encoding='utf-8')
            elif not target.is_file() or target.read_text(encoding='utf-8') != text:
                errors.append(f'Missing/stale dependency header: {target.relative_to(root)}')
        except (ValueError, OSError) as error:
            errors.append(str(error))
    for target in sorted((root / 'assets/effects').rglob('*' + SUFFIX)):
        if target not in expected_paths:
            errors.append(f'Orphan dependency header: {target.relative_to(root)}')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true', help='Regenerate headers; never modify sampled sources.')
    mode.add_argument('--check', action='store_true', help='Read-only exact source/header check (default).')
    args = parser.parse_args()
    errors = process(ROOT, args.write)
    for error in errors:
        print(error)
    print(f'Effect dependency headers: {len(errors)} errors')
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
