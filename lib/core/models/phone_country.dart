import 'package:prepskul/core/models/phone_countries_data.dart';

/// Dial-code country entry for phone signup/login.
class PhoneCountry {
  final String name;
  final String isoCode;
  final String dialCode;
  final String flag;

  const PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
  });

  static const cameroon = PhoneCountry(
    name: 'Cameroon',
    isoCode: 'CM',
    dialCode: '+237',
    flag: '🇨🇲',
  );

  static List<PhoneCountry> get all => kPhoneCountries;

  static PhoneCountry? findByDialCode(String dialCode) {
    final normalized = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    for (final country in all) {
      if (country.dialCode == normalized) return country;
    }
    return null;
  }

  /// Build E.164 phone number from local user input.
  static String formatFullNumber(PhoneCountry country, String localInput) {
    var digits = localInput.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return country.dialCode;

    final codeDigits = country.dialCode.replaceAll('+', '');
    if (digits.startsWith(codeDigits) && digits.length > codeDigits.length + 5) {
      return '+$digits';
    }
    if (digits.startsWith('00$codeDigits')) {
      digits = digits.substring(2 + codeDigits.length);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '${country.dialCode}$digits';
  }

  static String? validateLocalNumber(PhoneCountry country, String localInput) {
    final digits = localInput.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return 'Please enter phone number';

    if (country.isoCode == 'CM') {
      var local = digits;
      if (local.startsWith('237') && local.length > 9) local = local.substring(3);
      if (local.startsWith('0')) local = local.substring(1);
      if (local.length != 9) return 'Enter a valid 9-digit number';
      return null;
    }

    if (digits.length < 6 || digits.length > 14) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
