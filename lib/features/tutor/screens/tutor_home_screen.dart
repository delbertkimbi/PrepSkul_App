import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo_header.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/profile_completion_service.dart';
import '../../../core/models/profile_completion.dart';
import '../../../core/widgets/profile_completion_widget.dart';
import '../../../features/notifications/widgets/notification_bell.dart';
import 'tutor_admin_feedback_screen.dart';

class TutorHomeScreen extends StatefulWidget {
  const TutorHomeScreen({Key? key}) : super(key: key);

  @override
  State<TutorHomeScreen> createState() => _TutorHomeScreenState();
}

class _TutorHomeScreenState extends State<TutorHomeScreen> {
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _tutorProfile;
  ProfileCompletionStatus? _completionStatus;
  bool _isLoading = true;
  String? _approvalStatus; // 'pending', 'approved', 'rejected'
  bool _hasDismissedApprovalCard = false; // Track if user dismissed approval card

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkDismissedApprovalCard();
  }

  Future<void> _checkDismissedApprovalCard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasDismissedApprovalCard = prefs.getBool('tutor_approval_card_dismissed') ?? false;
    });
  }

  Future<void> _dismissApprovalCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutor_approval_card_dismissed', true);
    setState(() {
      _hasDismissedApprovalCard = true;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Load fresh profile data from database to get updated name
      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      // Get updated name from database (most up-to-date)
      final fullName = profileResponse?['full_name']?.toString() ?? 
          user['fullName']?.toString() ?? 'Tutor';

      // Load tutor profile data
      final tutorData = await SurveyRepository.getTutorSurvey(userId);

      // Calculate completion status
      ProfileCompletionStatus? status;
      if (tutorData != null) {
        status = ProfileCompletionService.calculateTutorCompletion(tutorData);
      }

      // Check if approval status changed (reset dismissal ONLY if status actually changed from non-approved to approved)
      final newApprovalStatus = tutorData?['status'] as String?;
      final prefs = await SharedPreferences.getInstance();
      final wasDismissed = prefs.getBool('tutor_approval_card_dismissed') ?? false;
      
      // Only reset dismissal if:
      // 1. Status is now 'approved' AND
      // 2. Previous status was NOT 'approved' (actual status change) AND
      // 3. User had previously dismissed it
      if (newApprovalStatus == 'approved' && 
          _approvalStatus != null && 
          _approvalStatus != 'approved' && 
          wasDismissed) {
        // Status changed from non-approved to approved - reset dismissal
        await prefs.setBool('tutor_approval_card_dismissed', false);
        _hasDismissedApprovalCard = false;
      } else if (newApprovalStatus == 'approved' && wasDismissed) {
        // Status is approved and was dismissed - keep it dismissed
        _hasDismissedApprovalCard = true;
      }

      setState(() {
        _userInfo = {
          ...user,
          'fullName': fullName, // Use updated name from database
        };
        _tutorProfile = tutorData;
        _completionStatus = status;
        _approvalStatus = newApprovalStatus;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Extract first name from full name
  String _getFirstName(String fullName) {
    if (fullName.isEmpty || fullName == 'Tutor') return fullName;
    // Split by space and take the first part
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : fullName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: const AppLogoHeader(),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: NotificationBell(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  Text(
                    'Welcome back, ${_getFirstName(_userInfo?['fullName']?.toString() ?? 'Tutor')}!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Profile Completion Banner (if not complete)
                  // Hide when: 100% complete AND approved
                  // Show when: Not complete OR (complete but not approved)
                  Builder(
                    builder: (context) {
                      final shouldShowCompletionCard =
                          _completionStatus != null &&
                          (!_completionStatus!.isComplete ||
                              (_completionStatus!.isComplete &&
                                  _approvalStatus != 'approved'));

                      if (!shouldShowCompletionCard) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          ProfileCompletionBanner(
                            status: _completionStatus!,
                            onTap: () {
                              // Navigate back to onboarding to complete profile
                              Navigator.of(context)
                                  .pushNamed(
                                    '/tutor-onboarding',
                                    arguments: {
                                      'userId': _userInfo?['userId'],
                                      'existingData': _tutorProfile,
                                    },
                                  )
                                  .then(
                                    (_) => _loadUserInfo(),
                                  ); // Reload after returning
                            },
                          ),
                          const SizedBox(height: 16),
                          // Profile Completion Details
                          ProfileCompletionWidget(
                            status: _completionStatus!,
                            showDetails: true,
                            onEditSection: () {
                              // Navigate to onboarding to edit
                              Navigator.of(context)
                                  .pushNamed(
                                    '/tutor-onboarding',
                                    arguments: {
                                      'userId': _userInfo?['userId'],
                                      'existingData': _tutorProfile,
                                    },
                                  )
                                  .then((_) => _loadUserInfo());
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // Approval Status Card
                  // Show if:
                  // 1. Status is 'approved' AND not dismissed, OR
                  // 2. Profile is complete AND status exists (and not approved), OR
                  // 3. Status is 'needs_improvement', 'rejected', 'blocked', or 'suspended'
                  if ((_approvalStatus == 'approved' && !_hasDismissedApprovalCard) ||
                      (_completionStatus?.isComplete == true &&
                          _approvalStatus != null &&
                          _approvalStatus != 'approved') ||
                      (_approvalStatus == 'needs_improvement' ||
                          _approvalStatus == 'rejected' ||
                          _approvalStatus == 'blocked' ||
                          _approvalStatus == 'suspended'))
                    _buildApprovalStatusCard(),

                  if ((_approvalStatus == 'approved' && !_hasDismissedApprovalCard) ||
                      (_completionStatus?.isComplete == true &&
                          _approvalStatus != null &&
                          _approvalStatus != 'approved') ||
                      (_approvalStatus == 'needs_improvement' ||
                          _approvalStatus == 'rejected' ||
                          _approvalStatus == 'blocked' ||
                          _approvalStatus == 'suspended'))
                    const SizedBox(height: 16),

                  // PrepSkul Wallet Section
                  // Only show after user has dismissed the approval alert
                  if (_approvalStatus == 'approved' && _hasDismissedApprovalCard) ...[
                    _buildWalletSection(),
                    const SizedBox(height: 24),
                  ],

                  // Quick Stats
                  Text(
                    'Quick Stats',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard('Students', '0', Icons.people),
                      const SizedBox(width: 16),
                      _buildStatCard('Sessions', '0', Icons.event),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildApprovalStatusCard() {
    // Handle blocked/suspended status
    if (_approvalStatus == 'blocked' || _approvalStatus == 'suspended') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, size: 32, color: Colors.red[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _approvalStatus == 'blocked'
                        ? 'Account Blocked'
                        : 'Account Suspended',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your account has been ${_approvalStatus == 'blocked' ? 'blocked' : 'suspended'}. View details for more information and to request a review.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewAdminFeedback(),
                icon: const Icon(Icons.visibility),
                label: Text(
                  'View Details',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_approvalStatus == 'approved') {
      // Approved - show compact success card with dismiss button
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentGreen,
              AppTheme.accentGreen.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 32, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approved!',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your profile is live and students can now book sessions with you.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white),
              onPressed: _dismissApprovalCard,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      );
    } else if (_approvalStatus == 'needs_improvement') {
      // Needs Improvement - show compact warning card with "View Details" button
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 24, color: Colors.orange[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Profile Needs Improvement',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Admin has requested changes to your profile. View details to see what needs to be updated.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewAdminFeedback(),
                icon: const Icon(Icons.visibility, size: 16),
                label: Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_approvalStatus == 'rejected') {
      // Rejected - show compact error card with "View Details" button
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, size: 24, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Application Rejected',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your application was not approved. View details to see the reason and what needs to be corrected.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewAdminFeedback(),
                icon: const Icon(Icons.visibility, size: 16),
                label: Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Pending - show compact waiting card
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, size: 32, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Approval',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your profile is being reviewed. You\'ll be notified once approved!',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _viewAdminFeedback() async {
    if (_tutorProfile == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            TutorAdminFeedbackScreen(tutorProfile: _tutorProfile!),
      ),
    );

    // Reload profile if feedback screen returned true (indicating update)
    if (result == true) {
      await _loadUserInfo();
    }
  }

  Widget _buildWalletSection() {
    // TODO: Replace with actual wallet data when wallet system is implemented
    const activeBalance = '0';
    const pendingBalance = '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PrepSkul Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Your earnings and balance',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildWalletBalanceCard(
                  label: 'Active Balance',
                  amount: activeBalance,
                  icon: Icons.check_circle,
                  color: Colors.green.shade300,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWalletBalanceCard(
                  label: 'Pending Balance',
                  amount: pendingBalance,
                  icon: Icons.pending,
                  color: Colors.orange.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to wallet/earnings screen when implemented
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Wallet feature coming soon!',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                'View Earnings',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBalanceCard({
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toString()} XAF',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
