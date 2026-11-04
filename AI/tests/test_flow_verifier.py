import unittest
from scripts.verify_flutter_flow import validate_result


class FlowResultTests(unittest.TestCase):
    def test_missing_nonfinite_and_failed_results_cannot_pass(self):
        for result in ({'status': 'failed'}, {'status': 'done', 'measures': {}},
                       {'status': 'done', 'measures': {'shoulder_tilt_deg': float('nan')}},
                       {'status': 'done', 'measures': {'shoulder_tilt_deg': True}}):
            with self.assertRaises(ValueError):
                validate_result(result)

    def test_missing_score_does_not_fail_valid_measurements(self):
        measures = {'shoulder_tilt_deg': .4, 'pelvis_tilt_deg': 1.2,
                    'shoulder_hip_ratio': 1.7, 'torso_leg_ratio': .7}
        self.assertEqual(validate_result({'status':'done','measures':measures,'balance_score':None}), measures)
