import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/neumorphic_surface.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/widgets/image_picker_bottom_sheet.dart';
import 'package:prepskul/features/payment/services/kyc_verification_service.dart';
import 'package:prepskul/features/payment/widgets/kyc_mascot_illustration.dart';
import 'package:prepskul/features/payment/widgets/kyc_upload_card.dart';

enum IdentityVerificationMode { wizard, pending }

/// Progressive onsite/hybrid identity verification before first payment.
class IdentityVerificationFlowScreen extends StatefulWidget {
  final String paymentRequestId;
  final String? bookingRequestId;
  final IdentityVerificationMode mode;

  const IdentityVerificationFlowScreen({
    super.key,
    required this.paymentRequestId,
    this.bookingRequestId,
    this.mode = IdentityVerificationMode.wizard,
  });

  @override
  State<IdentityVerificationFlowScreen> createState() =>
      _IdentityVerificationFlowScreenState();
}

class _IdentityVerificationFlowScreenState
    extends State<IdentityVerificationFlowScreen> {
  static const int _totalSteps = 4;

  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _rejectionReason;

  String? _selectedWhoseId;
  String? _relationship;
  String? _selectedDocumentType;

  dynamic _frontFile;
  dynamic _backFile;
  dynamic _holdingFile;
  dynamic _locationFile;
  String? _frontFileName;
  String? _backFileName;
  String? _holdingFileName;
  String? _locationFileName;

  @override
  void initState() {
    super.initState();
    _loadRejectionIfAny();
  }

  Future<void> _loadRejectionIfAny() async {
    try {
      final state = await KycVerificationService.getVerificationStateForCurrentUser();
      if (mounted && state.isRejected) {
        safeSetState(() => _rejectionReason = state.rejectionReason);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentStep >= _totalSteps - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    safeSetState(() => _currentStep++);
  }

  void _goBack() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
      safeSetState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  bool get _canContinueStep2 =>
      _selectedWhoseId != null &&
      (_selectedWhoseId == 'self' ||
          (_relationship != null && _relationship!.trim().isNotEmpty));

  bool get _canSubmit =>
      _selectedDocumentType != null &&
      _frontFile != null &&
      _backFile != null &&
      _holdingFile != null &&
      _locationFile != null;

  Future<void> _pickFile(void Function(dynamic file, String name) onPicked) async {
    final picked = await showModalBottomSheet<dynamic>(
      context: context,
      builder: (context) => const ImagePickerBottomSheet(),
      isScrollControlled: true,
    );
    if (picked == null || !mounted) return;
    onPicked(picked, _inferFileName(picked));
  }

  String _inferFileName(dynamic file) {
    if (file is XFile && file.name.isNotEmpty) return file.name;
    return 'photo.jpg';
  }

  Future<void> _submit() async {
    if (!_canSubmit || _selectedWhoseId == null || _selectedDocumentType == null) {
      _showSnack('Please complete all uploads before submitting.');
      return;
    }

    safeSetState(() => _isSubmitting = true);
    try {
      await KycVerificationService.submitVerification(
        documentType: _selectedDocumentType!,
        whoseId: _selectedWhoseId!,
        relationship: _relationship,
        frontFile: _frontFile!,
        backFile: _backFile!,
        holdingFile: _holdingFile!,
        locationFile: _locationFile!,
        bookingRequestId: widget.bookingRequestId,
      );
      if (!mounted) return;
      safeSetState(() {
        _isSubmitting = false;
        _currentStep = 3;
      });
      await _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      if (!mounted) return;
      safeSetState(() => _isSubmitting = false);
      _showSnack(ErrorHandler.getUserFriendlyMessage(e), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? AppTheme.error : AppTheme.primaryColor,
      ),
    );
  }

  void _exitToRequests() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == IdentityVerificationMode.pending) {
      return _buildScaffold(
        title: 'Verification in progress',
        showProgress: false,
        body: _buildPendingBody(),
      );
    }

    return _buildScaffold(
      title: 'Identity verification',
      showProgress: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildIntroStep(),
          _buildWhoseStep(),
          _buildUploadsStep(),
          _buildSubmittedStep(),
        ],
      ),
    );
  }

  Widget _buildScaffold({
    required String title,
    required bool showProgress,
    required Widget body,
  }) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (showProgress) _buildProgressHeader(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: body,
              ),
            ),
          ),
          if (showProgress && _currentStep < 3) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: NeumorphicSurface.card(radius: 16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${_currentStep + 1} of $_totalSteps',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 5,
              backgroundColor: AppTheme.neutral200,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isUploadStep = _currentStep == 2;
    final canProceed = _currentStep == 0 ||
        (_currentStep == 1 && _canContinueStep2) ||
        (isUploadStep && _canSubmit && !_isSubmitting);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        boxShadow: NeumorphicSurface.raised,
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _goBack,
              child: Text(
                'Back',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              onPressed: canProceed
                  ? (isUploadStep ? _submit : _goNext)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: AppTheme.neutral300,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting && isUploadStep
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      isUploadStep ? 'Submit for review' : 'Continue',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_rejectionReason != null && _rejectionReason!.isNotEmpty)
            _buildRejectedBanner(),
          _buildStepEyebrow('What you\'ll need'),
          const SizedBox(height: 8),
          Text(
            'Verify once for onsite sessions',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'For everyone\'s safety, we verify who hosts the tutor before your first onsite or hybrid payment. This is a one-time check on your account.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          NeumorphicSurface.wrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Four photos required',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _requirementRow(Icons.credit_card, 'ID — front & back'),
                _requirementRow(Icons.face_retouching_natural, 'You holding your ID'),
                _requirementRow(Icons.home_work_outlined, 'Tutoring location'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoBox('Review usually takes under 24 hours. We\'ll notify you when you can pay.'),
        ],
      ),
    );
  }

  Widget _buildRejectedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
        boxShadow: NeumorphicSurface.inset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _rejectionReason!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoseStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepEyebrow('Whose ID'),
          const SizedBox(height: 8),
          Text(
            'Whose ID are you uploading?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Many learners use a parent or guardian\'s ID. Choose the option that fits your situation.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _whoseTile(
            'self',
            'My ID',
            'I am the learner or parent/guardian paying',
          ),
          _whoseTile(
            'parent_guardian',
            'Parent or guardian',
            'The responsible adult\'s ID',
          ),
          _whoseTile(
            'other_adult',
            'Other responsible adult',
            'Another adult hosting the tutor',
          ),
          if (_selectedWhoseId == 'parent_guardian' ||
              _selectedWhoseId == 'other_adult') ...[
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => safeSetState(() => _relationship = v),
              decoration: _fieldDecoration('Relationship (e.g. mother, guardian)'),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepEyebrow('Your photos'),
          const SizedBox(height: 8),
          Text(
            'Upload your documents',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap each card to add a clear photo. All four are required.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDocumentType,
            decoration: _fieldDecoration('Type of ID'),
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
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
            onChanged: (v) => safeSetState(() => _selectedDocumentType = v),
          ),
          const SizedBox(height: 16),
          KycUploadCard(
            title: 'ID — front',
            subtitle: 'Flat, well-lit photo of the front',
            isComplete: _frontFile != null,
            fileName: _frontFileName,
            previewFile: _frontFile,
            onTap: () => _pickFile((f, n) {
              safeSetState(() {
                _frontFile = f;
                _frontFileName = n;
              });
            }),
          ),
          const SizedBox(height: 10),
          KycUploadCard(
            title: 'ID — back',
            subtitle: 'Clear photo of the back side',
            isComplete: _backFile != null,
            fileName: _backFileName,
            previewFile: _backFile,
            onTap: () => _pickFile((f, n) {
              safeSetState(() {
                _backFile = f;
                _backFileName = n;
              });
            }),
          ),
          const SizedBox(height: 10),
          KycUploadCard(
            title: 'You holding your ID',
            subtitle: 'Your face and ID visible in one photo',
            isComplete: _holdingFile != null,
            fileName: _holdingFileName,
            previewFile: _holdingFile,
            onTap: () => _pickFile((f, n) {
              safeSetState(() {
                _holdingFile = f;
                _holdingFileName = n;
              });
            }),
          ),
          const SizedBox(height: 10),
          KycUploadCard(
            title: 'Tutoring location',
            subtitle: 'Room or area where lessons take place',
            isComplete: _locationFile != null,
            fileName: _locationFileName,
            previewFile: _locationFile,
            onTap: () => _pickFile((f, n) {
              safeSetState(() {
                _locationFile = f;
                _locationFileName = n;
              });
            }),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSubmittedStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const KycMascotIllustration(variant: KycMascotVariant.submitted),
          const SizedBox(height: 20),
          Text(
            'Documents submitted',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thank you. Our team is reviewing your verification. '
            'This is usually completed within 24 hours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _infoBox(
            'We\'ll notify you by push and in the app when you can complete payment.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _exitToRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back to my requests',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const KycMascotIllustration(variant: KycMascotVariant.pending),
          const SizedBox(height: 20),
          Text(
            'Under review',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your documents are being reviewed. Verification is usually completed within 24 hours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _infoBox(
            'You\'ll receive a notification when you can pay for onsite sessions. '
            'Tap Pay again anytime to check this status.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _exitToRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back to my requests',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepEyebrow(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppTheme.textLight,
      ),
    );
  }

  Widget _requirementRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeumorphicSurface.inset,
        border: Border.all(color: AppTheme.softBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whoseTile(String value, String title, String subtitle) {
    final selected = _selectedWhoseId == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => safeSetState(() {
            _selectedWhoseId = value;
            if (value == 'self') _relationship = null;
          }),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.white : AppTheme.neutral50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.softBorder,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected ? NeumorphicSurface.raised : NeumorphicSurface.inset,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppTheme.primaryColor : AppTheme.neutral400,
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

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textLight),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.softBorder),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.softBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
