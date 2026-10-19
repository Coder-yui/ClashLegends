"""Tiny fixtures only: real codec/jobs, mocked engine, no project samples/Godot."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import compact_legacy_review
import resource_artifacts as artifacts
import resource_build_records as records
import resource_offline_worker as worker
import test_resource_artifacts as artifact_tests


class IncrementalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        self.index = artifact_tests.ArtifactTests().fixture(self.root)
        self.events = []
    def tearDown(self): self.temp.cleanup()

    def engine(self, _script, args, _folder):
        self.events.append('engine')
        jobs = json.loads(Path(args[2]).read_text())['models']
        entries = {Path(p).name: {k: json.loads((self.root/p).read_text())[k]
                                   for k in ['provider','variant','selection','resources','raw']}
                   for p in self.index['artifacts']}
        products, reports = {}, {}
        for name in jobs:
            recipe = json.loads((self.root/'tools/source_assets/model_recipes'/name).read_text())
            output = recipe['output'].removeprefix('res://');path=self.root/output
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(('tiny model '+records.key(recipe)).encode())
            products[output] = records.digest(path)
            reports[name] = {'source':recipe['source'],'output':recipe['output'],'clips':{},'meshes':[]}
        Path(args[1]).write_text(json.dumps({'definitions':1,'entries':entries,
                                           'model_templates':{'artifacts':products,'models':reports}}))

    def offline(self, arguments, folder, **_kwargs):
        self.events.append('offline')
        plan = json.loads(Path(arguments[arguments.index('--plan')+1]).read_text())
        worker.prepare(self.root,folder,plan,pulse=lambda _phase:None)
        self.events.append('offline-exit-cleanup')
        return {'pid':os.getpid(),'passed':True,'cleanup':{'confirmed':True}}

    def generate(self):
        with patch.object(artifacts.coverage_reviews,'check_sources',return_value=[]), \
             patch.object(artifacts.coverage_reviews,'check_entries',return_value=[]), \
             patch.object(artifacts,'check_model_imports',return_value=[]), \
             patch.object(artifacts,'guarded_process',side_effect=self.offline) as offline, \
             patch.object(artifacts,'guarded_engine',side_effect=self.engine) as engine:
            artifacts.generate(self.root)
        return offline,engine

    def actions(self):
        paths=sorted(self.root.glob('ClashLegends-开发素材库/04-中间产物/构建与验证/resource-artifacts/*/actions.json'))
        return json.loads(paths[-1].read_text())

    def change_source(self):
        path=self.root/records.COMPACT_SOURCE;path.write_bytes(path.read_bytes()+b' ')

    def add_model(self):
        source=self.root/'assets/units/example/source/model.glb';source.parent.mkdir(parents=True);source.write_bytes(b'model')
        cached=self.root/'.godot/imported/model.scn';cached.parent.mkdir(parents=True);cached.write_bytes(b'imported')
        settings=Path(str(source)+'.import');settings.write_text('dest_files=["res://.godot/imported/model.scn"]\n')
        sidecar=cached.parent/(source.name+'-'+hashlib.md5(('res://'+source.relative_to(self.root).as_posix()).encode()).hexdigest()+'.md5')
        sidecar.write_text('source_md5="'+hashlib.md5(source.read_bytes()).hexdigest()+'"\ndest_md5="'+hashlib.md5(cached.read_bytes()).hexdigest()+'"\n')
        recipe=self.root/'tools/source_assets/model_recipes/example.json';recipe.parent.mkdir(parents=True)
        recipe.write_text(json.dumps({'schema':1,'source':'res://'+source.relative_to(self.root).as_posix(),
                                    'output':'res://assets/generated/model_templates/example.res',
                                    'import_settings_sha256':records.digest(settings),'cards':[]}))
        output=self.root/'assets/generated/model_templates/example.res';output.parent.mkdir(parents=True);output.write_bytes(b'old model')
        index=artifacts.read_index(self.root);index['inputs']=artifacts.inputs(self.root)
        index['policy_sha256']=artifacts.policy_digest(index['inputs']);index['model_artifacts']={output.relative_to(self.root).as_posix():records.digest(output)}
        artifact_tests.ArtifactTests().stamp_records(self.root,index)
        (self.root/artifacts.INDEX).write_text(artifacts.canonical(index));self.index=index
        return recipe,output

    def test_noop_starts_no_worker_or_engine_and_preserves_index_bytes(self):
        path=self.root/artifacts.INDEX;before=path.read_bytes()
        offline,engine=self.generate();offline.assert_not_called();engine.assert_not_called()
        self.assertEqual(path.read_bytes(),before);self.assertTrue(self.actions()['noop'])

    def test_model_only_never_reads_sample_document_or_starts_worker(self):
        recipe,output=self.add_model();before=(self.root/records.COMPACT_OUTPUT).read_bytes()
        value=json.loads(recipe.read_text());value['review_change']='remove-full';recipe.write_text(json.dumps(value))
        with patch.object(worker.compact_samples,'read_document',side_effect=AssertionError('unrelated numeric source parsed')):
            offline,engine=self.generate()
        offline.assert_not_called();engine.assert_called_once()
        self.assertEqual((self.root/records.COMPACT_OUTPUT).read_bytes(),before)
        self.assertEqual(self.actions()['actions'][records.COMPACT_OUTPUT],'reuse')
        self.assertEqual(self.actions()['actions'][output.relative_to(self.root).as_posix()],'build')
        self.assertEqual(self.actions()['dependency_changes'],[])
        self.assertEqual(artifacts.check(self.root),[])

    def test_source_change_builds_only_related_offline_products_in_order(self):
        self.change_source();offline,engine=self.generate()
        offline.assert_called_once();engine.assert_called_once()
        self.assertEqual(self.events,['offline','offline-exit-cleanup','engine'])
        actions=self.actions()['actions']
        self.assertEqual(actions[records.COMPACT_OUTPUT],'build')
        self.assertEqual(actions[records.projection_path(records.COMPACT_SOURCE)],'build')
        self.assertEqual(actions[records.projection_path('assets/effects/sampled.json')],'reuse')
        self.assertEqual(artifacts.check(self.root),[])

    def test_compiler_change_rebuilds_model_without_offline_work(self):
        _, output = self.add_model()
        path = self.root / 'scripts/data/card_definition_compiler.gd'
        stamp = path.stat(); path.write_text('changed visual/form compilation')
        os.utime(path, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        self.assertIn('Stale resource artifacts', '\n'.join(artifacts.check(self.root)))
        offline, engine = self.generate()
        offline.assert_not_called(); engine.assert_called_once()
        actions = self.actions()['actions']
        self.assertEqual(actions[output.relative_to(self.root).as_posix()], 'build')
        self.assertEqual(actions[records.COMPACT_OUTPUT], 'reuse')
        self.assertTrue(all(action == 'reuse' for name, action in actions.items()
                            if name.startswith(records.PROJECTION_DIR)))
        self.assertEqual(artifacts.check(self.root), [])

    def test_model_key_covers_compiler_and_own_card_but_not_unrelated_inputs(self):
        recipe, _ = self.add_model()
        value = json.loads(recipe.read_text()); value['cards'] = ['new']
        recipe.write_text(json.dumps(value))
        before = artifacts.inputs(self.root)
        desired = records.model_specs(self.root, before)['example.json']
        for name in ['scripts/data/card_definition_compiler.gd', 'scripts/data/cards/new.gd']:
            changed = dict(before); changed[name] = '0' * 64
            self.assertNotEqual(records.model_specs(self.root, changed)['example.json'], desired)
        changed = dict(before); changed['assets/effects/strategy.gdshader'] = '0' * 64
        changed['scripts/data/cards/unrelated.gd'] = '0' * 64
        self.assertEqual(records.model_specs(self.root, changed)['example.json'], desired)
        missing = dict(before); missing.pop('scripts/data/card_definition_compiler.gd')
        with self.assertRaisesRegex(ValueError, 'Missing declared product input'):
            records.model_specs(self.root, missing)

    def test_relevant_producer_change_rebuilds_even_with_same_source_and_mtime(self):
        path=self.root/'tools/maintenance/compact_samples.py';stamp=path.stat();path.write_text('changed')
        os.utime(path,ns=(stamp.st_atime_ns,stamp.st_mtime_ns))
        offline,_=self.generate();offline.assert_called_once()
        self.assertEqual(self.actions()['actions'][records.COMPACT_OUTPUT],'build')

    def test_corrupt_compact_content_same_size_restored_mtime_cannot_reuse(self):
        path=self.root/records.COMPACT_OUTPUT;before=path.read_bytes();stamp=path.stat()
        path.write_bytes(b'x'*len(before));os.utime(path,ns=(stamp.st_atime_ns,stamp.st_mtime_ns))
        offline,_=self.generate();offline.assert_called_once()
        self.assertEqual(path.read_bytes(),before)

    def test_missing_record_is_rebuilt_not_blessed_by_existing_product_sha(self):
        index=artifacts.read_index(self.root);index['build_records'].pop(records.COMPACT_OUTPUT)
        (self.root/artifacts.INDEX).write_text(artifacts.canonical(index))
        offline,_=self.generate();offline.assert_called_once()
        self.assertEqual(self.actions()['actions'][records.COMPACT_OUTPUT],'build')

    def test_missing_projection_only_builds_that_source_and_uses_authenticated_clps_header(self):
        path=self.root/records.projection_path(records.COMPACT_SOURCE);path.unlink()
        with patch.object(worker.compact_samples,'read_document',side_effect=AssertionError('compact source parsed')):
            offline,_=self.generate()
        offline.assert_called_once()
        actions=self.actions()['actions'];self.assertEqual(actions[records.COMPACT_OUTPUT],'reuse')
        self.assertEqual(sum(a=='build' for p,a in actions.items() if p.startswith(records.PROJECTION_DIR)),1)

    def test_engine_failure_keeps_verified_dirty_products_staged_and_old_index(self):
        self.change_source();path=self.root/records.COMPACT_OUTPUT;old=path.read_bytes();receipt=(self.root/artifacts.INDEX).read_bytes()
        with patch.object(artifacts.coverage_reviews,'check_sources',return_value=[]), \
             patch.object(artifacts,'check_model_imports',return_value=[]), \
             patch.object(artifacts,'guarded_process',side_effect=self.offline), \
             patch.object(artifacts,'guarded_engine',side_effect=RuntimeError('engine refused')):
            with self.assertRaisesRegex(RuntimeError,'engine refused'):artifacts.generate(self.root)
        self.assertEqual(path.read_bytes(),old);self.assertEqual((self.root/artifacts.INDEX).read_bytes(),receipt)

    def test_partial_publication_failure_retains_old_index_then_revalidates_on_recovery(self):
        self.change_source();path=self.root/artifacts.INDEX;old=path.read_bytes();write=artifacts.atomic_json
        def fail_index(target,value):
            if Path(target)==path:raise OSError('index replace failed')
            return write(target,value)
        with patch.object(artifacts,'atomic_json',side_effect=fail_index):
            with self.assertRaisesRegex(OSError,'index replace'):self.generate()
        self.assertEqual(path.read_bytes(),old)
        offline,_=self.generate();offline.assert_called_once()
        self.assertEqual(artifacts.check(self.root),[])

    def test_worker_report_wrong_pid_or_changed_staged_content_is_rejected(self):
        self.change_source();before=artifacts.inputs(self.root);plan=artifacts.offline_plan(self.root,before,self.index)
        folder=self.root/'small-worker';result=worker.prepare(self.root,folder,plan,pulse=lambda _phase:None)
        artifacts.offline_report(self.root,folder,before,os.getpid(),plan)
        with self.assertRaisesRegex(ValueError,'identity'):artifacts.offline_report(self.root,folder,before,os.getpid()+1,plan)
        (folder/result['files'][records.COMPACT_OUTPUT]).write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError,'identity'):artifacts.offline_report(self.root,folder,before,os.getpid(),plan)

    def test_tiny_real_worker_exits_reaped_with_same_plan_and_main_thread_heartbeat(self):
        self.change_source();plan=artifacts.offline_plan(self.root,artifacts.inputs(self.root),self.index)
        path=self.root/'plan.json';path.write_text(json.dumps(plan));pulse=self.root/'heartbeat.json'
        env=dict(os.environ,CLASH_SAFE_PROBE_HEARTBEAT=str(pulse),CLASH_SAFE_PROBE_TOKEN='tiny-fixture',CLASH_SAFE_PROBE_PARENT_PID=str(os.getpid()))
        output=self.root/'worker-process'
        result=subprocess.run([sys.executable,str(artifacts.ROOT/'tools/maintenance/resource_offline_worker.py'),
                               '--root',str(self.root),'--output',str(output),'--plan',str(path)],env=env,capture_output=True,text=True,timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)
        report=json.loads((output/'report.json').read_text());pid=report['worker_pid']
        self.assertNotEqual(pid,os.getpid())
        with self.assertRaises(ProcessLookupError):os.kill(pid,0)
        self.assertTrue(json.loads(pulse.read_text())['ready'])

    def test_reviewed_legacy_receipt_is_explicit_and_rejects_tool_or_content_changes(self):
        codec='tools/maintenance/compact_samples.py'
        (self.root/codec).write_bytes((artifacts.ROOT/codec).read_bytes())
        old=copy.deepcopy(self.index);old.pop('build_records');old.pop('build_records_schema')
        (self.root/artifacts.INDEX).write_text(artifacts.canonical(old))
        path=self.root/compact_legacy_review.REVIEW;path.parent.mkdir(parents=True)
        header=artifacts.compact_samples.read_header(self.root/records.COMPACT_OUTPUT)
        review=dict(schema=1,source_sha256=old['inputs'][records.COMPACT_SOURCE],product_sha256=old['binary_artifacts'][records.COMPACT_OUTPUT],
                    legacy_index_sha256=records.digest(self.root/artifacts.INDEX),legacy_codec_sha256=old['inputs'][codec],
                    accepted_tools={codec:records.digest(self.root/codec)},
                    accepted_function_identities={name:compact_legacy_review.function_identity(self.root/codec,name) for name in ['encode_document','decode','verify_document']},
                    legacy_exact_validation=old['compact_validation'],payload_sha256=header['payload_sha256'],
                    core_equivalence={'fixture':True},evidence={'fixture':'tiny actual bit validation'},limitations=['not a full-source run'])
        path.write_text(json.dumps(review));snapshot=artifacts.inputs(self.root)
        desired=records.compact_spec(snapshot)
        migrated=compact_legacy_review.migrate(self.root,snapshot,desired,old)
        self.assertEqual(migrated['origin'],'reviewed-legacy-v1');self.assertFalse(migrated['evidence']['new_full_source_validation'])
        (self.root/codec).write_text('unreviewed')
        with self.assertRaisesRegex(ValueError,'not reviewed'):compact_legacy_review.migrate(self.root,snapshot,desired,old)


if __name__=='__main__':unittest.main()
