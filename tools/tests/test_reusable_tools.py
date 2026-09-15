import importlib.util
from pathlib import Path
import tempfile
import unittest
import wave
import json

TOOLS = Path(__file__).resolve().parents[1]
def module(name, path):
    spec = importlib.util.spec_from_file_location(name, TOOLS / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result
source = module('source', 'assets/lol_source.py')
audio = module('audition', 'audio_review/serve.py')
voice = module('voice', 'audio/find_lol_voice.py')

class SourceTests(unittest.TestCase):
    def test_archive_paths(self):
        for value in ['../escape', '/escape', 'C:/escape', 'a/../../b', 'a\\b', '']:
            with self.assertRaises(ValueError): source.safe_relative(value)
    def test_selection_and_missing(self):
        chunks = [{'path': 'assets/body.skn'}, {'path': 'assets/voice.wem'}]
        self.assertEqual(source.select_chunks(chunks, 'model'), chunks[:1])
        with self.assertRaises(ValueError): source.select_chunks(chunks, 'all', paths=['missing'])
    def test_protected_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            for output in [root / 'new', TOOLS / 'new', source.PROJECT / 'assets/new']:
                with self.assertRaises(ValueError): source.staging_path(output, root)

class VoiceLookupTests(unittest.TestCase):
    def test_text_to_event_keeps_site_keys_separate(self):
        info = {'select': {'ban': '让我带来终结。'}}
        skin = {'events': {'Play_vo_Test': {'name': '复活', 'voices': ['ABCDEF00']}},
                'transcript': {'ABCDEF00': {'text': '我回来了。'}}}
        self.assertEqual(voice.metadata_matches(info, skin, '终结')[0]['client_kind'], 'ban')
        hit = voice.metadata_matches(info, skin, '我回来了')[0]
        self.assertEqual(hit['event'], 'Play_vo_Test')
        self.assertEqual(hit['website_key'], 'ABCDEF00')
        self.assertNotIn('media_id', hit)
        self.assertEqual(voice.metadata_matches(info, skin, '不存在'), [])
    def test_outputs_stay_in_library(self):
        with self.assertRaises(ValueError): voice.output_path(TOOLS / 'bad.json')

class AudioTests(unittest.TestCase):
    def test_catalog_duration_and_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wav = root / 'sample.wav'
            with wave.open(str(wav), 'wb') as stream:
                stream.setparams((1, 2, 8000, 0, 'NONE', 'not compressed'))
                stream.writeframes(b'\0' * 8000)
            manifest = root / 'manifest.json'
            manifest.write_text(json.dumps([{'file': wav.name, 'duration': 99, 'event': 'test'}]))
            items = audio.build_catalog(manifests=[manifest])
            self.assertEqual(items[0]['duration'], .5)
            self.assertEqual(items[0]['event'], 'test')
            with self.assertRaises(ValueError): audio.build_catalog([root], cards=['absent'])
    def test_seek_ranges(self):
        self.assertEqual(audio.byte_range('bytes=2-6', 10), (2, 6))
        self.assertEqual(audio.byte_range('bytes=-3', 10), (7, 9))
        self.assertEqual(audio.byte_range('bytes=8-', 10), (8, 9))
        for value in ['bytes=20-', 'bytes=-0', 'bytes=3-2', 'bytes=1-2,4-5']:
            with self.assertRaises(ValueError): audio.byte_range(value, 10)

if __name__ == '__main__': unittest.main()
