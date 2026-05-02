import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';

/// Profile card overlay displayed when camera is off
/// Shows user's profile picture, name, and role in a professional card design
class ProfileCardOverlay extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String role; // 'tutor' or 'learner'
  final bool isLocal; // true for local user, false for remote
  final bool userLeft; // true if user left the call (for remote users)
  final bool screenOff; // true if user's screen is off (for remote users)
  final bool cameraOff; // true when remote camera is off (for remote users)
  final bool
  isSpeaking; // true when this user's audio is above threshold (talking indicator)
  final bool
  reconnecting; // true when connection unstable - show "Reconnecting" (independent of camera/screen state)
  /// Remote tile: joined but first decoded frame not ready yet (avoid generic “unavailable”).
  final bool waitingForVideo;

  const ProfileCardOverlay({
    Key? key,
    this.avatarUrl,
    required this.name,
    required this.role,
    this.isLocal = false,
    this.userLeft = false,
    this.screenOff = false,
    this.cameraOff = false,
    this.isSpeaking = false,
    this.reconnecting = false,
    this.waitingForVideo = false,
  }) : super(key: key);

  /// Get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Get color based on role
  Color _getRoleColor() {
    switch (role.toLowerCase()) {
      case 'tutor':
        return AppTheme.accentBlue;
      case 'learner':
        return AppTheme.accentGreen;
      default:
        return AppTheme.textMedium;
    }
  }

  /// Build one or more status lines (connecting, camera off, screen off, reconnecting).
  List<Widget> _buildStatusLines() {
    final lines = <Widget>[];
    if (waitingForVideo && !userLeft && !isLocal) {
      lines.add(_connectingVideoRow());
    }
    if (cameraOff) {
      lines.add(
        _statusRow(Icons.videocam_off, 'Camera is off', AppTheme.softYellow),
      );
    }
    if (screenOff) {
      lines.add(
        _statusRow(Icons.phone_android, 'Screen is off', AppTheme.primaryColor),
      );
    }
    if (reconnecting && !userLeft) {
      lines.add(
        _statusRow(Icons.sync, 'Video is reconnecting…', AppTheme.softYellow),
      );
    }
    if (lines.isEmpty && !userLeft && !isLocal) {
      lines.add(
        _statusRow(
          Icons.videocam_off,
          'Video is temporarily unavailable',
          AppTheme.softYellow,
        ),
      );
    }
    return lines;
  }

  Widget _connectingVideoRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor.withOpacity(0.95),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Connecting video…',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isShortHeight = media.size.height < 720;
    final avatarSize = isShortHeight ? 108.0 : 150.0;
    final nameFontSize = isShortHeight ? 18.0 : 24.0;
    final roleFontSize = isShortHeight ? 10.0 : 12.0;
    final cardPadding = isShortHeight ? 16.0 : 32.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryDark.withOpacity(0.9),
            AppTheme.primaryDark.withOpacity(0.95),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: isShortHeight ? 420 : 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture or initials
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getRoleColor().withOpacity(0.2),
                    border: Border.all(
                      color: _getRoleColor().withOpacity(0.5),
                      width: 3,
                    ),
                  ),
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                color: _getRoleColor(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                _getInitials(name),
                                style: GoogleFonts.poppins(
                                  fontSize: avatarSize * 0.32,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleColor(),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _getInitials(name),
                            style: GoogleFonts.poppins(
                              fontSize: avatarSize * 0.32,
                              fontWeight: FontWeight.bold,
                              color: _getRoleColor(),
                            ),
                          ),
                        ),
                ),
                SizedBox(height: isShortHeight ? 14 : 24),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: isShortHeight ? 6 : 8),
                // Role badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isShortHeight ? 12 : 16,
                    vertical: isShortHeight ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: roleFontSize,
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(),
                      letterSpacing: isShortHeight ? 1.0 : 1.2,
                    ),
                  ),
                ),
                if (!isLocal && userLeft) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_off,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Left the call',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isLocal && !userLeft) ...[
                  // Show status lines independently: camera off, screen off, and reconnecting can all be shown when true
                  const SizedBox(height: 16),
                  ..._buildStatusLines(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
