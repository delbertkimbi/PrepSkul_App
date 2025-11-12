import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/shimmer_loading.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userType;

  const ProfileScreen({Key? key, required this.userType}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userInfo;
  String? _profilePhotoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Get email from Supabase Auth (most reliable source)
      final authUser = SupabaseService.client.auth.currentUser;
      final authEmail = authUser?.email;

      // Load profile data from Supabase
      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select('avatar_url, full_name, email, phone_number')
          .eq('id', userId)
          .maybeSingle();

      // Load user-specific profile photo
      // For tutors, check tutor_profiles first, then fall back to profiles.avatar_url
      // For students/parents, use profiles.avatar_url
      String? photoUrl;
      if (widget.userType == 'tutor') {
        final tutorResponse = await SupabaseService.client
            .from('tutor_profiles')
            .select('profile_photo_url')
            .eq('user_id', userId)
            .maybeSingle();
        photoUrl = tutorResponse?['profile_photo_url']?.toString();
      }
      // For all users, also check avatar_url in profiles table
      if (photoUrl == null || photoUrl.isEmpty) {
        photoUrl = profileResponse?['avatar_url']?.toString();
      }

      // Get phone number from profile response (more reliable)
      final phoneNumber =
          profileResponse?['phone_number']?.toString() ??
          user['phone']?.toString() ??
          'Not set';

      // Get email with priority: Auth email > profiles.email > 'Not set'
      final email =
          authEmail ?? profileResponse?['email']?.toString() ?? 'Not set';

      // Get full name from database (most up-to-date)
      final fullName =
          profileResponse?['full_name']?.toString() ??
          user['fullName']?.toString() ??
          'User';

      setState(() {
        _userInfo = {
          ...user,
          'phone': phoneNumber, // Use phone from database
          'email': email, // Use email from auth or database
          'fullName': fullName, // Use name from database (most up-to-date)
        };
        _profilePhotoUrl =
            photoUrl ?? profileResponse?['avatar_url']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: AppTheme.primaryColor, // Deep blue
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? ShimmerLoading.profileScreen()
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Hero Section with Deep Blue Background extending to AppBar
                  Container(
                    width: double.infinity,
                    color: AppTheme.primaryColor, // Deep blue
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            // Profile Photo Section
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EditProfileScreen(
                                      userType: widget.userType,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _loadUserInfo();
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                    radius: 50,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                      backgroundImage:
                                          _profilePhotoUrl != null &&
                                              _profilePhotoUrl!.isNotEmpty
                                          ? NetworkImage(_profilePhotoUrl!)
                                          : null,
                                      child:
                                          _profilePhotoUrl == null ||
                                              _profilePhotoUrl!.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              size: 47,
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.primaryColor,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                    child: Icon(
                                        Icons.camera_alt,
                      color: AppTheme.primaryColor,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Name (Full name) - Less bold
                  Text(
                              _userInfo?['fullName']?.toString() ?? 'User',
                    style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w600, // Reduced from w700
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                    ),
                    child: Text(
                      widget.userType.toUpperCase(),
                      style: GoogleFonts.poppins(
                                  fontSize: 11,
                        fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Quick Info Cards (Neumorphic style)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoCard(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _userInfo?['email']?.toString() ?? 'Not set',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNeumorphicInfoCard(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: _formatPhoneNumber(
                              _userInfo?['phone']?.toString() ?? 'Not set',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Settings Section (Neumorphic style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildNeumorphicSection(
                      title: 'Settings',
                      icon: Icons.settings_outlined,
                      child: Column(
                        children: [
                          _buildNeumorphicSettingsItem(
                          icon: Icons.edit_outlined,
                          title: 'Edit Profile',
                            subtitle: 'Update your profile information',
                            onTap: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(
                                    userType: widget.userType,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadUserInfo();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildNeumorphicSettingsItem(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                            subtitle: 'Manage notification preferences',
                          onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed('/notifications/preferences');
                          },
                        ),
                          const SizedBox(height: 12),
                          _buildNeumorphicSettingsItem(
                          icon: Icons.language_outlined,
                          title: 'Language',
                            subtitle: 'Change app language',
                          onTap: () {
                            // TODO: Navigate to language settings
                          },
                        ),
                          const SizedBox(height: 12),
                          _buildNeumorphicSettingsItem(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                            subtitle: 'Get help and contact support',
                          onTap: () {
                            // TODO: Navigate to help
                          },
                        ),
                      ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button (Neumorphic style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.7),
                            blurRadius: 10,
                            offset: const Offset(-4, -4),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(4, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: _handleLogout,
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                                fontSize: 15,
                            fontWeight: FontWeight.w600,
                                color: Colors.red,
                          ),
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildNeumorphicInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(-3, -3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.length > 15 ? '${value.substring(0, 15)}...' : value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(-3, -3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildNeumorphicSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
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
                  color: AppTheme.textDark,
                ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  /// Format phone number to avoid duplicate country code
  /// Handles: +237+237..., 237237..., +237..., 237..., 0..., or 9 digits
  String _formatPhoneNumber(String phone) {
    if (phone == 'Not set' || phone.isEmpty) return phone;

    // Remove all spaces and special characters except +
    String cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Remove ALL instances of +237 (including duplicates)
    cleaned = cleaned.replaceAll('+237', '');
    cleaned = cleaned.replaceAll('237', '');

    // If it starts with 0, remove it
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Extract only digits (should be 9 digits for Cameroon)
    cleaned = cleaned.replaceAll(RegExp(r'[^\d]'), '');

    // If we have 9 digits, format as +237 + 9 digits
    if (cleaned.length == 9) {
      return '+237$cleaned';
    }
    // If we have more than 9 digits, take first 9
    else if (cleaned.length > 9) {
      return '+237${cleaned.substring(0, 9)}';
    }
    // If we have less than 9, return as is (might be incomplete)
    else if (cleaned.isNotEmpty) {
      return '+237$cleaned';
    }

    // Fallback: return original if we can't parse it
    return phone;
  }
}
