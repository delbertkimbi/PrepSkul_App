import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin User Detail Screen
/// 
/// Shows user profile details for admin review
class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  final String? userType; // 'student', 'parent', or 'tutor'
  
  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    this.userType,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _roleProfile; // tutor_profile, learner_profile, or parent_profile
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    try {
      // Load user profile
      final userResponse = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .maybeSingle();

      final userType = widget.userType ?? userResponse?['user_type'] ?? 'student';

      // Load role-specific profile
      String? roleTable;
      if (userType == 'tutor') {
        roleTable = 'tutor_profiles';
      } else if (userType == 'parent') {
        roleTable = 'parent_profiles';
      } else {
        roleTable = 'learner_profiles';
      }

      if (roleTable != null) {
        final roleResponse = await SupabaseService.client
            .from(roleTable)
            .select('*')
            .eq('user_id', widget.userId)
            .maybeSingle();

        setState(() {
          _roleProfile = roleResponse;
        });
      }

      setState(() {
        _userProfile = userResponse;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading user details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = widget.userType ?? _userProfile?['user_type'] ?? 'student';
    final userTypeDisplay = userType == 'student' 
        ? 'Student' 
        : userType == 'parent' 
            ? 'Parent' 
            : 'Tutor';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$userTypeDisplay Profile',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveHeadingSize(context),
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? Center(
                  child: Text(
                    'User profile not found',
                    style: GoogleFonts.poppins(color: AppTheme.textMedium),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(ResponsiveHelper.responsiveHorizontalPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: ResponsiveHelper.responsiveVerticalPadding(context)),
                      
                      // Profile Header
                      _buildProfileHeader(),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Contact Information
                      _buildSection(
                        'Contact Information',
                        [
                          _buildInfoRow('Email', _userProfile?['email'] ?? 'N/A'),
                          _buildInfoRow('Phone', _userProfile?['phone_number'] ?? 'N/A'),
                          _buildInfoRow('User Type', userTypeDisplay),
                        ],
                      ),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Role-specific details
                      if (_roleProfile != null && _roleProfile!.isNotEmpty)
                        _buildSection(
                          '$userTypeDisplay Details',
                          _roleProfile!.entries.map((entry) {
                            if (entry.value == null) return const SizedBox.shrink();
                            return _buildInfoRow(
                              entry.key.replaceAll('_', ' ').split(' ').map((word) => 
                                word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
                              ).join(' '),
                              entry.value.toString(),
                            );
                          }).toList(),
                        ),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Action Button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openWebAdmin();
                              },
                              icon: PhosphorIcon(PhosphorIcons.arrowSquareOut(), color: Colors.white),
                              label: Text(
                                'View in Admin Dashboard',
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveHelper.responsiveBodySize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = _userProfile?['avatar_url'];
    final name = _userProfile?['full_name'] ?? 'Unknown';
    
    return Row(
      children: [
        Container(
          width: ResponsiveHelper.responsiveSpacing(context, mobile: 60, tablet: 70, desktop: 80),
          height: ResponsiveHelper.responsiveSpacing(context, mobile: 60, tablet: 70, desktop: 80),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor.withOpacity(0.1),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.responsiveSubheadingSize(context) + 4,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context) + 4,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
        ),
        SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.responsiveSubheadingSize(context) + 2,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
              Text(
                widget.userType ?? _userProfile?['user_type'] ?? 'student',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.responsiveBodySize(context),
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
        Container(
          padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18)),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebAdmin() async {
    final userType = widget.userType ?? _userProfile?['user_type'] ?? 'student';
    final path = userType == 'tutor' 
        ? '/admin/tutors/pending' 
        : userType == 'parent'
            ? '/admin/users'
            : '/admin/users';
    final url = Uri.parse('https://admin.prepskul.com$path');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open admin dashboard. Please visit admin.prepskul.com',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }
}

