import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/core/utils/error_handler.dart';


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

  @override
  void initState() {
    super.initState();
    _loadPaymentRequest();
    _loadUserPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Load payment request details
  Future<void> _loadPaymentRequest() async {
    try {
      final request = await PaymentRequestService.getPaymentRequest(widget.paymentRequestId);
      if (request != null && mounted) {
        setState(() {
          _paymentRequest = request;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Payment request not found';
          });
        }
      }
    } catch (e) {
      print('❌ Error loading payment request: $e');
      if (mounted) {
        setState(() {
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
          setState(() {
            _phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      print('⚠️ Could not load user phone: $e');
    }
  }

  /// Initiate payment
  Future<void> _initiatePayment() async {
    if (_paymentRequest == null) {
      setState(() {
        _errorMessage = 'Payment request not loaded';
      });
      return;
    }

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

      setState(() {
        _paymentStatus = 'pending';
        _isProcessing = false;
        _isPolling = true;
      });

      // Start polling for payment status
      _pollPaymentStatus(paymentResponse.transId);
    } catch (e) {
      final friendlyMessage = ErrorHandler.getUserFriendlyMessage(e);
      setState(() {
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
        setState(() {
          _isPolling = false;
          if (status.isSuccessful) {
            _paymentStatus = 'successful';
            // Update payment request status
            _completePayment(transId);
          } else if (status.isFailed) {
            _paymentStatus = 'failed';
            _errorMessage = 'Payment failed. Please try again.';
            // Update payment request status
            PaymentRequestService.updatePaymentRequestStatus(
              widget.paymentRequestId,
              'failed',
              fapshiTransId: transId,
            );
          }
        });
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

  /// Complete payment
  Future<void> _completePayment(String transId) async {
    try {
      // Update payment request status to paid
      await PaymentRequestService.updatePaymentRequestStatus(
        widget.paymentRequestId,
        'paid',
        fapshiTransId: transId,
      );

      if (mounted) {
        // Show success
        BrandedSnackBar.showSuccess(
          context,
          'Payment successful! Your booking is confirmed.',
          duration: const Duration(seconds: 3),
        );

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Payment completed but failed to update status: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
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
        backgroundColor: Colors.grey[50],
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
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Payment request not found',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[700],
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
                color: Colors.grey[700],
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
              color: Colors.grey[600],
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
              color: Colors.grey[700],
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
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Save ${PricingService.formatPrice(discountAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
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
            hintText: 'Enter your phone number',
            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
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
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Processing payment... Please complete the payment on your phone.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.blue[900],
              ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Payment successful! Your booking is confirmed.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.green[900],
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
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red[900],
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

