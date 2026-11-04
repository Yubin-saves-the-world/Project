#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$ROOT/run.sh" --install-only "$@"
"$ROOT/.venv/bin/python" "$ROOT/scripts/check_coach.py"
exec bash "$ROOT/run.sh" --no-browser --port 8023 "$@"
