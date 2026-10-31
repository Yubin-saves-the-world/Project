#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/FE"
exec flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=DESKTOP_DEMO=true
