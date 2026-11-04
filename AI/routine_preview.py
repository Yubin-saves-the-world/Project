"""Preference-based general activity examples; no diagnosis or photo-derived targets."""
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator

VERSION = 'routine-preview-v1'
SOURCES = [
    {'title': 'CDC · 성인 신체활동 일반 지침', 'url': 'https://www.cdc.gov/physical-activity-basics/guidelines/adults.html/'},
    {'title': 'NHS · 근력 동작 안내', 'url': 'https://www.nhs.uk/live-well/exercise/strength-exercises/'},
    {'title': 'NHS · 앉아서 하는 동작 안내', 'url': 'https://www.nhs.uk/live-well/exercise/sitting-exercises/'},
]
PARTS = {'upper_body': '상체', 'lower_body': '하체'}
GOALS = {'habit': '운동 습관', 'strength': '기초 근력 동작 익히기', 'mobility': '가벼운 움직임'}
DAYS = {1: [0], 2: [0, 3], 3: [0, 2, 4], 4: [0, 2, 4, 6],
        5: [0, 1, 3, 4, 6], 6: [0, 1, 2, 3, 4, 5], 7: list(range(7))}
DAY_NAMES = ['월', '화', '수', '목', '금', '토', '일']
CATALOG = {
    'walk': ('편안한 속도로 걷기', '걷기와 휴식을 편안하게 번갈아 하세요. 숨을 참지 마세요.', '전신 움직임', None),
    'wall_press': ('벽 밀기 동작 익히기', '벽에 손을 대고 팔을 천천히 굽혔다 펴세요. 편안한 범위에서 연습하고 쉬세요.', '상체', 1),
    'sit_stand': ('의자 앉았다 일어나기', '바퀴 없는 안정된 의자에서 천천히 일어나고 앉는 동작을 연습하세요.', '하체', 1),
    'chest_open': ('앉아서 가슴 열기', '안정된 의자에서 어깨를 편안히 내리고 가슴 앞을 부드럽게 펴 보세요.', '상체', 2),
    'ankle_move': ('앉아서 발목 움직이기', '안정된 의자에서 발끝을 천천히 몸 쪽과 반대쪽으로 움직여 보세요.', '하체', 2),
}


class RoutinePreviewRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    goal: Literal['habit', 'strength', 'mobility'] = 'habit'
    focus: Literal['balanced', 'upper_body', 'lower_body'] = 'balanced'
    weekly_days: int = Field(default=3, ge=1, le=7, strict=True)
    minutes: int = Field(default=20, ge=5, le=45, strict=True)
    adult_confirmed: bool = Field(default=False, strict=True)
    cautions_confirmed: bool = Field(default=False, strict=True)
    cautions: list[Literal['pain_or_injury', 'exercise_restriction', 'individual_guidance_needed']] = Field(default_factory=list, max_length=3)

    @model_validator(mode='after')
    def unique_cautions(self):
        if len(self.cautions) != len(set(self.cautions)):
            raise ValueError('주의 항목은 중복 없이 선택하세요.')
        return self


def preview_routine(request: RoutinePreviewRequest):
    preferences = request.model_dump(include={'goal', 'focus', 'weekly_days', 'minutes'})
    result = {
        'version': VERSION, 'source': 'rule_based_general_example', 'model': None,
        'preferences': preferences, 'photo_measurements_used': False, 'goal_photo_required': False,
        'saved': False, 'rule_set_review_status': 'prototype_not_professionally_validated',
        'priority_parts': [], 'priority_parts_status': 'not_selected', 'routine': None,
        'sources': SOURCES,
        'limitations': ['일반 운동 예시이며 개인별 적합성을 검증한 처방이 아닙니다.',
                        '준비·정리·휴식을 포함한 시간 배분으로, 모든 시간을 계속 운동하라는 뜻이 아닙니다.',
                        '주간 활동 권장량 충족·체형 변화·근육 발달 효과를 보장하지 않습니다. 앱 일정에는 저장하지 않습니다.'],
    }
    if request.cautions:
        return result | {'status': 'needs_review', 'reason_codes': ['CAUTION_REQUIRES_REVIEW'],
                         'summary': '통증·부상이나 운동 제한이 표시되어 운동 예시 생성을 보류했습니다.',
                         'next_steps': ['해당 동작을 진행하기 전에 개인별 적합성을 전문가에게 확인하세요.']}
    missing = []
    if not request.adult_confirmed:
        missing.append('ADULT_CONFIRMATION_REQUIRED')
    if not request.cautions_confirmed:
        missing.append('CAUTION_CHECK_REQUIRED')
    if missing:
        return result | {'status': 'needs_information', 'reason_codes': missing,
                         'summary': '성인용 예시 적용과 주의 사항 확인이 필요합니다.',
                         'next_steps': ['성인용 일반 예시임을 확인하고 현재 주의 사항 여부를 직접 체크하세요.']}
    if request.goal == 'strength' and request.weekly_days > 3:
        return result | {'status': 'needs_information', 'reason_codes': ['STRENGTH_FREQUENCY_UNSUPPORTED'],
                         'summary': '이 시연의 근력 동작 예시는 주 1~3회만 지원합니다.',
                         'next_steps': ['주간 횟수를 1~3회로 바꾸거나 다른 운동 목표를 선택하세요.']}
    parts = list(PARTS) if request.focus == 'balanced' else [request.focus]
    basis = 'balanced_default' if request.focus == 'balanced' else 'user_preference'
    priorities = [{'part': part, 'label': PARTS[part], 'basis': basis,
                   'reason': '부족 부위 판정이 아닌 균형 구성 대상입니다.' if basis == 'balanced_default' else '사용자가 희망 부위로 선택했습니다.'}
                  for part in parts]
    activities = []
    if request.goal == 'habit':
        activities.append('walk')
    mapping = {'upper_body': 'wall_press', 'lower_body': 'sit_stand'} if request.goal == 'strength' else {
        'upper_body': 'chest_open', 'lower_body': 'ankle_move'}
    activities.extend(mapping[part] for part in parts)
    warm = max(1, request.minutes // 5)
    cool = warm
    main = request.minutes - warm - cool
    base, remainder = divmod(main, len(activities))
    steps = [{'phase': 'warm_up', 'title': '가벼운 준비 움직임', 'minutes': warm,
              'instruction': '편안한 범위에서 천천히 움직이며 준비하세요.', 'includes_rest': True}]
    for index, activity in enumerate(activities):
        title, instruction, target, source_index = CATALOG[activity]
        steps.append({'phase': 'practice', 'exercise_id': activity, 'title': title,
                      'minutes': base + (1 if index < remainder else 0), 'instruction': instruction,
                      'target': target, 'includes_rest': True, 'sets': None, 'repetitions': None,
                      'source_url': SOURCES[source_index]['url'] if source_index is not None else SOURCES[0]['url']})
    steps.append({'phase': 'cool_down', 'title': '천천히 정리하기', 'minutes': cool,
                  'instruction': '움직임을 줄이고 편안하게 쉬세요.', 'includes_rest': True})
    routine = {
        'title': f"{GOALS[request.goal]} · {request.minutes}분 예시",
        'session_minutes': request.minutes, 'weekly_days': request.weekly_days,
        'weekly_time_budget_minutes': request.minutes * request.weekly_days,
        'time_budget_includes_rest': True, 'steps': steps,
        'week': [{'day_index': day, 'label': DAY_NAMES[day], 'planned': day in DAYS[request.weekly_days]} for day in range(7)],
        'equipment': ['바퀴 없이 미끄러지지 않는 안정된 의자'] + (['안정된 벽'] if 'wall_press' in activities else []),
        'stop_instruction': '통증이나 불편이 생기면 해당 동작을 중단하고 적합성을 확인하세요.',
    }
    return result | {'status': 'ready', 'reason_codes': [], 'priority_parts': priorities,
                     'priority_parts_status': basis, 'routine': routine,
                     'summary': f"{GOALS[request.goal]} 목표와 선택 설정에 맞춘 일반 예시입니다. 사진의 부족 부위를 판정한 결과가 아닙니다.",
                     'next_steps': ['개인별 적합성을 확인하고 가능한 범위에서 시작하세요.']}
