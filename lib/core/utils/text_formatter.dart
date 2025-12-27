/// Text formatting utilities
/// 
/// Provides common text formatting functions used throughout the app.
class TextFormatter {
  /// Clean bio text for display
  /// 
  /// Removes common prefixes like "Hello!" and "I am" from bio text
  /// to make it more suitable for card displays.
  /// 
  /// [bio] - The original bio text
  /// 
  /// Returns cleaned bio text
  static String cleanBio(String bio) {
    if (bio.isEmpty) return bio;
    
    String cleaned = bio;
    
    // Remove "Hello!" prefix if present
    if (cleaned.toLowerCase().startsWith('hello!')) {
      cleaned = cleaned.substring(6).trim();
    }
    
    // Remove "I am" prefix if present
    if (cleaned.toLowerCase().startsWith('i am')) {
      cleaned = cleaned.substring(4).trim();
    }
    
    return cleaned;
  }

  /// Format name with fallback
  /// 
  /// Returns formatted name or 'Unknown' if empty/null.
  /// 
  /// [name] - The name to format
  /// 
  /// Returns formatted name
  static String formatName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Unknown';
    }
    return name.trim();
  }

  /// Truncate text to specified length
  /// 
  /// Truncates text and adds ellipsis if longer than maxLength.
  /// 
  /// [text] - The text to truncate
  /// [maxLength] - Maximum length (default: 100)
  /// 
  /// Returns truncated text
  static String truncate(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  /// Capitalize first letter
  /// 
  /// Capitalizes the first letter of a string.
  /// 
  /// [text] - The text to capitalize
  /// 
  /// Returns capitalized text
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Format phone number
  /// 
  /// Formats phone number for display (adds spacing, etc.).
  /// 
  /// [phone] - The phone number to format
  /// 
  /// Returns formatted phone number
  static String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'N/A';
    }
    
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Format based on length
    if (digits.length == 9) {
      // Format: 67X XX XX XX
      return '${digits.substring(0, 3)} ${digits.substring(3, 5)} ${digits.substring(5, 7)} ${digits.substring(7)}';
    } else if (digits.length == 10) {
      // Format: +237 6XX XX XX XX
      return '+237 ${digits.substring(1, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)} ${digits.substring(8)}';
    }
    
    return phone; // Return original if format doesn't match
  }
}
