import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import importlib.util
import subprocess
import resource_artifacts as artifacts

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'release'))
import pck_audit


from resource_contracts import make_pack


class ArtifactTests(unittest.TestCase):
    def test_model_source_settings_and_generated_bytes_invalidate(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); index = self.fixture(root)
            source = root / 'assets/units/example/source/model.glb'
            source.parent.mkdir(parents=True); source.write_bytes(b'model')
            settings = Path(str(source) + '.import'); settings.write_text('dest_files=["res://.godot/imported/model.scn"]\n')
            output = root / 'assets/generated/model_templates/example.res'
            output.parent.mkdir(parents=True); output.write_bytes(b'product')
            recipe = root / 'tools/source_assets/model_recipes/example.json'
            recipe.parent.mkdir(parents=True); recipe.write_text(artifacts.canonical(dict(schema=1, source='res://assets/units/example/source/model.glb', output='res://assets/generated/model_templates/example.res', import_settings_sha256=artifacts.digest(settings))))
            index.update(inputs=artifacts.inputs(root), model_artifacts={output.relative_to(root).as_posix(): artifacts.digest(output)})
            index['policy_sha256'] = artifacts.policy_digest(index['inputs'])
            self.stamp_records(root, index)
            (root / artifacts.INDEX).write_text(artifacts.canonical(index))
            self.assertEqual(artifacts.check(root), [])
            for path in [source, settings, output]:
                before = path.read_bytes(); stamp = path.stat(); path.write_bytes(b'x' * len(before))
                os.utime(path, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
                self.assertTrue(artifacts.check(root), str(path))
                path.write_bytes(before)
            (output.parent / 'orphan.res').write_bytes(b'orphan')
            self.assertIn('Missing/orphan model template artifacts', artifacts.check(root))

    def test_model_write_rejects_stale_import_and_unreviewed_settings(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            name = 'assets/units/example/source/model.glb'
            source = root / name; source.parent.mkdir(parents=True); source.write_bytes(b'model')
            imported = root / '.godot/imported/model.scn'; imported.parent.mkdir(parents=True); imported.write_bytes(b'imported')
            settings = Path(str(source) + '.import'); settings.write_text('dest_files=["res://.godot/imported/model.scn"]\n')
            sidecar = imported.parent / (source.name + '-' + hashlib.md5(('res://' + name).encode()).hexdigest() + '.md5')
            sidecar.write_text('source_md5="' + hashlib.md5(source.read_bytes()).hexdigest() + '"\ndest_md5="' + hashlib.md5(imported.read_bytes()).hexdigest() + '"\n')
            recipe = root / 'tools/source_assets/model_recipes/example.json'; recipe.parent.mkdir(parents=True)
            recipe.write_text(artifacts.canonical(dict(source='res://' + name, import_settings_sha256=artifacts.digest(settings))))
            self.assertEqual(artifacts.check_model_imports(root), [])
            stamp = imported.stat(); imported.write_bytes(b'corrupt!'); os.utime(imported, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
            self.assertIn('dest_md5 mismatch', '\n'.join(artifacts.check_model_imports(root)))
            self.assertIn('dest_md5 mismatch', '\n'.join(artifacts.check_model_imports(root, require_cache=False)))
            imported.write_bytes(b'imported')
            source.write_bytes(b'other')
            self.assertIn('needs Godot editor reimport', '\n'.join(artifacts.check_model_imports(root)))
            source.write_bytes(b'model'); settings.write_text(settings.read_text() + 'changed=true\n')
            self.assertIn('explicitly review recipe pin', '\n'.join(artifacts.check_model_imports(root)))

    def test_model_import_dest_md5_covers_all_formats_in_order(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); source = root / 'assets/units/model/source/a.glb'
            source.parent.mkdir(parents=True); source.write_bytes(b'source')
            targets = [root / '.godot/imported/a.first', root / '.godot/imported/a.second']
            targets[0].parent.mkdir(parents=True)
            for target, data in zip(targets, [b'first', b'second']): target.write_bytes(data)
            settings = Path(str(source) + '.import')
            settings.write_text('dest_files=["res://.godot/imported/a.first","res://.godot/imported/a.second"]\n')
            recipe = root / 'tools/source_assets/model_recipes/a.json'; recipe.parent.mkdir(parents=True)
            recipe.write_text(artifacts.canonical(dict(source='res://assets/units/model/source/a.glb', import_settings_sha256=artifacts.digest(settings))))
            sidecar = root / '.godot/imported' / ('a.glb-' + hashlib.md5(b'res://assets/units/model/source/a.glb').hexdigest() + '.md5')
            sidecar.write_text('source_md5="' + hashlib.md5(b'source').hexdigest() + '"\ndest_md5="' + hashlib.md5(b'firstsecond').hexdigest() + '"\n')
            self.assertEqual(artifacts.check_model_imports(root), [])
            targets[1].write_bytes(b'SECOND')
            self.assertIn('dest_md5 mismatch', '\n'.join(artifacts.check_model_imports(root)))
            for target in targets: target.unlink()
            sidecar.unlink()
            self.assertEqual(artifacts.check_model_imports(root, require_cache=False), [])
            self.assertIn('needs Godot editor reimport', '\n'.join(artifacts.check_model_imports(root)))

    def stamp_records(self, root, index):
        r = artifacts.records
        snapshot = index['inputs']
        previous = index.setdefault('build_records', {})
        for output in index['artifacts']:
            entry = json.loads((root / output).read_text())
            desired = r.manifest_spec(snapshot, output, entry)
            previous[output] = r.complete(desired, root / output, {'fixture': 'resolved'})
        for name, desired in r.model_specs(root, snapshot).items():
            previous[desired['output']] = r.complete(desired, root / desired['output'], {'clips': {}, 'meshes': []})
            index.setdefault('model_templates', {})[name] = {'source': 'fixture', 'output': 'res://' + desired['output'], 'clips': {}, 'meshes': []}
        index['build_records_schema'] = 1
        return index

    def fixture(self, root):
        import resource_offline_worker
        import shutil
        r = artifacts.records
        names = set(artifacts.GENERATOR_FILES + r.MODEL_PRODUCERS + r.MANIFEST_PRODUCERS +
                    ['project.godot', 'godot-version.txt', 'scripts/data/cards/new.gd',
                     'assets/effects/player.gd', 'assets/effects/strategy.gdshader'])
        for name in names:
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('fixture')
        (root / artifacts.coverage_reviews.RECORD).write_text('{"schema":1,"reviews":[]}')
        data = dict(fps=30, emitters=[{'name': 'one'}], frames=[[[[2**54+1,-0.0,0.1,1.0]]]])
        for name in [r.COMPACT_SOURCE, 'assets/effects/sampled.json']:
            path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data))
        (root / 'export_presets.cfg').write_text('include_filter="assets/generated/effect_dependencies/*.json,assets/effects/*.json"\nexclude_filter="tools/*"\n')
        output = root / artifacts.DIRECTORY / 'fixture.json'; output.parent.mkdir(parents=True)
        entry = dict(provider='res://assets/effects/player.gd', variant='fixture',
                     selection={'json':['res://assets/effects/sampled.json']}, resources=[], raw=['res://assets/effects/sampled.json'])
        snapshot=artifacts.inputs(root)
        desired=r.manifest_spec(snapshot, output.relative_to(root).as_posix(), entry)
        entry.update(schema=artifacts.SCHEMA,generator=artifacts.GENERATOR,policy=artifacts.POLICY,policy_sha256=r.key(desired),
                     source_identity={'res://'+p:sha for p,sha in desired['sources'].items()})
        output.write_text(artifacts.canonical(entry))
        plan=artifacts.offline_plan(root,snapshot,None)
        stage=root/'fixture-build'
        report=resource_offline_worker.prepare(root,stage,plan,pulse=lambda _phase:None)
        for target, relative in report['files'].items():
            path=root/target;path.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(stage/relative,path)
        compact=report['records'][r.COMPACT_OUTPUT]
        index=dict(schema=artifacts.SCHEMA,generator=artifacts.GENERATOR,policy=artifacts.POLICY,inputs=snapshot,
                   policy_sha256=artifacts.policy_digest(snapshot),artifacts={output.relative_to(root).as_posix():artifacts.digest(output)},
                   binary_artifacts={r.COMPACT_OUTPUT:compact['product']['sha256']},compact_validation=compact['validation']['result'],
                   compact_validation_origin='built',model_artifacts={},model_templates={},build_records=report['records'],
                   runtime_raw=['res://'+output.relative_to(root).as_posix(),'res://assets/effects/sampled.json'])
        self.stamp_records(root,index)
        path=root/artifacts.INDEX;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(artifacts.canonical(index))
        return index

    def test_content_changes_new_files_missing_and_corrupt_outputs_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); self.fixture(root)
            self.assertEqual(artifacts.check(root), [])
            for name in ['assets/effects/sampled.json', 'assets/effects/player.gd', 'assets/effects/strategy.gdshader', 'scripts/data/cards/new.gd']:
                path = root / name; original = path.read_bytes(); stamp = path.stat(); path.write_bytes(b'x' * len(original))
                os.utime(path, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
                self.assertEqual(path.stat().st_size, stamp.st_size)
                self.assertIn('Stale resource artifacts', '\n'.join(artifacts.check(root)))
                path.write_bytes(original)
            extra = root / 'assets/effects/added.gd'; extra.write_text('new provider')
            self.assertTrue(artifacts.check(root)); extra.unlink()
            output = root / artifacts.DIRECTORY / 'fixture.json'
            output.write_text('[]')
            self.assertTrue(artifacts.check(root))
            output.unlink()
            self.assertTrue(artifacts.check(root))

    def test_check_rejects_index_schema_and_export_exclusion(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); index = self.fixture(root)
            index['schema'] = 0
            (root / artifacts.INDEX).write_text(artifacts.canonical(index))
            self.assertTrue(artifacts.check(root))
            index['schema'] = 1
            (root / artifacts.INDEX).write_text(artifacts.canonical(index))
            (root / 'export_presets.cfg').write_text('include_filter=""\nexclude_filter="tools/*"\n')
            self.assertTrue(artifacts.check(root))

    def test_native_pck_presence_exact_bytes_exclusion_and_bad_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); native = root / 'runtime.json'; native.write_bytes(b'raw')
            pack = root / 'test.pck'; index = dict(runtime_raw=['res://runtime.json'])
            make_pack(pack, {'runtime.json': b'raw'})
            self.assertTrue(pck_audit.audit(pack, root, index)['passed'])
            for files in [{}, {'runtime.json': b'bad'}, {'runtime.json': b'raw', 'tools/source_assets/source.json': b'source'}]:
                make_pack(pack, files)
                with self.assertRaises(ValueError): pck_audit.audit(pack, root, index)
            pack.write_bytes(b'GDPC' + b'\0' * 40)
            with self.assertRaises(ValueError): pck_audit.entries(pack)

    def test_real_entrypoints_call_check_before_engine_export(self):
        root = artifacts.ROOT
        release = (root / 'tools/release/export_macos.py').read_text()
        self.assertLess(release.index("'--check'"), release.index("'--export-release'"))
        self.assertIn("report['pck_audit'] = audit_pck", release)
        self.assertIn('func _build() -> bool:', (root / 'addons/resource_artifacts/plugin.gd').read_text())
        self.assertIn('res://addons/resource_artifacts/plugin.cfg', (root / 'project.godot').read_text())
        sys.path.insert(0, str(root / 'tools'))
        import verify
        catalog = (root / 'tests/suite_catalog.json').read_text()
        for changed in ['assets/effects/strategy.gdshader', 'scripts/data/cards/garen.gd', 'tools/source_assets/void_summoning/sampled.json']:
            plan = verify.verification_plan(root, catalog, [changed], suites=['DependencyHeaderSuite'])
            commands = verify.planned_commands(plan, None, Path('/tmp/unused'))
            self.assertTrue(any('tools/maintenance/resource_artifacts.py' in command and '--check' in command for _, command in commands))

    def test_actual_release_entry_stops_at_failed_check_without_engine(self):
        spec = importlib.util.spec_from_file_location('artifact_release_test', artifacts.ROOT / 'tools/release/export_macos.py')
        release = importlib.util.module_from_spec(spec); spec.loader.exec_module(release)
        with patch.object(sys, 'argv', ['export_macos.py', '--godot', 'must-not-launch']), \
             patch.object(release.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'check')) as check, \
             patch.object(release.subprocess, 'check_output') as engine:
            with self.assertRaises(subprocess.CalledProcessError): release.main()
            self.assertIn('tools/maintenance/resource_artifacts.py', check.call_args.args[0][1])
            self.assertEqual(check.call_args.args[0][-1], '--check')
            engine.assert_not_called()

    def test_workbench_entry_stops_at_failed_check(self):
        spec = importlib.util.spec_from_file_location('artifact_dev_test', artifacts.ROOT / 'tools/dev.py')
        dev = importlib.util.module_from_spec(spec); spec.loader.exec_module(dev)
        with patch.object(sys, 'argv', ['dev.py', 'workbench']), \
             patch.object(dev.subprocess, 'call', return_value=1) as calls:
            self.assertEqual(dev.main(), 1)
            self.assertEqual(calls.call_count, 1)
            self.assertEqual(calls.call_args.args[0][-1], '--check')

    def test_release_bad_pck_records_original_error_and_stops_before_smoke(self):
        spec = importlib.util.spec_from_file_location('artifact_bad_pack_release_test', artifacts.ROOT / 'tools/release/export_macos.py')
        release = importlib.util.module_from_spec(spec); spec.loader.exec_module(release)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'godot-version.txt').write_text('fixture-engine\n')
            index = root / 'tools/generated/effect_artifacts.json'
            index.parent.mkdir(parents=True)
            index.write_text(json.dumps({'runtime_raw': []}))
            templates = root / 'Library/Application Support/Godot/export_templates/4.7.1.stable'
            templates.mkdir(parents=True)
            (templates / 'version.txt').write_text('4.7.1.stable')
            (templates / 'macos.zip').write_bytes(b'fixture-template')
            def fake_step(name, command, *_args):
                if name == 'export':
                    app = Path(command[-1])
                    app.mkdir(parents=True)
                    (app / 'fixture.pck').write_bytes(b'BAD!')
                return {'name': name, 'passed': True}
            identity = {'content_sha256': 'unchanged-fixture'}
            with patch.object(release, 'ROOT', root), \
                 patch.object(sys, 'argv', ['export_macos.py', '--godot', 'must-not-launch']), \
                 patch.object(release.Path, 'home', return_value=root), \
                 patch.object(release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as precheck, \
                 patch.object(release.subprocess, 'check_output', return_value='fixture-engine\n'), \
                 patch.object(release.verify, 'identity', return_value=identity), \
                 patch.object(release.verify, 'run_step', side_effect=fake_step) as steps:
                self.assertEqual(release.main(), 1)
            results = list(root.rglob('result.json'))
            self.assertEqual(len(results), 1)
            result = json.loads(results[0].read_text())
            self.assertFalse(result['passed'])
            self.assertEqual(result['error'], 'Not a standalone native PCK')
            self.assertEqual([step['name'] for step in result['steps']], ['import', 'export'])
            self.assertEqual(result['identity_before'], identity)
            self.assertEqual(result['identity_after'], identity)
            self.assertEqual(steps.call_count, 2)
            self.assertEqual(precheck.call_count, 1)

if __name__ == '__main__': unittest.main()
