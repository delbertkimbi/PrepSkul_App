import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenReject) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRejectDialog();
      });
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
      setState(() => _isProcessing = true);
      // TODO: Call API to approve
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request accepted successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
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
      setState(() => _isProcessing = true);
      // TODO: Call API to reject
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request declined', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.request['student'] as Map<String, dynamic>? ?? {};
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
          onPressed: () => Navigator.pop(context),
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

            // Student Card
            _buildStudentCard(student),
            const SizedBox(height: 24),

            // Schedule Section
            _buildSectionTitle('Requested Schedule'),
            const SizedBox(height: 16),
            _buildScheduleCard(),
            const SizedBox(height: 24),

            // Location Section
            _buildSectionTitle('Location'),
            const SizedBox(height: 16),
            _buildLocationCard(),
            const SizedBox(height: 24),

            // Revenue Section
            _buildSectionTitle('Revenue Details'),
            const SizedBox(height: 16),
            _buildRevenueCard(),

            const SizedBox(height: 32),

            // Action Buttons (for pending requests)
            if (isPending && !_isProcessing) ...[
              Row(
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
              ),
            ],
            if (_isProcessing) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: AssetImage(
              student['avatar_url'] ?? 'assets/images/prepskul_profile.png',
            ),
            onBackgroundImageError: (exception, stackTrace) {
              // Image failed to load, will show fallback
            },
            child: student['avatar_url'] == null
                ? Text(
                    (student['full_name'] ?? 'S')[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['full_name'] ?? 'Student',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: student['user_type'] == 'parent'
                        ? Colors.purple[100]
                        : Colors.blue[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    student['user_type'] == 'parent'
                        ? 'PARENT REQUEST'
                        : 'STUDENT REQUEST',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: student['user_type'] == 'parent'
                          ? Colors.purple[700]
                          : Colors.blue[700],
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

  Widget _buildScheduleCard() {
    final frequency = widget.request['frequency'] as int? ?? 0;
    final days = widget.request['days'] as List? ?? [];
    final times = widget.request['times'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Frequency', '$frequency sessions per week'),
          const SizedBox(height: 16),
          _buildDetailRow('Days', days.join(', ')),
          const SizedBox(height: 16),
          Text(
            'Session Times:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...days.map((day) {
            final time = times[day] ?? 'Not set';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$day: ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = widget.request['location'] as String? ?? 'Not specified';
    final address = widget.request['address'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Format', location.toUpperCase()),
          if (address != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow('Address', address),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    final monthlyTotal = widget.request['monthly_total'] as double? ?? 0.0;
    final paymentPlan = widget.request['payment_plan'] as String? ?? 'Not specified';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Revenue',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '${monthlyTotal.toStringAsFixed(0)} XAF',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Plan',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                paymentPlan.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _responseController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }
}
