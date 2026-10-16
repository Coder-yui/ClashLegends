"""Lossless offline particle sample packing: integer IDs + IEEE float64, Zstandard.

Only void_summoning is integrated. Never changes the authoritative sampled.json.
Python 3.14 standard-library compression.zstd is used; no package installation.
"""
from array import array
import argparse
from compression import zstd
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/effects/void_summoning/sampled.json'
MAGIC = b'CLPS0001'


def encode(source: Path, root: Path = ROOT) -> bytes:
    raw = source.read_bytes()
    data = json.loads(raw)
    layers = len(data['emitters'])
    offsets = array('q', [0])
    ids = array('q')
    values = array('d')
    width = None
    for frame in data['frames']:
        if len(frame) != layers: raise ValueError('layer count mismatch')
        for layer in frame:
            for row in layer:
                if width is None: width = len(row)
                if len(row) != width or width < 4: raise ValueError('inconsistent row width')
                serial = row[0]
                if (type(serial) not in (int, float) or not math.isfinite(serial)
                        or serial != int(serial) or not -(2**63) <= serial < 2**63):
                    raise ValueError('particle ID is not an exact int64')
                ids.append(int(serial))
                for value in row[1:]:
                    if type(value) not in (int, float) or not math.isfinite(value):
                        raise ValueError('nonfinite sample')
                    values.append(value)
            offsets.append(len(ids))
    if width is None: raise ValueError('empty dataset')
    for packed in (offsets, ids, values):
        if sys.byteorder != 'little': packed.byteswap()
    payload = offsets.tobytes() + ids.tobytes() + values.tobytes()
    header = dict(schema=1, source='res://' + source.relative_to(root).as_posix(),
                  source_sha256=hashlib.sha256(raw).hexdigest(), frames=len(data['frames']),
                  layers=layers, rows=len(ids), width=width, payload_bytes=len(payload),
                  payload_sha256=hashlib.sha256(payload).hexdigest(),
                  data={key:value for key,value in data.items() if key != 'frames'})
    encoded = json.dumps(header, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()
    return MAGIC + struct.pack('<I', len(encoded)) + encoded + zstd.compress(payload, level=9)


def decode(raw: bytes):
    if raw[:8] != MAGIC: raise ValueError('bad compact magic')
    length = struct.unpack_from('<I',raw,8)[0]
    header = json.loads(raw[12:12+length])
    payload = zstd.decompress(raw[12+length:])
    if len(payload) != header['payload_bytes'] or hashlib.sha256(payload).hexdigest() != header['payload_sha256']:
        raise ValueError('bad payload')
    count = header['frames']*header['layers']+1
    offsets = struct.unpack_from('<'+str(count)+'q',payload)
    start = count*8
    ids = struct.unpack_from('<'+str(header['rows'])+'q',payload,start)
    values = memoryview(payload)[start+header['rows']*8:].cast('d')
    return header,offsets,ids,values


def verify_exact(source: Path, packed: bytes) -> dict:
    original = json.loads(source.read_bytes())
    header,offsets,ids,values = decode(packed)
    if header['data'] != {k:v for k,v in original.items() if k != 'frames'}:
        raise ValueError('metadata differs')
    cursor = 0
    slot = 0
    compared = 0
    for frame in original['frames']:
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
                decoded_typed_bytes=header['payload_bytes'], source_bytes=source.stat().st_size)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write',action='store_true')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--report',type=Path)
    args = parser.parse_args()
    target = SOURCE.with_suffix('.clps')
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
