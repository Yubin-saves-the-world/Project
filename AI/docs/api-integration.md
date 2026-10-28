# AI API 연동 사항

## 요청

- GET /health: 정상 실행 시 `{"status":"ok"}`
- POST /analyze/body: multipart/form-data
- 필수 `front_images`: 정면 전신 사진 파일. 같은 필드 이름으로 여러 장 전송
- 선택 `text`: 사용자 입력 문자열
- 성공 시 HTTP 200과 BodyAnalysisResponse, 사진 누락 시 HTTP 422

## 저장 필드 매핑

| AI 응답 | 기존 BE 필드 |
|---|---|
| measurementVersion | measurementVersion |
| posture.shoulderTiltDeg | shoulderTiltDeg |
| posture.pelvisTiltDeg | pelvisTiltDeg |
| posture.neckForwardDeg | neckForwardDeg (현재 null) |
| posture.balanceScore | balanceScore |
| bodyShape.bodyType | bodyType |
| bodyShape.shoulderHipRatio | shoulderHipRatio |
| bodyShape.torsoLegRatio | torsoLegRatio |
| judgements | judgementsJson |
| priorityParts | priorityPartsJson |
| comparisonSummary | comparisonSummary |
| comparisonDetail | comparisonDetail |
| textSummary | textSummary |

## 연결 전 조정할 사항

- 기존 BE의 bodyType 길이 10자는 UPPER_DOMINANT 및 LOWER_DOMINANT의 14자를 수용하지 못하므로 필드·DB 확장 또는 코드 매핑이 필요합니다.
- AI 각도 소수 둘째 자리와 BE 소수 첫째 자리 사이의 반올림 정책을 정해야 합니다.
- debugImages는 로컬 경로입니다. 별도의 이미지 저장소 또는 제공 API가 필요합니다.
- text 입력은 서버 길이 제한이 없지만 BE의 textSummary는 500자이므로 검증이 필요합니다.
- 정면 사진 여러 장과 BE의 photo/sidePhoto 관계를 정해야 합니다. 정면 사진을 측면 사진으로 임의 연결하지 않습니다.
- 서버 주소 127.0.0.1은 같은 컴퓨터에서만 접근 가능합니다. 별도 머신 연동 시 호스트와 네트워크 설정을 정해야 합니다.

실제 AI API 호출은 확인했지만 BE 호출·DB 저장·FE 표시까지 전체 연결은 검증하지 않았습니다.
