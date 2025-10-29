import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepskul/core/localization/language_notifier.dart';

class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({Key? key}) : super(key: key);

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageNotifier>(
      builder: (context, languageNotifier, child) {
        final isEnglish = languageNotifier.currentLocale.languageCode == 'en';
        final isFrench = languageNotifier.currentLocale.languageCode == 'fr';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // English flag/text
              _buildLanguageOption(
                context,
                'EN',
                const Locale('en'),
                isSelected: isEnglish,
              ),

              const SizedBox(width: 8),

              // Separator
              Container(height: 16, width: 1, color: Colors.grey.shade300),

              const SizedBox(width: 8),

              // French flag/text
              _buildLanguageOption(
                context,
                'FR',
                const Locale('fr'),
                isSelected: isFrench,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String text,
    Locale locale, {
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _changeLanguage(context, locale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _changeLanguage(BuildContext context, Locale locale) async {
    final languageNotifier = Provider.of<LanguageNotifier>(
      context,
      listen: false,
    );
    await languageNotifier.setLanguage(locale);

    // Show feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.languageCode == 'en'
                ? 'Language changed to English'
                : 'Langue changée en Français',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }
}
