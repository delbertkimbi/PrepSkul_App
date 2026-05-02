import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/services/log_service.dart';

/// Agora Video View Widget
///
/// Displays local or remote video from Agora RTC engine.
/// Handles both Flutter Web and Mobile platforms.
/// 
/// STABILITY: Uses stable keys internally to prevent unnecessary widget recreation
/// which can cause video blackouts during network fluctuations.
class AgoraVideoViewWidget extends StatelessWidget {
  final agora_rtc_engine.RtcEngine engine;
  final int? uid;
  final bool isLocal;
  final agora_rtc_engine.RtcConnection? connection; // Optional connection for remote video
  final agora_rtc_engine.VideoSourceType? sourceType; // Optional source type (camera or screen)

  const AgoraVideoViewWidget({
    Key? key,
    required this.engine,
    required this.uid,
    this.isLocal = false,
    this.connection,
    this.sourceType,
  }) : super(key: key);
  
  /// Generate a stable key for the video view to prevent unnecessary recreation
  String get _stableKey {
    final type = isLocal ? 'local' : 'remote';
    final source = sourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen ? 'screen' : 'camera';
    return 'agora_video_${type}_${uid ?? 0}_$source';
  }

  // Prevent repeated local web setup calls on every rebuild.
  static final Map<String, String> _lastLocalSetupSignatureByUid = <String, String>{};
  static final Map<String, DateTime> _lastLocalSetupAtByUid = <String, DateTime>{};
  static final Map<String, String> _lastRemoteRenderSignatureByUid = <String, String>{};
  static final Map<String, DateTime> _lastRemoteRenderLogAtByUid = <String, DateTime>{};

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // For remote video, we need a connection with channelId
    // If connection is not provided or doesn't have channelId, show loading
    if (!isLocal && (connection == null || connection!.channelId == null)) {
      // Debug: Log why we're showing loading
      if (connection == null) {
        debugPrint('⚠️ [AgoraVideoView] Remote video: connection is null for UID=$uid');
      } else if (connection!.channelId == null) {
        debugPrint('⚠️ [AgoraVideoView] Remote video: connection.channelId is null for UID=$uid');
      }
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Determine the actual source type to use
    final actualSourceType = sourceType ?? agora_rtc_engine.VideoSourceType.videoSourceCamera;
    
    // Choose render mode:
    // - Camera: use HIDDEN (crop to fill, typical for faces)
    // - Screen share: use FIT (show whole shared screen without zooming/cropping)
    final renderMode = actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen
        ? agora_rtc_engine.RenderModeType.renderModeFit
        : agora_rtc_engine.RenderModeType.renderModeHidden;
    
    // CRITICAL: For screen sharing, we need to explicitly set up the video source
    // before creating the view controller
    final canvas = agora_rtc_engine.VideoCanvas(
      uid: isLocal ? 0 : uid!,
      sourceType: actualSourceType,
      renderMode: renderMode,
      // mirrorMode is optional - only set if available
    );

    // CRITICAL: Set up video source with correct sourceType
    // For local video: on web we call setupLocalVideo so the SDK binds to the plugin's element.
    // On Android/iOS we must NOT call setupLocalVideo here — the plugin's AgoraVideoView
    // creates the native view and binds it; our calling setupLocalVideo(canvas without view)
    // would clear that binding and cause a black preview.
    if (isLocal) {
      if (kIsWeb) {
        try {
          final sourceSig = actualSourceType.name;
          final uidKey = 'local_${uid ?? 0}';
          final now = DateTime.now();
          final previousSig = _lastLocalSetupSignatureByUid[uidKey];
          final previousAt = _lastLocalSetupAtByUid[uidKey];
          final shouldSetup = previousSig != sourceSig ||
              previousAt == null ||
              now.difference(previousAt) > const Duration(seconds: 10);

          if (shouldSetup) {
            _lastLocalSetupSignatureByUid[uidKey] = sourceSig;
            _lastLocalSetupAtByUid[uidKey] = now;
            engine.setupLocalVideo(canvas);
            if (actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen) {
              LogService.info('✅ [AgoraVideoView] Set up LOCAL video with SCREEN source (web)');
            } else {
              LogService.info('✅ [AgoraVideoView] Set up LOCAL video with CAMERA source (web)');
            }
            // Do not force-unmute from widget layer. AgoraService owns publish/mute policy.
          }
        } catch (e) {
          LogService.warning('⚠️ [AgoraVideoView] Failed to set up local video on web: $e');
        }
      }
      // On mobile, do not call setupLocalVideo — AgoraVideoView binds the view internally.
    } else {
      // For remote video, the VideoViewController.remote will handle setup
      // The canvas with sourceType is passed to the controller
      final remoteKey = 'remote_${uid ?? 0}';
      final sourceSig = actualSourceType.name;
      final now = DateTime.now();
      final previousSig = _lastRemoteRenderSignatureByUid[remoteKey];
      final previousAt = _lastRemoteRenderLogAtByUid[remoteKey];
      final shouldLog = previousSig != sourceSig ||
          previousAt == null ||
          now.difference(previousAt) > const Duration(seconds: 10);
      if (shouldLog) {
        _lastRemoteRenderSignatureByUid[remoteKey] = sourceSig;
        _lastRemoteRenderLogAtByUid[remoteKey] = now;
        if (actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen) {
          debugPrint('✅ [AgoraVideoView] Setting up REMOTE video with SCREEN source for UID=$uid');
        } else {
          debugPrint('✅ [AgoraVideoView] Setting up REMOTE video with CAMERA source for UID=$uid');
        }
      }
    }

    final controller = isLocal
        ? agora_rtc_engine.VideoViewController(
            rtcEngine: engine,
            canvas: agora_rtc_engine.VideoCanvas(
              uid: 0,
              sourceType: actualSourceType,
              renderMode: renderMode,
              // mirrorMode is optional - only set if available
            ),
          )
        : agora_rtc_engine.VideoViewController.remote(
            rtcEngine: engine,
            connection: connection!, // Safe to use ! here because we checked above
            canvas: agora_rtc_engine.VideoCanvas(
              uid: uid!,
              sourceType: actualSourceType,
              renderMode: renderMode,
              // mirrorMode is optional - only set if available
            ),
          );

    // Use stable key to prevent unnecessary widget recreation during network fluctuations
    return SizedBox.expand(
      key: ValueKey(_stableKey),
      child: agora_rtc_engine.AgoraVideoView(
        controller: controller,
      ),
    );
  }
}

