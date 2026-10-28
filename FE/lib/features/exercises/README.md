# exercises

개발 단계: MVP

운동 종목 목록·검색·상세. Exercise 모델을 소유합니다.

구현 계획은 [프론트 파일 구조](../../../docs/frontend-architecture/01-file-structure.md)를 참고하세요.

- data: 모델·API·Repository. home/settings는 조합 화면이라 별도 데이터 계층을 만들지 않습니다.
- presentation/pages: 화면.
- presentation/view_models: 화면 상태와 사용자 행동.
- presentation/widgets: 기능 전용 UI.
- `.gitkeep`은 비어 있는 폴더를 보존하는 파일이며 Dart 코드가 아닙니다.


## 구현 상태 (2026-10-26)

`presentation/pages/exercise_list_page.dart`와 `exercise_detail_page.dart`에서 검색·필터·페이지 조회와 상세/영상 링크를 제공한다. 마이페이지와 일정 편집에서 진입하며 기존 일정 ID는 변환하지 않는다. [T6 상세 보고](../../../docs/project-context/EXERCISES_INTEGRATION.md)를 참고한다.
