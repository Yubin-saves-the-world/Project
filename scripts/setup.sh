#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PYTHON312="${PYTHON312:-python3.12}"
"$PYTHON312" -m venv .venv
.venv/bin/python -m pip install -r AI/requirements-dinov3.txt
printf '\n설치 완료. 공식 모델 접근 승인을 받은 계정으로 .venv/bin/hf auth login을 실행하세요.\n'
