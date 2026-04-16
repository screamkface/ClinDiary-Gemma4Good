import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ClinDiary'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal health diary.'**
  String get appSubtitle;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal health diary.'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get passwordMinLength;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signingInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signing in with Google...'**
  String get signingInWithGoogle;

  /// No description provided for @googleAuthNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Google auth is not configured in this build.'**
  String get googleAuthNotConfigured;

  /// No description provided for @googleIdTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'Google did not return a valid ID token.'**
  String get googleIdTokenInvalid;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String signInFailed(Object error);

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String googleSignInFailed(Object error);

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @passwordResetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your email first to start the reset.'**
  String get passwordResetPrompt;

  /// No description provided for @passwordResetStarted.
  ///
  /// In en, this message translates to:
  /// **'Reset started. Check the expected channel.'**
  String get passwordResetStarted;

  /// No description provided for @passwordResetStartedToken.
  ///
  /// In en, this message translates to:
  /// **'Reset started. Development token: {token}'**
  String passwordResetStartedToken(Object token);

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset failed: {error}'**
  String passwordResetFailed(Object error);

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t have an account?'**
  String get noAccountPrompt;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @completeProfileNext.
  ///
  /// In en, this message translates to:
  /// **'You will complete your profile in the next step.'**
  String get completeProfileNext;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String registrationFailed(Object error);

  /// No description provided for @verifyingSession.
  ///
  /// In en, this message translates to:
  /// **'Verifying session...'**
  String get verifyingSession;

  /// No description provided for @startingApp.
  ///
  /// In en, this message translates to:
  /// **'Starting ClinDiary...'**
  String get startingApp;

  /// No description provided for @redirectingToLogin.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to sign in...'**
  String get redirectingToLogin;

  /// No description provided for @discoverAiPlus.
  ///
  /// In en, this message translates to:
  /// **'Discover AI Plus'**
  String get discoverAiPlus;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @profileSetupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Profile setup in progress'**
  String get profileSetupInProgress;

  /// No description provided for @completeOnboardingToStart.
  ///
  /// In en, this message translates to:
  /// **'Complete onboarding to start'**
  String get completeOnboardingToStart;

  /// No description provided for @chooseRecapOrSaveCheckUp.
  ///
  /// In en, this message translates to:
  /// **'Choose recap or save check up'**
  String get chooseRecapOrSaveCheckUp;

  /// No description provided for @alertsAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get alertsAllClear;

  /// No description provided for @alertsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} alerts'**
  String alertsCountLabel(int count);

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// No description provided for @notificationsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationsAllCaughtUp;

  /// No description provided for @medicationsDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get medicationsDue;

  /// No description provided for @medicationsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get medicationsAllCaughtUp;

  /// No description provided for @aiRecap.
  ///
  /// In en, this message translates to:
  /// **'AI Recap'**
  String get aiRecap;

  /// No description provided for @checkUp.
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get checkUp;

  /// No description provided for @demoScenarios.
  ///
  /// In en, this message translates to:
  /// **'Demo Scenarios'**
  String get demoScenarios;

  /// No description provided for @judgeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Judge Mode'**
  String get judgeModeSubtitle;

  /// No description provided for @openAiRecap.
  ///
  /// In en, this message translates to:
  /// **'Open AI Recap'**
  String get openAiRecap;

  /// No description provided for @goTo.
  ///
  /// In en, this message translates to:
  /// **'Go To'**
  String get goTo;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @medications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// No description provided for @treatments.
  ///
  /// In en, this message translates to:
  /// **'Treatments'**
  String get treatments;

  /// No description provided for @prevention.
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get prevention;

  /// No description provided for @checkups.
  ///
  /// In en, this message translates to:
  /// **'Checkups'**
  String get checkups;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @dossier.
  ///
  /// In en, this message translates to:
  /// **'Dossier'**
  String get dossier;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @activeProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Active: {name}'**
  String activeProfileLabel(String name);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @secondaryTools.
  ///
  /// In en, this message translates to:
  /// **'Secondary Tools'**
  String get secondaryTools;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @smartwatch.
  ///
  /// In en, this message translates to:
  /// **'Smartwatch'**
  String get smartwatch;

  /// No description provided for @aiPlus.
  ///
  /// In en, this message translates to:
  /// **'AI+'**
  String get aiPlus;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @primaryProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryProfileLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
