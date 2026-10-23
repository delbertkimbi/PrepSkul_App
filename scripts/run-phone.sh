#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
printf 'Building PrepSkul from %s\n' "$PWD"
git log -1 --format='Revision: %h %s'
flutter pub get
if [[ "${MATE_LOCAL_API:-0}" == "1" ]]; then
  adb reverse tcp:3000 tcp:3000
  flutter run --dart-define=SKULMATE_HTTP_API_BASE=http://127.0.0.1:3000/api "$@"
else
  flutter run "$@"
fi
