import unittest
from analyzers.analyze_body import line_tilt_deg
from analyzers.dinov3_features import upper_arm_box
class GeometryTests(unittest.TestCase):
    def test_pixel_angle_matches_known_slope(self):
        self.assertAlmostEqual(line_tilt_deg({'x':0,'y':0},{'x':100,'y':100}),45)
    def test_portrait_crop_uses_pixel_axes(self):
        points={'left_shoulder':{'x':.4,'y':.2,'visibility':.9},'left_elbow':{'x':.5,'y':.5,'visibility':.9}}
        self.assertEqual(upper_arm_box(points,'left',200,400),(37,37,143,243))
    def test_low_confidence_crop_is_unavailable(self):
        self.assertIsNone(upper_arm_box({},'left',200,400))
if __name__=='__main__':unittest.main()
