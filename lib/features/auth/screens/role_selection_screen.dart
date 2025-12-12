import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Curved wave background at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header content inside the wave
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Who are you?',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Select your role to continue',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content below wave
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 50),
                        
                        _buildRoleCard(
                          title: 'Student',
                          description: 'I want to learn and find tutors.',
                          icon: Icons.school_outlined,
                          value: 'student',
                        ),
                        const SizedBox(height: 16),
                        
                        _buildRoleCard(
                          title: 'Parent',
                          description: 'I want to find tutors for my child.',
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

                        const SizedBox(height: 40),

                        // Continue Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _selectedRole == null || _isLoading 
                                ? null 
                                : _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              disabledBackgroundColor: AppTheme.softBorder,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
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
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
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
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textLight,
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
      if (user != null) {
        // Update profile with selected role
        await SupabaseService.client.from('profiles').upsert({
          'id': user.id,
          'user_type': _selectedRole,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        // Update local session
        await AuthService.saveSession(
          userId: user.id,
          userRole: _selectedRole!,
          phone: '', // Retain existing or empty
          fullName: user.userMetadata?['full_name']?.toString() ?? 'User',
          surveyCompleted: false,
        );

        if (mounted) {
          // Navigate to profile setup (which will show the correct survey based on role)
          final navService = NavigationService();
          if (navService.isReady) {
            // Check if intro seen
            if (_selectedRole == 'tutor') {
               navService.navigateToRoute(
                '/tutor-onboarding-choice', // Or direct to onboarding
                replace: true,
              );
            } else {
               navService.navigateToRoute(
                '/survey-intro',
                arguments: {'userType': _selectedRole},
                replace: true,
              );
            }
          }
        }
      }
    } catch (e) {
      LogService.debug('Error updating role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role. Please try again.'),
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

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.85);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height * 0.85,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.85,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}















