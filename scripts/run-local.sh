#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p .runtime
PYTHON_BIN="${AI_PYTHON:-$ROOT/.venv/bin/python}"
# This computer already has the tested environment from the DINOv3 experiment.
if [[ ! -x "$PYTHON_BIN" && -x "$ROOT/../../movid-dinov3/.venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT/../../movid-dinov3/.venv/bin/python"
fi
if [[ ! -x "$PYTHON_BIN" ]]; then echo '먼저 bash scripts/setup.sh를 실행하세요.'; exit 1; fi
if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
fi
JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}java"
MODEL="${DINO_MODEL_PATH:-facebook/dinov3-vits16-pretrain-lvd1689m}"
EXPERIMENT_MODEL="$ROOT/../../movid-dinov3/.cache/hub/models--facebook--dinov3-vits16-pretrain-lvd1689m/snapshots/114c1379950215c8b35dfcd4e90a5c251dde0d32"
if [[ -z "${DINO_MODEL_PATH:-}" && -f "$EXPERIMENT_MODEL/model.safetensors" ]]; then MODEL="$EXPERIMENT_MODEL"; fi
export DINO_MODEL_PATH="$MODEL"
export MPLCONFIGDIR="$ROOT/.runtime/matplotlib"
export HF_HUB_CACHE="$ROOT/.cache/hub"
# Never stop a server started by another task or user.
"$PYTHON_BIN" - <<'PY'
import socket
for port in (8001,8080):
    with socket.socket() as s:
        if s.connect_ex(('127.0.0.1',port)) == 0:
            raise SystemExit(f'{port} 포트가 사용 중입니다. 기존 서버를 먼저 확인하세요.')
PY
(cd BE && GRADLE_USER_HOME="$ROOT/BE/.gradle-local" bash gradlew bootJar --console=plain)
AI_PID='';BE_PID=''
cleanup(){ [[ -z "$AI_PID" ]] || kill "$AI_PID" 2>/dev/null || true; [[ -z "$BE_PID" ]] || kill "$BE_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
(cd AI && exec "$PYTHON_BIN" -m uvicorn app:app --host "${AI_HOST:-127.0.0.1}" --port 8001) > .runtime/ai.log 2>&1 & AI_PID=$!
(cd BE && exec "$JAVA_BIN" -jar build/libs/BE-0.0.1-SNAPSHOT.jar --spring.profiles.active=demo --server.address="${BE_HOST:-127.0.0.1}" --server.port=8080) > .runtime/backend.log 2>&1 & BE_PID=$!
echo '서버 시작 중. 로그: .runtime/ai.log, .runtime/backend.log'
"$PYTHON_BIN" - <<'PY'
import time, urllib.request
for _ in range(120):
    try:
        for url in ('http://127.0.0.1:8001/health','http://127.0.0.1:8080/actuator/health'):
            with urllib.request.urlopen(url,timeout=2) as r: assert r.status==200
        break
    except Exception: time.sleep(1)
else: raise SystemExit('서버 시작 실패. .runtime 로그를 확인하세요.')
print('준비 완료: http://127.0.0.1:8080/integration.html')
print('로컬 계정: demo@movid.local / 최초 기본 비밀번호 movid1234')
print('종료하려면 Ctrl+C를 누르세요.')
PY
while kill -0 "$AI_PID" 2>/dev/null && kill -0 "$BE_PID" 2>/dev/null; do sleep 2; done
