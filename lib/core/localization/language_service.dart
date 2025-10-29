import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  static Locale _currentLocale = const Locale('en');

  static Locale get currentLocale => _currentLocale;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);
    if (savedLanguage != null) {
      _currentLocale = Locale(savedLanguage);
    }
  }

  static Future<void> setLanguage(Locale locale) async {
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  }

  static bool get isEnglish => _currentLocale.languageCode == 'en';
  static bool get isFrench => _currentLocale.languageCode == 'fr';

  static String get languageCode => _currentLocale.languageCode;

  static List<Locale> get supportedLocales => [
    const Locale('en'),
    const Locale('fr'),
  ];

  static Locale getFallbackLocale() {
    return const Locale('en');
  }
}
