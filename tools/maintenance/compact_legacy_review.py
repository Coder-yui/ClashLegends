"""One explicit, pinned migration of an already bit-verified CLPS.

No source parsing, decompression or automatic review renewal. This is not a
general legacy-cache fallback. A different source/product is a real dirty job;
a matching legacy product with an unreviewed tool transition is an error.
"""
import ast
import json

import compact_samples
import resource_build_records as records

REVIEW = 'tools/source_assets/compact_reviews/void_summoning_v2.json'


def function_identity(path, name):
    tree = ast.parse(path.read_text())
    node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == name)
    return records.key(ast.dump(node, include_attributes=False))


def migrate(root, snapshot, desired, old):
    review_path = root / REVIEW
    if old is None or not review_path.is_file(): return None
    review = json.loads(review_path.read_text())
    source_sha = snapshot[records.COMPACT_SOURCE]
    old_sha = old.get('binary_artifacts', {}).get(records.COMPACT_OUTPUT)
    if source_sha != review.get('source_sha256') or old_sha != review.get('product_sha256'):
        return None
    expected = review.get('accepted_tools', {})
    for name, sha in expected.items():
        if not (root / name).is_file() or records.digest(root / name) != sha:
            raise ValueError('Legacy compact transition not reviewed for current tool: ' + name)
    if not expected or review.get('schema') != 1 or not review.get('evidence') or not review.get('limitations'):
        raise ValueError('Incomplete explicit compact migration review')
    if records.digest(root / 'tools/generated/effect_artifacts.json') != review['legacy_index_sha256']:
        raise ValueError('Legacy compact index identity differs from reviewed receipt')
    if old.get('inputs', {}).get('tools/maintenance/compact_samples.py') != review['legacy_codec_sha256']:
        raise ValueError('Legacy compact producer identity differs')
    if old.get('inputs', {}).get(records.COMPACT_SOURCE) != source_sha:
        raise ValueError('Legacy compact source identity differs')
    for name, sha in review['accepted_function_identities'].items():
        if function_identity(root / 'tools/maintenance/compact_samples.py', name) != sha:
            raise ValueError('Legacy compact reviewed function differs: ' + name)
    validation = old.get('compact_validation')
    if validation != review['legacy_exact_validation']:
        raise ValueError('Legacy compact full-bit evidence differs')
    path = root / records.COMPACT_OUTPUT
    if not path.is_file() or records.digest(path) != old_sha:
        raise ValueError('Legacy compact content differs; no migration')
    header = compact_samples.read_header(path)
    if (header['source_sha256'] != source_sha or header['source'] != 'res://' + records.COMPACT_SOURCE
            or header['payload_sha256'] != review['payload_sha256']
            or any(header[k] != validation[k] for k in ['frames', 'layers', 'rows', 'width'])
            or header['payload_bytes'] != validation['decoded_typed_bytes']
            or path.stat().st_size != validation['packed_bytes']
            or (root / records.COMPACT_SOURCE).stat().st_size != validation['source_bytes']):
        raise ValueError('Legacy compact header/report binding differs')
    return records.complete(desired, path, validation, origin='reviewed-legacy-v1', evidence={
        'review': REVIEW, 'review_sha256': records.digest(review_path),
        'legacy_index_sha256': review['legacy_index_sha256'],
        'legacy_codec_sha256': review['legacy_codec_sha256'],
        'accepted_codec_sha256': snapshot['tools/maintenance/compact_samples.py'],
        'core_equivalence': review['core_equivalence'], 'evidence': review['evidence'],
        'limitations': review['limitations'], 'new_full_source_validation': False})
