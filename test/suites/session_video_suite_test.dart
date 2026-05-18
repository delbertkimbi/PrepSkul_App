// Consolidated session / classroom tests (single process, ordered groups).
// Hermetic: excludes `agora_video_session_test` (real Agora MethodChannel).
//
// Run:
//   flutter test test/suites/session_video_suite_test.dart
//
// Optional — Agora engine init against native bindings:
//   flutter test test/suites/session_video_native_test.dart
//
// Feature directory (excludes this suite — no duplicate counts):
//   flutter test test/features/sessions/

import 'package:flutter_test/flutter_test.dart';

import '../features/sessions/agora_adapter_boundary_test.dart'
    as agora_adapter_boundary_test;
import '../features/sessions/agora_cors_handling_test.dart'
    as agora_cors_handling_test;
import '../features/sessions/agora_production_config_test.dart'
    as agora_production_config_test;
import '../features/sessions/agora_recording_service_test.dart'
    as agora_recording_service_test;
import '../features/sessions/agora_screen_sharing_integration_test.dart'
    as agora_screen_sharing_integration_test;
import '../features/sessions/agora_session_navigation_test.dart'
    as agora_session_navigation_test;
import '../features/sessions/agora_session_uid_test.dart'
    as agora_session_uid_test;
import '../features/sessions/agora_session_validation_test.dart'
    as agora_session_validation_test;
import '../features/sessions/agora_token_service_test.dart'
    as agora_token_service_test;
import '../features/sessions/call_status_banner_test.dart'
    as call_status_banner_test;
import '../features/sessions/classroom_offline_banner_test.dart'
    as classroom_offline_banner_test;
import '../features/sessions/classroom_orchestrator_test.dart'
    as classroom_orchestrator_test;
import '../features/sessions/classroom_workspace_dod_test.dart'
    as classroom_workspace_dod_test;
import '../features/sessions/classroom_workspace_indexed_stack_test.dart'
    as classroom_workspace_indexed_stack_test;
import '../features/sessions/gallery_grid_layout_test.dart'
    as gallery_grid_layout_test;
import '../features/sessions/gallery_paging_chunks_test.dart'
    as gallery_paging_chunks_test;
import '../features/sessions/network_quality_combine_test.dart'
    as network_quality_combine_test;
import '../features/sessions/participant_registry_model_test.dart'
    as participant_registry_model_test;
import '../features/sessions/phase_c_dod_validation_test.dart'
    as phase_c_dod_validation_test;
import '../features/sessions/prejoin_readiness_lobby_wiring_test.dart'
    as prejoin_readiness_lobby_wiring_test;
import '../features/sessions/preply_classroom_dod_test.dart'
    as preply_classroom_dod_test;
import '../features/sessions/profile_card_overlay_test.dart'
    as profile_card_overlay_test;
import '../features/sessions/qoe_telemetry_pipeline_test.dart'
    as qoe_telemetry_pipeline_test;
import '../features/sessions/quality_controller_test.dart'
    as quality_controller_test;
import '../features/sessions/reconnect_grace_policy_test.dart'
    as reconnect_grace_policy_test;
import '../features/sessions/rollout_flags_guard_test.dart'
    as rollout_flags_guard_test;
import '../features/sessions/screen_sharing_test.dart' as screen_sharing_test;
import '../features/sessions/screenshare_owner_transition_test.dart'
    as screenshare_owner_transition_test;
import '../features/sessions/session_connection_help_sheet_test.dart'
    as session_connection_help_sheet_test;
import '../features/sessions/session_in_call_info_sheet_test.dart'
    as session_in_call_info_sheet_test;
import '../features/sessions/session_mode_statistics_service_test.dart'
    as session_mode_statistics_service_test;
import '../features/sessions/session_state_ux_stability_test.dart'
    as session_state_ux_stability_test;
import '../features/sessions/speaking_uid_debouncer_test.dart'
    as speaking_uid_debouncer_test;
import '../features/sessions/stream_priority_policy_test.dart'
    as stream_priority_policy_test;
import '../features/sessions/workspace_session_ui_wiring_test.dart'
    as workspace_session_ui_wiring_test;
import '../features/sessions/workspace_sync_state_test.dart'
    as workspace_sync_state_test;
import '../features/sessions/workspace_realtime_sync_auth_test.dart'
    as workspace_realtime_sync_auth_test;
import '../features/sessions/widgets/incall_chat_panel_test.dart'
    as incall_chat_panel_test;

void main() {
  group('Session / video / classroom suite', () {
    group('Agora & tokens', () {
      agora_token_service_test.main();
      agora_session_uid_test.main();
      agora_session_navigation_test.main();
      agora_session_validation_test.main();
      agora_cors_handling_test.main();
      agora_recording_service_test.main();
      agora_production_config_test.main();
      agora_adapter_boundary_test.main();
    });

    group('Screen share', () {
      screen_sharing_test.main();
      agora_screen_sharing_integration_test.main();
      screenshare_owner_transition_test.main();
    });

    group('Gallery & layout', () {
      gallery_grid_layout_test.main();
      gallery_paging_chunks_test.main();
    });

    group('Classroom workspace & orchestration', () {
      classroom_workspace_indexed_stack_test.main();
      classroom_workspace_dod_test.main();
      classroom_orchestrator_test.main();
      workspace_sync_state_test.main();
      workspace_realtime_sync_auth_test.main();
      workspace_session_ui_wiring_test.main();
      preply_classroom_dod_test.main();
      phase_c_dod_validation_test.main();
    });

    group('In-call UI & chat', () {
      call_status_banner_test.main();
      classroom_offline_banner_test.main();
      session_connection_help_sheet_test.main();
      session_in_call_info_sheet_test.main();
      incall_chat_panel_test.main();
      profile_card_overlay_test.main();
      prejoin_readiness_lobby_wiring_test.main();
    });

    group('Quality, QoE, reconnect', () {
      quality_controller_test.main();
      network_quality_combine_test.main();
      stream_priority_policy_test.main();
      reconnect_grace_policy_test.main();
      qoe_telemetry_pipeline_test.main();
      speaking_uid_debouncer_test.main();
    });

    group('Participants & session state', () {
      participant_registry_model_test.main();
      session_state_ux_stability_test.main();
      session_mode_statistics_service_test.main();
    });

    group('Flags & rollout', () {
      rollout_flags_guard_test.main();
    });
  });
}
