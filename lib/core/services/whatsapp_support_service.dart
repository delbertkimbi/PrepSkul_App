import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart';

/// WhatsApp Support Service
///
/// Provides context-specific WhatsApp support links with pre-filled messages
class WhatsAppSupportService {
  // WhatsApp number for PrepSkul support
  static const String _whatsappNumber = '+237674208573';

  /// Open WhatsApp with a pre-filled message
  static Future<void> openWhatsApp({
    required String context,
    String? additionalInfo,
    String? userId,
    String? userName,
    String? userEmail,
  }) async {
    try {
      // Get user info if not provided
      String? finalUserId = userId;
      String? finalUserName = userName;
      String? finalUserEmail = userEmail;

      if (finalUserId == null || finalUserName == null || finalUserEmail == null) {
        try {
          final userProfile = await AuthService.getUserProfile();
          finalUserId ??= userProfile?['id'] as String? ?? 'N/A';
          finalUserName ??= userProfile?['full_name'] as String? ?? 'User';
          finalUserEmail ??= userProfile?['email'] as String? ?? 'N/A';
        } catch (e) {
          LogService.warning('Could not fetch user profile for WhatsApp message: $e');
          finalUserId ??= 'N/A';
          finalUserName ??= 'User';
          finalUserEmail ??= 'N/A';
        }
      }

      // Build context-specific message
      String message = _buildMessage(
        context: context,
        additionalInfo: additionalInfo,
        userId: finalUserId,
        userName: finalUserName,
        userEmail: finalUserEmail,
      );

      // Encode message for URL
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$_whatsappNumber?text=$encodedMessage';

      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.success('WhatsApp opened successfully for context: $context');
      } else {
        throw Exception('WhatsApp is not installed');
      }
    } catch (e) {
      LogService.error('Error opening WhatsApp: $e');
      rethrow;
    }
  }

  /// Build context-specific message
  static String _buildMessage({
    required String context,
    String? additionalInfo,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    String baseMessage = 'Hello PrepSkul Support,\n\n';
    
    // Add context-specific message
    switch (context) {
      case 'email_verification':
        baseMessage += 'I need help with email verification.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Details: $additionalInfo\n\n';
        }
        break;
      
      case 'payment_failed':
        baseMessage += 'I encountered a payment failure.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Payment Details: $additionalInfo\n\n';
        }
        baseMessage += 'Please help me resolve this issue.\n\n';
        break;
      
      case 'payment_processing_error':
        baseMessage += 'I encountered an error while processing my payment.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Error Details: $additionalInfo\n\n';
        }
        break;
      
      case 'session_payment_failed':
        baseMessage += 'My session payment failed.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Session Details: $additionalInfo\n\n';
        }
        break;
      
      case 'booking_payment_failed':
        baseMessage += 'My booking payment failed.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Booking Details: $additionalInfo\n\n';
        }
        break;
      
      case 'trial_payment_failed':
        baseMessage += 'My trial session payment failed.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Trial Details: $additionalInfo\n\n';
        }
        break;
      
      case 'general_support':
      default:
        baseMessage += 'I need assistance.\n\n';
        if (additionalInfo != null) {
          baseMessage += 'Details: $additionalInfo\n\n';
        }
        break;
    }

    // Add user details
    baseMessage += '---\n';
    baseMessage += 'User Details:\n';
    baseMessage += 'Name: $userName\n';
    baseMessage += 'Email: $userEmail\n';
    baseMessage += 'User ID: $userId\n';
    baseMessage += '\nThank you!';

    return baseMessage;
  }

  /// Quick helper for email verification context
  static Future<void> contactSupportForEmailVerification({
    String? email,
  }) async {
    await openWhatsApp(
      context: 'email_verification',
      additionalInfo: email != null ? 'Email: $email' : null,
    );
  }

  /// Quick helper for payment failure context
  static Future<void> contactSupportForPaymentFailure({
    String? paymentId,
    String? amount,
    String? paymentType,
  }) async {
    String additionalInfo = '';
    if (paymentId != null) {
      additionalInfo += 'Payment ID: $paymentId';
    }
    if (amount != null) {
      additionalInfo += additionalInfo.isNotEmpty ? '\nAmount: $amount' : 'Amount: $amount';
    }
    if (paymentType != null) {
      additionalInfo += additionalInfo.isNotEmpty ? '\nType: $paymentType' : 'Type: $paymentType';
    }

    await openWhatsApp(
      context: 'payment_failed',
      additionalInfo: additionalInfo.isNotEmpty ? additionalInfo : null,
    );
  }

  /// Quick helper for session payment failure
  static Future<void> contactSupportForSessionPaymentFailure({
    String? sessionId,
    String? sessionDate,
  }) async {
    String additionalInfo = '';
    if (sessionId != null) {
      additionalInfo += 'Session ID: $sessionId';
    }
    if (sessionDate != null) {
      additionalInfo += additionalInfo.isNotEmpty ? '\nSession Date: $sessionDate' : 'Session Date: $sessionDate';
    }

    await openWhatsApp(
      context: 'session_payment_failed',
      additionalInfo: additionalInfo.isNotEmpty ? additionalInfo : null,
    );
  }

  /// Quick helper for booking payment failure
  static Future<void> contactSupportForBookingPaymentFailure({
    String? paymentId,
    String? amount,
  }) async {
    String additionalInfo = '';
    if (paymentId != null) {
      additionalInfo += 'Payment Request ID: $paymentId';
    }
    if (amount != null) {
      additionalInfo += additionalInfo.isNotEmpty ? '\nAmount: $amount' : 'Amount: $amount';
    }

    await openWhatsApp(
      context: 'booking_payment_failed',
      additionalInfo: additionalInfo.isNotEmpty ? additionalInfo : null,
    );
  }

  /// Quick helper for trial payment failure
  static Future<void> contactSupportForTrialPaymentFailure({
    String? sessionId,
    String? sessionDate,
  }) async {
    String additionalInfo = '';
    if (sessionId != null) {
      additionalInfo += 'Trial Session ID: $sessionId';
    }
    if (sessionDate != null) {
      additionalInfo += additionalInfo.isNotEmpty ? '\nSession Date: $sessionDate' : 'Session Date: $sessionDate';
    }

    await openWhatsApp(
      context: 'trial_payment_failed',
      additionalInfo: additionalInfo.isNotEmpty ? additionalInfo : null,
    );
  }
}
