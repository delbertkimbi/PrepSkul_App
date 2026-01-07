import 'package:flutter/material.dart';

/// Payment Provider Helper
/// 
/// Utility class for getting provider-specific information
/// for MTN and Orange mobile money providers in Cameroon
class PaymentProviderHelper {
  /// Get provider name from provider string
  /// Returns "MTN" or "Orange" based on provider ('mtn' or 'orange')
  static String getProviderName(String? provider) {
    if (provider == null) return 'Mobile Money';
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return 'MTN';
      case 'orange':
        return 'Orange';
      default:
        return 'Mobile Money';
    }
  }

  /// Get provider color for UI branding
  /// MTN: Yellow/Orange (#FFC107 or #FF9800)
  /// Orange: Orange/Red (#FF5722 or #FF9800)
  static Color getProviderColor(String? provider) {
    if (provider == null) return Colors.blue;
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return const Color(0xFFF59E0B); // MTN Yellow/Orange
      case 'orange':
        return const Color(0xFFFF5722); // Orange Red
      default:
        return Colors.blue;
    }
  }

  /// Get provider icon
  /// MTN: phone_android (Android icon)
  /// Orange: phone_iphone (iPhone icon)
  static IconData getProviderIcon(String? provider) {
    if (provider == null) return Icons.phone;
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return Icons.phone_android;
      case 'orange':
        return Icons.phone_iphone;
      default:
        return Icons.phone;
    }
  }

  /// Get provider-specific confirmation message
  static String getConfirmationMessage(String? provider) {
    if (provider == null) {
      return 'A payment request will be sent to this number. You\'ll need to approve it in your mobile money app.';
    }
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return 'You will receive a payment request on your MTN Mobile Money. Please approve it to complete the payment.';
      case 'orange':
        return 'You will receive a payment request on your Orange Money. Please approve it to complete the payment.';
      default:
        return 'A payment request will be sent to this number. You\'ll need to approve it in your mobile money app.';
    }
  }

  /// Get USSD code for the provider
  /// MTN: *126#
  /// Orange: *144#
  static String getUSSDCode(String? provider) {
    if (provider == null) return '*126#';
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return '*126#';
      case 'orange':
        return '*144#';
      default:
        return '*126#';
    }
  }
}
