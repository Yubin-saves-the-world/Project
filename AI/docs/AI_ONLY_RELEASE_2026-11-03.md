# AI-only 연결·배포 안내

사용자가 2026-11-03에 다시 확정한 제한: **AI 폴더만 수정. FE·BE 수정 금지.**

## 이번 연결

AI 호환 서버에 아래 인증 경로를 추가했다. 실제 Spring의 `/api/users/me`로 토큰·사용자·AI 동의를 검증하고 사용자별 로컬 SQLite에 완료된 대화 쌍만 저장한다.

- GET /api/ai-coach/messages → 최근 20개 messages.
- POST /api/ai-coach/messages, `{"content":"질문"}` → user_message, assistant_message.
- DELETE /api/ai-coach/messages → 삭제한 메시지 수.

대화 역할·문자열·시각·message_id는 받은 BE 코치 형식을 따른다. 모델 실패·시간 초과는 오류로 반환하고 고정 문장을 모델 답변으로 저장하지 않는다. 시간표·안내 원칙은 규칙 기반임을 문자열에도 명시한다. 모델 호출과 SQLite 저장 사이에는 긴 DB 트랜잭션을 유지하지 않는다. 두 메시지는 원자적으로 저장하고 사용자가 섞이지 않도록 uid를 인증 결과에서만 가져온다. 보관은 사용자별 최대 100개이며 읽기는 최근 20개다. 생성 중 삭제는 409, 중복 생성은 503이다.

이는 **AI 폴더의 데모 호환 구현**이며 실제 BE의 MySQL 코치 구현을 수정한 것이 아니다. 직접 `/v1/coach/chat` 웹 API는 이와 달리 대화를 서버 DB에 자동 저장하지 않는다.

## 원본 Flutter의 차단 요소

현재 로컬 FE와 확인한 GitHub main의 `main_shell.dart`에는 코치 화면이 `EmptyView`로 남아 있다. 기존 코치 탭은 API를 호출하지 않는다. AI API를 추가해도 이 정적 화면이 자동으로 채팅 화면으로 바뀌지는 않는다.

따라서 아래를 구분한다.

- AI 웹 코치 시연: 가능.
- 인증·Qwen3·사용자별 대화 저장 API: AI 호환 서버에서 가능.
- 원본 Flutter 사진 분석 연결: 기존 호환 서버 경로 사용.
- 원본 Flutter 코치 UI 종단 연결: FE 담당자가 화면을 연결해야 함. 이번 제한 안에서는 변경하지 않음.
- 실제 BE Anthropic 분기를 Qwen3로 교체: BE 담당 작업. 이번에 변경하지 않음.

## 실행

프로젝트 루트에서:

```bash
# AI 웹 사진 분석·Qwen3 코치
bash AI/run-coach.sh

# 인증·사진·코치 대화 저장을 포함한 호환 서버
bash AI/run-flutter.sh --no-app
```

Ollama 실행과 qwen3:4b 모델 준비가 필요하다. DINOv3는 각 환경에서 모델 승인·인증 또는 측정 전용 `--geometry-only` 옵션을 준비한다. 실제 가중치·개인 라벨·DB·토큰은 GitHub ZIP에 포함하지 않는다.

AI 호환 서버의 최초 로컬 계정은 demo@movid.local / movid1234이며 이미 DB가 있으면 기존 비밀번호 설정을 따른다. 공개 배포 계정이 아니다.

## 검증·GitHub 반영

코치 이력 소유권·인증·실패 시 미저장·시간표 출처·삭제 충돌 테스트를 추가했다. 전체 자동 테스트 152개 통과. 변경 경로는 AI 폴더만이며 기존 FE·BE 원본 보호 검사를 유지한다.

게시와 새 ZIP 실행 결과는 최종 작업 응답의 실제 PR·검증 결과로 확인한다. 기존 문서에서 '미게시'로 적은 내용은 당시 작업 스냅샷을 설명한다.
