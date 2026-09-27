"""Fail closed when manual values drift, markers disappear, or fields are unknown."""
import unittest
from check_card_facts import check_documents


class CardFactTests(unittest.TestCase):
    def setUp(self):
        self.payload = {'schema': 1, 'cards': {'sion': {'deploy_time': 2.0, 'cost': 8}}}
        self.required = {('sion', 'deploy_time')}

    def check(self, text, payload=None):
        return check_documents({'sion.md': text}, payload or self.payload, self.required)

    def test_numeric_format_and_unchanged_prose(self):
        self.assertEqual(self.check('| 部署 | <!-- card-fact: sion deploy_time -->2.00秒 / 建筑 |'), [])

    def test_drift_in_any_occurrence(self):
        errors = self.check('<!-- card-fact: sion deploy_time -->2\n<!-- card-fact: sion deploy_time -->1')
        self.assertTrue(any('document=1, compiled=2.0' in e for e in errors))

    def test_missing_marker_and_malformed_value(self):
        self.assertTrue(self.check('部署时间：2秒'))
        self.assertTrue(self.check('<!-- card-fact: sion deploy_time -->两秒'))

    def test_unknown_card_field_and_invalid_export(self):
        self.assertTrue(self.check('<!-- card-fact: unknown deploy_time -->2'))
        self.assertTrue(self.check('<!-- card-fact: sion typo -->2'))
        self.assertTrue(self.check('', {'schema': 2, 'cards': {}}))
        self.assertTrue(self.check('<!-- card-fact: sion deploy_time -->2', {'schema': 1, 'cards': {'sion': {'deploy_time': float('nan')}}}))
