import 'package:flutter/material.dart';

/// Payment Provider Helper
/// 
/// Provides utility functions and constants for payment providers (MTN, Orange)
class PaymentProviderHelper {
  /// MTN Mobile Money provider identifier
  static const String mtn = 'mtn';
  
  /// Orange Money provider identifier
  static const String orange = 'orange';

  /// Get USSD code for a provider
  static String getUssdCode(String? provider) {
    switch (provider) {
      case mtn:
        return '*126#';
      case orange:
        return '#144#';
      default:
        return '';
    }
  }

  /// Get provider display name
  static String getProviderName(String? provider) {
    switch (provider) {
      case mtn:
        return 'MTN Mobile Money';
      case orange:
        return 'Orange Money';
      default:
        return 'Mobile Money';
    }
  }

  /// Get provider color (for UI branding)
  static Color getProviderColor(String? provider) {
    switch (provider) {
      case mtn:
        return const Color(0xFFFFCC00); // MTN Yellow
      case orange:
        return const Color(0xFFFF6600); // Orange Orange
      default:
        return Colors.grey;
    }
  }

  /// Get provider icon
  static IconData getProviderIcon(String? provider) {
    switch (provider) {
      case mtn:
        return Icons.phone_android; // MTN icon placeholder
      case orange:
        return Icons.phone_iphone; // Orange icon placeholder
      default:
        return Icons.phone;
    }
  }

  /// Get step-by-step instructions for confirming payment
  static List<String> getPaymentInstructions(String? provider) {
    switch (provider) {
      case mtn:
        return [
          'Dial *126# on your phone',
          'Select "Mobile Money" from the menu',
          'Select "Pay" or "Payment"',
          'Confirm the payment request',
          'Enter your Mobile Money PIN when prompted',
        ];
      case orange:
        return [
          'Dial #144# on your phone',
          'Select "Orange Money" from the menu',
          'Select "Pay" or "Payment"',
          'Confirm the payment request',
          'Enter your Orange Money PIN when prompted',
        ];
      default:
        return [
          'Check your phone for the payment notification',
          'Follow the instructions on your phone',
          'Enter your Mobile Money PIN when prompted',
        ];
    }
  }

  /// Get short confirmation message
  static String getConfirmationMessage(String? provider) {
    final ussdCode = getUssdCode(provider);
    final providerName = getProviderName(provider);
    
    if (ussdCode.isNotEmpty) {
      return 'Payment request sent to your $providerName. Dial $ussdCode to confirm.';
    }
    return 'Payment request sent. Check your phone for the notification.';
  }

  /// Get helpful tips for payment
  static List<String> getPaymentTips(String? provider) {
    return [
      'Check your phone for the payment notification',
      'You have 2 minutes to confirm the payment',
      'If you don\'t receive the request, check your phone number',
      'Make sure you have sufficient balance in your $provider account',
    ];
  }
}

