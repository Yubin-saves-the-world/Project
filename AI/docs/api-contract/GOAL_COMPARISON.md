# 목표 사진 측정값 비교 — AI 단독 API

POST /v1/compare (multipart/form-data). current_front, goal_front 파일 각 1개 필수. current_side, goal_side 파일 각 1개 선택. capture_conditions_confirmed=true 필수. 이는 촬영 조건을 사용자가 확인했다는 선언이며 자동 검증은 아닙니다. 기존 /v1/analyze 및 Flutter 브리지는 변경하지 않았습니다.

```bash
curl --fail-with-body http://127.0.0.1:8015/v1/compare \
  -F 'current_front=@/absolute/path/current.jpg' \
  -F 'goal_front=@/absolute/path/goal.jpg' \
  -F 'capture_conditions_confirmed=true' \
  -o comparison.json
```

선택 측면: -F 'current_side=@/absolute/path/current-side.jpg' -F 'goal_side=@/absolute/path/goal-side.jpg'. AI 단독 화면 /goal-compare. 실행 예: bash AI/run.sh --port 8015 --no-browser.

성공 HTTP 200: status=done, comparison_version, current, goal, goal_comparison. current/goal은 각 측정값·사진 품질·설명·경고이며 특징 벡터와 사진 base64는 반환하지 않습니다.

goal_comparison: version, status(compared|partial|unavailable), compared_count, items, conditions_confirmation, summary, limitations, priority_parts=[], priority_parts_status=not_implemented, routine_status=not_implemented.

items: key, title, unit(deg|ratio), status(compared|unavailable), current_value(number|null), goal_value(number|null), delta_current_minus_goal(number|null), reason(null|MEASUREMENT_UNAVAILABLE), missing_inputs(current/goal 배열). 차이는 현재값−목표값입니다. 누락값을 0으로 대체하지 않습니다. 측면 사진 양쪽이 없으면 해당 항목 비교만 보류합니다.

조건 미확인: HTTP 422 PHOTO_CONDITIONS_UNCONFIRMED. 정면 분석 오류: HTTP 422 detail.code/message/input(current|goal). 잘못된 파일 업로드는 기존 INVALID_IMAGE/IMAGE_TOO_LARGE. 다른 요청 처리 중이면 AI_BUSY. 모든 업로드 검증 후 순차 추론하며 임시 파일은 성공·실패 모두 정리합니다.

이 기능은 사진상 기하 측정값 비교입니다. 목표 달성률, 체형 진단, 근육 부족이나 필요한 운동을 사진 차이로 추론하지 않습니다. 별도 설정 기반 운동 예시는 /v1/routines/preview에서 제공합니다. FE/BE 및 기존 Flutter 화면은 자동 연결되지 않습니다.

## 초기 도입 시점의 검증 기록

- 단위·HTTP 경계 테스트 포함 전체 122개 통과.
- 실제 모델 서버 8015 /v1/compare HTTP 200 확인. 같은 정면·측면 사진을 양쪽에 넣는 대조군에서 6개 차이 모두 0. 새 사람에 대한 모델 정확도 시험이 아님.
- 실제 응답: AI/.runtime/api-contract-review/actual-goal-comparison-control.json.
- /goal-compare 화면 표시 확인. 브라우저 파일 선택 자동 확인이 지연되어 화면 제출부터 결과 표시까지의 검증은 완료하지 못함.
- 새 API는 8015 서버에서 실행 중이며 기존 8005/Flutter 서버는 재시작하지 않았음.


## 추가: 설정 기반 운동 예시로 이동

goal_comparison.preference_routine은 status=available, api=/v1/routines/preview, page=/routine, uses_photo_measurements=false를 반환합니다. 기존 priority_parts=[], priority_parts_status=not_implemented, routine_status=not_implemented는 사진에서 직접 추론하는 기능이 없다는 의미로 유지합니다. 이 상태를 별도 설정 기반 API 전체의 미구현으로 해석하지 마세요. [새 계약과 기본 구성 기준](ROUTINE_PREVIEW.md)을 참고하세요.
