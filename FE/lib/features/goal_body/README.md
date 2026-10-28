# goal_body

개발 단계: MVP

목표 체형 등록·수정·상태 조회. 목표 사진 처리와 요약을 구분합니다.

구현 계획은 [프론트 파일 구조](../../../docs/frontend-architecture/01-file-structure.md)를 참고하세요.

- data: 모델·API·Repository. home/settings는 조합 화면이라 별도 데이터 계층을 만들지 않습니다.
- presentation/pages: 화면.
- presentation/view_models: 화면 상태와 사용자 행동.
- presentation/widgets: 기능 전용 UI.
- `.gitkeep`은 비어 있는 폴더를 보존하는 파일이며 Dart 코드가 아닙니다.


## 구현 상태 (2026-10-26)

분석 입력의 목표 카드·마이페이지에서 `presentation/pages/goal_body_page.dart`를 연다. `goal_view_model.dart`가 등록/수정/삭제와 pending 조회를 관리한다. 서버 저장소는 최신 목표 API, 로컬 미리보기는 계정별 세션 내 사진과 설명 등록·교체·삭제를 지원한다. 사진은 메모리에만 보관하고 실제 AI 특징 요약은 생성하지 않는다. 상세한 제한과 검증은 [T5 보고서](../../../docs/project-context/GOAL_BODY_INTEGRATION.md)를 참고한다.
