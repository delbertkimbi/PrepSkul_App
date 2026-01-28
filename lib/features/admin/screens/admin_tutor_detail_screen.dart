import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin Tutor Detail Screen
/// 
/// Shows full tutor profile details for admin review
class AdminTutorDetailScreen extends StatefulWidget {
  final String tutorId;
  
  const AdminTutorDetailScreen({
    super.key,
    required this.tutorId,
  });

  @override
  State<AdminTutorDetailScreen> createState() => _AdminTutorDetailScreenState();
}

class _AdminTutorDetailScreenState extends State<AdminTutorDetailScreen> {
  Map<String, dynamic>? _tutorProfile;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTutorDetails();
  }

  Future<void> _loadTutorDetails() async {
    try {
      // Load tutor profile
      final tutorResponse = await SupabaseService.client
          .from('tutor_profiles')
          .select('*')
          .eq('user_id', widget.tutorId)
          .maybeSingle();

      // Load user profile
      final userResponse = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', widget.tutorId)
          .maybeSingle();

      setState(() {
        _tutorProfile = tutorResponse;
        _userProfile = userResponse;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading tutor details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Tutor Profile',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveHeadingSize(context),
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tutorProfile == null
              ? Center(
                  child: Text(
                    'Tutor profile not found',
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
                          _buildInfoRow('Phone', _userProfile?['phone_number'] ?? _tutorProfile?['phone'] ?? 'N/A'),
                        ],
                      ),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Tutor Details
                      _buildSection(
                        'Tutor Details',
                        [
                          _buildInfoRow('Status', _tutorProfile?['status'] ?? 'N/A'),
                          _buildInfoRow('Subjects', (_tutorProfile?['subjects'] as List?)?.join(', ') ?? 'N/A'),
                          _buildInfoRow('Location', _tutorProfile?['location'] ?? 'N/A'),
                          _buildInfoRow('Hourly Rate', '${_tutorProfile?['hourly_rate'] ?? 0} XAF'),
                        ],
                      ),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Bio
                      if (_tutorProfile?['bio'] != null)
                        _buildSection(
                          'Bio',
                          [
                            Text(
                              _tutorProfile?['bio'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.responsiveBodySize(context),
                                color: AppTheme.textDark,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Action Buttons
                      if (_tutorProfile?['status'] == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Navigate to web admin dashboard for approval
                                  _openWebAdmin();
                                },
                                icon: PhosphorIcon(PhosphorIcons.checkCircle(), color: Colors.white),
                                label: Text(
                                  'Review in Dashboard',
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
    final avatarUrl = _userProfile?['avatar_url'] ?? _tutorProfile?['profile_photo_url'];
    final name = _userProfile?['full_name'] ?? _tutorProfile?['full_name'] ?? 'Unknown';
    
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
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12),
                  vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 5, desktop: 6),
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(_tutorProfile?['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tutorProfile?['status'] ?? 'unknown',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveBodySize(context) - 2,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(_tutorProfile?['status']),
                  ),
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
            width: 100,
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
  }

  Future<void> _openWebAdmin() async {
    final url = Uri.parse('https://admin.prepskul.com/admin/tutors/pending');
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

