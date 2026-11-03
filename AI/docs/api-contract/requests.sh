#!/usr/bin/env bash
# AI 서버가 8005 포트에서 실행 중일 때 사용합니다.
# 실제 사진 경로로 바꾸세요. 이 파일을 실행하면 로컬 서버로 사진을 전송합니다.

# 정면 사진 한 장
curl --fail-with-body -X POST 'http://127.0.0.1:8005/v1/analyze' \
  -F 'front_images=@/absolute/path/front.jpg' \
  -o response-front.json

# 정면 한 장 + 측면 한 장 (위 요청과 별개 예시)
curl --fail-with-body -X POST 'http://127.0.0.1:8005/v1/analyze' \
  -F 'front_images=@/absolute/path/front.jpg' \
  -F 'side_images=@/absolute/path/side.jpg' \
  -o response-front-side.json
