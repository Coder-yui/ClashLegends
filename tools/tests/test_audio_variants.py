import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'audio'))
from limit_audio_variants import cap_text, select_variants, prune_manifest


class AudioVariantTests(unittest.TestCase):
    def test_cap_preserves_event_boundaries_and_shared_files(self):
        paths = ['res://assets/audio/a%d.wav' % i for i in range(4)]
        text = json.dumps({'normal': {'pool': paths}, 'passive': {'pool': [paths[3]]}})
        capped, changes = cap_text(text)
        self.assertEqual(len(changes), 1)
        data = json.loads(capped)
        self.assertEqual(data['normal']['pool'], paths[:3])
        self.assertEqual(data['passive']['pool'], [paths[3]])

    def test_combinations_cover_both_random_layers(self):
        paths = ['res://assets/audio/spawn_%d_%d.wav' % (a, b)
                 for a in range(1, 4) for b in range(1, 4)]
        self.assertEqual(select_variants(paths), [paths[0], paths[4], paths[8]])
        self.assertEqual(select_variants(paths[:2]), paths[:2])

    def test_manifest_prunes_only_explicitly_removed_outputs(self):
        root = Path('/project')
        file = root / 'assets/audio/manifest.json'
        data = [{'file': 'assets/audio/kept.wav', 'event': 'normal',
                 'equivalent_sources': [{'file': 'assets/audio/retired.wav'}]},
                {'file': 'assets/audio/retired.wav', 'event': 'normal'},
                {'path': 'res://assets/audio/shared.wav', 'event': 'passive'}]
        result = prune_manifest(data, file, root, {'assets/audio/retired.wav'})
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['equivalent_sources'], data[0]['equivalent_sources'])
        self.assertEqual(result[1]['event'], 'passive')


if __name__ == '__main__':
    unittest.main()
