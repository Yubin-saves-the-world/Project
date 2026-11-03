# 종합 문제점 보고서 대응 — 2026-11-03

대상 보고서: 사용자 제공 `AI_문제점_종합.md`. 실제 수정 작업본은 `movid-reviewed/AI/`다. 보고서에 적힌 `capstone-2`와 다른 컴퓨터의 캐시·로그인 상태까지 변경한 것으로 간주하지 않는다. 이 컴퓨터에는 승인된 공식 DINOv3 가중치가 있으며 실제 특징 추출을 확인했다. 가중치·토큰은 코드와 함께 배포하지 않는다.

## 이번에 보완한 실행 경로

앞선 AI.md 대응으로 DINOv3 null 참조·requests 누락·요청 검증 형식·임시 경로 노출·사유 코드·health 상태는 수정돼 있었다. 이번에는 **실행기가 여전히 DINOv3 접근을 필수로 요구하던 부분**을 추가로 보완했다.

AI 폴더에서:

```bash
# Python 3.12 필요. Hugging Face 인증 없이 관절 측정만 실행
bash run.sh --geometry-only --no-browser --port 8001

# 환경 검사와 공식 다중 포즈 자산 준비만 실행
.venv/bin/python scripts/check_environment.py --geometry-only --model

# 승인·로그인 후 DINOv3 특징까지 사용
bash run.sh --no-browser --port 8001
```

측정 전용 모드는 기본 requirements.txt만 설치하고 torch·transformers를 필수 검사하지 않는다. DINOv3 저장소에 접근하지 않으며 캐시 model.json도 필요하지 않다. 다중 포즈 자산은 공식 주소에서 내려받아 고정 SHA-256을 검증한다. 첫 포즈 자산 준비에는 인터넷이 필요하다.

`AI_DISABLE_DINO=1`은 서버 프로세스에서 DINOv3 초기화를 생략한다. `AI_REQUIRE_DINO=1`과 동시 지정하면 충돌 오류다. CLI `--geometry-only`는 해당 자식 프로세스에만 측정 전용 설정을 적용하며 컴퓨터 전역 설정을 바꾸지 않는다.

로컬 브리지 데모에도 같은 옵션을 전달할 수 있다.

```bash
bash run-flutter.sh --geometry-only --no-app
```

이는 브리지 데모이며 실제 BE 통합 검사를 대체하지 않는다. 이번 작업에서는 측정 전용 AI 실행기와 실제 사진 요청을 검증했고, 이 새 옵션의 Flutter UI까지 다시 실행한 것은 아니다.

## 실제 BE 연결

BE 프로세스 환경의 **AI_SERVER_URL**을 실행 중인 AI 주소로 지정해야 한다. 저장소의 BE 파일은 수정하지 않았다.

```bash
# BE 담당자가 실제 BE를 기동할 때 설정할 값의 예시
export AI_SERVER_URL=http://127.0.0.1:8001
```

AI를 8000 또는 다른 포트에서 실행했다면 값도 같은 포트로 바꾼다. `localhost`는 두 서버가 같은 호스트에서 실행될 때만 같은 장비를 뜻한다. 컨테이너 안 BE에서 127.0.0.1은 AI 호스트가 아니다. AI_BACKEND_URL은 반대로 브리지가 인증 BE를 호출할 때 쓰는 값이므로 혼동하지 않는다. 예시는 `config/backend-ai.env.example`에도 있다.

AI_SERVER_URL이 없는 BE의 75점·고정 체형 결과는 AI 분석 성공 증거가 아니다. 최신 BE가 이 상태에서 실패하도록 할지, 명시적인 데모 모드로 구분할지는 BE 담당 결정이다. AI 쪽에서 BE의 더미 결과를 감추거나 가짜 성공 응답을 만들지 않는다.

## 재확인 결과

최종 자동 테스트 136개 통과. 원본 FE·BE 파일 723개 일치, AI-only 변경 범위 검사 및 git diff 공백 검사 통과.


새 명령으로 별도 로컬 8022 포트에서 측정 전용 서버를 기동했다.

| 검사 | 결과 |
|---|---|
| health | degraded, dinov3_loaded=false, pose_guard_loaded=true |
| 실제 정면 전신 사진 | HTTP 200, done, dinov3=null, 약 0.48초 |
| 측면 사진 없음 | unavailable.key=neck_forward_deg, reason=SIDE_PHOTO_MISSING |
| DINOv3 없는 윤곽 직접 분류 | HTTP 503, MODEL_NOT_CONFIGURED |
| 필수 사진 필드 누락 | HTTP 422, detail 객체의 VALIDATION_FAILED |
| AI-only 범위 | 원본 FE·BE 변경 없음 |

실제 응답은 비공개 `.runtime/comprehensive_fixes_20261103/`에 보관한다. 기본 전체 모델 실행은 이 컴퓨터에서 앞서 실제 사진으로 확인했고, 실제 BE→AI→격리 MySQL 정상 저장도 확인했다. 정확한 이전 실행·버전 차이는 [AI.md 대응 결과](AI_MD_REVIEW_2026-11-03.md)에 기록했다.

## 해결 범위와 남은 제한

| 보고서 항목 | 상태 |
|---|---|
| AI-1·AI-4·AI-7·AI-9 | 수정 및 회귀 검사 완료 |
| DINOv3 접근 불가 | 승인·로그인은 각 실행 환경에서 필요. 이번 측정 전용 명령은 이를 요구하지 않음 |
| 포즈 파일 없음·AI-5 | 실행 전 자산 준비·해시 검사, 부재 시 degraded 상태. 모든 다중 인물 탐지를 보장하지 않음 |
| AI-3·AI-13 | 공개 reason·label/unit 계약 검사. 현재 계약은 api-integration.md 참고 |
| AI-2 | 호출자 직렬화 정책 유지. 중복은 즉시 AI_BUSY이며 긴 숨은 큐 없음 |
| AI-6 | 안전한 오류 메시지 유지. BE enum 확장과 FE 표시 변경은 AI 외부 공동 작업 |
| AI-8·AI-12 | 실제 BE/MySQL 성공 경로는 확인. 문서가 가정한 최신 BE 수정본의 정확한 커밋은 미확인. 받은 BE의 오류 저장 경로는 실패해 전체 통합 완료가 아님 |
| AI-10·AI-11 | loopback 기본·인증 한계·정확한 API와 실행 버전 문서화. 공개 배포 인증은 팀 합의 필요 |
| NOT_FRONTAL | 자동 검사는 미구현. health.capabilities.frontal_check=false로 표시. 사람 확인 필요 |
| 코치·글 요약·추천·더미 | BE 담당 영역. AI 코드를 고쳐 해결됐다고 주장하지 않음 |

## 다음 담당자 작업

BE 담당자는 AI_SERVER_URL 설정과 실제 AI 호출을 확인하고, 오류 detail.message 파싱·DB 100자 제한 처리·미지원 오류 표시를 확정해야 한다. 받은 원격 BE에서는 흐린 사진의 HTTP 예외 전체를 저장해 error_message 컬럼 초과 HTTP 500이 재현됐다. AI 메시지 자체는 100자 이하다.

글 요약·목표 비교·코치 모델 호출은 BE 담당으로 유지한다. 키가 없을 때 고정 응답을 생성하는지, 명시적인 미설정 상태를 반환할지는 BE에서 정해야 한다. 실제 키를 만들거나 복사하지 않았고 외부 사진 전송도 수행하지 않았다. 외부 AI 전송 동의 고지는 BE·FE 공동 사항이다.

이번 수정만으로 다른 컴퓨터의 capstone-2 코드가 자동 갱신되거나 GitHub에 게시되지는 않는다. 변경된 AI 코드 반영과 환경별 실행 확인이 필요하다.
