import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/whatsapp_support_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/payment/services/fapshi_webhook_service.dart';
import 'package:prepskul/features/payment/services/user_credits_service.dart';
import 'package:prepskul/features/payment/widgets/payment_instructions_widget.dart';
import 'package:prepskul/features/payment/widgets/animated_checkmark.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/payment/services/kyc_verification_service.dart';
import 'package:prepskul/core/widgets/image_picker_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/features/booking/services/recurring_session_service.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/features/payment/screens/payment_confirmation_screen.dart';

/// Booking Payment Screen
///
/// Professional multi-step payment flow for recurring booking payments.
/// Combined view: Session Details, Phone Entry, Payment Breakdown, Pay.
/// After Pay → PaymentConfirmationScreen (logos, confetti, status).

class BookingPaymentScreen extends StatefulWidget {
  final String paymentRequestId;
  final String? bookingRequestId;

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
  final PageController _pageController = PageController();
  
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isPolling = false;
  String? _errorMessage;
  String _paymentStatus = 'idle';
  Map<String, dynamic>? _paymentRequest;
  String? _detectedProvider;
  int _currentStep = 0; // 0: Combined view, 2: Confirmation (after Pay)

  // Payment calculations
  double _subtotal = 0.0;
  double _charges = 0.0;
  double _total = 0.0;

  // KYC / identity verification state
  bool _isKycRequired = false; // Only for onsite/hybrid + not yet verified
  String? _kycStatus; // null, 'pending', 'verified', 'rejected'
  bool _isSubmittingKyc = false;
  String? _selectedDocumentType; // e.g. 'national_id'
  String? _selectedWhoseId; // 'self', 'parent_guardian', 'other_adult'
  String? _relationship;
  dynamic _kycFrontFile;
  dynamic _kycBackFile;
  String? _kycFrontFileName;
  String? _kycBackFileName;

  @override
  void initState() {
    super.initState();
    _loadPaymentRequest();
    _loadUserPhone();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

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

  Future<void> _loadPaymentRequest() async {
    try {
      final request = await PaymentRequestService.getPaymentRequest(widget.paymentRequestId);
      if (request != null && mounted) {
        final originalAmount = (request['original_amount'] as num?)?.toDouble() ?? 
                              (request['amount'] as num).toDouble();
        final charges = originalAmount * 0.02;
        final total = originalAmount + charges;
        safeSetState(() {
          _paymentRequest = request;
          _subtotal = originalAmount;
          _charges = charges;
          _total = total;
          _isLoading = false;
        });

        // After loading payment request, determine if KYC is required for this payment
        await _evaluateKycRequirement();
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

  /// Determine if identity verification (KYC) is required for this payment.
  ///
  /// KYC is required when:
  /// - The underlying booking location is onsite or hybrid, AND
  /// - The account is not yet marked identity verified.
  Future<void> _evaluateKycRequirement() async {
    try {
      final request = _paymentRequest;
      if (request == null) return;

      // Metadata contains booking location for this payment request
      final metadata = request['metadata'] as Map<String, dynamic>?;
      final location = metadata?['location'] as String? ?? '';
      final isOnsiteLike = location == 'onsite' || location == 'hybrid';

      if (!isOnsiteLike) {
        // Online-only or unknown location: no KYC gate
        if (mounted) {
          safeSetState(() {
            _isKycRequired = false;
            _kycStatus = null;
          });
        }
        return;
      }

      // Fetch latest verification status for current user
      final latest = await KycVerificationService.getLatestVerificationForCurrentUser();

      if (!mounted) return;

      if (latest == null) {
        // No record and not identity_verified_at -> require KYC
        safeSetState(() {
          _isKycRequired = true;
          _kycStatus = null;
        });
      } else {
        final status = latest['status'] as String? ?? 'pending';
        safeSetState(() {
          _kycStatus = status;
          _isKycRequired = status != 'verified';
        });
      }
    } catch (e) {
      // If KYC check fails, log but do not block payment completely
      LogService.error('Error evaluating KYC requirement: $e');
      if (mounted) {
        safeSetState(() {
          // Fail open: do not require KYC if check itself fails
          _isKycRequired = false;
        });
      }
    }
  }

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

  void _navigateToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    safeSetState(() {
      _currentStep = step;
    });
  }

  bool get _canInitiatePayment {
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    final hasProvider = _detectedProvider != null;
    final kycOk = !_isKycRequired || _kycStatus == 'verified';
    return hasPhone && hasProvider && !_isProcessing && kycOk;
  }

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

    // Validate and normalize phone number (same as trial payment)
    final phone = _phoneController.text.trim();
    String? normalizedPhone;
    try {
      // Normalize phone number (remove non-digits, handle country code)
      final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.startsWith('237')) {
        normalizedPhone = digitsOnly.substring(3);
      } else if (digitsOnly.startsWith('67') || digitsOnly.startsWith('69') ||
                 digitsOnly.startsWith('65') || digitsOnly.startsWith('66') ||
                 digitsOnly.startsWith('68')) {
        normalizedPhone = digitsOnly;
      } else {
        safeSetState(() {
          _errorMessage = 'Please enter a valid phone number (67XXXXXXX or 69XXXXXXX)';
          _isProcessing = false;
        });
        return;
      }
      
      if (normalizedPhone.length != 9) {
        safeSetState(() {
          _errorMessage = 'Please enter a valid phone number (67XXXXXXX or 69XXXXXXX)';
          _isProcessing = false;
        });
        return;
      }
    } catch (_) {
      safeSetState(() {
        _errorMessage = 'Please enter a valid phone number (67XXXXXXX or 69XXXXXXX)';
        _isProcessing = false;
      });
      return;
    }

    final provider = FapshiService.detectPhoneProvider(normalizedPhone!);
    
    String? transId;
    try {
      // Use total amount (subtotal + charges) for payment
      final amountToCharge = _total.toInt();

      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: amountToCharge,
        phone: normalizedPhone,
        externalId: 'payment_request_${widget.paymentRequestId}',
        userId: _paymentRequest!['student_id'] as String?,
        message: _paymentRequest!['description'] as String? ?? 'Booking payment',
      );

      transId = paymentResponse.transId;

      await PaymentRequestService.updatePaymentRequestStatus(
        widget.paymentRequestId,
        'pending',
        fapshiTransId: transId,
      );
    } catch (e) {
      // Even if payment initiation fails, navigate to confirmation screen
      // The new screen will handle the error and show appropriate message
      LogService.error('Error initiating payment: $e');
      
      // If we got a transaction ID before the error, use it
      // Otherwise, create a placeholder for sandbox mode
      if (transId == null && !FapshiService.isProduction) {
        transId = 'sandbox_error_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
    
    // Navigate to PaymentConfirmationScreen (same flow as recurring: nice UX, logos, confetti)
    if (mounted && transId != null) {
      safeSetState(() {
        _isProcessing = false;
        _detectedProvider = provider;
        _currentStep = 2;
      });
      final result = await Navigator.pushReplacement<bool, void>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentConfirmationScreen(
            provider: provider,
            phoneNumber: normalizedPhone!,
            amount: _total,
            transactionId: transId!,
            isSandbox: !FapshiService.isProduction,
            onPaymentComplete: (transId) async {
              try {
                await _completePayment(transId);
                return true;
              } catch (e) {
                LogService.error('Error completing payment: $e');
                return true;
              }
            },
          ),
        ),
      );
      if (result == true && mounted) {
        _showSuccessDialog();
      }
    } else if (transId == null) {
      // Only show error if we couldn't create a transaction ID at all
      final friendlyMessage = ErrorHandler.getUserFriendlyMessage(
        Exception('Payments are temporarily unavailable. Please try again later.')
      );
      safeSetState(() {
        _errorMessage = friendlyMessage;
        _isProcessing = false;
        _paymentStatus = 'failed';
      });
    }
  }

  Future<void> _pollPaymentStatus(String transId) async {
    try {
      final status = await FapshiService.pollPaymentStatus(
        transId,
        maxAttempts: 40,
        interval: const Duration(seconds: 3),
      );

      if (mounted) {
        if (status.isSuccessful) {
          _paymentStatus = 'successful';
          await _completePayment(transId);
          if (mounted) {
            safeSetState(() {
              _isPolling = false;
            });
          }
        } else {
          safeSetState(() {
            _isPolling = false;
            if (status.isFailed) {
              _paymentStatus = 'failed';
              _errorMessage = 'Your payment was declined. Please check your mobile money balance and try again.';
            } else if (status.isPending) {
              _paymentStatus = 'pending';
              _errorMessage = 'Payment is still pending. Please check your phone for the payment request and complete it.';
            } else {
              _paymentStatus = 'pending';
              _errorMessage = 'Payment status unknown. Please check your phone for the payment request.';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _isPolling = false;
          _paymentStatus = 'failed';
          _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        });
      }
    }
  }

  /// Sandbox helper: manually complete payment when the provider status API
  /// is not available, so we can still test the rest of the flow (session generation,
  /// notifications, sessions list).
  Future<void> _forceCompleteSandbox() async {
    safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final fakeTransId = 'sandbox_manual_${DateTime.now().millisecondsSinceEpoch}';
      LogService.info('🧪 Sandbox: Simulating payment success with transId: $fakeTransId');
      await _completePayment(fakeTransId);
    } catch (e) {
      LogService.error('❌ Sandbox completion failed: $e');
      if (mounted) {
        safeSetState(() {
          _errorMessage = 'Sandbox completion failed: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _completePayment(String transId) async {
    try {
      LogService.info('Completing payment: ${widget.paymentRequestId}, transId: $transId');
      
      // Check if payment is already processed (idempotency)
      final currentPaymentRequest = await PaymentRequestService.getPaymentRequest(widget.paymentRequestId);
      if (currentPaymentRequest != null) {
        final currentStatus = currentPaymentRequest['status'] as String?;
        if (currentStatus == 'paid') {
          LogService.info('Payment already processed as paid. Triggering webhook handler to ensure sessions are created...');
          // Payment already paid, but ensure webhook processing happens
          await FapshiWebhookService.handleWebhook(
            transactionId: transId,
            status: 'SUCCESS',
            externalId: 'payment_request_${widget.paymentRequestId}',
          );
          if (mounted) {
            // Show success dialog immediately without loading payment request first
            // This prevents the blank page issue
            _showSuccessDialog();
            // Load payment request in background
            _loadPaymentRequest();
          }
          return;
        }
      }
      
      // Update payment request status
      await PaymentRequestService.updatePaymentRequestStatus(
        widget.paymentRequestId,
        'paid',
        fapshiTransId: transId,
      );
      LogService.success('Payment request status updated to paid');

      // Trigger webhook handler to process payment and generate sessions
      try {
        LogService.info('🔄 Triggering webhook handler for payment: ${widget.paymentRequestId}, transId: $transId');
        await FapshiWebhookService.handleWebhook(
          transactionId: transId,
          status: 'SUCCESS',
          externalId: 'payment_request_${widget.paymentRequestId}',
        );
        LogService.success('✅ Webhook handler completed successfully');
        
        // Wait a moment and verify sessions were created
        await Future.delayed(const Duration(seconds: 3));
        final paymentRequest = await PaymentRequestService.getPaymentRequest(widget.paymentRequestId);
        if (paymentRequest != null) {
          final recurringSessionId = paymentRequest['recurring_session_id'] as String?;
          if (recurringSessionId != null) {
            final verifySessions = await SupabaseService.client
                .from('individual_sessions')
                .select('id, scheduled_date, status')
                .eq('recurring_session_id', recurringSessionId)
                .limit(5);
            LogService.info('🔍 Verification: Found ${verifySessions.length} sessions for recurring_session_id: $recurringSessionId');
            if (verifySessions.isNotEmpty) {
              LogService.success('✅ Sample session dates: ${verifySessions.map((s) => '${s['scheduled_date']} (${s['status']})').join(', ')}');
            } else {
              LogService.warning('⚠️ No sessions found after generation. This may indicate an issue with session generation.');
            }
          } else {
            LogService.warning('⚠️ No recurring_session_id found in payment request. Attempting to create recurring session and generate sessions...');
            // Fallback: If webhook didn't create recurring session, try to create it now
            try {
              final paymentRequest = await PaymentRequestService.getPaymentRequest(widget.paymentRequestId);
              if (paymentRequest != null) {
                final bookingRequestId = paymentRequest['booking_request_id'] as String?;
                if (bookingRequestId != null) {
                  LogService.info('🔧 Fallback: Creating recurring session from booking request...');
                  final bookingRequestData = await SupabaseService.client
                      .from('booking_requests')
                      .select()
                      .eq('id', bookingRequestId)
                      .maybeSingle();
                  
                  if (bookingRequestData != null) {
                    final bookingRequest = BookingRequest.fromJson(bookingRequestData);
                    final recurringSessionData = await RecurringSessionService.createRecurringSessionFromBooking(
                      bookingRequest,
                      paymentRequestId: widget.paymentRequestId,
                    );
                    
                    final recurringSessionId = recurringSessionData['id'] as String;
                    LogService.success('✅ Fallback: Created recurring session: $recurringSessionId');
                    
                    // Generate sessions
                    final sessionsGenerated = await RecurringSessionService.generateIndividualSessions(
                      recurringSessionId: recurringSessionId,
                      weeksAhead: 8,
                    );
                    LogService.success('✅ Fallback: Generated $sessionsGenerated individual sessions');
                  }
                }
              }
            } catch (fallbackError) {
              LogService.error('❌ Fallback session creation failed: $fallbackError');
            }
          }
        }
      } catch (e, stackTrace) {
        LogService.error('❌ Error triggering webhook handler: $e');
        LogService.error('Stack trace: $stackTrace');
        // Continue even if webhook fails - it may have already been processed
      }

      try {
        final credits = await UserCreditsService.convertPaymentToCredits(
          widget.paymentRequestId,
          _subtotal, // Use subtotal for credits, not total with charges
        );
        
        LogService.success('Payment converted to credits: $credits credits');
      } catch (e) {
        if (e.toString().contains('already converted') || 
            e.toString().contains('duplicate')) {
          LogService.info('Credits already converted (likely by webhook)');
        } else {
          LogService.warning('Error converting payment to credits: $e');
        }
      }

      if (mounted) {
        // Show success dialog immediately - this will hide the processing overlay
        _showSuccessDialog();
        // Load payment request in background (non-blocking)
        _loadPaymentRequest().then((_) {
          // After dialog is shown and data loaded, hide processing overlay
          if (mounted) {
            safeSetState(() {
              _isPolling = false;
            });
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
      }
    }
  }

  void _showSuccessDialog() {
    final confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Trigger confetti animation after dialog is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          confettiController.play();
        });
        
        return Stack(
          children: [
            Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Success Checkmark
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AnimatedCheckmark(
                          color: const Color(0xFF4CAF50), // Light green
                          size: 60,
                          animationDuration: const Duration(milliseconds: 1000),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Success Title
                    Text(
                      'Payment Successful!',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Success Message
                    Text(
                      'Your booking payment has been confirmed. Your sessions are now active!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          confettiController.dispose();
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context, true); // Return to previous screen
                          
                          // Navigate to sessions screen to show newly created sessions
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/student-nav',
                              (route) => route.isFirst,
                              arguments: {'initialTab': 2}, // Sessions tab
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Done',
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
              ),
            ),
            // Confetti overlay
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: confettiController,
                  blastDirection: 3.14 / 2, // Upward
                  maxBlastForce: 8,
                  minBlastForce: 3,
                  emissionFrequency: 0.03,
                  numberOfParticles: 80,
                  gravity: 0.15,
                  shouldLoop: false,
                  colors: [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                    AppTheme.primaryColor,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
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
            'Complete Payment',
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

    final paymentPlan = _paymentRequest!['payment_plan'] as String? ?? 'monthly';
    final description = _paymentRequest!['description'] as String?;
    final metadata = _paymentRequest!['metadata'] as Map<String, dynamic>?;
    final tutorName = metadata?['tutor_name'] as String? ?? 'Tutor';

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Complete Payment',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _currentStep == 2
          ? _buildPaymentConfirmationStep()
          : _buildCombinedPaymentView(tutorName, description, paymentPlan),
    );
  }

  Widget _buildCombinedPaymentView(String tutorName, String? description, String paymentPlan) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactBookingSummary(tutorName, description, paymentPlan),
          const SizedBox(height: 16),
          _buildInlinePhoneInput(),
          const SizedBox(height: 16),
          _buildCompactPaymentBreakdown(),
          const SizedBox(height: 16),
          if (_isKycRequired) _buildKycBlock(),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            _buildCompactErrorMessage(),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canInitiatePayment ? _initiatePayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: AppTheme.primaryColor.withOpacity(0.3),
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
                      'Pay ${PricingService.formatPrice(_total)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildKycBlock() {
    final isPending = _kycStatus == 'pending';
    final isVerified = _kycStatus == 'verified';
    final isRejected = _kycStatus == 'rejected';

    // If already verified, hide the block (safety net)
    if (isVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Identity verification for onsite bookings',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'For onsite sessions, we verify who is hosting the tutor once per account. '
            'Upload an ID (National ID, Passport, Voter card, or Driver’s licence) to complete this first onsite booking.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (isPending)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentOrange.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top, size: 18, color: AppTheme.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your identity verification is under review. Once approved, you’ll be able to complete payment for onsite bookings.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.accentOrange,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isPending) const SizedBox(height: 8),
          if (isRejected)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your previous verification was not approved. Please review your details and upload clear photos of the ID.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isRejected) const SizedBox(height: 12),
          if (!isPending) ...[
            _buildKycForm(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingKyc ? null : _submitKyc,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmittingKyc
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Submit verification',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Once your identity is verified, you’ll be able to complete payment for onsite sessions. This is a one-time step per account.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textMedium,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKycForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Whose ID?
        Text(
          'Whose ID are you uploading?',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip(
              label: 'My ID (I am the parent/guardian)',
              value: 'self',
              groupValue: _selectedWhoseId,
              onSelected: (val) {
                safeSetState(() {
                  _selectedWhoseId = val;
                  _relationship = null;
                });
              },
            ),
            _buildChoiceChip(
              label: 'Parent/guardian ID',
              value: 'parent_guardian',
              groupValue: _selectedWhoseId,
              onSelected: (val) {
                safeSetState(() {
                  _selectedWhoseId = val;
                });
              },
            ),
            _buildChoiceChip(
              label: 'Other responsible adult',
              value: 'other_adult',
              groupValue: _selectedWhoseId,
              onSelected: (val) {
                safeSetState(() {
                  _selectedWhoseId = val;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedWhoseId == 'parent_guardian' || _selectedWhoseId == 'other_adult')
          TextField(
            decoration: InputDecoration(
              labelText: 'Relationship (e.g. mother, uncle, guardian)',
              labelStyle: GoogleFonts.poppins(fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 13),
            onChanged: (value) {
              safeSetState(() {
                _relationship = value;
              });
            },
          ),
        const SizedBox(height: 12),
        // Document type
        Text(
          'Type of document',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDocumentType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(
              value: 'national_id',
              child: Text('National ID'),
            ),
            DropdownMenuItem(
              value: 'passport',
              child: Text('Passport'),
            ),
            DropdownMenuItem(
              value: 'voter_card',
              child: Text('Voter card'),
            ),
            DropdownMenuItem(
              value: 'drivers_licence',
              child: Text('Driver’s licence'),
            ),
            DropdownMenuItem(
              value: 'residence_permit',
              child: Text('Residence permit'),
            ),
            DropdownMenuItem(
              value: 'other',
              child: Text('Other government-issued ID'),
            ),
          ],
          onChanged: (value) {
            safeSetState(() {
              _selectedDocumentType = value;
            });
          },
        ),
        const SizedBox(height: 12),
        // Front / back upload
        Text(
          'Upload ID photos',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickKycFile(isFront: true),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(
                  _kycFrontFileName != null ? 'ID front selected' : 'Upload ID front',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickKycFile(isFront: false),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(
                  _kycBackFileName != null ? 'Back selected' : 'Upload back (optional)',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Clear photo of the ID is enough — this is a one-time step.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String value,
    required String? groupValue,
    required void Function(String value) onSelected,
  }) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Future<void> _pickKycFile({required bool isFront}) async {
    try {
      final pickedFile = await showModalBottomSheet<dynamic>(
        context: context,
        builder: (context) => const ImagePickerBottomSheet(),
        isScrollControlled: true,
      );
      if (pickedFile == null || !mounted) return;

      safeSetState(() {
        if (isFront) {
          _kycFrontFile = pickedFile;
          _kycFrontFileName = _inferFileName(pickedFile);
        } else {
          _kycBackFile = pickedFile;
          _kycBackFileName = _inferFileName(pickedFile);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to pick file: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _inferFileName(dynamic file) {
    try {
      // XFile has .name, PlatformFile has .name, File has path
      if (file is XFile) {
        return file.name.isNotEmpty ? file.name : 'selected_image.jpg';
      }
      // Fallback: best-effort string
      return 'selected_file';
    } catch (_) {
      return 'selected_file';
    }
  }

  Future<void> _submitKyc() async {
    if (_selectedDocumentType == null ||
        _selectedWhoseId == null ||
        _kycFrontFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select whose ID, choose a document type, and upload the front of the ID.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    safeSetState(() {
      _isSubmittingKyc = true;
    });

    try {
      await KycVerificationService.submitVerification(
        documentType: _selectedDocumentType!,
        whoseId: _selectedWhoseId!,
        relationship: _relationship,
        frontFile: _kycFrontFile,
        backFile: _kycBackFile,
      );

      if (!mounted) return;
      safeSetState(() {
        _isSubmittingKyc = false;
        _kycStatus = 'pending';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification submitted. We will review and notify you once it is approved.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _isSubmittingKyc = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.getUserFriendlyMessage(e),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCompactBookingSummary(String tutorName, String? description, String paymentPlan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Details',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tutorName,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Inline Phone Input with Provider Badge
  Widget _buildInlinePhoneInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                  color: AppTheme.textDark,
                ),
              ),
              // Provider badge inline
              if (_detectedProvider != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PaymentProviderHelper.getProviderColor(_detectedProvider).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                        size: 14,
                        color: PaymentProviderHelper.getProviderColor(_detectedProvider),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        PaymentProviderHelper.getProviderName(_detectedProvider),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
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
              prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (_detectedProvider == null && _phoneController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please enter a valid MTN or Orange number',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.accentOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Compact Payment Breakdown
  Widget _buildCompactPaymentBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
              Text(
                PricingService.formatPrice(_subtotal),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Charges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Charges (2%)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
              Text(
                PricingService.formatPrice(_charges),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.softBorder),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                PricingService.formatPrice(_total),
                style: GoogleFonts.poppins(
                  fontSize: 18,
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
  
  // Compact Error Message
  Widget _buildCompactErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppTheme.accentOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'An error occurred',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Payment Summary
  Widget _buildPaymentSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Summary Header
          Text(
            'Payment Summary',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 24),

          // Payment Breakdown Card
          Container(
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
              children: [
                // Subtotal
                _buildSummaryRow(
                  'Subtotal',
                  PricingService.formatPrice(_subtotal),
                  isTotal: false,
                ),
                const SizedBox(height: 16),
                
                // Divider
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 16),
                
                // Charges
                _buildSummaryRow(
                  'Payment Charges (2%)',
                  PricingService.formatPrice(_charges),
                  isTotal: false,
                  isCharges: true,
                ),
                const SizedBox(height: 20),
                
                // Total
                _buildSummaryRow(
                  'Total Amount',
                  PricingService.formatPrice(_total),
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Payment Method Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  _detectedProvider == 'mtn' 
                      ? Icons.phone_android 
                      : Icons.phone_iphone,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _detectedProvider != null
                            ? PaymentProviderHelper.getProviderName(_detectedProvider)
                            : 'Mobile Money',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _phoneController.text.trim(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Pay Now Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
                      'Pay ${PricingService.formatPrice(_total)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  // Step 3: Payment Confirmation
  Widget _buildPaymentConfirmationStep() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Payment Instructions (centered card)
              if (_paymentStatus == 'pending' || _isPolling)
                PaymentInstructionsWidget(
                  provider: _detectedProvider,
                  phoneNumber: _phoneController.text.trim(),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
        
        // Processing Overlay (shown while polling)
        if (_isPolling)
          _buildProcessingOverlay(),
      ],
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
        if (_detectedProvider == null && _phoneController.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please enter a valid MTN or Orange number',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isTotal = false, bool isCharges = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppTheme.textDark : Colors.grey.shade700,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: isTotal ? AppTheme.primaryColor : (isCharges ? Colors.grey.shade700 : AppTheme.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPending() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for payment confirmation...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
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
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.85), // Increased opacity for better visibility
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Processing payment...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    final isPaymentFailed = _paymentStatus == 'failed' || 
                           (_errorMessage != null && 
                            (_errorMessage!.toLowerCase().contains('failed') ||
                             _errorMessage!.toLowerCase().contains('error') ||
                             _errorMessage!.toLowerCase().contains('contact support')));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (isPaymentFailed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Just close the screen - user can try again later
                      Navigator.pop(context, false);
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      'Try Again Later',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMedium,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final amount = _paymentRequest != null 
                            ? PricingService.formatPrice((_paymentRequest!['amount'] as num).toDouble())
                            : 'N/A';
                        await WhatsAppSupportService.contactSupportForBookingPaymentFailure(
                          paymentId: widget.paymentRequestId,
                          amount: amount,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'WhatsApp is not installed. Please install WhatsApp to contact support.',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.chat, size: 18),
                    label: Text(
                      'Contact Support',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Sandbox testing button - only shown in sandbox mode when payment fails
  Widget _buildSandboxTestingButton() {
    final isSandbox = !FapshiService.isProduction;
    
    // Only show in sandbox mode when payment has failed
    if (!isSandbox || _paymentStatus != 'failed' || _errorMessage == null) {
      return const SizedBox.shrink();
    }
    
    // Only show if error is related to phone validation or payment processing
    final showButton = _errorMessage!.toLowerCase().contains('phone') ||
                       _errorMessage!.toLowerCase().contains('valid') ||
                       _errorMessage!.toLowerCase().contains('declined') ||
                       _errorMessage!.toLowerCase().contains('failed');
    
    if (!showButton) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[900]),
                  const SizedBox(width: 8),
                  Text(
                    'Sandbox Testing Only',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'If you\'re testing and the payment is failing, you can simulate a successful payment to test the rest of the flow (session generation, notifications, etc.).',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.orange[800],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isProcessing ? null : _forceCompleteSandbox,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: Colors.orange[100],
                ),
                child: Text(
                  'Simulate Payment Success (Testing Only)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
