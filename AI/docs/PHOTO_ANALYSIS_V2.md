# 사진 분석 v2 실행·계약

현재 `/`는 AI 전용 홈이며 사진 업로드·상세 결과는 `/analysis`에 있습니다. 홈의 숫자 기록·비교·라벨 기준과 독립 평가 도구는 [후속 안내](AI_HOME_AND_VALIDATION.md)를 확인하세요.

변경 범위는 AI/뿐입니다. 팀 FE·BE·루트 설정은 변경하지 않았습니다. 이 화면은 AI 단독 테스트이며 원본 Flutter 화면에 새 UI를 삽입하지 않습니다.

## 실행

AI 폴더에서 `bash run.sh`를 실행하고 표시되는 로컬 주소를 엽니다. 실험 분류기까지 사용하려면 사람이 검수한 자료로 학습한 모델을 명시적으로 지정합니다.

```sh
AI_CONTOUR_MODEL="$PWD/.runtime/merged_reviewed_dataset/model.json" bash run.sh --port 8005 --no-browser
```

현재 컴퓨터에는 해당 실험 모델이 있습니다. 새 GitHub ZIP에는 사진·모델·라벨·가상환경·특징 파일을 넣지 않습니다. 새 다운로드에서 측정과 특징 추출은 공식 DINOv3 접근 승인 후 실행할 수 있지만, 실험 분류에는 본인의 검수 자료와 학습이 별도로 필요합니다. 임의 모델을 자동 생성하지 않습니다.

공식 MediaPipe 다중 포즈 모델도 최초 준비 시 다운로드합니다. 고정 URL:
https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task

SHA256: `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`

파일은 AI/.cache/models에만 저장합니다. AI_POSE_MODEL_PATH로 지정한 파일도 동일 SHA를 검사합니다. 직접 uvicorn을 실행해 파일이 없는 경우 인원 검사는 not_configured로 명시하며 검사가 완료됐다고 표시하지 않습니다. 표준 run.sh는 모델을 먼저 준비합니다.

## 사진 분석

POST /v1/analyze, multipart:

- front_images: 필수 정면 전신 JPG/PNG 1장
- side_images: 선택 측면 JPG/PNG 최대 1장
- include_review_previews: 기본 false. true이면 상완 크롭 JPEG 미리보기를 반환합니다. 분류 모델이 설정돼 있을 때만 검수 토큰도 생성합니다.

응답 measurement_version은 pixel-dino-v2입니다. 기존 키와 balance_score/body_type=null을 유지합니다. 추가 필드는 다음과 같습니다.

- photo_quality: 크기·흐림 수치·필수 관절 수·최소 관절 모델 점수·사진 내 세로 비중·인원 검사. 모델 점수는 측정 정확도가 아닙니다.
- measures.body_axis_tilt_deg: 어깨 중심~골반 중심 연결선과 사진 수직선의 차이.
- measures.arm_projected_length_difference_pct, leg_projected_length_difference_pct: 양쪽 관절 연결 길이 차이 / 평균 길이 ×100. 실제 팔다리 길이 차이가 아닙니다.
- measures.joint_angles: 좌우 팔꿈치·무릎의 2차원 사진상 각도.
- measures.side_neck: 측면 귀~어깨 연결선과 사진 수직선의 차이. neck_forward_deg는 기존 클라이언트 키를 유지하기 위한 별칭이며 거북목 판정값이 아닙니다.
- measurement_report.items: 측정값·뜻·한계·표시 단위. 측정되지 않은 값은 null입니다.
- debug_image_base64와 debug_image_mime: 얼굴 인덱스·실루엣·개발용 수평선 없이 몸통·팔다리 연결선만 표시한 JPEG.

측면이 없거나 귀·어깨를 신뢰하기 어려우면 정면 결과를 유지하면서 SIDE_PHOTO_REQUIRED / SIDE_LANDMARKS_UNRELIABLE / SIDE_NO_PERSON 등을 반환합니다. 넓은 어깨 투영으로 측면 여부를 확인하지 못하면 SIDE_VIEW_UNCONFIRMED입니다. 촬영 방향 검사는 설명용 휴리스틱이며 검증된 방향 분류기가 아닙니다. 확인할 정보가 부족하면 view_check=unverified로 명시합니다.

공식 task 모델로 최대 3개 포즈를 검사합니다. 주요 관절 중 4개 이상과 최소 세로 범위가 확인된 포즈가 2개 이상이면 MULTIPLE_PEOPLE(422)로 전신 분석을 거절합니다. 부분 인물·작은 인물 누락이나 배경 인쇄 사진 검출이 있을 수 있으므로 인물 수를 보장하지 않습니다. 정면 여부·의복·노출 적합성은 자동 검사하지 않습니다.

## 상완 검수와 분류 연결

전신 결과에서 상완 위치와 피부가 보이는지 사람이 확인한 뒤 POST /v1/contour/review JSON을 보냅니다.

```json
{"token":"전신 응답의 review_session.token", "skin_visible_confirmed":true}
```

서버가 생성한 768차원 특징만 사용하며 클라이언트의 임의 벡터 입력은 받지 않습니다. 토큰은 추측하기 어려운 난수이고 서버 메모리에 최대 32개를 보관하며 토큰은 최대 300초간 유효합니다. 만료 항목은 다음 토큰 생성·조회 시 제거합니다. 용량 초과 시 오래된 토큰부터 제거하고 서버 종료 시 폐기합니다. 미확인 요청은 REVIEW_REQUIRED(422), 없는/만료된 토큰은 REVIEW_EXPIRED(410), 분류기 미설정은 MODEL_NOT_CONFIGURED(503)입니다. 토큰에는 접근 권한이 있으므로 외부에 공유하지 않습니다. 파일·DB에 토큰을 저장하지 않습니다.

옷이 상완을 가리는 test1 사진은 특징 추출은 가능하지만 피부 윤곽 분류에 사용하면 안 됩니다. 별도 검수된 피부 크롭은 /contour-test에서 시험할 수 있습니다. 작은 데이터의 임계값 미달은 label=null, candidate_label은 참고 후보입니다. 정확도를 높여 보이려고 보류 기준을 낮추지 않았습니다.

## 화면

측정 카드, 촬영 정보, 접을 수 있는 관절 연결 이미지, 상완 검수, 결과 JSON 저장, 인쇄/PDF, 두 결과의 수치 차이를 제공합니다. 비교 기준은 같은 탭 메모리에만 보관하며 다음 분석을 실행해 비교합니다. 차이는 개선/악화로 분류하지 않습니다. 결과 JSON 내보내기는 원본/크롭 이미지·특징 벡터·검수 토큰을 제외합니다. 사용자가 선택한 다운로드 파일에는 측정 결과가 포함됩니다.

## 원본 Flutter 연결

AI/bridge가 이미 지원하던 side_photo_id를 실제 엔진에 전달하도록 고쳤습니다. 소유자와 current/side 유형 검증을 유지합니다. 기존 캐시 결과는 기존 측정 버전을 유지하므로 v2 재측정에는 사진을 새로 업로드해야 합니다. 새 카드와 검수 UI는 AI 웹에만 있습니다. 팀 Flutter의 화면 수정은 하지 않았습니다.

## 라벨링·평가

라벨 화면에 묶음 이름과 batch_id, 서버 저장 영수증을 표시합니다. 저장 요청의 batch_id가 현재 묶음과 다르면 409로 차단합니다. 오래 열린 이전 화면에서 다른 묶음에 잘못 저장하는 상황을 줄입니다. 기존 외부 API 사용자는 GET /api/entries의 batch_id를 저장 JSON에 포함해야 합니다.

```sh
.venv/bin/python scripts/audit_contour_data.py --dataset .runtime/merged_reviewed_dataset
```

읽기 전용으로 실제 저장 라벨·제외·등급별 인물 수·학습/평가 최소 부족 인원을 보고합니다. 원본 라벨을 재작성하거나 제외 사진을 자동 복원하지 않습니다. 최소 인원 충족은 학습 실행 준비 조건일 뿐이며 정확도 보장이 아닙니다. 격리 자료는 계속 사용하지 않습니다.

현재 검수 자료는 7명·11영역(clear 6, medium 5)이고 weak 자료가 없습니다. 독립 평가·더 다양한 사람의 사진·등급별 합의 검수가 남아 있습니다. 건강 점수·근육량·근력·의학적 체형·개인 운동 처방은 이 데이터로 구현 완료할 수 없습니다.

## 이번 변경의 실행 확인

- 단위·계약 검사 69개 통과: 측면 전달, 다중 인물 사전 거절, 결측 각도, 검수 토큰 확인/만료/용량 제한, 묶음 불일치 저장 거절, 학습 준비 수 집계 등.
- 사용자 원본 test1 사진으로 실제 DINOv3·MediaPipe 분석 완료, 필수 관절 7/7·포즈 1개·양쪽 상완 추출 확인.
- 같은 정면 사진을 측면 입력에 넣었을 때 정면 결과를 유지하고 SIDE_VIEW_UNCONFIRMED 반환.
- test1을 나란히 배치한 로컬 시험 이미지에서 MULTIPLE_PEOPLE 422 확인. 다양한 실제 다중 인물 사진에 대한 성능 평가를 뜻하지 않습니다.
- 별도로 검수된 v2 상완 크롭에서 medium 후보 0.58229, label=null, status=abstained 확인.
- 브라우저에서 사진 선택→분석→비교 기준 저장→결과 다운로드 확인. 다운로드 JSON에 사진·원시 특징·검수 토큰이 없는 것을 확인.
- 실제 측면 촬영 사진에 대한 독립 측정 정확도 평가는 아직 하지 않았습니다. 합성 좌표 검사와 잘못된 측면 입력 검사는 실제 측면 성능 검증을 대신하지 않습니다.
