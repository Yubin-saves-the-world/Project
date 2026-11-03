# AI 연동 계약 — 현행 구현 기준 v1

갱신일: 2026-11-03. AI 코드 기준 계약이며 FE·BE 공동 합의가 완료됐다는 뜻은 아닙니다. FE/BE 파일은 수정하지 않았습니다.

## 요청

POST /v1/analyze, Content-Type: multipart/form-data (boundary는 클라이언트가 자동 생성).
- front_images: JPG/PNG 파일 정확히 1개, 필수.
- side_images: JPG/PNG 파일 최대 1개, 선택. 비어 있는 문자열 대신 필드 생략.
- include_review_previews: boolean, 기본 false. 상완 검수 UI가 필요할 때만 true.
- 파일당 10MB 이하, 최대 25,000,000 픽셀. EXIF 방향 보정 후 1024×1024 이내 축소.
- 포트는 실행 설정에 따라 달라집니다. 예시는 AI 직접 호출 8005입니다.
- /v1/analyze 직접 호출에는 현재 로그인 인증이 없습니다. 외부 공개용 인증 서버가 아닙니다.
- Flutter 연결에서는 인증이 필요한 POST /api/body-analyses/photo에 photo_id, 선택 side_photo_id를 전달하고, 받은 analysis_id로 GET /api/body-analyses/{analysis_id}를 조회합니다. 해당 응답은 직접 AI 응답과 별도 포장 형식입니다. goal_body_id 지원 여부와 목표 비교는 실제 BE 계약을 따릅니다. AI 브리지 데모의 제한을 실제 BE의 기능 범위로 해석하지 않습니다.

## 성공·항목 실패 원칙

- 전체 성공 HTTP 200, status=done. 일부 항목이 unavailable이어도 전체 성공일 수 있습니다.
- 측정 불가값은 null. 0은 측정 가능한 실제 0이므로 대체값으로 쓰지 않습니다.
- 기계 판정은 measures와 항목 status 사용. 한국어 설명을 파싱하지 않습니다.
- measures.unavailable는 {key:string,reason:string} 배열. 현재 측면 항목의 사유를 수록합니다. 모든 누락 관절 지표를 이 배열이 완전히 열거하는 것은 아닙니다.
- 표시 명칭: 측면 귀·어깨 각도. 기존 키 neck_forward_deg는 호환성을 위해 유지합니다. 귀–어깨 선과 사진 수직선의 각도이며 임상적 목 전방 자세 진단값이 아닙니다.
- balance_score, body_type, goal_comparison은 현재 null입니다. null을 정상·0점·목표 달성으로 변환하지 않습니다.
- judgements.level=unavailable / reason=PROFILE_NOT_VALIDATED는 정상/이상 판정 기준이 검증되지 않았음을 뜻합니다. 측정 실패와 구분합니다.

## 측정 불가·오류 코드

| 범위 | 코드 | 처리 |
|---|---|---|
| 측면 항목 | SIDE_PHOTO_MISSING | 사진 없음, 측면 업로드 안내 |
| 측면 항목 | LOW_CONFIDENCE | 측면 영상·인물·관절·방향을 충분히 확인하지 못함 |
| 정면 오류 | MULTIPLE_PEOPLE | 여러 인물 검출 |
| 상완 특징 | LOW_CONFIDENCE | 관절 불확실·영역 크기 부족, 해당 특징 추출 보류 |
| 판정 | PROFILE_NOT_VALIDATED | 측정 수치는 있을 수 있으나 판정 기준 미검증 |
| HTTP 413 | IMAGE_TOO_LARGE | 10MB 초과 |
| HTTP 422 | INVALID_IMAGE | 지원 형식·해상도·디코딩 확인 |
| HTTP 422 | IMAGE_BLURRY | 정면 흐림/단색 지표가 임시 기준 미만 |
| HTTP 422 | NO_PERSON | 정면 자세 미검출 |
| HTTP 422 | NOT_FULL_BODY | 필수 머리·어깨·골반·발목 추정점 부족 |
| HTTP 422 | VALIDATION_FAILED | 사진 개수 등 요청 확인 |
| HTTP 503 | AI_BUSY | 잠시 후 재시도 |
| HTTP 500 | AI_FAILED | 분석 내부 실패 |

직접 AI 오류 본문: {"detail":{"code":"...","message":"..."}}. FastAPI 필수 필드 누락 등의 검증 오류는 detail이 배열일 수 있습니다. Flutter 브리지는 {code,message,status,fields} 형식이며 같은 오류 포장으로 가정하지 않습니다.
알 수 없는 새 코드는 일반 안내로 표시하고 원래 코드를 보존합니다. 측면 파일 자체가 업로드 검증에 실패하면 전체 요청이 422가 될 수 있습니다. 측면 전용 흐림 검사 기준은 현재 별도로 적용되지 않습니다.

## measurement_report 구조

- version: string, 현행 photo-measurement-report-v1.
- title, summary, interpretation: string.
- measured_count: integer. items 중 measured 개수이며 joint_angles 전체 개수와 같지 않습니다.
- items: 배열. key, title, status(measured|unavailable), value(number|null), unit, display_value, description, meaning, limitation.
- 단위: °, 배, %. measures의 *_ratio는 무차원 비율.
- features: 배열. part, title, status(extracted|unavailable), description, classification_status, contour(object|null).
- classification_status는 현재 not_trained 또는 review_required 등이 가능. extracted는 근육 등급 판정 완료를 뜻하지 않습니다.
- next_steps: string 배열.
- capabilities: geometry, balance_score, body_type, muscle_grade, contour_classifier의 상태 문자열. 화면은 unknown 상태를 허용해야 합니다.
- items 자체에는 현재 reason 필드가 없습니다. measures.unavailable를 key로 연결합니다. null이지만 사유가 없으면 일반적인 측정 불가 안내를 사용합니다.

## photo_quality 구조

- width_px, height_px: integer. 처리 영상 해상도, 원본 해상도가 아님.
- blur_variance: number. 정면 처리 영상 회색조 Laplacian 분산; 정확도 점수가 아님. 정면 기준 <5면 오류 처리.
- required_landmarks_visible, required_landmarks_total: integer. 현재 필수 7개.
- minimum_landmark_score: number|null. 확인된 필수 관절의 최저 visibility.
- body_vertical_frame_fraction: number|null. 확인된 필수 관절 y좌표 범위; 실제 몸 전체 높이 측정이 아님. <0.45면 인물이 작다는 경고.
- person_check: object. status(checked|inconclusive|not_configured), 선택 detected_poses(integer), multiple_people_detected(boolean), detection_limit(integer), note(string). 미설정이면 status만 있을 수 있음.
- warnings: string 배열.
- score_meaning: string.
- content_safety: not_automatically_checked.
- front_view: not_automatically_verified.
- 의복·피부 가림·부적절 이미지·정면 여부의 자동 통과 판정으로 사용하지 않습니다.

## 계산·표시 기준

각도·거리는 정규화 좌표를 가로·세로 픽셀 크기로 환산한 후 계산합니다.
- 어깨/골반 기울기: 좌우 관절 연결선과 수평선의 차이, 절댓값.
- 어깨/골반 비율: 좌우 어깨 거리 / 좌우 골반 거리.
- 상체/다리 비율: 어깨 중심–골반 중심 거리 / 골반 중심–발목 중심 거리.
- 측면 각도: atan2(|귀x-어깨x|, |귀y-어깨y|)의 각도. 전방/후방 부호 없음.
- 현재 API는 수평에 가까움 구간을 확정 판정으로 반환하지 않습니다. 과거 2.5°/5° 구분은 설명용 임시 규칙이며 정상 기준이 아닙니다. FE/BE 문구를 별도 합의하기 전에는 숫자와 의미 설명을 우선합니다.

## 남은 구현

목표 사진의 기하 측정값 비교는 별도 POST /v1/compare 및 /goal-compare 화면으로 추가했습니다. 상세 계약은 GOAL_COMPARISON.md를 참조하세요. 기존 /v1/analyze 및 Flutter 브리지의 목표 비교 연결, 추천 우선 부위 반환, 운동 루틴 생성은 미구현입니다. 과거 camelCase API의 priorityParts 예시는 현행 /v1/analyze 계약에 포함하지 않습니다. 현 브리지 목표 비교·루틴 요청은 GOAL_NOT_READY로 거절합니다.

## 백엔드 포함 합의 제안 — 미구현·미합의

- 목표 사진 없음: 운동 목적, 경험, 주당 횟수, 이용 장비를 근거로 기본 전신 루틴. 사진 기반 맞춤 처방으로 표시하지 않음.
- 주의 항목은 none(없음), provided(있음), unknown(미입력) 구분. 미입력을 없음으로 간주하지 않음.
- 주의 항목 unknown일 때 기본 템플릿 제공 범위와 추가 확인 시점을 BE/FE와 합의. 주의 항목이 있을 때 제외 운동 매핑도 별도 합의.
- 제안 응답 필드: recommendation_mode, basis, missing_inputs, constraints_status, template_version. 이는 현재 API 응답 필드가 아님.
- 소유권 제안: AI는 측정·가용성·비교값, BE는 사용자 정보·주의 항목·운동 카탈로그·루틴 저장/조합, FE는 입력·표시. 최종 역할은 팀 합의 필요.
- 합의 전에는 현행 미지원 오류를 유지. FE/BE 파일을 임의 수정하지 않음.

## 예시 파일

response.structure.example.json은 실제 응답에서 구조 확인용 필드만 발췌한 예시입니다. 전체 원본 응답은 로컬 AI/.runtime/api-contract-review/actual-response.json에 있으며 사진의 base64와 384차원 특징을 포함합니다. 공개 저장소용 구조 예시에는 사진 바이트와 특징을 넣지 않았습니다.
requests.sh는 실행 포트와 실제 사진 경로를 바꿔 사용하는 요청 예시입니다.

2026-11-03 변경: 측면 원인 상세는 `measures.side_neck.diagnostic_reason`에 보관하고 공개 reason은 위 계약 어휘로 통일한다. `dinov3`는 모델 부재 시 null이며 사진 측정은 가능하다. 기본 요청 검증 오류도 detail 객체(code/message)다. `cases/actual-*`는 당시 실행 기록으로 이전 사유 코드가 포함될 수 있다. 현재 연결·직렬 호출·배포 범위는 [BE 연결 계약](../api-integration.md)을 따른다.
