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
        self.write('docs/navigation.json', '{"card_documents": {"gnar": ["gnar_small", "gnar_mega"]}}')
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



class NavigationTests(AuditTests):
    def manifest(self, **values):
        import json
        self.write('docs/navigation.json', json.dumps(values))

    def test_anchor_accepts_unicode_duplicates_and_rejects_missing(self):
        self.write('docs/topic.md', '# 中文标题\n## A `code`\n## A `code`\n')
        self.write('README.md', '[ok](docs/topic.md#中文标题) [dup](docs/topic.md#a-code-1)')
        self.assertEqual(audit(self.root)['errors'], [])
        self.write('README.md', '[bad](docs/topic.md#absent)')
        self.assertTrue(any('broken anchor' in e for e in audit(self.root)['errors']))

    def test_historical_required_route_rejected(self):
        self.write('AGENTS.md', '[history](docs/archive/old.md)')
        self.write('docs/archive/old.md', '# 历史\nshroud 协议 1')
        self.manifest(routes={'default': ['docs/archive/old.md']})
        self.assertTrue(any('historical page marked required' in e for e in audit(self.root)['errors']))

    def test_current_page_reachable_without_historical_bridge(self):
        self.write('AGENTS.md', '[history](docs/archive/old.md)')
        self.write('docs/archive/old.md', '[current](../current.md)')
        self.write('docs/current.md', '# Current')
        self.manifest(current=['docs/current.md'])
        self.assertTrue(any('unreachable' in e for e in audit(self.root)['errors']))
        self.write('AGENTS.md', '[current](docs/current.md)')
        self.assertEqual(audit(self.root)['errors'], [])

    def test_historical_facts_allowed_but_links_still_checked(self):
        self.write('docs/deliveries/old.md', '# 历史\n<!-- current-fact: scripts/version.gd VERSION -->1\nshroud')
        self.manifest()
        self.assertEqual(audit(self.root)['errors'], [])
        self.write('docs/deliveries/old.md', '[broken](missing.md)')
        self.assertTrue(any('broken link' in e for e in audit(self.root)['errors']))

    def test_current_fact_matches_constant(self):
        self.write('scripts/version.gd', 'const VERSION := 44')
        self.write('docs/current.md', '<!-- current-fact: scripts/version.gd VERSION -->44')
        self.manifest()
        self.assertEqual(audit(self.root)['errors'], [])
        self.write('docs/current.md', '<!-- current-fact: scripts/version.gd VERSION -->43')
        self.assertTrue(any('current fact mismatch' in e for e in audit(self.root)['errors']))

    def test_new_form_uses_declarative_mapping(self):
        self.write('scripts/data/cards/example.gd', 'var data = {"transformed_stats": {}}')
        self.manifest()
        self.assertTrue(any('form/document mapping missing' in e for e in audit(self.root)['errors']))
        self.manifest(card_documents={'example': ['example', 'example_big']})
        self.assertTrue(any('card registry/document mismatch' in e for e in audit(self.root)['errors']))
        self.write('docs/units/example_big.md', '# Big')
        self.assertEqual(audit(self.root)['errors'], [])

    def test_production_retirement_and_schedule_boundary(self):
        self.write('scripts/old.gd', 'var shroud_radius = 1')
        self.assertTrue(any('retired production mechanism' in e for e in audit(self.root)['errors']))
        self.write('scripts/old.gd', '_commands._impacts.clear()')
        self.assertTrue(any('command schedule private state access' in e for e in audit(self.root)['errors']))
        self.write('scripts/old.gd', '_commands.clear_impacts()')
        self.assertEqual(audit(self.root)['errors'], [])

if __name__ == '__main__':
    unittest.main()
