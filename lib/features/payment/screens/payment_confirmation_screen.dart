import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/payment/widgets/payment_instructions_widget.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:confetti/confetti.dart';

/// Payment Confirmation Screen
/// 
/// Dedicated screen that shows ONLY payment instructions and processing status
/// Used for both trial sessions and regular booking payments
class PaymentConfirmationScreen extends StatefulWidget {
  final String? provider; // 'mtn' or 'orange'
  final String phoneNumber;
  final double amount; // Payment amount in XAF
  final String transactionId; // Fapshi transaction ID
  final bool isSandbox; // Whether in sandbox mode
  final Future<bool> Function(String transId) onPaymentComplete; // Callback when payment succeeds

  const PaymentConfirmationScreen({
    Key? key,
    required this.provider,
    required this.phoneNumber,
    required this.amount,
    required this.transactionId,
    required this.isSandbox,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _isPolling = true;
  bool _isProcessing = false;
  String _paymentStatus = 'pending'; // pending, successful, failed
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    if (widget.isSandbox) {
      // In sandbox mode, use faster polling for auto-completion
      _pollPaymentStatus(
        maxAttempts: 5,
        interval: const Duration(seconds: 2),
        minWaitTime: const Duration(seconds: 3),
      );
    } else {
      // In production, poll until user confirms
      _pollPaymentStatus(
        maxAttempts: 60, // 5 minutes (60 * 5 seconds)
        interval: const Duration(seconds: 5),
        minWaitTime: const Duration(seconds: 10),
      );
    }
  }

  Future<void> _pollPaymentStatus({
    required int maxAttempts,
    required Duration interval,
    required Duration minWaitTime,
  }) async {
    final startTime = DateTime.now();
    int attempts = 0;

    while (attempts < maxAttempts && _isPolling && mounted) {
      // Ensure minimum wait time has passed
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minWaitTime) {
        await Future.delayed(minWaitTime - elapsed);
      }

      // In production mode, check database for webhook updates first
      // Webhook may update database before API polling detects it
      if (!widget.isSandbox) {
        final dbConfirmed = await _checkDatabaseForWebhookUpdate();
        if (dbConfirmed) {
          // Webhook already confirmed payment - show success immediately
          return;
        }
      }

      try {
        final status = widget.isSandbox
            ? await FapshiService.pollPaymentStatus(
                widget.transactionId,
                maxAttempts: 1, // Single check per iteration
                interval: interval,
                minWaitTime: const Duration(seconds: 0),
              )
            : await FapshiService.getPaymentStatus(widget.transactionId);

        if (!mounted) return;

        if (!status.isPending) {
          // Payment is no longer pending
          safeSetState(() {
            _isPolling = false;
            if (status.isSuccessful) {
              _paymentStatus = 'successful';
            } else if (status.isFailed) {
              _paymentStatus = 'failed';
              _errorMessage = 'Payment failed. Please try again.';
            } else if (status.status.toUpperCase() == 'EXPIRED') {
              _paymentStatus = 'failed';
              _errorMessage = 'Payment link expired. Please initiate a new payment.';
            }
          });

          // If successful, show confetti celebration and complete payment
          if (status.isSuccessful) {
            _isProcessing = true;
            final success = await widget.onPaymentComplete(widget.transactionId);
            if (mounted) {
              safeSetState(() {
                _isProcessing = false;
                if (success) {
                  _paymentStatus = 'successful';
                  // Show confetti celebration dialog
                  _showCelebrationDialog();
                } else {
                  _errorMessage = 'Payment confirmed but there was an issue completing the transaction. Please contact support.';
                }
              });
            }
          }
          return;
        }
      } catch (e) {
        // Continue polling on error - might be temporary network issue
        if (kDebugMode) {
          print('Error polling payment status (attempt ${attempts + 1}): $e');
        }
      }

      attempts++;
      if (attempts < maxAttempts && _isPolling && mounted) {
        await Future.delayed(interval);
      }
    }

    // If we've exhausted attempts and still pending
    if (mounted && _isPolling) {
      safeSetState(() {
        _isPolling = false;
        if (widget.isSandbox) {
          // In sandbox, if still pending after max attempts, treat as success
          _paymentStatus = 'successful';
          _handlePaymentSuccess();
        } else {
          // In production, show timeout message
          _paymentStatus = 'failed';
          _errorMessage = 'Payment confirmation timed out. Please check your phone and try again.';
        }
      });
    }
  }

  /// Check database for webhook payment confirmation
  /// Returns true if payment was confirmed via webhook, false otherwise
  Future<bool> _checkDatabaseForWebhookUpdate() async {
    try {
      // Check if transaction ID indicates a trial session payment
      // Trial session externalId format: 'trial_<sessionId>'
      if (widget.transactionId.startsWith('trial_') || 
          widget.transactionId.contains('trial')) {
        // Extract trial session ID from transaction ID
        String trialSessionId;
        if (widget.transactionId.startsWith('trial_')) {
          trialSessionId = widget.transactionId.replaceFirst('trial_', '');
        } else {
          // Try to extract from transaction ID (fallback)
          final parts = widget.transactionId.split('_');
          if (parts.length >= 2 && parts[0] == 'trial') {
            trialSessionId = parts.sublist(1).join('_');
          } else {
            // If we can't extract, check by fapshi_trans_id
            final trialData = await SupabaseService.client
                .from('trial_sessions')
                .select('id, payment_status, fapshi_trans_id')
                .eq('fapshi_trans_id', widget.transactionId)
                .maybeSingle();
            
            if (trialData != null) {
              final paymentStatus = trialData['payment_status'] as String?;
              if (paymentStatus?.toLowerCase() == 'paid') {
                LogService.info('✅ Payment confirmed via webhook (database check) for trial session: ${trialData['id']}');
                safeSetState(() {
                  _isPolling = false;
                  _paymentStatus = 'successful';
                });
                _isProcessing = true;
                final success = await widget.onPaymentComplete(widget.transactionId);
                if (mounted) {
                  safeSetState(() {
                    _isProcessing = false;
                    if (success) {
                      _paymentStatus = 'successful';
                      _showCelebrationDialog();
                    } else {
                      _errorMessage = 'Payment confirmed but there was an issue completing the transaction. Please contact support.';
                    }
                  });
                }
                return true;
              }
            }
            return false;
          }
        }
        
        // Check trial_sessions table for payment confirmation
        final trialData = await SupabaseService.client
            .from('trial_sessions')
            .select('id, payment_status, fapshi_trans_id')
            .eq('id', trialSessionId)
            .maybeSingle();
        
        if (trialData != null) {
          final paymentStatus = trialData['payment_status'] as String?;
          final transId = trialData['fapshi_trans_id'] as String?;
          
          // Check if payment was confirmed (either by status or matching transaction ID)
          if (paymentStatus?.toLowerCase() == 'paid' && 
              (transId == widget.transactionId || transId != null)) {
            LogService.info('✅ Payment confirmed via webhook (database check) for trial session: $trialSessionId');
            safeSetState(() {
              _isPolling = false;
              _paymentStatus = 'successful';
            });
            _isProcessing = true;
            final success = await widget.onPaymentComplete(widget.transactionId);
            if (mounted) {
              safeSetState(() {
                _isProcessing = false;
                if (success) {
                  _paymentStatus = 'successful';
                  _showCelebrationDialog();
                } else {
                  _errorMessage = 'Payment confirmed but there was an issue completing the transaction. Please contact support.';
                }
              });
            }
            return true;
          }
        }
      } else {
        // Regular payment request - check payment_requests table
        // Payment request externalId format: 'payment_request_<paymentRequestId>'
        String? paymentRequestId;
        if (widget.transactionId.startsWith('payment_request_')) {
          paymentRequestId = widget.transactionId.replaceFirst('payment_request_', '');
        } else {
          // Try to find by fapshi_trans_id
          final paymentData = await SupabaseService.client
              .from('payment_requests')
              .select('id, status, fapshi_trans_id')
              .eq('fapshi_trans_id', widget.transactionId)
              .maybeSingle();
          
          if (paymentData != null) {
            final paymentStatus = paymentData['status'] as String?;
            if (paymentStatus?.toLowerCase() == 'paid') {
              LogService.info('✅ Payment confirmed via webhook (database check) for payment request: ${paymentData['id']}');
              safeSetState(() {
                _isPolling = false;
                _paymentStatus = 'successful';
              });
              _isProcessing = true;
              final success = await widget.onPaymentComplete(widget.transactionId);
              if (mounted) {
                safeSetState(() {
                  _isProcessing = false;
                  if (success) {
                    _paymentStatus = 'successful';
                    _showCelebrationDialog();
                  } else {
                    _errorMessage = 'Payment confirmed but there was an issue completing the transaction. Please contact support.';
                  }
                });
              }
              return true;
            }
          }
          return false;
        }
        
        if (paymentRequestId != null) {
          // Check payment_requests table for payment confirmation
          final paymentData = await SupabaseService.client
              .from('payment_requests')
              .select('id, status, fapshi_trans_id')
              .eq('id', paymentRequestId)
              .maybeSingle();
          
          if (paymentData != null) {
            final paymentStatus = paymentData['status'] as String?;
            final transId = paymentData['fapshi_trans_id'] as String?;
            
            // Check if payment was confirmed
            if (paymentStatus?.toLowerCase() == 'paid' && 
                (transId == widget.transactionId || transId != null)) {
              LogService.info('✅ Payment confirmed via webhook (database check) for payment request: $paymentRequestId');
              safeSetState(() {
                _isPolling = false;
                _paymentStatus = 'successful';
              });
              _isProcessing = true;
              final success = await widget.onPaymentComplete(widget.transactionId);
              if (mounted) {
                safeSetState(() {
                  _isProcessing = false;
                  if (success) {
                    _paymentStatus = 'successful';
                    _showCelebrationDialog();
                  } else {
                    _errorMessage = 'Payment confirmed but there was an issue completing the transaction. Please contact support.';
                  }
                });
              }
              return true;
            }
          }
        }
      }
    } catch (e) {
      LogService.warning('Error checking database for webhook update: $e');
      // Continue with API polling on error
    }
    return false;
  }

  Future<void> _handlePaymentSuccess() async {
    _isProcessing = true;
    final success = await widget.onPaymentComplete(widget.transactionId);
    if (mounted) {
      safeSetState(() {
        _isProcessing = false;
        if (success) {
          _paymentStatus = 'successful';
          // Show confetti celebration dialog
          _showCelebrationDialog();
        } else {
          _errorMessage = 'Payment confirmed but there was an issue completing the transaction. Please contact support.';
        }
      });
    }
  }

  void _showCelebrationDialog() {
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
            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confettiController,
                blastDirection: 3.14 / 2, // Downward
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.1,
              ),
            ),
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
                    'Your payment has been confirmed successfully.',
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
                        // Navigate back with success
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Prevent back navigation while processing
            if (_isPolling || _isProcessing) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context, false);
            }
          },
        ),
        title: Text(
          'Complete Payment',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Payment Instructions Card (centered)
              PaymentInstructionsWidget(
                provider: widget.provider,
                phoneNumber: widget.phoneNumber,
                amount: widget.amount,
              ),

              // Processing Indicator (below instructions)
              if (_isPolling || _isProcessing) ...[
                const SizedBox(height: 32),
                _buildProcessingIndicator(),
              ],

              // Success Message
              if (_paymentStatus == 'successful' && !_isProcessing) ...[
                const SizedBox(height: 32),
                _buildSuccessMessage(),
              ],

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                _buildErrorMessage(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Processing payment...',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppTheme.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
                fontSize: 16,
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Future<void> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Exit Payment?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Payment is still being processed. Are you sure you want to exit?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Exit', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, false);
    }
  }
}

