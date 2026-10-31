import math
import unittest
from integration import rounded_measure, valid_landmark


class ValidationTests(unittest.TestCase):
    def test_missing_and_nonfinite_ratios_remain_unavailable(self):
        for value in (None, math.nan, math.inf, -math.inf):
            self.assertIsNone(rounded_measure(value))
        self.assertEqual(rounded_measure(1.724), 1.72)

    def test_landmark_requires_finite_coordinates_and_confidence(self):
        good = {'x': .4, 'y': .5, 'visibility': .9}
        self.assertTrue(valid_landmark(good))
        for key in good:
            for value in (math.nan, math.inf, None):
                self.assertFalse(valid_landmark({**good, key: value}))
        self.assertFalse(valid_landmark(None))
        self.assertFalse(valid_landmark({**good, 'visibility': .1}))
        self.assertFalse(valid_landmark({**good, 'x': 1.1}))


if __name__ == '__main__':
    unittest.main()
