# BE → AI 사진 측정 API 계약

2026-11-03 기준. 운영 연동은 `POST /v1/analyze`다. `/analyze/body`는 호환용 레거시이며 신규 BE 연동에 사용하지 않는다.

## 요청

`multipart/form-data`: 필수 `front_images` 정확히 1장, 선택 `side_images` 최대 1장. JPG/PNG, 파일별 10MB 이하·25MP 이하. 측면 사진은 정면 대신 사용하지 않는다.

```bash
curl -X POST http://127.0.0.1:8005/v1/analyze \
  -F 'front_images=@front.jpg' -F 'side_images=@side.jpg'
```

## 저장할 응답

- `measurement_version`: 현재 `pixel-dino-v2`(20자 이하).
- `measures`: `shoulder_tilt_deg`, `pelvis_tilt_deg`, `neck_forward_deg`, `shoulder_hip_ratio`, `torso_leg_ratio`. 측정 불가는 숫자 0이 아니라 null.
- `measures.unavailable[]`: `key`는 해당 measures 키, `reason`은 `SIDE_PHOTO_MISSING`, `LOW_CONFIDENCE`, `OCCLUDED`, `PROFILE_NOT_VALIDATED` 중 해당 값. 현재 측면 누락은 `SIDE_PHOTO_MISSING`, 측면 인식·관절·방향 불확실은 `LOW_CONFIDENCE`. 자세한 진단 코드는 확장 필드 `measures.side_neck.diagnostic_reason`에 보관한다.
- `judgements[]`: 모든 항목에 `item`, 비어 있지 않은 문자열 `label`, `value`, `unit`(`deg`/`ratio`), `level`, `reason` 포함.
- `balance_score`, `body_type`, `goal_comparison`: null. 임의 점수·10자를 넘는 체형 문자열을 만들지 않는다.
- `text_summary`와 `summary`: 사진상 측정 요약. 건강·정상/이상 판정이 아니다.
- `dinov3`: 모델 사용 가능 시 특징 블록, 사용 불가 시 null. DINOv3가 없어도 관절 측정은 완료할 수 있다. 라벨링·윤곽 분류는 모델이 필요하다.
- 확장 필드 `measurement_report`, `photo_quality`, `warnings`는 BE가 저장·전달하지 않을 수 있다. 원본 FE에서 보인다고 가정하지 않는다.

전체 구조와 요청 예시는 `api-contract/`를 참고한다. 과거 실행 응답은 당시 버전의 증거이므로 이전 측면 사유 코드가 남아 있을 수 있다. 현재 어휘는 본 문서가 기준이다.

## 오류와 직렬 호출

검증 오류도 `{"detail":{"code":"VALIDATION_FAILED","message":"요청 필드와 사진 개수를 확인해 주세요."}}` 형태다. 사용자 표시 메시지는 100자 이하다. 파일 내용·검증 입력값·서버 경로를 오류에 포함하지 않는다.

BE가 저장하는 코드: `IMAGE_BLURRY`, `NO_PERSON`, `MULTIPLE_PEOPLE`, `NOT_FULL_BODY`, `NOT_FRONTAL`, `AI_FAILED`, `AI_TIMEOUT`. AI는 추가로 `INVALID_IMAGE`, `IMAGE_TOO_LARGE`, `VALIDATION_FAILED`, `AI_BUSY`, 윤곽 전용 `MODEL_NOT_CONFIGURED` 등을 반환한다. 현재 BE는 미지원 코드를 `AI_FAILED`로 저장한다. BE·FE가 안전한 `error_message`를 표시하는 방안과 enum 확장은 담당자 합의 사항이다. 임의로 BE enum·DB를 수정하지 않는다.

AI는 추론 1건만 실행하며 중복 요청은 대기 큐 없이 HTTP 503 `AI_BUSY`다. **호출자는 직렬화해야 한다.** BE의 단일 워커 구성과 맞으며 다른 클라이언트·브리지도 같은 제한을 고려해야 한다. 90초 타임아웃 안에 완료하는지는 배포 장비에서 실제 사진으로 확인한다. 목표 비교 단계의 잔여 시간 제한은 BE가 관리한다.

## 모델과 상태 확인

`GET /health`: DINOv3 또는 다중 포즈 검사 자산이 없으면 HTTP 200, `status: degraded`. `dinov3_loaded`, `pose_guard_loaded`, `capabilities.multiple_people_check`, `capabilities.frontal_check`를 확인한다. 단순 HTTP 200만으로 모든 기능 준비를 판단하지 않는다.

DINOv3 로딩 실패 시 기본은 측정 전용 모드다. 반드시 필요하면 `AI_REQUIRE_DINO=1`로 기동 실패를 선택할 수 있다. `AI_CONTOUR_MODEL`은 DINOv3가 있어야 활성화된다. 윤곽 직접 분류는 모델 부재 시 HTTP 503 `MODEL_NOT_CONFIGURED`다.

포즈 자산 부재 시 다중 인물 검사는 사용할 수 없고 상태에 표시된다. `NOT_FRONTAL` 자동 검사는 현재 미구현이며 자동 검증된 정면 사진으로 표시하면 안 된다. 다중 포즈 검사가 있어도 사람 수를 보장하지 않는다.

## 책임 경계와 배포

글 분석 요약·목표 사진 요약·목표 비교는 최신 BE가 담당한다. AI `/v1/analyze`의 `goal_comparison`은 null 유지. AI의 별도 `/v1/compare`는 독립적인 실험용 기하 비교 화면이며 BE의 목표 비교 경로와 이중 호출하지 않는다. 모델·책임 위치를 옮기려면 팀 합의가 먼저다.

AI 브리지는 로컬 데모 어댑터다. 브리지 통과는 **FE → 실제 BE → AI → MySQL 통합 검증이 아니다.** 실제 BE의 사진 저장·할당량·목표 비교·오류 매핑·DB 제약은 별도 검증한다.

AI 서버에는 기본 인증이 없다. 기본 실행은 127.0.0.1에만 바인딩한다. 별도 머신 배포는 사설망·방화벽으로 BE만 접근하도록 제한해야 한다. 공개 인터넷 바인딩은 지원된 안전 배포로 간주하지 않는다. 공유 키 인증을 추가하려면 BE 요청 헤더 설정과 함께 합의해야 한다. CORS는 서버 간 인증·접근 통제를 대체하지 않는다.

BE의 외부 AI 전송과 동의 고지는 BE·FE 담당 범위다. AI 로컬 측정이 외부 전송을 하지 않는다는 사실을 전체 BE 목표 비교까지 확대해 설명하지 않는다.
