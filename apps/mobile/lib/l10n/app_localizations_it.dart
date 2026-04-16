// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'ClinDiary';

  @override
  String get appSubtitle => 'Personal health diary.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Personal health diary.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordMinLength => 'Minimum 8 characters';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signingInWithGoogle => 'Signing in with Google...';

  @override
  String get googleAuthNotConfigured =>
      'Google auth is not configured in this build.';

  @override
  String get googleIdTokenInvalid => 'Google did not return a valid ID token.';

  @override
  String signInFailed(Object error) {
    return 'Sign-in failed: $error';
  }

  @override
  String googleSignInFailed(Object error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get resetPassword => 'Reset password';

  @override
  String get passwordResetPrompt =>
      'Enter your email first to start the reset.';

  @override
  String get passwordResetStarted =>
      'Reset started. Check the expected channel.';

  @override
  String passwordResetStartedToken(Object token) {
    return 'Reset started. Development token: $token';
  }

  @override
  String passwordResetFailed(Object error) {
    return 'Password reset failed: $error';
  }

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get register => 'Register';

  @override
  String get createAccount => 'Create account';

  @override
  String get completeProfileNext =>
      'You will complete your profile in the next step.';

  @override
  String get creatingAccount => 'Creating account...';

  @override
  String get continueButton => 'Continue';

  @override
  String get alreadyHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String registrationFailed(Object error) {
    return 'Registration failed: $error';
  }

  @override
  String get verifyingSession => 'Verifying session...';

  @override
  String get startingApp => 'Starting ClinDiary...';

  @override
  String get redirectingToLogin => 'Redirecting to sign in...';

  @override
  String get discoverAiPlus => 'Discover AI Plus';

  @override
  String get todayTitle => 'Today';

  @override
  String get profileSetupInProgress => 'Profile setup in progress';

  @override
  String get completeOnboardingToStart => 'Complete onboarding to start';

  @override
  String get chooseRecapOrSaveCheckUp => 'Choose recap or save check up';

  @override
  String get alertsAllClear => 'All clear';

  @override
  String alertsCountLabel(int count) {
    return '$count avvisi';
  }

  @override
  String get notificationsUnread => 'Unread';

  @override
  String get notificationsAllCaughtUp => 'All caught up';

  @override
  String get medicationsDue => 'Due';

  @override
  String get medicationsAllCaughtUp => 'All caught up';

  @override
  String get aiRecap => 'AI Recap';

  @override
  String get checkUp => 'Check-up';

  @override
  String get demoScenarios => 'Demo Scenarios';

  @override
  String get judgeModeSubtitle => 'Judge Mode';

  @override
  String get openAiRecap => 'Open AI Recap';

  @override
  String get goTo => 'Go To';

  @override
  String get documents => 'Documents';

  @override
  String get reports => 'Reports';

  @override
  String get medications => 'Medications';

  @override
  String get treatments => 'Treatments';

  @override
  String get prevention => 'Prevention';

  @override
  String get checkups => 'Checkups';

  @override
  String get devices => 'Devices';

  @override
  String get dossier => 'Dossier';

  @override
  String get history => 'History';

  @override
  String get profiles => 'Profiles';

  @override
  String activeProfileLabel(String name) {
    return 'Active: $name';
  }

  @override
  String get manage => 'Manage';

  @override
  String get add => 'Add';

  @override
  String get more => 'More';

  @override
  String get secondaryTools => 'Secondary Tools';

  @override
  String get timeline => 'Timeline';

  @override
  String get notifications => 'Notifications';

  @override
  String get smartwatch => 'Smartwatch';

  @override
  String get aiPlus => 'AI+';

  @override
  String get alerts => 'Alerts';

  @override
  String get primaryProfileLabel => 'Primary';
}
