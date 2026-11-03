# 실제 API 실행 확인 사례

2026-11-02, 로컬 http://127.0.0.1:8005/v1/analyze 실행. 데이터·모델 교체 없이 호출했습니다. FE/BE 수정 없음.

| 파일 | 실제 HTTP | 입력/결과 |
|---|---|---|
| actual-front-side.structure.json | 200 | 로컬 Kaggle body_measurements inspection/1_front_img.jpg + 1_side_img.jpg. 측면 귀·어깨 각도 9.13°, measured, unavailable=[] |
| actual-side-no-person.structure.json | 200 | 위 정면 + 합성 흰색 JPG 측면. neck_forward_deg=null, side_neck.status=unavailable, reason=SIDE_NO_PERSON. 정면 측정은 유지 |
| actual-http-invalid-image.json | 422 | 이미지가 아닌 바이트를 JPG 파일 필드로 전송. detail 객체, INVALID_IMAGE |
| actual-http-blurry.json | 422 | 합성 흰색 JPG를 정면으로 전송. detail 객체, IMAGE_BLURRY |
| actual-http-missing-field.json | 422 | front_images 필드 없이 요청. detail 배열, FastAPI 필수 필드 검증 오류 |

structure 파일은 실제 전체 응답에서 이미지 base64·특징 벡터 등의 큰 필드만 제외한 구조 예시입니다. 전체 HTTP 200 응답 원본은 AI/.runtime/api-contract-review/actual-front-side.json 및 actual-side-no-person.json에 보존합니다. HTTP 오류 JSON은 전체 본문입니다. HTTP 상태 코드는 위 표를 함께 사용하세요. 9.13°는 예시 사진 결과이며 정상/이상 기준이 아닙니다.

SIDE_LANDMARKS_UNRELIABLE는 이번 실제 사진 요청에서 재현하지 않았습니다. SIDE_NO_PERSON를 해당 코드로 바꾸어 실제 결과라고 주장하지 않습니다. 같은 부분 성공 계약에서 unavailable 및 reason 값으로 구분합니다. side_neck의 unavailable 객체는 measured 객체보다 필드가 적으므로 unit/person_check/view_check 등을 필수로 가정하지 마세요.

## 정면+측면 요청

```bash
curl --fail-with-body -sS -w '\nHTTP %{http_code}\n' \
  'http://127.0.0.1:8005/v1/analyze' \
  -F 'front_images=@/absolute/path/front.jpg' \
  -F 'side_images=@/absolute/path/side.jpg' \
  -o response-front-side.json
```

## 앱·백엔드 파싱

1. HTTP 상태 코드를 먼저 검사합니다.
2. 200이면 status와 각 항목 status/value를 읽고, null은 0으로 바꾸지 않습니다.
3. side_neck.reason 또는 measures.unavailable에서 측면 재촬영 안내를 선택합니다. 정면 측정은 유지합니다.
4. 4xx/5xx이면 detail이 객체인지 배열인지 분기합니다. 객체는 code/message, 배열은 loc/type/msg를 처리합니다. 알 수 없는 포장은 일반 오류 안내로 처리합니다.
5. photo_quality는 정면 처리 영상 기준이며 측면 품질 점수로 재사용하지 않습니다. side_neck.person_check도 항상 존재하지 않습니다.
6. 여기의 예시는 AI 직접 API입니다. 인증·분석 ID 기반 Flutter 브리지의 상태/포장과 구분합니다.
