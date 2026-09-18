import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/profile_bootstrap_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _redirectReturningUserIfNeeded();
  }

  /// Returning users can land here after an offline nav glitch — send them back.
  Future<void> _redirectReturningUserIfNeeded() async {
    try {
      if (!SupabaseService.isAuthenticated) return;
      final role = await AuthService.getUserRole();
      if (role == null || role.trim().isEmpty) return;

      final navService = NavigationService();
      if (!navService.isReady) return;

      final result = await navService.determineInitialRoute();
      if (result.route == '/role-selection' || !mounted) return;

      LogService.info(
        '[ROLE_SELECTION] Existing role ($role) — routing to ${result.route}',
      );
      await navService.navigateToRoute(
        result.route,
        arguments: result.arguments,
        clearStack: true,
      );
    } catch (e) {
      LogService.debug('[ROLE_SELECTION] Skip auto-redirect: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
      backgroundColor: OnboardPalette.cream,
      body: Stack(
        children: [
          // Curved wave background at top
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                const AuthPaperHeader(
                  title: 'Who are you?',
                  subtitle: 'Parents count as students too.',
                ),

                // Content below wave
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        
                        _buildRoleCard(
                          title: 'Student',
                          description: 'I want Mate to tutor me, and a person when I ask.',
                          icon: Icons.school_outlined,
                          value: 'student',
                        ),
                        const SizedBox(height: 16),
                        
                        _buildRoleCard(
                          title: 'Parent',
                          description: 'I’m studying too. Mate tutors me, and I can request a person.',
                          icon: Icons.family_restroom_outlined,
                          value: 'parent',
                        ),
                        const SizedBox(height: 16),
                        
                        _buildRoleCard(
                          title: 'Tutor',
                          description: 'I want to teach and earn money.',
                          icon: Icons.person_outline,
                          value: 'tutor',
                        ),

                        const SizedBox(height: 12),

                        // Continue Button
                        OnboardPrimaryButton(
                          label: 'Continue',
                          enabled: _selectedRole != null,
                          busy: _isLoading,
                          onTap: _handleContinue,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedRole == value;
    
    return GestureDetector(
      onTap: () => safeSetState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: OnboardPalette.card(selected: isSelected),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : AppTheme.softBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textMedium,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: onboardFont(
                      size: 16,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: onboardFont(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_selectedRole == null) return;

    safeSetState(() => _isLoading = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('Your session expired. Please sign in again.');
      }

      final prefs = await SharedPreferences.getInstance();
      final fullName = prefs.getString('signup_full_name') ??
          user.userMetadata?['full_name']?.toString() ??
          'User';
      final email = user.email ?? prefs.getString('signup_email') ?? '';

      await ProfileBootstrapService.upsertProfile(
        userId: user.id,
        fullName: fullName,
        email: email,
        phoneNumber: null,
        userType: _selectedRole,
        surveyCompleted: false,
      );

      await AuthService.saveSession(
        userId: user.id,
        userRole: _selectedRole!,
        phone: '',
        fullName: fullName,
        surveyCompleted: false,
      );

      if (mounted) {
        final navService = NavigationService();
        if (navService.isReady) {
          if (_selectedRole == 'tutor') {
            await navService.navigateToRoute(
              '/tutor-onboarding-choice',
              replace: true,
            );
          } else {
            await navService.navigateToRoute(
              '/survey-intro',
              arguments: {'userType': _selectedRole},
              replace: true,
            );
          }
        }
      }
    } catch (e) {
      LogService.error('Error updating role: $e');
      if (mounted) {
        final message = AuthService.parseAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.contains('incorrect') || message.contains('session')
                  ? message
                  : 'Failed to update role. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }
}




