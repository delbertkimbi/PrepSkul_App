import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';

/// Agora Video View Widget
///
/// Displays local or remote video from Agora RTC engine.
/// Handles both Flutter Web and Mobile platforms.
/// 
/// STABILITY: Uses stable keys internally to prevent unnecessary widget recreation
/// which can cause video blackouts during network fluctuations.
class AgoraVideoViewWidget extends StatefulWidget {
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

  // Prevent repeated local web setup calls on every rebuild.
  static final Map<String, String> _lastLocalSetupSignatureByUid = <String, String>{};
  static final Map<String, DateTime> _lastLocalSetupAtByUid = <String, DateTime>{};
  static final Map<String, String> _lastRemoteRenderSignatureByUid = <String, String>{};
  static final Map<String, DateTime> _lastRemoteRenderLogAtByUid = <String, DateTime>{};

  @override
  State<AgoraVideoViewWidget> createState() => _AgoraVideoViewWidgetState();
}

class _AgoraVideoViewWidgetState extends State<AgoraVideoViewWidget> {
  agora_rtc_engine.VideoViewControllerBase? _controller;
  String? _controllerSignature;

  String _buildSignature({
    required bool isLocal,
    required int uid,
    required agora_rtc_engine.VideoSourceType sourceType,
    required String? channelId,
  }) {
    final source = sourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen
        ? 'screen'
        : 'camera';
    final role = isLocal ? 'local' : 'remote';
    return '$role-$uid-$source-${channelId ?? "none"}';
  }

  String _stableKey({
    required bool isLocal,
    required int uid,
    required agora_rtc_engine.VideoSourceType sourceType,
  }) {
    final source = sourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen
        ? 'screen'
        : 'camera';
    return 'agora_video_${isLocal ? "local" : "remote"}_${uid}_$source';
  }

  void _ensureController({
    required agora_rtc_engine.RtcEngine engine,
    required bool isLocal,
    required int uid,
    required agora_rtc_engine.VideoSourceType sourceType,
    required agora_rtc_engine.RenderModeType renderMode,
    required agora_rtc_engine.RtcConnection? connection,
  }) {
    final signature = _buildSignature(
      isLocal: isLocal,
      uid: uid,
      sourceType: sourceType,
      channelId: connection?.channelId,
    );
    if (_controller != null && _controllerSignature == signature) return;

    _controllerSignature = signature;
    _controller = isLocal
        ? agora_rtc_engine.VideoViewController(
            rtcEngine: engine,
            canvas: agora_rtc_engine.VideoCanvas(
              uid: 0,
              sourceType: sourceType,
              renderMode: renderMode,
            ),
          )
        : agora_rtc_engine.VideoViewController.remote(
            rtcEngine: engine,
            connection: connection!,
            canvas: agora_rtc_engine.VideoCanvas(
              uid: uid,
              sourceType: sourceType,
              renderMode: renderMode,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // For remote video, we need a connection with channelId
    // If connection is not provided or doesn't have channelId, show loading
    if (!widget.isLocal &&
        (widget.connection == null || widget.connection!.channelId == null)) {
      // Debug: Log why we're showing loading
      if (widget.connection == null) {
        debugPrint(
          '⚠️ [AgoraVideoView] Remote video: connection is null for UID=${widget.uid}',
        );
      } else if (widget.connection!.channelId == null) {
        debugPrint(
          '⚠️ [AgoraVideoView] Remote video: connection.channelId is null for UID=${widget.uid}',
        );
      }
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Determine the actual source type to use
    final actualSourceType =
        widget.sourceType ??
        agora_rtc_engine.VideoSourceType.videoSourceCamera;
    
    // Choose render mode:
    // - Camera: use HIDDEN (crop to fill, typical for faces)
    // - Screen share: use FIT (show whole shared screen without zooming/cropping)
    final renderMode = actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen
        ? agora_rtc_engine.RenderModeType.renderModeFit
        : agora_rtc_engine.RenderModeType.renderModeHidden;
    
    // CRITICAL: For screen sharing, we need to explicitly set up the video source
    // before creating the view controller
    final canvas = agora_rtc_engine.VideoCanvas(
      uid: widget.isLocal ? 0 : widget.uid!,
      sourceType: actualSourceType,
      renderMode: renderMode,
      // mirrorMode is optional - only set if available
    );

    // CRITICAL: Set up video source with correct sourceType
    // For local video: on web we call setupLocalVideo so the SDK binds to the plugin's element.
    // On Android/iOS we must NOT call setupLocalVideo here — the plugin's AgoraVideoView
    // creates the native view and binds it; our calling setupLocalVideo(canvas without view)
    // would clear that binding and cause a black preview.
    if (widget.isLocal) {
      if (kIsWeb) {
        final skipCameraSetupWhileSharing =
            actualSourceType ==
                agora_rtc_engine.VideoSourceType.videoSourceCamera &&
            AgoraService().isPublishingScreen;
        if (!skipCameraSetupWhileSharing) {
          try {
            final sourceSig = actualSourceType.name;
            final uidKey = 'local_${widget.uid ?? 0}';
            final now = DateTime.now();
            final previousSig =
                AgoraVideoViewWidget._lastLocalSetupSignatureByUid[uidKey];
            final previousAt =
                AgoraVideoViewWidget._lastLocalSetupAtByUid[uidKey];
            final shouldSetup = previousSig != sourceSig ||
                previousAt == null ||
                now.difference(previousAt) > const Duration(seconds: 10);

            if (shouldSetup) {
              AgoraVideoViewWidget._lastLocalSetupSignatureByUid[uidKey] =
                  sourceSig;
              AgoraVideoViewWidget._lastLocalSetupAtByUid[uidKey] = now;
              widget.engine.setupLocalVideo(canvas);
              if (actualSourceType ==
                  agora_rtc_engine.VideoSourceType.videoSourceScreen) {
                LogService.info(
                  '✅ [AgoraVideoView] Set up LOCAL video with SCREEN source (web)',
                );
              } else {
                LogService.info(
                  '✅ [AgoraVideoView] Set up LOCAL video with CAMERA source (web)',
                );
              }
              // Do not force-unmute from widget layer. AgoraService owns publish/mute policy.
            }
          } catch (e) {
            LogService.warning(
              '⚠️ [AgoraVideoView] Failed to set up local video on web: $e',
            );
          }
        }
      }
      // On mobile, do not call setupLocalVideo — AgoraVideoView binds the view internally.
    } else {
      // For remote video, the VideoViewController.remote will handle setup
      // The canvas with sourceType is passed to the controller
      final remoteKey = 'remote_${widget.uid ?? 0}';
      final sourceSig = actualSourceType.name;
      final now = DateTime.now();
      final previousSig =
          AgoraVideoViewWidget._lastRemoteRenderSignatureByUid[remoteKey];
      final previousAt =
          AgoraVideoViewWidget._lastRemoteRenderLogAtByUid[remoteKey];
      final shouldLog = previousSig != sourceSig ||
          previousAt == null ||
          now.difference(previousAt) > const Duration(seconds: 10);
      if (shouldLog) {
        AgoraVideoViewWidget._lastRemoteRenderSignatureByUid[remoteKey] =
            sourceSig;
        AgoraVideoViewWidget._lastRemoteRenderLogAtByUid[remoteKey] = now;
        if (actualSourceType == agora_rtc_engine.VideoSourceType.videoSourceScreen) {
          debugPrint(
            '✅ [AgoraVideoView] Setting up REMOTE video with SCREEN source for UID=${widget.uid}',
          );
        } else {
          debugPrint(
            '✅ [AgoraVideoView] Setting up REMOTE video with CAMERA source for UID=${widget.uid}',
          );
        }
      }
    }

    _ensureController(
      engine: widget.engine,
      isLocal: widget.isLocal,
      uid: widget.uid!,
      sourceType: actualSourceType,
      renderMode: renderMode,
      connection: widget.connection,
    );

    // Use stable key to prevent unnecessary widget recreation during network fluctuations
    return SizedBox.expand(
      key: ValueKey(
        _stableKey(
          isLocal: widget.isLocal,
          uid: widget.uid!,
          sourceType: actualSourceType,
        ),
      ),
      child: agora_rtc_engine.AgoraVideoView(
        controller: _controller!,
      ),
    );
  }
}

