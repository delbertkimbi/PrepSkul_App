import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';

class BeautifulSignupScreen extends StatefulWidget {
  const BeautifulSignupScreen({Key? key}) : super(key: key);

  @override
  State<BeautifulSignupScreen> createState() => _BeautifulSignupScreenState();
}

class _BeautifulSignupScreenState extends State<BeautifulSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
                  padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          'Sign up',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Subtitle
                      Center(
                        child: Text(
                          'Join us to start your learning journey',
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

                // Form content - below the wave
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name Field
                              Text(
                                'Full Name',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _nameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter your name',
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppTheme.textLight,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.softCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Phone Number Field
                              Text(
                                'Phone Number (WhatsApp Number)',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  // Country code
                                  Container(
                                    width: 80,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppTheme.softBackground,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppTheme.softBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+237',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Phone number input
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter phone number';
                                        }
                                        if (value.trim().length < 9) {
                                          return 'Phone number must be 9 digits';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: '6 53 30 19 97',
                                        hintStyle: GoogleFonts.poppins(
                                          color: AppTheme.textLight,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.softCard,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.softBorder,
                                            width: 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.softBorder,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 15),

                              // Password Field
                              Text(
                                'Password (at least 6 character long)',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter Password',
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppTheme.textLight,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.softCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppTheme.textMedium,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Confirm Password Field
                              Text(
                                'Confirm password',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Confirm Password',
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppTheme.textLight,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.softCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    child: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppTheme.textMedium,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Role Selection
                              Text(
                                'I am a...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildRoleChip(
                                    'Student',
                                    'student',
                                    Icons.school,
                                  ),
                                  _buildRoleChip(
                                    'Parent',
                                    'parent',
                                    Icons.family_restroom,
                                  ),
                                  _buildRoleChip(
                                    'Tutor',
                                    'tutor',
                                    Icons.person,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 27),

                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: AppTheme.primaryColor
                                        .withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Sign up',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Already have account link
                              Center(
                                child: Row(
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
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/beautiful-login',
                                        );
                                      },
                                      child: Text(
                                        'Log in',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
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

  Future<void> _handleSignup() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if role is selected
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select your role',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Format phone number (ensure it starts with +237 for Cameroon)
    String phoneNumber = _phoneController.text.trim();
    if (!phoneNumber.startsWith('+')) {
      if (phoneNumber.startsWith('237')) {
        phoneNumber = '+$phoneNumber';
      } else if (phoneNumber.startsWith('0')) {
        phoneNumber = '+237${phoneNumber.substring(1)}';
      } else {
        phoneNumber = '+237$phoneNumber';
      }
    }

    setState(() => _isLoading = true);

    try {
      // Send OTP via Supabase
      await SupabaseService.sendPhoneOTP(phoneNumber);

      // Navigate to OTP verification screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phoneNumber: phoneNumber,
              fullName: _nameController.text.trim(),
              userRole: _selectedRole!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send verification code. Please check your phone number.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRoleChip(String label, String value, IconData icon) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.softCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textMedium,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// Custom wave clipper for the header - Clean and professional
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    // Start from top-left corner
    path.lineTo(0, size.height - 50); // Straight down left side

    // Create smooth, gentle wave curve
    var controlPoint1 = Offset(size.width * 0.25, size.height - 30);
    var endPoint1 = Offset(size.width * 0.5, size.height - 40);

    path.quadraticBezierTo(
      controlPoint1.dx,
      controlPoint1.dy,
      endPoint1.dx,
      endPoint1.dy,
    );

    var controlPoint2 = Offset(size.width * 0.75, size.height - 50);
    var endPoint2 = Offset(size.width, size.height - 40);

    path.quadraticBezierTo(
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint2.dx,
      endPoint2.dy,
    );

    // Complete the path
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
