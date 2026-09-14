"""Repository audit regression fixtures; no project or asset writes."""
import tempfile
import unittest
from pathlib import Path
from audit_project import audit


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write('scripts/data/card_db.gd', 'preload("res://scripts/data/cards/example.gd")')
        self.write('scripts/data/cards/example.gd', 'extends RefCounted\n')
        self.write('docs/units/example.md', '[definition](../../scripts/data/cards/example.gd)\n')

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)

    def test_valid_links_and_intentional_invalid_fixture(self):
        self.write('tests/fixture.gd', 'var invalid = "res://missing.wav"')
        self.write('docs/examples.md', '```md\n[placeholder](not-a-file.md)\n```\n')
        self.assertEqual(audit(self.root)['errors'], [])

    def test_real_missing_resource_link_uid_and_card_doc_fail(self):
        self.write('scripts/broken.gd', 'var broken = "res://missing.wav"')
        self.write('docs/broken.md', '[broken](absent.md)')
        self.write('scripts/orphan.gd.uid', 'uid://dummy')
        (self.root / 'docs/units/example.md').unlink()
        errors = audit(self.root)['errors']
        self.assertEqual(len(errors), 4, errors)

    def test_gnar_requires_both_reader_facing_forms(self):
        self.write('scripts/data/card_db.gd', 'preload("res://scripts/data/cards/gnar.gd")')
        (self.root / 'scripts/data/cards/example.gd').unlink()
        (self.root / 'docs/units/example.md').unlink()
        self.write('scripts/data/cards/gnar.gd', 'extends RefCounted\n')
        self.write('docs/units/gnar_small.md', '# 小纳尔\n')
        self.write('docs/units/gnar_mega.md', '# 大纳尔\n')
        self.write('docs/units/arena.md', '# 竞技场\n')
        self.assertEqual(audit(self.root)['errors'], [])
        (self.root / 'docs/units/gnar_mega.md').unlink()
        self.assertEqual(audit(self.root)['errors'], ['card registry/document mismatch: gnar_mega'])

    def test_development_library_is_ignored_but_runtime_references_fail(self):
        self.write('ClashLegends-开发素材库/.gdignore', '')
        self.write('ClashLegends-开发素材库/03-制作中/model.png', 'candidate')
        self.write('ClashLegends-开发素材库/04-中间产物/preview/model.png.import', 'local cache')
        self.assertEqual(audit(self.root)['errors'], [])
        self.write('scripts/invalid.gd', 'var image = "res://ClashLegends-开发素材库/03-制作中/model.png"')
        self.assertTrue(any('non-runtime resource' in error for error in audit(self.root)['errors']))
        self.write('assets/archive/old.gd', 'var source = "res://retired.png"')
        self.assertTrue(any('assets/archive: development content' in error for error in audit(self.root)['errors']))


if __name__ == '__main__':
    unittest.main()
