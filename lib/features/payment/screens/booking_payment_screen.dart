import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/payment/services/user_credits_service.dart';
import 'package:prepskul/features/payment/widgets/payment_instructions_widget.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';


/// Booking Payment Screen
/// 
/// Payment screen for regular booking payments
/// Auto-launched when tutor approves booking and payment request is created
/// Handles Fapshi payment initiation and polling

class BookingPaymentScreen extends StatefulWidget {
  final String paymentRequestId;
  final String? bookingRequestId; // Optional, for navigation back

  const BookingPaymentScreen({
    Key? key,
    required this.paymentRequestId,
    this.bookingRequestId,
  }) : super(key: key);

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isPolling = false;
  String? _errorMessage;
  String _paymentStatus = 'idle'; // idle, pending, successful, failed
  Map<String, dynamic>? _paymentRequest;
  String? _detectedProvider; // 'mtn' or 'orange'

  @override
  void initState() {
    super.initState();
    _loadPaymentRequest();
    _loadUserPhone();
    // Listen to phone number changes to detect provider
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  /// Detect provider when phone number changes
  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final provider = FapshiService.detectPhoneProvider(phone);
      if (mounted) {
        safeSetState(() {
          _detectedProvider = provider;
        });
      }
    } else {
      if (mounted) {
        safeSetState(() {
          _detectedProvider = null;
        });
      }
    }
  }

  /// Load payment request details
  Future<void> _loadPaymentRequest() async {
    try {
      final request = await PaymentRequestService.getPaymentRequest(widget.paymentRequestId);
      if (request != null && mounted) {
        safeSetState(() {
          _paymentRequest = request;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          safeSetState(() {
            _isLoading = false;
            _errorMessage = 'Payment request not found';
          });
        }
      }
    } catch (e) {
      LogService.error('Error loading payment request: $e');
      if (mounted) {
        safeSetState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        });
      }
    }
  }

  /// Pre-fill phone number from user profile
  Future<void> _loadUserPhone() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile != null && mounted) {
        final phone = userProfile['phone_number'] as String?;
        if (phone != null && phone.isNotEmpty) {
          safeSetState(() {
            _phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      LogService.warning('Could not load user phone: $e');
    }
  }

  /// Initiate payment
  Future<void> _initiatePayment() async {
    if (_paymentRequest == null) {
      safeSetState(() {
        _errorMessage = 'Payment request not loaded';
      });
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      safeSetState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
      _paymentStatus = 'idle';
    });

    try {
      final amount = (_paymentRequest!['amount'] as num).toDouble();
      final bookingRequestId = _paymentRequest!['booking_request_id'] as String?;

      // Initiate payment via PaymentService
      // Use payment_request_ prefix for webhook routing
      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: amount.toInt(),
        phone: _phoneController.text.trim(),
        externalId: 'payment_request_${widget.paymentRequestId}',
        userId: _paymentRequest!['student_id'] as String?,
        message: _paymentRequest!['description'] as String? ?? 'Booking payment',
      );

      // Update payment request with Fapshi transaction ID
      await PaymentRequestService.updatePaymentRequestStatus(
        widget.paymentRequestId,
        'pending',
        fapshiTransId: paymentResponse.transId,
      );

      // Detect provider for instructions
      final provider = FapshiService.detectPhoneProvider(_phoneController.text.trim());
      
      safeSetState(() {
        _paymentStatus = 'pending';
        _isProcessing = false;
        _isPolling = true;
        _detectedProvider = provider;
      });

      // Start polling for payment status
      _pollPaymentStatus(paymentResponse.transId);
    } catch (e) {
      final friendlyMessage = ErrorHandler.getUserFriendlyMessage(e);
      safeSetState(() {
        _errorMessage = friendlyMessage;
        _isProcessing = false;
        _paymentStatus = 'failed';
      });
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
        safeSetState(() {
          _isPolling = false;
          if (status.isSuccessful) {
            _paymentStatus = 'successful';
            // Update payment request status
            _completePayment(transId);
          } else if (status.isFailed) {
            _paymentStatus = 'failed';
            _errorMessage = 'Your payment was declined. Please check your mobile money balance and try again.';
            // Update payment request status
            PaymentRequestService.updatePaymentRequestStatus(
              widget.paymentRequestId,
              'failed',
              fapshiTransId: transId,
            );
          } else if (status.isPending) {
            // Still pending after max attempts - don't mark as failed
            // User might still be processing payment
            _paymentStatus = 'pending';
            _errorMessage = 'Payment is still pending. Please check your phone for the payment request and complete it.';
            LogService.info('Payment still pending after polling: $transId');
          } else {
            // Unknown status - don't mark as failed
            _paymentStatus = 'pending';
            _errorMessage = 'Payment status unknown. Please check your phone for the payment request.';
            LogService.warning('Unknown payment status: ${status.status}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _isPolling = false;
          _paymentStatus = 'failed';
          // Use user-friendly error message
          _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        });
      }
    }
  }

  /// Complete payment
  Future<void> _completePayment(String transId) async {
    try {
      LogService.info('Completing payment: ${widget.paymentRequestId}, transId: $transId');
      
      // Update payment request status to paid
      await PaymentRequestService.updatePaymentRequestStatus(
        widget.paymentRequestId,
        'paid',
        fapshiTransId: transId,
      );
      LogService.success('Payment request status updated to paid');

      // Convert payment to credits (idempotent - won't double-convert if webhook already processed)
      try {
        final amount = (_paymentRequest!['amount'] as num).toDouble();
        final credits = await UserCreditsService.convertPaymentToCredits(
          widget.paymentRequestId,
          amount,
        );
        
        LogService.success('Payment converted to credits: $credits credits');
        
        if (mounted) {
          // Show success with credits info
          BrandedSnackBar.showSuccess(
            context,
            'Payment successful! $credits credits added to your account.',
            duration: const Duration(seconds: 4),
          );
        }
      } catch (e) {
        // Check if credits were already converted (webhook may have processed it)
        if (e.toString().contains('already converted') || 
            e.toString().contains('duplicate')) {
          LogService.info('Credits already converted (likely by webhook)');
          if (mounted) {
            BrandedSnackBar.showSuccess(
              context,
              'Payment successful! Your booking is confirmed.',
              duration: const Duration(seconds: 3),
            );
          }
        } else {
          LogService.warning('Error converting payment to credits: $e');
          // Don't fail the payment if credit conversion fails
          if (mounted) {
            BrandedSnackBar.showSuccess(
              context,
              'Payment successful! Your booking is confirmed.',
              duration: const Duration(seconds: 3),
            );
          }
        }
      }

      if (mounted) {
        // Refresh payment request to show updated status
        await _loadPaymentRequest();
        
        // Navigate back after a short delay to allow user to see success message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success
          }
        });
      }
    } catch (e) {
      LogService.error('Error completing payment: $e');
      if (mounted) {
        safeSetState(() {
          _errorMessage = 'Payment completed but failed to update status: ${ErrorHandler.getUserFriendlyMessage(e)}';
          _paymentStatus = 'failed';
        });
        // Still show success message since payment went through
        BrandedSnackBar.showSuccess(
          context,
          'Payment received! Please refresh to see updated status.',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Payment',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_paymentRequest == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Payment',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Payment request not found',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final amount = (_paymentRequest!['amount'] as num).toDouble();
    final originalAmount = (_paymentRequest!['original_amount'] as num).toDouble();
    final discountAmount = (_paymentRequest!['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentPlan = _paymentRequest!['payment_plan'] as String? ?? 'monthly';
    final description = _paymentRequest!['description'] as String?;
    final metadata = _paymentRequest!['metadata'] as Map<String, dynamic>?;
    final tutorName = metadata?['tutor_name'] as String? ?? 'Tutor';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Summary Card
            _buildBookingSummary(tutorName, description, paymentPlan),
            const SizedBox(height: 24),

            // Payment Amount Card
            _buildPaymentAmount(amount, originalAmount, discountAmount),
            const SizedBox(height: 24),

            // Phone Number Input
            if (_paymentStatus == 'idle' || _paymentStatus == 'failed')
              _buildPhoneInput(),
            const SizedBox(height: 24),

            // Payment Instructions (shown when pending)
            if (_paymentStatus == 'pending' || _isPolling)
              PaymentInstructionsWidget(
                provider: _detectedProvider,
                phoneNumber: _phoneController.text.trim(),
              ),
            
            // Payment Status
            if (_paymentStatus == 'pending' || _isPolling)
              _buildPaymentPending(),
            if (_paymentStatus == 'successful')
              _buildPaymentSuccess(),
            if (_errorMessage != null)
              _buildErrorMessage(),

            // Action Button
            if (_paymentStatus == 'idle' || _paymentStatus == 'failed')
              _buildPayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummary(String tutorName, String? description, String paymentPlan) {
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
          Row(
            children: [
              Icon(Icons.school, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Booking Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (description != null) ...[
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Tutor: $tutorName',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Payment Plan: ${paymentPlan.toUpperCase()}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAmount(double amount, double originalAmount, double discountAmount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Amount',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (discountAmount > 0) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PricingService.formatPrice(originalAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Save ${PricingService.formatPrice(discountAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discount for ${_paymentRequest!['payment_plan']?.toString().toUpperCase() ?? 'upfront'} payment',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
              Text(
                PricingService.formatPrice(amount),
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Phone Number',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            // Provider badge
            if (_detectedProvider != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PaymentProviderHelper.getProviderColor(_detectedProvider).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: PaymentProviderHelper.getProviderColor(_detectedProvider).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PaymentProviderHelper.getProviderIcon(_detectedProvider),
                      size: 16,
                      color: PaymentProviderHelper.getProviderColor(_detectedProvider),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      PaymentProviderHelper.getProviderName(_detectedProvider),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PaymentProviderHelper.getProviderColor(_detectedProvider),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '67XXXXXXX (MTN) or 69XXXXXXX (Orange)',
            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _detectedProvider != null
                      ? PaymentProviderHelper.getConfirmationMessage(_detectedProvider)
                      : 'A payment request will be sent to this number. You\'ll need to approve it in your mobile money app.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPending() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Waiting for payment confirmation...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Please follow the instructions above to confirm the payment on your phone.\n\n'
            'This screen will update automatically once you complete the payment.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.orange.shade800,
              height: 1.5,
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
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Payment successful! Your booking is confirmed.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.green.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Pay ${PricingService.formatPrice((_paymentRequest!['amount'] as num).toDouble())}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
