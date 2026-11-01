#!/usr/bin/env bash
bash "$(cd "$(dirname "$0")" && pwd)/run.sh" "$@"
status=$?
if [[ $status -ne 0 && -t 0 ]]; then
  echo '위 오류 안내를 확인하세요. Enter를 누르면 종료합니다.'
  read -r _
fi
exit "$status"
