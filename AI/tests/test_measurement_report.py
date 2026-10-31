import unittest
from measurement_report import measurement_report


class MeasurementReportTests(unittest.TestCase):
    def test_describes_actual_values_without_inventing_judgement(self):
        report = measurement_report({'shoulder_tilt_deg': .64, 'pelvis_tilt_deg': 1.4,
                                     'shoulder_hip_ratio': 1.73, 'torso_leg_ratio': .7},
                                    [{'part': 'left_upper_arm', 'status': 'extracted', 'classification': 'not_trained'}])
        self.assertEqual(report['measured_count'], 4)
        self.assertIn('0.64°', report['summary'])
        self.assertEqual(report['items'][-1]['status'], 'unavailable')
        self.assertEqual(report['capabilities']['contour_classifier'], 'not_trained')
        self.assertEqual(report['capabilities']['balance_score'], 'not_implemented')

    def test_missing_and_nonfinite_values_do_not_become_measurements(self):
        report = measurement_report({'shoulder_tilt_deg': float('nan'), 'pelvis_tilt_deg': True,
                                     'torso_leg_ratio': float('inf')}, [])
        self.assertEqual(report['measured_count'], 0)
        self.assertTrue(all(item['value'] is None for item in report['items']))

    def test_feature_unavailable_and_classifier_abstention_stay_explicit(self):
        report = measurement_report({}, [{'part': 'left_upper_arm', 'status': 'unavailable'},
            {'part': 'right_upper_arm', 'status': 'extracted', 'classification': 'contour_abstained',
             'contour': {'status': 'abstained', 'label': None}}])
        self.assertEqual(report['features'][0]['classification_status'], 'unavailable')
        self.assertIsNone(report['features'][1]['contour']['label'])
        self.assertEqual(report['capabilities']['contour_classifier'], 'configured')
