"""Descriptive photo geometry comparison; never infer training needs from ratios."""
import math


METRICS = (
    ('shoulder_hip_ratio', '어깨·골반 너비 비율', 'ratio'),
    ('torso_leg_ratio', '상체·다리 길이 비율', 'ratio'),
    ('shoulder_tilt_deg', '어깨 연결선 기울기', 'deg'),
    ('pelvis_tilt_deg', '골반 연결선 기울기', 'deg'),
    ('body_axis_tilt_deg', '몸통 중심선 기울기', 'deg'),
    ('neck_forward_deg', '측면 귀·어깨 각도', 'deg'),
)


def finite(value):
    return (not isinstance(value, bool) and isinstance(value, (int, float))
            and math.isfinite(value))


def compare_measurements(current, goal):
    items = []
    for key, title, unit in METRICS:
        a, b = current.get('measures', {}).get(key), goal.get('measures', {}).get(key)
        valid = finite(a) and finite(b)
        missing = [side for side, value in [('current', a), ('goal', b)] if not finite(value)]
        items.append({'key': key, 'title': title, 'unit': unit,
                      'status': 'compared' if valid else 'unavailable',
                      'current_value': a if finite(a) else None,
                      'goal_value': b if finite(b) else None,
                      'delta_current_minus_goal': round(a-b, 2) if valid else None,
                      'reason': None if valid else 'MEASUREMENT_UNAVAILABLE',
                      'missing_inputs': missing})
    count = sum(item['status'] == 'compared' for item in items)
    return {'version': 'photo-geometry-comparison-v1',
            'status': 'compared' if count == len(items) else 'partial' if count else 'unavailable',
            'compared_count': count, 'items': items,
            'conditions_confirmation': 'user_declaration_not_automatically_verified',
            'summary': f'사진상 측정값 {count}개를 비교했습니다. 차이는 현재값에서 목표값을 뺀 값입니다.',
            'limitations': ['두 사진의 촬영 조건·자세가 다르면 비교가 왜곡될 수 있습니다.',
                           '목표 사진의 비율은 운동으로 달성 가능한 목표나 이상적인 신체 기준을 뜻하지 않습니다.',
                           '측정값 차이로 근육 부족·운동 우선 부위·건강 상태를 결정하지 않습니다.'],
            'priority_parts': [], 'priority_parts_status': 'not_implemented',
            'routine_status': 'not_implemented',
            'preference_routine': {'status': 'available', 'api': '/v1/routines/preview',
                                   'page': '/routine', 'uses_photo_measurements': False}}


def measurement_view(result):
    """Do not return image bytes, review tokens, or feature vectors in comparisons."""
    return {key: result.get(key) for key in
            ('status', 'measurement_version', 'measures', 'photo_quality', 'measurement_report', 'warnings')}
