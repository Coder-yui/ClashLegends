import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import coverage_reviews as reviews
import resource_artifacts as artifacts
import compact_samples


class CoverageReviewTests(unittest.TestCase):
    def fixture(self, root):
        provider = 'assets/effects/fixture/player.gd'
        shader = 'assets/effects/fixture/beam.gdshader'
        paths = reviews.COMMON | {provider, shader}
        for name in paths:
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('uniform float elapsed; // reviewed fixed topology')
        (root / provider).write_text('extends Node3D\nfunc seek(age):\n\tpass\n')
        (root / shader).write_text('shader_type spatial;\nuniform float elapsed = 0.0;\nvoid fragment() { ALBEDO = vec3(elapsed); }\n')
        sample = dict(player='res://' + provider, setup='provider_sample', coverage=dict(
            strategy=reviews.STRATEGY, states=[dict(shader='res://' + shader)]))
        record = dict(provider='res://' + provider, variant='beam', sample_sha256=reviews.sample_digest(sample),
                      inputs={name: reviews.digest(root / name) for name in paths},
                      evidence=['fixture-only'], limitations='not a continuous-time proof')
        registry = root / reviews.RECORD; registry.parent.mkdir(parents=True, exist_ok=True)
        registry.write_text(json.dumps(dict(schema=1, reviews=[record])))
        entry = dict(provider=record['provider'], variant='beam', selection=dict(sample=sample))
        return provider, shader, registry, entry

    def test_late_layer_and_same_uniform_semantic_changes_cannot_be_regenerated_into_approval(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            provider, shader, registry, entry = self.fixture(root)
            self.assertEqual(reviews.check_entries(root, [entry]), [])
            original_record = registry.read_bytes()
            for name in [provider, shader]:
                path = root / name; original = path.read_bytes()
                changed = (original + b'\nfunc late(age):\n\tif age > 0.5:\n\t\tadd_child(MeshInstance3D.new())\n' if name == provider else original.replace(b'vec3(elapsed)', b'vec3(step(0.5, elapsed))'))
                path.write_bytes(changed)
                self.assertIn('Coverage review stale', '\n'.join(reviews.check_sources(root)))
                # Real --write entry fails BEFORE expensive generation or any engine.
                with patch.object(compact_samples, 'encode') as encode, patch.object(artifacts, 'guarded_engine') as engine:
                    with self.assertRaisesRegex(ValueError, 'Coverage review stale'):
                        artifacts.generate(root)
                    encode.assert_not_called(); engine.assert_not_called()
                self.assertEqual(registry.read_bytes(), original_record)
                path.write_bytes(original)

    def test_unrelated_changes_do_not_revoke_review(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); _, _, _, entry = self.fixture(root)
            path = root / 'scripts/unrelated.gd'; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('unrelated change')
            self.assertEqual(reviews.check_entries(root, [entry]), [])

    def test_missing_review_setup_change_and_omitted_shader_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); _, shader, registry, entry = self.fixture(root)
            entry['selection']['sample']['setup'] = 'native'
            self.assertTrue(reviews.check_entries(root, [entry]))
            _, _, _, entry = self.fixture(root)
            value = json.loads(registry.read_text()); value['reviews'][0]['inputs'].pop(shader)
            registry.write_text(json.dumps(value))
            self.assertTrue(reviews.check_entries(root, [entry]))
            registry.write_text('{"schema":1,"reviews":[]}')
            self.assertIn('no explicit review', '\n'.join(reviews.check_entries(root, [entry])))



class SampledReviewTests(unittest.TestCase):
    def test_sampled_include_mesh_and_declaration_are_independently_pinned(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            provider, shader, registry, entry = CoverageReviewTests().fixture(root)
            include = 'assets/effects/fixture/particle.gdshaderinc'
            source = 'assets/effects/fixture/sampled.json'
            mesh = 'assets/effects/fixture/mesh.json'
            (root / shader).write_text('shader_type spatial;\n#include "particle.gdshaderinc"\n')
            (root / include).write_text('void fragment() { ALPHA = 1.0; }')
            (root / source).write_text('{"frames":[]}')
            (root / mesh).write_text('{"vertices":[]}')
            for name in ['scripts/presentation/sampled_effect_coverage.gd',
                         'tools/maintenance/sampled_coverage_builder.gd', 'tools/maintenance/sampled_shader_contract.gd',
                         'tools/maintenance/generate_effect_artifacts.gd']:
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('fixture')
            entry['selection']['json'] = ['res://' + source]
            entry['raw'] = ['res://' + mesh]
            texture = 'assets/effects/fixture/texture.png'
            (root / texture).write_bytes(b'fixture texture')
            (root / (texture + '.import')).write_text('filter/mipmaps reviewed')
            entry['resources'] = ['res://' + texture]
            entry['selection']['sample']['coverage'] = dict(strategy=reviews.FIXED, layers=[dict(signature=dict(shader='res://' + shader))])
            value = json.loads(registry.read_text()); record = value['reviews'][0]
            names = set(record['inputs']) | {include, source, mesh, texture, texture + '.import',
                    'scripts/presentation/sampled_effect_coverage.gd',
                    'tools/maintenance/sampled_coverage_builder.gd', 'tools/maintenance/sampled_shader_contract.gd', 'tools/maintenance/generate_effect_artifacts.gd'}
            record['inputs'] = {name: reviews.digest(root / name) for name in names}
            record['sample_sha256'] = reviews.sample_digest(entry['selection']['sample'])
            registry.write_text(json.dumps(value))
            self.assertEqual(reviews.check_entries(root, [entry]), [])
            original = registry.read_bytes()
            for name in [include, source, mesh, texture, texture + ".import"]:
                path = root / name; before = path.read_bytes(); path.write_bytes(before + b'\nchanged')
                with patch.object(artifacts, 'guarded_engine') as engine:
                    with self.assertRaisesRegex(ValueError, 'Coverage review stale'): artifacts.generate(root)
                    engine.assert_not_called()
                path.write_bytes(before)
            self.assertEqual(registry.read_bytes(), original)
            record['inputs'].pop(include); registry.write_text(json.dumps(value))
            self.assertTrue(reviews.check_entries(root, [entry]))


if __name__ == "__main__": unittest.main()
