import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/notifications/widgets/notification_bell.dart';
import 'package:prepskul/features/messaging/widgets/message_icon_badge.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'admin_tutor_detail_screen.dart';
import 'admin_user_detail_screen.dart';
import 'admin_tutor_request_detail_screen.dart';

/// Admin Dashboard Screen
/// 
/// Main dashboard for admin users showing stats and quick actions
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Get pending tutors count
      final pendingTutorsResponse = await SupabaseService.client
          .from('tutor_profiles')
          .select('id')
          .eq('status', 'pending');

      // Get total users count
      final totalUsersResponse = await SupabaseService.client
          .from('profiles')
          .select('id');

      // Get active sessions count
      final activeSessionsResponse = await SupabaseService.client
          .from('individual_sessions')
          .select('id')
          .inFilter('status', ['scheduled', 'in_progress']);

      setState(() {
        _stats = {
          'pending_tutors': (pendingTutorsResponse as List).length,
          'total_users': (totalUsersResponse as List).length,
          'active_sessions': (activeSessionsResponse as List).length,
        };
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading admin stats: $e');
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
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveHeadingSize(context),
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
        actions: [
          const MessageIconBadge(),
          Padding(
            padding: EdgeInsets.only(right: ResponsiveHelper.responsiveHorizontalPadding(context)),
            child: const NotificationBell(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveHelper.responsiveHorizontalPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ResponsiveHelper.responsiveVerticalPadding(context)),
                  
                  // Stats Cards
                  Text(
                    'Overview',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  
                  ResponsiveHelper.isMobile(context)
                      ? Column(
                          children: [
                            _buildStatCard(
                              'Pending Tutors',
                              '${_stats?['pending_tutors'] ?? 0}',
                              PhosphorIcons.userCircle(),
                              Colors.orange,
                              onTap: () {
                                // Navigate to pending tutors list
                                Navigator.pushNamed(context, '/admin/pending-tutors');
                              },
                            ),
                            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                            _buildStatCard(
                              'Total Users',
                              '${_stats?['total_users'] ?? 0}',
                              PhosphorIcons.users(),
                              AppTheme.primaryColor,
                            ),
                            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                            _buildStatCard(
                              'Active Sessions',
                              '${_stats?['active_sessions'] ?? 0}',
                              PhosphorIcons.videoCamera(),
                              Colors.green,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Pending Tutors',
                                '${_stats?['pending_tutors'] ?? 0}',
                                PhosphorIcons.userCircle(),
                                Colors.orange,
                                onTap: () {
                                  Navigator.pushNamed(context, '/admin/pending-tutors');
                                },
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                            Expanded(
                              child: _buildStatCard(
                                'Total Users',
                                '${_stats?['total_users'] ?? 0}',
                                PhosphorIcons.users(),
                                AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                            Expanded(
                              child: _buildStatCard(
                                'Active Sessions',
                                '${_stats?['active_sessions'] ?? 0}',
                                PhosphorIcons.videoCamera(),
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                  
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 24, tablet: 28, desktop: 32)),
                  
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  
                  _buildActionCard(
                    icon: PhosphorIcons.userCircle(),
                    title: 'Pending Tutors',
                    subtitle: 'Review tutor applications',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/pending-tutors');
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  
                  _buildActionCard(
                    icon: PhosphorIcons.users(),
                    title: 'All Users',
                    subtitle: 'View and manage users',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/users');
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  
                  _buildActionCard(
                    icon: PhosphorIcons.clipboardText(),
                    title: 'Tutor Requests',
                    subtitle: 'Review tutor matching requests',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/tutor-requests');
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: PhosphorIcon(
                icon,
                color: color,
                size: ResponsiveHelper.responsiveIconSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
            ),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveSubheadingSize(context) + 4,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveBodySize(context),
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: PhosphorIcon(
                icon,
                color: color,
                size: ResponsiveHelper.responsiveIconSize(context, mobile: 21, tablet: 24, desktop: 26),
              ),
            ),
            SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context) - 1,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 1 : 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            PhosphorIcon(
              PhosphorIcons.caretRight(),
              size: ResponsiveHelper.responsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18),
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

