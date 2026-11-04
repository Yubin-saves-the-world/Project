# MOVID AI 서버

사진의 관절 각도·비율 측정, DINOv3 특징 추출, 로컬 Qwen3 코치와 계정 대화 시연을 제공합니다. 변경 범위는 **AI/ 폴더**입니다. [작업 지침](AGENTS.md)을 따릅니다.

## 먼저 실행 방식 선택

프로젝트 전체 ZIP을 푼 뒤 **프로젝트 루트에서 아래 중 하나**를 실행하세요. 실행기가 출력하는 주소와 준비 상태를 확인합니다.

| 목적 | 실행 | 기본 접속 주소 |
|---|---|---|
| DINOv3 승인 없이 사진 수치 측정 | `bash AI/run.sh --geometry-only` | `http://127.0.0.1:8001/analysis` |
| 목표·희망 부위·시간으로 일반 운동 예시 | `bash AI/run.sh --geometry-only` | `http://127.0.0.1:8001/routine` |
| 로그인 없이 Qwen3 대화 | `bash AI/run-coach.sh --geometry-only` | `http://127.0.0.1:8023/coach` |
| 계정 로그인·대화 저장·사진 분석 연동 | `bash AI/run-flutter.sh --no-app --require-coach` | `http://127.0.0.1:8080/coach/account` |

사진 서버는 Python 3.12가 필요합니다. 코치는 **Ollama와 로컬 qwen3:4b**, 계정 시연은 **JDK 17 이상**도 필요합니다. 원본 Flutter 실행은 아래 별도 절을 참고하세요. `--geometry-only`를 빼면 DINOv3를 준비하며 각 PC에서 Hugging Face 승인·인증이 필요합니다. ZIP에는 모델·개인 사진·라벨·DB·가상환경·인증 키가 들어 있지 않습니다.

포트가 사용 중이면 기존 실행을 확인하거나 실행 옵션으로 다른 포트를 지정하세요. 실행 터미널의 `Ctrl+C`로 해당 실행을 종료합니다. 의존성과 모델 다운로드는 첫 실행에 시간이 걸립니다.

## 계정 코치 시연 순서

1. 위 계정 시연 명령으로 서버를 시작하고 출력된 `/coach/account` 주소를 엽니다.
2. 로컬 시연 계정으로 로그인합니다. 최초 기본값은 `demo@movid.local` / `movid1234`이며 기존 DB에서는 기존 비밀번호를 사용합니다.
3. 질문을 보냅니다. 확인된 답변은 즉시 표시되며 계정별로 저장됩니다.
4. ‘운동 설정과 사진 측정값 참고’를 펼쳐 목표·경험·시간과 본인의 완료 분석을 선택합니다. 측정값 참고는 기본적으로 꺼져 있습니다.
5. ‘대화·분석 새로고침’으로 계정 대화와 완료 분석 목록을 함께 갱신합니다. 분석 목록을 못 불러와도 일반 대화는 사용할 수 있습니다.

여기서 선택하는 분석은 **같은 AI 호환 서버의 계정에 저장된 분석**입니다. `/analysis`의 단독 웹 분석은 계정 분석 이력에 자동 저장되지 않습니다. 로그아웃 시 화면과 인증 정보를 비우며, 서버 대화는 별도 삭제 전까지 유지합니다. 새로고침 시 재로그인이 필요합니다.

## 지금 되는 것과 남은 연결

- **사용 가능:** 정면·측면 관절 수치 측정, 선택적 DINOv3 특징 추출, 사진 간 수치 비교, 실험적 상완 윤곽 검수·분류, Qwen3 대화, 계정별 대화 저장·복원·삭제, 사용자 설정 기반 운동 예시 생성.
- **판정 검증 필요:** 근육 발달 등급, 건강·체형 점수, 측정값에 따른 운동 우선 부위·개인별 운동 처방. `/routine`의 희망 부위는 사용자 선택 또는 기본 균형 구성이며 사진 판정이 아닙니다. 규칙 기반 일반 운동 예시는 검증된 맞춤 처방이 아닙니다.
- **원본 앱 연결 미완료:** Flutter 코치 탭은 빈 화면이며, 확인한 원격 BE에는 로컬 Qwen3 호출 연결이 없습니다. 환경 변수만 넣으면 연결되는 상태가 아닙니다. AI 웹 시연과 원본 앱을 구분하세요.

연결 근거를 읽기 전용으로 점검하려면 `python3 AI/scripts/check_team_integration.py --json`을 실행합니다. 소스 근거 점검이며 실제 종단 실행 검증을 대신하지 않습니다.

- [운동 예시·희망 부위·주의 사항 계약과 전체 JSON](docs/api-contract/ROUTINE_PREVIEW.md)
- [BE 코치 요청·응답 및 오류 계약](docs/BE_COACH_COMPATIBILITY.md)
- [AI-only 계정 연결 안내](docs/AI_ONLY_RELEASE_2026-11-03.md)
- [Qwen3 시연과 실행 준비](docs/QWEN3_COACH_DEMO.md)
- [사진 분석 안내](docs/PHOTO_ANALYSIS_V2.md) · [목표 사진 수치 비교 API](docs/api-contract/GOAL_COMPARISON.md)

<details>
<summary>과거 검증·데이터 작업 기록</summary>

- [GitHub ZIP의 별도 환경 검증](docs/ZIP_RELEASE_CHECK_2026-11-03.md)
- [종합 문제점 대응](docs/COMPREHENSIVE_FIXES_2026-11-03.md)
- [AI.md 및 BE/MySQL 점검](docs/AI_MD_REVIEW_2026-11-03.md)
- [2026-11-03 작업 보고서](docs/WORK_REPORT_2026-11-03.md)
- [독립 시험 데이터 검수](docs/INDEPENDENT_TEST_V1.md)
- [AI 홈·검수 기준 안내](docs/AI_HOME_AND_VALIDATION.md)
- [2026-11-01 개발 보고서](docs/DAILY_REPORT_2026-11-01.md)

각 문서의 수치와 테스트 개수는 해당 날짜의 기록입니다.

</details>

## Kaggle 자료 수집

선택한 자료 5종의 원본 다운로드·버전·해시·실제 파일 점검 도구를 추가했습니다. 사진·합성 인물·분할 마스크·수치 자료를 용도별로 기록하며 기존 학습 모델에 자동 혼합하지 않습니다. [수집 명령과 검수 절차](docs/KAGGLE_SOURCES.md)를 확인하세요.

## 사진 분석 v2

정면 사진과 선택 측면 사진의 관절 측정, 촬영 정보, 상완 크롭 확인 후 실험 분류, 두 결과 수치 비교, 결과 저장을 AI 웹 화면에서 연결했습니다. 원본 FE·BE는 변경하지 않았습니다. [새 화면·API·실행 방법](docs/PHOTO_ANALYSIS_V2.md)을 확인하세요.

## 검수한 상완 크롭의 실험용 윤곽 분류

라벨 통합·평가 조건 검사·미검증 실험 학습과 Flutter 실제 HTTP 연결 검사는 [재학습 및 연결 확인 안내](docs/RETRAIN_AND_VERIFY.md)를 참고하세요. `fit-only`는 전체 입력으로 학습하며 평가 점수를 만들지 않습니다. 모델 상태와 해시는 `/health`에서 확인할 수 있습니다.

`POST /v1/contour/classify`와 `/contour-test` 화면을 추가했습니다. 피부가 보이는 상완 크롭을 사람이 확인한 경우에만 실험 모델의 참고 후보·모델 점수·보류 상태를 반환합니다. 근육량이나 체형 점수가 아닙니다. 학습 모델을 명시적으로 설정해야 하며 사진·학습 결과는 Git에 포함하지 않습니다. [초기 실험과 실행 방법](docs/CURRENT_EXPERIMENT.md)을 확인하세요.

## GitHub ZIP에서 Flutter 앱 실행하기 (macOS)

**ZIP 다운로드만으로 앱과 AI 서버가 자동 실행되지는 않습니다.** 아래 환경과 공식 모델 접근 권한을 준비한 뒤 실행하세요. 프로젝트 전체 ZIP이 필요하며 `AI/`, `FE/`, `BE/`를 함께 유지합니다.

### 1. 실행 환경 준비

- Python 3.12, JDK 17 이상, Flutter SDK
- Xcode 및 설치된 iOS Simulator 런타임, Flutter iOS 빌드 환경
- Hugging Face의 `facebook/dinov3-vits16-pretrain-lvd1689m` 이용 승인을 받은 계정
- 첫 실행에 필요한 인터넷 연결과 의존성·모델 다운로드 공간

### 2. 설치와 Hugging Face 로그인

압축을 푼 **프로젝트 루트**에서 실행합니다. 로그인 토큰은 터미널의 숨겨진 입력란에만 입력하고 코드나 채팅에 넣지 않습니다. 기존 로컬 로그인이 있으면 로그인 명령을 생략할 수 있습니다.

```bash
bash AI/run.sh --install-only
AI/.venv/bin/hf auth login
```

브라우저 로그인과 모델 이용 승인은 CLI 로그인과 별개입니다. 모델 접근 오류(401/403)가 발생하면 승인받은 동일 계정의 토큰인지 확인하세요.

### 3. Flutter와 로컬 서버 실행

아래 사진 경로를 자신의 정면 전신 JPG/PNG 경로로 바꿉니다.

```bash
bash AI/run-flutter.sh --photo "/사진의/절대경로/test1.jpg"
```

실행기는 공식 모델을 준비하고 로그인용 Spring 서버와 AI 연결 서버를 시작한 뒤, **MOVID AI QA** iOS 시뮬레이터에 원본 Flutter 앱을 실행합니다. 사진은 해당 기기의 앨범으로 가져옵니다. 첫 빌드는 시간이 걸릴 수 있습니다. 터미널은 켜 두세요.

원본 `FE/`와 `BE/`는 수정하지 않습니다. 빌드용 복사본과 실행 자료는 `AI/.runtime/flutter_demo/` 안에 생성합니다.

### 4. 앱에서 사진 분석

1. 시연 계정 `demo@movid.local` / 최초 기본 비밀번호 `movid1234`로 로그인합니다.
2. **분석 → 사진으로 분석 → 정면 사진 추가 → 앨범에서 선택**으로 사진을 고릅니다.
3. **확인 → 분석 시작**을 누릅니다.
4. 결과의 **체형 측정**에서 어깨·골반 기울기와 신체 비율을 확인합니다.

기존 시연 계정의 비밀번호를 별도로 지정했다면 실행 시 `AI_DEMO_PASSWORD`에 기존 값을 지정합니다. 테스트용 프로필과 계정은 로컬 시연 데이터입니다.

### 결과에서 확인할 수 있는 것

| 항목 | 현재 동작 |
| --- | --- |
| 사진 분석 | 관절 검출, 사진상 기울기·비율 측정, DINOv3 특징 추출 |
| 점수·체형 판정 | 제공하지 않음. 기존 Flutter는 ‘점수 산출 불가’·‘판정 불가’ 표시 |
| 측면 측정 | 적합한 측면 사진이 함께 전달될 때 시도하며, 없으면 해당 항목만 미측정 |
| 상완 윤곽 등급 | 별도 학습 모델과 사람의 피부·위치 검수가 필요. 기존 Flutter에는 검수·상세 화면 없음 |
| 홈 운동 기록·루틴·식단 | 이번 AI 연결의 검증 범위 밖. 일부 카드에 오류 또는 준비 중 표시 가능 |

**숫자 측정값이 표시되면 사진 측정은 완료된 것입니다.** 점수 미제공 문구와 분석 요청 실패를 구분하세요. 사진상 측정값은 실제 신체 치수·의학적 진단·근육량·근력이 아닙니다.

### ZIP에 포함되지 않는 자료

가상환경, 공식 모델 가중치, 개인 사진, 라벨, 학습한 윤곽 분류기, DB와 인증 키는 포함하지 않습니다. 공식 모델은 승인 계정으로 준비하며, 윤곽 분류기는 별도 검수 자료로 학습해야 합니다. **윤곽 분류기가 없어도 사진 측정은 실행할 수 있습니다.**

이미 학습한 로컬 모델이 있다면 다음 옵션을 추가합니다. 예시 경로는 자신의 모델 파일로 바꿉니다.

```bash
bash AI/run-flutter.sh \
  --contour-model "/학습한/모델/model.json" \
  --photo "/사진의/절대경로/test1.jpg"
```

윤곽 분류기는 실험 모델입니다. 사용한 모델의 검수·평가 상태를 확인해야 하며, 모델을 지정해도 원본 Flutter에 윤곽 등급 상세 화면이 생기지는 않습니다.

### 실행 중 문제가 생기면

- 화면이 안 보이면 **Simulator 또는 Device Hub → MOVID AI QA**를 선택합니다.
- 포트가 사용 중이면 기존 실행을 확인하거나 `--port 8090 --backend-port 8092`를 지정합니다. 기존 서버를 자동 종료하지 않습니다.
- 서버 로그: `AI/.runtime/flutter_demo/backend.log`, `ai.log`
- 종료: 실행 터미널에서 `Ctrl+C`
- 서버만 실행: `bash AI/run-flutter.sh --no-app`

2026-11-01 현재 개발 환경에서 원본 Flutter 시뮬레이터의 사진 선택 → 업로드 → 분석 → 측정값 표시를 확인했습니다. 실제 휴대폰 카메라 촬영과 모든 새 컴퓨터 환경의 실행을 검증한 것은 아닙니다. 자세한 환경·포트·실행 구조는 [Flutter 로컬 시연 안내](docs/FLUTTER_LOCAL_DEMO.md)를 참고하세요.

## GitHub ZIP으로 바로 시작하기 (macOS)

최신 AI 코드가 있는 [기본 main ZIP](https://github.com/Yubin-saves-the-world/Project/archive/refs/heads/main.zip)을 다운로드하고 압축을 풉니다. 기본 main ZIP에 AI 서버와 Flutter 로컬 연결 실행기가 포함됩니다. 이 절은 Flutter 앱이 아닌 AI 단독 웹 테스트 방법입니다.

1. Python 3.12를 설치합니다. 이 컴퓨터에 이미 설치돼 있다면 그대로 사용합니다.
2. 압축을 푼 프로젝트의 `AI` 폴더에서 터미널로 `bash run.sh`를 실행합니다. macOS에서는 `AI 서버 실행.command`를 실행해도 됩니다.
3. 설치·공식 모델 확인이 끝나면 `http://127.0.0.1:8001/analysis`에서 사진을 선택하고 **사진 분석하기**를 누릅니다.

첫 실행은 가상환경 생성, 고정 버전 라이브러리 설치와 가중치 다운로드가 필요해 시간이 걸립니다. 이후에는 설치 결과와 다운로드 모델을 재사용합니다. Python 환경은 현재 AI/.venv에 생성하며 다른 프로젝트 가상환경에 의존하지 않습니다. 실행 폴더에 공백이 있어도 됩니다.

Hugging Face 모델 이용 승인과 로그인은 필수입니다. 이미 승인받은 계정의 로컬 로그인을 사용합니다. 로그인하지 않았다면 설치 후 AI 폴더에서 `.venv/bin/hf auth login`을 실행하고 `bash run.sh`를 다시 실행하세요. 토큰은 채팅이나 소스에 적지 않습니다. 모델 파일을 ZIP에 넣어 승인을 대신하지 않습니다.

- 종료: 서버를 실행한 터미널에서 Ctrl+C
- 8001 포트 사용 중: 기존 서버를 임의 종료하지 않습니다. `bash run.sh --port 8002`로 다른 포트를 사용할 수 있습니다.
- 브라우저 자동 열기 생략: `bash run.sh --no-browser`
- 설치만 확인: `bash run.sh --install-only`
- 폴더 위치를 옮긴 뒤 가상환경 경로 오류: AI/.venv를 새 위치에서 다시 생성합니다. 가상환경은 ZIP에 포함하지 않습니다.

이 경로에서 검증하는 것은 **AI 단독 서버와 AI 안의 사진 테스트 화면**입니다. Flutter 앱 전체의 연동이나 BE 서버 실행을 보장하는 변경이 아닙니다. FE·BE 파일은 수정하지 않습니다.

## 현재 기능

- FastAPI `POST /v1/analyze`: 정면 전신 사진 1장과 선택 측면 1장의 관절 기울기·비율·각도, 촬영 정보와 DINOv3 상완 특징을 반환합니다.
- 픽셀 좌표를 사용해 어깨·골반 기울기, 어깨/골반 너비 및 상체/하체 길이 비율을 계산합니다.
- 공식 DINOv3 모델을 시작 시 한 번 로딩하고 양쪽 상완의 CLS·평균 패치 특징을 추출합니다.
- JPG/PNG, 파일당 10MB, 2,500만 픽셀 제한·EXIF 보정·긴 변 1024px 축소를 적용합니다.
- 손상·단색·극단적으로 흐린 사진, 낮은 관절 신뢰도 및 전신 누락을 거절합니다. 처리 임시 파일은 응답 후 삭제합니다.
- 기존 `POST /analyze/body`는 별도 경로로 camelCase 응답과 선택적 text 입력을 유지합니다. 기존 MediaPipe 파이프라인을 호출하며 DINOv3 결과와 혼합하지 않습니다. 사진은 1~3장으로 제한합니다.

소규모 검수 라벨로 학습한 것은 **사진상 상완 윤곽의 실험 분류기**입니다. 검증된 근육 발달 분류기는 없습니다. `/v1/analyze`는 근육 발달 등급·균형 점수·체형 판정·운동 처방을 생성하지 않습니다. `/v1/compare`는 두 사진의 각도·비율 차이를 비교하며 목표 달성 점수를 만들지 않습니다. 기존 API의 휴리스틱 응답은 검증된 진단이나 학습된 근육 분류 결과가 아닙니다.

## AI 단독 실행

이 폴더(`AI/`)에서 Python 3.12로 실행합니다.

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements-dinov3.txt
.venv/bin/hf auth login
.venv/bin/python -m uvicorn app:app --host 127.0.0.1 --port 8001
```

공식 `facebook/dinov3-vits16-pretrain-lvd1689m` 모델 접근 승인을 받은 계정이 필요합니다. 토큰을 코드에 적거나 공유하지 않습니다. 승인된 로컬 모델이 있으면 `DINO_MODEL_PATH=/절대/모델/폴더`를 지정할 수 있습니다. `AI_DEVICE`는 기본 `cpu`이며 `auto`도 지원합니다. 모델·사진·DB·토큰은 저장소에 포함하지 않습니다.

- 상태 확인: `http://127.0.0.1:8001/health`
- 사진 테스트 화면: `http://127.0.0.1:8001/analysis`
- API 문서: `http://127.0.0.1:8001/docs`
- DINOv3 요청:

```sh
curl -X POST http://127.0.0.1:8001/v1/analyze \
  -F 'front_images=@/절대/경로/photo.jpg'
```

응답과 오류 계약은 [DINOv3 API 명세](docs/dinov3-api.md)를 확인하세요. Flutter 시연 연결은 `AI/bridge`에서 원본 Spring 인증과 로컬 사진·분석 저장을 연결합니다. 팀 Flutter 화면 자체는 수정하지 않습니다.

## 검사

```sh
.venv/bin/python -m pip install -r requirements-test.txt
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
```

API 경계 테스트는 가짜 엔진을 사용하며 모델이나 개인 사진을 다운로드하지 않습니다. 실제 추론 여부는 별도 모델 실행 검사와 구분합니다. 검증 범위는 [리뷰 기록](docs/ai-only-review-2026-10-31.md)을 확인하세요.

## 남은 기능

추가 검수 자료와 독립 성능 평가, 정면·의복 자동 검사, 목표 비교, 추천 루틴이 남아 있습니다. 윤곽 학습·실험 분류, 일부 다중 인물 검사와 측면 귀·어깨 각도 측정은 구현돼 있으나 성능 한계가 있습니다. AI 단독 `/v1` API에는 JWT·사용자별 제한·DB·분산 큐가 없습니다. Flutter용 `/api` 연결 계층은 Spring JWT 검증과 로컬 DB·사용 한도를 별도로 적용합니다. 한 번에 한 요청만 처리하고 사용 중이면 503을 반환합니다. 외부에 직접 공개하지 않고 로컬 또는 제한된 네트워크에서 사용합니다. 과거 모델 비교 자료는 연구 계획이며 현재 구현 범위는 이 README와 새 API 명세를 따릅니다.

## 커밋 전 범위 검사

Git 체크아웃의 `AI/`에서 `python scripts/check_scope.py`를 실행합니다. 기준 브랜치가 다르면 마지막 인자로 지정합니다. 커밋된 변경·작업 중 변경·미추적 파일에 AI 밖의 경로가 있으면 실패합니다.

## ZIP 검증 결과

GitHub ZIP을 실제로 다운로드해 새 가상환경 생성·설치·모델 다운로드·서버 실행·실제 사진 분석과 브라우저 결과 표시를 확인했습니다. [실행 검증 기록](docs/zip-startup-verification-2026-10-31.md)을 참고하세요. 검증 환경은 Apple Silicon Mac/Python 3.12입니다.


## 상완 윤곽 라벨링·학습 준비

사람이 검수할 로컬 라벨링 화면과 학습·평가 도구를 제공합니다. 실제 라벨이 없으면 학습하지 않고 안내합니다. 사진상 윤곽을 분류하는 도구이며 근육량이나 근력 등급을 추정하지 않습니다.

AI 서버 실행 후 다른 터미널의 AI 폴더에서:

```sh
.venv/bin/python scripts/label_contours.py --images /절대/사진/폴더
# http://127.0.0.1:8002에서 사람이 검수·저장
.venv/bin/python scripts/train_contours.py --validate-only
.venv/bin/python scripts/train_contours.py
```

검수한 인물 ID로 train/val/test를 분리합니다. 자세한 기준·명령·모델 연결은 [상완 윤곽 학습 안내](docs/contour-training.md)를 확인하세요. 실제 사진과 라벨·모델은 AI/.runtime에만 저장하며 GitHub에는 포함하지 않습니다.


계정 코치 화면 로직의 회귀 검사는 프로젝트 루트에서 `node --test AI/tests/test_account_coach.mjs`로 실행합니다. Node.js는 이 개발 검사에만 필요하며 서버 실행이나 화면 사용에 필요하지 않습니다.
