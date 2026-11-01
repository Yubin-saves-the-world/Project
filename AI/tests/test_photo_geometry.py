import unittest
from types import SimpleNamespace
from analyzers.photo_geometry import point, joint_angle, difference_percent, side_neck_measurement, extra_geometry
from analyzers.pose_guard import credible_pose
from review_sessions import ReviewSessions


class GeometryTests(unittest.TestCase):
    def test_strict_landmarks_and_degenerate_segments(self):
        for bad in (True, float('nan'), 2, None):
            self.assertIsNone(point({'a': {'x': bad, 'y': .2, 'visibility': .9}}, 'a', 100, 100))
        self.assertIsNone(joint_angle((0, 0), (0, 0), (1, 1)))
        self.assertEqual(joint_angle((0, 0), (1, 0), (1, 1)), 90)
        self.assertEqual(difference_percent(90, 110), 20)
        self.assertIsNone(difference_percent(None, 10))

    def test_side_angle_and_front_view_guard(self):
        lm = {k: {'x': x, 'y': y, 'visibility': .9} for k, x, y in (
            ('left_ear', .52, .1), ('left_shoulder', .5, .3), ('right_shoulder', .51, .3), ('left_hip', .5, .7))}
        result = side_neck_measurement(lm, 500, 1000)
        self.assertEqual(result['status'], 'measured')
        self.assertAlmostEqual(result['value'], 2.86)
        lm['right_shoulder']['x'] = .95
        lm['left_shoulder']['x'] = .05
        self.assertEqual(side_neck_measurement(lm, 1000, 1000)['reason'], 'SIDE_VIEW_UNCONFIRMED')
        self.assertEqual(side_neck_measurement({}, 100, 100)['status'], 'unavailable')
        self.assertIsNone(extra_geometry({}, 100, 100)['body_axis_tilt_deg'])

    def test_person_guard_rejects_bad_visibility_without_crashing(self):
        pose = [SimpleNamespace(x=.5, y=i/33, visibility=.9) for i in range(33)]
        self.assertTrue(credible_pose(pose))
        for p in pose:
            p.visibility = None
        self.assertFalse(credible_pose(pose))
        self.assertFalse(credible_pose([]))

    def test_review_tickets_expire_and_bound_memory(self):
        now = [0]
        store = ReviewSessions(ttl_seconds=10, capacity=1, clock=lambda: now[0])
        vector = [1.] * 768
        first = store.create('left_upper_arm', vector)
        second = store.create('right_upper_arm', vector)
        with self.assertRaises(KeyError):
            store.get(first['token'])
        self.assertEqual(store.get(second['token'])['part'], 'right_upper_arm')
        now[0] = 10
        with self.assertRaises(KeyError):
            store.get(second['token'])
        for values in ([0.] * 768, [float('nan')] * 768, [1.]):
            with self.assertRaises(ValueError):
                store.create('arm', values)
