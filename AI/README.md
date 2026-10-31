# MOVID AI 서버 통합본

실행·연동·검증 방법은 루트 [README_INTEGRATION.md](../README_INTEGRATION.md)를 기준으로 합니다.

- FastAPI는 시작 시 공식 DINOv3 모델을 1회 로딩합니다.
- POST /v1/analyze에 multipart front_images 정면 사진 1장을 받습니다.
- MediaPipe 관절·실루엣 분석과 좌우 상완 DINOv3 특징 추출을 수행합니다.
- 픽셀 좌표로 각도와 거리를 계산합니다.
- 근육 등급 분류기는 미학습입니다. 판정·균형 점수·목표 비교를 만들어 내지 않습니다.
- 요청 임시 원본과 중간 파일은 응답 후 삭제합니다.
- 응답은 snake_case이며 Spring이 DB에 저장하고 Flutter가 조회합니다.
- 기존 /analyze/body도 같은 응답으로 연결했습니다. 이전 camelCase 응답을 쓰던 독립 클라이언트는 갱신해야 합니다.

이 폴더의 과거 model-selection.md 등은 연구 계획 자료입니다. 현재 구현 상태는 루트 실행 안내를 확인하세요.
