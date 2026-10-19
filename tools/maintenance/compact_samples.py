"""Lossless offline particle sample packing: integer IDs + IEEE float64, Zstandard.

Only void_summoning is integrated. Never changes the editable development source.
Python 3.14 standard-library compression.zstd is used; no package installation.
"""
import argparse
from compression import zstd
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/source_assets/void_summoning/sampled.json'
TARGET = ROOT / 'assets/effects/void_summoning/sampled.clps'
MAGIC = b'CLPS0002'
GENERATOR = 'compact-f64-v2'


def encode(source: Path, root: Path = ROOT) -> bytes:
    data, source_sha, _ = read_document(source)
    return encode_document(data, 'res://' + source.relative_to(root).as_posix(), source_sha)


def read_document(source, *, progress=None):
    if progress: progress('compact:read-source')
    raw = source.read_bytes()
    data = json.loads(raw)
    source_sha, source_bytes = hashlib.sha256(raw).hexdigest(), len(raw)
    del raw
    if not isinstance(data, dict) or not isinstance(data.get('emitters'), list) or not isinstance(data.get('frames'), list):
        raise ValueError('Unsupported sampled frame shape: ' + str(source))
    return data, source_sha, source_bytes


def encode_document(data, source_uri, source_sha, *, progress=None) -> bytes:
    """Same CLPS0002 structure-of-arrays layout in one payload buffer.

    Offsets, then ALL IDs, then ALL float64 values; rows are not interleaved.
    Only the count pass precedes writing. The source document remains available
    to the independent decode/bit comparison below.
    """
    layers = len(data['emitters'])
    rows = 0
    width = None
    for frame in data['frames']:
        if progress: progress('compact:count-frame')
        if len(frame) != layers: raise ValueError('layer count mismatch')
        for layer in frame:
            for row in layer:
                if width is None: width = len(row)
                if len(row) != width or width < 4: raise ValueError('inconsistent row width')
                rows += 1
    if width is None: raise ValueError('empty dataset')
    offset_bytes = (len(data['frames']) * layers + 1) * 8
    value_start = offset_bytes + rows * 8
    payload_bytes = (len(data['frames']) * layers + 1 + rows * width) * 8
    if payload_bytes > 268435456: raise ValueError('bad allocation length')
    payload = bytearray(payload_bytes)
    integer = struct.Struct('<q')
    floats = struct.Struct('<' + str(width - 1) + 'd')
    cursor, slot = 0, 0
    for frame in data['frames']:
        if progress: progress('compact:encode-frame')
        for layer in frame:
            for row in layer:
                serial = row[0]
                if (type(serial) not in (int, float) or not math.isfinite(serial)
                        or serial != int(serial) or not -(2**63) <= serial < 2**63):
                    raise ValueError('particle ID is not an exact int64')
                integer.pack_into(payload, offset_bytes + cursor * 8, int(serial))
                for value in row[1:]:
                    if type(value) not in (int, float) or not math.isfinite(value):
                        raise ValueError('nonfinite sample')
                floats.pack_into(payload, value_start + cursor * (width - 1) * 8, *row[1:])
                cursor += 1
            slot += 1
            integer.pack_into(payload, slot * 8, cursor)
    header = dict(schema=2, generator=GENERATOR, source=source_uri,
                  source_sha256=source_sha, frames=len(data['frames']),
                  layers=layers, rows=rows, width=width, payload_bytes=len(payload),
                  payload_sha256=hashlib.sha256(payload).hexdigest(),
                  data={key:value for key,value in data.items() if key != 'frames'})
    encoded = json.dumps(header, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()
    return MAGIC + struct.pack('<I', len(encoded)) + encoded + zstd.compress(payload, level=9)


def read_header(path):
    """Bounded metadata only. Caller must first authenticate the complete file SHA."""
    with path.open('rb') as stream:
        prefix = stream.read(12)
        if len(prefix) != 12 or prefix[:8] != MAGIC: raise ValueError('bad compact magic')
        length = struct.unpack_from('<I', prefix, 8)[0]
        if not 2 <= length <= 1048576: raise ValueError('bad header length')
        encoded = stream.read(length)
        if len(encoded) != length: raise ValueError('short compact header')
    header = json.loads(encoded)
    if not isinstance(header, dict) or header.get('schema') != 2 or header.get('generator') != GENERATOR or not isinstance(header.get('data'), dict):
        raise ValueError('bad compact header identity')
    if 'frames' in header['data'] or not isinstance(header['data'].get('emitters'), list):
        raise ValueError('bad compact metadata')
    return header


def decode(raw: bytes):
    if len(raw) < 12 or raw[:8] != MAGIC: raise ValueError('bad compact magic')
    length = struct.unpack_from('<I', raw, 8)[0]
    if not 2 <= length <= 1048576 or len(raw) < 12 + length: raise ValueError('bad header length')
    header = json.loads(raw[12:12+length])
    if not isinstance(header, dict) or header.get('schema') != 2 or header.get('generator') != GENERATOR:
        raise ValueError('bad schema/generator')
    for key in ('frames', 'layers', 'rows', 'width', 'payload_bytes'):
        if type(header.get(key)) is not int: raise ValueError('bad dimension type')
    frames, layers, rows, width = (header[k] for k in ('frames', 'layers', 'rows', 'width'))
    if not (0 < frames <= 1000000 and 0 < layers <= 1024 and 0 <= rows <= 10000000 and 4 <= width <= 256):
        raise ValueError('bad dimensions')
    expected = (frames * layers + 1 + rows * width) * 8
    if expected != header['payload_bytes'] or expected > 268435456: raise ValueError('bad allocation length')
    decoder = zstd.ZstdDecompressor()
    payload = decoder.decompress(raw[12+length:], max_length=expected + 1)
    if not decoder.eof or decoder.unused_data: raise ValueError('bad compressed length/frame')
    if len(payload) != expected or hashlib.sha256(payload).hexdigest() != header.get('payload_sha256'):
        raise ValueError('bad payload')
    count = frames * layers + 1
    offsets = struct.unpack_from('<'+str(count)+'q', payload)
    if offsets[0] != 0 or offsets[-1] != rows or any(a > b or not 0 <= b <= rows for a, b in zip(offsets, offsets[1:])):
        raise ValueError('bad offsets')
    start = count * 8
    ids = struct.unpack_from('<'+str(rows)+'q', payload, start)
    values = memoryview(payload)[start+rows*8:].cast('d')
    return header, offsets, ids, values


def verify_exact(source: Path, packed: bytes) -> dict:
    raw = source.read_bytes()
    original = json.loads(raw)
    source_sha, source_bytes = hashlib.sha256(raw).hexdigest(), len(raw)
    del raw
    return verify_document(original, source_sha, source_bytes, packed)


def verify_document(original, source_sha, source_bytes, packed, *, progress=None) -> dict:
    header,offsets,ids,values = decode(packed)
    if source_sha != header.get('source_sha256'): raise ValueError('source identity differs')
    if header['data'] != {k:v for k,v in original.items() if k != 'frames'}:
        raise ValueError('metadata differs')
    cursor = 0
    slot = 0
    compared = 0
    for frame in original['frames']:
        if progress: progress('compact:verify-frame')
        for layer in frame:
            if offsets[slot] != cursor or offsets[slot+1]-cursor != len(layer):
                raise ValueError('frame/layer offsets differ')
            for row in layer:
                if ids[cursor] != row[0]: raise ValueError('ID differs')
                for column, value in enumerate(row[1:]):
                    other = values[cursor*(header['width']-1)+column]
                    if struct.pack('<d',float(value)) != struct.pack('<d',other):
                        raise ValueError('float64 bits differ')
                    compared += 1
                cursor += 1
            slot += 1
    return dict(rows=cursor, float64_values_compared=compared, frames=header['frames'],
                layers=header['layers'], width=header['width'], packed_bytes=len(packed),
                decoded_typed_bytes=header['payload_bytes'], source_bytes=source_bytes)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write',action='store_true')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--report',type=Path)
    args = parser.parse_args()
    target = TARGET
    if args.write:
        packed = encode(SOURCE)
        target.write_bytes(packed)
    else:
        packed = target.read_bytes()
    report = verify_exact(SOURCE,packed)
    if args.check and packed != encode(SOURCE): raise ValueError('compact output not reproducible')
    if args.report: args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))

if __name__ == '__main__': main()
