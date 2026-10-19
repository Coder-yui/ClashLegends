from pathlib import Path
import json
import struct
import tempfile
import unittest
import compact_samples as compact

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
    def test_fractional_id_rejected(self):
        self.data['frames'][0][0][0][0]=1.5;self.write()
        with self.assertRaises(ValueError):compact.encode(self.source,self.root)
    def test_width_mismatch_rejected(self):
        self.data['frames'][0][0].append([1,2,3,4]);self.write()
        with self.assertRaises(ValueError):compact.encode(self.source,self.root)
    def test_corrupt_header_magic_rejected(self):
        self.write();packed=compact.encode(self.source,self.root)
        with self.assertRaises(ValueError):compact.decode(b'INVALID!'+packed[8:])

if __name__=='__main__':unittest.main()
