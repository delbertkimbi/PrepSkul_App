import 'web_onboarding_handoff_stub.dart'
    if (dart.library.html) 'web_onboarding_handoff_web.dart'
    as platform;

/// Read the one-time draft written by `web/index.html` before Flutter starts.
Future<String?> consumeWebOnboardingHandoff() => platform.consume();
