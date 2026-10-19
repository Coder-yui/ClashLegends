import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import effect_dependencies as deps


class EffectDependencyTests(unittest.TestCase):
    def fixture(self, root):
        source = root / 'assets/effects/test/sampled.json'
        source.parent.mkdir(parents=True)
        source.write_text(json.dumps({'fps': 30, 'emitters': [{'name': 'hidden', 'blendMode': 4,
                          'texture_path': 'res://texture.png', 'nested': {'shader': 'res://test.gdshader'}}],
                          'frames': [[[[1, 0.25, 3]]]]}))
        return source

    def test_exact_projection_keeps_nested_dependencies_and_does_not_modify_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fixture(root)
            before = source.read_bytes()
            result = deps.project(source, root)
            self.assertEqual(source.read_bytes(), before)
            self.assertEqual(result['source_sha256'], hashlib.sha256(before).hexdigest())
            self.assertEqual(result['source'], 'res://assets/effects/test/sampled.json')
            self.assertEqual(result['data'], {k: v for k, v in json.loads(before).items() if k != 'frames'})

    def test_nonnumeric_frame_reference_cannot_be_silently_omitted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fixture(root)
            data = json.loads(source.read_text())
            data['frames'] = [[['res://unexpected.png']]]
            source.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                deps.project(source, root)
            data['frames'] = [[float('nan')]]
            source.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                deps.project(source, root)
