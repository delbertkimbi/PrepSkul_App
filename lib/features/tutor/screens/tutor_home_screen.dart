import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/profile_completion_service.dart';
import '../../../core/models/profile_completion.dart';
import '../../../core/widgets/profile_completion_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getCurrentUser();

      // Load tutor profile data
      final tutorData = await SurveyRepository.getTutorSurvey(user['userId']);

      // Calculate completion status
      ProfileCompletionStatus? status;
      if (tutorData != null) {
        status = ProfileCompletionService.calculateTutorCompletion(tutorData);
      }

      setState(() {
        _userInfo = user;
        _tutorProfile = tutorData;
        _completionStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Tutor Dashboard',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                    'Welcome back, ${_userInfo?['fullName'] ?? 'Tutor'}!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Completion Banner (if not complete)
                  if (_completionStatus != null &&
                      !_completionStatus!.isComplete)
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

                  if (_completionStatus != null &&
                      !_completionStatus!.isComplete)
                    const SizedBox(height: 16),

                  // Profile Completion Details
                  if (_completionStatus != null)
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

                  if (_completionStatus != null) const SizedBox(height: 24),

                  // Pending Approval Card (only if profile is complete)
                  if (_completionStatus?.isComplete == true)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.hourglass_empty,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pending Approval',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your profile is being reviewed by our admin team.\nYou\'ll be notified once approved!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_completionStatus?.isComplete == true)
                    const SizedBox(height: 24),

                  // Quick Stats (mock data for now)
                  Text(
                    'Quick Stats',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
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

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
