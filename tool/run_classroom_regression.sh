#!/usr/bin/env bash
# Runs the classroom + booking automated regression pack (Flutter) and optionally
# Next.js Agora token authz tests (Jest).
#
# Usage:
#   bash prepskul_app/tool/run_classroom_regression.sh
#   bash prepskul_app/tool/run_classroom_regression.sh --with-web
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$APP_ROOT/.." && pwd)"
WEB_ROOT="$REPO_ROOT/PrepSkul_Web"

WITH_WEB=0
for arg in "$@"; do
  case "$arg" in
    --with-web) WITH_WEB=1 ;;
    -h|--help)
      echo "Usage: $0 [--with-web]"
      echo "  --with-web  Also run PrepSkul_Web Jest: __tests__/agora/session-service-authz.test.ts"
      exit 0
      ;;
  esac
done

TESTS=(
  test/features/sessions/agora_adapter_boundary_test.dart
  test/features/sessions/classroom_orchestrator_test.dart
  test/features/sessions/participant_registry_model_test.dart
  test/features/sessions/quality_controller_test.dart
  test/features/sessions/stream_priority_policy_test.dart
  test/features/sessions/reconnect_grace_policy_test.dart
  test/features/sessions/session_state_ux_stability_test.dart
  test/features/sessions/screenshare_owner_transition_test.dart
  test/features/sessions/phase_c_dod_validation_test.dart
  test/features/sessions/rollout_flags_guard_test.dart
  test/features/sessions/qoe_telemetry_pipeline_test.dart
  test/features/sessions/agora_session_navigation_test.dart
  test/features/sessions/agora_video_session_test.dart
  test/features/booking/session_participants_enrollment_test.dart
  test/features/booking/booking_flow_integration_test.dart
)

cd "$APP_ROOT"
echo "==> Flutter classroom regression (@ $APP_ROOT)"
flutter test "${TESTS[@]}"

if [[ "$WITH_WEB" -eq 1 ]]; then
  if [[ ! -f "$WEB_ROOT/package.json" ]]; then
    echo "ERROR: PrepSkul_Web not found at $WEB_ROOT" >&2
    exit 1
  fi
  echo "==> Jest Agora session authz (@ $WEB_ROOT)"
  pnpm --dir "$WEB_ROOT" test -- __tests__/agora/session-service-authz.test.ts
fi

echo "==> All requested checks passed."
