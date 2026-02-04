import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// TutorRequestDetailScreen
///
/// Full detail view of a booking request (tutor's perspective)
/// Shows complete schedule, student info, conflicts
/// Actions: Approve, Reject (with reason), Suggest Modifications
class TutorRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final bool autoOpenReject;

  const TutorRequestDetailScreen({
    Key? key,
    required this.request,
    this.autoOpenReject = false,
  }) : super(key: key);

  @override
  State<TutorRequestDetailScreen> createState() =>
      _TutorRequestDetailScreenState();
}

class _TutorRequestDetailScreenState extends State<TutorRequestDetailScreen> {
  final TextEditingController _responseController = TextEditingController();
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  bool _isProcessing = false;
  Map<String, dynamic>? _studentSurvey;
  bool _isLoadingSurvey = true;
  Map<String, dynamic>? _requesterProfile; // Store requester profile (who made the booking)
  bool _isLoadingProfile = true;
  Map<String, String> _learnerRejectionReasons = {}; // Track rejection reasons per learner
  Map<String, bool> _expandedLearners = {}; // Track which learners are expanded
  Map<String, Map<String, dynamic>> _learnerDetails = {}; // Cache learner details from parent_learners
  bool _isLoadingLearnerDetails = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenReject) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRejectDialog();
      });
    }
    _loadRequesterProfile(); // Load requester (who made the booking)
    _loadStudentSurvey();
  }

  /// Load the requester's profile (who made the booking) - this is what tutors should see
  /// For trial sessions: requester could be parent or student
  /// For regular bookings: requester is the student
  Future<void> _loadRequesterProfile() async {
    try {
      // Check if this is a trial session request
      final isTrial = widget.request['is_trial'] == true;
      
      // CRITICAL: Get the requester_id (who made the booking), not learner_id
      // The requester is the one who actually created the request
      String? requesterId;
      if (isTrial) {
        // For trial sessions, get requester_id (who made the booking)
        requesterId = widget.request['requester_id'] as String?;
        
        // If requester_id not in request, fetch from trial_sessions table
        if (requesterId == null || requesterId.isEmpty) {
          final requestId = widget.request['id'] as String?;
          if (requestId != null) {
            try {
              final trialSession = await SupabaseService.client
                  .from('trial_sessions')
                  .select('requester_id, learner_id')
                  .eq('id', requestId)
                  .maybeSingle();
              
              if (trialSession != null) {
                requesterId = trialSession['requester_id'] as String?;
                LogService.debug('Fetched requester_id from trial_sessions: $requesterId');
              }
            } catch (e) {
              LogService.warning('Error fetching requester_id from trial_sessions: $e');
            }
          }
        }
      } else {
        // For regular bookings, student_id is the requester
        requesterId = widget.request['student_id'] as String?;
      }
      
      if (requesterId != null && requesterId.isNotEmpty) {
        LogService.debug('Loading requester profile for ID: $requesterId (isTrial: $isTrial)');
        final profile = await SupabaseService.client
            .from('profiles')
            .select('id, full_name, avatar_url, user_type, email')
            .eq('id', requesterId)
            .maybeSingle();
        
        if (mounted) {
          safeSetState(() {
            _requesterProfile = profile as Map<String, dynamic>?;
            _isLoadingProfile = false;
          });
          
          if (_requesterProfile != null) {
            LogService.success('✅ Loaded requester profile: ${_requesterProfile!['full_name']} (user_type: ${_requesterProfile!['user_type']})');
          } else {
            LogService.warning('⚠️ Requester profile not found for ID: $requesterId');
          }
        }
      } else {
        LogService.warning('⚠️ No requester_id or student_id found in request');
        safeSetState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      LogService.error('Error loading requester profile: $e');
      if (mounted) {
        safeSetState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _loadStudentSurvey() async {
    try {
      // Use learner_id for trial sessions, student_id for regular bookings
      final isTrial = widget.request['is_trial'] == true;
      final studentId = isTrial 
          ? (widget.request['learner_id'] as String?)
          : (widget.request['student_id'] as String?);
      
      if (studentId != null) {
        final survey = await SurveyRepository.getStudentSurvey(studentId);
        if (mounted) {
          safeSetState(() {
            _studentSurvey = survey;
            _isLoadingSurvey = false;
          });
        }
      } else {
        safeSetState(() => _isLoadingSurvey = false);
      }
    } catch (e) {
      LogService.warning('Error loading student survey: $e');
      if (mounted) {
        safeSetState(() => _isLoadingSurvey = false);
      }
    }
  }

  Future<void> _approveRequest() async {
    final response = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Accept This Request?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a message to the student (optional):',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _responseController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'E.g., Looking forward to working with you!',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _responseController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Accept Request',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (response != null) {
      safeSetState(() => _isProcessing = true);
      try {
        final requestId = widget.request['id'] as String;
        // TutorRequestDetailScreen handles booking_requests (recurring sessions), not trials
        await BookingService.approveBookingRequest(requestId, responseNotes: response);
        
        if (!mounted) return;
        Navigator.pop(context); // Go back to list
        BrandedSnackBar.show(
          context,
          message: 'Request accepted successfully!',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      } catch (e) {
        LogService.error('Error approving request: $e');
        if (!mounted) return;
        safeSetState(() => _isProcessing = false);
        BrandedSnackBar.showError(
          context,
          'Failed to accept request: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Decline This Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason (required):',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'E.g., Schedule conflict, location too far, etc.',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Be respectful and helpful. Suggest alternatives if possible.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _rejectionReasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please provide a reason',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Decline Request',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      safeSetState(() => _isProcessing = true);
      try {
        final requestId = widget.request['id'] as String;
        final isTrial = widget.request['is_trial'] == true;
        
        if (isTrial) {
          await BookingService.rejectTrialRequest(
            requestId,
            reason: result,
          );
        } else {
          await BookingService.rejectBookingRequest(
            requestId,
            reason: result,
          );
        }
        
        if (!mounted) return;
        Navigator.pop(context); // Go back to list
        BrandedSnackBar.show(
          context,
          message: 'Request declined',
          backgroundColor: Colors.orange,
          icon: Icons.info_outline,
        );
      } catch (e) {
        LogService.error('Error rejecting request: $e');
        if (!mounted) return;
        BrandedSnackBar.showError(
          context,
          'Failed to decline request: $e',
        );
        safeSetState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Use requester profile (who made the booking) for display
    // Priority: 1. Freshly loaded requester profile, 2. Request student data, 3. Empty map
    final requester = _requesterProfile ?? widget.request['student'] as Map<String, dynamic>? ?? {};
    final status = widget.request['status'] as String? ?? 'pending';
    final hasConflict = widget.request['has_conflict'] == true;
    final isPending = status == 'pending';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Check if we can pop, if not, navigate to tutor requests screen
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // If no previous screen, navigate to tutor requests tab
              Navigator.of(context).pushReplacementNamed(
                '/tutor-nav',
                arguments: {'initialTab': 1}, // Requests tab
              );
            }
          },
        ),
        title: Text(
          'Request Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(status),
            const SizedBox(height: 24),
            // Conflict Warning (if applicable)
            if (hasConflict && isPending)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange[700],
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule Conflict',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.request['conflict_details'] as String? ??
                                'Time slot conflict with existing student',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (hasConflict && isPending) const SizedBox(height: 24),

            // Student Card - Show loading if profile is still loading
            if (_isLoadingProfile)
              const Center(child: CircularProgressIndicator())
            else
              _buildStudentCard(requester),
            const SizedBox(height: 24),

            // Student Analysis Section (from survey)
            if (_studentSurvey != null) ...[
              _buildStudentAnalysisCard(),
              const SizedBox(height: 24),
            ],

            // Schedule Section
            _buildScheduleCard(),
            const SizedBox(height: 20),

            // Location Section
            _buildLocationCard(),
            const SizedBox(height: 20),

            // Revenue Section
            _buildRevenueCard(),

            const SizedBox(height: 32),

            // Action Buttons (for pending requests - only show if NOT multi-learner)
            // Multi-learner bookings use per-learner accept/decline in the group card
            Builder(
              builder: (context) {
                final learnerLabels = widget.request['learner_labels'] as List?;
                final isMultiLearner = learnerLabels != null && learnerLabels.isNotEmpty;
                
                // Hide global buttons for multi-learner bookings
                if (isMultiLearner) {
                  return const SizedBox.shrink();
                }
                
                // Show global buttons for single-learner bookings
                if (isPending && !_isProcessing) {
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showRejectDialog,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Decline',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _approveRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Accept Request',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (_isProcessing) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }


  Widget _buildStatusBanner(String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status.toUpperCase()) {
      case 'PENDING':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'PENDING';
        break;
      case 'APPROVED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'APPROVED';
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'REJECTED';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = status.toUpperCase();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Text(
            'Status: $statusText',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStudentCard(Map<String, dynamic> requester) {
    // CRITICAL: This function receives the requester (who made the booking)
    // Determine if requester is a parent or student/learner
    final userType = requester['user_type'] as String?;
    final isParent = userType == 'parent' || userType == 'Parent';
    
    // Get the actual name - prefer full_name, fall back to email, then generic
    // IMPORTANT: Never show "Student" as default - always try to get the actual name
    String requesterName = isParent ? 'Parent' : 'Student';
    
    if (requester['full_name'] != null && 
        requester['full_name'].toString().trim().isNotEmpty &&
        requester['full_name'].toString().toLowerCase() != 'user' &&
        requester['full_name'].toString().toLowerCase() != 'null' &&
        requester['full_name'].toString().toLowerCase() != 'student') {
      requesterName = requester['full_name'].toString().trim();
      LogService.debug('✅ Using requester full_name: $requesterName');
    } else if (requester['email'] != null && 
               requester['email'].toString().trim().isNotEmpty) {
      // Extract name from email as fallback
      final email = requester['email'].toString().trim();
      final emailName = email.split('@').first;
      if (emailName.isNotEmpty && 
          emailName.toLowerCase() != 'user' &&
          emailName.toLowerCase() != 'student' &&
          emailName.toLowerCase() != 'parent') {
        requesterName = emailName[0].toUpperCase() + emailName.substring(1);
        LogService.debug('✅ Using requester email name: $requesterName');
      }
    }
    
    // Log for debugging
    LogService.info('📋 Displaying requester: $requesterName (user_type: $userType, isParent: $isParent)');
    
    // Get avatar URL - try avatar_url first, then profile_photo_url
    final avatarUrl = requester['avatar_url'] as String? ?? 
                     requester['profile_photo_url'] as String?;
    
    // Get initial for avatar placeholder - use requester's name, not generic "S"
    final initial = requesterName.isNotEmpty && requesterName != 'Student' && requesterName != 'Parent'
        ? requesterName[0].toUpperCase()
        : (isParent ? 'P' : 'S');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isParent ? Colors.purple[50]! : Colors.blue[50]!),
              (isParent ? Colors.purple[100]! : Colors.blue[100]!).withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar with better styling
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isParent ? Colors.purple : Colors.blue).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isParent ? Colors.purple : Colors.blue).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 72,
                          height: 72,
                          color: isParent ? Colors.purple[400] : Colors.blue[400],
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 72,
                          height: 72,
                          color: isParent ? Colors.purple[400] : Colors.blue[400],
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 36,
                      backgroundColor: isParent ? Colors.purple[400] : Colors.blue[400],
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requesterName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isParent
                          ? Colors.purple[100]
                          : Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isParent
                            ? Colors.purple[300]!
                            : Colors.blue[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isParent ? Icons.family_restroom : Icons.school,
                          size: 14,
                          color: isParent
                              ? Colors.purple[700]
                              : Colors.blue[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isParent
                              ? AppLocalizations.of(context)!.parentRequest
                              : AppLocalizations.of(context)!.studentRequest,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isParent
                                ? Colors.purple[700]
                                : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Multi-learner group card with per-learner accept/decline
            Builder(
              builder: (context) {
                final isTrial = widget.request['is_trial'] == true;
                if (isTrial) return const SizedBox.shrink();
                
                final learnerLabels = widget.request['learner_labels'] as List?;
                if (learnerLabels == null || learnerLabels.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                // This is a multi-learner booking - show group card with per-learner actions
                return _buildMultiLearnerGroupCard(learnerLabels);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    final isTrial = widget.request['is_trial'] == true;
    final frequency = widget.request['frequency'] as int? ?? 0;
    final days = widget.request['days'] as List? ?? [];
    final times = widget.request['times'] as Map<String, dynamic>? ?? {};
    final scheduledDate = widget.request['scheduled_date'] != null
        ? DateTime.tryParse(widget.request['scheduled_date'].toString())
        : null;
    final subject = widget.request['subject'] as String?;
    final durationMinutes = widget.request['duration_minutes'] as int?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Schedule Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isTrial) ...[
              if (scheduledDate != null)
                _buildDetailRow(
                  Icons.event,
                  'Date',
                  '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}',
                ),
              if (subject != null)
                _buildDetailRow(Icons.menu_book, 'Subject', subject),
              if (durationMinutes != null)
                _buildDetailRow(Icons.timer, 'Duration', '$durationMinutes minutes'),
            ] else ...[
              _buildDetailRow(Icons.event_repeat, 'Frequency', '$frequency sessions per week'),
              if (days.isNotEmpty) ...[
                _buildDetailRow(Icons.calendar_today, 'Days', days.join(', ')),
                const SizedBox(height: 16),
                Text(
                  'Session Times',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 12),
                ...days.map((day) {
                  final time = times[day] ?? 'Not set';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[100]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$day',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = widget.request['location'] as String? ?? 'Not specified';
    final address = widget.request['address'] as String?;
    final locationDescription = widget.request['location_description'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green[50]!,
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_on, color: Colors.green[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Location',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.public, 'Type', location.toUpperCase()),
            if (address != null && address.isNotEmpty)
              _buildDetailRow(Icons.home, 'Address', address),
            // Show location description if provided by learner
            if (locationDescription != null && locationDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.description, 'Location Details', locationDescription),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    final monthlyTotal = widget.request['monthly_total'] as double? ?? 0.0;
    final paymentPlan = widget.request['payment_plan'] as String? ?? 'Not specified';
    final isTrial = widget.request['is_trial'] == true;
    final location = widget.request['location'] as String? ?? 'online';
    final estimatedTransportationCost = (widget.request['estimated_transportation_cost'] as num?)?.toDouble();
    final isOnsite = location == 'onsite' || location == 'hybrid';
    final frequency = widget.request['frequency'] as int? ?? 1;
    final sessionsPerMonth = frequency * 4;
    final monthlyTransportationTotal = (estimatedTransportationCost != null && estimatedTransportationCost > 0 && isOnsite)
        ? estimatedTransportationCost * sessionsPerMonth
        : 0.0;
    final totalMonthlyPayment = monthlyTotal + monthlyTransportationTotal;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green[50]!,
              Colors.green[100]!.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance_wallet, color: Colors.green[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payment Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isTrial)
              _buildDetailRow(Icons.money, 'Trial Session', 'FREE', iconColor: Colors.green[700])
            else ...[
              _buildDetailRow(Icons.attach_money, 'Session Fee (Monthly)', '${monthlyTotal.toStringAsFixed(0)} XAF', iconColor: Colors.green[700]),
              if (isOnsite && monthlyTransportationTotal > 0) ...[
                const SizedBox(height: 8),
                _buildDetailRow(Icons.directions_car, 'Transportation (Monthly)', '${monthlyTransportationTotal.toStringAsFixed(0)} XAF', iconColor: Colors.orange[700]),
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${estimatedTransportationCost?.toStringAsFixed(0) ?? '0'} XAF per session (round trip)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange[900],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Parent Pays:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[900],
                      ),
                    ),
                    Text(
                      '${totalMonthlyPayment.toStringAsFixed(0)} XAF',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.payment, 'Payment Plan', paymentPlan.toUpperCase(), iconColor: Colors.green[700]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAnalysisCard() {
    if (_studentSurvey == null) return const SizedBox.shrink();
    
    final survey = _studentSurvey!;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.psychology, color: Colors.blue[700], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Student Analysis',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Learning Path
            if (survey['learning_path'] != null) ...[
              _buildAnalysisRow(
                Icons.trending_up,
                'Learning Path',
                survey['learning_path'].toString(),
              ),
              const SizedBox(height: 12),
            ],
            
            // Education Level
            if (survey['education_level'] != null) ...[
              _buildAnalysisRow(
                Icons.school,
                'Education Level',
                survey['education_level'].toString(),
              ),
              const SizedBox(height: 12),
            ],
            
            // Subjects of Interest
            if (survey['subjects_of_interest'] != null) ...[
              Builder(
                builder: (context) {
                  final subjects = survey['subjects_of_interest'];
                  String subjectsText = '';
                  if (subjects is List && subjects.isNotEmpty) {
                    subjectsText = subjects.join(', ');
                  } else if (subjects is String && subjects.isNotEmpty) {
                    subjectsText = subjects;
                  }
                  if (subjectsText.isNotEmpty) {
                    return Column(
                      children: [
                        _buildAnalysisRow(
                          Icons.menu_book,
                          'Subjects of Interest',
                          subjectsText,
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            // Learning Goals
            if (survey['learning_goals'] != null) ...[
              Builder(
                builder: (context) {
                  final goals = survey['learning_goals'];
                  String goalsText = '';
                  if (goals is List && goals.isNotEmpty) {
                    goalsText = goals.join(', ');
                  } else if (goals is String && goals.isNotEmpty) {
                    goalsText = goals;
                  }
                  if (goalsText.isNotEmpty) {
                    return Column(
                      children: [
                        _buildAnalysisRow(
                          Icons.flag,
                          'Learning Goals',
                          goalsText,
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            // Challenges
            if (survey['challenges'] != null) ...[
              Builder(
                builder: (context) {
                  final challenges = survey['challenges'];
                  String challengesText = '';
                  if (challenges is List && challenges.isNotEmpty) {
                    challengesText = challenges.join(', ');
                  } else if (challenges is String && challenges.isNotEmpty) {
                    challengesText = challenges;
                  }
                  if (challengesText.isNotEmpty) {
                    return Column(
                      children: [
                        _buildAnalysisRow(
                          Icons.help_outline,
                          'Challenges',
                          challengesText,
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            // Learning Style
            if (survey['learning_styles'] != null || survey['learning_style'] != null) ...[
              Builder(
                builder: (context) {
                  final styles = survey['learning_styles'] ?? survey['learning_style'];
                  String stylesText = '';
                  if (styles is List && styles.isNotEmpty) {
                    stylesText = styles.join(', ');
                  } else if (styles is String && styles.isNotEmpty) {
                    stylesText = styles;
                  }
                  if (stylesText.isNotEmpty) {
                    return _buildAnalysisRow(
                      Icons.style,
                      'Learning Style',
                      stylesText,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            // Confidence Level
            if (survey['confidence_level'] != null) ...[
              const SizedBox(height: 12),
              _buildAnalysisRow(
                Icons.sentiment_satisfied,
                'Confidence Level',
                survey['confidence_level'].toString(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalysisRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700],),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build multi-learner group card with per-learner accept/decline actions
  Widget _buildMultiLearnerGroupCard(List learnerLabels) {
    final learnerAcceptanceStatus = widget.request['learner_acceptance_status'] as Map<String, dynamic>?;
    final isPending = widget.request['status'] == 'pending';
    
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Learners for this booking (${learnerLabels.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...learnerLabels.asMap().entries.map((entry) {
                final index = entry.key;
                final learnerName = entry.value.toString();
                final learnerStatus = learnerAcceptanceStatus?[learnerName]?['status'] as String?;
                final learnerReason = learnerAcceptanceStatus?[learnerName]?['reason'] as String?;
                final isExpanded = _expandedLearners[learnerName] ?? false;
                final learnerDetails = _learnerDetails[learnerName];
                
                return _buildLearnerCard(
                  learnerName: learnerName,
                  index: index,
                  status: learnerStatus,
                  rejectionReason: learnerReason,
                  isPending: isPending,
                  isExpanded: isExpanded,
                  learnerDetails: learnerDetails,
                  onToggleExpand: () {
                    setState(() {
                      _expandedLearners[learnerName] = !isExpanded;
                      // Load learner details when expanding
                      if (!isExpanded && learnerDetails == null) {
                        _loadLearnerDetails(learnerName);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// Load learner details from parent_learners table
  Future<void> _loadLearnerDetails(String learnerName) async {
    if (_isLoadingLearnerDetails) return;
    
    try {
      safeSetState(() => _isLoadingLearnerDetails = true);
      
      // Get parent_id from booking request (student_id for parent bookings)
      final studentId = widget.request['student_id'] as String?;
      if (studentId == null) return;
      
      // Fetch learner from parent_learners by name and parent_id
      final learners = await SupabaseService.client
          .from('parent_learners')
          .select()
          .eq('parent_id', studentId)
          .eq('name', learnerName)
          .maybeSingle();
      
      if (learners != null && mounted) {
        safeSetState(() {
          _learnerDetails[learnerName] = learners as Map<String, dynamic>;
          _isLoadingLearnerDetails = false;
        });
      } else {
        safeSetState(() => _isLoadingLearnerDetails = false);
      }
    } catch (e) {
      LogService.warning('Error loading learner details: $e');
      if (mounted) {
        safeSetState(() => _isLoadingLearnerDetails = false);
      }
    }
  }

  /// Build individual learner card with accept/decline actions
  Widget _buildLearnerCard({
    required String learnerName,
    required int index,
    String? status,
    String? rejectionReason,
    required bool isPending,
    required bool isExpanded,
    Map<String, dynamic>? learnerDetails,
    required VoidCallback onToggleExpand,
  }) {
    final isAccepted = status == 'accepted';
    final isDeclined = status == 'declined';
    final isPendingStatus = status == null || status == 'pending';
    
    return Container(
      margin: EdgeInsets.only(bottom: index < (widget.request['learner_labels'] as List).length - 1 ? 12 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAccepted 
              ? Colors.green[300]!
              : isDeclined 
                  ? Colors.red[300]!
                  : Colors.grey[300]!,
          width: isAccepted || isDeclined ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAccepted 
                      ? Colors.green
                      : isDeclined 
                          ? Colors.red
                          : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learnerName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (isAccepted || isDeclined) ...[
                      const SizedBox(height: 4),
                      Text(
                        isAccepted ? '✓ Accepted' : '✗ Declined',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isAccepted ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Expand/collapse button
              if (isPendingStatus)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppTheme.textMedium,
                  ),
                  onPressed: onToggleExpand,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          
          // Expanded details and actions
          if (isExpanded && isPendingStatus) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Learner details
            if (_isLoadingLearnerDetails && learnerDetails == null)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (learnerDetails != null) ...[
              // Education Level
              if (learnerDetails['education_level'] != null)
                _buildLearnerDetailRow(
                  Icons.school,
                  'Education Level',
                  learnerDetails['education_level'].toString(),
                ),
              
              // Class Level
              if (learnerDetails['class_level'] != null)
                _buildLearnerDetailRow(
                  Icons.grade,
                  'Class Level',
                  learnerDetails['class_level'].toString(),
                ),
              
              // Subjects
              if (learnerDetails['subjects'] != null && (learnerDetails['subjects'] as List).isNotEmpty)
                _buildLearnerDetailRow(
                  Icons.book,
                  'Subjects',
                  (learnerDetails['subjects'] as List).join(', '),
                ),
              
              // Stream (for secondary)
              if (learnerDetails['stream'] != null)
                _buildLearnerDetailRow(
                  Icons.track_changes,
                  'Stream',
                  learnerDetails['stream'].toString(),
                ),
              
              // Exam Type
              if (learnerDetails['exam_type'] != null)
                _buildLearnerDetailRow(
                  Icons.quiz,
                  'Exam Type',
                  learnerDetails['exam_type'].toString(),
                ),
              
              // Confidence Level
              if (learnerDetails['confidence_level'] != null)
                _buildLearnerDetailRow(
                  Icons.sentiment_satisfied,
                  'Confidence Level',
                  learnerDetails['confidence_level'].toString(),
                ),
              
              const SizedBox(height: 8),
            ] else ...[
              // Fallback: Show booking subject if learner details not available
              Text(
                'Subject: ${widget.request['subject'] ?? 'Not specified'}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Accept/Decline buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _acceptLearner(learnerName),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.green[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Accept',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDeclineLearnerDialog(learnerName),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Show rejection reason if declined
          if (isDeclined && rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: $rejectionReason',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Accept a specific learner
  Future<void> _acceptLearner(String learnerName) async {
    try {
      safeSetState(() => _isProcessing = true);
      
      final requestId = widget.request['id'] as String;
      await BookingService.acceptLearner(
        requestId,
        learnerName,
        responseNotes: _responseController.text.trim().isNotEmpty 
            ? _responseController.text.trim() 
            : null,
      );
      
      if (!mounted) return;
      
      // Reload request to get updated status
      final updatedRequest = await BookingService.getBookingRequestById(requestId);
      final updatedRequestData = updatedRequest.toJson();
      
      safeSetState(() {
        widget.request.clear();
        widget.request.addAll(updatedRequestData);
        _isProcessing = false;
      });
      
      BrandedSnackBar.show(
        context,
        message: '$learnerName accepted successfully!',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );
      
      // If all learners responded, show appropriate message
      if (updatedRequest.allLearnersResponded) {
        if (updatedRequest.isApproved) {
          BrandedSnackBar.show(
            context,
            message: 'Booking approved! Payment request created for accepted learners.',
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
          );
        } else if (updatedRequest.isRejected) {
          BrandedSnackBar.show(
            context,
            message: 'All learners declined. Booking rejected.',
            backgroundColor: Colors.orange,
            icon: Icons.info_outline,
          );
        }
      }
    } catch (e) {
      LogService.error('Error accepting learner: $e');
      if (!mounted) return;
      safeSetState(() => _isProcessing = false);
      BrandedSnackBar.showError(
        context,
        'Failed to accept learner: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Show dialog to decline a specific learner
  Future<void> _showDeclineLearnerDialog(String learnerName) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Decline $learnerName',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason (required):',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'E.g., Not teaching this subject, schedule conflict, etc.',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please provide a reason', style: GoogleFonts.poppins()),
                  ),
                );
                return;
              }
              Navigator.pop(context, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Decline',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _declineLearner(learnerName, result);
    }
  }

  /// Decline a specific learner
  Future<void> _declineLearner(String learnerName, String reason) async {
    try {
      safeSetState(() => _isProcessing = true);
      
      final requestId = widget.request['id'] as String;
      await BookingService.declineLearner(
        requestId,
        learnerName,
        reason: reason,
      );
      
      if (!mounted) return;
      
      // Reload request to get updated status
      final updatedRequest = await BookingService.getBookingRequestById(requestId);
      final updatedRequestData = updatedRequest.toJson();
      
      safeSetState(() {
        widget.request.clear();
        widget.request.addAll(updatedRequestData);
        _isProcessing = false;
      });
      
      BrandedSnackBar.show(
        context,
        message: '$learnerName declined',
        backgroundColor: Colors.orange,
        icon: Icons.info_outline,
      );
      
      // If all learners responded, show appropriate message
      if (updatedRequest.allLearnersResponded) {
        if (updatedRequest.isApproved) {
          BrandedSnackBar.show(
            context,
            message: 'Booking approved! Payment request created for accepted learners.',
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
          );
        } else if (updatedRequest.isRejected) {
          BrandedSnackBar.show(
            context,
            message: 'All learners declined. Booking rejected.',
            backgroundColor: Colors.orange,
            icon: Icons.info_outline,
          );
        }
      }
    } catch (e) {
      LogService.error('Error declining learner: $e');
      if (!mounted) return;
      safeSetState(() => _isProcessing = false);
      BrandedSnackBar.showError(
        context,
        'Failed to decline learner: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }
}
