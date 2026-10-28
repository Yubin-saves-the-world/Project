# workout

개발 단계: MVP

종목별 서버 운동 시작·이어하기·세트 기록/수정/삭제·휴식 타이머·기본 종료를 구현했습니다. 홈 자유 운동/이어하기와 오늘 추천 루틴에서 진입합니다.

- `data/workout_repository.dart`: 실제 서버 운동 기록과 세트 API.
- `data/workout_draft_store.dart`: 계정·로그별 미확인 요청과 타이머 복원 정보.
- `presentation/workout_view_model.dart`: 화면 상태와 사용자 행동. UUID 재사용·수정 버전·범위 검사도 담당합니다.
- `presentation/pages/workout_page.dart`: 진행 화면과 세트 수정 시트.

종료 메모·서버 확정 요약·다음 종목·루틴 완료·홈 탭 복귀(T10)도 구현했습니다. 종료 응답 유실 시 서버 상세에서 요약을 복구합니다. 상세 내용은 [종료 요약 연동 보고](../../../docs/project-context/WORKOUT_SUMMARY_INTEGRATION.md)를 참고하세요. T11 월별 서버 기록 달력·상태 필터/페이지·상세·완료 세트 수정/삭제·로그 삭제도 구현했습니다. 기존 `workout_history_page`를 서버 기록 화면으로 확장하고 서버 의존성이 없는 안내는 보존했습니다. 홈에서 기존 기기 기록 달력도 따로 열 수 있습니다. [운동 기록 연동 보고](../../../docs/project-context/WORKOUT_HISTORY_INTEGRATION.md)에 정책과 검증을 정리했습니다. 상세 정책과 검증은 [운동 진행 연동 보고](../../../docs/project-context/WORKOUT_PROGRESS_INTEGRATION.md)를 참고하세요.

구현 계획은 [프론트 파일 구조](../../../docs/frontend-architecture/01-file-structure.md)를 참고하세요.

- data: 모델·API·Repository. home/settings는 조합 화면이라 별도 데이터 계층을 만들지 않습니다.
- presentation/pages: 화면.
- presentation/view_models: 화면 상태와 사용자 행동.
- presentation/widgets: 기능 전용 UI.
- `.gitkeep`은 비어 있는 폴더를 보존하는 파일이며 Dart 코드가 아닙니다.

