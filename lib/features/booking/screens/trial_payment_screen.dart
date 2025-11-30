import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/core/utils/error_handler.dart';


/// Trial Payment Screen
/// 
/// Payment gate screen that appears after tutor approves trial session
/// Handles Fapshi payment initiation and polling

class TrialPaymentScreen extends StatefulWidget {
  final TrialSession trialSession;

  const TrialPaymentScreen({
    Key? key,
    required this.trialSession,
  }) : super(key: key);

  @override
  State<TrialPaymentScreen> createState() => _TrialPaymentScreenState();
}

class _TrialPaymentScreenState extends State<TrialPaymentScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isProcessing = false;
  bool _isPolling = false;
  String? _errorMessage;
  String _paymentStatus = 'idle'; // idle, pending, successful, failed
  String? _lastTransactionId; // Used to retry Meet link generation

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Pre-fill phone number from user profile
  Future<void> _loadUserPhone() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile != null && mounted) {
        final phone = userProfile['phone_number'] as String?;
        if (phone != null && phone.isNotEmpty) {
          setState(() {
            _phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      print('⚠️ Could not load user phone: $e');
    }
      return;
  }

  /// Initiate payment
  Future<void> _initiatePayment() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _paymentStatus = 'idle';
    });

    try {
      // Initiate payment via trial session service
      // Pass trial session to avoid unnecessary fetch
      final transId = await TrialSessionService.initiatePayment(
        sessionId: widget.trialSession.id,
        phoneNumber: _phoneController.text.trim(),
        trialSession: widget.trialSession,
      );

      setState(() {
        _paymentStatus = 'pending';
        _isProcessing = false;
        _isPolling = true;
      });

      // Start polling for payment status
      _pollPaymentStatus(transId);
    } catch (e) {
      String userMessage = 'Failed to initiate payment';
      final errorString = e.toString().toLowerCase();
      // Provide user-friendly error messages
      if (errorString.contains('failed to fetch') || 
          errorString.contains('clientexception') ||
          errorString.contains('network') ||
          errorString.contains('connection')) {
        userMessage = 'Network error: Please check your internet connection and try again.';
      } else if (errorString.contains('not authenticated') || 
                 errorString.contains('unauthorized')) {
        userMessage = 'Please sign in again to continue.';
      } else if (errorString.contains('already completed') ||
                 errorString.contains('already paid')) {
        userMessage = 'This payment has already been completed.';
      } else if (errorString.contains('approved') || 
                 errorString.contains('tutor')) {
        userMessage = 'Please wait for the tutor to approve this trial session before paying.';
      } else {
        userMessage = 'Failed to initiate payment. Please try again.';
      }
      setState(() {
        _errorMessage = userMessage;
        _isProcessing = false;
        _paymentStatus = 'failed';
      });
      print('❌ Payment initiation error: $e');
    }
  }

  /// Poll payment status
  Future<void> _pollPaymentStatus(String transId) async {
    try {
      final status = await FapshiService.pollPaymentStatus(
        transId,
        maxAttempts: 40, // 2 minutes max
        interval: const Duration(seconds: 3),
      );

      if (mounted) {
        setState(() {
          _isPolling = false;
          if (status.isSuccessful) {
            _paymentStatus = 'successful';
            // Complete payment and generate Meet link
            // Payment completion moved outside setState
          } else if (status.isFailed) {
            _paymentStatus = 'failed';
            _errorMessage = 'Payment failed. Please try again.';
          }
        });
        // Complete payment outside setState (async operation)
        if (status.isSuccessful) {
          final success = await _completePayment(transId);
          // Don't navigate here - let _completePayment handle it based on calendar status
          // If calendar is not connected, the button will be shown
          // If calendar is connected, navigation happens in _connectCalendarAndRetry
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPolling = false;
          _paymentStatus = 'failed';
          _errorMessage = 'Error checking payment status: $e';
        });
      }
    }
  }

  /// Sandbox helper: manually complete payment when the provider status API
  /// is not available, so we can still test the rest of the flow (calendar,
  /// Meet link, notifications, sessions list).
  Future<void> _forceCompleteSandbox() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final fakeTransId =
          'sandbox_manual_${DateTime.now().millisecondsSinceEpoch}';
      await _completePayment(fakeTransId); // Returns bool but we ignore it for sandbox
    } catch (e) {
      if (!mounted) // void function, no return needed
      setState(() {
        _errorMessage = 'Sandbox completion failed: $e';
      });
    } finally {
      if (!mounted) // void function, no return needed
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Complete payment and generate Meet link
  Future<bool> _completePayment(String transId) async {
    _lastTransactionId = transId;
    try {
      final calendarOk = await TrialSessionService.completePaymentAndGenerateMeet(
        sessionId: widget.trialSession.id,
        transactionId: transId,
      );

      if (!mounted) return false;

      // Update message if Calendar is not connected
      setState(() {
        if (!calendarOk) {
          _errorMessage =
              'Your payment is done and your lesson is booked.\n'
              'Next steps:\n'
              '• Open "My Sessions" to see the lesson and, when it is time, tap "Join meeting" there.\n'
              '• If you want the lesson to appear in your Google Calendar with a reminder, tap the button below to add it (optional).';
        } else {
          _errorMessage = null;
        }
      });

      // Always show a clear success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Always return true to indicate payment success, regardless of Calendar status
      // This ensures the parent screen reloads the requests list
      // Add a small delay to ensure database update is complete
      // Auto-navigation removed - user can manually navigate back
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'We saved your payment but could not finish saving the lesson. Please pull to refresh on the My Sessions page. If it is still empty, contact support.';
        });
      }
      return false;
    }
  }

  /// Connect Google Calendar (OAuth) and retry Meet link generation
  Future<void> _connectCalendarAndRetry() async {
    if (_lastTransactionId == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final ok = await GoogleCalendarAuthService.signIn();
    if (!ok) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'We couldn’t finish connecting to Google Calendar. Your payment and booking are safe — '
              'you can still find and join this session from the My Sessions screen. '
              'If this keeps happening, it’s likely a setup issue on our side.';
        });
      }
      return;
    }

    try {
      final success = await _completePayment(_lastTransactionId!);
      if (success && mounted) {
        // Calendar connected and payment completed - navigate to sessions page
        Navigator.pop(context, true); // Return true to indicate success
        // Navigate to sessions page
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pushNamed(context, '/student-nav', arguments: {'initialTab': 2}); // Sessions tab
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsCalendarAuth =
        _errorMessage != null && _errorMessage!.contains('Google Calendar');
    return WillPopScope(

      onWillPop: () async {

        // Return true if payment was successful, so parent screen refreshes

        if (_paymentStatus == 'successful') {

          return true; // This will trigger the .then() callback in parent

        }

        return true; // Always allow back navigation

      },

      child: Scaffold(
        backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Complete Payment',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Summary Card
                  _buildSessionSummary(),
                  const SizedBox(height: 24),

                  // Payment Amount Card
                  _buildPaymentAmount(),
                  const SizedBox(height: 24),

                  // Phone Number Input
                  if (_paymentStatus == 'idle' || _paymentStatus == 'failed')
                    _buildPhoneInput(),
                  const SizedBox(height: 24),

                  // Payment Status
                  if (_paymentStatus == 'pending' || _isPolling)
                    _buildPaymentPending(),
                  if (_paymentStatus == 'successful')
                    _buildPaymentSuccess(),
                  if (_paymentStatus == 'successful' && _errorMessage != null)
                    const SizedBox(height: 12),
                  if (_errorMessage != null) _buildErrorMessage(),

                  const SizedBox(height: 16),

                  // Action Buttons
                  if (_paymentStatus == 'idle' || _paymentStatus == 'failed')
                    _buildPayButton(),
                  if (needsCalendarAuth) _buildCalendarRetryButton(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
      ),

    );

  }

  Widget _buildSessionSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            'Trial Session Details',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Subject', widget.trialSession.subject),
          _buildDetailRow('Date', widget.trialSession.formattedDate),
          _buildDetailRow('Time', widget.trialSession.formattedTime),
          _buildDetailRow('Duration', widget.trialSession.formattedDuration),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAmount() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Total Amount',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              '${widget.trialSession.trialFee.toStringAsFixed(0)} XAF',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '670000000',
            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You will receive a payment request on this number',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPending() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Waiting for payment confirmation...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.orange[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please complete the payment on your mobile device',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSuccess() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Payment successful!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re all set for this lesson',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ??
                      'Your payment is done and your lesson is booked.\n'
                      'Next steps:\n'
                      '• Open "My Sessions" to see the lesson and, when it is time, tap "Join meeting" there.\n'
                      '• If you want the lesson to appear in your Google Calendar with a reminder, tap the button below to add it (optional).',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textDark,
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

  Widget _buildPayButton() {
    final isSandbox = !FapshiService.isProduction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _initiatePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Pay ${widget.trialSession.trialFee.toStringAsFixed(0)} XAF',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (isSandbox && _paymentStatus == 'failed') ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isProcessing ? null : _forceCompleteSandbox,
            child: Text(
              'Mark as paid (sandbox test)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sandbox only: this will simulate a successful payment so you can test calendar events and Meet links.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  /// Button to help the user add the lesson to Google Calendar (optional).
  Widget _buildCalendarRetryButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _isProcessing ? null : _connectCalendarAndRetry,
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
        label: Text(
          'Add this lesson to Google Calendar (optional)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      );
  }
}

