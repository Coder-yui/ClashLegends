"""Development-only lossless metadata projection; CLI routes to unified artifacts."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def numeric_frames(value):
    if isinstance(value, list):
        return all(numeric_frames(child) for child in value)
    return type(value) in (int, float) and math.isfinite(value)


def metadata_projection(data, source: Path, root: Path, source_sha: str) -> dict:
    """Metadata only, after caller's numeric/compact validation has succeeded."""
    header = {key: value for key, value in data.items() if key != 'frames'}
    return {'schema': 1, 'source': 'res://' + source.relative_to(root).as_posix(),
            'source_sha256': source_sha, 'data': header}


def validate_document_shape(data, source):
    if not isinstance(data, dict) or not isinstance(data.get('emitters'), list) or not isinstance(data.get('frames'), list):
        raise ValueError(f'Unsupported sampled frame shape: {source}')


def project_document(data, source: Path, root: Path, source_sha: str, *, progress=None) -> dict:
    validate_document_shape(data, source)
    for frame in data['frames']:
        if progress: progress('projection:validate-frame')
        if not numeric_frames(frame): raise ValueError(f'Unsupported sampled frame shape: {source}')
    return metadata_projection(data, source, root, source_sha)


def project(source: Path, root: Path) -> dict:
    raw = source.read_bytes()
    data = json.loads(raw)
    source_sha = hashlib.sha256(raw).hexdigest()
    del raw
    return project_document(data, source, root, source_sha)


def encode_projection(entry):
    return (json.dumps(entry, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode()


def project_compact_header(header, source: Path, root: Path, source_sha: str):
    """Only for a CLPS whose complete content and validation receipt are verified."""
    uri = 'res://' + source.relative_to(root).as_posix()
    if header.get('source') != uri or header.get('source_sha256') != source_sha:
        raise ValueError('Compact projection source identity mismatch')
    data = header['data']
    if not isinstance(data, dict) or 'frames' in data or not isinstance(data.get('emitters'), list):
        raise ValueError('Invalid compact metadata projection')
    return {'schema': 1, 'source': uri, 'source_sha256': source_sha, 'data': data}



if __name__ == "__main__":
    from resource_artifacts import main
    raise SystemExit(main())
