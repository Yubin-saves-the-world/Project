# MOVID AI 연동 작업본

2026-10-28 첨부 Project-main.zip을 별도 작업본으로 풀어 기존 FastAPI와 MediaPipe에 DINOv3를 통합했습니다. 원본 ZIP과 이전 실험 폴더는 변경하지 않았습니다.

## 지금 실행되는 흐름

Flutter의 기존 사진·분석 API 경로 → Spring JWT 인증·사진 저장 → 분석 ID 즉시 반환 → FastAPI 호출 → MediaPipe 수치와 DINOv3 상완 특징 계산 → DB 저장 → Flutter가 2초마다 조회 → 결과 표시.

브라우저에서 같은 경로를 확인하는 페이지도 있습니다: http://127.0.0.1:8080/integration.html
로컬 시연 계정은 `demo@movid.local`, 최초 기본 비밀번호는 `movid1234`입니다. 로그인 토큰은 페이지 메모리에서만 유지합니다.

## 빠른 실행

이 컴퓨터에서는 기존 `movid-dinov3`의 검증된 Python 환경과 승인된 모델 캐시를 자동으로 찾습니다. 프로젝트 루트에서:

```sh
bash scripts/run-local.sh
```

또는 `MOVID 실행.command`를 실행합니다. 8001/8080 포트가 이미 사용 중이면 기존 서버를 임의 종료하지 않고 중단합니다. 이 작업에서 띄운 서버가 현재 실행 중이면 아래 시연 주소부터 사용하면 됩니다.

- AI 상태: http://127.0.0.1:8001/health
- AI API 문서: http://127.0.0.1:8001/docs
- 백엔드 상태: http://127.0.0.1:8080/actuator/health
- 브라우저 시연: http://127.0.0.1:8080/integration.html
- 종료: 실행 터미널에서 Ctrl+C

### 다른 컴퓨터

Python 3.12, Java 17, 인터넷 연결이 필요합니다.

```sh
bash scripts/setup.sh
.venv/bin/hf auth login
bash scripts/run-local.sh
```

DINOv3 모델 이용 승인을 받은 계정이 필요합니다. `DINO_MODEL_PATH`로 승인된 로컬 Transformers 모델 폴더를 지정할 수 있습니다. 가중치나 토큰은 배포 ZIP에 포함하지 않습니다. 서버가 시작할 때 모델을 한 번 로딩해 재사용합니다.

## Flutter 연결

이 ZIP 앱에는 이미 서버 모드 사진 업로드와 분석 조회가 구현돼 있습니다. 이번 작업은 결과 모델과 화면에 DINOv3 처리 상태·검출 이미지를 추가했습니다. 새 회원가입은 이메일 인증 API가 아직 백엔드에 없으므로 시연 계정으로 로그인하세요.

```sh
cd FE
flutter pub get
# Android emulator: BE_HOST=0.0.0.0으로 서버 실행 후
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
# iOS simulator / desktop
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=DESKTOP_DEMO=true
```

`USE_LOCAL_PREVIEW=true`는 실제 서버 연결이 아니므로 지정하지 마세요. 실제 휴대폰은 PC와 같은 네트워크에서 `BE_HOST=0.0.0.0 PUBLIC_BASE_URL=http://PC의LAN주소:8080 bash scripts/run-local.sh`로 실행하고 API_BASE_URL에도 같은 LAN 주소를 사용합니다. Android HTTP 연결은 debug 모드만 허용합니다. 외부 공개 배포용 설정은 아닙니다.

## API 계약

- `POST /api/photos`: 인증 필요. multipart `image`, `type=current`, `side=front`. 201과 photo_id, 한 시간 유효한 HMAC 서명 URL.
- `POST /api/body-analyses/photo`: `{ "photo_id": 1 }`. 202와 analysis_id. 목표 비교는 아직 지원하지 않으며 goal_body_id 요청은 명시적 오류.
- `GET /api/body-analyses/{id}`: pending/done/failed. failed도 HTTP 200이며 error_code 표시.
- `GET /api/body-analyses`: 분석 이력.
- `GET /api/body-analyses/usage`: 하루 3회, failed는 제외. 같은 사진 ID의 완료 결과를 재사용.
- `DELETE /api/photos/{id}`, `DELETE /api/photos`: 파일 삭제와 삭제 표시. 분석 중 사진은 삭제하지 않음.
- 내부 `POST http://127.0.0.1:8001/v1/analyze`: multipart front_images 파일 1장. Spring만 호출. 별도 인증이 없으므로 외부로 노출하지 않습니다.
- 기존 AI `/analyze/body`도 같은 통합 응답으로 연결했습니다. 과거 camelCase 응답과 달라졌으므로 별도 외부 호출자는 업데이트해야 합니다.

응답은 기존 Flutter의 snake_case 계약에 맞췄습니다. DINOv3 정보는 추가 `dinov3` 필드에 있으며 CLS/patch 평균, 공간 특징 크기를 포함합니다. debug_image_base64에 검출 이미지를 반환합니다.

## 저장과 실행 모드

- 기본 설정은 기존 MySQL·Flyway를 유지합니다. V4 마이그레이션으로 body_analyses에 result_payload LONGTEXT만 추가했습니다.
- 빠른 시연은 별도 `demo` 프로필: `BE/data/integration-demo.mv.db` H2 파일 DB. 기존 MySQL 데이터와 분리하며 서버 재시작 뒤에도 결과를 유지합니다. Flyway는 이 프로필에서만 끄고 Hibernate로 테이블을 만듭니다.
- 시연 계정의 신체정보·동의는 가상 시연 데이터입니다. demo 프로필에서만 생성됩니다. 실제 사용자 가입·동의로 오인하지 마세요.
- 사진은 `BE/data/photos`에 저장하고 삭제 API에서 실제 파일도 삭제합니다. AI의 요청별 임시 원본·중간 결과는 응답 직후 삭제합니다. 분석 검출 이미지와 특징은 DB 결과에 남습니다.
- 앱·브라우저에서 목표 체형·추천 루틴·식단·AI 코치를 눌러도 이 작업에서 해당 기능을 새로 구현한 것은 아닙니다. 사진 분석 경로가 이번 통합 범위입니다.

## 구현된 분석과 한계

- EXIF 방향 보정, JPEG/PNG 확인, 10MB 제한, 과도한 해상도 거부, AI 입력 1024px 축소.
- 관절 기반 각도·거리 계산을 픽셀 좌표로 수정해 가로세로 비율 왜곡 방지.
- 사람을 못 찾거나 주요 관절이 화면 밖/신뢰도 부족이면 failed. 단색·극심한 흐림은 거부합니다. 다중 인물·정면 여부·의복 노출 판단은 아직 구현하지 않았습니다.
- 좌우 상완 crop → 공식 DINOv3 ViT-S/16 특징 추출. 판정기는 미학습이며 근육량·근력·체지방률을 측정하지 않습니다.
- 균형 점수·체형 등급은 null, 자세 판정은 unavailable. 목 전방 각도는 측면 사진이 있어도 아직 구현하지 않았습니다.
- Qwen-VL 설명, 목표 체형 비교, 루틴 생성은 미구현입니다. 기존 수치 요약과 경고를 반환합니다.
- Spring은 AI 요청을 최대 85초 기다리고, 90초 지난 pending은 실패 처리합니다. 백엔드/AI 모두 단일 분석 동시 처리로 메모리를 제한하며 다른 사용자의 동시 작업은 실패·재시도 안내합니다. 재시작 후 남은 pending은 타임아웃 처리합니다. 운영용 분산 큐는 없습니다.
- 이 시연 서버는 HTTPS·S3·대규모 운영 배포가 아닙니다. 공개 배포 전 사진 보관/탈퇴 파기·목표 사진 수명·관리 기능을 완성해야 합니다.

## 검증

`validation/live-smoke.json`, `validation/negative-smoke.json`, `validation/restart-smoke.json`에 실제 테스트 요약을 저장했습니다. 인증 토큰·사진 원본은 이 검증 파일에 기록하지 않습니다.

```sh
# 서버 실행 후 전체 경로 검사
.venv/bin/python scripts/smoke_integration.py /absolute/front.jpg
.venv/bin/python scripts/check_failures.py
# 앱의 실제 Repository로 HTTP 연결·결과 파싱 확인
cd FE
flutter test test/live/ai_integration_live_test.dart --dart-define=LIVE_AI_IMAGE=/absolute/front.jpg
```

확인 범위: 실제 사진의 Spring→FastAPI→MediaPipe·DINOv3→H2 저장, 재조회, 캐시, 인증·소유권·사진 서명·실패 처리. MySQL 실제 실행 검증은 시스템 mysqld의 공유 라이브러리 누락과 Docker 미실행으로 수행하지 못했습니다. MySQL 배포 전 V4 적용과 통합 검사를 추가로 해야 합니다. 전체 앱의 모든 화면을 기기에서 수동 검증한 것은 아닙니다.

### 이번 검증 결과

- Spring 최종 빌드 성공, demo 프로필 컨텍스트 테스트 1개 통과. 기존 MySQL 전용 테스트 40개는 DB_URL 미지정으로 건너뛰었습니다.
- Python 좌표·crop 검사 3개 통과.
- Flutter 사진·분석 관련 테스트 33개 통과. Flutter 실제 Repository를 통한 실서버 사진 분석 1개 통과.
- flutter analyze는 변경 범위의 오류는 없지만 원본 커뮤니티 코드의 info 1개와 아이콘 테스트의 warning 1개가 남아 종료 코드는 1입니다.
- 실제 Android/iOS 기기 빌드·전체 화면 수동 조작은 이번 검증 범위에 포함하지 않았습니다.

## 2026-10-28 macOS 직접 실행 보완

- 기존 Flutter 화면을 유지하고 macos 네이티브 실행 프로젝트를 추가했습니다. 설치된 Xcode에 맞춰 macOS 12.0 이상으로 설정했습니다.
- root와 FE 폴더 양쪽 .vscode/launch.json에 `MOVID · macOS · 실제 서버` 구성을 추가했습니다. VS Code 실행 및 디버그에서 선택해 F5로 실행할 수 있습니다.
- 네트워크 요청과 사용자가 선택한 사진 읽기 권한을 추가했습니다. Android 에뮬레이터·avdmanager 없이 Mac 앱으로 실행됩니다.
- 개발자 인증서 없이 로컬 시연하기 위해 DESKTOP_DEMO=true인 macOS debug 실행만 메모리 토큰 저장소를 사용합니다. 앱 재시작 시 다시 로그인합니다. 서버 JWT 인증·운영 기본 보안 저장소는 유지합니다. Release는 기존 보안 저장소를 사용하므로 배포 시 개발자 서명이 필요합니다.
- 실행 검증: MOVID.app debug 빌드와 Flutter VM Service 시작 확인. 창 앞으로 가져오기는 Computer Use 권한이 없어 수행하지 못했습니다. Dock에서 MOVID를 선택하세요. 사진은 촬영 대신 앨범/파일 선택을 사용하세요.

추가 회귀 검사: 앱 진입·가입·분석 묶음에서 35개 통과, 기존 화면 비교(golden) 11개는 픽셀 차이로 실패했습니다. 기준 이미지는 자동 갱신하지 않았습니다. macOS 빌드와 앱 프로세스·VM Service 실행은 성공했습니다.

## 2026-10-28 사진 측정값 설명 추가

- 저장된 분석 조회 응답에 summary·observations·next_steps·interpretation_note를 생성합니다. 기존 기록도 재분석 없이 설명이 붙습니다.
- 설명은 MediaPipe 측정값을 바탕으로 한 명시적 규칙이며 Qwen-VL 출력이나 DINOv3 근육 분류가 아닙니다. 사진상 연결선의 기울기와 관절 간 비율만 설명합니다. 2.5°·5°는 설명용 임시 구분으로 의료적 정상/이상 기준이 아닙니다.
- 사진 측정 완료와 근육 등급 미제공을 구분하고, 반복된 판정 불가 문구 대신 사진상 관찰 내용을 표시합니다. 개발용 검출 이미지는 접을 수 있는 영역에 넣었습니다.
- capabilities.routine_generation=false인 이 서버의 결과에서는 작동하지 않는 루틴 생성 버튼을 표시하지 않습니다. 다른 서버 응답은 기존 동작을 유지합니다.
- 검증: 설명 생성 JUnit 3개, Flutter 분석 테스트 18개 통과. 실서버에서 기존 analysis_id=5에 설명 4개가 붙는 것을 확인했습니다. validation/explanation-smoke.json 참고.

## 관리자 분석 횟수

서버가 DB의 User.Role.admin을 확인해 분석 횟수 제한을 면제합니다. 일반 회원은 하루 3회 정책을 유지합니다. demo 프로필은 기존 demo@movid.local 계정과 새 시연 계정을 admin으로 설정하며, 다른 환경의 계정을 자동 승격하지 않습니다. usage 응답에 unlimited=true를 추가했고 관리자 limit/remaining의 0은 횟수 소진이 아니라 비적용을 뜻합니다. 앱은 unlimited를 우선해 분석 시작을 허용하고 '관리자 계정 · 분석 횟수 제한 없음'으로 표시합니다. 동시 분석·사진 크기·사진 저장 장수 등의 제한은 그대로입니다.

결과 화면 가독성 개선: 부위별 수치·짧은 설명 카드로 통합해 중복을 제거했습니다. 2열/1열 반응형, 두 자리 소수 표시, 접힌 참고 정보로 정리했습니다. 검증 이미지: FE/docs/project-context/previews/analysis-readable-desktop.png 및 analysis-readable-mobile.png.


## 2026-10-31 코드 리뷰 및 오류 방어

- Flutter `data` 소스까지 제외하던 Git 규칙을 `/BE/data/`로 제한했습니다. 사진·모델·토큰·DB 및 생성된 테스트 차이 이미지는 배포에서 제외합니다.
- 잘못된 Base64/빈 검출 이미지는 화면 오류 대신 안내를 표시하고, 비유한 수치는 미측정으로 처리합니다.
- 화면 대기 제한을 110초로 맞춰 서버의 90초 분석 제한보다 먼저 종료되지 않도록 했습니다. 미지원 루틴은 ViewModel에서도 차단합니다.
- AI의 누락·비유한 비율과 관절점 입력을 방어합니다. 백엔드는 잘못된 성공 응답/범위를 완료 결과로 저장하지 않습니다. 업로드 파일을 읽기 전에 계정·동의를 검사하고 잘못된 이미지 헤더는 입력 오류로 응답합니다.
- 기본 서버 컨텍스트 테스트는 개발자 MySQL 대신 별도 메모리 H2 DB를 사용합니다. MySQL 전용 40개 검사는 별도로 실행해야 합니다.
- macOS를 추가할 때 기존 Android/iOS 마이그레이션 정보를 보존합니다. Flutter 잠금 파일은 이번에 검증한 Flutter 3.44/Dart 3.12 계열입니다.
- 검증: AI 5개, Flutter 분석 25개, 백엔드 10개 통과(기존 MySQL 검사 40개 미실행), bootJar 성공. 임시 DB에서 test1.jpg 실제 추론·서명·인증·캐시 및 실패/소유권 검사를 통과했습니다. 사용자 DB와 사진을 GitHub에 포함하지 않습니다.

전체 리뷰 결과: [CODE_REVIEW_2026-10-31.md](docs/CODE_REVIEW_2026-10-31.md)
