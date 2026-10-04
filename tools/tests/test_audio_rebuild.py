import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'audio'))
HAS_NUMPY = importlib.util.find_spec('numpy') is not None
if HAS_NUMPY:
    from rebuild_original_audio import run_recipe


@unittest.skipUnless(HAS_NUMPY, 'batch renderer requires its documented NumPy runtime')
class AudioRebuildTests(unittest.TestCase):
    def test_excludes_freeze(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(ValueError, 'excluded'):
                run_recipe({'file': 'assets/audio/units/freeze/voice.wav'}, Path(d))

    def test_rejects_changed_source_before_decode(self):
        with tempfile.TemporaryDirectory() as d:
            source = Path(d)/'source.wav'
            source.write_bytes(b'changed')
            recipe = dict(file='assets/audio/units/test/voice.wav', post_gain_db=0,
                          tool_master_gain_db=0, inputs=[str(source)], input_sha256=['stale'])
            with self.assertRaisesRegex(ValueError, 'changed since'):
                run_recipe(recipe, Path(d)/'output')
            self.assertFalse((Path(d)/'output').exists())

    def test_rejects_escape_from_batch(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(ValueError, 'destination'):
                run_recipe(dict(file='../assets/audio/bad.wav', post_gain_db=0,
                                tool_master_gain_db=0), Path(d))
