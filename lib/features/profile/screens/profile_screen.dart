import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart' hide LogService;
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/tutor_onboarding_progress_service.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/utils/status_bar_utils.dart';
import 'edit_profile_screen.dart';
import 'language_settings_screen.dart';
import 'profile_preview_screen.dart';
import '../../tutor/screens/tutor_onboarding_screen.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../../notifications/screens/notification_preferences_screen.dart';
import '../../support/screens/help_support_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final String userType;

  const ProfileScreen({Key? key, required this.userType}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _tutorProfile;
  String? _profilePhotoUrl;
  bool _isLoading = true;
  Map<String, dynamic>? _surveyData;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh profile data when screen becomes visible again
    // This ensures saved phone and profile picture are displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUserInfo();
      }
    });
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
        LogService.warning('Profile not found for user $userId, attempting to create...');
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

          LogService.success('Profile created for user: $userId');
        } catch (e) {
          LogService.warning('Error creating profile: $e');
          // Continue with fallback values
        }
      }

      // Load user-specific profile photo and full tutor profile
      // For tutors, check tutor_profiles first, then fall back to profiles.avatar_url
      // For students/parents, use profiles.avatar_url
      String? photoUrl;
      Map<String, dynamic>? tutorProfileData;
      if (widget.userType == 'tutor') {
        tutorProfileData = await SupabaseService.client
            .from('tutor_profiles')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        photoUrl = tutorProfileData?['profile_photo_url']?.toString();
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

      // Get email with priority: Auth email > profiles.email > stored signup email > onboarding progress > 'Not set'
      final prefs = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString('signup_email');
      
      // Check if email exists in auth but not in profiles - sync it if needed
      String? email = authEmail ??
          profileResponse?['email']?.toString() ??
          storedEmail;
      
      // Also check auth user metadata for email (some signup flows store it there)
      final metadataEmail = authUser?.userMetadata?['email']?.toString();
      if (email == null && metadataEmail != null && metadataEmail.isNotEmpty) {
        email = metadataEmail;
      }
      
      // For tutors, also check onboarding progress for email (in case it was collected but not synced)
      if (widget.userType == 'tutor' && (email == null || email.isEmpty || email == 'Not set')) {
        try {
          final onboardingProgress = await TutorOnboardingProgressService.loadProgress(userId);
          if (onboardingProgress != null) {
            final step0Data = onboardingProgress['step_0'] as Map<String, dynamic>?;
            final onboardingEmail = step0Data?['email']?.toString();
            if (onboardingEmail != null && onboardingEmail.isNotEmpty && onboardingEmail.contains('@')) {
              email = onboardingEmail;
              LogService.debug('Found email in onboarding progress: $email');
            }
          }
        } catch (e) {
          LogService.debug('Error checking onboarding progress for email: $e');
        }
      }
      
      // If we have email from any source but profiles table doesn't have it, update profiles
      final currentProfileEmail = profileResponse?['email']?.toString();
      final needsEmailSync = email != null && 
          email.isNotEmpty && 
          email != 'Not set' && 
          email.contains('@') &&
          (currentProfileEmail == null || 
           currentProfileEmail.isEmpty ||
           currentProfileEmail == 'Not set');
      
      if (needsEmailSync) {
        try {
          await SupabaseService.client
              .from('profiles')
              .update({'email': email})
              .eq('id', userId);
          LogService.success('Synced email to profiles table: $email');
          // Reload profile response to get updated email
          profileResponse = await SupabaseService.client
              .from('profiles')
              .select('avatar_url, full_name, email, phone_number')
              .eq('id', userId)
              .maybeSingle();
          // Use the synced email
          email = profileResponse?['email']?.toString() ?? email;
        } catch (e) {
          LogService.warning('Error syncing email to profiles: $e');
        }
      }
      
      // Final fallback
      email = email ?? 'Not set';

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
        LogService.warning('Error loading survey data: $surveyError');
        LogService.warning('Stack trace: $stackTrace');
        // Continue without survey data - don't block profile display
        surveyData = null;
      }

      if (!mounted) return;

      safeSetState(() {
        _userInfo = {
          ...user,
          'phone': phoneNumber, // Use phone from database
          'email': email, // Use email from auth or database
          'fullName': fullName, // Use name from database (most up-to-date)
        };
        _tutorProfile = tutorProfileData;
        _profilePhotoUrl =
            photoUrl ?? profileResponse?['avatar_url']?.toString();
        _surveyData = surveyData;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      LogService.error('Error loading profile: $e');
      LogService.error('Stack trace: $stackTrace');
      if (!mounted) return;

      safeSetState(() {
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
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t.profileLogout,
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
            child: Text(t.profileLogout, style: GoogleFonts.poppins()),
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
    final t = AppLocalizations.of(context)!;
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          automaticallyImplyLeading: false, // No back button in bottom nav
          backgroundColor: AppTheme.primaryColor, // Deep blue
          elevation: 0,
          title: Text(
            t.profileTitle,
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
                          vertical: 16,
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
                                      radius: 42,
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
                                              PhosphorIcons.user(),
                                              size: 40,
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
                                      padding: const EdgeInsets.all(5),
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
                                        PhosphorIcons.camera(),
                                        color: AppTheme.primaryColor,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Name (Full name) - Less bold
                            Text(
                              _userInfo?['fullName']?.toString() ?? 'User',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Role Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                widget.userType.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
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
                            icon: PhosphorIcons.envelope(),
                            label: 'Email',
                            value: _userInfo?['email']?.toString() ?? 'Not set',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNeumorphicInfoCard(
                            icon: PhosphorIcons.phone(),
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

                  
                  // Survey Completion Card (if not completed)
                  if ((widget.userType == 'student' || 
                       widget.userType == 'learner' || 
                       widget.userType == 'parent') && 
                      (_surveyData == null || 
                       (_userInfo?['surveyCompleted'] != true))) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSurveyCompletionCard(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Personal Information Section (from survey)
                  // Learning information card removed temporarily

                  // Settings Section (Neumorphic style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildNeumorphicSection(
                      title: t.profileSettings,
                      icon: PhosphorIcons.gear(),
                      child: Column(
                        children: [
                          _buildNeumorphicSettingsItem(
                            icon: PhosphorIcons.pencil(),
                            title: t.profileEditProfile,
                            subtitle: t.profileEditProfileSubtitle,
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
                          
                          if (widget.userType == 'tutor') ...[
                            _buildNeumorphicSettingsItem(
                              icon: PhosphorIcons.graduationCap(),
                              title: t.profileEditTutorInfo,
                              subtitle: t.profileEditTutorInfoSubtitle,
                              onTap: () async {
                                // Fetch complete tutor profile data before navigating
                                Map<String, dynamic>? tutorProfileData;
                                try {
                                  final user = await AuthService.getCurrentUser();
                                  final userId = user['userId'] as String;
                                  final tutorResponse = await SupabaseService.client
                                      .from('tutor_profiles')
                                      .select('*')
                                      .eq('user_id', userId)
                                      .maybeSingle();
                                  tutorProfileData = tutorResponse;
                                } catch (e) {
                                  LogService.warning('Error fetching tutor profile: $e');
                                }
                                
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => TutorOnboardingScreen(
                                      basicInfo: {
                                        'needsImprovement': true,
                                        'existingData': tutorProfileData ?? {},
                                      },
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
                              icon: PhosphorIcons.eye(),
                              title: t.profilePreviewProfile,
                              subtitle: t.profilePreviewProfileSubtitle,
                              onTap: () {
                                if (_tutorProfile != null) {
                                  // Merge basic info with tutor profile to ensure completeness
                                  final mergedProfile = Map<String, dynamic>.from(_tutorProfile!);
                                  if (mergedProfile['full_name'] == null) {
                                    mergedProfile['full_name'] = _userInfo?['fullName'];
                                  }
                                  // Ensure verified status is visual
                                  if (mergedProfile['status'] == 'verified' || mergedProfile['status'] == 'approved') {
                                     mergedProfile['is_verified'] = true;
                                  }
                                  
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ProfilePreviewScreen(
                                        tutor: mergedProfile,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tutor profile not loaded yet')),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildNeumorphicSettingsItem(
                            icon: PhosphorIcons.bell(),
                            title: t.profileNotifications,
                            subtitle: t.profileNotificationsSubtitle,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const NotificationPreferencesScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildNeumorphicSettingsItem(
                            icon: PhosphorIcons.translate(),
                            title: t.profileLanguage,
                            subtitle: t.profileLanguageSubtitle,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LanguageSettingsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildNeumorphicSettingsItem(
                            icon: PhosphorIcons.question(),
                            title: t.profileHelpSupport,
                            subtitle: t.profileHelpSupportSubtitle,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HelpSupportScreen(),
                                ),
                              );
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
                            Icon(PhosphorIcons.signOut(), color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              t.profileLogout,
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
      ),
    );
  }

  Widget _buildNeumorphicInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.length > 15 ? '${value.substring(0, 15)}...' : value,
            style: GoogleFonts.poppins(
              fontSize: 13,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  letterSpacing: -0.3,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppTheme.primaryColor.withOpacity(0.1),
        highlightColor: AppTheme.primaryColor.withOpacity(0.05),
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
              Icon(PhosphorIcons.caretRight(), color: AppTheme.textLight, size: 20),
            ],
          ),
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
          try {
            // Try parsing as JSON first
            final decoded = jsonDecode(goalsData);
            if (decoded is List) {
              learningGoals = decoded;
            } else {
              // Fallback to comma-separated if not a JSON list
              learningGoals = goalsData.split(',').map((s) => s.trim()).toList();
            }
          } catch (e) {
            // Fallback to comma-separated string if JSON parsing fails
            learningGoals = goalsData.split(',').map((s) => s.trim()).toList();
          }
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    PhosphorIcons.trendUp(),
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Learning Path',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              learningPath,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Subjects & Skills Group
          if ((subjects != null && subjects.isNotEmpty) || 
              (skills != null && skills.isNotEmpty)) ...[
          // Subjects
          if (subjects != null && subjects.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      PhosphorIcons.bookOpen(),
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
            Text(
              'Subjects',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
                      letterSpacing: 0.2,
              ),
            ),
                ],
              ),
              const SizedBox(height: 6),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subjects.map((s) {
                return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                    ),
                  ),
                  child: Text(
                      s.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                        color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
              const SizedBox(height: 10),
          ],

          // Skills
          if (skills != null && skills.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      PhosphorIcons.star(),
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
            Text(
              'Skills',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
                      letterSpacing: 0.2,
              ),
            ),
                ],
              ),
              const SizedBox(height: 6),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.map((s) {
                return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                  ),
                  child: Text(
                      s.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                        color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
              const SizedBox(height: 12),
            ],
          ],

          // Learning Goals - 2 columns
          if (learningGoals != null && learningGoals.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    PhosphorIcons.flag(),
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
            Text(
              'Learning Goals',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
                const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final List<dynamic> goalsList = learningGoals ?? [];
                if (goalsList.isEmpty) return const SizedBox.shrink();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 6,
                    childAspectRatio: 3.5,
                  ),
                  itemCount: goalsList.length,
                  itemBuilder: (context, index) {
                    final goal = goalsList[index];
              String goalText;
              if (goal is String) {
                goalText = goal;
              } else if (goal is List) {
                goalText = goal.map((item) => item.toString()).join(', ');
              } else {
                goalText = goal.toString().replaceAll(RegExp(r'[\[\]]'), '');
              }
              goalText = goalText.trim();
              if (goalText.startsWith('[') && goalText.endsWith(']')) {
                goalText = goalText.substring(1, goalText.length - 1);
              }
                    return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                          margin: const EdgeInsets.only(top: 4, right: 6),
                          width: 4,
                          height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        goalText,
                        style: GoogleFonts.poppins(
                              fontSize: 12,
                          color: AppTheme.textDark,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                        ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 4),
          ],

          // Learning Styles
          if (learningStyles != null && learningStyles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    PhosphorIcons.brain(),
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
            Text(
              'Learning Styles',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
                    letterSpacing: 0.2,
              ),
            ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: learningStyles.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    s.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Empty state
          if ((learningPath == null || learningPath.isEmpty) &&
              (subjects == null || subjects.isEmpty) &&
              (skills == null || skills.isEmpty) &&
              (learningGoals == null || learningGoals.isEmpty) &&
              (learningStyles == null || learningStyles.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 48,
                      color: AppTheme.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                'Complete your onboarding survey to see your learning information here.',
                      textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                        fontSize: 13,
                  color: AppTheme.textMedium,
                ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } catch (e, stackTrace) {
      // Handle any type casting errors gracefully
      LogService.error('Error building learning info section: $e');
      LogService.error('Stack trace: $stackTrace');
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

  Widget _buildSurveyCompletionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Your Profile Survey',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help us understand your needs so we can match you with the best tutors.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/profile-setup',
                  arguments: {'userRole': widget.userType},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Complete Survey',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a professional learning info item with icon, label, and content
  Widget _buildLearningInfoItem({
    required IconData icon,
    required String label,
    String? value,
    List<String>? chips,
    List<String>? goals,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon and label
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Content
        if (value != null)
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          )
        else if (chips != null && chips.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  chip,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          )
        else if (goals != null && goals.isNotEmpty)
          ...goals.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textDark,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

}

