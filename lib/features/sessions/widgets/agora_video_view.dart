import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/services/log_service.dart';

/// Agora Video View Widget
///
/// Displays local or remote video from Agora RTC engine.
/// Handles both Flutter Web and Mobile platforms.
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
    
    // CRITICAL: For screen sharing, we need to explicitly set up the video source
    // before creating the view controller
    final canvas = agora_rtc_engine.VideoCanvas(
      uid: isLocal ? 0 : uid!,
      sourceType: actualSourceType,
      // mirrorMode is optional - only set if available
    );

    // CRITICAL: Set up video source with correct sourceType
    // For local video, we need to call setupLocalVideo
    // For remote video, VideoViewController.remote handles setup automatically via the canvas
    if (isLocal) {
      // For local video (both camera and screen)
      // CRITICAL: On web, ensure setupLocalVideo is called with explicit source type
      try {
        engine.setupLocalVideo(canvas);
        if (actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen) {
          if (kIsWeb) {
            LogService.info('✅ [AgoraVideoView] Set up LOCAL video with SCREEN source (web)');
          } else {
            debugPrint('✅ [AgoraVideoView] Set up LOCAL video with SCREEN source');
          }
        } else {
          if (kIsWeb) {
            LogService.info('✅ [AgoraVideoView] Set up LOCAL video with CAMERA source (web)');
          } else {
            debugPrint('✅ [AgoraVideoView] Set up LOCAL video with CAMERA source');
          }
        }
        
        // CRITICAL: On web, ensure video stream is unmuted after setup
        if (kIsWeb && actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceCamera) {
          // Use a post-frame callback to ensure unmute happens after setup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            engine.muteLocalVideoStream(false).catchError((e) {
              LogService.warning('Could not unmute local video after setup: $e');
            });
          });
        }
      } catch (e) {
        if (kIsWeb) {
          LogService.warning('⚠️ [AgoraVideoView] Failed to set up local video on web: $e');
        } else {
          debugPrint('⚠️ [AgoraVideoView] Failed to set up local video: $e');
        }
      }
    } else {
      // For remote video, the VideoViewController.remote will handle setup
      // The canvas with sourceType is passed to the controller
      if (actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen) {
        debugPrint('✅ [AgoraVideoView] Setting up REMOTE video with SCREEN source for UID=$uid');
      } else {
        debugPrint('✅ [AgoraVideoView] Setting up REMOTE video with CAMERA source for UID=$uid');
      }
    }

    final controller = isLocal
        ? agora_rtc_engine.VideoViewController(
            rtcEngine: engine,
            canvas: agora_rtc_engine.VideoCanvas(
              uid: 0,
              sourceType: actualSourceType,
              // mirrorMode is optional - only set if available
            ),
          )
        : agora_rtc_engine.VideoViewController.remote(
            rtcEngine: engine,
            connection: connection!, // Safe to use ! here because we checked above
            canvas: agora_rtc_engine.VideoCanvas(
              uid: uid!,
              sourceType: actualSourceType,
              // mirrorMode is optional - only set if available
            ),
          );

    return SizedBox.expand(
      child: agora_rtc_engine.AgoraVideoView(
        controller: controller,
      ),
    );
  }
}

