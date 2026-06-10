/// Helpers for password-based phone auth (no OTP).
class PhoneAuthUtils {
  static const String aliasDomain = '@phone.prepskul.local';

  static String aliasEmail(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return 'p$digitsOnly$aliasDomain';
  }

  static bool isPhoneAliasEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return RegExp(r'^p\d+@phone\.prepskul\.local$').hasMatch(email);
  }

  static bool isEmailNotConfirmedError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('email_not_confirmed') ||
        text.contains('email not confirmed');
  }
}
