"""Photo-coordinate measurements with no normal/abnormal or health thresholds."""
from __future__ import annotations
import math


def point(landmarks, name, width, height, visibility=.5):
    item = landmarks.get(name)
    if not isinstance(item, dict):
        return None
    if any(isinstance(item.get(k), bool) or not isinstance(item.get(k), (int, float))
           or not math.isfinite(item[k]) for k in ('x', 'y', 'visibility')):
        return None
    if not (0 <= item['x'] <= 1 and 0 <= item['y'] <= 1 and visibility <= item['visibility'] <= 1):
        return None
    return item['x'] * width, item['y'] * height


def midpoint(a, b):
    return ((a[0]+b[0])/2, (a[1]+b[1])/2) if a is not None and b is not None else None


def angle_from_vertical(a, b):
    if a is None or b is None or math.dist(a, b) < 1:
        return None
    return round(math.degrees(math.atan2(abs(a[0]-b[0]), abs(a[1]-b[1]))), 2)


def joint_angle(a, vertex, b):
    if any(p is None for p in (a, vertex, b)):
        return None
    u, v = (a[0]-vertex[0], a[1]-vertex[1]), (b[0]-vertex[0], b[1]-vertex[1])
    denominator = math.hypot(*u)*math.hypot(*v)
    if denominator < 1:
        return None
    return round(math.degrees(math.acos(max(-1, min(1, (u[0]*v[0]+u[1]*v[1])/denominator)))), 2)


def chain_length(points):
    if any(p is None for p in points):
        return None
    return sum(math.dist(a, b) for a, b in zip(points, points[1:]))


def difference_percent(left, right):
    if left is None or right is None or min(left, right) < 1:
        return None
    return round(100*abs(left-right)/((left+right)/2), 2)


def extra_geometry(landmarks, width, height):
    p = lambda name: point(landmarks, name, width, height)
    shoulder = midpoint(p('left_shoulder'), p('right_shoulder'))
    hip = midpoint(p('left_hip'), p('right_hip'))
    arms = [chain_length([p(f'{s}_shoulder'), p(f'{s}_elbow'), p(f'{s}_wrist')]) for s in ('left', 'right')]
    legs = [chain_length([p(f'{s}_hip'), p(f'{s}_knee'), p(f'{s}_ankle')]) for s in ('left', 'right')]
    return {'body_axis_tilt_deg': angle_from_vertical(shoulder, hip),
            'arm_projected_length_difference_pct': difference_percent(*arms),
            'leg_projected_length_difference_pct': difference_percent(*legs),
            'joint_angles': {f'{s}_{joint}_deg': joint_angle(p(f'{s}_{first}'), p(f'{s}_{joint}'), p(f'{s}_{last}'))
                             for s in ('left', 'right')
                             for first, joint, last in [('shoulder', 'elbow', 'wrist'), ('hip', 'knee', 'ankle')]}}


def side_neck_measurement(landmarks, width, height):
    """Ear-shoulder line versus image vertical, not a clinical forward-head diagnosis."""
    candidates = []
    for side in ('left', 'right'):
        ear, shoulder = (point(landmarks, f'{side}_{name}', width, height, .7) for name in ('ear', 'shoulder'))
        if ear is None or shoulder is None or math.dist(ear, shoulder) < 16 or ear[1] >= shoulder[1]:
            continue
        confidence = min(landmarks[f'{side}_{name}']['visibility'] for name in ('ear', 'shoulder'))
        candidates.append((confidence, side, ear, shoulder))
    if not candidates:
        return {'status': 'unavailable', 'value': None, 'reason': 'SIDE_LANDMARKS_UNRELIABLE',
                'description': '측면 사진의 귀·어깨 추정점을 충분히 확인하지 못했습니다.'}
    _, side, ear, shoulder = max(candidates, key=lambda row: row[0])
    left = point(landmarks, 'left_shoulder', width, height, .7)
    right = point(landmarks, 'right_shoulder', width, height, .7)
    hip = point(landmarks, f'{side}_hip', width, height, .7)
    orientation = 'unverified'
    if left is not None and right is not None and hip is not None:
        torso = math.dist(shoulder, hip)
        if torso > 16 and abs(left[0]-right[0])/torso > .65:
            return {'status': 'unavailable', 'value': None, 'reason': 'SIDE_VIEW_UNCONFIRMED',
                    'description': '양쪽 어깨가 넓게 보여 측면 여부를 확인하지 못했습니다. 옆모습 사진으로 다시 확인하세요.'}
        orientation = 'narrow_shoulder_projection'
    return {'status': 'measured', 'value': angle_from_vertical(ear, shoulder), 'unit': 'deg',
            'landmark_side': side, 'view_check': orientation, 'reason': None,
            'description': '측면 사진의 귀·어깨 연결선과 사진 수직선의 차이입니다.',
            'limitation': '촬영 방향과 카메라 기울기에 영향을 받습니다. 거북목·골격 상태를 판정하지 않습니다.'}


def photo_quality(landmarks, width, height, blur, person_check):
    required = ['nose', 'left_shoulder', 'right_shoulder', 'left_hip', 'right_hip', 'left_ankle', 'right_ankle']
    visible = [landmarks[k]['visibility'] for k in required if point(landmarks, k, width, height) is not None]
    ys = [landmarks[k]['y'] for k in required if point(landmarks, k, width, height) is not None]
    fraction = max(ys)-min(ys) if ys else None
    warnings = []
    if fraction is not None and fraction < .45:
        warnings.append('인물이 사진에서 작게 보입니다. 카메라를 더 가까이 두고 전신이 잘리지 않게 촬영하세요.')
    if person_check.get('status') != 'checked':
        warnings.append('자동 인물 수 검사가 완료되지 않았습니다. 사진에 한 명만 있는지 확인하세요.')
    return {'width_px': width, 'height_px': height, 'blur_variance': round(float(blur), 2),
            'required_landmarks_visible': len(visible), 'required_landmarks_total': len(required),
            'minimum_landmark_score': round(min(visible), 3) if visible else None,
            'body_vertical_frame_fraction': round(fraction, 3) if fraction is not None else None,
            'person_check': person_check, 'warnings': warnings,
            'score_meaning': '관절 모델 점수와 촬영 조건입니다. 측정 정확도나 건강 점수가 아닙니다.',
            'content_safety': 'not_automatically_checked', 'front_view': 'not_automatically_verified'}
