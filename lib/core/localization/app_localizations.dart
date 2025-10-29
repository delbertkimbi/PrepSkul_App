import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Common translations
  String get appName => _getTranslation('app_name');
  String get tagline => _getTranslation('tagline');

  // Navigation
  String get welcome => _getTranslation('welcome');
  String get selectRole => _getTranslation('select_role');
  String get login => _getTranslation('login');
  String get signup => _getTranslation('signup');
  String get logout => _getTranslation('logout');

  // User roles
  String get learner => _getTranslation('learner');
  String get parent => _getTranslation('parent');
  String get tutor => _getTranslation('tutor');

  // Role descriptions
  String get learnerDescription => _getTranslation('learner_description');
  String get parentDescription => _getTranslation('parent_description');
  String get tutorDescription => _getTranslation('tutor_description');

  // Auth forms
  String get email => _getTranslation('email');
  String get password => _getTranslation('password');
  String get confirmPassword => _getTranslation('confirm_password');
  String get fullName => _getTranslation('full_name');
  String get forgotPassword => _getTranslation('forgot_password');
  String get dontHaveAccount => _getTranslation('dont_have_account');
  String get alreadyHaveAccount => _getTranslation('already_have_account');

  // Validation messages
  String get pleaseEnterEmail => _getTranslation('please_enter_email');
  String get pleaseEnterValidEmail =>
      _getTranslation('please_enter_valid_email');
  String get pleaseEnterPassword => _getTranslation('please_enter_password');
  String get passwordTooShort => _getTranslation('password_too_short');
  String get passwordsDoNotMatch => _getTranslation('passwords_do_not_match');
  String get pleaseEnterFullName => _getTranslation('please_enter_full_name');

  // Success messages
  String get loginSuccessful => _getTranslation('login_successful');
  String get signupSuccessful => _getTranslation('signup_successful');

  // Onboarding
  String get getStarted => _getTranslation('get_started');
  String get next => _getTranslation('next');
  String get skip => _getTranslation('skip');
  String get done => _getTranslation('done');

  // Language helper
  bool get isEnglish => locale.languageCode == 'en';
  bool get isFrench => locale.languageCode == 'fr';

  String _getTranslation(String key) {
    return _localizedValues[locale.languageCode]![key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'PrepSkul',
      'tagline': 'Building a Future Where Every Learner is Guided',
      'welcome': 'Welcome to PrepSkul',
      'select_role': 'Select your role to continue',
      'login': 'Login',
      'signup': 'Sign Up',
      'logout': 'Logout',
      'learner': 'Learner',
      'parent': 'Parent',
      'tutor': 'Tutor',
      'learner_description':
          'Access personalized tutoring and track your progress',
      'parent_description':
          'Manage learner profiles, book lessons, and make payments',
      'tutor_description':
          'Create your profile, manage availability, and conduct lessons',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'full_name': 'Full Name',
      'forgot_password': 'Forgot Password?',
      'dont_have_account': 'Don\'t have an account?',
      'already_have_account': 'Already have an account?',
      'please_enter_email': 'Please enter your email',
      'please_enter_valid_email': 'Please enter a valid email',
      'please_enter_password': 'Please enter your password',
      'password_too_short': 'Password must be at least 6 characters',
      'passwords_do_not_match': 'Passwords do not match',
      'please_enter_full_name': 'Please enter your full name',
      'login_successful': 'Login successful!',
      'signup_successful': 'Signup successful!',
      'get_started': 'Get Started',
      'next': 'Next',
      'skip': 'Skip',
      'done': 'Done',
    },
    'fr': {
      'app_name': 'PrepSkul',
      'tagline': 'Construire un Avenir où Chaque Apprenant est Guidé',
      'welcome': 'Bienvenue à PrepSkul',
      'select_role': 'Sélectionnez votre rôle pour continuer',
      'login': 'Connexion',
      'signup': 'S\'inscrire',
      'logout': 'Déconnexion',
      'learner': 'Apprenant',
      'parent': 'Parent',
      'tutor': 'Tuteur',
      'learner_description':
          'Accédez à un tutorat personnalisé et suivez vos progrès',
      'parent_description':
          'Gérez les profils d\'apprenants, réservez des cours et effectuez des paiements',
      'tutor_description':
          'Créez votre profil, gérez votre disponibilité et donnez des cours',
      'email': 'Email',
      'password': 'Mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'full_name': 'Nom complet',
      'forgot_password': 'Mot de passe oublié?',
      'dont_have_account': 'Vous n\'avez pas de compte?',
      'already_have_account': 'Vous avez déjà un compte?',
      'please_enter_email': 'Veuillez entrer votre email',
      'please_enter_valid_email': 'Veuillez entrer un email valide',
      'please_enter_password': 'Veuillez entrer votre mot de passe',
      'password_too_short':
          'Le mot de passe doit contenir au moins 6 caractères',
      'passwords_do_not_match': 'Les mots de passe ne correspondent pas',
      'please_enter_full_name': 'Veuillez entrer votre nom complet',
      'login_successful': 'Connexion réussie!',
      'signup_successful': 'Inscription réussie!',
      'get_started': 'Commencer',
      'next': 'Suivant',
      'skip': 'Passer',
      'done': 'Terminé',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
