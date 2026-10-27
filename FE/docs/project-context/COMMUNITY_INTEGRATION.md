# 커뮤니티 추가 구현 — 2026-10-27

## 범위와 기준

사용자가 별도로 추가한 커뮤니티 범위를 구현했다. 기존 MVP의 로그인·가입·온보딩·홈·주간 일정·운동 기록·마이페이지와 하단 메뉴 구성은 유지한다. 백엔드 코드는 수정하지 않았다.

- Figma `pdQ0Dn4jcL4m7FC0hXAQ7x`, `665:261`(09 커뮤니티)의 목록 화면을 확인했다. 배경, 공지 카드, 카테고리, 게시글 카드, 글쓰기 버튼과 해당 SVG를 반영했다. 기존 홈/하단 메뉴 아이콘은 교체하지 않았다. 관리 메뉴는 차단 목록 진입을 위해 추가했다.
- 최신 계약: `docs/team-handoff/2026-10-25/api/openapi.yaml`의 community/safety. 이 API들은 문서상 **2차 기능**이다. 프론트 연결 코드가 있다는 사실이 실제 서버 배포를 의미하지 않는다.
- 상세·작성·신고·차단 관리 화면은 별도 Figma 프레임이 없어 기존 `ManagementPage`, 공통 글꼴·색상·입력·확인창 체계를 사용했다. Figma 파일 자체는 변경하지 않았다.

## 구현한 흐름

- 커뮤니티 탭을 선택할 때 목록 조회. 탭 재진입·앱 복귀·아래로 당기기로 갱신. 전체/운동 정보/인증/질문, 고정 공지, 20개 단위 더 보기.
- 검색은 **불러온 게시글만** 대상으로 제목·미리보기·작성자를 검색한다. 검색 API가 없어 임의의 `q` 쿼리나 전체 서버 검색을 만들지 않았다. 검색창에 조회 범위를 표시한다.
- 상세 본문·첨부 사진·작성자·날짜·조회 수, 좋아요 추가/취소, 댓글·답글·더 보기, 본인 댓글 삭제와 삭제된 부모 댓글 표시.
- 글 작성/수정/삭제. 본인 글만 수정·삭제 메뉴를 제공한다. 일반 사용자는 공지를 새로 작성할 수 없다.
- 제목 1~50자, 본문 1~2,000자, 댓글 1~500자. JPG/PNG 사진 최대 4장·장당 10MB. 선택 파일의 크기와 형식 헤더를 확인한다. 실제 파일 유효성·접근 제어는 서버에서도 검증해야 한다.
- 기존 사진 삭제 ID는 `remove_image_ids` 반복 텍스트 파트로, 새 사진은 `images` 반복 파일 파트로 보낸다. 수정은 multipart PATCH다. 분석용 사진 업로드 API/사진 저장 폴더와 혼용하지 않는다.
- 다른 사용자의 글/댓글 신고(사유·선택 설명 200자), 사용자 차단, 차단 목록·해제. 본인 글/댓글에는 신고·차단 메뉴를 제공하지 않는다. 서버가 전달하는 차단/숨김 결과를 따른다.

## 통신과 상태 보존

- 기존 공통 ApiClient와 Bearer 토큰·세션 만료 처리를 사용한다. 공통 multipart에 선택적 method/반복 필드만 추가했다. 기존 사진 업로드의 기본 POST 동작과 동의 검사는 유지한다.
- 빠른 필터 변경이나 페이지 조회 도중 늦게 도착한 이전 응답을 버린다. 중복 페이지 항목은 ID로 합친다. 추가 페이지 오류는 기존 목록을 유지한다.
- 서버 오류/빈 목록/로딩을 구분한다. 서버 모드에서 실패했다고 예시 글을 보여주지 않는다. 잘못된 게시글 응답은 화면 빌드 전에 조회 오류로 처리한다.
- 쓰기 중 중복 제출과 해당 쓰기 화면의 뒤로 이동을 제한한다. 글 작성 오류 후 제목·본문·선택 사진을 유지하고, 저장하지 않은 내용을 버릴 때 확인한다.
- 계약에 커뮤니티 쓰기 멱등성 키가 없다. 글/댓글을 자동 재전송하지 않는다. 응답 유실 시 저장됐을 수 있음을 알리고 먼저 목록 확인을 안내한다. 명시적 재전송은 사용자 확인을 거친다. 앱 프로세스 종료 후 작성 초안 복원 기능은 없다.
- 좋아요 `ALREADY_LIKED`는 재조회, 신고 `ALREADY_REPORTED`는 이미 접수됨 안내, 차단 `ALREADY_BLOCKED`는 알려진 차단 상태로 처리한다. 조회 수가 늘어나는 상세 GET을 주기적으로 폴링하지 않는다.
- 외부 사진 URL은 http(s) 주소로 제한하고 잘못되거나 실패한 사진은 대체 UI를 제공한다. 사진 디코딩 폭은 1040으로 제한한다.

## 로컬 미리보기

기존 `USE_LOCAL_PREVIEW=true` 실행에서만 계정별 메모리 저장소를 사용한다. 예시 글과 작성·댓글·좋아요·신고·차단은 **실제 서버에 전송되지 않으며 앱 종료 시 초기화**된다. 화면과 완료 안내에 미리보기임을 명시한다. 기존 기기 일정·기록 저장 키와 형식은 바꾸지 않는다. 서버 모드와 자동으로 전환하지 않는다.

## 변경 파일

- `lib/features/community/data/community_models.dart`: 응답 모델, 입력·사진 제약
- `lib/features/community/data/community_repository.dart`: 계약 API 저장소와 독립 사진 선택 인터페이스
- `lib/features/community/data/local_community_repository.dart`: 명시적 메모리 미리보기
- `lib/features/community/presentation/community_controller.dart`: 의존성, 목록·필터·페이지 상태
- `lib/features/community/presentation/community_page.dart`: Figma 목록과 진입
- `lib/features/community/presentation/community_detail_page.dart`: 상세·댓글·좋아요·소유권 메뉴
- `lib/features/community/presentation/community_editor_page.dart`: 작성·수정·첨부
- `lib/features/community/presentation/community_safety_pages.dart`: 신고·차단 관리
- `lib/features/community/presentation/community_widgets.dart`: 카드/사진/확인 UI 보조
- `lib/app/onboarding/onboarding_flow.dart`, `lib/app/shell/main_shell.dart`: 기존 계정별 저장소와 탭 연결, 탈퇴 시 캐시 해제
- `lib/core/network/api_client.dart`, `api_contract.dart`: multipart 확장과 커뮤니티 경로
- `assets/icons/figma/community/`의 SVG 5개, `pubspec.yaml`의 해당 하위 폴더 등록. 패키지·폰트 의존성 추가 없음.
- `test/features/community/`의 테스트 2개, `test/app/main_shell_test.dart`의 새 진입 안내 기대값, `integration_test/community_smoke_test.dart`
- 인수인계·기능 README와 `docs/project-context/previews/community-*.png`

## 검증

검증 결과는 아래 최종 실행 결과와 인수인계 최신 항목을 기준으로 한다. 실제 서버·실제 게시·메일·AI 기능이 확인됐다는 의미가 아니다.

- 커뮤니티 단위/화면 테스트 15개 통과: multipart PATCH 반복 필드·인증, 계약 경로, 세션 만료, 서버 오류와 빈 상태 구분, 입력 제약, 계정 분리, 페이지 실패·중복·늦은 응답, 목록/상세/댓글/답글/수정/삭제/신고/차단/해제, 중복 전송과 입력 보존.
- 393×852, 320×640/글꼴 130% 화면 캡처를 확인했다. 새 화면은 작은 화면·키보드에서 스크롤로 입력과 완료 버튼에 접근한다.
- 전체 회귀 테스트: 317개 통과, 실서버용 2개 미실행.
- 최종 Flutter 정적 분석 문제 없음. 전체 테스트 재실행도 317개 통과·실서버용 2개 미실행이다.
- iPhone 16 Pro/iOS 18.3 시뮬레이터에서 커뮤니티 목록→게시→좋아요→댓글→수정→삭제 UI 테스트 1개 통과. 로컬 메모리 저장소 기준이며 실제 서버·사진 보관함 선택 검증은 아니다.
- 일반 main.dart 대상 iOS 시뮬레이터 앱 빌드도 성공했다.

## 남은 연결 확인

백엔드의 2차 API 배포 후 실서버로 multipart(반복 ID 포함)·파일 제한·소유권·페이지 순서·신고 중복·차단 필터·회원 탈퇴 후 삭제 정책을 확인해야 한다. 현재 문서에 없는 서버 전체 검색, 푸시 알림, 관리자 UI는 구현하지 않았다.
