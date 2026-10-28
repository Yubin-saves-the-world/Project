# routines

개발 단계: MVP

오늘·주간·상세 루틴. Routine·RoutineItem·RoutineDay 모델을 소유합니다.

구현 계획은 [프론트 파일 구조](../../../docs/frontend-architecture/01-file-structure.md)를 참고하세요.

- data: 모델·API·Repository. home/settings는 조합 화면이라 별도 데이터 계층을 만들지 않습니다.
- presentation/pages: 화면.
- presentation/view_models: 화면 상태와 사용자 행동.
- presentation/widgets: 기능 전용 UI.
- `.gitkeep`은 비어 있는 폴더를 보존하는 파일이며 Dart 코드가 아닙니다.


## 구현 상태 (2026-10-26)

`routine_week_page.dart`, `routine_detail_page.dart`에서 주간/상세 조회와 추천 상태 변경을 제공한다. 분석 결과 생성은 기존 API를 재사용하며 실제 생성 ID로 상세를 연다. 수동 일정 교체/홈 동기화(T8), 운동 실행(T9)은 이후 단계다. [T7 구현 보고](../../../docs/project-context/ROUTINES_INTEGRATION.md)를 참고한다.
