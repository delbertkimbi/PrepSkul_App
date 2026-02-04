import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Tutor Trial Card - Shows ONE trial session.
/// If trial has multiple learners (learnerLabels), shows all learners in the same card.
/// Tutor accepts/declines the single trial (one session, one price, regardless of learner count).
class TutorGroupTrialCard extends StatefulWidget {
  final TrialSession trial; // ONE trial session (may have multiple learners)
  final VoidCallback? onUpdated; // Callback when trial is accepted/rejected

  const TutorGroupTrialCard({
    Key? key,
    required this.trial,
    this.onUpdated,
  }) : super(key: key);

  @override
  State<TutorGroupTrialCard> createState() => _TutorGroupTrialCardState();
}

class _TutorGroupTrialCardState extends State<TutorGroupTrialCard> {
  final TextEditingController _rejectionReasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  List<String> get _learnerNames {
    if (widget.trial.learnerLabels != null && widget.trial.learnerLabels!.isNotEmpty) {
      return widget.trial.learnerLabels!;
    } else if (widget.trial.learnerLabel != null) {
      return [widget.trial.learnerLabel!];
    }
    return ['Learner'];
  }

  bool get _hasMultipleLearners => _learnerNames.length > 1;

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    safeSetState(() => _isProcessing = true);
    try {
      await TrialSessionService.approveTrialSession(widget.trial.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trial session accepted'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
        safeSetState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDecline() async {
    final reason = _rejectionReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for declining'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_isProcessing) return;
    safeSetState(() => _isProcessing = true);
    try {
      await TrialSessionService.rejectTrialSession(widget.trial.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trial session declined'),
            backgroundColor: Colors.orange,
          ),
        );
        _rejectionReasonController.clear();
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
        safeSetState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y').format(widget.trial.scheduledDate);
    final timeStr = widget.trial.scheduledTime;
    final locationStr = widget.trial.location == 'online' ? 'Online' : 'Onsite';
    final status = widget.trial.status;
    final isPending = status == 'pending';
    final isApproved = status == 'approved' || status == 'scheduled';
    final isRejected = status == 'rejected';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: Icon(
                    _hasMultipleLearners ? PhosphorIcons.users() : PhosphorIcons.user(),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasMultipleLearners
                            ? 'Trial session (${_learnerNames.length} learners)'
                            : 'Trial session request',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr at $timeStr • $locationStr',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                if (!isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isApproved ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isApproved ? 'Accepted' : 'Declined',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isApproved ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Learners list
            Text(
              _hasMultipleLearners ? 'Learners:' : 'Learner:',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            ..._learnerNames.map((name) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.user(), size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            // Subject and details
            _buildInfoRow(PhosphorIcons.book(), 'Subject', widget.trial.subject),
            const SizedBox(height: 8),
            _buildInfoRow(PhosphorIcons.clock(), 'Duration', '${widget.trial.durationMinutes} minutes'),
            if (widget.trial.trialGoal != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(PhosphorIcons.target(), 'Goal', widget.trial.trialGoal!),
            ],
            if (widget.trial.learnerChallenges != null && widget.trial.learnerChallenges!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(PhosphorIcons.warning(), 'Challenges', widget.trial.learnerChallenges!),
            ],
            // Action buttons (only for pending)
            if (isPending) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleDecline,
                      icon: Icon(PhosphorIcons.x(), size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleAccept,
                      icon: Icon(PhosphorIcons.check(), size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rejectionReasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for decline (required)',
                  hintText: 'e.g. Schedule conflict, not available for this subject',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(PhosphorIcons.note(), color: Colors.grey[600]),
                ),
                maxLines: 2,
              ),
            ] else if (isRejected && widget.trial.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIcons.info(), size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${widget.trial.rejectionReason}',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isProcessing) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
