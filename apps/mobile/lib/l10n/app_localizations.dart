import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }

    bool get _isEnglish => true;

  String get appTitle => 'ClinDiary';

  String get appSubtitle =>
      _isEnglish ? 'Personal health diary.' : 'Personal health diary.';

    String get signInTitle => _isEnglish ? 'Sign in' : 'Sign in';

  String get emailLabel => 'Email';

  String get passwordLabel => _isEnglish ? 'Password' : 'Password';

  String get confirmPasswordLabel =>
      _isEnglish ? 'Confirm password' : 'Confirm password';

  String get passwordsDoNotMatch =>
      _isEnglish ? 'Passwords do not match' : 'Passwords do not match';

  String get emailInvalid =>
      _isEnglish ? 'Enter a valid email' : 'Enter a valid email';

  String get passwordMinLength =>
      _isEnglish ? 'Minimum 8 characters' : 'Minimum 8 characters';

    String get signIn => _isEnglish ? 'Sign in' : 'Sign in';

    String get signingIn => _isEnglish ? 'Signing in...' : 'Signing in...';

  String get signInWithGoogle =>
      _isEnglish ? 'Sign in with Google' : 'Sign in with Google';

  String get signingInWithGoogle =>
      _isEnglish ? 'Signing in with Google...' : 'Signing in with Google...';

  String get googleAuthNotConfigured => _isEnglish
      ? 'Google auth is not configured in this build.'
      : 'Google auth is not configured in this build.';

  String get googleIdTokenInvalid => _isEnglish
      ? 'Google did not return a valid ID token.'
      : 'Google did not return a valid ID token.';

  String signInFailed(String error) => _isEnglish
      ? 'Sign-in failed: $error'
      : 'Sign-in failed: $error';

  String googleSignInFailed(String error) => _isEnglish
      ? 'Google sign-in failed: $error'
      : 'Google sign-in failed: $error';

  String get resetPassword =>
      _isEnglish ? 'Reset password' : 'Reset password';

  String get passwordResetPrompt => _isEnglish
      ? 'Enter your email first to start the reset.'
      : 'Enter your email first to start the reset.';

  String get passwordResetStarted => _isEnglish
      ? 'Reset started. Check the expected channel.'
      : 'Reset started. Check the expected channel.';

  String passwordResetStartedToken(String token) => _isEnglish
      ? 'Reset started. Development token: $token'
      : 'Reset started. Development token: $token';

  String passwordResetFailed(String error) => _isEnglish
      ? 'Password reset failed: $error'
      : 'Password reset failed: $error';

  String get noAccountPrompt =>
      _isEnglish ? "Don't have an account?" : "Don't have an account?";

    String get register => _isEnglish ? 'Register' : 'Register';

    String get createAccount => _isEnglish ? 'Create account' : 'Create account';

  String get completeProfileNext => _isEnglish
      ? 'You will complete your profile in the next step.'
      : 'You will complete your profile in the next step.';

  String get creatingAccount =>
      _isEnglish ? 'Creating account...' : 'Creating account...';

    String get continueButton => _isEnglish ? 'Continue' : 'Continue';

  String get alreadyHaveAccountSignIn => _isEnglish
      ? 'Already have an account? Sign in'
      : 'Already have an account? Sign in';

  String registrationFailed(String error) => _isEnglish
      ? 'Registration failed: $error'
      : 'Registration failed: $error';

  String get verifyingSession =>
      _isEnglish ? 'Verifying session...' : 'Verifying session...';

  String get startingApp =>
      _isEnglish ? 'Starting ClinDiary...' : 'Starting ClinDiary...';

  String get redirectingToLogin =>
      _isEnglish ? 'Redirecting to sign in...' : 'Redirecting to sign in...';

  String get discoverAiPlus =>
      _isEnglish ? 'Discover AI Plus' : 'Discover AI Plus';

  String get todayTitle => _isEnglish ? 'Today' : 'Oggi';
  

  String get profileSetupInProgress => _isEnglish
      ? 'Profile setup in progress'
      : 'Profile setup in progress';

  String get completeOnboardingToStart => _isEnglish
      ? 'Complete onboarding to get started.'
      : 'Complete onboarding to get started.';

  String get chooseRecapOrSaveCheckUp => _isEnglish
      ? 'Choose a recap or save a check-up.'
      : 'Choose a recap or save a check-up.';

    String get alertsAllClear => _isEnglish ? 'All clear' : 'All clear';

  String alertsCountLabel(int count) => _isEnglish
      ? '$count alerts'
      : '$count alerts';

  String get notificationsUnread => _isEnglish
      ? 'Unread'
      : 'Unread';

  String get notificationsAllCaughtUp => _isEnglish
      ? 'All caught up'
      : 'All caught up';

  String get medicationsDue => _isEnglish
      ? 'Medications due'
      : 'Medications due';

  String get medicationsAllCaughtUp => _isEnglish
      ? 'All set'
      : 'All set';

    String get aiRecap => _isEnglish ? 'AI Recap' : 'AI Recap';

    String get checkUp => _isEnglish ? 'Check-up' : 'Check-up';

    String get demoScenarios => _isEnglish ? 'Demo scenarios' : 'Demo scenarios';

  String get judgeModeSubtitle => _isEnglish
      ? 'Judge mode active. Switch scenario and open the local recap right away.'
      : 'Judge mode active. Switch scenario and open the local recap right away.';

    String get openAiRecap => _isEnglish ? 'Open AI Recap' : 'Open AI Recap';

    String get goTo => _isEnglish ? 'Go to' : 'Go to';

    String get documents => _isEnglish ? 'Documents' : 'Documents';

    String get reports => _isEnglish ? 'Reports' : 'Reports';

    String get medications => _isEnglish ? 'Medications' : 'Medications';

    String get treatments => _isEnglish ? 'Treatments' : 'Treatments';

    String get prevention => _isEnglish ? 'Prevention' : 'Prevention';

    String get checkups => _isEnglish ? 'Checkups' : 'Checkups';

    String get devices => _isEnglish ? 'Devices' : 'Devices';

    String get dossier => _isEnglish ? 'Dossier' : 'Dossier';

    String get history => _isEnglish ? 'History' : 'History';

    String get profiles => _isEnglish ? 'Profiles' : 'Profiles';

    String get manage => _isEnglish ? 'Manage' : 'Manage';

    String get add => _isEnglish ? 'Add' : 'Add';

    String get more => _isEnglish ? 'More' : 'More';

  String get secondaryTools => _isEnglish ? 'Secondary tools' : 'Strumenti secondari';

    String get timeline => _isEnglish ? 'Timeline' : 'Timeline';

    String get notifications => _isEnglish ? 'Notifications' : 'Notifications';

    String get smartwatch => _isEnglish ? 'Smartwatch' : 'Smartwatch';

    String get aiPlus => _isEnglish ? 'AI Plus' : 'AI Plus';

    String get alerts => _isEnglish ? 'Alerts' : 'Alerts';

    String get primaryProfileLabel => _isEnglish ? 'primary' : 'primary';

  String activeProfileLabel(String profileName) => _isEnglish
      ? 'You are using $profileName'
      : 'You are using $profileName';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}