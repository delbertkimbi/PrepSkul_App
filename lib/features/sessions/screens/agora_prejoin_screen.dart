import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/screens/agora_video_session_screen.dart';
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

class _AgoraPreJoinScreenState extends State<AgoraPreJoinScreen> {
  final SessionProfileService _profileService = SessionProfileService();
  final _supabase = SupabaseService.client;

  bool _cameraEnabled = true;
  bool _micEnabled = true;
  bool _permissionsGranted = false;
  bool _isLoading = false;
  bool _showPermissionDialog = false;
  String? _errorMessage;
  
  Map<String, dynamic>? _userProfile;
  
  // Permission states
  bool _cameraPermissionRequested = false;
  bool _micPermissionRequested = false;
  bool _notificationPermissionRequested = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // Don't auto-request permissions - show custom UI first
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    super.dispose();
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
    // Show permission dialog on first load
    // On web, permissions will be requested by browser when Agora SDK calls getUserMedia
    // On mobile, permissions will be requested by platform when needed
    setState(() {
      _showPermissionDialog = true;
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
        // We just mark as granted and let the SDK handle it
        setState(() {
          _permissionsGranted = true;
          _showPermissionDialog = false;
        });
        LogService.success('✅ Permissions will be requested by browser when joining');
      } else {
        // For mobile, permissions will be requested by platform when Agora SDK accesses camera/mic
        // Mark as granted - actual permissions will be requested by platform
        setState(() {
          _cameraPermissionRequested = true;
          _micPermissionRequested = true;
          _notificationPermissionRequested = true;
          _permissionsGranted = true; // Will be requested by platform when needed
          _showPermissionDialog = false;
        });
        LogService.success('✅ Permissions will be requested by platform when joining');
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

  /// Get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Join the session
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
      // Stream will be cleaned up automatically

      // Navigate to video session with initial camera/mic state
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AgoraVideoSessionScreen(
              sessionId: widget.sessionId,
              userRole: widget.userRole,
              initialCameraEnabled: _cameraEnabled,
              initialMicEnabled: _micEnabled,
            ),
          ),
        );
      }
    } catch (e) {
      LogService.error('Error joining session: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to join session. Please try again.';
      });
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

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      body: Stack(
        children: [
          SafeArea(
            child: isMobile ? _buildMobileLayout(name, avatarUrl) : _buildDesktopLayout(name, avatarUrl),
          ),
          // Permission dialog overlay
          if (_showPermissionDialog) _buildPermissionDialog(),
        ],
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
                        Navigator.pop(context);
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
                      onPressed: _isLoading ? null : _requestPermissions,
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
                              'Allow',
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
        // Left panel - Preview
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Video preview or profile
                Center(
                  child: _buildProfilePreview(name, avatarUrl),
                ),
                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
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
                          onTap: () {
                            setState(() {
                              _cameraEnabled = !_cameraEnabled;
                            });
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
        // Top panel - Preview
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Video preview or profile
                Center(
                  child: _buildProfilePreview(name, avatarUrl, isMobile: true),
                ),
                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
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
                          onTap: () {
                            setState(() {
                              _cameraEnabled = !_cameraEnabled;
                            });
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
        // Bottom panel - Join options
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: _buildJoinOptions(),
        ),
      ],
    );
  }

  /// Join options section (reusable for both layouts)
  Widget _buildJoinOptions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ready to join?',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No one else is here',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        // Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Join button
        ElevatedButton(
          onPressed: _permissionsGranted && !_isLoading ? _joinSession : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
            shadowColor: AppTheme.primaryColor.withOpacity(0.3),
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
                  'Join now',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        if (!_permissionsGranted) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _requestPermissions,
            child: Text(
              'Grant permissions',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }


  /// Build profile preview
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
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Build pre-join control button
  Widget _buildPreJoinControl({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isActive 
                ? AppTheme.primaryColor.withOpacity(0.2) 
                : Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: !isActive 
                ? Border.all(color: AppTheme.accentOrange, width: 2) 
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: !isActive 
                  ? AppTheme.accentOrange 
                  : AppTheme.primaryColor,
              size: 24,
            ),
            onPressed: onTap,
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
}

