"""Staging preserves source import settings and records its actual initial contents."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import development_workspace as workspace


class StageTests(unittest.TestCase):
    def test_source_settings_manifest_and_cache_exclusion(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ['assets', 'scripts', 'scenes', 'tools', 'tests', 'docs']:
                (root / name).mkdir()
            for name in ['project.godot', 'default_bus_layout.tres', 'godot-version.txt', 'README.md', 'AGENTS.md']:
                (root / name).write_text('source')
            settings = root / 'assets/model.glb.import'
            settings.write_text('custom import settings')
            (root / 'assets/.DS_Store').write_text('cache')
            with patch.object(workspace, 'PROJECT', root), patch.object(workspace, 'LIBRARY', root / 'library'):
                output = workspace.stage()
                self.assertEqual((output / 'assets/model.glb.import').read_text(), settings.read_text())
                self.assertFalse((output / 'assets/.DS_Store').exists())
                manifest = json.loads((output / 'stage_manifest.json').read_text())
                self.assertEqual(manifest['files']['assets/model.glb.import'], hashlib.sha256(settings.read_bytes()).hexdigest())
                self.assertEqual(manifest['source'], str(root))
                (output / 'project.godot').write_text('local edits')
                with patch.object(sys, 'argv', ['stage', '--reuse', str(output)]):
                    self.assertEqual(workspace.main(), 0)
                self.assertEqual((output / 'project.godot').read_text(), 'local edits')
                with patch.object(sys, 'argv', ['stage', '--reuse', str(root)]):
                    with self.assertRaises(SystemExit) as error:
                        workspace.main()
                    self.assertEqual(error.exception.code, 2)
