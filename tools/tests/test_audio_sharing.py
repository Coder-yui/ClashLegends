import json
import sys
import tempfile
import unittest
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'audio'))
from consolidate_audio import sharing_plan, rewrite_text, rewrite_manifest


class AudioSharingTests(unittest.TestCase):
    def make_wav(self, root, name, samples=b'\x01\x00' * 8, settings='edit/loop_mode=0'):
        path = root / 'assets/audio/units/test' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), 'wb') as stream:
            stream.setparams((1, 2, 8000, 0, 'NONE', 'not compressed'))
            stream.writeframes(samples)
        Path(str(path) + '.import').write_text('[params]\n' + settings)
        return path

    def test_only_equal_pcm_and_import_settings_are_shared(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_wav(root, 'a.wav')
            self.make_wav(root, 'b.wav')
            self.make_wav(root, 'different.wav', samples=b'\x02\x00' * 8)
            self.make_wav(root, 'loop.wav', settings='edit/loop_mode=2')
            self.assertEqual(sharing_plan(root), {'assets/audio/units/test/b.wav': 'assets/audio/units/test/a.wav'})

    def test_pool_members_deduplicated_without_merging_events(self):
        root = Path('/project')
        aliases = {'assets/audio/units/test/b.wav': 'assets/audio/units/test/a.wav'}
        text = '{"normal": {"pool": ["res://assets/audio/units/test/a.wav", "res://assets/audio/units/test/b.wav"]}, "passive": {"pool": ["res://assets/audio/units/test/b.wav"]}}'
        rewritten = rewrite_text(text, root / 'scripts/test.gd', root, aliases)
        data = json.loads(rewritten)
        self.assertEqual(set(data), {'normal', 'passive'})
        self.assertEqual(data['normal']['pool'], ['res://assets/audio/units/test/a.wav'])
        self.assertEqual(data['passive']['pool'], ['res://assets/audio/units/test/a.wav'])

    def test_manifest_keeps_source_events_for_all_destination_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            kept = self.make_wav(root, 'a.wav')
            aliases = {'assets/audio/units/test/b.wav': 'assets/audio/units/test/a.wav'}
            for key in ['file', 'path', 'output']:
                original = [{key: 'b.wav', 'event': 'second', 'sha256': 'old'},
                            {key: 'a.wav', 'event': 'first', 'sha256': 'canonical'}]
                result = rewrite_manifest(original, kept.parent / 'manifest.json', root, aliases)
                self.assertEqual(len(result), 1)
                self.assertEqual(result[0][key], 'a.wav')
                self.assertEqual(result[0]['event'], 'first')
                self.assertEqual(result[0]['equivalent_sources'][0]['event'], 'second')
                self.assertEqual(result[0]['equivalent_sources'][0]['former_filename'], 'b.wav')


if __name__ == '__main__':
    unittest.main()
