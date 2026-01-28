import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'agora_video_view.dart' as agora_widget;
import 'package:prepskul/core/services/log_service.dart';

/// Draggable Picture-in-Picture local video widget
/// Shows local video in a small draggable window
class LocalVideoPIP extends StatefulWidget {
  final agora_rtc_engine.RtcEngine engine;
  final int? localUid;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final VoidCallback? onTap;

  const LocalVideoPIP({
    Key? key,
    required this.engine,
    required this.localUid,
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    this.onTap,
  }) : super(key: key);

  @override
  State<LocalVideoPIP> createState() => _LocalVideoPIPState();
}

class _LocalVideoPIPState extends State<LocalVideoPIP>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    
    // CRITICAL: On web, ensure local video is set up with camera source before widget builds
    if (kIsWeb && widget.localUid != null && widget.isVideoEnabled) {
      _setupWebLocalVideo();
    }
  }
  
  /// Set up local video for web platform
  /// This ensures the camera feed is properly captured and displayed in the PIP
  Future<void> _setupWebLocalVideo() async {
    try {
      // Explicitly set up local video with camera source type for web
      await widget.engine.setupLocalVideo(
        const agora_rtc_engine.VideoCanvas(
          uid: 0,
          sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera,
        ),
      );
      LogService.info('✅ Local video PIP set up for web (camera source)');
      
      // Small delay to allow camera to initialize
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Ensure video stream is unmuted
      await widget.engine.muteLocalVideoStream(false);
      LogService.info('✅ Local video PIP stream unmuted for web');
    } catch (e) {
      LogService.warning('Could not set up local video PIP for web: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePosition(Offset newPosition) {
    setState(() {
      _position = newPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final pipSize = Size(160, 120); // Small PIP size
    
    // Default position: bottom-right with padding
    final defaultPosition = Offset(
      screenSize.width - pipSize.width - 16,
      screenSize.height - pipSize.height - 100, // Above control bar
    );

    final currentPosition = _position.dx == 0 && _position.dy == 0
        ? defaultPosition
        : _position;

    // Constrain position to screen bounds
    final constrainedX = currentPosition.dx.clamp(
      0.0,
      screenSize.width - pipSize.width,
    );
    final constrainedY = currentPosition.dy.clamp(
      0.0,
      screenSize.height - pipSize.height - 80, // Leave space for controls
    );

    return Positioned(
      left: constrainedX,
      top: constrainedY,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          _updatePosition(
            Offset(
              constrainedX + details.delta.dx,
              constrainedY + details.delta.dy,
            ),
          );
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: pipSize.width,
            height: pipSize.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDragging ? Colors.blue : Colors.white.withOpacity(0.3),
                width: _isDragging ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Video view
                widget.localUid != null && widget.isVideoEnabled
                    ? Builder(
                        builder: (context) {
                          // CRITICAL: On web, ensure setupLocalVideo is called with explicit source type
                          // This is done in initState, but we also ensure it here for reliability
                          if (kIsWeb) {
                            // Use a post-frame callback to ensure setup happens after widget build
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.engine.setupLocalVideo(
                                const agora_rtc_engine.VideoCanvas(
                                  uid: 0,
                                  sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera,
                                ),
                              ).catchError((e) {
                                LogService.warning('Post-frame local video setup failed: $e');
                              });
                            });
                          }
                          
                          return agora_widget.AgoraVideoViewWidget(
                            engine: widget.engine,
                            uid: widget.localUid,
                            isLocal: true,
                            sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera, // Explicitly use camera source for preview
                          );
                        },
                      )
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: widget.isVideoEnabled
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Icon(
                                  Icons.videocam_off,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 32,
                                ),
                        ),
                      ),
                // Overlay with status indicators
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mic status
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isAudioEnabled ? Icons.mic : Icons.mic_off,
                          size: 12,
                          color: widget.isAudioEnabled
                              ? Colors.white
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Camera status
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isVideoEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
                          size: 12,
                          color: widget.isVideoEnabled
                              ? Colors.white
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                // "You" label
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'You',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

