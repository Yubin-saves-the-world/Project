# 설정 기반 운동 예시 — routine-preview-v1

`POST /v1/routines/preview` (application/json), AI 웹 화면 `/routine`.

사진 측정값·목표 사진·윤곽 등급에서 필요한 운동을 추론하지 않는다. 사용자 목표·희망 부위·시간을 받아 **규칙 기반 일반 예시**를 구성한다. Qwen3·DINOv3·인증 BE 없이 이 API 자체를 사용할 수 있다. 앱 일정·운동 기록·DB에는 저장하지 않는다. FE/BE는 변경하지 않았다.

## 요청

```json
{
  "goal": "strength",
  "focus": "upper_body",
  "weekly_days": 3,
  "minutes": 10,
  "adult_confirmed": true,
  "cautions_confirmed": true,
  "cautions": []
}
```

| 필드 | 허용값·기본값 |
|---|---|
| goal | habit(기본), strength, mobility |
| focus | balanced(기본), upper_body, lower_body |
| weekly_days | 엄격한 정수 1~7, 기본 3 |
| minutes | 엄격한 정수 5~45, 기본 20. 휴식 포함 시간 배정 |
| adult_confirmed | 엄격한 boolean, 기본 false. 성인용 예시 적용 확인 |
| cautions_confirmed | 엄격한 boolean, 기본 false. 주의 사항 여부의 직접 확인 |
| cautions | pain_or_injury, exercise_restriction, individual_guidance_needed. 중복 금지, 기본 [] |

알 수 없는 필드·문자열 숫자·숫자 대신 boolean·알 수 없는 주의 코드 등은 HTTP 422 VALIDATION_FAILED. 사진·측정값·점수를 보내도 알 수 없는 필드로 거절한다.

## 상태와 의미

- `ready`: 확인이 끝났고 이 시연에서 지원하는 설정이다. routine과 priority_parts를 반환한다.
- `needs_information`: 확인 누락 또는 지원 범위를 벗어난 주간 근력 구성을 선택했다. routine=null, priority_parts=[]로 두며 reason_codes와 다음 행동을 반환한다.
- `needs_review`: 주의 항목이 하나라도 있다. 운동 동작을 만들지 않고 routine=null, priority_parts=[]로 보류한다.

이 세 상태는 모두 HTTP 200의 업무 결과다. 입력 형식 오류 422와 구분한다.

| reason_codes | 처리 |
|---|---|
| ADULT_CONFIRMATION_REQUIRED | 성인용 예시 적용 확인 필요 |
| CAUTION_CHECK_REQUIRED | 주의 사항 직접 확인 필요 |
| CAUTION_REQUIRES_REVIEW | 통증·부상·운동 제한 등의 개인별 확인 필요 |
| STRENGTH_FREQUENCY_UNSUPPORTED | 시연 근력 구성은 주 1~3회만 지원. 나머지 목표는 주 1~7회 |

근력 주 1~3회 제한은 **제품의 제한된 예시 범위**이며 4회 이상 운동이 의학적으로 위험하다는 판정이 아니다.

## 부위·기본 구성 기준

- 목표 사진 없음: 사진은 어떤 경우에도 필요하지 않다.
- 희망 부위 없음: focus=balanced로 상·하체를 고르게 구성한다. priority_parts_status=balanced_default, 두 대상은 같은 수준의 구성 대상이며 부족 순위가 아니다.
- 희망 부위 있음: 선택한 상체 또는 하체만 priority_parts에 반환한다. priority_parts_status=user_preference이며 판정 근거는 사용자 선택이다.
- 주의 항목 없음: 빈 배열만 보내서는 생성하지 않는다. cautions_confirmed=true와 adult_confirmed=true를 사용자가 확인해야 한다.
- 통증·부상·운동 제한 또는 적합성 불확실: 어떤 목표나 시간에서도 생성을 보류한다. 자세한 진료 정보는 받지 않는다.

습관 목표는 편안한 걷기와 선택 부위의 가벼운 움직임, 근력 목표는 벽 밀기·의자 앉았다 일어나기의 동작 익히기, 움직임 목표는 앉아서 가슴 열기·발목 움직이기에서 구성한다. 사용자별 중량·세트·반복 횟수·강도 처방은 생성하지 않는다. 근력 발달이나 자세 교정 효과를 보장하지 않는다.

## 시간·일정 기준

1. 준비와 정리는 각각 `max(1, minutes // 5)`분.
2. 나머지를 선택 동작 수로 나눠 배정하고 나머지 분은 앞 동작부터 1분씩 배분한다.
3. 모든 단계는 양의 정수 시간이며 합계는 요청 minutes와 정확히 같다.
4. 동작 단계 시간은 연습·필요한 휴식을 포함한 구간이다. 해당 시간 내내 반복하라는 뜻이 아니다. sets와 repetitions는 null.
5. 주간 예시는 월요일을 0으로 한 day_index 0~6, label, planned로 반환한다. 선택한 횟수와 planned=true 개수가 일치한다. 실제 날짜에 예약하지 않는다.
6. weekly_time_budget_minutes는 준비·정리·휴식도 포함한다. 주간 권장 활동량을 달성했다는 지표가 아니다.

항상 source=rule_based_general_example, model=null, photo_measurements_used=false, goal_photo_required=false, saved=false. rule_set_review_status=prototype_not_professionally_validated. 기존 분석 JSON의 건강 점수나 체형 판정에 이 정보를 대입하지 않는다.

## 실제 HTTP 응답 파일

일반 테스트 입력으로 로컬 서버에 요청해 저장한 전체 예시:

- [요청 JSON](cases/routine-preview.request.json)
- [생성 결과 전체 JSON](cases/routine-preview.ready.json)
- [주의 사항 보류 전체 JSON](cases/routine-preview.caution.json)
- [확인 누락 전체 JSON](cases/routine-preview.unconfirmed.json)

```bash
curl --fail-with-body http://127.0.0.1:8001/v1/routines/preview \
  -H 'Content-Type: application/json' \
  --data-binary @AI/docs/api-contract/cases/routine-preview.request.json
```

프로젝트 루트에서 `bash AI/run.sh --geometry-only`로 실행하고 `/routine`에 접속한다. `/goal-compare` 결과와 AI 홈에서도 이동할 수 있다. 이 경로는 AI 웹 시연이며 원본 Flutter 루틴 API에 자동 저장·연결되지 않는다.

## 참고 근거와 검증 범위

- [CDC 성인 신체활동 일반 지침](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html/): 전반적인 활동·근력 운동 안내를 참고했다. 이 시연의 짧은 시간표가 권장량을 충족한다고 주장하지 않는다.
- [NHS 근력 동작](https://www.nhs.uk/live-well/exercise/strength-exercises/), [NHS 앉아서 하는 동작](https://www.nhs.uk/live-well/exercise/sitting-exercises/): 동작 명칭·기본 설명과 안정된 의자 사용을 참고했다.

배분 비율·예시 일정은 프로젝트 규칙이다. 이 구성 자체에 대한 전문가 승인·임상적 유효성·개인별 운동 안전성을 검증한 것은 아니다.

테스트는 모든 목표·희망 부위와 5~45분 조합의 시간 합계, 주간 횟수, 확인·주의 사항 차단, 잘못된 입력과 원본 API 호환성을 검사한다. 실제 로컬 사진 동일 입력 비교→설정 기반 생성, 주의 사항·미확인 보류 응답도 확인했다. 같은 사진 비교는 수치 차이 0을 보는 대조군이며 독립 인물 정확도 시험이 아니다.

## 아직 완료하지 않은 기능

사진으로 부족 근육·건강 점수·체형·운동 우선 부위를 판정하는 기능은 이 API로 해결됐다고 표시하지 않는다. 현재 139개 상완 윤곽 라벨은 근육량·건강·체형 점수의 정답 자료가 아니다. `merged_reviewed_v9` 내부의 test 분할은 비어 있으며, 별도 독립 세트와 동일인 여부·등급 대표성을 구분해 검증해야 한다. 이 안내를 위해 학습 라벨·분할·평가 기준을 변경하지 않았다.
