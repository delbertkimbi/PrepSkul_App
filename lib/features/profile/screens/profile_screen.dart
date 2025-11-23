import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
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
  Map<String, dynamic>? _surveyData;

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
      var profileResponse = await SupabaseService.client
          .from('profiles')
          .select('avatar_url, full_name, email, phone_number')
          .eq('id', userId)
          .maybeSingle();

      // If profile doesn't exist, try to create it from stored signup data or auth user
      if (profileResponse == null) {
        print('⚠️ Profile not found for user $userId, attempting to create...');
        try {
          // Get stored signup data as fallback
          final prefs = await SharedPreferences.getInstance();
          final storedName = prefs.getString('signup_full_name');
          final storedEmail = prefs.getString('signup_email');

          // Determine the best name to use (avoid 'User' or 'Student' defaults)
          String? nameToUse;
          if (storedName != null &&
              storedName.isNotEmpty &&
              storedName != 'User' &&
              storedName != 'Student') {
            nameToUse = storedName;
          } else if (user['fullName'] != null) {
            final sessionName = user['fullName']?.toString() ?? '';
            if (sessionName.isNotEmpty &&
                sessionName != 'User' &&
                sessionName != 'Student') {
              nameToUse = sessionName;
            }
          } else if (authUser?.userMetadata?['full_name'] != null) {
            final metadataName =
                authUser!.userMetadata!['full_name']?.toString() ?? '';
            if (metadataName.isNotEmpty &&
                metadataName != 'User' &&
                metadataName != 'Student') {
              nameToUse = metadataName;
            }
          } else if (authEmail != null) {
            // Extract name from email as last resort
            final emailName = authEmail.split('@')[0];
            if (emailName.isNotEmpty &&
                emailName != 'user' &&
                emailName != 'student') {
              nameToUse = emailName
                  .split('.')
                  .map(
                    (s) => s.isNotEmpty && s.length > 1
                        ? s[0].toUpperCase() + s.substring(1)
                        : s.toUpperCase(),
                  )
                  .where((s) => s.isNotEmpty)
                  .join(' ');
            }
          }

          // Create profile using stored data or auth user data
          await SupabaseService.client.from('profiles').upsert({
            'id': userId,
            'email': storedEmail ?? authEmail ?? '',
            'full_name': nameToUse ?? '', // Use empty string instead of 'User'
            'phone_number': user['phone'],
            'user_type': widget.userType,
            'avatar_url': null,
            'survey_completed': false,
            'is_admin': false,
          }, onConflict: 'id');

          // Fetch the created profile
          profileResponse = await SupabaseService.client
              .from('profiles')
              .select('avatar_url, full_name, email, phone_number')
              .eq('id', userId)
              .maybeSingle();

          print('✅ Profile created for user: $userId');
        } catch (e) {
          print('⚠️ Error creating profile: $e');
          // Continue with fallback values
        }
      }

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

      // Get email with priority: Auth email > profiles.email > stored signup email > 'Not set'
      final prefs = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString('signup_email');
      final email =
          authEmail ??
          profileResponse?['email']?.toString() ??
          storedEmail ??
          'Not set';

      // Get full name from database (most up-to-date)
      // Priority: profile > stored signup data > session > auth metadata > email extraction > empty
      final storedName = prefs.getString('signup_full_name');
      var fullName = profileResponse?['full_name'] != null
          ? profileResponse!['full_name'].toString()
          : null;

      // If name is invalid (empty, 'User', or 'Student'), try other sources
      if (fullName == null ||
          fullName.isEmpty ||
          fullName == 'User' ||
          fullName == 'Student') {
        if (storedName != null &&
            storedName.isNotEmpty &&
            storedName != 'User' &&
            storedName != 'Student') {
          fullName = storedName;
        }
      }
      if (fullName == null ||
          fullName.isEmpty ||
          fullName == 'User' ||
          fullName == 'Student') {
        final sessionName = user['fullName']?.toString();
        if (sessionName != null &&
            sessionName.isNotEmpty &&
            sessionName != 'User' &&
            sessionName != 'Student') {
          fullName = sessionName;
        }
      }
      if (fullName == null ||
          fullName.isEmpty ||
          fullName == 'User' ||
          fullName == 'Student') {
        final metadataName = authUser?.userMetadata?['full_name']?.toString();
        if (metadataName != null &&
            metadataName.isNotEmpty &&
            metadataName != 'User' &&
            metadataName != 'Student') {
          fullName = metadataName;
        }
      }
      if (fullName == null ||
          fullName.isEmpty ||
          fullName == 'User' ||
          fullName == 'Student') {
        // Extract name from email as last resort
        if (authEmail != null) {
          final emailName = authEmail.split('@')[0];
          if (emailName.isNotEmpty &&
              emailName != 'user' &&
              emailName != 'student') {
            fullName = emailName
                .split('.')
                .map(
                  (s) => s.isNotEmpty && s.length > 1
                      ? s[0].toUpperCase() + s.substring(1)
                      : s.toUpperCase(),
                )
                .where((s) => s.isNotEmpty)
                .join(' ');
          }
        }
      }

      // Final fallback: use empty string instead of 'User' or 'Student'
      if (fullName == null ||
          fullName.isEmpty ||
          fullName == 'User' ||
          fullName == 'Student') {
        fullName = widget.userType == 'student'
            ? 'Student'
            : widget.userType == 'parent'
            ? 'Parent'
            : widget.userType == 'tutor'
            ? 'Tutor'
            : 'User';
      }

      // Load survey data for students and parents
      Map<String, dynamic>? surveyData;
      try {
        if (widget.userType == 'student' || widget.userType == 'learner') {
          surveyData = await SurveyRepository.getStudentSurvey(userId);
        } else if (widget.userType == 'parent') {
          surveyData = await SurveyRepository.getParentSurvey(userId);
        }
      } catch (surveyError, stackTrace) {
        print('⚠️ Error loading survey data: $surveyError');
        print('⚠️ Stack trace: $stackTrace');
        // Continue without survey data - don't block profile display
        surveyData = null;
      }

      setState(() {
        _userInfo = {
          ...user,
          'phone': phoneNumber, // Use phone from database
          'email': email, // Use email from auth or database
          'fullName': fullName, // Use name from database (most up-to-date)
        };
        _profilePhotoUrl =
            photoUrl ?? profileResponse?['avatar_url']?.toString();
        _surveyData = surveyData;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading profile: $e');
      print('❌ Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        // Set safe defaults to prevent crashes
        _userInfo = {
          'fullName': widget.userType == 'student'
              ? 'Student'
              : widget.userType == 'parent'
              ? 'Parent'
              : widget.userType == 'tutor'
              ? 'Tutor'
              : 'User',
          'email': 'Not set',
          'phone': 'Not set',
          'avatarUrl': null,
        };
        _surveyData = null;
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
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/email-login', (route) => false);
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

                  // Personal Information Section (from survey)
                  if (_surveyData != null &&
                      (widget.userType == 'student' ||
                          widget.userType == 'learner' ||
                          widget.userType == 'parent')) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildNeumorphicSection(
                        title: 'Learning Information',
                        icon: Icons.school_outlined,
                        child: _buildLearningInfoSection(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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

  Widget _buildLearningInfoSection() {
    // Wrap in try-catch to prevent crashes from type casting errors
    try {
      final learningPath = _surveyData?['learning_path'] as String?;

      // Safely handle subjects - might be String or List
      List? subjects;
      if (_surveyData?['subjects'] != null) {
        final subjectsData = _surveyData!['subjects'];
        if (subjectsData is List) {
          subjects = subjectsData;
        } else if (subjectsData is String && subjectsData.isNotEmpty) {
          // Handle old data format (comma-separated string)
          subjects = subjectsData.split(',').map((s) => s.trim()).toList();
        }
      }

      // Safely handle skills - might be String or List
      List? skills;
      if (_surveyData?['skills'] != null) {
        final skillsData = _surveyData!['skills'];
        if (skillsData is List) {
          skills = skillsData;
        } else if (skillsData is String && skillsData.isNotEmpty) {
          // Handle old data format (comma-separated string)
          skills = skillsData.split(',').map((s) => s.trim()).toList();
        }
      }

      // Safely handle learning_goals - might be String or List
      List? learningGoals;
      if (_surveyData?['learning_goals'] != null) {
        final goalsData = _surveyData!['learning_goals'];
        if (goalsData is List) {
          learningGoals = goalsData;
        } else if (goalsData is String && goalsData.isNotEmpty) {
          // Handle old data format (comma-separated string)
          learningGoals = goalsData.split(',').map((s) => s.trim()).toList();
        }
      }

      // Safely handle learning_styles - might be String or List
      List? learningStyles;
      if (_surveyData?['learning_styles'] != null) {
        final stylesData = _surveyData!['learning_styles'];
        if (stylesData is List) {
          learningStyles = stylesData;
        } else if (stylesData is String && stylesData.isNotEmpty) {
          // Handle old data format (comma-separated string)
          learningStyles = stylesData.split(',').map((s) => s.trim()).toList();
        }
      }

      // Also check for old learning_style (singular) field and migrate
      if (learningStyles == null && _surveyData?['learning_style'] != null) {
        final styleData = _surveyData!['learning_style'];
        if (styleData is String && styleData.isNotEmpty) {
          learningStyles = [styleData];
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Learning Path
          if (learningPath != null && learningPath.isNotEmpty) ...[
            _buildInfoRow(label: 'Learning Path', value: learningPath),
            const SizedBox(height: 16),
          ],

          // Subjects
          if (subjects != null && subjects.isNotEmpty) ...[
            Text(
              'Subjects',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((subject) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    subject.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Skills
          if (skills != null && skills.isNotEmpty) ...[
            Text(
              'Skills',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    skill.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Learning Goals
          if (learningGoals != null && learningGoals.isNotEmpty) ...[
            Text(
              'Learning Goals',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...learningGoals.map((goal) {
              // Safely extract goal text - handle both String and List cases
              String goalText;
              if (goal is String) {
                goalText = goal;
              } else if (goal is List) {
                // If goal is a list, join it without brackets
                goalText = goal.map((item) => item.toString()).join(', ');
              } else {
                // Convert to string and clean up any bracket formatting
                goalText = goal.toString().replaceAll(RegExp(r'[\[\]]'), '');
              }

              // Clean up any remaining bracket artifacts
              goalText = goalText.trim();
              if (goalText.startsWith('[') && goalText.endsWith(']')) {
                goalText = goalText.substring(1, goalText.length - 1);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        goalText,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textDark,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],

          // Learning Styles
          if (learningStyles != null && learningStyles.isNotEmpty) ...[
            Text(
              'Learning Styles',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: learningStyles.map((style) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Text(
                    style.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Empty state
          if ((learningPath == null || learningPath.isEmpty) &&
              (subjects == null || subjects.isEmpty) &&
              (skills == null || skills.isEmpty) &&
              (learningGoals == null || learningGoals.isEmpty) &&
              (learningStyles == null || learningStyles.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Complete your onboarding survey to see your learning information here.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    } catch (e, stackTrace) {
      // Handle any type casting errors gracefully
      print('❌ Error building learning info section: $e');
      print('❌ Stack trace: $stackTrace');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Unable to load learning information. Please try again later.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textMedium,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  Widget _buildInfoRow({
    IconData? icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
