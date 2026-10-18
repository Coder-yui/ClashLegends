"""Machine-headroom policy checks; only a tiny Python process, no engine."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'performance'))
import match_loading as loading

class MatchLoadingBudgetTests(unittest.TestCase):
    def test_process_query_tolerates_non_utf8_arguments(self):
        self.assertEqual(loading.command(sys.executable, '-c', 'import os; os.write(1, bytes([255]))'), '\ufffd')

    def test_invalid_memory_readings_fail_closed(self):
        for query in ['unreadable', 'free percentage: 101%']:
            with patch.object(loading, 'command', side_effect=[str(16 * loading.GIB), '1', query]):
                with self.assertRaises(ValueError): loading.memory_state()

    def state(self, gib, pressure=1):
        return dict(available_estimate_bytes=int(gib * loading.GIB), pressure_level=pressure)

    def test_reserves_current_headroom(self):
        self.assertEqual(loading.budget(self.state(8)), 2 * loading.GIB)
        self.assertEqual(loading.budget(self.state(9)), 3 * loading.GIB)
        self.assertEqual(loading.budget(self.state(20)), 3 * loading.GIB)

    def test_pressure_and_low_headroom_prevent_launch(self):
        for state in [self.state(7.9), self.state(10, 2), self.state(10, 4)]:
            with self.assertRaises(RuntimeError): loading.budget(state)

    def test_match_limits_still_bound(self):
        for values in [dict(wall_seconds=61), dict(rss_bytes=3*loading.GIB+1),
                       dict(heartbeat_seconds=3), dict(startup_grace_seconds=7)]:
            with self.assertRaises(ValueError): loading.MatchLimits(**values)

if __name__ == '__main__':
    unittest.main()
