import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Profile card overlay displayed when camera is off
/// Shows user's profile picture, name, and role in a professional card design
class ProfileCardOverlay extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String role; // 'tutor' or 'learner'
  final bool isLocal; // true for local user, false for remote
  final bool userLeft; // true if remote user has left the call

  const ProfileCardOverlay({
    Key? key,
    this.avatarUrl,
    required this.name,
    required this.role,
    this.isLocal = false,
    this.userLeft = false,
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
        return Colors.blue;
      case 'learner':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile picture or initials
              Container(
                width: 150,
                height: 150,
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
                                fontSize: 48,
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
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              // Name
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getRoleColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getRoleColor().withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getRoleColor(),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (!isLocal && !userLeft) ...[
                // Only show "Camera is off" message when camera is off but user hasn't left
                // "Left the call" message is shown at the top via SessionStateMessages
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      color: Colors.orange.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Camera is off',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

