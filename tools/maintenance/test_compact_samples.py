from pathlib import Path
import json
import struct
import tempfile
import unittest
import compact_samples as compact

from array import array
from compression import zstd
import hashlib
import math
import random
import sys
MAGIC = compact.MAGIC
GENERATOR = compact.GENERATOR

def reference_encode_document(data, source_uri, source_sha, *, progress=None) -> bytes:
    """Same encoding for an already parsed document; worker owns its lifetime."""
    layers = len(data['emitters'])
    offsets = array('q', [0])
    ids = array('q')
    values = array('d')
    width = None
    for frame in data['frames']:
        if progress: progress('compact:encode-frame')
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
    header = dict(schema=2, generator=GENERATOR, source=source_uri,
                  source_sha256=source_sha, frames=len(data['frames']),
                  layers=layers, rows=len(ids), width=width, payload_bytes=len(payload),
                  payload_sha256=hashlib.sha256(payload).hexdigest(),
                  data={key:value for key,value in data.items() if key != 'frames'})
    encoded = json.dumps(header, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()
    return MAGIC + struct.pack('<I', len(encoded)) + encoded + zstd.compress(payload, level=9)

class CompactSamplesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / 'sampled.json'
        self.data = dict(fps=120,duration=1,seed=1,emitters=[dict(name='a',trail=None)],
                         frames=[[[[2**54+1,-0.0,0.1,1e-180,1e180]]], [[]]])
    def tearDown(self): self.temp.cleanup()
    def write(self): self.source.write_text(json.dumps(self.data))
    def test_exact_int64_and_float64_including_signed_zero(self):
        self.write(); packed=compact.encode(self.source,self.root)
        report=compact.verify_exact(self.source,packed)
        header,offsets,ids,values=compact.decode(packed)
        self.assertEqual(ids[0],2**54+1)
        self.assertEqual(struct.pack('<d',values[0]),struct.pack('<d',-0.0))
        self.assertEqual(report['rows'],1)
        self.assertEqual(offsets,(0,1,1))
    def test_reproducible(self):
        self.write();self.assertEqual(compact.encode(self.source,self.root),compact.encode(self.source,self.root))
    def test_single_buffer_matches_reviewed_reference_bytes_for_layout_boundaries(self):
        rng = random.Random(17)
        for width in [4, 5, 38]:
            for layers in [1, 3]:
                frames = []
                for frame in range(4):
                    groups = []
                    for layer in range(layers):
                        rows = []
                        for row in range((frame + layer) % 3):
                            serial = [-(2**63), 2**63-1, 2**54+1, 3.0][(frame+layer+row) % 4]
                            values = [-0.0, 0.1, 1e-180, 1e180, -1.0, 0, 1]
                            rows.append([serial] + [values[rng.randrange(len(values))] for _ in range(width-1)])
                        groups.append(rows)
                    frames.append(groups)
                data = dict(fps=30, emitters=[{'name': '层'+str(i)} for i in range(layers)], frames=frames)
                raw = json.dumps(data).encode(); sha = hashlib.sha256(raw).hexdigest()
                old = reference_encode_document(data, 'res://sampled.json', sha)
                new = compact.encode_document(data, 'res://sampled.json', sha)
                self.assertEqual(new, old, (width,layers))
                compact.verify_document(data, sha, len(raw), new)

    def test_single_buffer_rejects_invalid_values_and_header_only_reader_is_bounded(self):
        for invalid in [float('nan'), float('inf'), True, None]:
            value = json.loads(json.dumps(self.data)); value['frames'][0][0][0][1] = invalid
            with self.assertRaises((ValueError, TypeError)):
                compact.encode_document(value, 'res://sampled.json', 'a'*64)
        self.write(); packed = compact.encode(self.source,self.root)
        target=self.root/'sampled.clps'; target.write_bytes(packed)
        header=compact.read_header(target)
        self.assertEqual(header['source_sha256'],hashlib.sha256(self.source.read_bytes()).hexdigest())
        self.assertNotIn('frames',header['data'])
        target.write_bytes(compact.MAGIC+struct.pack('<I',1048577))
        with self.assertRaises(ValueError):compact.read_header(target)
    def test_fractional_id_rejected(self):
        self.data['frames'][0][0][0][0]=1.5;self.write()
        with self.assertRaises(ValueError):compact.encode(self.source,self.root)
    def test_width_mismatch_rejected(self):
        self.data['frames'][0][0].append([1,2,3,4]);self.write()
        with self.assertRaises(ValueError):compact.encode(self.source,self.root)
    def test_corrupt_header_magic_rejected(self):
        self.write();packed=compact.encode(self.source,self.root)
        with self.assertRaises(ValueError):compact.decode(b'INVALID!'+packed[8:])

    def rewrite(self, packed, change_header=None, change_payload=None):
        from compression import zstd
        length = struct.unpack_from('<I', packed, 8)[0]
        header = json.loads(packed[12:12+length])
        payload = zstd.decompress(packed[12+length:])
        if change_payload:
            import hashlib
            payload = change_payload(payload)
            header['payload_sha256'] = hashlib.sha256(payload).hexdigest()
        if change_header: change_header(header)
        text = json.dumps(header).encode()
        return compact.MAGIC + struct.pack('<I',len(text)) + text + zstd.compress(payload)

    def test_source_sha_schema_length_and_offsets_rejected(self):
        self.write(); packed = compact.encode(self.source,self.root)
        self.source.write_text(self.source.read_text() + ' ')
        with self.assertRaises(ValueError): compact.verify_exact(self.source, packed)
        for field in ['schema','generator','frames','payload_bytes']:
            changed = self.rewrite(packed, lambda h: h.update({field: 0}))
            with self.assertRaises(ValueError): compact.decode(changed)
        changed = self.rewrite(packed, change_payload=lambda p: struct.pack('<q',1) + p[8:])
        with self.assertRaises(ValueError): compact.decode(changed)
        with self.assertRaises(ValueError): compact.decode(compact.MAGIC + struct.pack('<I',1048577))

if __name__=='__main__':unittest.main()
