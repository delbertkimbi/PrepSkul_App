import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beautiful_login_screen.dart';
import 'email_signup_screen.dart';

class AuthMethodSelectionScreen extends StatelessWidget {
  const AuthMethodSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo/Title
              Text(
                'Sign up to see all our tutors',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Get instant access to 40,000+ profiles',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Auth Method Buttons
              _AuthMethodButton(
                icon: Icons.email_outlined,
                label: 'Sign up with email',
                onTap: () async {
                  // Save auth method choice
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('auth_method', 'email');

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailSignupScreen(),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),

              _AuthMethodButton(
                icon: Icons.phone_outlined,
                label: 'Sign up with phone',
                onTap: () async {
                  // Save auth method choice
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('auth_method', 'phone');

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BeautifulLoginScreen(),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // Already have account?
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BeautifulLoginScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Terms
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'By signing up, you agree to PrepSkul\'s Terms of Service and Privacy Policy',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthMethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AuthMethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppTheme.softBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppTheme.textDark),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
