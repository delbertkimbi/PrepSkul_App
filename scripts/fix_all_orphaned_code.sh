#!/bin/bash
# Script to remove all orphaned code blocks (code after class closing braces)

echo "=== Removing orphaned code blocks ==="

# List of files with orphaned code (from previous scan)
files=(
  "lib/core/config/app_config.dart"
  "lib/core/config/web_env_reader.dart"
  "lib/core/config/web_env_helper.dart"
  "lib/core/config/web_env_helper_stub.dart"
  "lib/core/config/web_env_reader_stub.dart"
  "lib/core/navigation/navigation_state.dart"
  "lib/core/navigation/navigation_analytics.dart"
  "lib/core/utils/hourly_rate_parser.dart"
  "lib/core/utils/status_bar_utils.dart"
  "lib/core/services/web_splash_service_web.dart"
  "lib/core/services/push_notification_service.dart"
  "lib/core/services/google_calendar_service.dart"
  "lib/core/services/unblock_request_service.dart"
  "lib/core/services/tutor_data_validation_service.dart"
  "lib/core/services/splash_navigation_helper.dart"
  "lib/core/services/offline_cache_service.dart"
  "lib/core/services/web_splash_service_stub.dart"
  "lib/core/services/profile_completion_service.dart"
  "lib/core/widgets/offline_dialog.dart"
  "lib/core/widgets/offline_indicator.dart"
  "lib/core/widgets/app_logo_header.dart"
  "lib/core/widgets/skeletons/student_home_skeleton.dart"
  "lib/core/widgets/profile_completion_widget.dart"
  "lib/core/widgets/branded_snackbar.dart"
  "lib/core/widgets/initial_loading_screen.dart"
  "lib/features/auth/screens/role_selection_screen.dart"
  "lib/features/booking/models/tutor_request_model.dart"
  "lib/features/booking/screens/my_requests_screen.dart"
  "lib/features/booking/screens/my_sessions_screen.dart"
  "lib/features/booking/screens/tutor_booking_detail_screen.dart"
  "lib/features/booking/screens/request_detail_screen.dart"
  "lib/features/booking/screens/trial_payment_screen.dart"
  "lib/features/booking/services/quality_assurance_service.dart"
  "lib/features/booking/widgets/post_trial_dialog.dart"
  "lib/features/booking/widgets/location_selector.dart"
  "lib/features/payment/models/fapshi_transaction_model.dart"
  "lib/features/payment/screens/booking_payment_screen.dart"
  "lib/features/payment/services/fapshi_webhook_service.dart"
  "lib/features/payment/services/fapshi_service.dart"
  "lib/features/discovery/screens/web_video_helper.dart"
  "lib/features/discovery/screens/web_video_helper_stub.dart"
  "lib/features/sessions/services/fathom_summary_service.dart"
  "lib/features/sessions/services/connection_quality_service.dart"
  "lib/features/sessions/services/fathom_service.dart"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    # Find the last closing brace
    last_brace=$(grep -n "^}" "$file" | tail -1 | cut -d: -f1)
    if [ -n "$last_brace" ]; then
      total_lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$last_brace" -lt "$total_lines" ]; then
        echo "Fixing $file (class ends at $last_brace, file has $total_lines lines)"
        head -"$last_brace" "$file" > /tmp/$(basename "$file") && mv /tmp/$(basename "$file") "$file"
      fi
    fi
  fi
done

echo "=== Done ==="

