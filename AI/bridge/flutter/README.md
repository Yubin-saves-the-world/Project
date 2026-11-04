# 원본 Flutter 코치 탭 연결용 인수인계

`ai_coach_page.dart`는 AI 폴더에 준비한 코치 화면이다. 원본 `FE/`에는 설치하거나 연결하지 않았다. main의 `MainShell` 코치 탭은 아직 `EmptyView`이므로 이 파일이 저장소에 있다는 것만으로 앱의 코치 탭이 바뀌지 않는다.

## FE 담당 연결 지점

1. 이 위젯을 FE 담당 구조에 맞게 가져온다. `MainShell`의 코치 탭에서 빈 화면 대신 `AiCoachPage`를 표시한다.
2. 로그인한 계정의 **기존 tokenStore**와 로그아웃 처리를 공유한다. 별도 사용자 ID나 고정 토큰을 넣지 않는다.
3. 요청은 로컬 AI 브리지 주소의 `/api/ai-coach/messages`로 보낸다. 브리지 없이 원본 BE를 직접 사용할 경우 BE 담당자가 같은 계약을 제공해야 한다.
4. 원본 `ApiClient` 기본 timeout은 10초다. 코치 전용 클라이언트를 90초로 만들고 나머지 요청의 기본 설정은 바꾸지 않는다. Qwen3 최초 로딩은 더 오래 걸릴 수 있다.

현재 FE의 `ApiClient` 기준 연결 예시(변수 `api`는 로그인에 사용 중인 클라이언트, `aiBaseUrl`은 실행기가 출력한 AI 주소):

```dart
final coachApi = ApiClient(
  baseUrl: aiBaseUrl,
  tokenStore: api.tokens,
  onSessionExpired: api.onSessionExpired,
  timeout: const Duration(seconds: 90),
);
coachApi.beforeAuthorizedRequest = api.beforeAuthorizedRequest;

final coachPage = AiCoachPage(
  request: (method, path, body) =>
      coachApi.send(method, path, body: body),
);
// 페이지를 관리하는 상위 State.dispose에서 coachApi.dispose() 호출.
```

예시를 자동으로 FE에 적용하지 않았다. 기존 세션·페이지 소유 수명에 맞춰 한 번 생성하고 정리한다. 코치 페이지는 비밀번호·토큰을 저장하거나 새 인증을 수행하지 않는다.

## 동작과 오류 처리

- GET /api/ai-coach/messages: 저장된 최근 20개 대화.
- POST /api/ai-coach/messages: `{"content":"오늘 플랜을 알려주세요"}`. 응답의 user_message와 assistant_message를 표시한다.
- 서버가 현재 계정의 오늘 플랜을 조회하므로 클라이언트가 다른 계정의 루틴을 전달하지 않는다.
- 저장 플랜의 숫자는 `rule_based_saved_routine`, model=null로 제공한다. 일반 질문에 대한 실제 생성 답변은 qwen3 모델명을 표시한다.
- POST 확인 뒤 바로 표시하며 추가 GET 실패 때문에 성공한 전송을 실패로 바꾸지 않는다.
- 전송 오류 뒤 자동 재전송하지 않는다. 대화 새로고침으로 저장 여부를 확인한 뒤 다시 보낼 수 있다.
- 500자 제한, 응답 대기 표시, 잘못된 목록 형식 거절, 페이지 종료 후 응답 무시를 구현했다.

Flutter 위젯 테스트 3개를 AI 실행 복사본에서 통과했다. 원본 앱에 설치된 화면의 실제 사용자 동작 검증을 대신하지 않는다. 재검증은 AI 실행 복사본 FE를 작업 폴더로 하여 `flutter test --no-pub /절대경로/AI/bridge/flutter/ai_coach_page_test.dart`로 수행한다.
