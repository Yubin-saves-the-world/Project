#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="${PYTHON312:-$(command -v python3.12 || true)}"
if [[ -z "$PYTHON_BIN" && -x "$HOME/.local/bin/python3.12" ]]; then PYTHON_BIN="$HOME/.local/bin/python3.12"; fi
if [[ -z "$PYTHON_BIN" ]]; then echo 'Python 3.12가 필요합니다.'; exit 1; fi
exec "$PYTHON_BIN" "$ROOT/scripts/run_flutter_demo.py" "$@"
