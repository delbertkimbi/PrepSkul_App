import 'package:flutter/material.dart';
import 'package:prepskul/core/localization/language_service.dart';

class LanguageNotifier extends ChangeNotifier {
  Locale _currentLocale = LanguageService.currentLocale;

  Locale get currentLocale => _currentLocale;

  Future<void> setLanguage(Locale locale) async {
    if (_currentLocale != locale) {
      _currentLocale = locale;
      await LanguageService.setLanguage(locale);
      notifyListeners();
    }
  }

  void initialize() {
    _currentLocale = LanguageService.currentLocale;
  }
}
