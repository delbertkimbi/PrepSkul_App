import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/camera_mic_permission_service.dart';
import 'package:prepskul/core/services/device_readiness_service.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/services/connection_quality_service.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart' as agora_widget;
import 'package:prepskul/features/sessions/widgets/classroom_offline_banner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/core/config/app_config.dart';

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

  bool _cameraEnabled = AppConfig.enableSessionCameraPublishing;
  bool _micEnabled = true;
  bool _permissionsGranted = false;
  bool _isLoading = false;
  bool _showPermissionDialog = false;
  String? _errorMessage;
  bool _permissionDeniedPermanently = false;
  
  Map<String, dynamic>? _userProfile;

  Map<String, dynamic>? _sessionContext;
  /// True after the first roster fetch attempt (success or empty).
  bool _sessionContextResolved = false;
  DeviceReadinessSnapshot? _deviceSnapshot;
  bool _isProbingDevices = false;
  
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
  /// True after user taps Join; [dispose] must not release the shared engine —
  /// the call screen reuses it. Only release when the user backs out / cancels.
  bool _handedOffEngineToSession = false;
  bool _previewStarted = false;
  bool _previewStartScheduled = false; // Prevent multiple concurrent starts
  bool _previewStartInProgress = false;
  bool _webPermissionPromptAttempted = false;
  String? _previewError; // e.g. CORS or token failure on web

  /// Talking indicator — isolated from full-screen rebuilds ([ValueNotifier] vs [setState]).
  final ValueNotifier<bool> _localSpeakingVN = ValueNotifier<bool>(false);
  /// Normalized microphone level (0–1) from [AgoraService.preJoinMicLevelStream] for web-friendly wave.
  final ValueNotifier<double> _preJoinMicLevelVN = ValueNotifier<double>(0);
  StreamSubscription<Set<int>>? _speakingSubscription;
  StreamSubscription<double>? _preJoinMicLevelSubscription;
  double _smoothedPreJoinMicLevel = 0;
  double _preJoinMicWaveVisualLevel = 0;
  DateTime _preJoinMicWaveHoldUntil = DateTime.fromMillisecondsSinceEpoch(0);

  late final Listenable _preJoinMicVisualListenable =
      Listenable.merge([_localSpeakingVN, _preJoinMicLevelVN]);

  final ConnectivityService _connectivity = ConnectivityService();
  StreamSubscription<bool>? _lobbyConnectivitySubscription;
  Timer? _lobbyOfflineDebounce;
  bool _lobbyOfflineDialogOpen = false;
  bool _lobbyConnectivityOnline = true;
  static const Duration _kLobbyOfflineDebounce =
      Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupLobbyConnectivityGuards();
    _loadUserProfile();
    _loadSessionContext();
    _probeDevices();
    _checkPermissionStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runConnectionTestIfReady());
    _speakingSubscription = _agoraService.speakingStream.listen((uids) {
      final speaking = uids.contains(0);
      if (_localSpeakingVN.value != speaking) _localSpeakingVN.value = speaking;
    });
    _preJoinMicLevelSubscription =
        _agoraService.preJoinMicLevelStream.listen((raw) {
      _smoothedPreJoinMicLevel += 0.42 * (raw.clamp(0.0, 1.0) - _smoothedPreJoinMicLevel);
      final v = _smoothedPreJoinMicLevel.clamp(0.0, 1.0);
      if ((_preJoinMicLevelVN.value - v).abs() > 0.02 || (v < 0.03 && _preJoinMicLevelVN.value > 0)) {
        _preJoinMicLevelVN.value = v < 0.03 ? 0 : v;
      }
    });
  }

  @override
  void dispose() {
    _lobbyConnectivitySubscription?.cancel();
    _lobbyOfflineDebounce?.cancel();
    _speakingSubscription?.cancel();
    _preJoinMicLevelSubscription?.cancel();
    _localSpeakingVN.dispose();
    _preJoinMicLevelVN.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (!_handedOffEngineToSession) {
      _agoraService.releasePreviewIfNotInChannel();
    }
    super.dispose();
  }

  void _setupLobbyConnectivityGuards() {
    unawaited(() async {
      try {
        await _connectivity.initialize();
      } catch (e) {
        LogService.warning('Lobby connectivity init failed: $e');
      }
      if (!mounted) return;

      var bootOnline = true;
      try {
        bootOnline = await _connectivity.checkConnectivity();
      } catch (e) {
        LogService.warning('Lobby boot connectivity failed: $e');
        bootOnline = false;
      }
      if (!mounted) return;
      setState(() => _lobbyConnectivityOnline = bootOnline);

      _lobbyConnectivitySubscription =
          _connectivity.connectivityStream.listen((online) {
        if (!mounted) return;
        setState(() => _lobbyConnectivityOnline = online);
        if (!online) {
          _lobbyOfflineDebounce?.cancel();
          _lobbyOfflineDebounce = Timer(_kLobbyOfflineDebounce, () async {
            if (!mounted) return;
            try {
              final ok = await _connectivity.checkConnectivity();
              if (ok || !mounted) return;
              await _presentLobbyOfflineDialog();
            } catch (e) {
              LogService.warning('Lobby offline recheck failed: $e');
            }
          });
        } else {
          _lobbyOfflineDebounce?.cancel();
          unawaited(() async {
            if (!mounted) return;
            try {
              final ok = await _connectivity.checkConnectivity();
              if (!ok || !mounted) return;
            } catch (_) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _dismissLobbyOfflineDialogIfOpen();
            });
          }());
        }
      });

      if (!bootOnline && mounted) {
        await _presentLobbyOfflineDialog();
      }
    }());
  }

  Future<void> _presentLobbyOfflineDialog() async {
    if (!mounted || _lobbyOfflineDialogOpen) return;
    final ctx = context;
    if (!ctx.mounted) return;
    _lobbyOfflineDialogOpen = true;
    try {
      await OfflineDialog.show(
        ctx,
        message:
            'No internet connection. You need a network link to preview your mic or camera '
            'and to join this lesson.\n\n'
            'Check Wi‑Fi or mobile data, then try again.',
      );
    } finally {
      _lobbyOfflineDialogOpen = false;
    }
  }

  void _dismissLobbyOfflineDialogIfOpen() {
    if (!mounted || !_lobbyOfflineDialogOpen) return;
    try {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    } catch (e) {
      LogService.debug('Auto-dismiss lobby offline dialog: $e');
    }
  }

  /// Start lobby RTC: camera preview when enabled, otherwise audio-only (**mic level**) path.
  Future<void> _startPreviewIfNeeded() async {
    if (!_permissionsGranted ||
        _previewStarted ||
        _previewStartInProgress) {
      return;
    }
    _previewStartInProgress = true;
    if (mounted) {
      setState(() {
        _previewStartScheduled = true;
        _previewError = null;
      });
    }
    final wantCameraPreview =
        AppConfig.enableSessionCameraPublishing && _cameraEnabled;
    try {
      if (_voiceOnlyLesson) {
        await _agoraService.startPreJoinAudioMeterOnly(widget.sessionId);
      } else if (wantCameraPreview) {
        await _agoraService.startLocalPreviewForPreJoin(widget.sessionId);
      } else {
        await _agoraService.startPreJoinAudioMeterOnly(widget.sessionId);
      }
      await _agoraService.setPreJoinMicEnabled(_micEnabled);
      if (mounted) {
        setState(() {
          _previewStarted = true;
          _previewStartScheduled = false;
          _previewStartInProgress = false;
          _previewError = null;
        });
      }
    } catch (e) {
      LogService.warning('[PREVIEW] Pre-join lobby media failed: $e');
      final msg = e.toString().contains('CORS') || e.toString().contains('origin')
          ? 'Could not connect to the server. If you\'re on localhost, the API may need to allow your origin (CORS). Try again or use the app from the same domain as the API.'
          : (!wantCameraPreview || _voiceOnlyLesson)
              ? 'Microphone check could not start. Check your connection and try again.'
              : 'Camera could not start. Check your connection and try again.';
      if (mounted) {
        setState(() {
          _previewStartScheduled = false;
          _previewStartInProgress = false;
          _previewError = msg;
        });
      }
    } finally {
      if (!mounted) {
        _previewStartInProgress = false;
        _previewStartScheduled = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If user goes to Settings and comes back, refresh permission status.
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
      _probeDevices();
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

  Future<void> _loadSessionContext() async {
    try {
      Map<String, dynamic>? row;

      final individual = await _supabase
          .from('individual_sessions')
          .select('subject, scheduled_date, scheduled_time')
          .eq('id', widget.sessionId)
          .maybeSingle();

      if (individual != null) {
        row = Map<String, dynamic>.from(individual);
      } else {
        final trial = await _supabase
            .from('trial_sessions')
            .select('subject, scheduled_date, scheduled_time')
            .eq('id', widget.sessionId)
            .maybeSingle();
        if (trial != null) {
          row = Map<String, dynamic>.from(trial);
        }
      }

      if (!mounted) return;
      setState(() => _sessionContext = row);
    } catch (e) {
      LogService.debug('[PREJOIN] Session context unavailable: $e');
    } finally {
      if (mounted) {
        setState(() => _sessionContextResolved = true);
      }
    }
  }

  Future<void> _probeDevices() async {
    if (_isProbingDevices) return;
    setState(() => _isProbingDevices = true);
    try {
      final snapshot = await DeviceReadinessService.probe();
      if (!mounted) return;
      setState(() => _deviceSnapshot = snapshot);
    } catch (e) {
      LogService.debug('[PREJOIN] Device probe failed: $e');
    } finally {
      if (mounted) setState(() => _isProbingDevices = false);
    }
  }

  String _lessonScheduleLine() {
    if (!_sessionContextResolved) {
      return 'Loading your roster details…';
    }
    if (_sessionContext == null) {
      return 'Open this lesson from My sessions (or your booking link) so the scheduled time can load.';
    }
    final ctx = _sessionContext!;
    final pretty = sessionScheduledDisplayFromParts(
      ctx['scheduled_date'],
      ctx['scheduled_time'],
    );
    if (pretty != null && pretty.isNotEmpty) return pretty;

    return 'We have this lesson on file; if the time looks wrong, open it from My sessions for the latest schedule.';
  }

  /// Check current permission status
  Future<void> _checkPermissionStatus() async {
    if (kIsWeb) {
      // Web: rely on browser-native prompt once when prejoin media starts.
      setState(() {
        _permissionsGranted = true;
        _showPermissionDialog = false;
      });
      if (!_webPermissionPromptAttempted) {
        _webPermissionPromptAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _runConnectionTestIfReady();
          _startPreviewIfNeeded();
        });
      }
      return;
    }

    // Android: check runtime permissions so we can guide user (or deep-link to settings).
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await _cameraMicPermissionService.getStatus();
      final ready = _lessonMediaPermissionsGranted(status);
      setState(() {
        _permissionsGranted = ready;
        _permissionDeniedPermanently = AppConfig.enableSessionCameraPublishing
            ? status.anyDeniedPermanently
            : (status.microphone == PermissionState.deniedPermanently);
        _showPermissionDialog = !ready;
      });
      if (ready) {
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

  /// Request permissions via custom in-app UI
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
        _webPermissionPromptAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _runConnectionTestIfReady();
          _startPreviewIfNeeded(); // Start preview on web so user sees camera feed
        });
        LogService.success('✅ Permissions will be requested by browser when joining');
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final status = await _cameraMicPermissionService.request();
          final ready = _lessonMediaPermissionsGranted(status);
        setState(() {
          _cameraPermissionRequested = true;
          _micPermissionRequested = true;
          _notificationPermissionRequested = true;
            _permissionsGranted = ready;
            _permissionDeniedPermanently = AppConfig.enableSessionCameraPublishing
                ? status.anyDeniedPermanently
                : (status.microphone == PermissionState.deniedPermanently);
            _showPermissionDialog = !ready;
          });

          if (!ready) {
            setState(() {
              if (_voiceOnlyLesson) {
                _errorMessage = status.microphone ==
                        PermissionState.deniedPermanently
                    ? 'Microphone permission is blocked. Enable it in Settings to join.'
                    : 'Allow microphone permission to join this lesson.';
              } else {
                _errorMessage = status.anyDeniedPermanently
                    ? 'Camera/Microphone permissions are blocked. Please enable them in Settings.'
                    : 'Please allow camera and microphone permissions to continue.';
              }
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

  bool get _voiceOnlyLesson =>
      !AppConfig.enableSessionCameraPublishing;

  bool _lessonMediaPermissionsGranted(CameraMicPermissionStatus status) {
    if (_voiceOnlyLesson) {
      return status.microphone == PermissionState.granted;
    }
    return status.allGranted;
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
        _errorMessage = _voiceOnlyLesson
            ? 'Allow microphone permission to continue.'
            : 'Please grant camera and microphone permissions to continue.';
      });
      return;
    }

    try {
      final online = await _connectivity.checkConnectivity();
      if (!online) {
        if (mounted) await _presentLobbyOfflineDialog();
        return;
      }
    } catch (e) {
      LogService.warning('Pre-join join connectivity check: $e');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (mounted) {
        _handedOffEngineToSession = true;
        Navigator.pop(context, <String, dynamic>{
          'join': true,
          'camera': _cameraEnabled,
          'mic': _micEnabled,
        });
      }
    } catch (e) {
      _handedOffEngineToSession = false;
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

    return StatusBarUtils.withLightStatusBar(
      Scaffold(
      backgroundColor: AppTheme.softBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_lobbyConnectivityOnline)
                  const ClassroomOfflineBanner(
                    message:
                        'No internet — connect to preview AV and join the lesson.',
                  ),
                Expanded(
                  child: isMobile
                      ? _buildMobileLayout(name, avatarUrl)
                      : _buildDesktopLayout(name, avatarUrl),
                ),
              ],
            ),
          ),
          if (_showPermissionDialog) _buildPermissionDialog(),
        ],
        ),
      ),
    );
  }

  /// Build permission request dialog (PrepSkul in-app)
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
                  _voiceOnlyLesson ? Icons.mic : Icons.videocam,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                _voiceOnlyLesson
                    ? 'Allow microphone'
                    : 'Allow camera and microphone',
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
                _voiceOnlyLesson
                    ? 'This lesson connects by voice — we need microphone access so you and your tutor can hear each other. Camera stays off.'
                    : 'To join the video session, we need access to your camera and microphone. This allows you to see and hear others in the call.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Permission list
              if (!_voiceOnlyLesson) ...[
                _buildPermissionItem(Icons.videocam, 'Camera', 'To show your video to others'),
                const SizedBox(height: 12),
              ],
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
                          fontSize: 14,
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
                                fontSize: 13,
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
                        _buildPreJoinMicDial(),
                        if (AppConfig.enableSessionCameraPublishing) ...[
                          const SizedBox(width: 16),
                          // Camera toggle
                          _buildPreJoinControl(
                            icon: _cameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            label: _cameraEnabled ? 'Camera on' : 'Camera off',
                            isActive: _cameraEnabled,
                            onTap: () async {
                              setState(() => _cameraEnabled = !_cameraEnabled);
                              if (_cameraEnabled) {
                                if (_previewStarted) {
                                  await _agoraService.setPreJoinCameraEnabled(
                                      true);
                                } else {
                                  await _startPreviewIfNeeded();
                                }
                              } else {
                                await _agoraService.setPreJoinCameraEnabled(
                                    false);
                              }
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
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
            child: _buildJoinOptions(prioritizeJoinAboveFold: false),
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
                        _buildPreJoinMicDial(),
                        if (AppConfig.enableSessionCameraPublishing) ...[
                          const SizedBox(width: 16),
                          // Camera toggle
                          _buildPreJoinControl(
                            icon: _cameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            label: _cameraEnabled ? 'Camera on' : 'Camera off',
                            isActive: _cameraEnabled,
                            onTap: () async {
                              setState(() => _cameraEnabled = !_cameraEnabled);
                              if (_cameraEnabled) {
                                if (_previewStarted) {
                                  await _agoraService.setPreJoinCameraEnabled(
                                      true);
                                } else {
                                  await _startPreviewIfNeeded();
                                }
                              } else {
                                await _agoraService.setPreJoinCameraEnabled(
                                    false);
                              }
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _buildJoinOptions(prioritizeJoinAboveFold: true),
          ),
        ),
      ],
    );
  }

  /// VA awareness: monitoring and supervision (no support). Visible block with link to web doc.
  /// Uses smaller font and card on mobile (web and app).
  Widget _buildVAAwarenessBlock() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final iconSize = isMobile ? 16.0 : 18.0;
    final bodyFontSize = isMobile ? 11.0 : 12.0;
    final linkFontSize = isMobile ? 11.0 : 12.0;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: iconSize),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PrepSkul VA monitors lesson quality and safety in the background.",
                      style: GoogleFonts.poppins(
                        fontSize: bodyFontSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(AppConfig.vaDocumentationUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        "About PrepSkul's VA",
                        style: GoogleFonts.poppins(
                          fontSize: linkFontSize,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionContextCard() {
    final subject = (_sessionContext?['subject'] as String?)?.trim();
    final lesson = (subject == null || subject.isEmpty)
        ? 'This lesson'
        : subject;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x221B2C4F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _lessonScheduleLine(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (_sessionContextResolved && _sessionContext == null) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: this screen loads booking details from PrepSkul when you start the lesson from your schedule.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadinessChecklist() {
    final snapshot = _deviceSnapshot;
    final connReady =
        _connectionQuality == 'good' || _connectionQuality == 'fair';
    final connLabel = _isTestingConnection
        ? 'Checking...'
        : _connectionQuality == null
            ? 'Pending'
            : _connectionQuality!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pre-class readiness',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          _readinessRow(
            label: 'Permissions',
            ok: _permissionsGranted,
            detail: _permissionsGranted ? 'Granted' : 'Needed',
          ),
          if (_voiceOnlyLesson)
            _readinessRow(
              label: 'Video',
              ok: true,
              detail: 'Voice-only (no camera)',
            ),
          if (AppConfig.enableSessionCameraPublishing)
            _readinessRow(
              label: 'Camera',
              ok: _cameraEnabled && (_previewStarted || !kIsWeb),
              detail: snapshot == null
                  ? (_isProbingDevices ? 'Checking device...' : 'Pending')
                  : '${snapshot.cameraInputs} input(s)',
            ),
          ValueListenableBuilder<bool>(
            valueListenable: _localSpeakingVN,
            builder: (context, speaking, _) {
              final micSignal = speaking && _micEnabled;
              return _readinessRow(
                label: 'Microphone',
                ok: _micEnabled,
                detail: !_micEnabled
                    ? 'Mic is off'
                    : micSignal
                        ? 'Sound picked up'
                        : 'Speak — wave shows on mic',
              );
            },
          ),
          const SizedBox(height: 2),
          _buildNetworkReadinessBlock(
            connReady: connReady,
            connLabel: connLabel,
          ),
        ],
      ),
    );
  }

  /// Single place for network guidance (avoids duplicating the big red banner).
  Widget _buildNetworkReadinessBlock({
    required bool connReady,
    required String connLabel,
  }) {
    final tested = _connectionQuality != null;
    final color = !tested
        ? Colors.grey[500]!
        : connReady
            ? AppTheme.success
            : (_connectionQuality == 'fair'
                ? AppTheme.softYellow
                : AppTheme.error);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                !tested
                    ? Icons.wifi_tethering_outlined
                    : (connReady
                        ? Icons.check_circle_rounded
                        : Icons.signal_cellular_alt),
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Network',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[800]),
                ),
              ),
              Text(
                connLabel,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          if (tested && _connectionQuality == 'poor') ...[
            const SizedBox(height: 6),
            Text(
              'You can still join — this is guidance, not a hard block. Move closer to Wi‑Fi or wait a few seconds and retest.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.35,
                color: AppTheme.neutral600,
              ),
            ),
          ],
          if (!_isTestingConnection)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _runConnectionTest,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  tested ? 'Retest connectivity' : 'Run network check',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _readinessRow({
    required String label,
    required bool ok,
    required String detail,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? AppTheme.success : Colors.grey[500],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[800]),
            ),
          ),
          Flexible(
            child: Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop: natural stack in the right pane. Narrow: **[Join]** pinned under the headline;
  /// readiness, VA, and connection scroll underneath so Join is visible without digging.
  Widget _buildJoinOptions({required bool prioritizeJoinAboveFold}) {
    Widget joinButton() {
      return ElevatedButton(
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
      );
    }

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ready to join?',
          style: GoogleFonts.poppins(
            fontSize: prioritizeJoinAboveFold ? 18 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _voiceOnlyLesson
              ? 'This lesson uses audio only — check your microphone, then join.'
              : 'Check your camera and mic, then join.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );

    Widget errorBannerWidget() => Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.softYellowLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.softYellow),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.softYellow, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        );

    final trailingActions = <Widget>[
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
      if (!_permissionsGranted)
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
    ];

    if (prioritizeJoinAboveFold) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          const SizedBox(height: 10),
          joinButton(),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSessionContextCard(),
                  const SizedBox(height: 10),
                  _buildReadinessChecklist(),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) errorBannerWidget(),
                  _buildVAAwarenessBlock(),
                  const SizedBox(height: 14),
                  ...trailingActions,
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleBlock,
        const SizedBox(height: 14),
        _buildSessionContextCard(),
        const SizedBox(height: 10),
        _buildReadinessChecklist(),
        const SizedBox(height: 12),
        joinButton(),
        const SizedBox(height: 14),
        _buildVAAwarenessBlock(),
        const SizedBox(height: 14),
        if (_errorMessage != null) errorBannerWidget(),
        ...trailingActions,
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
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.softYellow,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _previewError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppTheme.neutral700,
                          fontSize: 14,
                        ),
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

  Widget _buildPreJoinMicDial() {
    return AnimatedBuilder(
      animation: _preJoinMicVisualListenable,
      builder: (context, _) {
        final speaking = _localSpeakingVN.value;
        final level = _preJoinMicLevelVN.value;
        final levelGate = kIsWeb ? 0.02 : 0.03;
        final now = DateTime.now();
        if (_micEnabled && (speaking || level > levelGate)) {
          _preJoinMicWaveHoldUntil = now.add(const Duration(milliseconds: 240));
        }
        var target = _micEnabled ? level : 0.0;
        if (_micEnabled && speaking && target < 0.18) {
          target = 0.18;
        }
        if (_micEnabled &&
            now.isBefore(_preJoinMicWaveHoldUntil) &&
            target < 0.14) {
          target = 0.14;
        }
        final easing = target > _preJoinMicWaveVisualLevel ? 0.55 : 0.22;
        _preJoinMicWaveVisualLevel +=
            (target - _preJoinMicWaveVisualLevel) * easing;
        if (!_micEnabled || _preJoinMicWaveVisualLevel < 0.015) {
          _preJoinMicWaveVisualLevel = 0;
        }
        final showWave = _micEnabled && _preJoinMicWaveVisualLevel > 0.05;
        return _buildPreJoinControl(
          icon: _micEnabled ? Icons.mic : Icons.mic_off,
          label: _micEnabled ? 'Mic on' : 'Mic off',
          isActive: _micEnabled,
          showSpeakingWave: showWave,
          micActivityLevel: _preJoinMicWaveVisualLevel,
          onTap: () async {
            setState(() => _micEnabled = !_micEnabled);
            if (_previewStarted) {
              await _agoraService.setPreJoinMicEnabled(_micEnabled);
            }
          },
        );
      },
    );
  }

  /// Build pre-join control button (neutral when on, red when off; deep blue border when on).
  /// [showSpeakingWave] mirrors the in-call mic activity hint (small bars under the icon).
  Widget _buildPreJoinControl({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool showSpeakingWave = false,
    double micActivityLevel = 0,
  }) {
    const deepBlue = AppTheme.primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
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
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isActive ? deepBlue : Colors.red,
                    size: 24,
                  ),
                  if (showSpeakingWave)
                    Positioned(
                      bottom: 9,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(4, (i) {
                          final base = 4.0 + (i % 2) * 4.0;
                          final boosted =
                              base + micActivityLevel * (14.0 + i * 4.0);
                          return Container(
                            width: 2,
                            height: boosted.clamp(3.0, 22.0),
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? deepBlue.withOpacity(0.88)
                                  : Colors.red.withOpacity(0.88),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
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