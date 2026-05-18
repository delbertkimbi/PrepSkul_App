/// Result of checking whether the current user can pay for onsite/hybrid bookings.
class KycVerificationState {
  final bool isVerified;
  final String? status; // null, pending, verified, rejected
  final String? rejectionReason;

  const KycVerificationState({
    required this.isVerified,
    this.status,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get needsSubmission => !isVerified && !isPending;

  static const verified = KycVerificationState(isVerified: true, status: 'verified');
}
