#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
backend_dir="${PREPSKUL_BACKEND_DIR:-../PrepSkul_Web}"
if ! curl -s --max-time 2 -o /dev/null http://localhost:3000/api/skulmate/session; then
  if [[ ! -d "$backend_dir" ]]; then
    echo 'Mate backend checkout is missing. Set PREPSKUL_BACKEND_DIR.' >&2
    exit 1
  fi
  (cd "$backend_dir" && npm run dev) &
  mate_backend_pid=$!
  trap 'kill "$mate_backend_pid" 2>/dev/null || true' EXIT
fi
if [[ ! -f build/web/index.html ]]; then
  flutter build web --release --no-wasm-dry-run
fi
printf 'PrepSkul: http://127.0.0.1:8080/#/student-nav\nMate API: http://localhost:3000/api\n'
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
