import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin Tutor Request Detail Screen
/// 
/// Shows tutor request details for admin review
class AdminTutorRequestDetailScreen extends StatefulWidget {
  final String requestId;
  
  const AdminTutorRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<AdminTutorRequestDetailScreen> createState() => _AdminTutorRequestDetailScreenState();
}

class _AdminTutorRequestDetailScreenState extends State<AdminTutorRequestDetailScreen> {
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _requesterProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    try {
      // Load tutor request
      final requestResponse = await SupabaseService.client
          .from('tutor_requests')
          .select('*')
          .eq('id', widget.requestId)
          .maybeSingle();

      if (requestResponse != null) {
        final requesterId = requestResponse['student_id'] ?? requestResponse['parent_id'];
        
        // Load requester profile
        if (requesterId != null) {
          final requesterResponse = await SupabaseService.client
              .from('profiles')
              .select('*')
              .eq('id', requesterId)
              .maybeSingle();

          setState(() {
            _requesterProfile = requesterResponse;
          });
        }
      }

      setState(() {
        _request = requestResponse;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading tutor request details: $e');
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
          'Tutor Request',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveHeadingSize(context),
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _request == null
              ? Center(
                  child: Text(
                    'Request not found',
                    style: GoogleFonts.poppins(color: AppTheme.textMedium),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(ResponsiveHelper.responsiveHorizontalPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: ResponsiveHelper.responsiveVerticalPadding(context)),
                      
                      // Request Header
                      _buildRequestHeader(),
                      
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Requester Information
                      if (_requesterProfile != null)
                        _buildSection(
                          'Requester Information',
                          [
                            _buildInfoRow('Name', _requesterProfile?['full_name'] ?? 'N/A'),
                            _buildInfoRow('Email', _requesterProfile?['email'] ?? 'N/A'),
                            _buildInfoRow('Phone', _requesterProfile?['phone_number'] ?? 'N/A'),
                          ],
                        ),
                      
                      if (_requesterProfile != null)
                        SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      
                      // Request Details
                      _buildSection(
                        'Request Details',
                        [
                          _buildInfoRow('Status', _request?['status'] ?? 'N/A'),
                          _buildInfoRow('Subject', _request?['subject'] ?? 'N/A'),
                          _buildInfoRow('Location', _request?['location'] ?? 'N/A'),
                          if (_request?['preferred_days'] != null)
                            _buildInfoRow('Preferred Days', (_request?['preferred_days'] as List?)?.join(', ') ?? 'N/A'),
                          if (_request?['preferred_time'] != null)
                            _buildInfoRow('Preferred Time', _request?['preferred_time'] ?? 'N/A'),
                          if (_request?['notes'] != null && (_request?['notes'].toString().isNotEmpty ?? false))
                            _buildInfoRow('Notes', _request?['notes'] ?? 'N/A'),
                        ],
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
                                'Review in Admin Dashboard',
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

  Widget _buildRequestHeader() {
    final requesterName = _requesterProfile?['full_name'] ?? 'Unknown';
    
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: PhosphorIcon(
              PhosphorIcons.graduationCap(),
              color: Colors.white,
              size: ResponsiveHelper.responsiveIconSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
          ),
          SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tutor Request',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
                Text(
                  'From: $requesterName',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveBodySize(context),
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final url = Uri.parse('https://admin.prepskul.com/admin/tutor-requests/${widget.requestId}');
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

