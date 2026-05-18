import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Branded identity verification block for onsite/hybrid checkout.
class PaymentKycSection extends StatelessWidget {
  final String? kycStatus;
  final bool isSubmitting;
  final String? selectedWhoseId;
  final String? selectedDocumentType;
  final String? relationship;
  final String? frontFileName;
  final String? backFileName;
  final ValueChanged<String> onWhoseIdChanged;
  final ValueChanged<String?> onDocumentTypeChanged;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onSubmit;

  const PaymentKycSection({
    super.key,
    required this.kycStatus,
    required this.isSubmitting,
    required this.selectedWhoseId,
    required this.selectedDocumentType,
    required this.relationship,
    required this.frontFileName,
    required this.backFileName,
    required this.onWhoseIdChanged,
    required this.onDocumentTypeChanged,
    required this.onRelationshipChanged,
    required this.onPickFront,
    required this.onPickBack,
    required this.onSubmit,
  });

  bool get _isPending => kycStatus == 'pending';
  bool get _isRejected => kycStatus == 'rejected';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify your identity',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Required once for onsite & hybrid sessions. '
                        'Usually takes under 2 minutes.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.softBorder),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isPending) ...[
                  _buildStatusBanner(
                    icon: Icons.schedule_outlined,
                    iconColor: AppTheme.skyBlue,
                    background: AppTheme.skyBlueLight,
                    title: 'Under review',
                    body:
                        'We\'re checking your ID. You can complete payment as soon as we approve it — we\'ll notify you in the app.',
                  ),
                ] else if (_isRejected) ...[
                  _buildStatusBanner(
                    icon: Icons.info_outline,
                    iconColor: AppTheme.error,
                    background: const Color(0xFFFEF2F2),
                    title: 'Please try again',
                    body:
                        'Your last submission couldn\'t be verified. Upload a clear, well-lit photo of a valid government ID.',
                  ),
                  const SizedBox(height: 20),
                  _buildForm(context),
                ] else ...[
                  _buildForm(context),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        disabledBackgroundColor: AppTheme.neutral300,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Submit for review',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Your documents are encrypted and only used for safeguarding.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textLight,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Who is this ID for?'),
        const SizedBox(height: 10),
        _radioTile(
          title: 'My ID',
          subtitle: 'I am the learner or parent/guardian paying',
          value: 'self',
        ),
        _radioTile(
          title: 'Parent or guardian',
          subtitle: 'ID belongs to a parent/guardian',
          value: 'parent_guardian',
        ),
        _radioTile(
          title: 'Other responsible adult',
          subtitle: 'Another adult hosting the tutor onsite',
          value: 'other_adult',
        ),
        if (selectedWhoseId == 'parent_guardian' ||
            selectedWhoseId == 'other_adult') ...[
          const SizedBox(height: 12),
          TextField(
            onChanged: onRelationshipChanged,
            decoration: _inputDecoration('Relationship (e.g. mother, guardian)'),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        _sectionLabel('Document type'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedDocumentType,
          decoration: _inputDecoration('Select ID type'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textDark,
          ),
          items: const [
            DropdownMenuItem(value: 'national_id', child: Text('National ID')),
            DropdownMenuItem(value: 'passport', child: Text('Passport')),
            DropdownMenuItem(value: 'voter_card', child: Text('Voter card')),
            DropdownMenuItem(
              value: 'drivers_licence',
              child: Text('Driver’s licence'),
            ),
            DropdownMenuItem(
              value: 'residence_permit',
              child: Text('Residence permit'),
            ),
            DropdownMenuItem(value: 'school_id', child: Text('School ID')),
            DropdownMenuItem(
              value: 'other',
              child: Text('Other government-issued ID'),
            ),
          ],
          onChanged: onDocumentTypeChanged,
        ),
        const SizedBox(height: 24),
        _sectionLabel('Upload photos'),
        const SizedBox(height: 10),
        _uploadTile(
          label: frontFileName != null ? 'Front — selected' : 'Front of ID',
          hint: frontFileName ?? 'Tap to upload',
          isComplete: frontFileName != null,
          onTap: onPickFront,
        ),
        const SizedBox(height: 10),
        _uploadTile(
          label: backFileName != null ? 'Back — selected' : 'Back of ID (optional)',
          hint: backFileName ?? 'Tap to upload if available',
          isComplete: backFileName != null,
          onTap: onPickBack,
          optional: true,
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppTheme.textLight,
      ),
    );
  }

  Widget _radioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final selected = selectedWhoseId == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.primaryColor.withOpacity(0.04)
            : AppTheme.neutral50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onWhoseIdChanged(value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.softBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppTheme.primaryColor : AppTheme.neutral400,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadTile({
    required String label,
    required String hint,
    required bool isComplete,
    required VoidCallback onTap,
    bool optional = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: isComplete
                ? AppTheme.accentLightGreen.withOpacity(0.5)
                : AppTheme.neutral50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isComplete ? AppTheme.success : AppTheme.neutral300,
              width: isComplete ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppTheme.success.withOpacity(0.12)
                      : AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isComplete ? Icons.check_circle_outline : Icons.add_a_photo_outlined,
                  color: isComplete ? AppTheme.success : AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      hint,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (optional && !isComplete)
                Text(
                  'Optional',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textLight),
      filled: true,
      fillColor: AppTheme.neutral50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.softBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.softBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

/// Step indicator: Verify → Pay
class PaymentCheckoutSteps extends StatelessWidget {
  final int activeStep; // 0 = verify, 1 = pay

  const PaymentCheckoutSteps({super.key, required this.activeStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step(0, 'Verify', activeStep >= 0, activeStep == 0),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: activeStep >= 1
                ? AppTheme.primaryColor
                : AppTheme.neutral200,
          ),
        ),
        _step(1, 'Pay', activeStep >= 1, activeStep == 1),
      ],
    );
  }

  Widget _step(int index, String label, bool reached, bool current) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: current
                ? AppTheme.primaryColor
                : reached
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : AppTheme.neutral200,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: current ? Colors.white : AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: current ? FontWeight.w600 : FontWeight.w500,
            color: current ? AppTheme.primaryColor : AppTheme.textMedium,
          ),
        ),
      ],
    );
  }
}
