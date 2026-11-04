"""Descriptions of observed photo geometry; no normative or muscle scores."""
import math


def measurement_report(measures, parts):
    definitions = [
        ('shoulder_tilt_deg', '어깨 연결선', '°', '좌우 어깨 추정점을 연결한 선과 사진 수평선의 차이', '카메라 기울기와 팔 자세의 영향을 받습니다.'),
        ('pelvis_tilt_deg', '골반 연결선', '°', '좌우 골반 추정점을 연결한 선과 사진 수평선의 차이', '골반뼈 자체의 변형이나 실제 높이 차이를 판정한 값은 아닙니다.'),
        ('shoulder_hip_ratio', '어깨·골반 너비 비율', '배', '어깨 관절 사이 거리를 골반 관절 사이 거리로 나눈 값', '신체 외곽 너비나 근육량을 측정한 값은 아닙니다.'),
        ('torso_leg_ratio', '상체·다리 길이 비율', '배', '어깨 중심부터 골반 중심까지 거리를 골반 중심부터 발목 중심까지 거리로 나눈 값', '사진의 원근과 카메라 높이에 영향을 받으며 실제 신체 치수가 아닙니다.'),
        ('neck_forward_deg', '목 전방 각도', '°', '현재 분석 경로에서 지원하지 않는 측면 측정', '측면 분석 기능이 추가되어야 측정할 수 있습니다.'),
    ]
    items = []
    for key, title, unit, meaning, limitation in definitions:
        value = measures.get(key)
        available = key != 'neck_forward_deg' and isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
        display = f'{value:.2f}{unit}' if available else '측정 안 됨'
        description = f'{meaning}: {display}.' if available else f'{title} 값은 이번 결과에 없습니다.'
        items.append({'key': key, 'title': title, 'status': 'measured' if available else 'unavailable',
                      'value': value if available else None, 'unit': unit, 'display_value': display,
                      'description': description, 'meaning': meaning, 'limitation': limitation})
    features = []
    names = {'left_upper_arm': '왼쪽 상완', 'right_upper_arm': '오른쪽 상완'}
    for part in parts:
        extracted = part.get('status') == 'extracted'
        contour = part.get('contour')
        features.append({'part': part['part'], 'title': names.get(part['part'], part['part']),
                         'status': part.get('status'),
                         'description': '사진 특징 추출 완료' if extracted else '관절 신뢰도 부족으로 특징 추출을 보류했습니다.',
                         'classification_status': part.get('classification', 'unavailable'),
                         'contour': contour})
    measured = [item for item in items if item['status'] == 'measured']
    return {'version': 'photo-measurement-report-v1', 'title': '사진 측정 결과',
            'summary': ' · '.join(f"{item['title']} {item['display_value']}" for item in measured) if measured else '사용 가능한 측정값이 없습니다.',
            'measured_count': len(measured), 'items': items, 'features': features,
            'interpretation': '사진에서 관찰한 기울기와 비율입니다. 정상·이상, 근육 발달 또는 건강 점수 판정은 포함하지 않습니다.',
            'next_steps': ['카메라를 수평으로 고정하고 같은 높이와 거리에서 전신을 촬영해 비교하세요.',
                           '양팔이 몸통을 가리지 않게 하고 관절이 보이는 사진을 사용하세요.'],
            'capabilities': {'geometry': 'available', 'balance_score': 'not_implemented',
                             'body_type': 'not_implemented', 'muscle_grade': 'not_implemented',
                             'contour_classifier': 'configured' if any(p.get('contour') is not None for p in parts) else 'not_trained'}}
