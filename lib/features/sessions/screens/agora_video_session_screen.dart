import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart' as agora_widget;
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';
import 'dart:async';

/// Agora Video Session Screen
///
/// Full-screen video session interface with controls for mute, camera, and end call.
class AgoraVideoSessionScreen extends StatefulWidget {
  final String sessionId;
  final String userRole; // 'tutor' or 'learner'

  const AgoraVideoSessionScreen({
    Key? key,
    required this.sessionId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<AgoraVideoSessionScreen> createState() => _AgoraVideoSessionScreenState();
}

class _AgoraVideoSessionScreenState extends State<AgoraVideoSessionScreen> {
  final AgoraService _agoraService = AgoraService();
  final _supabase = SupabaseService.client;

  AgoraSessionState _sessionState = AgoraSessionState.disconnected;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  int? _remoteUID;
  String? _errorMessage;
  StreamSubscription<AgoraSessionState>? _stateSubscription;
  StreamSubscription<int>? _userJoinedSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSession();
    _setupListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _userJoinedSubscription?.cancel();
    _errorSubscription?.cancel();
    // Don't dispose AgoraService here - it's a singleton
    super.dispose();
  }

  /// Initialize Agora session
  Future<void> _initializeSession() async {
    try {
      safeSetState(() {
        _sessionState = AgoraSessionState.joining;
        _errorMessage = null;
      });

      // Get current user ID
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Join channel
      await _agoraService.joinChannel(
        sessionId: widget.sessionId,
        userId: user.id,
        userRole: widget.userRole,
      );

      // If tutor, start the session in the lifecycle service
      if (widget.userRole == 'tutor') {
        try {
          await SessionLifecycleService.startSession(
            widget.sessionId,
            isOnline: true,
          );
        } catch (e) {
          LogService.warning('Failed to start session in lifecycle: $e');
          // Don't fail the video session if lifecycle start fails
        }
      }
    } catch (e) {
      LogService.error('Error initializing Agora session: $e');
      
      // Provide user-friendly error message
      String userMessage = e.toString();
      if (userMessage.contains('createIrisApiEngine') || 
          userMessage.contains('undefined') ||
          userMessage.contains('iris-web-rtc')) {
        userMessage = 'Agora Web SDK not loaded. Please ensure iris-web-rtc.js script is loaded. Refresh the page and try again.';
      } else if (userMessage.contains('Failed to initialize')) {
        userMessage = 'Unable to start video session. Please check your internet connection and try again.';
      } else if (userMessage.contains('permission') || userMessage.contains('Permission')) {
        userMessage = 'Camera or microphone permission denied. Please allow access and try again.';
      }
      
      safeSetState(() {
        _sessionState = AgoraSessionState.error;
        _errorMessage = userMessage;
      });
    }
  }

  /// Setup Agora event listeners
  void _setupListeners() {
    _stateSubscription = _agoraService.stateStream.listen((state) {
      safeSetState(() {
        _sessionState = state;
      });
    });

    _userJoinedSubscription = _agoraService.userJoinedStream.listen((uid) {
      safeSetState(() {
        _remoteUID = uid;
      });
    });

    _errorSubscription = _agoraService.errorStream.listen((error) {
      safeSetState(() {
        _errorMessage = error;
        _sessionState = AgoraSessionState.error;
      });
    });
  }

  /// Toggle video (camera)
  Future<void> _toggleVideo() async {
    try {
      await _agoraService.toggleVideo();
      safeSetState(() {
        _isVideoEnabled = _agoraService.isVideoEnabled();
      });
    } catch (e) {
      LogService.error('Error toggling video: $e');
      _showError('Failed to toggle camera');
    }
  }

  /// Toggle audio (microphone)
  Future<void> _toggleAudio() async {
    try {
      await _agoraService.toggleAudio();
      safeSetState(() {
        _isAudioEnabled = _agoraService.isAudioEnabled();
      });
    } catch (e) {
      LogService.error('Error toggling audio: $e');
      _showError('Failed to toggle microphone');
    }
  }

  /// End call and leave session
  Future<void> _endCall() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Leave Agora channel
      await _agoraService.leaveChannel();

      // If tutor, end the session in lifecycle service
      if (widget.userRole == 'tutor') {
        try {
          await SessionLifecycleService.endSession(widget.sessionId);
        } catch (e) {
          LogService.warning('Failed to end session in lifecycle: $e');
        }
      }

      // Navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      LogService.error('Error ending call: $e');
      _showError('Failed to end session');
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video views
            _buildVideoViews(),

            // Top status bar
            _buildStatusBar(),

            // Bottom controls
            _buildControls(),

            // Error overlay
            if (_errorMessage != null) _buildErrorOverlay(),

            // Loading overlay
            if (_sessionState.isConnecting) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  /// Build video views (local and remote)
  Widget _buildVideoViews() {
    final engine = _agoraService.engine;
    if (engine == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // If remote user joined, show grid layout
    if (_remoteUID != null) {
      return Column(
        children: [
          // Remote video (larger)
          Expanded(
            flex: 2,
            child: agora_widget.AgoraVideoViewWidget(
              engine: engine,
              uid: _remoteUID,
              isLocal: false,
            ),
          ),
          // Local video (smaller, bottom right)
          Expanded(
            flex: 1,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                agora_widget.AgoraVideoViewWidget(
                  engine: engine,
                  uid: _agoraService.currentUID,
                  isLocal: true,
                ),
                // Video disabled indicator
                if (!_isVideoEnabled)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Icon(Icons.videocam_off, color: Colors.white, size: 48),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Only local video (waiting for remote)
    return Stack(
      children: [
        agora_widget.AgoraVideoViewWidget(
          engine: engine,
          uid: _agoraService.currentUID,
          isLocal: true,
        ),
        // Waiting overlay
        Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Waiting for ${widget.userRole == 'tutor' ? 'learner' : 'tutor'}...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Video disabled indicator
        if (!_isVideoEnabled)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Icon(Icons.videocam_off, color: Colors.white, size: 64),
            ),
          ),
      ],
    );
  }

  /// Build status bar (top)
  Widget _buildStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Connection status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _sessionState.isActive
                    ? Colors.green
                    : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sessionState.isActive ? Icons.circle : Icons.sync,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sessionState.displayName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Close button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _endCall,
            ),
          ],
        ),
      ),
    );
  }

  /// Build controls (bottom)
  Widget _buildControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute/Unmute button
            _buildControlButton(
              icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
              label: _isAudioEnabled ? 'Mute' : 'Unmute',
              onPressed: _toggleAudio,
              isActive: _isAudioEnabled,
            ),
            // Camera on/off button
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: _isVideoEnabled ? 'Camera Off' : 'Camera On',
              onPressed: _toggleVideo,
              isActive: _isVideoEnabled,
            ),
            // End call button
            _buildControlButton(
              icon: Icons.call_end,
              label: 'End Call',
              onPressed: _endCall,
              isActive: false,
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Build control button
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    bool isDanger = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isDanger
                ? Colors.red
                : (isActive ? AppTheme.primaryColor : Colors.white.withOpacity(0.3)),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build error overlay
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  safeSetState(() {
                    _errorMessage = null;
                  });
                  _initializeSession();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build loading overlay
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              _sessionState.displayName,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

