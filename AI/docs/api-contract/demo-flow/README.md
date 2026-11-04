# 실제 로컬 시연 API 응답

2026-11-04의 전용 시연 계정으로 생성한 전체 JSON입니다. 세트는 검사용 자동 입력이며 실제 운동 수행 증거가 아닙니다. 날짜·ID·응답 문구를 앱에 고정하지 마세요. 원본 사진·인증 토큰·특징 벡터는 포함하지 않습니다.

- routines.json: POST /api/routines
- routine-detail.json: GET /api/routines/{id}
- today.json: GET /api/routines/today
- weekly.json: GET /api/routines/weekly
- completed.json: PATCH /api/workout-logs/{id}/complete
- calendar.json: GET /api/workout-logs
- coach-saved-plan.json: 저장된 오늘 플랜 수치 안내(model=null, 규칙 기반)
- coach-qwen.json: 일반 질문에 대한 실제 Qwen3 생성 답변

검사 중의 응답 스냅샷이라 완료 전·후 상태가 파일마다 다를 수 있습니다. 주간 응답은 시험 기록 정리 후 다시 조회한 값이므로 완료 응답과 진행도가 다를 수 있습니다. 자세한 요청 규격과 한계는 ../../DEMO_TEN_STEP.md를 참고하세요.
