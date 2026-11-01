#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="${PYTHON312:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  for candidate in "$(command -v python3.12 || true)" "$HOME/.local/bin/python3.12" /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then PYTHON_BIN="$candidate"; break; fi
  done
fi
if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
  echo 'Python 3.12가 필요합니다. 설치 후 다시 실행하거나 PYTHON312에 실행 파일 경로를 지정하세요.'
  exit 1
fi
exec "$PYTHON_BIN" "$ROOT/scripts/launch.py" "$@"
