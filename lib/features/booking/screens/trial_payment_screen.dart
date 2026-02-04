import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/whatsapp_support_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart' hide LogService;
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:confetti/confetti.dart';


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
  bool _isCancelled = false; // Track if user cancelled polling
  int _pollAttempts = 0; // Track polling attempts for timeout
  String? _errorMessage;
  String? _phoneError; // Phone number validation error
  String _paymentStatus = 'idle'; // idle, pending, successful, failed, timeout
  String? _lastTransactionId; // Used to retry Meet link generation
  double? _payableAmount; // Total amount (single fee or group total with discount)
  bool _loadingAmount = true;

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
    _loadPayableAmount();
  }

  /// Load payable amount (single fee or sum of all accepted trials in group).
  /// Note: Trial sessions have fixed pricing - no multi-learner discounts. All trials use same base price.
  Future<void> _loadPayableAmount() async {
    try {
      final amount = await TrialSessionService.getPayableAmountForTrial(widget.trialSession);
      if (mounted) {
        safeSetState(() {
          _payableAmount = amount;
          _loadingAmount = false;
        });
      }
    } catch (e) {
      LogService.warning('Could not load payable amount: $e');
      if (mounted) {
        safeSetState(() {
          _payableAmount = widget.trialSession.trialFee;
          _loadingAmount = false;
        });
      }
    }
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
          safeSetState(() {
            _phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      LogService.warning('Could not load user phone: $e');
    }
      return;
  }

  /// Validate phone number using same logic as FapshiService
  String? _validatePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats
    String normalized;
    if (digitsOnly.startsWith('237')) {
      // International format: 23767XXXXXXX -> 67XXXXXXX
      normalized = digitsOnly.substring(3);
    } else if (digitsOnly.startsWith('67') || 
                digitsOnly.startsWith('69') || 
                digitsOnly.startsWith('65') || 
                digitsOnly.startsWith('66') ||
                digitsOnly.startsWith('68')) {
      // Already in correct format: 67XXXXXXX or 69XXXXXXX
      normalized = digitsOnly;
    } else {
      return null; // Invalid format
    }
    
    // Validate length (should be 9 digits for Cameroon)
    if (normalized.length != 9) {
      return null;
    }
    
    // Validate it starts with valid Cameroon mobile prefix
    final validPrefixes = ['67', '69', '65', '66', '68'];
    if (!validPrefixes.any((prefix) => normalized.startsWith(prefix))) {
      return null;
    }
    
    return normalized;
  }

  /// Initiate payment
  Future<void> _initiatePayment() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      safeSetState(() {
        _phoneError = 'Please enter your phone number';
      });
      return;
    }
    
    // Validate phone number format
    final normalizedPhone = _validatePhoneNumber(phone);
    if (normalizedPhone == null) {
      safeSetState(() {
        _phoneError = 'Please enter a valid phone number (67XXXXXXX or 69XXXXXXX)';
      });
      return;
    }

    safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
      _phoneError = null;
      _paymentStatus = 'idle';
    });

    try {
      // Initiate payment via trial session service
      // Pass trial session to avoid unnecessary fetch
      final transId = await TrialSessionService.initiatePayment(
        sessionId: widget.trialSession.id,
        phoneNumber: normalizedPhone, // Use validated and normalized phone number
        trialSession: widget.trialSession,
      );

      safeSetState(() {
        _paymentStatus = 'pending';
        _isProcessing = false;
        _isPolling = true;
      });

      // Start polling for payment status
      _pollPaymentStatus(transId);
    } catch (e) {
      // FapshiService already provides user-friendly messages, so use them directly
      // Remove "Exception: " prefix if present
      String userMessage = e.toString().replaceFirst('Exception: ', '').trim();
      
      // If message is already user-friendly (contains helpful guidance), use as-is
      // Otherwise, provide a generic helpful message
      if (userMessage.isEmpty || 
          userMessage.toLowerCase().contains('exception') ||
          userMessage.toLowerCase().contains('error:') ||
          userMessage.toLowerCase().contains('failed:')) {
        userMessage = 'We couldn\'t process your payment. Please check your phone number and try again.\n\nIf this continues, contact our support team for assistance.';
      }
      
      safeSetState(() {
        _errorMessage = userMessage;
        _isProcessing = false;
        _paymentStatus = 'failed';
      });
      LogService.error('Payment initiation error: $e');
    }
  }

  /// Poll payment status with database verification
  /// 
  /// This method:
  /// 1. Polls Fapshi API for payment status
  /// 2. Also checks database periodically to see if webhook already processed payment
  /// 3. Handles both polling success and webhook success scenarios
  Future<void> _pollPaymentStatus(String transId) async {
    try {
      int attempts = 0;
      const maxAttempts = 40; // 2 minutes max
      const interval = Duration(seconds: 3);
      
      // Reset cancellation flag
      _isCancelled = false;
      
      while (attempts < maxAttempts && mounted && !_isCancelled) {
        // Check database first (webhook might have already processed payment)
        try {
          final trial = await TrialSessionService.getTrialSessionById(widget.trialSession.id);
          if (trial.paymentStatus.toLowerCase() == 'paid') {
            // Webhook already processed payment - complete the flow
            LogService.success('Payment confirmed via webhook (database check)');
            if (mounted) {
              safeSetState(() {
                _isPolling = false;
                _paymentStatus = 'successful';
              });
              // Payment already confirmed, just verify Meet link and navigate
              final success = await _verifyPaymentComplete(transId);
              if (success && mounted) {
                Navigator.pop(context, true);
              }
            }
            return;
          }
        } catch (e) {
          LogService.warning('Error checking database for payment status: $e');
          // Continue with polling
        }
        
        // Poll Fapshi API
        try {
          final status = await FapshiService.getPaymentStatus(transId);
          
          if (!status.isPending) {
            // Payment is no longer pending
      if (mounted) {
        safeSetState(() {
          _isPolling = false;
          if (status.isSuccessful) {
            _paymentStatus = 'successful';
          } else if (status.isFailed) {
            _paymentStatus = 'failed';
            // Provide user-friendly error messages based on failure reason
            final statusStr = status.status?.toUpperCase() ?? '';
            if (statusStr.contains('INSUFFICIENT') || statusStr.contains('BALANCE')) {
              _errorMessage = 'Payment failed due to insufficient balance. Please check your mobile money account balance and try again.';
            } else if (statusStr.contains('DECLINED') || statusStr.contains('REJECTED')) {
              _errorMessage = 'Payment was declined. Please check your mobile money account and try again.';
            } else if (statusStr.contains('CANCELLED') || statusStr.contains('CANCELED')) {
              _errorMessage = 'Payment was cancelled. Please try again when ready.';
            } else if (statusStr.contains('EXPIRED')) {
              _paymentStatus = 'failed';
              _errorMessage = 'Payment link expired. Please initiate a new payment.';
            } else if (statusStr.contains('TIMEOUT') || statusStr.contains('TIMED OUT')) {
              _errorMessage = 'Payment request timed out. Please check your phone and try again.';
            } else if (statusStr.contains('NETWORK') || statusStr.contains('CONNECTION')) {
              _errorMessage = 'Network error occurred. Please check your internet connection and try again.';
            } else if (statusStr.contains('SIM') || statusStr.contains('NO ACCESS')) {
              _errorMessage = 'Unable to access your mobile money account. Please ensure your SIM card is inserted and try again.';
            } else {
              _errorMessage = 'Payment failed. Please check your mobile money account balance and ensure you have sufficient funds, then try again.';
            }
                } else if (status.status.toUpperCase() == 'EXPIRED') {
                  _paymentStatus = 'failed';
                  _errorMessage = 'Payment link expired. Please initiate a new payment.';
          }
        });
              
              // Complete payment if successful
        if (status.isSuccessful) {
          final success = await _completePayment(transId);
          if (success && mounted) {
            Navigator.pop(context, true);
          }
              }
            }
            return;
          }
        } catch (e) {
          LogService.warning('Error polling payment status (attempt ${attempts + 1}): $e');
          // Continue polling - might be temporary network issue
        }
        
        // Wait before next attempt
        await Future.delayed(interval);
        attempts++;
        _pollAttempts = attempts;
        
        if (mounted && attempts % 5 == 0) {
          // Log progress every 15 seconds
          LogService.debug('⏳ Still polling payment status (attempt $attempts/$maxAttempts)...');
        }
      }
      
      // Check if user cancelled
      if (_isCancelled && mounted) {
        safeSetState(() {
          _isPolling = false;
          _paymentStatus = 'idle';
          _errorMessage = null; // Clear any previous errors
        });
        return;
      }
      
      // Max attempts reached - check database one final time
      if (mounted) {
        try {
          final trial = await TrialSessionService.getTrialSessionById(widget.trialSession.id);
          if (trial.paymentStatus.toLowerCase() == 'paid') {
            // Webhook processed it while we were polling
            LogService.success('Payment confirmed via webhook (final check)');
            safeSetState(() {
              _isPolling = false;
              _paymentStatus = 'successful';
            });
            final success = await _verifyPaymentComplete(transId);
            if (success && mounted) {
              Navigator.pop(context, true);
            }
            return;
          }
        } catch (e) {
          LogService.warning('Error in final database check: $e');
        }
        
        // Still pending after max attempts - show timeout with retry option
        safeSetState(() {
          _isPolling = false;
          _paymentStatus = 'timeout';
          _errorMessage = 'Payment confirmation timed out. If you completed the payment, it will be confirmed automatically. Otherwise, please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _isPolling = false;
          _paymentStatus = 'failed';
          _errorMessage = 'Error checking payment status. Please check your payment history or contact support if payment was successful.';
        });
      }
      LogService.error('Error in payment polling: $e');
    }
  }
  
  /// Verify payment is complete and handle navigation
  /// 
  /// Used when webhook has already processed payment
  /// Just verifies Meet link exists and navigates
  Future<bool> _verifyPaymentComplete(String transId) async {
    try {
      // Refresh trial session to get latest data
      final trial = await TrialSessionService.getTrialSessionById(widget.trialSession.id);
      
      if (trial.paymentStatus.toLowerCase() != 'paid') {
        LogService.warning('Payment verification failed: status is not paid');
        return false;
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment confirmed!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navigate to sessions screen
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/my-sessions',
            (route) => route.settings.name == '/student-nav' || route.isFirst,
            arguments: {
              'initialTab': 0, // Upcoming tab
              'sessionId': widget.trialSession.id,
            },
          );
        }
      }
      return true;
    } catch (e) {
      LogService.error('Error verifying payment completion: $e');
      return false;
    }
  }

  /// Sandbox helper: manually complete payment when the provider status API
  /// is not available, so we can still test the rest of the flow (calendar,
  /// Meet link, notifications, sessions list).
  Future<void> _forceCompleteSandbox() async {
    safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final fakeTransId =
          'sandbox_manual_${DateTime.now().millisecondsSinceEpoch}';
      await _completePayment(fakeTransId); // Returns bool but we ignore it for sandbox
    } catch (e) {
      if (!mounted) // void function, no return needed
      safeSetState(() {
        _errorMessage = 'Sandbox completion failed: $e';
      });
    } finally {
      if (!mounted) // void function, no return needed
      safeSetState(() {
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
      safeSetState(() {
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

      // Set payment status to successful
      safeSetState(() {
        _paymentStatus = 'successful';
      });

      // Show confetti celebration dialog
      if (mounted) {
        _showCelebrationDialog(calendarOk);
      }

      // Navigate to sessions screen after successful payment
      if (mounted) {
        // Small delay to ensure database update is complete and user sees celebration
        await Future.delayed(const Duration(milliseconds: 2000));
        
          if (mounted) {
          // Navigate directly to sessions screen with the paid session
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/my-sessions',
            (route) => route.settings.name == '/student-nav' || route.isFirst,
            arguments: {
              'initialTab': 0, // Upcoming tab
              'sessionId': widget.trialSession.id, // Scroll to this session
            },
          );
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _errorMessage =
              'We saved your payment but could not finish saving the lesson. Please pull to refresh on the My Sessions page. If it is still empty, contact support.';
        });
      }
      return false;
    }
  }

  /// Show confetti celebration dialog after successful payment
  void _showCelebrationDialog(bool calendarOk) {
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
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Payment Successful!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    calendarOk
                        ? 'Your trial session is booked and added to your calendar. You\'ll receive a notification when it\'s time to join!'
                        : 'Your trial session payment is confirmed. Your lesson will appear under "My Sessions".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        confettiController.dispose();
                        Navigator.pop(context); // Close dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View My Sessions',
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

  /// Connect Google Calendar (OAuth) and retry Meet link generation
  Future<void> _connectCalendarAndRetry() async {
    if (_lastTransactionId == null) return;

    safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final ok = await GoogleCalendarAuthService.signIn();
    if (!ok) {
      if (mounted) {
        safeSetState(() {
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
        safeSetState(() {
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
                  if (_paymentStatus == 'idle' || _paymentStatus == 'failed' || _paymentStatus == 'timeout')
                    _buildPayButton(),
                  if (_paymentStatus == 'failed' || _paymentStatus == 'timeout') ...[
                    const SizedBox(height: 12),
                    _buildRetryButton(),
                  ],
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
            child: _loadingAmount
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : Text(
                    '${(_payableAmount ?? widget.trialSession.trialFee).toStringAsFixed(0)} XAF',
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
          onChanged: (value) {
            // Validate phone number as user types
            safeSetState(() {
              if (value.trim().isEmpty) {
                _phoneError = null; // Don't show error for empty field
              } else {
                // Use FapshiService validation logic
                final normalized = _validatePhoneNumber(value.trim());
                if (normalized == null) {
                  _phoneError = 'Please enter a valid phone number (67XXXXXXX or 69XXXXXXX)';
                } else {
                  _phoneError = null; // Valid phone number
                }
              }
            });
          },
          decoration: InputDecoration(
            hintText: '670000000',
            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
            filled: true,
            fillColor: Colors.white,
            errorText: _phoneError,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
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
    // Calculate progress percentage (max 40 attempts = 100%)
    final progressPercent = _pollAttempts > 0 ? (_pollAttempts / 40).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
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
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for payment confirmation...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please complete the payment on your mobile device',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
          if (_pollAttempts > 0) ...[
            const SizedBox(height: 16),
            // Progress indicator
            Column(
              children: [
                LinearProgressIndicator(
                  value: progressPercent,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking payment status... (${_pollAttempts}/40)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          // Helpful information card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If payment fails or you don\'t have access to your SIM, you can cancel and try again later.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue[800],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              safeSetState(() {
                _isCancelled = true;
                _isPolling = false;
                _paymentStatus = 'idle';
                _pollAttempts = 0;
                _errorMessage = null;
              });
            },
            icon: const Icon(Icons.close, size: 18),
            label: Text(
              'Cancel Payment',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMedium,
              side: BorderSide(color: AppTheme.softBorder),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
    // Show success message only when payment is successful
    if (_paymentStatus == 'successful') {
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
    
    // Show error message for failed/timeout payments
    final isError = _paymentStatus == 'failed' || _paymentStatus == 'timeout';
    if (!isError || _errorMessage == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _paymentStatus == 'timeout' 
                          ? 'Payment Confirmation Timed Out'
                          : 'Payment Failed',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.red[800],
                        height: 1.4,
                      ),
                    ),
                    if (_paymentStatus == 'timeout') ...[
                      const SizedBox(height: 8),
                      Text(
                        'If you completed the payment on your phone, it will be confirmed automatically. You can also try again below.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red[700],
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_paymentStatus == 'failed') ...[
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
                        await WhatsAppSupportService.contactSupportForTrialPaymentFailure(
                          sessionId: widget.trialSession.id,
                          sessionDate: widget.trialSession.formattedDate,
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
                    'Pay ${(_payableAmount ?? widget.trialSession.trialFee).toStringAsFixed(0)} XAF',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        // Only show "Mark as paid" in sandbox as absolute last resort
        // This should only appear if:
        // 1. We're in sandbox
        // 2. Payment failed due to phone number validation (not network/polling issues)
        // 3. User explicitly needs to test the flow
        if (isSandbox && _paymentStatus == 'failed' && _errorMessage != null && 
            (_errorMessage!.contains('phone') || _errorMessage!.contains('valid'))) ...[
          const SizedBox(height: 12),
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
                  'If you\'re testing and the phone number validation is blocking you, you can simulate a successful payment to test the rest of the flow.',
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
          const SizedBox(height: 4),
          Text(
                  '⚠️ This bypasses actual payment. In production, use valid phone numbers (67XXXXXXX or 69XXXXXXX).',
            style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.orange[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : () {
          safeSetState(() {
            _paymentStatus = 'idle';
            _errorMessage = null;
            _pollAttempts = 0;
            _isCancelled = false;
          });
        },
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(
          'Try Again',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
