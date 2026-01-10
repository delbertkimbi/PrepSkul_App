import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;

/// Agora Video View Widget
///
/// Displays local or remote video from Agora RTC engine.
/// Handles both Flutter Web and Mobile platforms.
class AgoraVideoViewWidget extends StatelessWidget {
  final agora_rtc_engine.RtcEngine engine;
  final int? uid;
  final bool isLocal;
  final agora_rtc_engine.RtcConnection? connection; // Optional connection for remote video

  const AgoraVideoViewWidget({
    Key? key,
    required this.engine,
    required this.uid,
    this.isLocal = false,
    this.connection,
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

    // Create controller based on local/remote
    // Use AgoraVideoView widget (not VideoView) with VideoViewController
    // Note: mirrorMode might not be available in all SDK versions, so we'll make it optional
    final controller = isLocal
        ? agora_rtc_engine.VideoViewController(
            rtcEngine: engine,
            canvas: agora_rtc_engine.VideoCanvas(
              uid: 0,
              // mirrorMode is optional - only set if available
            ),
          )
        : agora_rtc_engine.VideoViewController.remote(
            rtcEngine: engine,
            connection: connection!, // Safe to use ! here because we checked above
            canvas: agora_rtc_engine.VideoCanvas(
              uid: uid!,
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

