/// Utility class for parsing hourly rate strings from formatted input
/// Handles ranges like "4,000 – 5,000 XAF" and ensures values are within valid range (1000-50000)
class HourlyRateParser {
  /// Parse hourly rate from formatted string (e.g., "4,000 – 5,000 XAF" -> 4000.0)
  /// Handles ranges by extracting the first number, and ensures value is within valid range (1000-50000)
  static double? parseHourlyRate(String? expectedRate) {
    if (expectedRate == null || expectedRate.isEmpty) {
      return null;
    }

    // Handle "Above X" cases - use the minimum value from the range
    if (expectedRate.toLowerCase().contains('above')) {
      // Extract the number after "above"
      final match = RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?)').firstMatch(expectedRate);
      if (match != null) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value != null && value >= 1000 && value <= 50000) {
          return value;
        }
      }
      // Default to 5000 for "Above 5,000" if parsing fails
      return 5000.0;
    }

    // For ranges like "4,000 – 5,000 XAF", extract only the first number
    // Split by common range separators (dash, hyphen, etc.)
    final parts = expectedRate.split(RegExp(r'[–\-–]'));
    String firstPart = parts.isNotEmpty ? parts[0].trim() : expectedRate;

    // Remove all non-digit characters except decimal point, then parse
    final cleanedValue = firstPart.replaceAll(RegExp(r'[^\d.]'), '');
    final parsedValue = double.tryParse(cleanedValue);

    if (parsedValue == null) {
      return null;
    }

    // Ensure the value is within the valid database constraint range (1000-50000)
    if (parsedValue < 1000) {
      return 1000.0; // Minimum allowed
    } else if (parsedValue > 50000) {
      return 50000.0; // Maximum allowed
    }

    return parsedValue;
  }
}





