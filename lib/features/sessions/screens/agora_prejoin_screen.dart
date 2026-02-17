import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/camera_mic_permission_service.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/services/connection_quality_service.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/screens/agora_video_session_screen.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart' as agora_widget;
import 'package:cached_network_image/cached_network_image.dart';

/// Pre-join screen for Agora video sessions
/// Allows users to grant permissions and choose initial camera/mic state
class AgoraPreJoinScreen extends StatefulWidget {
  final String sessionId;
  final String userRole; // 'tutor' or 'learner'

  const AgoraPreJoinScreen({
    Key? key,
    required this.sessionId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<AgoraPreJoinScreen> createState() => _AgoraPreJoinScreenState();
}

class _AgoraPreJoinScreenState extends State<AgoraPreJoinScreen>
    with WidgetsBindingObserver {
  final SessionProfileService _profileService = SessionProfileService();
  final _supabase = SupabaseService.client;
  final CameraMicPermissionService _cameraMicPermissionService =
      CameraMicPermissionService();

  bool _cameraEnabled = true;
  bool _micEnabled = true;
  bool _permissionsGranted = false;
  bool _isLoading = false;
  bool _showPermissionDialog = false;
  String? _errorMessage;
  bool _permissionDeniedPermanently = false;
  
  Map<String, dynamic>? _userProfile;
  
  // Permission states
  bool _cameraPermissionRequested = false;
  bool _micPermissionRequested = false;
  bool _notificationPermissionRequested = false;

  // Pre-lesson connection test (optional)
  String? _connectionQuality; // 'good', 'fair', 'poor'
  bool _connectionTested = false;
  bool _isTestingConnection = false;

  // Live camera preview (pre-join)
  final AgoraService _agoraService = AgoraService();
  bool _previewStarted = false;
  bool _previewStartScheduled = false; // Prevent multiple concurrent starts
  String? _previewError; // e.g. CORS or token failure on web

  /// Talking indicator: true when local volume is above threshold (pre-join).
  bool _localSpeaking = false;
  StreamSubscription<Set<int>>? _speakingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _checkPermissionStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runConnectionTestIfReady());
    _speakingSubscription = _agoraService.speakingStream.listen((uids) {
      if (mounted) setState(() => _localSpeaking = uids.contains(0));
    });
  }

  @override
  void dispose() {
    _speakingSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _agoraService.releasePreviewIfNotInChannel();
    super.dispose();
  }

  /// Start Agora local preview when permissions granted and camera on (so user sees themselves).
  Future<void> _startPreviewIfNeeded() async {
    if (!_permissionsGranted || !_cameraEnabled || _previewStarted) return;
    if (mounted) setState(() => _previewError = null);
    try {
      await _agoraService.startLocalPreviewForPreJoin(widget.sessionId);
      if (mounted) setState(() {
        _previewStarted = true;
        _previewStartScheduled = false;
        _previewError = null;
      });
    } catch (e) {
      LogService.warning('[PREVIEW] Pre-join preview failed: $e');
      final msg = e.toString().contains('CORS') || e.toString().contains('origin')
          ? 'Could not connect to the server. If you\'re on localhost, the API may need to allow your origin (CORS). Try again or use the app from the same domain as the API.'
          : 'Camera could not start. Check your connection and try again.';
      if (mounted) setState(() {
        _previewStartScheduled = false;
        _previewError = msg;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If user goes to Settings and comes back, refresh permission status.
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  /// Load user profile
  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _profileService.getUserProfile(user.id);
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      LogService.warning('Error loading profile: $e');
    }
  }

  /// Check current permission status
  Future<void> _checkPermissionStatus() async {
    if (kIsWeb) {
      // Web: permissions are requested by browser when joining (getUserMedia).
      setState(() {
        _showPermissionDialog = true;
      });
      return;
    }

    // Android: check runtime permissions so we can guide user (or deep-link to settings).
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await _cameraMicPermissionService.getStatus();
      setState(() {
        _permissionsGranted = status.allGranted;
        _permissionDeniedPermanently = status.anyDeniedPermanently;
        _showPermissionDialog = !status.allGranted;
      });
      if (status.allGranted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _runConnectionTestIfReady();
          _startPreviewIfNeeded();
        });
      }
      return;
    }

    // Other platforms: allow flow and rely on OS prompts.
    setState(() {
      _permissionsGranted = true;
      _showPermissionDialog = false;
    });
  }

  /// Request permissions via custom UI (like Google Meet)
  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // On web, permissions are requested when Agora SDK calls getUserMedia
        setState(() {
          _permissionsGranted = true;
          _showPermissionDialog = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _runConnectionTestIfReady();
          _startPreviewIfNeeded(); // Start preview on web so user sees camera feed
        });
        LogService.success('✅ Permissions will be requested by browser when joining');
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final status = await _cameraMicPermissionService.request();
          setState(() {
            _cameraPermissionRequested = true;
            _micPermissionRequested = true;
            _notificationPermissionRequested = true;
            _permissionsGranted = status.allGranted;
            _permissionDeniedPermanently = status.anyDeniedPermanently;
            _showPermissionDialog = !status.allGranted;
          });

          if (!status.allGranted) {
            setState(() {
              _errorMessage = status.anyDeniedPermanently
                  ? 'Camera/Microphone permissions are blocked. Please enable them in Settings.'
                  : 'Please allow camera and microphone permissions to continue.';
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) => _startPreviewIfNeeded());
          }
        } else {
          // For other platforms, rely on platform prompt when joining.
          setState(() {
            _cameraPermissionRequested = true;
            _micPermissionRequested = true;
            _notificationPermissionRequested = true;
            _permissionsGranted = true;
            _showPermissionDialog = false;
          });
          LogService.success('✅ Permissions will be requested by platform when joining');
        }
      }
    } catch (e) {
      LogService.error('❌ Error requesting permissions: $e');
      setState(() {
        _permissionsGranted = false;
        _errorMessage = 'Failed to request permissions. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openAppSettings() async {
    await _cameraMicPermissionService.openAppSettings();
  }

  /// Run connection test when permissions are granted (optional pre-lesson check).
  void _runConnectionTestIfReady() {
    if (!_permissionsGranted || _connectionTested || _isTestingConnection || !mounted) return;
    _runConnectionTest();
  }

  Future<void> _runConnectionTest() async {
    if (_isTestingConnection || !mounted) return;
    setState(() {
      _isTestingConnection = true;
      _connectionTested = false;
      _connectionQuality = null;
    });
    try {
      final quality = await ConnectionQualityService.assessConnectionQuality();
      if (mounted) {
        setState(() {
          _connectionQuality = quality;
          _connectionTested = true;
          _isTestingConnection = false;
        });
      }
    } catch (e) {
      LogService.warning('Connection test failed: $e');
      if (mounted) {
        setState(() {
          _connectionQuality = 'fair';
          _connectionTested = true;
          _isTestingConnection = false;
        });
      }
    }
  }

  /// Get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Join the session: pop with result so caller can push video screen (unified join flow).
  Future<void> _joinSession() async {
    if (!_permissionsGranted) {
      setState(() {
        _errorMessage = 'Please grant camera and microphone permissions to continue.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (mounted) {
        Navigator.pop(context, <String, dynamic>{
          'join': true,
          'camera': _cameraEnabled,
          'mic': _micEnabled,
        });
      }
    } catch (e) {
      LogService.error('[PREVIEW] Error joining session: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to join session. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get name from profile, with proper fallback
    String name = 'Loading...';
    if (_userProfile != null) {
      final profileName = _userProfile!['full_name'] as String?;
      if (profileName != null && profileName.isNotEmpty && profileName != 'User') {
        name = profileName;
      } else {
        name = widget.userRole == 'tutor' ? 'Tutor' : 'Learner';
      }
    } else {
      name = widget.userRole == 'tutor' ? 'Tutor' : 'Learner';
    }
    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Start live camera preview once when permissions granted and camera on (single schedule)
    if (_permissionsGranted && _cameraEnabled && !_showPermissionDialog && !_previewStarted && !_previewStartScheduled) {
      setState(() => _previewStartScheduled = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPreviewIfNeeded());
    }

    return StatusBarUtils.withLightStatusBar(
      Scaffold(
        backgroundColor: AppTheme.softBackground,
        body: Stack(
          children: [
            SafeArea(
              child: isMobile ? _buildMobileLayout(name, avatarUrl) : _buildDesktopLayout(name, avatarUrl),
            ),
            if (_showPermissionDialog) _buildPermissionDialog(),
          ],
        ),
      ),
    );
  }

  /// Build permission request dialog (Google Meet style)
  Widget _buildPermissionDialog() {
    if (!_showPermissionDialog) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.videocam,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'Allow camera and microphone',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'To join the video session, we need access to your camera and microphone. This allows you to see and hear others in the call.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Permission list
              _buildPermissionItem(Icons.videocam, 'Camera', 'To show your video to others'),
              const SizedBox(height: 12),
              _buildPermissionItem(Icons.mic, 'Microphone', 'To let others hear you'),
              const SizedBox(height: 12),
              _buildPermissionItem(Icons.notifications, 'Notifications', 'To notify you about calls'),
              const SizedBox(height: 32),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showPermissionDialog = false;
                        });
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_permissionDeniedPermanently
                              ? _openAppSettings
                              : _requestPermissions),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _permissionDeniedPermanently
                                  ? 'Open Settings'
                                  : 'Allow',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build permission item in dialog
  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop layout (side-by-side)
  Widget _buildDesktopLayout(String name, String? avatarUrl) {
    return Row(
      children: [
        // Left panel - Preview (soft neutral, no black)
        Expanded(
          flex: 2,
          child: Container(
            color: AppTheme.softBackground,
            child: Stack(
              children: [
                // Live camera preview when on and engine ready, else profile/avatar
                _buildPreviewContent(name, avatarUrl),
                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mic toggle
                        _buildPreJoinControl(
                          icon: _micEnabled ? Icons.mic : Icons.mic_off,
                          label: _micEnabled ? 'Mic on' : 'Mic off',
                          isActive: _micEnabled,
                          onTap: () {
                            setState(() {
                              _micEnabled = !_micEnabled;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        // Camera toggle
                        _buildPreJoinControl(
                          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                          label: _cameraEnabled ? 'Camera on' : 'Camera off',
                          isActive: _cameraEnabled,
                          onTap: () async {
                            setState(() => _cameraEnabled = !_cameraEnabled);
                            if (_cameraEnabled) {
                              if (_previewStarted) {
                                await _agoraService.setPreJoinCameraEnabled(true);
                              } else {
                                await _startPreviewIfNeeded();
                              }
                            } else {
                              await _agoraService.setPreJoinCameraEnabled(false);
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right panel - Join options
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(32),
            child: _buildJoinOptions(),
          ),
        ),
      ],
    );
  }

  /// Mobile layout (stacked)
  Widget _buildMobileLayout(String name, String? avatarUrl) {
    return Column(
      children: [
        // Top panel - Preview (larger area so video is clearly visible; ~2/3 of screen)
        Expanded(
          flex: 2,
          child: Container(
            color: AppTheme.softBackground,
            child: Stack(
              children: [
                // Live camera preview when on and engine ready, else profile/avatar
                _buildPreviewContent(name, avatarUrl, isMobile: true),
                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mic toggle
                        _buildPreJoinControl(
                          icon: _micEnabled ? Icons.mic : Icons.mic_off,
                          label: _micEnabled ? 'Mic on' : 'Mic off',
                          isActive: _micEnabled,
                          onTap: () {
                            setState(() {
                              _micEnabled = !_micEnabled;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        // Camera toggle
                        _buildPreJoinControl(
                          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                          label: _cameraEnabled ? 'Camera on' : 'Camera off',
                          isActive: _cameraEnabled,
                          onTap: () async {
                            setState(() => _cameraEnabled = !_cameraEnabled);
                            if (_cameraEnabled) {
                              if (_previewStarted) {
                                await _agoraService.setPreJoinCameraEnabled(true);
                              } else {
                                await _startPreviewIfNeeded();
                              }
                            } else {
                              await _agoraService.setPreJoinCameraEnabled(false);
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom panel - Join options (compact, scrollable to avoid overflow and show Join + Cancel)
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SingleChildScrollView(
              child: _buildJoinOptions(),
            ),
          ),
        ),
      ],
    );
  }

  /// Join options section (compact to avoid overflow; Join and Cancel always visible)
  Widget _buildJoinOptions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ready to join?',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check your camera and mic, then join.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        if (_connectionQuality != null) ...[
          _buildConnectionResult(),
          const SizedBox(height: 12),
        ],
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton(
          onPressed: _permissionsGranted && !_isLoading ? _joinSession : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 2,
            shadowColor: AppTheme.primaryColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Join',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        if (!_permissionsGranted) ...[
          TextButton(
            onPressed: _requestPermissions,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Grant permissions',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionResult() {
    final q = _connectionQuality!;
    final label = q == 'good'
        ? 'Good – you\'re good to go'
        : q == 'fair'
            ? 'Fair – you can join'
            : 'Poor – try moving closer to your router';
    final color = q == 'good'
        ? Colors.green[700]
        : q == 'fair'
            ? Colors.orange[700]
            : Colors.red[700];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.signal_cellular_alt, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              'Connection: ${q[0].toUpperCase()}${q.substring(1)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        if (!_isTestingConnection) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _runConnectionTest,
            child: Text(
              'Try again',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }


  /// Preview area: live camera when engine ready and preview started; profile when off or not ready.
  /// Keep the same video view in the tree once preview has started so mute/unmute doesn't lose the view.
  Widget _buildPreviewContent(String name, String? avatarUrl, {bool isMobile = false}) {
    final engine = _agoraService.engine;
    if (engine == null || !_previewStarted) {
      return Container(
        color: AppTheme.softBackground,
        child: Center(
          child: _previewError != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _previewError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : _previewStartScheduled && _cameraEnabled
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'Starting camera...',
                          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    )
                  : _buildProfilePreview(name, avatarUrl, isMobile: isMobile),
        ),
      );
    }
    // Once preview started, keep the video view in the tree so toggling camera off/on doesn't recreate it.
    // On Android, startPreview() must run after the platform view exists; _PreJoinVideoHost does that.
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: SizedBox.expand(
            child: _PreJoinVideoHost(
              agoraService: _agoraService,
              child: agora_widget.AgoraVideoViewWidget(
                key: const ValueKey<String>('prejoin_local_video'),
                engine: engine,
                uid: 0,
                isLocal: true,
                connection: null,
              ),
            ),
          ),
        ),
        if (!_cameraEnabled)
          Container(
            color: AppTheme.softBackground,
            child: Center(child: _buildProfilePreview(name, avatarUrl, isMobile: isMobile)),
          ),
        // Talking indicator: show when local mic volume is above threshold
        if (_localSpeaking && _micEnabled)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Speaking', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Build profile preview (avatar + name, used when camera off or preview not ready)
  Widget _buildProfilePreview(String name, String? avatarUrl, {bool isMobile = false}) {
    final size = isMobile ? 120.0 : 150.0;
    final fontSize = isMobile ? 36.0 : 48.0;
    final nameFontSize = isMobile ? 18.0 : 20.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[800],
            border: Border.all(
              color: Colors.grey[600]!,
              width: 3,
            ),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        _getInitials(name),
                        style: GoogleFonts.poppins(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _getInitials(name),
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
        SizedBox(height: isMobile ? 16 : 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: nameFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  /// Build pre-join control button (neutral when on, red when off; deep blue border when on)
  Widget _buildPreJoinControl({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const deepBlue = AppTheme.primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isActive
                ? deepBlue.withOpacity(0.08)
                : Colors.red.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? deepBlue : Colors.red,
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? deepBlue : Colors.red,
              size: 24,
            ),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey[800],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// On Android, the native video view must exist before startPreview() or the preview stays black.
/// This widget calls [AgoraService.startPreJoinPreviewCapture] after the first frame so the view is in the tree.
class _PreJoinVideoHost extends StatefulWidget {
  final AgoraService agoraService;
  final Widget child;

  const _PreJoinVideoHost({required this.agoraService, required this.child});

  @override
  State<_PreJoinVideoHost> createState() => _PreJoinVideoHostState();
}

class _PreJoinVideoHostState extends State<_PreJoinVideoHost> {
  bool _captureStarted = false;

  @override
  void initState() {
    super.initState();
    // On mobile (Android/iOS), the native view must exist before startPreview() or preview stays black.
    if (!kIsWeb) {
      // Delay so the platform view is in the tree and has a surface (Android especially needs this).
      final delayMs = defaultTargetPlatform == TargetPlatform.android ? 150 : 50;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_captureStarted && mounted) {
          await Future.delayed(Duration(milliseconds: delayMs));
          if (!_captureStarted && mounted) {
            _captureStarted = true;
            widget.agoraService.startPreJoinPreviewCapture();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}