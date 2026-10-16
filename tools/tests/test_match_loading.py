"""Machine-headroom policy checks; no engine or external process is launched."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'performance'))
import match_loading as loading

class MatchLoadingBudgetTests(unittest.TestCase):
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
