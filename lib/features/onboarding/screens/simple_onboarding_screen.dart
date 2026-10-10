import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/web_splash_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/language_switcher.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleOnboardingScreen extends StatefulWidget {
  const SimpleOnboardingScreen({super.key});

  @override
  State<SimpleOnboardingScreen> createState() => _SimpleOnboardingScreenState();
}

class _SimpleOnboardingScreenState extends State<SimpleOnboardingScreen> {
  late final PageController _pageController;
  Timer? _autoSlide;
  int _currentPage = 0;

  List<_IntroSlide> _slides(AppLocalizations t) => [
        _IntroSlide(
          title: t.onboardingConnectTitle,
          description: t.onboardingConnectSubtitle,
          image: 'assets/images/onboarding3.jpg',
          mood: Mood.wave,
        ),
        _IntroSlide(
          title: t.onboardingAchieveTitle,
          description: t.onboardingAchieveSubtitle,
          image: 'assets/images/onboarding2.png',
          mood: Mood.point,
        ),
        _IntroSlide(
          title: t.onboardingLearnTitle,
          description: t.onboardingLearnSubtitle,
          image: 'assets/images/onboarding1.png',
          mood: Mood.talk,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebSplashService.removeSplash();
      });
    }
    _armAutoSlide();
  }

  void _armAutoSlide() {
    _autoSlide?.cancel();
    _autoSlide = Timer(const Duration(seconds: 5), () {
      if (!mounted || _currentPage >= 2) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      _armAutoSlide();
    });
  }

  @override
  void dispose() {
    _autoSlide?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage(int lastIndex) {
    if (_currentPage < lastIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    LogService.debug('Onboarding completed, navigating to auth method selection...');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/auth-method-selection');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final slides = _slides(t);
    final last = slides.length - 1;
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _currentPage < last
                          ? TextButton(
                              onPressed: _completeOnboarding,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(t.buttonSkip, style: onboardFont(size: 15)),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const LanguageSwitcher(),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: slides.length,
                itemBuilder: (context, index) => _IntroPage(slide: slides[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (index) {
                final active = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: OnboardPrimaryButton(
                label: _currentPage == last ? t.onboardingCta : t.buttonNext,
                onTap: () => _nextPage(last),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.slide});
  final _IntroSlide slide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardPeopleMateStage(
              photoAsset: slide.image,
              mood: slide.mood,
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                slide.title,
                textAlign: TextAlign.center,
                style: onboardDisplay(size: 26),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                slide.description,
                textAlign: TextAlign.center,
                style: onboardFont(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppTheme.textMedium,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSlide {
  const _IntroSlide({
    required this.title,
    required this.description,
    required this.image,
    required this.mood,
  });

  final String title;
  final String description;
  final String image;
  final Mood mood;
}
