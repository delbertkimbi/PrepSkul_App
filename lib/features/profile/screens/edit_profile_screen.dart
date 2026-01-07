import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart' hide LogService;
import '../../../core/services/supabase_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/image_picker_bottom_sheet.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/branded_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

/// Edit Profile Screen
/// 
/// Allows users (tutors, students, parents) to edit:
/// - Profile picture
/// - Phone number
/// - Email (if allowed)
/// - Basic info (name, city, quarter)
class EditProfileScreen extends StatefulWidget {
  final String userType; // 'tutor', 'student', 'parent'

  const EditProfileScreen({Key? key, required this.userType}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  String? _selectedCity;
  String? _selectedQuarter;
  String? _profilePhotoUrl;
  String? _uploadedProfilePhotoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    safeSetState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Load from profiles table
      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      // Load user-specific profile data
      if (widget.userType == 'tutor') {
        final tutorResponse = await SupabaseService.client
            .from('tutor_profiles')
            .select('profile_photo_url, city, quarter')
            .eq('user_id', userId)
            .maybeSingle();
        _profileData = tutorResponse;
      }

      // Format phone number to remove duplicates
      final rawPhone = profileResponse?['phone_number']?.toString() ?? '';
      final formattedPhone = _formatPhoneNumber(rawPhone);

      safeSetState(() {
        _nameController.text = profileResponse?['full_name']?.toString() ?? '';
        _phoneController.text = formattedPhone;
        _emailController.text = profileResponse?['email']?.toString() ?? '';
        _selectedCity = _profileData?['city']?.toString();
        _selectedQuarter = _profileData?['quarter']?.toString();
        _profilePhotoUrl = _profileData?['profile_photo_url']?.toString() ?? 
            profileResponse?['avatar_url']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading profile: $e');
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      // ImagePickerBottomSheet returns XFile or PlatformFile directly
      final pickedFile = await showModalBottomSheet<dynamic>(
        context: context,
        builder: (context) => ImagePickerBottomSheet(),
        isScrollControlled: true,
      );

      if (pickedFile == null || !mounted) return;

      // Wait for the next frame to ensure bottom sheet is fully closed
      await SchedulerBinding.instance.endOfFrame;

      if (!mounted) return;

      // StorageService.uploadDocument can handle XFile, PlatformFile, or File
      // So we can pass the picked file directly
      dynamic fileToUpload;
      if (pickedFile is XFile) {
        fileToUpload = pickedFile;
      } else if (pickedFile is PlatformFile) {
        // StorageService handles PlatformFile directly (works on web and mobile)
        fileToUpload = pickedFile;
      } else {
        return; // Unknown type
      }

      // Show loading
      if (!mounted) return;
      BrandedSnackBar.showLoading(context, 'Uploading profile photo...');

      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Upload to Supabase Storage
      final uploadedUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: fileToUpload,
        documentType: 'profile_picture',
      );

      // Add cache-busting parameter to ensure image refreshes
      final cacheBustUrl = uploadedUrl.contains('?')
          ? '$uploadedUrl&t=${DateTime.now().millisecondsSinceEpoch}'
          : '$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;
      
      safeSetState(() {
        _uploadedProfilePhotoUrl = uploadedUrl;
        _profilePhotoUrl = cacheBustUrl; // Use cache-busted URL for immediate display
      });

      // Wait for the next frame to ensure state update is complete
      await SchedulerBinding.instance.endOfFrame;
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      BrandedSnackBar.showSuccess(context, 'Profile photo uploaded successfully!');
    } catch (e) {
      LogService.error('Error uploading profile photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      BrandedSnackBar.showError(context, 'Error uploading photo: ${e.toString()}');
    }
  }

  bool _isValidEmail(String email) {
    // Allow common email formats (including '+') and require at least 2 characters for TLD
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    safeSetState(() => _isSaving = true);

    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Format phone number before saving to prevent duplicates
      final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

      // Update profiles table
      final profileUpdates = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone_number': formattedPhone,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update email if changed (only if email auth)
      if (_emailController.text.trim().isNotEmpty) {
        profileUpdates['email'] = _emailController.text.trim();
      }

      await SupabaseService.client
          .from('profiles')
          .update(profileUpdates)
          .eq('id', userId);

      // Update user-specific profile data
      if (widget.userType == 'tutor') {
        final tutorUpdates = <String, dynamic>{
          'city': _selectedCity,
          'quarter': _selectedQuarter,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (_uploadedProfilePhotoUrl != null) {
          tutorUpdates['profile_photo_url'] = _uploadedProfilePhotoUrl;
        }

        await SupabaseService.client
            .from('tutor_profiles')
            .update(tutorUpdates)
            .eq('user_id', userId);
      }

      // Update avatar_url in profiles if profile photo uploaded
      if (_uploadedProfilePhotoUrl != null) {
        await SupabaseService.client
            .from('profiles')
            .update({'avatar_url': _uploadedProfilePhotoUrl})
            .eq('id', userId);
      }

      if (!mounted) return;
      BrandedSnackBar.showSuccess(context, 'Profile updated successfully!');

      // Navigate back
      Navigator.of(context).pop(true); // Return true to refresh
    } catch (e) {
      if (!mounted) return;
      BrandedSnackBar.showError(context, 'Error updating profile: ${e.toString()}');
    } finally {
      if (mounted) {
        safeSetState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? ShimmerLoading.editProfileScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Section
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                backgroundImage: _profilePhotoUrl != null && 
                                    _profilePhotoUrl!.isNotEmpty
                                    ? NetworkImage(_profilePhotoUrl!)
                                    : null,
                                child: _profilePhotoUrl == null || 
                                    _profilePhotoUrl!.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppTheme.primaryColor,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _pickProfilePhoto,
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(
                              'Change Photo',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Basic Information
                    _buildNeumorphicSection(
                      title: 'Basic Information',
                      icon: Icons.person_outline,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              String phone = value.trim();
                              if (phone.startsWith('+237')) {
                                phone = phone.substring(4);
                              } else if (phone.startsWith('237')) {
                                phone = phone.substring(3);
                              } else if (phone.startsWith('0')) {
                                phone = phone.substring(1);
                              }
                              if (!RegExp(r'^[0-9]{9}$').hasMatch(phone)) {
                                return 'Please enter a valid phone number (9 digits)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            enabled: false, // Email cannot be changed easily
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (!_isValidEmail(value)) {
                                  return 'Please enter a valid email';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    // Location (for tutors)
                    if (widget.userType == 'tutor') ...[
                      const SizedBox(height: 16),
                      _buildNeumorphicSection(
                        title: 'Location',
                        icon: Icons.location_on_outlined,
                        child: Column(
                          children: [
                            // City dropdown (simplified - would need actual city list)
                            // For now, just show current values
                            if (_selectedCity != null || _selectedQuarter != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.neutral100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, 
                                        size: 16, 
                                        color: AppTheme.textMedium),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Location: $_selectedCity${_selectedQuarter != null ? ', $_selectedQuarter' : ''}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'To change location, please update your profile through the onboarding flow.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textMedium,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppTheme.textDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        filled: true,
        fillColor: enabled ? Colors.white : AppTheme.neutral100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.neutral200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  /// Format phone number to avoid duplicate country code
  /// Handles: +237+237..., 237237..., +237..., 237..., 0..., or 9 digits
  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;

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