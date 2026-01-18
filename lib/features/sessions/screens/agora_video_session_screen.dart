import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart' as agora_widget;
import 'package:prepskul/features/sessions/widgets/profile_card_overlay.dart';
import 'package:prepskul/features/sessions/widgets/session_state_message.dart';
import 'package:prepskul/features/sessions/widgets/local_video_pip.dart';
import 'package:prepskul/features/sessions/widgets/reactions_panel.dart';
import 'package:prepskul/features/sessions/widgets/reaction_animation.dart';
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';
import 'dart:async';

/// Agora Video Session Screen
///
/// Full-screen video session interface with controls for mute, camera, and end call.
class AgoraVideoSessionScreen extends StatefulWidget {
  final String sessionId;
  final String userRole; // 'tutor' or 'learner'
  final bool initialCameraEnabled; // Initial camera state from pre-join
  final bool initialMicEnabled; // Initial mic state from pre-join

  const AgoraVideoSessionScreen({
    Key? key,
    required this.sessionId,
    required this.userRole,
    this.initialCameraEnabled = false, // Default to OFF
    this.initialMicEnabled = false, // Default to OFF
  }) : super(key: key);

  @override
  State<AgoraVideoSessionScreen> createState() => _AgoraVideoSessionScreenState();
}

class _AgoraVideoSessionScreenState extends State<AgoraVideoSessionScreen> {
  final AgoraService _agoraService = AgoraService();
  final _supabase = SupabaseService.client;
  final SessionProfileService _profileService = SessionProfileService();

  AgoraSessionState _sessionState = AgoraSessionState.disconnected;
  bool _isVideoEnabled = false; // Will be set from initial state
  bool _isAudioEnabled = false; // Will be set from initial state
  int? _remoteUID;
  String? _errorMessage;
  
  // Remote state tracking
  bool _remoteVideoMuted = false;
  bool _remoteAudioMuted = false;
  bool _isScreenSharing = false;
  bool _remoteIsScreenSharing = false;
  bool _remoteUserLeft = false;
  
  // Profile data
  Map<String, dynamic>? _localProfile;
  Map<String, dynamic>? _remoteProfile;
  
  // Reactions
  bool _showReactionsPanel = false;
  final List<Widget> _reactionAnimations = [];
  
  // Stream subscriptions
  StreamSubscription<AgoraSessionState>? _stateSubscription;
  StreamSubscription<int>? _userJoinedSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteVideoMutedSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteAudioMutedSubscription;
  StreamSubscription<Map<String, dynamic>>? _screenSharingSubscription;
  StreamSubscription<int>? _userLeftSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteNetworkQualitySubscription;
  StreamSubscription<Map<String, dynamic>>? _reactionSubscription;
  
  // Network instability tracking
  bool _remoteConnectionUnstable = false;

  @override
  void initState() {
    super.initState();
    _initializeSession();
    _setupListeners();
  }

  @override
  void dispose() {
    // CRITICAL: Ensure mic and camera are turned off when screen is disposed
    // This is especially important on mobile devices where tracks might persist
    // Call leaveChannel to ensure proper cleanup of all media tracks
    _agoraService.leaveChannel().catchError((e) {
      // Log error but don't block disposal - user is leaving anyway
      LogService.warning('Error leaving channel during dispose: $e');
    });
    
    _stateSubscription?.cancel();
    _userJoinedSubscription?.cancel();
    _errorSubscription?.cancel();
    _remoteVideoMutedSubscription?.cancel();
    _remoteAudioMutedSubscription?.cancel();
    _screenSharingSubscription?.cancel();
    _userLeftSubscription?.cancel();
    _remoteNetworkQualitySubscription?.cancel();
    _reactionSubscription?.cancel();
    // Don't dispose AgoraService here - it's a singleton
    super.dispose();
  }

  /// Initialize Agora session
  Future<void> _initializeSession() async {
    try {
      LogService.info('🎥 Initializing Agora session - Session ID: ${widget.sessionId}, User Role: ${widget.userRole}');
      
      safeSetState(() {
        _sessionState = AgoraSessionState.joining;
        _errorMessage = null;
      });

      // Get current user ID
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load profile data
      _loadProfileData(user.id);

      // Set initial camera/mic state from pre-join screen
      _isVideoEnabled = widget.initialCameraEnabled;
      _isAudioEnabled = widget.initialMicEnabled;

      // Join channel with initial camera/mic state
      await _agoraService.joinChannel(
        sessionId: widget.sessionId,
        userId: user.id,
        userRole: widget.userRole,
        initialCameraEnabled: widget.initialCameraEnabled,
        initialMicEnabled: widget.initialMicEnabled,
      );

      // Update state to reflect actual camera/mic state
      safeSetState(() {
        _isVideoEnabled = _agoraService.isVideoEnabled();
        _isAudioEnabled = _agoraService.isAudioEnabled();
      });

      // If tutor, start the session in the lifecycle service
      if (widget.userRole == 'tutor') {
        try {
          await SessionLifecycleService.startSession(
            widget.sessionId,
            isOnline: true,
          );
        } catch (e) {
          LogService.warning('Failed to start session in lifecycle: $e');
        }
      }
    } catch (e) {
      LogService.error('Error initializing Agora session: $e');
      
      // Format error message for user
      String userMessage = e.toString();
      
      // Remove "Exception: " prefix if present
      if (userMessage.startsWith('Exception: ')) {
        userMessage = userMessage.substring(11);
      }
      
      // Provide user-friendly error messages
      if (userMessage.contains('timeout') || userMessage.contains('unreachable') || userMessage.contains('slow to respond')) {
        userMessage = 'Connection timeout. The video service is taking too long to respond.\n\n'
            'Please check:\n'
            '• Your internet connection\n'
            '• The API server is running\n'
            '• Try again in a moment\n\n'
            'If the problem persists, please contact support.';
      } else if (userMessage.contains('CORS') || userMessage.contains('cors') || userMessage.contains('Cross-Origin')) {
        userMessage = 'Connection blocked. This may be a browser security issue.\n\n'
            'Please try:\n'
            '• Refreshing the page\n'
            '• Using a different browser\n'
            '• Contacting support if the issue persists';
      } else if (userMessage.contains('Unauthorized') || userMessage.contains('401')) {
        userMessage = 'Session expired. Please log in again.';
      } else if (userMessage.contains('Access denied') || userMessage.contains('403')) {
        userMessage = 'You do not have access to this session.';
      } else if (userMessage.contains('createIrisApiEngine') || 
          userMessage.contains('undefined') ||
          userMessage.contains('iris-web-rtc')) {
        userMessage = 'Unable to start video session. Please refresh the page and try again.';
      } else if (userMessage.contains('Failed to initialize')) {
        userMessage = 'Unable to start video session. Please check your internet connection and try again.';
      } else if (userMessage.contains('permission') || 
                 userMessage.contains('Permission') ||
                 userMessage.contains('NotAllowedError') ||
                 userMessage.contains('NotAllowed') ||
                 userMessage.contains('Permission denied')) {
        userMessage = 'Camera and Microphone Permission Required\n\n'
            'Your browser is blocking camera and microphone access.\n\n'
            'To fix this:\n'
            '1. Look at the address bar (top-left of your browser)\n'
            '2. Click the camera/microphone icon (🔒 or 🎥 or 🎤)\n'
            '3. Set both "Camera" and "Microphone" to "Allow"\n'
            '4. Refresh this page (press F5 or click refresh)\n'
            '5. Try joining the session again\n\n'
            'If you don\'t see the icon:\n'
            '• Chrome/Edge: Click the padlock icon → Site settings → Allow camera and microphone\n'
            '• Firefox: Click the padlock icon → More Information → Permissions → Allow\n\n'
            'After allowing permissions, refresh the page and try again.';
      } else if (userMessage.contains('localhost:3000')) {
        // If error mentions localhost, suggest checking if server is running
        userMessage = 'Unable to connect to video service.\n\n'
            'The API server may not be running.\n'
            'Please ensure the Next.js server is started and try again.';
      }
      
      safeSetState(() {
        _sessionState = AgoraSessionState.error;
        _errorMessage = userMessage;
      });
    }
  }

  /// Load profile data for local and remote users
  Future<void> _loadProfileData(String localUserId) async {
    try {
      // Load local profile
      _localProfile = await _profileService.getUserProfile(localUserId);
      
      // Load session participants
      final participants = await _profileService.getSessionParticipants(widget.sessionId);
      if (widget.userRole == 'tutor') {
        _remoteProfile = participants['learner'];
      } else {
        _remoteProfile = participants['tutor'];
      }
      
      safeSetState(() {});
    } catch (e) {
      LogService.warning('Error loading profile data: $e');
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
        _remoteUserLeft = false; // User joined, reset left state
      });
    });

    _errorSubscription = _agoraService.errorStream.listen((error) {
      safeSetState(() {
        _errorMessage = error;
        _sessionState = AgoraSessionState.error;
      });
    });

    // Remote video muted state
    _remoteVideoMutedSubscription = _agoraService.remoteVideoMutedStream.listen((data) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        safeSetState(() {
          _remoteVideoMuted = muted;
        });
      }
    });

    // Remote audio muted state
    _remoteAudioMutedSubscription = _agoraService.remoteAudioMutedStream.listen((data) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        safeSetState(() {
          _remoteAudioMuted = muted;
        });
      }
    });

    // Screen sharing state
    _screenSharingSubscription = _agoraService.screenSharingStream.listen((data) {
      final uid = data['uid'] as int;
      final sharing = data['sharing'] as bool;
      if (uid == _remoteUID) {
        safeSetState(() {
          _remoteIsScreenSharing = sharing;
        });
      } else if (uid == _agoraService.currentUID) {
        safeSetState(() {
          _isScreenSharing = sharing;
        });
      }
    });

    // User left
    _userLeftSubscription = _agoraService.userLeftStream.listen((uid) {
      if (uid == _remoteUID) {
        safeSetState(() {
          _remoteUserLeft = true;
          _remoteUID = null; // Clear remote UID so profile card shows
          _remoteConnectionUnstable = false; // Reset instability flag when user leaves
        });
        LogService.info('📤 Remote user left - showing profile card');
      }
    });
    
    // Remote network quality (for instability detection)
    _remoteNetworkQualitySubscription = _agoraService.remoteNetworkQualityStream.listen((data) {
      final uid = data['uid'] as int;
      final isUnstable = data['isUnstable'] as bool? ?? false;
      
      if (uid == _remoteUID) {
        safeSetState(() {
          _remoteConnectionUnstable = isUnstable;
        });
        
        if (isUnstable) {
          LogService.warning('⚠️ Remote user connection is unstable');
        } else {
          LogService.info('✅ Remote user connection is stable');
        }
      }
    });
    
    // Remote reactions
    _reactionSubscription = _agoraService.reactionStream.listen((data) {
      final uid = data['uid'] as int;
      final emoji = data['emoji'] as String;
      
      // Only show reactions from the remote user we're connected to
      if (uid == _remoteUID) {
        LogService.info('🎉 Displaying remote reaction: $emoji from UID=$uid');
        // Add reaction animation on screen
        _addReactionAnimation(emoji);
      }
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

  /// Toggle screen sharing
  Future<void> _toggleScreenSharing() async {
    try {
      if (_isScreenSharing) {
        await _agoraService.stopScreenSharing();
        // State will be updated via stream subscription in _setupListeners
        // No need to manually update _isScreenSharing here
      } else {
        await _agoraService.startScreenSharing();
        // State will be updated via stream subscription in _setupListeners
        // The service emits via _screenSharingController, which triggers UI update
        // No need to manually update _isScreenSharing here - rely on stream events
      }
    } catch (e) {
      // Check if user cancelled
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('notallowed') || 
          errorStr.contains('not allowed') ||
          errorStr.contains('permission') ||
          errorStr.contains('denied') ||
          errorStr.contains('user') && errorStr.contains('cancel')) {
        // User cancelled - don't show error
        LogService.info('Screen sharing cancelled by user');
        return;
      }
      
      // For other errors, log but don't show to user
      LogService.warning('Screen sharing error (not showing to user): $e');
      // Don't call _showError - avoid showing technical errors
    }
  }

  /// Handle reaction emoji selection
  void _handleReaction(String emoji) {
    // Add local reaction animation
    _addReactionAnimation(emoji);
    
    // Send reaction to remote users via Agora data stream
    try {
      _agoraService.sendReaction(emoji);
    } catch (e) {
      LogService.warning('Failed to send reaction: $e');
    }
  }

  /// Helper method to add reaction animation (can be reused for local and remote)
  void _addReactionAnimation(String emoji) {
    final screenSize = MediaQuery.of(context).size;
    final reactionKey = UniqueKey();
    
    final reactionWidget = ReactionAnimation(
      key: reactionKey,
      emoji: emoji,
      startPosition: Offset(screenSize.width / 2, screenSize.height / 2),
      onComplete: () {
        safeSetState(() {
          _reactionAnimations.removeWhere((w) {
            if (w is ReactionAnimation) {
              return w.key == reactionKey;
            }
            return false;
          });
        });
      },
    );
    
    safeSetState(() {
      _reactionAnimations.add(reactionWidget);
    });
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
      // Try to leave channel - handle errors gracefully
      try {
        await _agoraService.leaveChannel();
      } catch (e) {
        // Handle mutex and other leave errors gracefully
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('mutex') || 
            errorStr.contains('already') || 
            errorStr.contains('not in channel')) {
          LogService.info('Channel already left (this is okay)');
        } else {
          LogService.warning('Error leaving channel (continuing anyway): $e');
        }
        // Continue with cleanup even if leaveChannel fails
      }

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
      // Even if there's an error, try to navigate back
      if (mounted) {
        Navigator.pop(context);
      }
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
            // Main video area - covers almost entire screen
            _buildMainVideoArea(),

            // Picture-in-picture local video (when camera is on and call is active)
            if (_isVideoEnabled && _sessionState == AgoraSessionState.connected && _remoteUID != null && !_remoteUserLeft)
              _buildLocalVideoPIP(),

            // Profile cards - ONLY show when:
            // 1. Remote user left (show local profile)
            // 2. No remote user joined yet (show local profile if camera off)
            // 3. Remote user camera is off AND no remote video is available (show remote profile)
            // DO NOT show local profile during active call with remote user
            if (_sessionState == AgoraSessionState.connected) ...[
              // Show local profile only if: remote left OR (no remote user AND camera off)
              if (_remoteUserLeft || (_remoteUID == null && !_isVideoEnabled))
                _buildLocalProfileCard(),
              // Show remote profile if: remote user left (abnormal disconnect) OR (remote exists, camera off, and they haven't left)
              if (_remoteUserLeft)
                _buildRemoteProfileCard(), // Show remote profile when they left
              if (_remoteUID != null && !_remoteUserLeft && _remoteVideoMuted)
                _buildRemoteProfileCard(), // Show remote profile when camera is off
            ],

            // State messages (non-intrusive, top-center)
            _buildStateMessages(),

            // Reactions animations
            ..._reactionAnimations,

            // Top status bar (minimal)
            _buildStatusBar(),

            // Bottom control bar
            _buildControlBar(),

            // Reactions panel (overlay)
            if (_showReactionsPanel) _buildReactionsPanel(),

            // Error overlay
            if (_errorMessage != null) _buildErrorOverlay(),

            // Loading overlay (only during initial connection)
            if (_sessionState == AgoraSessionState.joining) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  /// Build main video area - covers almost entire screen
  Widget _buildMainVideoArea() {
    final engine = _agoraService.engine;
    if (engine == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // CRITICAL: Check if remote user left FIRST before showing screen sharing
    // This ensures we show profile card instead of blank screen after user leaves during screen share
    if (_remoteUserLeft && (_isScreenSharing || _remoteIsScreenSharing)) {
      // User left during screen sharing - show profile card instead of blank screen
      return Container(
        color: Colors.black,
        child: const SizedBox.shrink(), // Profile card overlay will show
      );
    }

    // If screen sharing is active, show screen share (not camera video)
    if (_isScreenSharing || _remoteIsScreenSharing) {
      final sharingUid = _remoteIsScreenSharing ? _remoteUID : _agoraService.currentUID;
      if (sharingUid != null && !(_remoteIsScreenSharing && _remoteUserLeft)) {
        return SizedBox.expand(
          child: agora_widget.AgoraVideoViewWidget(
            engine: engine,
            uid: sharingUid,
            isLocal: sharingUid == _agoraService.currentUID,
            connection: _agoraService.currentConnection,
          ),
        );
      } else if (_remoteUID != null && !_remoteUserLeft) {
        // Fallback: If screen share UID is invalid but remote user exists, show camera instead
        LogService.warning('⚠️ Screen sharing UID is null, falling back to camera view');
        final connection = _agoraService.currentConnection;
        return SizedBox.expand(
          key: ValueKey('remote_camera_fallback_$_videoRebuildKey'),
          child: agora_widget.AgoraVideoViewWidget(
            engine: engine,
            uid: _remoteUID,
            isLocal: false,
            connection: connection,
            sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera, // Fallback to camera
          ),
        );
      }
    }

    // If remote user joined and video is available
    if (_remoteUID != null && !_remoteUserLeft) {
      final connection = _agoraService.currentConnection;
      return SizedBox.expand(
        child: agora_widget.AgoraVideoViewWidget(
          engine: engine,
          uid: _remoteUID,
          isLocal: false,
          connection: connection,
        ),
      );
    }

    // If remote user left - show black screen with profile card
    if (_remoteUserLeft) {
      return Container(
        color: Colors.black,
        child: const SizedBox.shrink(), // Profile card overlay will show
      );
    }
    
    // If remote UID is null but we were connected, user might have left abnormally
    // This handles browser tab close scenarios
    if (_sessionState == AgoraSessionState.connected && _remoteUID == null && !_remoteUserLeft) {
      // Show black screen - profile card will show if camera is off
      return Container(
        color: Colors.black,
        child: const SizedBox.shrink(),
      );
    }

    // Waiting state - show loading or black screen
    return Container(
      color: Colors.black,
      child: _sessionState == AgoraSessionState.joining
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : const SizedBox.shrink(), // Profile card will be shown separately if camera off
    );
  }

  /// Build local video PIP
  Widget _buildLocalVideoPIP() {
    final engine = _agoraService.engine;
    if (engine == null || _agoraService.currentUID == null) {
      return const SizedBox.shrink();
    }

    return LocalVideoPIP(
      engine: engine,
      localUid: _agoraService.currentUID,
      isVideoEnabled: _isVideoEnabled,
      isAudioEnabled: _isAudioEnabled,
    );
  }

  /// Build local profile card (when camera is off)
  Widget _buildLocalProfileCard() {
    String name = widget.userRole == 'tutor' ? 'Tutor' : 'Learner';
    if (_localProfile != null) {
      final profileName = _localProfile!['full_name'] as String?;
      if (profileName != null && profileName.isNotEmpty && profileName != 'User') {
        name = profileName;
      }
    }
    final avatarUrl = _localProfile?['avatar_url'] as String?;

    return ProfileCardOverlay(
      avatarUrl: avatarUrl,
      name: name,
      role: widget.userRole,
      isLocal: true,
    );
  }

  /// Build remote profile card (when remote camera is off or user left)
  Widget _buildRemoteProfileCard() {
    // Show if remote user left OR remote video is muted (camera off)
    // Always show when user left (abnormal disconnect)
    if (!_remoteUserLeft && !_remoteVideoMuted) {
      return const SizedBox.shrink();
    }

    String name = widget.userRole == 'tutor' ? 'Learner' : 'Tutor';
    if (_remoteProfile != null) {
      final profileName = _remoteProfile!['full_name'] as String?;
      if (profileName != null && profileName.isNotEmpty && profileName != 'User') {
        name = profileName;
      }
    }
    final avatarUrl = _remoteProfile?['avatar_url'] as String?;
    final role = widget.userRole == 'tutor' ? 'learner' : 'tutor';

    return ProfileCardOverlay(
      avatarUrl: avatarUrl,
      name: name,
      role: role,
      isLocal: false,
    );
  }

  /// Build state messages (non-intrusive)
  Widget _buildStateMessages() {
    if (_sessionState != AgoraSessionState.connected) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Remote video muted
          if (_remoteVideoMuted && _remoteUID != null)
            widget.userRole == 'tutor'
                ? SessionStateMessages.learnerCameraOff()
                : SessionStateMessages.tutorCameraOff(),
          // Remote audio muted
          if (_remoteAudioMuted && _remoteUID != null)
            widget.userRole == 'tutor'
                ? SessionStateMessages.learnerMicMuted()
                : SessionStateMessages.tutorMicMuted(),
          // Remote user left
          if (_remoteUserLeft)
            widget.userRole == 'tutor' 
                ? SessionStateMessages.learnerLeft()
                : SessionStateMessages.tutorLeft(),
          // Remote connection unstable
          if (_remoteConnectionUnstable && _remoteUID != null && !_remoteUserLeft)
            widget.userRole == 'tutor'
                ? SessionStateMessages.learnerConnectionUnstable()
                : SessionStateMessages.tutorConnectionUnstable(),
        ],
      ),
    );
  }

  /// Build status bar (minimal, top)
  Widget _buildStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.5),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Connection status (minimal)
            if (_sessionState.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            // Close button (minimal)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: _endCall,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build control bar (bottom, Google Meet style)
  Widget _buildControlBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mic toggle
              _buildControlButton(
                icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                label: _isAudioEnabled ? 'Mute' : 'Unmute',
                onPressed: _toggleAudio,
                isActive: _isAudioEnabled,
                showMutedIndicator: !_isAudioEnabled,
              ),
              const SizedBox(width: 12),
              // Camera toggle
              _buildControlButton(
                icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                label: _isVideoEnabled ? 'Camera Off' : 'Camera On',
                onPressed: _toggleVideo,
                isActive: _isVideoEnabled,
                showMutedIndicator: !_isVideoEnabled,
              ),
              const SizedBox(width: 12),
              // Reactions button
              _buildControlButton(
                icon: Icons.emoji_emotions,
                label: 'Reactions',
                onPressed: () {
                  safeSetState(() {
                    _showReactionsPanel = !_showReactionsPanel;
                  });
                },
                isActive: _showReactionsPanel,
              ),
              const SizedBox(width: 12),
              // Screen share button
              _buildControlButton(
                icon: Icons.screen_share,
                label: _isScreenSharing ? 'Stop Sharing' : 'Share Screen',
                onPressed: _toggleScreenSharing,
                isActive: _isScreenSharing,
              ),
              const SizedBox(width: 12),
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
      ),
    );
  }

  /// Build reactions panel
  Widget _buildReactionsPanel() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: ReactionsPanel(
          onEmojiSelected: _handleReaction,
          onClose: () {
            safeSetState(() {
              _showReactionsPanel = false;
            });
          },
        ),
      ),
    );
  }

  /// Build control button (Google Meet style)
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    bool isDanger = false,
    bool showMutedIndicator = false,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDanger
                  ? Colors.red
                  : (isActive 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.15)),
              shape: BoxShape.circle,
              border: showMutedIndicator
                  ? Border.all(color: Colors.red, width: 2)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: showMutedIndicator ? Colors.red : Colors.white,
                  size: 24,
                ),
                // Muted indicator (red slash)
                if (showMutedIndicator)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 12,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(1),
                      ),
                      transform: Matrix4.rotationZ(-0.785398), // 45 degrees
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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

  /// Build loading overlay (minimal, professional)
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              'Connecting to session...',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

