# DINOv3 API 계약

이 문서는 AI 담당 영역의 계약입니다. FE/BE 코드를 수정하거나 해당 연동이 완성됐다고 전제하지 않습니다.

## 경로 분리

| 경로 | 입력 | 응답 | 용도 |
| --- | --- | --- | --- |
| `GET /health` | 없음 | `status`, `dinov3_loaded`, `device` | 모델 로딩 후 상태 확인 |
| `POST /v1/analyze` | multipart `front_images` 1장 | snake_case | 새 MediaPipe + DINOv3 결과 |
| `POST /analyze/body` | multipart `front_images` 1~3장, 선택적 `text` | 기존 `BodyAnalysisResponse` camelCase | 기존 호출자의 응답 계약 유지 |

새 API는 요청 중 동기 계산 후 JSON을 반환합니다. 분석 ID·작업 조회·DB 저장·JWT 인증·사용자별 횟수 제한은 제공하지 않습니다. 호출하는 서버가 필요에 따라 담당해야 합니다. 기존 API의 `measurementVersion`, `posture`, `bodyShape`, `priorityParts` 등은 `schemas/analysis_result.py`를 따릅니다. 기존 debugImages의 경로는 임시 처리 파일 정보이며 다운로드 URL이 아닙니다. 사진 제한·오류 코드·임시 파일 삭제는 이번 버전의 명시적 제한입니다.

## 새 API의 주요 응답

| 필드 | 타입/의미 |
| --- | --- |
| `status` | 성공 시 `done` |
| `measurement_version` | `pixel-dino-v1` |
| `measures.shoulder_tilt_deg` | 사진상 어깨 연결선 기울기의 절댓값, 도 |
| `measures.pelvis_tilt_deg` | 사진상 골반 연결선 기울기의 절댓값, 도 |
| `measures.shoulder_hip_ratio` | 어깨 관절 간 거리 / 골반 관절 간 거리, 계산 불가 시 null |
| `measures.torso_leg_ratio` | 어깨 중심~골반 중심 / 골반 중심~발목 중심, 계산 불가 시 null |
| `measures.neck_forward_deg` | 현재 null |
| `measures.unavailable` | `key`, `reason` 배열; 목 분석은 `SIDE_ANALYSIS_NOT_IMPLEMENTED` |
| `dinov3.model`, `revision`, `device` | 사용 모델 정보 |
| `dinov3.parts` | 좌우 상완별 특징 또는 unavailable 상태 |
| `dinov3.parts[].cls` | 추출 성공 시 384차원 벡터 |
| `dinov3.parts[].patch_mean` | 추출 성공 시 평균 패치 384차원 벡터 |
| `dinov3.parts[].patch_shape` | 패치 배열 크기. 현재 기본 전처리에서 `[196,384]` |
| `dinov3.parts[].classification` | 추출 성공 시 `not_trained` |
| `debug_image_base64` | 관절·실루엣 확인용 JPEG/PNG 이미지의 Base64 문자열 |
| `balance_score`, `body_type`, `goal_comparison`, `text_summary` | 미지원이므로 null |
| `summary`, `warnings`, `judgements` | 참고 설명·제한 안내; 판정 level은 unavailable |
| `processing_seconds` | 서버 내 추론 처리 시간 |

각도와 비율은 사진 기울기·옷·관절 추정 오차에 영향을 받으며 근육량이 아닙니다. `extracted`는 특징 추출 성공만 뜻합니다. 상완 관절 신뢰도가 낮으면 해당 영역은 `unavailable`이며 다른 결과와 별도로 처리합니다. 벡터가 포함되므로 응답이 클 수 있습니다. 실제 이미지 특징과 Base64 원본은 일반 로그에 기록하지 않는 것이 좋습니다.

## 오류

형식은 `{"detail":{"code":"NO_PERSON","message":"..."}}`입니다. FastAPI 필수 필드 누락 검증은 기본 `detail` 배열일 수 있으므로 호출자는 두 형식을 처리해야 합니다.

| HTTP | 코드 | 의미 |
| --- | --- | --- |
| 413 | `IMAGE_TOO_LARGE` | 파일당 10MB 초과 |
| 422 | `VALIDATION_FAILED` | 사진 장수 불일치 |
| 422 | `INVALID_IMAGE` | 손상·지원하지 않는 형식·해상도 초과 |
| 422 | `IMAGE_BLURRY` | 단색 또는 극단적으로 흐린 사진 |
| 422 | `NO_PERSON` | 관절 추정 실패 |
| 422 | `NOT_FULL_BODY` | 주요 관절의 위치/신뢰도 불충분 |
| 503 | `AI_BUSY` | 이미 다른 요청 처리 중. 나중에 재시도 |
| 500 | `AI_FAILED` | 예상하지 못한 처리 실패 |

두 분석 경로는 같은 동시 처리 제한을 사용합니다. 타임아웃·취소·재시도 정책은 호출자가 별도로 정해야 합니다. 현재 서버에는 영구 작업 큐와 추론 강제 종료 기능이 없습니다.
