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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @activeProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Active: {name}'**
  String activeProfileLabel(String name);

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:190)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:301)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1431)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add3;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:156)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add4;

  /// No description provided for @aiPlus.
  ///
  /// In en, this message translates to:
  /// **'AI+'**
  String get aiPlus;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:217)
  ///
  /// In en, this message translates to:
  /// **'AI Recap'**
  String get aiRecap;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:520)
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// Title text (lib/features/home/presentation/home_screen.dart:327)
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts2;

  /// Title text (lib/features/home/presentation/home_screen.dart:331)
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts3;

  /// Title text (lib/features/home/presentation/home_screen.dart:879)
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts4;

  /// Title text (lib/features/home/presentation/home_screen.dart:894)
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts5;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:229)
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts6;

  /// Title text (lib/features/alerts/presentation/alerts_screen.dart:43)
  ///
  /// In en, this message translates to:
  /// **'Alert center'**
  String get alertsAlertCenter;

  /// No description provided for @alertsAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get alertsAllClear;

  /// User-facing UI text (lib/features/alerts/presentation/alert_ui.dart:10)
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get alertsAttention;

  /// User-facing UI text (lib/features/alerts/presentation/alert_ui.dart:8)
  ///
  /// In en, this message translates to:
  /// **'Contact doctor'**
  String get alertsContactDoctor;

  /// No description provided for @alertsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} alerts'**
  String alertsCountLabel(int count);

  /// User-facing UI text (lib/features/alerts/presentation/alerts_screen.dart:39)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get alertsDdMmmYyyyHhMm;

  /// User-facing UI text (lib/features/alerts/presentation/alert_ui.dart:12)
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get alertsInfo;

  /// User-facing UI text (lib/features/alerts/presentation/alerts_screen.dart:121)
  ///
  /// In en, this message translates to:
  /// **'Mark resolved'**
  String get alertsMarkResolved;

  /// User-facing UI text (lib/features/alerts/presentation/alerts_screen.dart:58)
  ///
  /// In en, this message translates to:
  /// **'No open clinical alerts.'**
  String get alertsNoOpenClinicalAlerts;

  /// User-facing UI text (lib/features/alerts/presentation/alerts_screen.dart:106)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get alertsOpen;

  /// User-facing UI text (lib/features/alerts/presentation/alerts_screen.dart:106)
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get alertsResolved;

  /// User-facing UI text (lib/features/alerts/presentation/alert_ui.dart:6)
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get alertsUrgency;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccountSignIn;

  /// User-facing UI text (lib/app/core/app_config.dart:13)
  ///
  /// In en, this message translates to:
  /// **'HACKATHON_DEMO_MODE'**
  String get appConfigHackathonDemoMode;

  /// User-facing UI text (lib/app/core/app_config.dart:16)
  ///
  /// In en, this message translates to:
  /// **'LOCAL_ONLY_MODE'**
  String get appConfigLocalOnlyMode;

  /// User-facing UI text (lib/app/core/security/app_lock_controller.dart:48)
  ///
  /// In en, this message translates to:
  /// **'Set a PIN before enabling app lock.'**
  String get appLockControllerSetAPinBeforeEnablingApp;

  /// Input label text (lib/app/core/security/app_lock_gate.dart:164)
  ///
  /// In en, this message translates to:
  /// **'6 digit PIN'**
  String get appLockGate6DigitPin;

  /// User-facing UI text (lib/app/core/security/app_lock_gate.dart:146)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary is locked'**
  String get appLockGateClindiaryIsLocked;

  /// Snackbar message (lib/app/core/security/app_lock_gate.dart:61)
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN.'**
  String get appLockGateIncorrectPin;

  /// User-facing UI text (lib/app/core/security/app_lock_gate.dart:172)
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockGateUnlock;

  /// User-facing UI text (lib/app/core/security/app_lock_gate.dart:153)
  ///
  /// In en, this message translates to:
  /// **'Unlock to access local health data on this device.'**
  String get appLockGateUnlockToAccessLocalHealthData;

  /// Snackbar message (lib/app/core/security/app_lock_gate.dart:78)
  ///
  /// In en, this message translates to:
  /// **'Unlock was not completed.'**
  String get appLockGateUnlockWasNotCompleted;

  /// User-facing UI text (lib/app/core/security/app_lock_gate.dart:172)
  ///
  /// In en, this message translates to:
  /// **'Unlocking...'**
  String get appLockGateUnlocking;

  /// User-facing UI text (lib/app/core/security/app_lock_gate.dart:179)
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get appLockGateUseBiometrics;

  /// User-facing UI text (lib/app/core/security/app_lock_service.dart:89)
  ///
  /// In en, this message translates to:
  /// **'Unlock ClinDiary to access local health data.'**
  String get appLockServiceUnlockClindiaryToAccessLocalHealth;

  /// User-facing UI text (lib/app/core/security/app_lock_service.dart:102)
  ///
  /// In en, this message translates to:
  /// **'Use a 6 digit PIN.'**
  String get appLockServiceUseA6DigitPin;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal health diary.'**
  String get appSubtitle;

  /// User-facing UI text (lib/features/auth/presentation/session_gate_screen.dart:39)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary'**
  String get appTitle;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:206)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary'**
  String get appTitle2;

  /// User-facing UI text (lib/shared/widgets/clin_diary_logo.dart:15)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary'**
  String get appTitle3;

  /// User-facing UI text (lib/shared/widgets/async_view.dart:8)
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get asyncViewLoading;

  /// User-facing UI text (lib/features/auth/presentation/login_screen.dart:18)
  ///
  /// In en, this message translates to:
  /// **'ChangeMe123!'**
  String get authChangeme123;

  /// User-facing UI text (lib/features/auth/presentation/session_gate_screen.dart:75)
  ///
  /// In en, this message translates to:
  /// **'Redirecting to login...'**
  String get authRedirectingToLogin;

  /// User-facing UI text (lib/features/auth/presentation/session_gate_screen.dart:71)
  ///
  /// In en, this message translates to:
  /// **'Starting app...'**
  String get authStartingApp;

  /// User-facing UI text (lib/features/billing/presentation/billing_screen.dart:21)
  ///
  /// In en, this message translates to:
  /// **'Billing and plan activation flows are disabled. Features are driven by local-only mode and on-device capabilities.'**
  String get billingBillingAndPlanActivationFlowsAre;

  /// Title text (lib/features/billing/presentation/billing_screen.dart:13)
  ///
  /// In en, this message translates to:
  /// **'Billing removed for hackathon'**
  String get billingBillingRemovedForHackathon;

  /// Title text (lib/features/billing/presentation/billing_screen.dart:18)
  ///
  /// In en, this message translates to:
  /// **'Local-first build'**
  String get billingLocalFirstBuild;

  /// User-facing UI text (lib/features/billing/presentation/billing_screen.dart:28)
  ///
  /// In en, this message translates to:
  /// **'Open Privacy and AI settings'**
  String get billingOpenPrivacyAndAiSettings;

  /// Title text (lib/features/billing/presentation/billing_screen.dart:19)
  ///
  /// In en, this message translates to:
  /// **'This hackathon build runs without billing gates.'**
  String get billingThisHackathonBuildRunsWithoutBilling;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:413)
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get checkUp;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:482)
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get checkUp2;

  /// Title text (lib/features/history/presentation/history_screen.dart:545)
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get checkUp3;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:76)
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get checkUp4;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:414)
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get checkUp5;

  /// No description provided for @checkups.
  ///
  /// In en, this message translates to:
  /// **'Checkups'**
  String get checkups;

  /// No description provided for @chooseRecapOrSaveCheckUp.
  ///
  /// In en, this message translates to:
  /// **'Choose recap or save check up'**
  String get chooseRecapOrSaveCheckUp;

  /// No description provided for @completeOnboardingToStart.
  ///
  /// In en, this message translates to:
  /// **'Complete onboarding to start'**
  String get completeOnboardingToStart;

  /// No description provided for @completeProfileNext.
  ///
  /// In en, this message translates to:
  /// **'You will complete your profile in the next step.'**
  String get completeProfileNext;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:237)
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// Title text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:145)
  ///
  /// In en, this message translates to:
  /// **'A symptom logged yesterday needs a fast check.'**
  String get dailyJournalASymptomLoggedYesterdayNeedsA;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:560)
  ///
  /// In en, this message translates to:
  /// **'Add a symptom now?'**
  String get dailyJournalAddASymptomNow;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:759)
  ///
  /// In en, this message translates to:
  /// **'Add another voice message or fill in the fields manually if needed.'**
  String get dailyJournalAddAnotherVoiceMessageOrFill;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:251)
  ///
  /// In en, this message translates to:
  /// **'Add notes or record voice before extracting symptoms'**
  String get dailyJournalAddNotesOrRecordVoiceBefore;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:568)
  ///
  /// In en, this message translates to:
  /// **'Add now'**
  String get dailyJournalAddNow;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:56)
  ///
  /// In en, this message translates to:
  /// **'Add symptom'**
  String get dailyJournalAddSymptom;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:443)
  ///
  /// In en, this message translates to:
  /// **'Add symptom'**
  String get dailyJournalAddSymptom2;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:231)
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get dailyJournalAdditionalDetails;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:313)
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get dailyJournalAdditionalDetails2;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:844)
  ///
  /// In en, this message translates to:
  /// **'Appetite'**
  String get dailyJournalAppetite;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:338)
  ///
  /// In en, this message translates to:
  /// **'Associated symptoms'**
  String get dailyJournalAssociatedSymptoms;

  /// Title text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:302)
  ///
  /// In en, this message translates to:
  /// **'Associated with nausea'**
  String get dailyJournalAssociatedWithNausea;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:60)
  ///
  /// In en, this message translates to:
  /// **'Attach to latest check-up'**
  String get dailyJournalAttachToLatestCheckUp;

  /// Title text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:308)
  ///
  /// In en, this message translates to:
  /// **'Aura present'**
  String get dailyJournalAuraPresent;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:204)
  ///
  /// In en, this message translates to:
  /// **'Body location'**
  String get dailyJournalBodyLocation;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:127)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dailyJournalCancel;

  /// Snackbar message (lib/features/daily_journal/presentation/daily_check_in_screen.dart:548)
  ///
  /// In en, this message translates to:
  /// **'Check-in and voice symptoms saved'**
  String get dailyJournalCheckInAndVoiceSymptomsSaved;

  /// Title text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:782)
  ///
  /// In en, this message translates to:
  /// **'Check-in basics'**
  String get dailyJournalCheckInBasics;

  /// Snackbar message (lib/features/daily_journal/presentation/daily_check_in_screen.dart:485)
  ///
  /// In en, this message translates to:
  /// **'Check-in filled in by Gemma 4'**
  String get dailyJournalCheckInFilledInByGemma;

  /// Title text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:559)
  ///
  /// In en, this message translates to:
  /// **'Check-in saved'**
  String get dailyJournalCheckInSaved;

  /// Snackbar message (lib/features/daily_journal/presentation/diary_screen.dart:152)
  ///
  /// In en, this message translates to:
  /// **'Check-up deleted'**
  String get dailyJournalCheckUpDeleted;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:635)
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get dailyJournalClear;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:664)
  ///
  /// In en, this message translates to:
  /// **'Clear detected symptoms'**
  String get dailyJournalClearDetectedSymptoms;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:362)
  ///
  /// In en, this message translates to:
  /// **'Cough'**
  String get dailyJournalCough;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:59)
  ///
  /// In en, this message translates to:
  /// **'Create a check-up first'**
  String get dailyJournalCreateACheckUpFirst;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:95)
  ///
  /// In en, this message translates to:
  /// **'Create a check-up first, then add symptoms.'**
  String get dailyJournalCreateACheckUpFirstThen;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:331)
  ///
  /// In en, this message translates to:
  /// **'Create first check-up'**
  String get dailyJournalCreateFirstCheckUp;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:177)
  ///
  /// In en, this message translates to:
  /// **'Current intensity'**
  String get dailyJournalCurrentIntensity;

  /// Input label text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:788)
  ///
  /// In en, this message translates to:
  /// **'Date (YYYY-MM-DD)'**
  String get dailyJournalDateYyyyMmDd;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:168)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get dailyJournalDdMmmYyyy;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:131)
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dailyJournalDelete;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:120)
  ///
  /// In en, this message translates to:
  /// **'Delete check-up?'**
  String get dailyJournalDeleteCheckUp;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:448)
  ///
  /// In en, this message translates to:
  /// **'Delete check-up'**
  String get dailyJournalDeleteCheckUp2;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:179)
  ///
  /// In en, this message translates to:
  /// **'Describe the symptom'**
  String get dailyJournalDescribeTheSymptom;

  /// Title text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:218)
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get dailyJournalDetails;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:658)
  ///
  /// In en, this message translates to:
  /// **'Detect symptoms with Gemma'**
  String get dailyJournalDetectSymptomsWithGemma;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:174)
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get dailyJournalDiary;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:197)
  ///
  /// In en, this message translates to:
  /// **'Duration in minutes'**
  String get dailyJournalDurationInMinutes;

  /// Input hint text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:180)
  ///
  /// In en, this message translates to:
  /// **'E.g. abdominal pain after meals'**
  String get dailyJournalEGAbdominalPainAfterMeals;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:233)
  ///
  /// In en, this message translates to:
  /// **'E.g. it appears after lunch and improves when lying down'**
  String get dailyJournalEGItAppearsAfterLunch;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:829)
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get dailyJournalEnergy;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:187)
  ///
  /// In en, this message translates to:
  /// **'Enter the symptom'**
  String get dailyJournalEnterTheSymptom;

  /// Input hint text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:193)
  ///
  /// In en, this message translates to:
  /// **'Example: less intense than yesterday'**
  String get dailyJournalExampleLessIntenseThanYesterday;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:311)
  ///
  /// In en, this message translates to:
  /// **'Exception:'**
  String get dailyJournalException;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:491)
  ///
  /// In en, this message translates to:
  /// **'Exception:'**
  String get dailyJournalException2;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:363)
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get dailyJournalFatigue;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:360)
  ///
  /// In en, this message translates to:
  /// **'Fever'**
  String get dailyJournalFever;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:345)
  ///
  /// In en, this message translates to:
  /// **'For this symptom you can use duration, intensity and location.'**
  String get dailyJournalForThisSymptomYouCanUse;

  /// Title text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:602)
  ///
  /// In en, this message translates to:
  /// **'Gemma 4 voice dictation'**
  String get dailyJournalGemma4VoiceDictation;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:746)
  ///
  /// In en, this message translates to:
  /// **'Gemma asks for clarification before closing the check-in.'**
  String get dailyJournalGemmaAsksForClarificationBeforeClosing;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:300)
  ///
  /// In en, this message translates to:
  /// **'Gemma did not detect symptoms from the current notes.'**
  String get dailyJournalGemmaDidNotDetectSymptomsFrom;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:741)
  ///
  /// In en, this message translates to:
  /// **'Gemma filled in the main fields. Open \"Symptoms via Gemma\" to detect symptoms from notes.'**
  String get dailyJournalGemmaFilledInTheMainFields;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:712)
  ///
  /// In en, this message translates to:
  /// **'Gemma is filling in the fields...'**
  String get dailyJournalGemmaIsFillingInTheFields;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:303)
  ///
  /// In en, this message translates to:
  /// **'Gemma refreshed detected symptoms.'**
  String get dailyJournalGemmaRefreshedDetectedSymptoms;

  /// Input label text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:812)
  ///
  /// In en, this message translates to:
  /// **'General notes'**
  String get dailyJournalGeneralNotes;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:854)
  ///
  /// In en, this message translates to:
  /// **'General pain'**
  String get dailyJournalGeneralPain;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:359)
  ///
  /// In en, this message translates to:
  /// **'Headache'**
  String get dailyJournalHeadache;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:849)
  ///
  /// In en, this message translates to:
  /// **'Hydration'**
  String get dailyJournalHydration;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:78)
  ///
  /// In en, this message translates to:
  /// **'I did not hear enough speech. Tap Speak and start talking right away.'**
  String get dailyJournalIDidNotHearEnoughSpeech;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:451)
  ///
  /// In en, this message translates to:
  /// **'I did not recognize any useful text.'**
  String get dailyJournalIDidNotRecognizeAnyUseful;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:224)
  ///
  /// In en, this message translates to:
  /// **'If you prefer to describe the symptom in words, ClinDiary saves the free text so you can find it later in the history and recaps.'**
  String get dailyJournalIfYouPreferToDescribeThe;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:209)
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get dailyJournalIntensity;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:792)
  ///
  /// In en, this message translates to:
  /// **'Invalid date'**
  String get dailyJournalInvalidDate;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:564)
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get dailyJournalLater;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:320)
  ///
  /// In en, this message translates to:
  /// **'Latest check-ups'**
  String get dailyJournalLatestCheckUps;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:145)
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get dailyJournalList;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:706)
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get dailyJournalListening;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:406)
  ///
  /// In en, this message translates to:
  /// **'Local draft'**
  String get dailyJournalLocalDraft;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:284)
  ///
  /// In en, this message translates to:
  /// **'Local sync up to date'**
  String get dailyJournalLocalSyncUpToDate;

  /// Title text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:135)
  ///
  /// In en, this message translates to:
  /// **'Main symptom'**
  String get dailyJournalMainSymptom;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:323)
  ///
  /// In en, this message translates to:
  /// **'Maximum temperature (°C)'**
  String get dailyJournalMaximumTemperatureC;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:359)
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied.'**
  String get dailyJournalMicrophonePermissionDenied;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:834)
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get dailyJournalMood;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:361)
  ///
  /// In en, this message translates to:
  /// **'Nausea'**
  String get dailyJournalNausea;

  /// Title text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:594)
  ///
  /// In en, this message translates to:
  /// **'New check-in'**
  String get dailyJournalNewCheckIn;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:49)
  ///
  /// In en, this message translates to:
  /// **'New check-up'**
  String get dailyJournalNewCheckUp;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:306)
  ///
  /// In en, this message translates to:
  /// **'New check-up'**
  String get dailyJournalNewCheckUp2;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:325)
  ///
  /// In en, this message translates to:
  /// **'No check-up recorded yet.'**
  String get dailyJournalNoCheckUpRecordedYet;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:267)
  ///
  /// In en, this message translates to:
  /// **'No check-ups'**
  String get dailyJournalNoCheckUps;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:390)
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get dailyJournalNoNotes;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:165)
  ///
  /// In en, this message translates to:
  /// **'No, resolved'**
  String get dailyJournalNoResolved;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:371)
  ///
  /// In en, this message translates to:
  /// **'notListening'**
  String get dailyJournalNotlistening;

  /// Title text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:173)
  ///
  /// In en, this message translates to:
  /// **'Only if you want to be more precise.'**
  String get dailyJournalOnlyIfYouWantToBe;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:68)
  ///
  /// In en, this message translates to:
  /// **'Open history'**
  String get dailyJournalOpenHistory;

  /// Title text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:172)
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get dailyJournalOptionalDetails;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:133)
  ///
  /// In en, this message translates to:
  /// **'Original symptom not available.'**
  String get dailyJournalOriginalSymptomNotAvailable;

  /// Snackbar message (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:65)
  ///
  /// In en, this message translates to:
  /// **'Original symptom not found anymore.'**
  String get dailyJournalOriginalSymptomNotFoundAnymore;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:311)
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get dailyJournalQuickActions;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:50)
  ///
  /// In en, this message translates to:
  /// **'Quick daily recap and notes'**
  String get dailyJournalQuickDailyRecapAndNotes;

  /// Title text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:820)
  ///
  /// In en, this message translates to:
  /// **'Quick metrics'**
  String get dailyJournalQuickMetrics;

  /// Input label text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:192)
  ///
  /// In en, this message translates to:
  /// **'Quick note'**
  String get dailyJournalQuickNote;

  /// Title text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:144)
  ///
  /// In en, this message translates to:
  /// **'Quick update'**
  String get dailyJournalQuickUpdate;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:864)
  ///
  /// In en, this message translates to:
  /// **'Save check-in'**
  String get dailyJournalSaveCheckIn;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:258)
  ///
  /// In en, this message translates to:
  /// **'Save symptom'**
  String get dailyJournalSaveSymptom;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:864)
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get dailyJournalSaving;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:258)
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get dailyJournalSaving2;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:69)
  ///
  /// In en, this message translates to:
  /// **'See previous days and events'**
  String get dailyJournalSeePreviousDaysAndEvents;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:650)
  ///
  /// In en, this message translates to:
  /// **'Send to Gemma'**
  String get dailyJournalSendToGemma;

  /// Input label text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:804)
  ///
  /// In en, this message translates to:
  /// **'Sleep hours'**
  String get dailyJournalSleepHours;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:824)
  ///
  /// In en, this message translates to:
  /// **'Sleep quality'**
  String get dailyJournalSleepQuality;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:623)
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get dailyJournalSpeak;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:607)
  ///
  /// In en, this message translates to:
  /// **'Speak in English: ClinDiary transcribes your voice, Gemma 4 fills in the check-in and can add recognized symptoms.'**
  String get dailyJournalSpeakInEnglishClindiaryTranscribesYour;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:387)
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available on this device.'**
  String get dailyJournalSpeechRecognitionIsNotAvailableOn;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:244)
  ///
  /// In en, this message translates to:
  /// **'Start quickly from one action.'**
  String get dailyJournalStartQuicklyFromOneAction;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:623)
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get dailyJournalStop;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:839)
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get dailyJournalStress;

  /// Input label text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:162)
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get dailyJournalSymptom;

  /// Title text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:128)
  ///
  /// In en, this message translates to:
  /// **'Symptom details'**
  String get dailyJournalSymptomDetails;

  /// Title text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:128)
  ///
  /// In en, this message translates to:
  /// **'Symptom follow-up'**
  String get dailyJournalSymptomFollowUp;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:91)
  ///
  /// In en, this message translates to:
  /// **'Symptom marked as resolved for today.'**
  String get dailyJournalSymptomMarkedAsResolvedForToday;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:90)
  ///
  /// In en, this message translates to:
  /// **'Symptom updated for today.'**
  String get dailyJournalSymptomUpdatedForToday;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:684)
  ///
  /// In en, this message translates to:
  /// **'Symptoms via Gemma'**
  String get dailyJournalSymptomsViaGemma;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:413)
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get dailyJournalSyncPending;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:30)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get dailyJournalT;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:106)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get dailyJournalT2;

  /// User-facing UI text (lib/features/daily_journal/presentation/diary_screen.dart:122)
  ///
  /// In en, this message translates to:
  /// **'This removes the check-up and related symptom/vital events.'**
  String get dailyJournalThisRemovesTheCheckUpAnd;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:716)
  ///
  /// In en, this message translates to:
  /// **'Transcript (edit before sending)'**
  String get dailyJournalTranscriptEditBeforeSending;

  /// Title text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:333)
  ///
  /// In en, this message translates to:
  /// **'Vomiting present'**
  String get dailyJournalVomitingPresent;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_entry_screen.dart:150)
  ///
  /// In en, this message translates to:
  /// **'Write your own'**
  String get dailyJournalWriteYourOwn;

  /// User-facing UI text (lib/features/daily_journal/presentation/symptom_follow_up_screen.dart:158)
  ///
  /// In en, this message translates to:
  /// **'Yes, still present'**
  String get dailyJournalYesStillPresent;

  /// User-facing UI text (lib/features/daily_journal/presentation/daily_check_in_screen.dart:732)
  ///
  /// In en, this message translates to:
  /// **'Your transcript will appear here after recording. Edit as needed before sending to Gemma.'**
  String get dailyJournalYourTranscriptWillAppearHereAfter;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:71)
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get debugActions;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:24)
  ///
  /// In en, this message translates to:
  /// **'App is in local-only mode — no operations to sync.'**
  String get debugAppIsInLocalOnlyMode;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:85)
  ///
  /// In en, this message translates to:
  /// **'Cleaning...'**
  String get debugCleaning;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:85)
  ///
  /// In en, this message translates to:
  /// **'Clear debug'**
  String get debugClearDebug;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:52)
  ///
  /// In en, this message translates to:
  /// **'dd MMM HH:mm'**
  String get debugDdMmmHhMm;

  /// Snackbar message (lib/features/debug/presentation/sync_debug_screen.dart:39)
  ///
  /// In en, this message translates to:
  /// **'Local queue and traces cleared.'**
  String get debugLocalQueueAndTracesCleared;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:56)
  ///
  /// In en, this message translates to:
  /// **'Local sync'**
  String get debugLocalSync;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:132)
  ///
  /// In en, this message translates to:
  /// **'No pending operations.'**
  String get debugNoPendingOperations;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:135)
  ///
  /// In en, this message translates to:
  /// **'No pending operations.'**
  String get debugNoPendingOperations2;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:166)
  ///
  /// In en, this message translates to:
  /// **'No traces recorded.'**
  String get debugNoTracesRecorded;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:169)
  ///
  /// In en, this message translates to:
  /// **'No traces recorded.'**
  String get debugNoTracesRecorded2;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:122)
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get debugOther;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:106)
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get debugProfile;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:95)
  ///
  /// In en, this message translates to:
  /// **'Queue summary'**
  String get debugQueueSummary;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:130)
  ///
  /// In en, this message translates to:
  /// **'Queued operations'**
  String get debugQueuedOperations;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:153)
  ///
  /// In en, this message translates to:
  /// **'Queued operations'**
  String get debugQueuedOperations2;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:157)
  ///
  /// In en, this message translates to:
  /// **'Queued operations'**
  String get debugQueuedOperations3;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:96)
  ///
  /// In en, this message translates to:
  /// **'Quick status of offline operations.'**
  String get debugQuickStatusOfOfflineOperations;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:164)
  ///
  /// In en, this message translates to:
  /// **'Recent network traces'**
  String get debugRecentNetworkTraces;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:80)
  ///
  /// In en, this message translates to:
  /// **'Sync...'**
  String get debugSync;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:80)
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get debugSync2;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:102)
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get debugTotal;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:188)
  ///
  /// In en, this message translates to:
  /// **'Trace rete recenti'**
  String get debugTraceReteRecenti;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:192)
  ///
  /// In en, this message translates to:
  /// **'Trace rete recenti'**
  String get debugTraceReteRecenti2;

  /// Title text (lib/features/debug/presentation/sync_debug_screen.dart:72)
  ///
  /// In en, this message translates to:
  /// **'Use these actions only for local debug.'**
  String get debugUseTheseActionsOnlyForLocal;

  /// No description provided for @demoScenarios.
  ///
  /// In en, this message translates to:
  /// **'Demo Scenarios'**
  String get demoScenarios;

  /// Title text (lib/features/devices/presentation/devices_screen.dart:197)
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:1045)
  ///
  /// In en, this message translates to:
  /// **'Account or device label'**
  String get devicesAccountOrDeviceLabel;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:101)
  ///
  /// In en, this message translates to:
  /// **'Already imported measurements will remain in the clinical history.'**
  String get devicesAlreadyImportedMeasurementsWillRemainIn;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1269)
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get devicesApiKey;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1350)
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get devicesBloodPressure;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1384)
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get devicesC;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:106)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devicesCancel;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:922)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devicesCancel2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1098)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devicesCancel3;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1355)
  ///
  /// In en, this message translates to:
  /// **'Capillary glucose'**
  String get devicesCapillaryGlucose;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1256)
  ///
  /// In en, this message translates to:
  /// **'Clinical device'**
  String get devicesClinicalDevice;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1299)
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get devicesCompleted;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:338)
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get devicesConfigure;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:462)
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get devicesConfigure2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:259)
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get devicesConnected;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1282)
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get devicesConnected2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:390)
  ///
  /// In en, this message translates to:
  /// **'Connected to this profile'**
  String get devicesConnectedToThisProfile;

  /// Snackbar message (lib/features/devices/presentation/devices_screen.dart:130)
  ///
  /// In en, this message translates to:
  /// **'Connector removed.'**
  String get devicesConnectorRemoved;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:391)
  ///
  /// In en, this message translates to:
  /// **'Connector saved for this profile'**
  String get devicesConnectorSavedForThisProfile;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:507)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get devicesDdMmmYyyyHhMm;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:588)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get devicesDdMmmYyyyHhMm2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:655)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get devicesDdMmmYyyyHhMm3;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:900)
  ///
  /// In en, this message translates to:
  /// **'Device model (optional)'**
  String get devicesDeviceModelOptional;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1258)
  ///
  /// In en, this message translates to:
  /// **'Diabetes'**
  String get devicesDiabetes;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1363)
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get devicesDiastolic;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1288)
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get devicesDisconnected;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1093)
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get devicesDocumentation;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1286)
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get devicesError;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:1053)
  ///
  /// In en, this message translates to:
  /// **'External user ID (optional)'**
  String get devicesExternalUserIdOptional;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1301)
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get devicesFailed;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1388)
  ///
  /// In en, this message translates to:
  /// **'Glucose'**
  String get devicesGlucose;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1353)
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get devicesHeartRate;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1364)
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get devicesHeartRate2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1378)
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get devicesHeartRate3;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:261)
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get devicesImport;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:618)
  ///
  /// In en, this message translates to:
  /// **'Imports, syncs, and bootstrap runs from Wave 1 providers will appear here with their results.'**
  String get devicesImportsSyncsAndBootstrapRunsFrom;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:373)
  ///
  /// In en, this message translates to:
  /// **'Key metrics'**
  String get devicesKeyMetrics;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:487)
  ///
  /// In en, this message translates to:
  /// **'Live sync not ready'**
  String get devicesLiveSyncNotReady;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:1060)
  ///
  /// In en, this message translates to:
  /// **'Manual access token'**
  String get devicesManualAccessToken;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:172)
  ///
  /// In en, this message translates to:
  /// **'Measurement recorded.'**
  String get devicesMeasurementRecorded;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:260)
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get devicesMeasurements;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:561)
  ///
  /// In en, this message translates to:
  /// **'Measurements imported from Wave 1 providers will appear here in chronological order.'**
  String get devicesMeasurementsImportedFromWave1Providers;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:843)
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get devicesMetric;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1389)
  ///
  /// In en, this message translates to:
  /// **'mg/dL'**
  String get devicesMgDl;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1365)
  ///
  /// In en, this message translates to:
  /// **'mmHg'**
  String get devicesMmhg;

  /// Title text (lib/features/devices/presentation/devices_screen.dart:428)
  ///
  /// In en, this message translates to:
  /// **'No connector saved yet'**
  String get devicesNoConnectorSavedYet;

  /// Title text (lib/features/devices/presentation/devices_screen.dart:559)
  ///
  /// In en, this message translates to:
  /// **'No device measurements available yet'**
  String get devicesNoDeviceMeasurementsAvailableYet;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:520)
  ///
  /// In en, this message translates to:
  /// **'No measurements imported yet for this connector.'**
  String get devicesNoMeasurementsImportedYetForThis;

  /// Title text (lib/features/devices/presentation/devices_screen.dart:616)
  ///
  /// In en, this message translates to:
  /// **'No recent imports'**
  String get devicesNoRecentImports;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:909)
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get devicesNotesOptional;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:228)
  ///
  /// In en, this message translates to:
  /// **'OMRON, Withings, iHealth, A&D, and Dexcom in one unified module.'**
  String get devicesOmronWithingsIhealthADAnd;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:429)
  ///
  /// In en, this message translates to:
  /// **'Open the Provider tab and set up the first clinical device.'**
  String get devicesOpenTheProviderTabAndSet;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1352)
  ///
  /// In en, this message translates to:
  /// **'Oxygen saturation'**
  String get devicesOxygenSaturation;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1271)
  ///
  /// In en, this message translates to:
  /// **'Partner platform'**
  String get devicesPartnerPlatform;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:361)
  ///
  /// In en, this message translates to:
  /// **'Partner required'**
  String get devicesPartnerRequired;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1062)
  ///
  /// In en, this message translates to:
  /// **'Paste the token here if you get it from the partner portal'**
  String get devicesPasteTheTokenHereIfYou;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1303)
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get devicesPending;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:258)
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get devicesProvider;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:528)
  ///
  /// In en, this message translates to:
  /// **'Record measurement'**
  String get devicesRecordMeasurement;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:833)
  ///
  /// In en, this message translates to:
  /// **'Record measurement'**
  String get devicesRecordMeasurement2;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:1071)
  ///
  /// In en, this message translates to:
  /// **'Refresh token (optional)'**
  String get devicesRefreshTokenOptional;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1267)
  ///
  /// In en, this message translates to:
  /// **'Remote API'**
  String get devicesRemoteApi;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:110)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get devicesRemove;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:468)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get devicesRemove2;

  /// Title text (lib/features/devices/presentation/devices_screen.dart:98)
  ///
  /// In en, this message translates to:
  /// **'Remove the connector?'**
  String get devicesRemoveTheConnector;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1297)
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get devicesRunning;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1104)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get devicesSave;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:927)
  ///
  /// In en, this message translates to:
  /// **'Save measurement'**
  String get devicesSaveMeasurement;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1104)
  ///
  /// In en, this message translates to:
  /// **'Save setup'**
  String get devicesSaveSetup;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1273)
  ///
  /// In en, this message translates to:
  /// **'SDK/BLE'**
  String get devicesSdkBle;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:366)
  ///
  /// In en, this message translates to:
  /// **'SDK ingest'**
  String get devicesSdkIngest;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:494)
  ///
  /// In en, this message translates to:
  /// **'SDK ready'**
  String get devicesSdkReady;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:353)
  ///
  /// In en, this message translates to:
  /// **'Server ready'**
  String get devicesServerReady;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:354)
  ///
  /// In en, this message translates to:
  /// **'Server to configure'**
  String get devicesServerToConfigure;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1284)
  ///
  /// In en, this message translates to:
  /// **'Setting up'**
  String get devicesSettingUp;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1375)
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get devicesSpo2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:466)
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get devicesSync;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:486)
  ///
  /// In en, this message translates to:
  /// **'Sync live'**
  String get devicesSyncLive;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1362)
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get devicesSystolic;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1354)
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get devicesTemperature;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1383)
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get devicesTemperature2;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:914)
  ///
  /// In en, this message translates to:
  /// **'The measurement is saved with the device current time.'**
  String get devicesTheMeasurementIsSavedWithThe;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:338)
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get devicesUpdate;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1392)
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get devicesValue;

  /// Input label text (lib/features/devices/presentation/devices_screen.dart:1081)
  ///
  /// In en, this message translates to:
  /// **'Vendor API key'**
  String get devicesVendorApiKey;

  /// Title text (lib/features/devices/presentation/devices_screen.dart:226)
  ///
  /// In en, this message translates to:
  /// **'Wave 1 clinical'**
  String get devicesWave1Clinical;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1351)
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get devicesWeight;

  /// User-facing UI text (lib/features/devices/presentation/devices_screen.dart:1371)
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get devicesWeight2;

  /// No description provided for @discoverAiPlus.
  ///
  /// In en, this message translates to:
  /// **'Discover AI Plus'**
  String get discoverAiPlus;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:118)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:131)
  ///
  /// In en, this message translates to:
  /// **'1 file'**
  String get documents1File;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:235)
  ///
  /// In en, this message translates to:
  /// **'1 file'**
  String get documents1File2;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:238)
  ///
  /// In en, this message translates to:
  /// **'1 useful part'**
  String get documents1UsefulPart;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:298)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:516)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents3;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:492)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents4;

  /// Title text (lib/features/home/presentation/home_screen.dart:598)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents5;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:82)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents6;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:51)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get documentsActive;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:300)
  ///
  /// In en, this message translates to:
  /// **'Add a few details so answers work better.'**
  String get documentsAddAFewDetailsSoAnswers;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:146)
  ///
  /// In en, this message translates to:
  /// **'Add at least one valid lab result.'**
  String get documentsAddAtLeastOneValidLab;

  /// Title text (lib/features/documents/presentation/document_upload_screen.dart:143)
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get documentsAddFile;

  /// Title text (lib/features/documents/presentation/document_upload_screen.dart:206)
  ///
  /// In en, this message translates to:
  /// **'Add only the useful information.'**
  String get documentsAddOnlyTheUsefulInformation;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:318)
  ///
  /// In en, this message translates to:
  /// **'Add result'**
  String get documentsAddResult;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:546)
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get documentsAdded;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:443)
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get documentsAll;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:483)
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get documentsAllFiles;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:443)
  ///
  /// In en, this message translates to:
  /// **'Analyte'**
  String get documentsAnalyte;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:369)
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get documentsArchive;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:701)
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get documentsArchive2;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:91)
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get documentsArchived;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:32)
  ///
  /// In en, this message translates to:
  /// **'Are there documents with out-of-range values in the last few months?'**
  String get documentsAreThereDocumentsWithOutOf;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:615)
  ///
  /// In en, this message translates to:
  /// **'Ask about this file'**
  String get documentsAskAboutThisFile;

  /// Input label text (lib/features/documents/presentation/document_query_screen.dart:556)
  ///
  /// In en, this message translates to:
  /// **'Ask about your files'**
  String get documentsAskAboutYourFiles;

  /// Title text (lib/features/documents/presentation/document_query_screen.dart:249)
  ///
  /// In en, this message translates to:
  /// **'Ask files'**
  String get documentsAskFiles;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:771)
  ///
  /// In en, this message translates to:
  /// **'Ask files'**
  String get documentsAskFiles2;

  /// No description provided for @documentsAskFilesExample.
  ///
  /// In en, this message translates to:
  /// **'Example: what should I bring to the doctor?'**
  String get documentsAskFilesExample;

  /// Title text (lib/features/documents/presentation/document_query_history_screen.dart:27)
  ///
  /// In en, this message translates to:
  /// **'Ask files history'**
  String get documentsAskFilesHistory;

  /// No description provided for @documentsAskFilesOnlyCited.
  ///
  /// In en, this message translates to:
  /// **'I will answer only from files I can cite back to you.'**
  String get documentsAskFilesOnlyCited;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:297)
  ///
  /// In en, this message translates to:
  /// **'Ask for a quick explanation or open the file.'**
  String get documentsAskForAQuickExplanationOr;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:609)
  ///
  /// In en, this message translates to:
  /// **'Ask one simple question.'**
  String get documentsAskOneSimpleQuestion;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:459)
  ///
  /// In en, this message translates to:
  /// **'Ask your files'**
  String get documentsAskYourFiles;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:492)
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get documentsAutomatic;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:723)
  ///
  /// In en, this message translates to:
  /// **'Available on demand.'**
  String get documentsAvailableOnDemand;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:371)
  ///
  /// In en, this message translates to:
  /// **'Body part'**
  String get documentsBodyPart;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:100)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get documentsCancel;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:237)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get documentsCancel2;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:272)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get documentsCancel3;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:129)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get documentsCancel4;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:153)
  ///
  /// In en, this message translates to:
  /// **'Choose what you want to add.'**
  String get documentsChooseWhatYouWantToAdd;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:286)
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get documentsClear;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:38)
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get documentsClearAllHistory;

  /// Title text (lib/features/documents/presentation/document_query_history_screen.dart:265)
  ///
  /// In en, this message translates to:
  /// **'Clear all history?'**
  String get documentsClearAllHistory2;

  /// No description provided for @documentsClearAllHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove all your document questions and answers from history. This cannot be undone.'**
  String get documentsClearAllHistoryBody;

  /// No description provided for @documentsClearAllHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all history?'**
  String get documentsClearAllHistoryTitle;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:581)
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get documentsClearSearch;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:654)
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get documentsClearSearch2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:154)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary document'**
  String get documentsClindiaryDocument;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:714)
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get documentsCloseSearch;

  /// Title text (lib/features/documents/presentation/document_review_screen.dart:203)
  ///
  /// In en, this message translates to:
  /// **'Correct and confirm the document'**
  String get documentsCorrectAndConfirmTheDocument;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:208)
  ///
  /// In en, this message translates to:
  /// **'Correct metadata and extracted data.'**
  String get documentsCorrectMetadataAndExtractedData;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:284)
  ///
  /// In en, this message translates to:
  /// **'Corrected or added text'**
  String get documentsCorrectedOrAddedText;

  /// No description provided for @documentsCouldNotReadFilesTryAgain.
  ///
  /// In en, this message translates to:
  /// **'I could not read the files this time. Try again or refresh the index.'**
  String get documentsCouldNotReadFilesTryAgain;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:136)
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get documentsCreate;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:245)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get documentsDdMmmYyyy;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:295)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get documentsDdMmmYyyy2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:327)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get documentsDdMmmYyyyHhMm;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:23)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy HH:mm'**
  String get documentsDdMmmYyyyHhMm2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:105)
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get documentsDelete;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:241)
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get documentsDelete2;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:92)
  ///
  /// In en, this message translates to:
  /// **'Delete document'**
  String get documentsDeleteDocument;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:406)
  ///
  /// In en, this message translates to:
  /// **'Delete document'**
  String get documentsDeleteDocument2;

  /// Title text (lib/features/documents/presentation/document_query_history_screen.dart:230)
  ///
  /// In en, this message translates to:
  /// **'Delete history entry?'**
  String get documentsDeleteHistoryEntry;

  /// No description provided for @documentsDeleteHistoryEntryBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the question and answer from your history.'**
  String get documentsDeleteHistoryEntryBody;

  /// Title text (lib/features/documents/presentation/document_upload_screen.dart:205)
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get documentsDetails;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:239)
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get documentsDischargeSummary;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:10)
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get documentsDischargeSummary2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:237)
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get documentsDischargeSummary3;

  /// Snackbar message (lib/features/documents/presentation/document_detail_screen.dart:128)
  ///
  /// In en, this message translates to:
  /// **'Document deleted.'**
  String get documentsDocumentDeleted;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:331)
  ///
  /// In en, this message translates to:
  /// **'Document details'**
  String get documentsDocumentDetails;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:71)
  ///
  /// In en, this message translates to:
  /// **'Document marked as old. It will not be used in AI recaps.'**
  String get documentsDocumentMarkedAsOldItWill;

  /// Snackbar message (lib/features/documents/presentation/document_detail_screen.dart:276)
  ///
  /// In en, this message translates to:
  /// **'Document moved.'**
  String get documentsDocumentMoved;

  /// Snackbar message (lib/features/documents/presentation/documents_screen.dart:251)
  ///
  /// In en, this message translates to:
  /// **'Document moved.'**
  String get documentsDocumentMoved2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:72)
  ///
  /// In en, this message translates to:
  /// **'Document reactivated for AI recaps.'**
  String get documentsDocumentReactivatedForAiRecaps;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:215)
  ///
  /// In en, this message translates to:
  /// **'Document title'**
  String get documentsDocumentTitle;

  /// Input label text (lib/features/documents/presentation/document_upload_screen.dart:213)
  ///
  /// In en, this message translates to:
  /// **'Document title'**
  String get documentsDocumentTitle2;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:222)
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentsDocumentType;

  /// Input label text (lib/features/documents/presentation/document_upload_screen.dart:220)
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentsDocumentType2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'documentId'**
  String get documentsDocumentid;

  /// Input hint text (lib/features/documents/presentation/documents_screen.dart:116)
  ///
  /// In en, this message translates to:
  /// **'E.g. Blood tests'**
  String get documentsEGBloodTests;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:563)
  ///
  /// In en, this message translates to:
  /// **'Empty archive'**
  String get documentsEmptyArchive;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:164)
  ///
  /// In en, this message translates to:
  /// **'Enter the body of the imaging report.'**
  String get documentsEnterTheBodyOfTheImaging;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:331)
  ///
  /// In en, this message translates to:
  /// **'Enter the panel name'**
  String get documentsEnterThePanelName;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:392)
  ///
  /// In en, this message translates to:
  /// **'Enter the report content'**
  String get documentsEnterTheReportContent;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:39)
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get documentsError;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:372)
  ///
  /// In en, this message translates to:
  /// **'Everything important in one place.'**
  String get documentsEverythingImportantInOnePlace;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:550)
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get documentsExam;

  /// Input label text (lib/features/documents/presentation/document_upload_screen.dart:262)
  ///
  /// In en, this message translates to:
  /// **'Exam date'**
  String get documentsExamDate;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:262)
  ///
  /// In en, this message translates to:
  /// **'Exam date (YYYY-MM-DD)'**
  String get documentsExamDateYyyyMmDd;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:366)
  ///
  /// In en, this message translates to:
  /// **'Exam type'**
  String get documentsExamType;

  /// Input hint text (lib/features/documents/presentation/document_query_screen.dart:557)
  ///
  /// In en, this message translates to:
  /// **'Example: what should I bring to the doctor?'**
  String get documentsExampleWhatShouldIBringTo;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:179)
  ///
  /// In en, this message translates to:
  /// **'Explain this document in simple terms.'**
  String get documentsExplainThisDocumentInSimpleTerms;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:720)
  ///
  /// In en, this message translates to:
  /// **'Extracted text'**
  String get documentsExtractedText;

  /// Title text (lib/features/documents/presentation/document_upload_screen.dart:151)
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get documentsFile;

  /// No description provided for @documentsFileSingular.
  ///
  /// In en, this message translates to:
  /// **'1 file'**
  String get documentsFileSingular;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:612)
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get documentsFiles;

  /// No description provided for @documentsFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String documentsFilesCount(Object count);

  /// Title text (lib/features/documents/presentation/document_query_screen.dart:290)
  ///
  /// In en, this message translates to:
  /// **'Files used'**
  String get documentsFilesUsed;

  /// Input label text (lib/features/documents/presentation/documents_screen.dart:115)
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get documentsFolderName;

  /// User-facing UI text (lib/features/documents/data/local_document_vault_service.dart:343)
  ///
  /// In en, this message translates to:
  /// **'Folder name cannot be empty.'**
  String get documentsFolderNameCannotBeEmpty;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:268)
  ///
  /// In en, this message translates to:
  /// **'folderId'**
  String get documentsFolderid;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:282)
  ///
  /// In en, this message translates to:
  /// **'folderId'**
  String get documentsFolderid2;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:270)
  ///
  /// In en, this message translates to:
  /// **'folderName'**
  String get documentsFoldername;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:284)
  ///
  /// In en, this message translates to:
  /// **'folderName'**
  String get documentsFoldername2;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:523)
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get documentsFolders;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:612)
  ///
  /// In en, this message translates to:
  /// **'Found files'**
  String get documentsFoundFiles;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:559)
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get documentsFrom;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:227)
  ///
  /// In en, this message translates to:
  /// **'General document'**
  String get documentsGeneralDocument;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:18)
  ///
  /// In en, this message translates to:
  /// **'General document'**
  String get documentsGeneralDocument2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:225)
  ///
  /// In en, this message translates to:
  /// **'General document'**
  String get documentsGeneralDocument3;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:491)
  ///
  /// In en, this message translates to:
  /// **'Hide technical details'**
  String get documentsHideTechnicalDetails;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:733)
  ///
  /// In en, this message translates to:
  /// **'Hide text'**
  String get documentsHideText;

  /// Snackbar message (lib/features/documents/presentation/document_query_history_screen.dart:282)
  ///
  /// In en, this message translates to:
  /// **'History cleared.'**
  String get documentsHistoryCleared;

  /// Snackbar message (lib/features/documents/presentation/document_query_history_screen.dart:257)
  ///
  /// In en, this message translates to:
  /// **'History entry deleted.'**
  String get documentsHistoryEntryDeleted;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:119)
  ///
  /// In en, this message translates to:
  /// **'I could not read the files this time. Try again or refresh the index.'**
  String get documentsICouldNotReadTheFiles;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:617)
  ///
  /// In en, this message translates to:
  /// **'I will answer only from files I can cite back to you.'**
  String get documentsIWillAnswerOnlyFromFiles;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:770)
  ///
  /// In en, this message translates to:
  /// **'Imaging report'**
  String get documentsImagingReport;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:235)
  ///
  /// In en, this message translates to:
  /// **'Imaging report'**
  String get documentsImagingReport2;

  /// Title text (lib/features/documents/presentation/document_review_screen.dart:361)
  ///
  /// In en, this message translates to:
  /// **'Imaging report'**
  String get documentsImagingReport3;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:8)
  ///
  /// In en, this message translates to:
  /// **'Imaging report'**
  String get documentsImagingReport4;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:233)
  ///
  /// In en, this message translates to:
  /// **'Imaging report'**
  String get documentsImagingReport5;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:376)
  ///
  /// In en, this message translates to:
  /// **'Impression'**
  String get documentsImpression;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:206)
  ///
  /// In en, this message translates to:
  /// **'Indexing started for 1 document.'**
  String get documentsIndexingStartedFor1Document;

  /// No description provided for @documentsIndexingStartedManyDocuments.
  ///
  /// In en, this message translates to:
  /// **'Indexing started for {count} documents.'**
  String documentsIndexingStartedManyDocuments(Object count);

  /// No description provided for @documentsIndexingStartedOneDocument.
  ///
  /// In en, this message translates to:
  /// **'Indexing started for 1 document.'**
  String get documentsIndexingStartedOneDocument;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:269)
  ///
  /// In en, this message translates to:
  /// **'Invalid date'**
  String get documentsInvalidDate;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:271)
  ///
  /// In en, this message translates to:
  /// **'Invalid date'**
  String get documentsInvalidDate2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:154)
  ///
  /// In en, this message translates to:
  /// **'It will go in this folder.'**
  String get documentsItWillGoInThisFolder;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:231)
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get documentsLabReport;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:6)
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get documentsLabReport2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:229)
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get documentsLabReport3;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:754)
  ///
  /// In en, this message translates to:
  /// **'Lab results'**
  String get documentsLabResults;

  /// Title text (lib/features/documents/presentation/document_review_screen.dart:314)
  ///
  /// In en, this message translates to:
  /// **'Lab results'**
  String get documentsLabResults2;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:219)
  ///
  /// In en, this message translates to:
  /// **'Main archive'**
  String get documentsMainArchive;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'Main archive'**
  String get documentsMainArchive2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:644)
  ///
  /// In en, this message translates to:
  /// **'Manual review'**
  String get documentsManualReview;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:683)
  ///
  /// In en, this message translates to:
  /// **'Manual review'**
  String get documentsManualReview2;

  /// Title text (lib/features/documents/presentation/document_review_screen.dart:193)
  ///
  /// In en, this message translates to:
  /// **'Manual review'**
  String get documentsManualReview3;

  /// Snackbar message (lib/features/documents/presentation/document_review_screen.dart:112)
  ///
  /// In en, this message translates to:
  /// **'Manual review saved.'**
  String get documentsManualReviewSaved;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:391)
  ///
  /// In en, this message translates to:
  /// **'Mark as old'**
  String get documentsMarkAsOld;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:479)
  ///
  /// In en, this message translates to:
  /// **'Max range'**
  String get documentsMaxRange;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:251)
  ///
  /// In en, this message translates to:
  /// **'Medical certificate'**
  String get documentsMedicalCertificate;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:16)
  ///
  /// In en, this message translates to:
  /// **'Medical certificate'**
  String get documentsMedicalCertificate2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:249)
  ///
  /// In en, this message translates to:
  /// **'Medical certificate'**
  String get documentsMedicalCertificate3;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:469)
  ///
  /// In en, this message translates to:
  /// **'Min range'**
  String get documentsMinRange;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:246)
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get documentsMove;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:223)
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get documentsMove2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:207)
  ///
  /// In en, this message translates to:
  /// **'Move file'**
  String get documentsMoveFile;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:371)
  ///
  /// In en, this message translates to:
  /// **'Move file'**
  String get documentsMoveFile2;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:184)
  ///
  /// In en, this message translates to:
  /// **'Move file'**
  String get documentsMoveFile3;

  /// Tooltip (lib/features/documents/presentation/documents_screen.dart:955)
  ///
  /// In en, this message translates to:
  /// **'Move file'**
  String get documentsMoveFile4;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:35)
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get documentsNeedsReview;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:450)
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get documentsNeedsReview2;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:111)
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get documentsNewFolder;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:430)
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get documentsNewFolder2;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:602)
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get documentsNewFolder3;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:601)
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get documentsNextStep;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:65)
  ///
  /// In en, this message translates to:
  /// **'No ask files history yet'**
  String get documentsNoAskFilesHistoryYet;

  /// No description provided for @documentsNoCitationsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No citations available. Try refreshing the index or rephrasing the question.'**
  String get documentsNoCitationsAvailable;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:296)
  ///
  /// In en, this message translates to:
  /// **'No citations available. Try refreshing the index or rephrasing the question.'**
  String get documentsNoCitationsAvailableTryRefreshingThe;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:491)
  ///
  /// In en, this message translates to:
  /// **'No diagnosis'**
  String get documentsNoDiagnosis;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:639)
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get documentsNoMatchingFiles;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:563)
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get documentsNoResults;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:493)
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get documentsNormal;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:552)
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get documentsNotAdded;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:33)
  ///
  /// In en, this message translates to:
  /// **'OCR pending'**
  String get documentsOcrPending;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:722)
  ///
  /// In en, this message translates to:
  /// **'OCR text for the document.'**
  String get documentsOcrTextForTheDocument;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:937)
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get documentsOk;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:48)
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get documentsOld;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:860)
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get documentsOld2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:442)
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get documentsOpenFile;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:433)
  ///
  /// In en, this message translates to:
  /// **'Open it, move it, or ask for a quick explanation.'**
  String get documentsOpenItMoveItOrAsk;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:294)
  ///
  /// In en, this message translates to:
  /// **'Open Manual review to add or confirm key values.'**
  String get documentsOpenManualReviewToAddOr;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:302)
  ///
  /// In en, this message translates to:
  /// **'Open the file and confirm details if needed.'**
  String get documentsOpenTheFileAndConfirmDetails;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:937)
  ///
  /// In en, this message translates to:
  /// **'Out of range'**
  String get documentsOutOfRange;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:496)
  ///
  /// In en, this message translates to:
  /// **'Out of range'**
  String get documentsOutOfRange2;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:490)
  ///
  /// In en, this message translates to:
  /// **'Out-of-range flag'**
  String get documentsOutOfRangeFlag;

  /// Title text (lib/features/documents/presentation/document_detail_screen.dart:220)
  ///
  /// In en, this message translates to:
  /// **'Outside any folder'**
  String get documentsOutsideAnyFolder;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:197)
  ///
  /// In en, this message translates to:
  /// **'Outside any folder'**
  String get documentsOutsideAnyFolder2;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:325)
  ///
  /// In en, this message translates to:
  /// **'Panel name'**
  String get documentsPanelName;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:31)
  ///
  /// In en, this message translates to:
  /// **'Parsed'**
  String get documentsParsed;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:459)
  ///
  /// In en, this message translates to:
  /// **'Parsing'**
  String get documentsParsing;

  /// No description provided for @documentsPastAnswers.
  ///
  /// In en, this message translates to:
  /// **'Past answers'**
  String get documentsPastAnswers;

  /// No description provided for @documentsPastAnswersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse a recent answer instead of running the same search again.'**
  String get documentsPastAnswersSubtitle;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:186)
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG or PNG.'**
  String get documentsPdfJpgOrPng;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:27)
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get documentsPending;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:247)
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get documentsPrescription;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:14)
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get documentsPrescription2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:245)
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get documentsPrescription3;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:632)
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get documentsProcess;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:632)
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get documentsProcessing;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:29)
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get documentsProcessing2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:291)
  ///
  /// In en, this message translates to:
  /// **'Processing is running. Refresh in a few seconds.'**
  String get documentsProcessingIsRunningRefreshInA;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:969)
  ///
  /// In en, this message translates to:
  /// **'Range unavailable'**
  String get documentsRangeUnavailable;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:391)
  ///
  /// In en, this message translates to:
  /// **'Reactivate for AI'**
  String get documentsReactivateForAi;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:25)
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get documentsReady;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:468)
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get documentsReady2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:665)
  ///
  /// In en, this message translates to:
  /// **'Ready to use.'**
  String get documentsReadyToUse;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:265)
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get documentsRefresh;

  /// Tooltip (lib/features/documents/presentation/document_review_screen.dart:437)
  ///
  /// In en, this message translates to:
  /// **'Remove result'**
  String get documentsRemoveResult;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:384)
  ///
  /// In en, this message translates to:
  /// **'Report text'**
  String get documentsReportText;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:649)
  ///
  /// In en, this message translates to:
  /// **'Reset filter'**
  String get documentsResetFilter;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:37)
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get documentsReviewed;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:410)
  ///
  /// In en, this message translates to:
  /// **'Save here'**
  String get documentsSaveHere;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:299)
  ///
  /// In en, this message translates to:
  /// **'Save manual review'**
  String get documentsSaveManualReview;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:287)
  ///
  /// In en, this message translates to:
  /// **'Save on device'**
  String get documentsSaveOnDevice;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:88)
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get documentsSaved;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:299)
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get documentsSaving;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:287)
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get documentsSaving2;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:507)
  ///
  /// In en, this message translates to:
  /// **'Search active'**
  String get documentsSearchActive;

  /// Input label text (lib/features/documents/presentation/documents_screen.dart:381)
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get documentsSearchFiles;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:613)
  ///
  /// In en, this message translates to:
  /// **'Search results.'**
  String get documentsSearchResults;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:371)
  ///
  /// In en, this message translates to:
  /// **'Search your files.'**
  String get documentsSearchYourFiles;

  /// No description provided for @documentsSearchingAllSavedFiles.
  ///
  /// In en, this message translates to:
  /// **'Searching all your saved files.'**
  String get documentsSearchingAllSavedFiles;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:467)
  ///
  /// In en, this message translates to:
  /// **'Searching all your saved files.'**
  String get documentsSearchingAllYourSavedFiles;

  /// No description provided for @documentsSearchingInFolder.
  ///
  /// In en, this message translates to:
  /// **'Searching in {folderName}.'**
  String documentsSearchingInFolder(Object folderName);

  /// Snackbar message (lib/features/documents/presentation/document_upload_screen.dart:98)
  ///
  /// In en, this message translates to:
  /// **'Select a file first.'**
  String get documentsSelectAFileFirst;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:82)
  ///
  /// In en, this message translates to:
  /// **'Select exam date'**
  String get documentsSelectExamDate;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:173)
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get documentsSelectFile;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:195)
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get documentsSelected;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:492)
  ///
  /// In en, this message translates to:
  /// **'Show technical details'**
  String get documentsShowTechnicalDetails;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:733)
  ///
  /// In en, this message translates to:
  /// **'Show text'**
  String get documentsShowText;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:487)
  ///
  /// In en, this message translates to:
  /// **'Shows sources'**
  String get documentsShowsSources;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:561)
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get documentsSize;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:276)
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get documentsSource;

  /// Input label text (lib/features/documents/presentation/document_upload_screen.dart:278)
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get documentsSource2;

  /// No description provided for @documentsSourceSummary.
  ///
  /// In en, this message translates to:
  /// **'{files} • {passages}'**
  String documentsSourceSummary(Object files, Object passages);

  /// No description provided for @documentsSourcesCount.
  ///
  /// In en, this message translates to:
  /// **'Sources ({count})'**
  String documentsSourcesCount(Object count);

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:243)
  ///
  /// In en, this message translates to:
  /// **'Specialist visit'**
  String get documentsSpecialistVisit;

  /// User-facing UI text (lib/features/documents/presentation/document_ui.dart:12)
  ///
  /// In en, this message translates to:
  /// **'Specialist visit'**
  String get documentsSpecialistVisit2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:241)
  ///
  /// In en, this message translates to:
  /// **'Specialist visit'**
  String get documentsSpecialistVisit3;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:570)
  ///
  /// In en, this message translates to:
  /// **'Start by saving a file or creating a folder.'**
  String get documentsStartBySavingAFileOr;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:33)
  ///
  /// In en, this message translates to:
  /// **'Summarize the recent reports to bring to the doctor.'**
  String get documentsSummarizeTheRecentReportsToBring;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:523)
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get documentsSyncPending;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:869)
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get documentsSyncPending2;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:555)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get documentsT;

  /// User-facing UI text (lib/features/documents/presentation/document_review_screen.dart:61)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get documentsT2;

  /// User-facing UI text (lib/features/documents/presentation/document_upload_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get documentsTakePhoto;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:421)
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get documentsTakePhoto2;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:524)
  ///
  /// In en, this message translates to:
  /// **'Tap a folder to open it.'**
  String get documentsTapAFolderToOpenIt;

  /// No description provided for @documentsTapToReuseAnswer.
  ///
  /// In en, this message translates to:
  /// **'Tap a card to reopen that answer.'**
  String get documentsTapToReuseAnswer;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:94)
  ///
  /// In en, this message translates to:
  /// **'The document will be deleted permanently. Do you want to continue?'**
  String get documentsTheDocumentWillBeDeletedPermanently;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:748)
  ///
  /// In en, this message translates to:
  /// **'The extracted text is ready but stays hidden until you choose to view it.'**
  String get documentsTheExtractedTextIsReadyBut;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:534)
  ///
  /// In en, this message translates to:
  /// **'This document has changes waiting to sync.'**
  String get documentsThisDocumentHasChangesWaitingTo;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:570)
  ///
  /// In en, this message translates to:
  /// **'This document is marked as old and is not included in AI recaps.'**
  String get documentsThisDocumentIsMarkedAsOld;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:267)
  ///
  /// In en, this message translates to:
  /// **'This will remove all your document questions and answers from history. This cannot be undone.'**
  String get documentsThisWillRemoveAllYourDocument;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:232)
  ///
  /// In en, this message translates to:
  /// **'This will remove the question and answer from your history.'**
  String get documentsThisWillRemoveTheQuestionAnd;

  /// Input hint text (lib/features/documents/presentation/documents_screen.dart:382)
  ///
  /// In en, this message translates to:
  /// **'Title, folder, source, file name...'**
  String get documentsTitleFolderSourceFileName;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:804)
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get documentsTryAgain;

  /// Title text (lib/features/documents/presentation/documents_screen.dart:640)
  ///
  /// In en, this message translates to:
  /// **'Try another filter or clear the search.'**
  String get documentsTryAnotherFilterOrClearThe;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:569)
  ///
  /// In en, this message translates to:
  /// **'Try different words or clear the search.'**
  String get documentsTryDifferentWordsOrClearThe;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:794)
  ///
  /// In en, this message translates to:
  /// **'Unable to load this document.'**
  String get documentsUnableToLoadThisDocument;

  /// Snackbar message (lib/features/documents/presentation/document_detail_screen.dart:169)
  ///
  /// In en, this message translates to:
  /// **'Unable to open the document.'**
  String get documentsUnableToOpenTheDocument;

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:458)
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get documentsUnit;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:265)
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get documentsUpdating;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:409)
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get documentsUploadFile;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:591)
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get documentsUploadFile2;

  /// No description provided for @documentsUsefulPartSingular.
  ///
  /// In en, this message translates to:
  /// **'1 useful part'**
  String get documentsUsefulPartSingular;

  /// No description provided for @documentsUsefulPartsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} useful parts'**
  String documentsUsefulPartsCount(Object count);

  /// Input label text (lib/features/documents/presentation/document_review_screen.dart:451)
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get documentsValue;

  /// Tooltip (lib/features/documents/presentation/document_query_screen.dart:253)
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get documentsViewHistory;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:703)
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get documentsViewOnly;

  /// User-facing UI text (lib/features/documents/presentation/documents_screen.dart:903)
  ///
  /// In en, this message translates to:
  /// **'Waiting for sync'**
  String get documentsWaitingForSync;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:31)
  ///
  /// In en, this message translates to:
  /// **'Which recent tests mention creatinine or kidney function?'**
  String get documentsWhichRecentTestsMentionCreatinineOr;

  /// User-facing UI text (lib/features/documents/presentation/document_query_screen.dart:68)
  ///
  /// In en, this message translates to:
  /// **'Write a slightly more specific question.'**
  String get documentsWriteASlightlyMoreSpecificQuestion;

  /// No description provided for @documentsWriteSpecificQuestion.
  ///
  /// In en, this message translates to:
  /// **'Write a slightly more specific question.'**
  String get documentsWriteSpecificQuestion;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:670)
  ///
  /// In en, this message translates to:
  /// **'You can open it, review it, or ask for a simple explanation.'**
  String get documentsYouCanOpenItReviewIt;

  /// User-facing UI text (lib/features/documents/presentation/document_detail_screen.dart:708)
  ///
  /// In en, this message translates to:
  /// **'You can read this file, but editing is disabled right now.'**
  String get documentsYouCanReadThisFileBut;

  /// User-facing UI text (lib/features/documents/presentation/document_query_history_screen.dart:70)
  ///
  /// In en, this message translates to:
  /// **'Your document questions will appear here.'**
  String get documentsYourDocumentQuestionsWillAppearHere;

  /// Input hint text (lib/features/documents/presentation/document_upload_screen.dart:263)
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get documentsYyyyMmDd;

  /// No description provided for @dossier.
  ///
  /// In en, this message translates to:
  /// **'Dossier'**
  String get dossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:819)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dossierActive;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:612)
  ///
  /// In en, this message translates to:
  /// **'Active issues'**
  String get dossierActiveIssues;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:651)
  ///
  /// In en, this message translates to:
  /// **'Active medications'**
  String get dossierActiveMedications;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:666)
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get dossierAllergies;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:421)
  ///
  /// In en, this message translates to:
  /// **'Backup JSON'**
  String get dossierBackupJson;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:152)
  ///
  /// In en, this message translates to:
  /// **'Bring an NFC tag or compatible card close to the device.'**
  String get dossierBringAnNfcTagOrCompatible;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dossierCancel;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:350)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dossierCancel2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1379)
  ///
  /// In en, this message translates to:
  /// **'CD'**
  String get dossierCd;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:96)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary emergency card'**
  String get dossierClindiaryEmergencyCard;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:97)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary emergency card'**
  String get dossierClindiaryEmergencyCard2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:290)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary emergency card'**
  String get dossierClindiaryEmergencyCard3;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:323)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary emergency card'**
  String get dossierClindiaryEmergencyCard4;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:322)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary full dossier'**
  String get dossierClindiaryFullDossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:46)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary health dossier'**
  String get dossierClindiaryHealthDossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:47)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary health dossier'**
  String get dossierClindiaryHealthDossier2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:71)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary structured backup'**
  String get dossierClindiaryStructuredBackup;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:72)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary structured backup'**
  String get dossierClindiaryStructuredBackup2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:442)
  ///
  /// In en, this message translates to:
  /// **'Clinical'**
  String get dossierClinical;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:828)
  ///
  /// In en, this message translates to:
  /// **'Clinical devices'**
  String get dossierClinicalDevices;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:758)
  ///
  /// In en, this message translates to:
  /// **'Clinical issues'**
  String get dossierClinicalIssues;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:830)
  ///
  /// In en, this message translates to:
  /// **'Compact summary of recent measurements from connected providers.'**
  String get dossierCompactSummaryOfRecentMeasurementsFrom;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:736)
  ///
  /// In en, this message translates to:
  /// **'Conditions, allergies, and family history'**
  String get dossierConditionsAllergiesAndFamilyHistory;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:563)
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get dossierCopy;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:428)
  ///
  /// In en, this message translates to:
  /// **'Copy emergency card'**
  String get dossierCopyEmergencyCard;

  /// Tooltip (lib/features/dossier/presentation/health_dossier_screen.dart:1252)
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get dossierCopyLink;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:795)
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get dossierCurrentMedications;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1554)
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get dossierDailyReport;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:713)
  ///
  /// In en, this message translates to:
  /// **'Data provenance'**
  String get dossierDataProvenance;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:32)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get dossierDdMmmYyyy;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:33)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get dossierDdMmmYyyyHhMm;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:525)
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get dossierDevice;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:444)
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get dossierDiary;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:890)
  ///
  /// In en, this message translates to:
  /// **'Documents and reports'**
  String get dossierDocumentsAndReports;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1213)
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get dossierEmergency;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:314)
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get dossierEmergencyCard;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:552)
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get dossierEmergencyCard2;

  /// Snackbar message (lib/features/dossier/presentation/health_dossier_screen.dart:280)
  ///
  /// In en, this message translates to:
  /// **'Emergency card copied.'**
  String get dossierEmergencyCardCopied;

  /// Snackbar message (lib/features/dossier/presentation/health_dossier_screen.dart:169)
  ///
  /// In en, this message translates to:
  /// **'Emergency card written to NFC.'**
  String get dossierEmergencyCardWrittenToNfc;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:145)
  ///
  /// In en, this message translates to:
  /// **'Emergency link not available.'**
  String get dossierEmergencyLinkNotAvailable;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1186)
  ///
  /// In en, this message translates to:
  /// **'Emergency PDF'**
  String get dossierEmergencyPdf;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1236)
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get dossierExpired;

  /// Tooltip (lib/features/dossier/presentation/health_dossier_screen.dart:395)
  ///
  /// In en, this message translates to:
  /// **'Export and share'**
  String get dossierExportAndShare;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1541)
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get dossierFemale;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1176)
  ///
  /// In en, this message translates to:
  /// **'For emergency sharing, use the emergency PDF or NFC write flow. For full portability, use JSON export/import.'**
  String get dossierForEmergencySharingUseTheEmergency;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:314)
  ///
  /// In en, this message translates to:
  /// **'Full dossier'**
  String get dossierFullDossier;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:390)
  ///
  /// In en, this message translates to:
  /// **'Health dossier'**
  String get dossierHealthDossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1503)
  ///
  /// In en, this message translates to:
  /// **'High attention'**
  String get dossierHighAttention;

  /// Snackbar message (lib/features/dossier/presentation/health_dossier_screen.dart:236)
  ///
  /// In en, this message translates to:
  /// **'Import canceled.'**
  String get dossierImportCanceled;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1196)
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get dossierImportJson;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:424)
  ///
  /// In en, this message translates to:
  /// **'Import JSON backup'**
  String get dossierImportJsonBackup;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:1060)
  ///
  /// In en, this message translates to:
  /// **'Insights, reports, and alerts'**
  String get dossierInsightsReportsAndAlerts;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1545)
  ///
  /// In en, this message translates to:
  /// **'Intersex'**
  String get dossierIntersex;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:507)
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get dossierIssues;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1191)
  ///
  /// In en, this message translates to:
  /// **'JSON backup'**
  String get dossierJsonBackup;

  /// Snackbar message (lib/features/dossier/presentation/health_dossier_screen.dart:261)
  ///
  /// In en, this message translates to:
  /// **'JSON backup imported.'**
  String get dossierJsonBackupImported;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:681)
  ///
  /// In en, this message translates to:
  /// **'Known conditions'**
  String get dossierKnownConditions;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1270)
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get dossierLinkCopied;

  /// Snackbar message (lib/features/dossier/presentation/health_dossier_screen.dart:369)
  ///
  /// In en, this message translates to:
  /// **'Link revoked.'**
  String get dossierLinkRevoked;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1543)
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get dossierMale;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1558)
  ///
  /// In en, this message translates to:
  /// **'Monthly report'**
  String get dossierMonthlyReport;

  /// Tooltip (lib/features/dossier/presentation/health_dossier_screen.dart:399)
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get dossierMoreActions;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:577)
  ///
  /// In en, this message translates to:
  /// **'NFC'**
  String get dossierNfc;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:138)
  ///
  /// In en, this message translates to:
  /// **'NFC emergency card'**
  String get dossierNfcEmergencyCard;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:126)
  ///
  /// In en, this message translates to:
  /// **'NFC is not available on this device. Using the emergency card PDF.'**
  String get dossierNfcIsNotAvailableOnThis;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1224)
  ///
  /// In en, this message translates to:
  /// **'No active secure links.'**
  String get dossierNoActiveSecureLinks;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:837)
  ///
  /// In en, this message translates to:
  /// **'No clinical device measurements in the dossier.'**
  String get dossierNoClinicalDeviceMeasurementsInThe;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:764)
  ///
  /// In en, this message translates to:
  /// **'No clinical issues recorded.'**
  String get dossierNoClinicalIssuesRecorded;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:899)
  ///
  /// In en, this message translates to:
  /// **'No documents in the dossier.'**
  String get dossierNoDocumentsInTheDossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:750)
  ///
  /// In en, this message translates to:
  /// **'No items recorded.'**
  String get dossierNoItemsRecorded;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:801)
  ///
  /// In en, this message translates to:
  /// **'No medications recorded.'**
  String get dossierNoMedicationsRecorded;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1103)
  ///
  /// In en, this message translates to:
  /// **'No open alerts.'**
  String get dossierNoOpenAlerts;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:533)
  ///
  /// In en, this message translates to:
  /// **'No profile details available.'**
  String get dossierNoProfileDetailsAvailable;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:716)
  ///
  /// In en, this message translates to:
  /// **'No provenance available.'**
  String get dossierNoProvenanceAvailable;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:996)
  ///
  /// In en, this message translates to:
  /// **'No recent check-up.'**
  String get dossierNoRecentCheckUp;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:859)
  ///
  /// In en, this message translates to:
  /// **'No vaccines in the dossier.'**
  String get dossierNoVaccinesInTheDossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1137)
  ///
  /// In en, this message translates to:
  /// **'No wearable data in the dossier.'**
  String get dossierNoWearableDataInTheDossier;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1547)
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get dossierNotSpecified;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:761)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dossierOpen;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:798)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dossierOpen2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:833)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dossierOpen3;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:893)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dossierOpen4;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1134)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dossierOpen5;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:696)
  ///
  /// In en, this message translates to:
  /// **'Open alerts'**
  String get dossierOpenAlerts;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1106)
  ///
  /// In en, this message translates to:
  /// **'Open alerts'**
  String get dossierOpenAlerts2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:753)
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get dossierOpenProfile;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:486)
  ///
  /// In en, this message translates to:
  /// **'Organized personal record'**
  String get dossierOrganizedPersonalRecord;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:582)
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get dossierPdf;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1560)
  ///
  /// In en, this message translates to:
  /// **'Pre-visit report'**
  String get dossierPreVisitReport;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:456)
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get dossierProfile;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:457)
  ///
  /// In en, this message translates to:
  /// **'Quick summary of the active dossier.'**
  String get dossierQuickSummaryOfTheActiveDossier;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:553)
  ///
  /// In en, this message translates to:
  /// **'Quick version to copy or share.'**
  String get dossierQuickVersionToCopyOrShare;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:920)
  ///
  /// In en, this message translates to:
  /// **'Recent blood tests'**
  String get dossierRecentBloodTests;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:990)
  ///
  /// In en, this message translates to:
  /// **'Recent diary'**
  String get dossierRecentDiary;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:957)
  ///
  /// In en, this message translates to:
  /// **'Recent imaging'**
  String get dossierRecentImaging;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1066)
  ///
  /// In en, this message translates to:
  /// **'Recent insights'**
  String get dossierRecentInsights;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:628)
  ///
  /// In en, this message translates to:
  /// **'Recent report'**
  String get dossierRecentReport;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1086)
  ///
  /// In en, this message translates to:
  /// **'Recent reports'**
  String get dossierRecentReports;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1218)
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get dossierRecord;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:1206)
  ///
  /// In en, this message translates to:
  /// **'Revocable temporary links, max 30 days.'**
  String get dossierRevocableTemporaryLinksMax30Days;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:355)
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get dossierRevoke;

  /// Tooltip (lib/features/dossier/presentation/health_dossier_screen.dart:1280)
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get dossierRevoke2;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:344)
  ///
  /// In en, this message translates to:
  /// **'Revoke the link?'**
  String get dossierRevokeTheLink;

  /// Snackbar message (lib/features/dossier/presentation/health_dossier_screen.dart:331)
  ///
  /// In en, this message translates to:
  /// **'Secure link created.'**
  String get dossierSecureLinkCreated;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:303)
  ///
  /// In en, this message translates to:
  /// **'Secure share links are disabled while local-only mode is active.'**
  String get dossierSecureShareLinksAreDisabledWhile;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:1169)
  ///
  /// In en, this message translates to:
  /// **'Secure shares'**
  String get dossierSecureShares;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:1205)
  ///
  /// In en, this message translates to:
  /// **'Secure shares'**
  String get dossierSecureShares2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:445)
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get dossierShare;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:571)
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get dossierShare2;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1171)
  ///
  /// In en, this message translates to:
  /// **'Share links are disabled in local-only mode. Use encrypted local exports and backup restore.'**
  String get dossierShareLinksAreDisabledInLocal;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:1131)
  ///
  /// In en, this message translates to:
  /// **'Smartwatch data'**
  String get dossierSmartwatchData;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:714)
  ///
  /// In en, this message translates to:
  /// **'Source and update time of aggregated data.'**
  String get dossierSourceAndUpdateTimeOfAggregated;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:819)
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get dossierStopped;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:441)
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get dossierSummary;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:345)
  ///
  /// In en, this message translates to:
  /// **'The link will no longer be usable.'**
  String get dossierTheLinkWillNoLongerBe;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1584)
  ///
  /// In en, this message translates to:
  /// **'This NFC tag does not support NDEF.'**
  String get dossierThisNfcTagDoesNotSupport;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1569)
  ///
  /// In en, this message translates to:
  /// **'This NFC tag is not writable.'**
  String get dossierThisNfcTagIsNotWritable;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1572)
  ///
  /// In en, this message translates to:
  /// **'This NFC tag is too small for the emergency card.'**
  String get dossierThisNfcTagIsTooSmall;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1504)
  ///
  /// In en, this message translates to:
  /// **'To monitor'**
  String get dossierToMonitor;

  /// Title text (lib/features/dossier/presentation/health_dossier_screen.dart:852)
  ///
  /// In en, this message translates to:
  /// **'Vaccination history'**
  String get dossierVaccinationHistory;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:774)
  ///
  /// In en, this message translates to:
  /// **'Waiting for sync'**
  String get dossierWaitingForSync;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:639)
  ///
  /// In en, this message translates to:
  /// **'Wearable'**
  String get dossierWearable;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:1556)
  ///
  /// In en, this message translates to:
  /// **'Weekly report'**
  String get dossierWeeklyReport;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:138)
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get gemmaDownloadNotificationServiceB;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:138)
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get gemmaDownloadNotificationServiceGb;

  /// Title text (lib/app/core/notifications/gemma_download_notification_service.dart:99)
  ///
  /// In en, this message translates to:
  /// **'Gemma 4 download failed'**
  String get gemmaDownloadNotificationServiceGemma4DownloadFailed;

  /// Title text (lib/app/core/notifications/gemma_download_notification_service.dart:66)
  ///
  /// In en, this message translates to:
  /// **'Gemma 4 download in progress'**
  String get gemmaDownloadNotificationServiceGemma4DownloadInProgress;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:6)
  ///
  /// In en, this message translates to:
  /// **'Gemma model download'**
  String get gemmaDownloadNotificationServiceGemmaModelDownload;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:138)
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get gemmaDownloadNotificationServiceKb;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:138)
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get gemmaDownloadNotificationServiceMb;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:27)
  ///
  /// In en, this message translates to:
  /// **'@mipmap/ic_launcher'**
  String get gemmaDownloadNotificationServiceMipmapIcLauncher;

  /// User-facing UI text (lib/app/core/notifications/gemma_download_notification_service.dart:8)
  ///
  /// In en, this message translates to:
  /// **'Progress notification for Gemma model downloads.'**
  String get gemmaDownloadNotificationServiceProgressNotificationForGemmaModelDownloads;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:45)
  ///
  /// In en, this message translates to:
  /// **'Checking whether Gemma 4 E2B is already installed...'**
  String get gemmaModelBootstrapCheckingWhetherGemma4E2bIs;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:373)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary is setting up the on-device model for the demo.'**
  String get gemmaModelBootstrapClindiaryIsSettingUpTheOn;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:432)
  ///
  /// In en, this message translates to:
  /// **'Continue to app'**
  String get gemmaModelBootstrapContinueToApp;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:438)
  ///
  /// In en, this message translates to:
  /// **'Do not close the app while the model is being prepared.'**
  String get gemmaModelBootstrapDoNotCloseTheAppWhile;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:201)
  ///
  /// In en, this message translates to:
  /// **'Downloading EmbeddingGemma 300M...'**
  String get gemmaModelBootstrapDownloadingEmbeddinggemma300m;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:202)
  ///
  /// In en, this message translates to:
  /// **'Downloading EmbeddingGemma 300M...'**
  String get gemmaModelBootstrapDownloadingEmbeddinggemma300m2;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:194)
  ///
  /// In en, this message translates to:
  /// **'Downloading EmbeddingGemma 300M from Hugging Face...'**
  String get gemmaModelBootstrapDownloadingEmbeddinggemma300mFromHuggingFace;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:97)
  ///
  /// In en, this message translates to:
  /// **'Downloading Gemma 4 E2B...'**
  String get gemmaModelBootstrapDownloadingGemma4E2b;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:106)
  ///
  /// In en, this message translates to:
  /// **'Downloading Gemma 4 E2B...'**
  String get gemmaModelBootstrapDownloadingGemma4E2b2;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:182)
  ///
  /// In en, this message translates to:
  /// **'Downloading Gemma 4 E2B...'**
  String get gemmaModelBootstrapDownloadingGemma4E2b3;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:183)
  ///
  /// In en, this message translates to:
  /// **'Downloading Gemma 4 E2B...'**
  String get gemmaModelBootstrapDownloadingGemma4E2b4;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:174)
  ///
  /// In en, this message translates to:
  /// **'Downloading Gemma 4 E2B from Hugging Face...'**
  String get gemmaModelBootstrapDownloadingGemma4E2bFromHugging;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:396)
  ///
  /// In en, this message translates to:
  /// **'Model directory'**
  String get gemmaModelBootstrapModelDirectory;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:237)
  ///
  /// In en, this message translates to:
  /// **'Model download failed.'**
  String get gemmaModelBootstrapModelDownloadFailed;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:403)
  ///
  /// In en, this message translates to:
  /// **'Model file'**
  String get gemmaModelBootstrapModelFile;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:138)
  ///
  /// In en, this message translates to:
  /// **'Models are already present. Verifying the runtime...'**
  String get gemmaModelBootstrapModelsAreAlreadyPresentVerifyingThe;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:160)
  ///
  /// In en, this message translates to:
  /// **'Models are installed, but LiteRT-LM could not load them. You can retry the download or continue to the app.'**
  String get gemmaModelBootstrapModelsAreInstalledButLitertLm;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:117)
  ///
  /// In en, this message translates to:
  /// **'On-device AI is not available on this platform.'**
  String get gemmaModelBootstrapOnDeviceAiIsNotAvailable;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:129)
  ///
  /// In en, this message translates to:
  /// **'On-device AI models are ready.'**
  String get gemmaModelBootstrapOnDeviceAiModelsAreReady;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:151)
  ///
  /// In en, this message translates to:
  /// **'On-device AI models are ready.'**
  String get gemmaModelBootstrapOnDeviceAiModelsAreReady2;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:219)
  ///
  /// In en, this message translates to:
  /// **'On-device AI models are ready.'**
  String get gemmaModelBootstrapOnDeviceAiModelsAreReady3;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:364)
  ///
  /// In en, this message translates to:
  /// **'Preparing Gemma 4 E2B'**
  String get gemmaModelBootstrapPreparingGemma4E2b;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:427)
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get gemmaModelBootstrapRetryDownload;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:57)
  ///
  /// In en, this message translates to:
  /// **'Retrying Gemma 4 E2B model setup...'**
  String get gemmaModelBootstrapRetryingGemma4E2bModelSetup;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:165)
  ///
  /// In en, this message translates to:
  /// **'Runtime initialization failed.'**
  String get gemmaModelBootstrapRuntimeInitializationFailed;

  /// User-facing UI text (lib/app/bootstrap/gemma_model_bootstrap.dart:229)
  ///
  /// In en, this message translates to:
  /// **'The models have been downloaded, but LiteRT-LM still could not initialize. You can continue to the app and try again from the model screen.'**
  String get gemmaModelBootstrapTheModelsHaveBeenDownloadedBut;

  /// User-facing UI text (lib/shared/widgets/generation_phase_label.dart:12)
  ///
  /// In en, this message translates to:
  /// **'Refining...'**
  String get generationPhaseLabelRefining;

  /// User-facing UI text (lib/shared/widgets/generation_phase_label.dart:10)
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get generationPhaseLabelThinking;

  /// User-facing UI text (lib/shared/widgets/generation_phase_label.dart:11)
  ///
  /// In en, this message translates to:
  /// **'Writing...'**
  String get generationPhaseLabelWriting;

  /// No description provided for @goTo.
  ///
  /// In en, this message translates to:
  /// **'Go To'**
  String get goTo;

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

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String googleSignInFailed(Object error);

  /// Tooltip (lib/features/daily_journal/presentation/diary_screen.dart:177)
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:993)
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history2;

  /// Title text (lib/features/history/presentation/history_screen.dart:158)
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history3;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:255)
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history4;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1671)
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history5;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:179)
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get historyCalendar;

  /// Title text (lib/features/history/presentation/history_screen.dart:222)
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get historyCalendar2;

  /// Title text (lib/features/history/presentation/history_screen.dart:223)
  ///
  /// In en, this message translates to:
  /// **'Choose a day.'**
  String get historyChooseADay;

  /// Tooltip (lib/features/history/presentation/history_screen.dart:514)
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get historyCopyReport;

  /// Title text (lib/features/history/presentation/history_screen.dart:508)
  ///
  /// In en, this message translates to:
  /// **'Daily recap'**
  String get historyDailyRecap;

  /// Title text (lib/features/history/presentation/history_screen.dart:546)
  ///
  /// In en, this message translates to:
  /// **'Data recorded on the day.'**
  String get historyDataRecordedOnTheDay;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get historyDay;

  /// Title text (lib/features/history/presentation/history_screen.dart:210)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get historyDay2;

  /// Title text (lib/features/history/presentation/history_screen.dart:214)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get historyDay3;

  /// Title text (lib/features/history/presentation/history_screen.dart:471)
  ///
  /// In en, this message translates to:
  /// **'Day details'**
  String get historyDayDetails;

  /// Title text (lib/features/history/presentation/history_screen.dart:643)
  ///
  /// In en, this message translates to:
  /// **'Day documents'**
  String get historyDayDocuments;

  /// Title text (lib/features/history/presentation/history_screen.dart:667)
  ///
  /// In en, this message translates to:
  /// **'Day summary.'**
  String get historyDaySummary;

  /// Title text (lib/features/history/presentation/history_screen.dart:633)
  ///
  /// In en, this message translates to:
  /// **'Day timeline.'**
  String get historyDayTimeline;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:147)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get historyDdMmmYyyy;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:368)
  ///
  /// In en, this message translates to:
  /// **'Dot = recorded activity'**
  String get historyDotRecordedActivity;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:487)
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get historyEvents;

  /// Title text (lib/features/history/presentation/history_screen.dart:632)
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get historyEvents2;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:718)
  ///
  /// In en, this message translates to:
  /// **'HH:mm'**
  String get historyHhMm;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:413)
  ///
  /// In en, this message translates to:
  /// **'No check-up'**
  String get historyNoCheckUp;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:548)
  ///
  /// In en, this message translates to:
  /// **'No check-up recorded for this day.'**
  String get historyNoCheckUpRecordedForThis;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:646)
  ///
  /// In en, this message translates to:
  /// **'No documents linked to this day.'**
  String get historyNoDocumentsLinkedToThisDay;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:635)
  ///
  /// In en, this message translates to:
  /// **'No events recorded for this day.'**
  String get historyNoEventsRecordedForThisDay;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:538)
  ///
  /// In en, this message translates to:
  /// **'No recap available.'**
  String get historyNoRecapAvailable;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:669)
  ///
  /// In en, this message translates to:
  /// **'No wearable data for this day.'**
  String get historyNoWearableDataForThisDay;

  /// Title text (lib/features/history/presentation/history_screen.dart:472)
  ///
  /// In en, this message translates to:
  /// **'Open only the section you need.'**
  String get historyOpenOnlyTheSectionYouNeed;

  /// Title text (lib/features/history/presentation/history_screen.dart:407)
  ///
  /// In en, this message translates to:
  /// **'Quick overview.'**
  String get historyQuickOverview;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:477)
  ///
  /// In en, this message translates to:
  /// **'Recap'**
  String get historyRecap;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:417)
  ///
  /// In en, this message translates to:
  /// **'Recap available'**
  String get historyRecapAvailable;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:532)
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get historyRegenerate;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:531)
  ///
  /// In en, this message translates to:
  /// **'Regenerating...'**
  String get historyRegenerating;

  /// Snackbar message (lib/features/history/presentation/history_screen.dart:119)
  ///
  /// In en, this message translates to:
  /// **'Report copied to clipboard.'**
  String get historyReportCopiedToClipboard;

  /// Title text (lib/features/history/presentation/history_screen.dart:406)
  ///
  /// In en, this message translates to:
  /// **'Selected day'**
  String get historySelectedDay;

  /// Title text (lib/features/history/presentation/history_screen.dart:584)
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get historySymptoms;

  /// Title text (lib/features/history/presentation/history_screen.dart:644)
  ///
  /// In en, this message translates to:
  /// **'Uploaded or linked to this date.'**
  String get historyUploadedOrLinkedToThisDate;

  /// Title text (lib/features/history/presentation/history_screen.dart:603)
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get historyVitals;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:419)
  ///
  /// In en, this message translates to:
  /// **'Wearable'**
  String get historyWearable;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:497)
  ///
  /// In en, this message translates to:
  /// **'Wearable'**
  String get historyWearable2;

  /// Title text (lib/features/history/presentation/history_screen.dart:666)
  ///
  /// In en, this message translates to:
  /// **'Wearable data'**
  String get historyWearableData;

  /// Title text (lib/features/home/presentation/home_screen.dart:584)
  ///
  /// In en, this message translates to:
  /// **'Add check-up'**
  String get homeAddCheckUp;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:409)
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get homeAddProfile;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:965)
  ///
  /// In en, this message translates to:
  /// **'annual visit'**
  String get homeAnnualVisit;

  /// Title text (lib/features/home/presentation/home_screen.dart:606)
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get homeAskAi;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:76)
  ///
  /// In en, this message translates to:
  /// **'CD'**
  String get homeCd;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1122)
  ///
  /// In en, this message translates to:
  /// **'CD'**
  String get homeCd2;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:962)
  ///
  /// In en, this message translates to:
  /// **'check up'**
  String get homeCheckUp;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1085)
  ///
  /// In en, this message translates to:
  /// **'Check-up completed for today.'**
  String get homeCheckUpCompletedForToday;

  /// Title text (lib/features/home/presentation/home_screen.dart:622)
  ///
  /// In en, this message translates to:
  /// **'Checks to plan'**
  String get homeChecksToPlan;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1101)
  ///
  /// In en, this message translates to:
  /// **'Complete check-up'**
  String get homeCompleteCheckUp;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1093)
  ///
  /// In en, this message translates to:
  /// **'Complete it now to stop today\'\'s reminders.'**
  String get homeCompleteItNowToStopToday;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1000)
  ///
  /// In en, this message translates to:
  /// **'Create first check-up'**
  String get homeCreateFirstCheckUp;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:891)
  ///
  /// In en, this message translates to:
  /// **'dd MMM · HH:mm'**
  String get homeDdMmmHhMm;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1010)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get homeDdMmmYyyy;

  /// Title text (lib/features/home/presentation/home_screen.dart:880)
  ///
  /// In en, this message translates to:
  /// **'Everything looks stable right now.'**
  String get homeEverythingLooksStableRightNow;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1079)
  ///
  /// In en, this message translates to:
  /// **'HH:mm'**
  String get homeHhMm;

  /// Title text (lib/features/home/presentation/home_screen.dart:592)
  ///
  /// In en, this message translates to:
  /// **'History and boosters'**
  String get homeHistoryAndBoosters;

  /// Title text (lib/features/home/presentation/home_screen.dart:585)
  ///
  /// In en, this message translates to:
  /// **'How are you today?'**
  String get homeHowAreYouToday;

  /// Title text (lib/features/home/presentation/home_screen.dart:1025)
  ///
  /// In en, this message translates to:
  /// **'Latest saved check-ins in your diary.'**
  String get homeLatestSavedCheckInsInYour;

  /// Title text (lib/features/home/presentation/home_screen.dart:462)
  ///
  /// In en, this message translates to:
  /// **'Less frequent actions and settings.'**
  String get homeLessFrequentActionsAndSettings;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:206)
  ///
  /// In en, this message translates to:
  /// **'Local sync up to date'**
  String get homeLocalSyncUpToDate;

  /// Title text (lib/features/home/presentation/home_screen.dart:383)
  ///
  /// In en, this message translates to:
  /// **'Next recommended checks'**
  String get homeNextRecommendedChecks;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:886)
  ///
  /// In en, this message translates to:
  /// **'No active alerts to review.'**
  String get homeNoActiveAlertsToReview;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:995)
  ///
  /// In en, this message translates to:
  /// **'No check-up saved yet.'**
  String get homeNoCheckUpSavedYet;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1054)
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get homeNoNotes;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:884)
  ///
  /// In en, this message translates to:
  /// **'Open center'**
  String get homeOpenCenter;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1029)
  ///
  /// In en, this message translates to:
  /// **'Open diary'**
  String get homeOpenDiary;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:495)
  ///
  /// In en, this message translates to:
  /// **'Privacy and AI'**
  String get homePrivacyAndAi;

  /// Title text (lib/features/home/presentation/home_screen.dart:347)
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// Title text (lib/features/home/presentation/home_screen.dart:337)
  ///
  /// In en, this message translates to:
  /// **'Recent check-ups'**
  String get homeRecentCheckUps;

  /// Title text (lib/features/home/presentation/home_screen.dart:341)
  ///
  /// In en, this message translates to:
  /// **'Recent check-ups'**
  String get homeRecentCheckUps2;

  /// Title text (lib/features/home/presentation/home_screen.dart:990)
  ///
  /// In en, this message translates to:
  /// **'Recent check-ups'**
  String get homeRecentCheckUps3;

  /// Title text (lib/features/home/presentation/home_screen.dart:1024)
  ///
  /// In en, this message translates to:
  /// **'Recent check-ups'**
  String get homeRecentCheckUps4;

  /// Title text (lib/features/home/presentation/home_screen.dart:599)
  ///
  /// In en, this message translates to:
  /// **'Reports and files'**
  String get homeReportsAndFiles;

  /// Title text (lib/features/home/presentation/home_screen.dart:359)
  ///
  /// In en, this message translates to:
  /// **'Save and review files'**
  String get homeSaveAndReviewFiles;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:554)
  ///
  /// In en, this message translates to:
  /// **'Scenario A'**
  String get homeScenarioA;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:554)
  ///
  /// In en, this message translates to:
  /// **'Scenario B'**
  String get homeScenarioB;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:554)
  ///
  /// In en, this message translates to:
  /// **'Scenario C'**
  String get homeScenarioC;

  /// Title text (lib/features/home/presentation/home_screen.dart:461)
  ///
  /// In en, this message translates to:
  /// **'Secondary tools'**
  String get homeSecondaryTools;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:69)
  ///
  /// In en, this message translates to:
  /// **'Start with one action below.'**
  String get homeStartWithOneActionBelow;

  /// Title text (lib/features/home/presentation/home_screen.dart:607)
  ///
  /// In en, this message translates to:
  /// **'Summaries and help'**
  String get homeSummariesAndHelp;

  /// Title text (lib/features/home/presentation/home_screen.dart:895)
  ///
  /// In en, this message translates to:
  /// **'Tap an alert to open the relevant section.'**
  String get homeTapAnAlertToOpenThe;

  /// Title text (lib/features/home/presentation/home_screen.dart:631)
  ///
  /// In en, this message translates to:
  /// **'The important sections are now one tap away.'**
  String get homeTheImportantSectionsAreNowOne;

  /// Title text (lib/features/home/presentation/home_screen.dart:991)
  ///
  /// In en, this message translates to:
  /// **'The latest check-ins appear here right after saving.'**
  String get homeTheLatestCheckInsAppearHere;

  /// Title text (lib/features/home/presentation/home_screen.dart:370)
  ///
  /// In en, this message translates to:
  /// **'Today and schedule'**
  String get homeTodayAndSchedule;

  /// Title text (lib/features/home/presentation/home_screen.dart:615)
  ///
  /// In en, this message translates to:
  /// **'Today schedule'**
  String get homeTodaySchedule;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1086)
  ///
  /// In en, this message translates to:
  /// **'Today still needs a check-up.'**
  String get homeTodayStillNeedsACheckUp;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:1101)
  ///
  /// In en, this message translates to:
  /// **'Update check-up'**
  String get homeUpdateCheckUp;

  /// Title text (lib/features/home/presentation/home_screen.dart:348)
  ///
  /// In en, this message translates to:
  /// **'Use these most of the time.'**
  String get homeUseTheseMostOfTheTime;

  /// Title text (lib/features/home/presentation/home_screen.dart:591)
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get homeVaccines;

  /// User-facing UI text (lib/features/home/presentation/home_screen.dart:899)
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// Title text (lib/features/home/presentation/home_screen.dart:630)
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get homeWhatDoYouNeed;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:470)
  ///
  /// In en, this message translates to:
  /// **'A calm place to understand your diary. You stay in control.'**
  String get insightsACalmPlaceToUnderstandYour;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:249)
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get insightsActions;

  /// No description provided for @insightsActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'Active profile: {profile}'**
  String insightsActiveProfile(Object profile);

  /// Title text (lib/features/insights/presentation/insights_screen.dart:209)
  ///
  /// In en, this message translates to:
  /// **'AI recap'**
  String get insightsAiRecap;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:1233)
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get insightsAnswer;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:28)
  ///
  /// In en, this message translates to:
  /// **'Are there any important trends or associations to watch?'**
  String get insightsAreThereAnyImportantTrendsOr;

  /// Input label text (lib/features/insights/presentation/gemma_center_screen.dart:555)
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your diary'**
  String get insightsAskAnythingAboutYourDiary;

  /// No description provided for @insightsAskDiaryExample.
  ///
  /// In en, this message translates to:
  /// **'Example: what changed this week?'**
  String get insightsAskDiaryExample;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:1033)
  ///
  /// In en, this message translates to:
  /// **'Ask one question at a time.'**
  String get insightsAskOneQuestionAtATime;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:431)
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get insightsB;

  /// No description provided for @insightsCalmPlace.
  ///
  /// In en, this message translates to:
  /// **'A calm place to understand your diary. You stay in control.'**
  String get insightsCalmPlace;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1135)
  ///
  /// In en, this message translates to:
  /// **'Cautious fallback'**
  String get insightsCautiousFallback;

  /// Title text (lib/features/insights/presentation/insights_screen.dart:349)
  ///
  /// In en, this message translates to:
  /// **'Cautious use'**
  String get insightsCautiousUse;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:802)
  ///
  /// In en, this message translates to:
  /// **'Checking local runtime...'**
  String get insightsCheckingLocalRuntime;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:354)
  ///
  /// In en, this message translates to:
  /// **'Checking model status...'**
  String get insightsCheckingModelStatus;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:743)
  ///
  /// In en, this message translates to:
  /// **'Checking on-device inference...'**
  String get insightsCheckingOnDeviceInference;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:255)
  ///
  /// In en, this message translates to:
  /// **'Choose a period and a date.'**
  String get insightsChooseAPeriodAndADate;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:838)
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get insightsClear;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1133)
  ///
  /// In en, this message translates to:
  /// **'Compatible provider'**
  String get insightsCompatibleProvider;

  /// Tooltip (lib/features/insights/presentation/insights_screen.dart:213)
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get insightsCopyReport;

  /// No description provided for @insightsCouldNotAnswerThisTime.
  ///
  /// In en, this message translates to:
  /// **'I could not answer this time. {error}'**
  String insightsCouldNotAnswerThisTime(Object error);

  /// Title text (lib/features/insights/domain/gemma_center_history_entry.dart:82)
  ///
  /// In en, this message translates to:
  /// **'Daily recap'**
  String get insightsDailyRecap;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1118)
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get insightsDailySummary;

  /// No description provided for @insightsDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String insightsDateLabel(Object date);

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:266)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get insightsDay;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:629)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get insightsDdMmmYyyy;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:204)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get insightsDdMmmYyyy2;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:1210)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get insightsDdMmmYyyyHhMm;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:203)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get insightsDdMmmYyyyHhMm2;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:160)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get insightsDdMmmYyyyHhMm3;

  /// No description provided for @insightsDocumentHasOcr.
  ///
  /// In en, this message translates to:
  /// **'The document contains OCR text that Gemma can use for a summary.'**
  String get insightsDocumentHasOcr;

  /// No description provided for @insightsDocumentStructuredSummary.
  ///
  /// In en, this message translates to:
  /// **'The document has metadata and structured sections that Gemma can summarize cautiously.'**
  String get insightsDocumentStructuredSummary;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:498)
  ///
  /// In en, this message translates to:
  /// **'Dot = day with activity'**
  String get insightsDotDayWithActivity;

  /// Input hint text (lib/features/insights/presentation/gemma_center_screen.dart:556)
  ///
  /// In en, this message translates to:
  /// **'Example: what changed this week?'**
  String get insightsExampleWhatChangedThisWeek;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:218)
  ///
  /// In en, this message translates to:
  /// **'Exception:'**
  String get insightsException;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:328)
  ///
  /// In en, this message translates to:
  /// **'Exception:'**
  String get insightsException2;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:368)
  ///
  /// In en, this message translates to:
  /// **'Exception:'**
  String get insightsException3;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:410)
  ///
  /// In en, this message translates to:
  /// **'Exception:'**
  String get insightsException4;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:199)
  ///
  /// In en, this message translates to:
  /// **'Expected directory'**
  String get insightsExpectedDirectory;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:723)
  ///
  /// In en, this message translates to:
  /// **'Explain a file'**
  String get insightsExplainAFile;

  /// No description provided for @insightsExplainFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a file and ask Gemma to explain it here.'**
  String get insightsExplainFileSubtitle;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:638)
  ///
  /// In en, this message translates to:
  /// **'Explain trend'**
  String get insightsExplainTrend;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:202)
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get insightsFileSize;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:431)
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get insightsGb;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1131)
  ///
  /// In en, this message translates to:
  /// **'Gemini AI Studio'**
  String get insightsGeminiAiStudio;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:1041)
  ///
  /// In en, this message translates to:
  /// **'Gemma can summarize patterns and prepare questions for your doctor, but it will not diagnose or prescribe.'**
  String get insightsGemmaCanSummarizePatternsAndPrepare;

  /// No description provided for @insightsGemmaCanSummarizeSelectedFile.
  ///
  /// In en, this message translates to:
  /// **'Gemma can summarize the selected file in simple words.'**
  String get insightsGemmaCanSummarizeSelectedFile;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:726)
  ///
  /// In en, this message translates to:
  /// **'Gemma can summarize the selected file in simple words.'**
  String get insightsGemmaCanSummarizeTheSelectedFile;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:873)
  ///
  /// In en, this message translates to:
  /// **'Gemma Center'**
  String get insightsGemmaCenter;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:670)
  ///
  /// In en, this message translates to:
  /// **'Gemma creates a practical summary with points to discuss.'**
  String get insightsGemmaCreatesAPracticalSummaryWith;

  /// No description provided for @insightsGemmaCreatesSummary.
  ///
  /// In en, this message translates to:
  /// **'Gemma creates a practical summary with points to discuss.'**
  String get insightsGemmaCreatesSummary;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:584)
  ///
  /// In en, this message translates to:
  /// **'Gemma is thinking'**
  String get insightsGemmaIsThinking;

  /// No description provided for @insightsGemmaThinking.
  ///
  /// In en, this message translates to:
  /// **'Gemma is thinking'**
  String get insightsGemmaThinking;

  /// No description provided for @insightsGemmaWelcome.
  ///
  /// In en, this message translates to:
  /// **'Gemma can summarize patterns and prepare questions for your doctor, but it will not diagnose or prescribe.'**
  String get insightsGemmaWelcome;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:26)
  ///
  /// In en, this message translates to:
  /// **'How has my clinical picture been over the last few days?'**
  String get insightsHowHasMyClinicalPictureBeen;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:329)
  ///
  /// In en, this message translates to:
  /// **'If you import a new model, ClinDiary resets the runtime and rereads the file from the app models folder.'**
  String get insightsIfYouImportANewModel;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:37)
  ///
  /// In en, this message translates to:
  /// **'Import canceled.'**
  String get insightsImportCanceled;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:989)
  ///
  /// In en, this message translates to:
  /// **'Import .litertlm model'**
  String get insightsImportLitertlmModel;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:273)
  ///
  /// In en, this message translates to:
  /// **'Import .litertlm model'**
  String get insightsImportLitertlmModel2;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:986)
  ///
  /// In en, this message translates to:
  /// **'Importing model...'**
  String get insightsImportingModel;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:270)
  ///
  /// In en, this message translates to:
  /// **'Importing model...'**
  String get insightsImportingModel2;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:431)
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get insightsKb;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:203)
  ///
  /// In en, this message translates to:
  /// **'Last modified'**
  String get insightsLastModified;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1057)
  ///
  /// In en, this message translates to:
  /// **'Loading report...'**
  String get insightsLoadingReport;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:483)
  ///
  /// In en, this message translates to:
  /// **'Local first'**
  String get insightsLocalFirst;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1125)
  ///
  /// In en, this message translates to:
  /// **'Local on-device'**
  String get insightsLocalOnDevice;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:310)
  ///
  /// In en, this message translates to:
  /// **'Local private'**
  String get insightsLocalPrivate;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:392)
  ///
  /// In en, this message translates to:
  /// **'Local private mode'**
  String get insightsLocalPrivateMode;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1127)
  ///
  /// In en, this message translates to:
  /// **'Local private mode'**
  String get insightsLocalPrivateMode2;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:552)
  ///
  /// In en, this message translates to:
  /// **'Local private path active'**
  String get insightsLocalPrivatePathActive;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:773)
  ///
  /// In en, this message translates to:
  /// **'Local proof'**
  String get insightsLocalProof;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:610)
  ///
  /// In en, this message translates to:
  /// **'Look for simple changes in your recent diary.'**
  String get insightsLookForSimpleChangesInYour;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1002)
  ///
  /// In en, this message translates to:
  /// **'Manage model'**
  String get insightsManageModel;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:122)
  ///
  /// In en, this message translates to:
  /// **'Manage the LiteRT-LM model used for on-device recaps.'**
  String get insightsManageTheLitertLmModelUsed;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:431)
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get insightsMb;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get insightsModel;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:134)
  ///
  /// In en, this message translates to:
  /// **'Model import canceled.'**
  String get insightsModelImportCanceled;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:276)
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get insightsMonth;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1114)
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get insightsMonthlySummary;

  /// No description provided for @insightsNoAnswersSaved.
  ///
  /// In en, this message translates to:
  /// **'No answers saved for this profile yet.'**
  String get insightsNoAnswersSaved;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:843)
  ///
  /// In en, this message translates to:
  /// **'No answers saved for this profile yet.'**
  String get insightsNoAnswersSavedForThisProfile;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:486)
  ///
  /// In en, this message translates to:
  /// **'No diagnosis'**
  String get insightsNoDiagnosis;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:903)
  ///
  /// In en, this message translates to:
  /// **'Not ready'**
  String get insightsNotReady;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:191)
  ///
  /// In en, this message translates to:
  /// **'Not ready'**
  String get insightsNotReady2;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:315)
  ///
  /// In en, this message translates to:
  /// **'On device'**
  String get insightsOnDevice;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:561)
  ///
  /// In en, this message translates to:
  /// **'On-device inference active'**
  String get insightsOnDeviceInferenceActive;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:398)
  ///
  /// In en, this message translates to:
  /// **'On-device local'**
  String get insightsOnDeviceLocal;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:878)
  ///
  /// In en, this message translates to:
  /// **'On-device mode runs the daily recap directly on Android with LiteRT-LM. It reuses the cautious ClinDiary prompt but does not send the text to the cloud AI provider.'**
  String get insightsOnDeviceModeRunsTheDaily;

  /// Title text (lib/features/insights/presentation/on_device_model_screen.dart:117)
  ///
  /// In en, this message translates to:
  /// **'On-device model'**
  String get insightsOnDeviceModel;

  /// Snackbar message (lib/features/insights/presentation/on_device_model_screen.dart:69)
  ///
  /// In en, this message translates to:
  /// **'On-device model removed.'**
  String get insightsOnDeviceModelRemoved;

  /// Snackbar message (lib/features/insights/presentation/on_device_model_screen.dart:97)
  ///
  /// In en, this message translates to:
  /// **'On-device runtime reset.'**
  String get insightsOnDeviceRuntimeReset;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:725)
  ///
  /// In en, this message translates to:
  /// **'Open a file and ask Gemma to explain it here.'**
  String get insightsOpenAFileAndAskGemma;

  /// No description provided for @insightsOpenAnyFileFromDocuments.
  ///
  /// In en, this message translates to:
  /// **'Open any file from Documents, then ask Gemma to explain it.'**
  String get insightsOpenAnyFileFromDocuments;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:776)
  ///
  /// In en, this message translates to:
  /// **'Open any file from Documents, then ask Gemma to explain it.'**
  String get insightsOpenAnyFileFromDocumentsThen;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:829)
  ///
  /// In en, this message translates to:
  /// **'Past answers'**
  String get insightsPastAnswers;

  /// No description provided for @insightsPastAnswersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Previous Gemma replies for this profile.'**
  String get insightsPastAnswersSubtitle;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:197)
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get insightsPath;

  /// No description provided for @insightsPickADay.
  ///
  /// In en, this message translates to:
  /// **'Pick a day and Gemma will explain what changed around it.'**
  String get insightsPickADay;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:617)
  ///
  /// In en, this message translates to:
  /// **'Pick a day and Gemma will explain what changed around it.'**
  String get insightsPickADayAndGemmaWill;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:322)
  ///
  /// In en, this message translates to:
  /// **'Practical notes'**
  String get insightsPracticalNotes;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:281)
  ///
  /// In en, this message translates to:
  /// **'Pre-visit'**
  String get insightsPreVisit;

  /// Title text (lib/features/insights/domain/gemma_center_history_entry.dart:67)
  ///
  /// In en, this message translates to:
  /// **'Pre-visit brief'**
  String get insightsPreVisitBrief;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1116)
  ///
  /// In en, this message translates to:
  /// **'Pre-visit summary'**
  String get insightsPreVisitSummary;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:691)
  ///
  /// In en, this message translates to:
  /// **'Prepare note'**
  String get insightsPrepareNote;

  /// No description provided for @insightsPrepareVisitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn your diary into a short note for the doctor.'**
  String get insightsPrepareVisitSubtitle;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:662)
  ///
  /// In en, this message translates to:
  /// **'Prepare your visit'**
  String get insightsPrepareYourVisit;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:830)
  ///
  /// In en, this message translates to:
  /// **'Previous Gemma replies for this profile.'**
  String get insightsPreviousGemmaRepliesForThisProfile;

  /// Snackbar message (lib/features/insights/presentation/gemma_center_screen.dart:814)
  ///
  /// In en, this message translates to:
  /// **'Profile history cleared.'**
  String get insightsProfileHistoryCleared;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:1222)
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get insightsPrompt;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:918)
  ///
  /// In en, this message translates to:
  /// **'Proof on-device'**
  String get insightsProofOnDevice;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:903)
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get insightsReady;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1137)
  ///
  /// In en, this message translates to:
  /// **'Recap AI'**
  String get insightsRecapAi;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:295)
  ///
  /// In en, this message translates to:
  /// **'Recap mode'**
  String get insightsRecapMode;

  /// No description provided for @insightsReferenceDate.
  ///
  /// In en, this message translates to:
  /// **'Ref. {date}'**
  String insightsReferenceDate(Object date);

  /// Tooltip (lib/features/insights/presentation/gemma_center_screen.dart:888)
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get insightsRefresh;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:224)
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get insightsRegenerate;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1129)
  ///
  /// In en, this message translates to:
  /// **'Regolo AI'**
  String get insightsRegoloAi;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:288)
  ///
  /// In en, this message translates to:
  /// **'Remove model'**
  String get insightsRemoveModel;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:288)
  ///
  /// In en, this message translates to:
  /// **'Removing model...'**
  String get insightsRemovingModel;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:988)
  ///
  /// In en, this message translates to:
  /// **'Replace model'**
  String get insightsReplaceModel;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:272)
  ///
  /// In en, this message translates to:
  /// **'Replace model'**
  String get insightsReplaceModel2;

  /// Snackbar message (lib/features/insights/presentation/insights_screen.dart:159)
  ///
  /// In en, this message translates to:
  /// **'Report copied to clipboard.'**
  String get insightsReportCopiedToClipboard;

  /// Snackbar message (lib/features/insights/presentation/insights_screen.dart:90)
  ///
  /// In en, this message translates to:
  /// **'Report regenerated.'**
  String get insightsReportRegenerated;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:534)
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get insightsRequest;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:301)
  ///
  /// In en, this message translates to:
  /// **'Reset runtime'**
  String get insightsResetRuntime;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:301)
  ///
  /// In en, this message translates to:
  /// **'Resetting runtime...'**
  String get insightsResettingRuntime;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:490)
  ///
  /// In en, this message translates to:
  /// **'Safety checks stay separate'**
  String get insightsSafetyChecksStaySeparate;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:609)
  ///
  /// In en, this message translates to:
  /// **'Spot patterns'**
  String get insightsSpotPatterns;

  /// No description provided for @insightsSpotPatternsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Look for simple changes in your recent diary.'**
  String get insightsSpotPatternsSubtitle;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:305)
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get insightsStandard;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:175)
  ///
  /// In en, this message translates to:
  /// **'Stato runtime'**
  String get insightsStatoRuntime;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:765)
  ///
  /// In en, this message translates to:
  /// **'Summarize document'**
  String get insightsSummarizeDocument;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:642)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get insightsT;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:463)
  ///
  /// In en, this message translates to:
  /// **'Talk with Gemma'**
  String get insightsTalkWithGemma;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:351)
  ///
  /// In en, this message translates to:
  /// **'The AI recap reorganizes diary and recent document data, but it does not replace a clinician, diagnosis, or prescription.'**
  String get insightsTheAiRecapReorganizesDiaryAnd;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:753)
  ///
  /// In en, this message translates to:
  /// **'The document contains OCR text that Gemma can use for a summary.'**
  String get insightsTheDocumentContainsOcrTextThat;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:754)
  ///
  /// In en, this message translates to:
  /// **'The document has metadata and structured sections that Gemma can summarize cautiously.'**
  String get insightsTheDocumentHasMetadataAndStructured;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:698)
  ///
  /// In en, this message translates to:
  /// **'The local private mode uses a local/private runtime for the daily recap. The text is intentionally shorter and stays on the device.'**
  String get insightsTheLocalPrivateModeUsesA;

  /// User-facing UI text (lib/features/insights/data/on_device_ai_service.dart:118)
  ///
  /// In en, this message translates to:
  /// **'The on-device runtime returned empty content.'**
  String get insightsTheOnDeviceRuntimeReturnedEmpty;

  /// User-facing UI text (lib/features/insights/data/on_device_ai_service.dart:145)
  ///
  /// In en, this message translates to:
  /// **'The on-device runtime returned empty embedding.'**
  String get insightsTheOnDeviceRuntimeReturnedEmpty2;

  /// Title text (lib/features/insights/domain/gemma_center_history_entry.dart:52)
  ///
  /// In en, this message translates to:
  /// **'Trend analysis'**
  String get insightsTrendAnalysis;

  /// Title text (lib/features/insights/presentation/gemma_center_screen.dart:663)
  ///
  /// In en, this message translates to:
  /// **'Turn your diary into a short note for the doctor.'**
  String get insightsTurnYourDiaryIntoAShort;

  /// No description provided for @insightsUnableToClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Unable to clear history: {error}'**
  String insightsUnableToClearHistory(Object error);

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:139)
  ///
  /// In en, this message translates to:
  /// **'US'**
  String get insightsUs;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:55)
  ///
  /// In en, this message translates to:
  /// **'US'**
  String get insightsUs2;

  /// User-facing UI text (lib/features/insights/presentation/on_device_model_screen.dart:325)
  ///
  /// In en, this message translates to:
  /// **'Use a .litertlm file compatible with LiteRT-LM on Android. For the on-device recap demo, the target remains Gemma 4 E2B.'**
  String get insightsUseALitertlmFileCompatibleWith;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:271)
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get insightsWeek;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:1112)
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get insightsWeeklySummary;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:29)
  ///
  /// In en, this message translates to:
  /// **'What am I missing to get a more complete picture?'**
  String get insightsWhatAmIMissingToGet;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:27)
  ///
  /// In en, this message translates to:
  /// **'What changes should I bring to the doctor at the next visit?'**
  String get insightsWhatChangesShouldIBringTo;

  /// User-facing UI text (lib/features/insights/presentation/gemma_center_screen.dart:175)
  ///
  /// In en, this message translates to:
  /// **'Write a question before asking Gemma.'**
  String get insightsWriteAQuestionBeforeAskingGemma;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:791)
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get insightsYes;

  /// User-facing UI text (lib/features/insights/presentation/insights_screen.dart:942)
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get insightsYes2;

  /// No description provided for @judgeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Judge Mode'**
  String get judgeModeSubtitle;

  /// User-facing UI text (lib/app/core/storage/local_database.dart:224)
  ///
  /// In en, this message translates to:
  /// **'PRAGMA foreign_keys = ON'**
  String get localDatabasePragmaForeignKeysOn;

  /// User-facing UI text (lib/app/core/storage/local_database.dart:225)
  ///
  /// In en, this message translates to:
  /// **'PRAGMA journal_mode = WAL'**
  String get localDatabasePragmaJournalModeWal;

  /// User-facing UI text (lib/app/core/storage/local_database.dart:315)
  ///
  /// In en, this message translates to:
  /// **'UPDATE pending_operations SET attempts = attempts + 1, last_error = ? WHERE id = ?'**
  String get localDatabaseUpdatePendingOperationsSetAttemptsAttempts;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:22)
  ///
  /// In en, this message translates to:
  /// **'Check-in reminders'**
  String get localMedicationReminderServiceCheckInReminders;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:412)
  ///
  /// In en, this message translates to:
  /// **'Daily check-in reminders are disabled in preferences.'**
  String get localMedicationReminderServiceDailyCheckInRemindersAreDisabled;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:452)
  ///
  /// In en, this message translates to:
  /// **'Daily check-in reminders synchronized on the device.'**
  String get localMedicationReminderServiceDailyCheckInRemindersSynchronizedOn;

  /// Title text (lib/app/core/notifications/local_medication_reminder_service.dart:954)
  ///
  /// In en, this message translates to:
  /// **'Daily check-up'**
  String get localMedicationReminderServiceDailyCheckUp;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:321)
  ///
  /// In en, this message translates to:
  /// **'Enable device notifications first to generate reminders.'**
  String get localMedicationReminderServiceEnableDeviceNotificationsFirstToGenerate;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:422)
  ///
  /// In en, this message translates to:
  /// **'Enable device notifications first to generate reminders.'**
  String get localMedicationReminderServiceEnableDeviceNotificationsFirstToGenerate2;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:515)
  ///
  /// In en, this message translates to:
  /// **'Enable device notifications first to generate reminders.'**
  String get localMedicationReminderServiceEnableDeviceNotificationsFirstToGenerate3;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:212)
  ///
  /// In en, this message translates to:
  /// **'Local reminders are available on Android and iOS.'**
  String get localMedicationReminderServiceLocalRemindersAreAvailableOnAndroid;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:20)
  ///
  /// In en, this message translates to:
  /// **'Local reminders generated on the device for medication therapy.'**
  String get localMedicationReminderServiceLocalRemindersGeneratedOnTheDevice;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:24)
  ///
  /// In en, this message translates to:
  /// **'Local reminders generated on the device for the daily check-up.'**
  String get localMedicationReminderServiceLocalRemindersGeneratedOnTheDevice2;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:28)
  ///
  /// In en, this message translates to:
  /// **'Local reminders generated on the device to confirm recent symptoms.'**
  String get localMedicationReminderServiceLocalRemindersGeneratedOnTheDevice3;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:357)
  ///
  /// In en, this message translates to:
  /// **'Local reminders synchronized on the device.'**
  String get localMedicationReminderServiceLocalRemindersSynchronizedOnTheDevice;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:18)
  ///
  /// In en, this message translates to:
  /// **'Medication reminders'**
  String get localMedicationReminderServiceMedicationReminders;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:309)
  ///
  /// In en, this message translates to:
  /// **'Medication reminders are disabled in preferences.'**
  String get localMedicationReminderServiceMedicationRemindersAreDisabledInPreferences;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:143)
  ///
  /// In en, this message translates to:
  /// **'@mipmap/ic_launcher'**
  String get localMedicationReminderServiceMipmapIcLauncher;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:451)
  ///
  /// In en, this message translates to:
  /// **'No daily check-in reminders can be scheduled right now.'**
  String get localMedicationReminderServiceNoDailyCheckInRemindersCan;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:356)
  ///
  /// In en, this message translates to:
  /// **'No reminders can be scheduled with the current data.'**
  String get localMedicationReminderServiceNoRemindersCanBeScheduledWith;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:539)
  ///
  /// In en, this message translates to:
  /// **'No symptom follow-up reminders can be scheduled right now.'**
  String get localMedicationReminderServiceNoSymptomFollowUpRemindersCan;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:284)
  ///
  /// In en, this message translates to:
  /// **'Permesso notifiche negato dal dispositivo.'**
  String get localMedicationReminderServicePermessoNotificheNegatoDalDispositivo;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:230)
  ///
  /// In en, this message translates to:
  /// **'Permesso notifiche non ancora concesso sul dispositivo.'**
  String get localMedicationReminderServicePermessoNotificheNonAncoraConcessoSul;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:680)
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get localMedicationReminderServiceResolved;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:798)
  ///
  /// In en, this message translates to:
  /// **'sourceEntryId'**
  String get localMedicationReminderServiceSourceentryid;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:799)
  ///
  /// In en, this message translates to:
  /// **'sourceSymptomId'**
  String get localMedicationReminderServiceSourcesymptomid;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:674)
  ///
  /// In en, this message translates to:
  /// **'Still present'**
  String get localMedicationReminderServiceStillPresent;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:26)
  ///
  /// In en, this message translates to:
  /// **'Symptom follow-up'**
  String get localMedicationReminderServiceSymptomFollowUp;

  /// Title text (lib/app/core/notifications/local_medication_reminder_service.dart:999)
  ///
  /// In en, this message translates to:
  /// **'Symptom follow-up'**
  String get localMedicationReminderServiceSymptomFollowUp2;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:505)
  ///
  /// In en, this message translates to:
  /// **'Symptom follow-up reminders are disabled in preferences.'**
  String get localMedicationReminderServiceSymptomFollowUpRemindersAreDisabled;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:540)
  ///
  /// In en, this message translates to:
  /// **'Symptom follow-up reminders synchronized on the device.'**
  String get localMedicationReminderServiceSymptomFollowUpRemindersSynchronizedOn;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:705)
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get localMedicationReminderServiceUtc;

  /// User-facing UI text (lib/app/core/notifications/local_medication_reminder_service.dart:955)
  ///
  /// In en, this message translates to:
  /// **'You still have not completed today\'\'s check-up.'**
  String get localMedicationReminderServiceYouStillHaveNotCompletedToday;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:856)
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:114)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:512)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications2;

  /// Title text (lib/features/home/presentation/home_screen.dart:614)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications3;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:429)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:112)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications5;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1347)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications6;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1373)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications7;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:88)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications8;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:570)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get medicationsActive;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:454)
  ///
  /// In en, this message translates to:
  /// **'Active medications and reminders.'**
  String get medicationsActiveMedicationsAndReminders;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:701)
  ///
  /// In en, this message translates to:
  /// **'Adherence history'**
  String get medicationsAdherenceHistory;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:725)
  ///
  /// In en, this message translates to:
  /// **'Adherence history'**
  String get medicationsAdherenceHistory2;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:729)
  ///
  /// In en, this message translates to:
  /// **'Adherence history'**
  String get medicationsAdherenceHistory3;

  /// No description provided for @medicationsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get medicationsAllCaughtUp;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:661)
  ///
  /// In en, this message translates to:
  /// **'Already logged'**
  String get medicationsAlreadyLogged;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:319)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get medicationsCancel;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:373)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get medicationsCancel2;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:408)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get medicationsCancel3;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:355)
  ///
  /// In en, this message translates to:
  /// **'Confirm intake'**
  String get medicationsConfirmIntake;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:21)
  ///
  /// In en, this message translates to:
  /// **'dd/MM/yyyy'**
  String get medicationsDdMmYyyy;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:18)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get medicationsDdMmmYyyyHhMm;

  /// No description provided for @medicationsDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get medicationsDue;

  /// Input hint text (lib/features/medications/presentation/medications_screen.dart:302)
  ///
  /// In en, this message translates to:
  /// **'e.g. after dinner'**
  String get medicationsEGAfterDinner;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:609)
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get medicationsEdit;

  /// Input label text (lib/features/medications/presentation/medications_screen.dart:301)
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get medicationsInstructions;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:130)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get medicationsIt;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:702)
  ///
  /// In en, this message translates to:
  /// **'Latest confirmations.'**
  String get medicationsLatestConfirmations;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:660)
  ///
  /// In en, this message translates to:
  /// **'Mark as taken'**
  String get medicationsMarkAsTaken;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:453)
  ///
  /// In en, this message translates to:
  /// **'Medication therapy'**
  String get medicationsMedicationTherapy;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:690)
  ///
  /// In en, this message translates to:
  /// **'Medication therapy'**
  String get medicationsMedicationTherapy2;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:694)
  ///
  /// In en, this message translates to:
  /// **'Medication therapy'**
  String get medicationsMedicationTherapy3;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:456)
  ///
  /// In en, this message translates to:
  /// **'No active therapy recorded.'**
  String get medicationsNoActiveTherapyRecorded;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:704)
  ///
  /// In en, this message translates to:
  /// **'No intake confirmations yet.'**
  String get medicationsNoIntakeConfirmationsYet;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:746)
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get medicationsNotConfirmed;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:364)
  ///
  /// In en, this message translates to:
  /// **'Optional notes'**
  String get medicationsOptionalNotes;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:285)
  ///
  /// In en, this message translates to:
  /// **'Orario'**
  String get medicationsOrario;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:621)
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get medicationsPause;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:571)
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get medicationsPaused;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:488)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get medicationsPendingSync;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:365)
  ///
  /// In en, this message translates to:
  /// **'Reason or optional notes'**
  String get medicationsReasonOrOptionalNotes;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:355)
  ///
  /// In en, this message translates to:
  /// **'Record missed dose'**
  String get medicationsRecordMissedDose;

  /// Snackbar message (lib/features/medications/presentation/medications_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'Reminder resumed.'**
  String get medicationsReminderResumed;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:413)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get medicationsRemove;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:227)
  ///
  /// In en, this message translates to:
  /// **'Remove medication?'**
  String get medicationsRemoveMedication;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:521)
  ///
  /// In en, this message translates to:
  /// **'Remove medication'**
  String get medicationsRemoveMedication2;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'Remove schedule?'**
  String get medicationsRemoveSchedule;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:627)
  ///
  /// In en, this message translates to:
  /// **'Remove schedule'**
  String get medicationsRemoveSchedule2;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:620)
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get medicationsResume;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:335)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get medicationsSave;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:388)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get medicationsSave2;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:72)
  ///
  /// In en, this message translates to:
  /// **'Saved offline. ClinDiary will sync as soon as the network is back.'**
  String get medicationsSavedOfflineClindiaryWillSyncAs;

  /// Title text (lib/features/medications/presentation/medications_screen.dart:310)
  ///
  /// In en, this message translates to:
  /// **'Schedule active'**
  String get medicationsScheduleActive;

  /// Snackbar message (lib/features/medications/presentation/medications_screen.dart:212)
  ///
  /// In en, this message translates to:
  /// **'Schedule removed.'**
  String get medicationsScheduleRemoved;

  /// Snackbar message (lib/features/medications/presentation/medications_screen.dart:107)
  ///
  /// In en, this message translates to:
  /// **'Schedule updated.'**
  String get medicationsScheduleUpdated;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:677)
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get medicationsSkipped;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:744)
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get medicationsSkipped2;

  /// User-facing UI text (lib/features/medications/presentation/medications_screen.dart:742)
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get medicationsTaken;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t have an account?'**
  String get noAccountPrompt;

  /// User-facing UI text (lib/features/debug/presentation/sync_debug_screen.dart:110)
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:219)
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications2;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:468)
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications3;

  /// No description provided for @notificationsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationsAllCaughtUp;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:269)
  ///
  /// In en, this message translates to:
  /// **'All read'**
  String get notificationsAllRead;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:305)
  ///
  /// In en, this message translates to:
  /// **'Check-in reminders'**
  String get notificationsCheckInReminders;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:369)
  ///
  /// In en, this message translates to:
  /// **'Clinical alerts in notifications'**
  String get notificationsClinicalAlertsInNotifications;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:398)
  ///
  /// In en, this message translates to:
  /// **'Created on the device.'**
  String get notificationsCreatedOnTheDevice;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:215)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get notificationsDdMmmYyyyHhMm;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:349)
  ///
  /// In en, this message translates to:
  /// **'Document follow-up'**
  String get notificationsDocumentFollowUp;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:146)
  ///
  /// In en, this message translates to:
  /// **'Enable at least push or email to run the test.'**
  String get notificationsEnableAtLeastPushOrEmail;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:444)
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notificationsEnableNotifications;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:288)
  ///
  /// In en, this message translates to:
  /// **'Enable only what you need.'**
  String get notificationsEnableOnlyWhatYouNeed;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:582)
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get notificationsHigh;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:474)
  ///
  /// In en, this message translates to:
  /// **'Latest notifications'**
  String get notificationsLatestNotifications;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:397)
  ///
  /// In en, this message translates to:
  /// **'Local reminders'**
  String get notificationsLocalReminders;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:451)
  ///
  /// In en, this message translates to:
  /// **'Local reminders'**
  String get notificationsLocalReminders2;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:455)
  ///
  /// In en, this message translates to:
  /// **'Local reminders'**
  String get notificationsLocalReminders3;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:584)
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get notificationsLow;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:540)
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationsMarkAsRead;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:327)
  ///
  /// In en, this message translates to:
  /// **'Medication reminders'**
  String get notificationsMedicationReminders;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:475)
  ///
  /// In en, this message translates to:
  /// **'Most recent first.'**
  String get notificationsMostRecentFirst;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:268)
  ///
  /// In en, this message translates to:
  /// **'Need attention'**
  String get notificationsNeedAttention;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:469)
  ///
  /// In en, this message translates to:
  /// **'No active notifications.'**
  String get notificationsNoActiveNotifications;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:586)
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get notificationsNormal;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:237)
  ///
  /// In en, this message translates to:
  /// **'Notification and reminder status.'**
  String get notificationsNotificationAndReminderStatus;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:195)
  ///
  /// In en, this message translates to:
  /// **'Notification permission enabled.'**
  String get notificationsNotificationPermissionEnabled;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'Notification permission not granted.'**
  String get notificationsNotificationPermissionNotGranted;

  /// Title text (lib/features/notifications/data/notifications_repository.dart:37)
  ///
  /// In en, this message translates to:
  /// **'Notification updated'**
  String get notificationsNotificationUpdated;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:298)
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notificationsNotificationsEnabled;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:236)
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get notificationsOverview;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:278)
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get notificationsOverview2;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:282)
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get notificationsOverview3;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:417)
  ///
  /// In en, this message translates to:
  /// **'Permission granted'**
  String get notificationsPermissionGranted;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:418)
  ///
  /// In en, this message translates to:
  /// **'Permission needs to be enabled'**
  String get notificationsPermissionNeedsToBeEnabled;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:380)
  ///
  /// In en, this message translates to:
  /// **'Prevention tips'**
  String get notificationsPreventionTips;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:525)
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notificationsRead;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:287)
  ///
  /// In en, this message translates to:
  /// **'Reminder preferences'**
  String get notificationsReminderPreferences;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:386)
  ///
  /// In en, this message translates to:
  /// **'Reminder preferences'**
  String get notificationsReminderPreferences2;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:390)
  ///
  /// In en, this message translates to:
  /// **'Reminder preferences'**
  String get notificationsReminderPreferences3;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:358)
  ///
  /// In en, this message translates to:
  /// **'Reports ready'**
  String get notificationsReportsReady;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:338)
  ///
  /// In en, this message translates to:
  /// **'Screening reminders'**
  String get notificationsScreeningReminders;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:239)
  ///
  /// In en, this message translates to:
  /// **'Send test notifications'**
  String get notificationsSendTestNotifications;

  /// Title text (lib/features/notifications/presentation/notifications_screen.dart:316)
  ///
  /// In en, this message translates to:
  /// **'Symptom follow-up reminders'**
  String get notificationsSymptomFollowUpReminders;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:403)
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get notificationsSync;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:631)
  ///
  /// In en, this message translates to:
  /// **'Test delivery completed.'**
  String get notificationsTestDeliveryCompleted;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:249)
  ///
  /// In en, this message translates to:
  /// **'Test notifications'**
  String get notificationsTestNotifications;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:525)
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// User-facing UI text (lib/features/notifications/presentation/notifications_screen.dart:580)
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get notificationsUrgent;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:457)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get onboardingActive;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:452)
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get onboardingActivityLevel;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:465)
  ///
  /// In en, this message translates to:
  /// **'Alcohol use'**
  String get onboardingAlcoholUse;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:220)
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:360)
  ///
  /// In en, this message translates to:
  /// **'Biological sex'**
  String get onboardingBiologicalSex;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:341)
  ///
  /// In en, this message translates to:
  /// **'Birth date (YYYY-MM-DD)'**
  String get onboardingBirthDateYyyyMmDd;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:530)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary is local-first and keeps AI output assistive.'**
  String get onboardingClindiaryIsLocalFirstAndKeeps;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:382)
  ///
  /// In en, this message translates to:
  /// **'Clinical context'**
  String get onboardingClinicalContext;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:415)
  ///
  /// In en, this message translates to:
  /// **'Current smoker'**
  String get onboardingCurrentSmoker;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:285)
  ///
  /// In en, this message translates to:
  /// **'Daily diary'**
  String get onboardingDailyDiary;

  /// Input hint text (lib/features/onboarding/presentation/onboarding_screen.dart:488)
  ///
  /// In en, this message translates to:
  /// **'E.g. irregular sleep due to shifts'**
  String get onboardingEGIrregularSleepDueTo;

  /// Input hint text (lib/features/onboarding/presentation/onboarding_screen.dart:515)
  ///
  /// In en, this message translates to:
  /// **'E.g. sedentary job / night shifts'**
  String get onboardingEGSedentaryJobNightShifts;

  /// Input hint text (lib/features/onboarding/presentation/onboarding_screen.dart:497)
  ///
  /// In en, this message translates to:
  /// **'E.g. stress, little sleep, intense exertion'**
  String get onboardingEGStressLittleSleepIntense;

  /// Input hint text (lib/features/onboarding/presentation/onboarding_screen.dart:506)
  ///
  /// In en, this message translates to:
  /// **'E.g. trouble with stairs or prolonged standing'**
  String get onboardingEGTroubleWithStairsOr;

  /// Input hint text (lib/features/onboarding/presentation/onboarding_screen.dart:479)
  ///
  /// In en, this message translates to:
  /// **'E.g. walking 30 minutes most days'**
  String get onboardingEGWalking30MinutesMost;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:540)
  ///
  /// In en, this message translates to:
  /// **'Encrypted document vault'**
  String get onboardingEncryptedDocumentVault;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:290)
  ///
  /// In en, this message translates to:
  /// **'Encrypted vault'**
  String get onboardingEncryptedVault;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:362)
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get onboardingFemale;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:324)
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get onboardingFirstName;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:505)
  ///
  /// In en, this message translates to:
  /// **'Functional limitations'**
  String get onboardingFunctionalLimitations;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:297)
  ///
  /// In en, this message translates to:
  /// **'Generate cautious summaries without delegating safety rules.'**
  String get onboardingGenerateCautiousSummariesWithoutDelegatingSafety;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:546)
  ///
  /// In en, this message translates to:
  /// **'Generated summaries do not diagnose, prescribe or triage.'**
  String get onboardingGeneratedSummariesDoNotDiagnosePrescribe;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:138)
  ///
  /// In en, this message translates to:
  /// **'Health data consent is required to use ClinDiary.'**
  String get onboardingHealthDataConsentIsRequiredTo;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:536)
  ///
  /// In en, this message translates to:
  /// **'Health diary data is stored locally on this device.'**
  String get onboardingHealthDiaryDataIsStoredLocally;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:395)
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get onboardingHeightCm;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:470)
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get onboardingHigh;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:553)
  ///
  /// In en, this message translates to:
  /// **'I consent to the processing of health data'**
  String get onboardingIConsentToTheProcessingOf;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:276)
  ///
  /// In en, this message translates to:
  /// **'In a few guided steps we will create your local clinical diary, explain the main areas, and keep your data on this device by default.'**
  String get onboardingInAFewGuidedStepsWe;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:364)
  ///
  /// In en, this message translates to:
  /// **'Intersex'**
  String get onboardingIntersex;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:352)
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get onboardingInvalidFormat;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:36)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get onboardingIt;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:433)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get onboardingIt2;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:291)
  ///
  /// In en, this message translates to:
  /// **'Keep documents in a local AES-GCM encrypted archive.'**
  String get onboardingKeepDocumentsInALocalAes;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:496)
  ///
  /// In en, this message translates to:
  /// **'Known symptom triggers'**
  String get onboardingKnownSymptomTriggers;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:332)
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get onboardingLastName;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:445)
  ///
  /// In en, this message translates to:
  /// **'Lifestyle and symptom context'**
  String get onboardingLifestyleAndSymptomContext;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:455)
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get onboardingLight;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:535)
  ///
  /// In en, this message translates to:
  /// **'Local diary data'**
  String get onboardingLocalDiaryData;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:363)
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get onboardingMale;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:456)
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get onboardingModerate;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:469)
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get onboardingModerate2;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:545)
  ///
  /// In en, this message translates to:
  /// **'No AI diagnosis'**
  String get onboardingNoAiDiagnosis;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:467)
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get onboardingNone;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:468)
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get onboardingOccasional;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:295)
  ///
  /// In en, this message translates to:
  /// **'On-device AI'**
  String get onboardingOnDeviceAi;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:384)
  ///
  /// In en, this message translates to:
  /// **'Optional values help trends, reports and prevention cards.'**
  String get onboardingOptionalValuesHelpTrendsReportsAnd;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:367)
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboardingPreferNotToSay;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:529)
  ///
  /// In en, this message translates to:
  /// **'Privacy and safety'**
  String get onboardingPrivacyAndSafety;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:568)
  ///
  /// In en, this message translates to:
  /// **'Read AI note'**
  String get onboardingReadAiNote;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:563)
  ///
  /// In en, this message translates to:
  /// **'Read privacy notice'**
  String get onboardingReadPrivacyNotice;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:327)
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get onboardingRequiredField;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:335)
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get onboardingRequiredField2;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:349)
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get onboardingRequiredField3;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:554)
  ///
  /// In en, this message translates to:
  /// **'Required to use ClinDiary on this device.'**
  String get onboardingRequiredToUseClindiaryOnThis;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:234)
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get onboardingSaving;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:422)
  ///
  /// In en, this message translates to:
  /// **'Screening region'**
  String get onboardingScreeningRegion;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:454)
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get onboardingSedentary;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:612)
  ///
  /// In en, this message translates to:
  /// **'Set up ClinDiary'**
  String get onboardingSetUpClindiary;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:236)
  ///
  /// In en, this message translates to:
  /// **'Start using ClinDiary'**
  String get onboardingStartUsingClindiary;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:319)
  ///
  /// In en, this message translates to:
  /// **'These fields personalize diary views and prevention logic.'**
  String get onboardingTheseFieldsPersonalizeDiaryViewsAnd;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:286)
  ///
  /// In en, this message translates to:
  /// **'Track symptoms, vitals, notes, sleep and daily context.'**
  String get onboardingTrackSymptomsVitalsNotesSleepAnd;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:541)
  ///
  /// In en, this message translates to:
  /// **'Uploaded documents are stored in the encrypted local vault.'**
  String get onboardingUploadedDocumentsAreStoredInThe;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:303)
  ///
  /// In en, this message translates to:
  /// **'Use deterministic local logic for screenings and reminders.'**
  String get onboardingUseDeterministicLocalLogicForScreenings;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:416)
  ///
  /// In en, this message translates to:
  /// **'Used only for local prevention logic.'**
  String get onboardingUsedOnlyForLocalPreventionLogic;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:423)
  ///
  /// In en, this message translates to:
  /// **'Used to adapt screenings and prevention to your area.'**
  String get onboardingUsedToAdaptScreeningsAndPrevention;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:478)
  ///
  /// In en, this message translates to:
  /// **'Usual exercise or physical activity'**
  String get onboardingUsualExerciseOrPhysicalActivity;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:487)
  ///
  /// In en, this message translates to:
  /// **'Usual sleep pattern'**
  String get onboardingUsualSleepPattern;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:458)
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get onboardingVeryActive;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:405)
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get onboardingWeightKg;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:269)
  ///
  /// In en, this message translates to:
  /// **'Welcome to ClinDiary'**
  String get onboardingWelcomeToClindiary;

  /// Input label text (lib/features/onboarding/presentation/onboarding_screen.dart:514)
  ///
  /// In en, this message translates to:
  /// **'Work or daily context'**
  String get onboardingWorkOrDailyContext;

  /// User-facing UI text (lib/features/onboarding/presentation/onboarding_screen.dart:447)
  ///
  /// In en, this message translates to:
  /// **'You can complete or edit these later from the profile area.'**
  String get onboardingYouCanCompleteOrEditThese;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:317)
  ///
  /// In en, this message translates to:
  /// **'Your personal baseline'**
  String get onboardingYourPersonalBaseline;

  /// No description provided for @openAiRecap.
  ///
  /// In en, this message translates to:
  /// **'Open AI Recap'**
  String get openAiRecap;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset failed: {error}'**
  String passwordResetFailed(Object error);

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

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Title text (lib/features/home/presentation/home_screen.dart:621)
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get prevention;

  /// Title text (lib/features/onboarding/presentation/onboarding_screen.dart:301)
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get prevention2;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:119)
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get prevention3;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:94)
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get prevention4;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:410)
  ///
  /// In en, this message translates to:
  /// **'Prevention'**
  String get prevention5;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:202)
  ///
  /// In en, this message translates to:
  /// **'Areas where ClinDiary stays cautious.'**
  String get preventionCenterAreasWhereClindiaryStaysCautious;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:425)
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get preventionCenterAttention;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:452)
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get preventionCenterCheck;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:39)
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get preventionCenterChecks;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:16)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get preventionCenterDdMmmYyyyHhMm;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Driven by the profile.'**
  String get preventionCenterDrivenByTheProfile;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:459)
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get preventionCenterFemale;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:42)
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get preventionCenterFollowUp;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:450)
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get preventionCenterFollowUp2;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:220)
  ///
  /// In en, this message translates to:
  /// **'Follow-up reminders'**
  String get preventionCenterFollowUpReminders;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:144)
  ///
  /// In en, this message translates to:
  /// **'General check.'**
  String get preventionCenterGeneralCheck;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:463)
  ///
  /// In en, this message translates to:
  /// **'Intersex'**
  String get preventionCenterIntersex;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:221)
  ///
  /// In en, this message translates to:
  /// **'Items to close.'**
  String get preventionCenterItemsToClose;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:461)
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get preventionCenterMale;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:197)
  ///
  /// In en, this message translates to:
  /// **'No active preconception or pregnancy pathway in the profile.'**
  String get preventionCenterNoActivePreconceptionOrPregnancyPathway;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:216)
  ///
  /// In en, this message translates to:
  /// **'No active seasonal check at the moment.'**
  String get preventionCenterNoActiveSeasonalCheckAtThe;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:157)
  ///
  /// In en, this message translates to:
  /// **'No additional periodic checks to show.'**
  String get preventionCenterNoAdditionalPeriodicChecksToShow;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:285)
  ///
  /// In en, this message translates to:
  /// **'No items available.'**
  String get preventionCenterNoItemsAvailable;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:223)
  ///
  /// In en, this message translates to:
  /// **'No open follow-up.'**
  String get preventionCenterNoOpenFollowUp;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:205)
  ///
  /// In en, this message translates to:
  /// **'No specific shared decision to show with the current data.'**
  String get preventionCenterNoSpecificSharedDecisionToShow;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:180)
  ///
  /// In en, this message translates to:
  /// **'No vaccination summary available.'**
  String get preventionCenterNoVaccinationSummaryAvailable;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:173)
  ///
  /// In en, this message translates to:
  /// **'No vaccine to highlight with the current data.'**
  String get preventionCenterNoVaccineToHighlightWithThe;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:465)
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get preventionCenterNotSpecified;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:194)
  ///
  /// In en, this message translates to:
  /// **'Only if the profile requires it.'**
  String get preventionCenterOnlyIfTheProfileRequiresIt;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:184)
  ///
  /// In en, this message translates to:
  /// **'Open history'**
  String get preventionCenterOpenHistory;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:226)
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get preventionCenterOpenNotifications;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:160)
  ///
  /// In en, this message translates to:
  /// **'Open screenings'**
  String get preventionCenterOpenScreenings;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:423)
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get preventionCenterOverdue;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:41)
  ///
  /// In en, this message translates to:
  /// **'Pathways'**
  String get preventionCenterPathways;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:53)
  ///
  /// In en, this message translates to:
  /// **'Personal prevention'**
  String get preventionCenterPersonalPrevention;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:81)
  ///
  /// In en, this message translates to:
  /// **'Personal prevention profile'**
  String get preventionCenterPersonalPreventionProfile;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:60)
  ///
  /// In en, this message translates to:
  /// **'Personal summary'**
  String get preventionCenterPersonalSummary;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:446)
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get preventionCenterPregnancy;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:193)
  ///
  /// In en, this message translates to:
  /// **'Pregnancy and preconception'**
  String get preventionCenterPregnancyAndPreconception;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:27)
  ///
  /// In en, this message translates to:
  /// **'Prevention center'**
  String get preventionCenterPreventionCenter;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:61)
  ///
  /// In en, this message translates to:
  /// **'Quick priorities.'**
  String get preventionCenterQuickPriorities;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:427)
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get preventionCenterReady;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:421)
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get preventionCenterRecommended;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:143)
  ///
  /// In en, this message translates to:
  /// **'Recommended annual visit'**
  String get preventionCenterRecommendedAnnualVisit;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:169)
  ///
  /// In en, this message translates to:
  /// **'Recommended vaccines'**
  String get preventionCenterRecommendedVaccines;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:444)
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get preventionCenterRegistry;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:429)
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get preventionCenterSeasonal;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:448)
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get preventionCenterSeasonal2;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:213)
  ///
  /// In en, this message translates to:
  /// **'Seasonal checks'**
  String get preventionCenterSeasonalChecks;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:214)
  ///
  /// In en, this message translates to:
  /// **'Seasonal reminders.'**
  String get preventionCenterSeasonalReminders;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:433)
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get preventionCenterShared;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:201)
  ///
  /// In en, this message translates to:
  /// **'Shared decisions'**
  String get preventionCenterSharedDecisions;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:38)
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get preventionCenterSummary;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'Summary status of your history.'**
  String get preventionCenterSummaryStatusOfYourHistory;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:55)
  ///
  /// In en, this message translates to:
  /// **'These recommendations help organize checks and follow-up. They are not an automatic prescription and must be contextualized with the doctor.'**
  String get preventionCenterTheseRecommendationsHelpOrganizeChecksAnd;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:435)
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get preventionCenterToReview;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:170)
  ///
  /// In en, this message translates to:
  /// **'To verify with your history.'**
  String get preventionCenterToVerifyWithYourHistory;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:431)
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get preventionCenterUpToDate;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:177)
  ///
  /// In en, this message translates to:
  /// **'Vaccination registry'**
  String get preventionCenterVaccinationRegistry;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:442)
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get preventionCenterVaccine;

  /// User-facing UI text (lib/features/prevention_center/presentation/prevention_center_screen.dart:40)
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get preventionCenterVaccines;

  /// Title text (lib/features/prevention_center/presentation/prevention_center_screen.dart:154)
  ///
  /// In en, this message translates to:
  /// **'Visits and checks for your profile'**
  String get preventionCenterVisitsAndChecksForYourProfile;

  /// No description provided for @primaryProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryProfileLabel;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1426)
  ///
  /// In en, this message translates to:
  /// **'0 items'**
  String get profile0Items;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:10)
  ///
  /// In en, this message translates to:
  /// **'Abruzzo'**
  String get profileAbruzzo;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:117)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:642)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:812)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1041)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1860)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive5;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:55)
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get profileActiveProfile;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:93)
  ///
  /// In en, this message translates to:
  /// **'Active profile ready'**
  String get profileActiveProfileReady;

  /// Title text (lib/features/profile/presentation/family_profiles_screen.dart:70)
  ///
  /// In en, this message translates to:
  /// **'Active status'**
  String get profileActiveStatus;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1854)
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profileActivity;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:630)
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get profileActivityLevel;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:506)
  ///
  /// In en, this message translates to:
  /// **'Add a vaccine in seconds'**
  String get profileAddAVaccineInSeconds;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1873)
  ///
  /// In en, this message translates to:
  /// **'Add the essential profile data.'**
  String get profileAddTheEssentialProfileData;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1798)
  ///
  /// In en, this message translates to:
  /// **'Add useful details to give recaps more context.'**
  String get profileAddUsefulDetailsToGiveRecaps;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:350)
  ///
  /// In en, this message translates to:
  /// **'Add vaccine'**
  String get profileAddVaccine;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:520)
  ///
  /// In en, this message translates to:
  /// **'Add vaccine'**
  String get profileAddVaccine2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:731)
  ///
  /// In en, this message translates to:
  /// **'Advanced prevention'**
  String get profileAdvancedPrevention;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1867)
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get profileAi;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2078)
  ///
  /// In en, this message translates to:
  /// **'AI: local only'**
  String get profileAiLocalOnly;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1856)
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get profileAlcohol;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:653)
  ///
  /// In en, this message translates to:
  /// **'Alcohol use'**
  String get profileAlcoholUse;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:965)
  ///
  /// In en, this message translates to:
  /// **'Allergen'**
  String get profileAllergen;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:103)
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileAllergies;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1357)
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileAllergies2;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1387)
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileAllergies3;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:133)
  ///
  /// In en, this message translates to:
  /// **'Attiva'**
  String get profileAttiva;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:129)
  ///
  /// In en, this message translates to:
  /// **'Attivo'**
  String get profileAttivo;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:11)
  ///
  /// In en, this message translates to:
  /// **'Basilicata'**
  String get profileBasilicata;

  /// Input label text (lib/features/profile/presentation/family_profiles_screen.dart:266)
  ///
  /// In en, this message translates to:
  /// **'Biological sex'**
  String get profileBiologicalSex;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:545)
  ///
  /// In en, this message translates to:
  /// **'Biological sex'**
  String get profileBiologicalSex2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1842)
  ///
  /// In en, this message translates to:
  /// **'Birth'**
  String get profileBirth;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:12)
  ///
  /// In en, this message translates to:
  /// **'Calabria'**
  String get profileCalabria;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:13)
  ///
  /// In en, this message translates to:
  /// **'Campania'**
  String get profileCampania;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:52)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:55)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel10;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:411)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel11;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:219)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel2;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:307)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:399)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:855)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel5;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:988)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel6;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1060)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel7;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1174)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel8;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1259)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel9;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1577)
  ///
  /// In en, this message translates to:
  /// **'CD'**
  String get profileCd;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:379)
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get profileChooseDate;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1193)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary local reminder'**
  String get profileClindiaryLocalReminder;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:37)
  ///
  /// In en, this message translates to:
  /// **'Clinical'**
  String get profileClinical;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1679)
  ///
  /// In en, this message translates to:
  /// **'Clinical'**
  String get profileClinical2;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1341)
  ///
  /// In en, this message translates to:
  /// **'Clinical area'**
  String get profileClinicalArea;

  /// Title text (lib/features/profile/presentation/clinical_episodes_screen.dart:272)
  ///
  /// In en, this message translates to:
  /// **'Clinical issues'**
  String get profileClinicalIssues;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:45)
  ///
  /// In en, this message translates to:
  /// **'Complete authentication to view the profile.'**
  String get profileCompleteAuthenticationToViewTheProfile;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:50)
  ///
  /// In en, this message translates to:
  /// **'Complete onboarding to manage profiles.'**
  String get profileCompleteOnboardingToManageProfiles;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:284)
  ///
  /// In en, this message translates to:
  /// **'Complete the profile to manage clinical issues.'**
  String get profileCompleteTheProfileToManageClinical;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:113)
  ///
  /// In en, this message translates to:
  /// **'Complete the profile to manage vaccinations.'**
  String get profileCompleteTheProfileToManageVaccinations;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1251)
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get profileCondition;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1033)
  ///
  /// In en, this message translates to:
  /// **'Condition name'**
  String get profileConditionName;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:107)
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get profileConditions;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1352)
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get profileConditions2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:36)
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get profileContext;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:153)
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get profileContext2;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:766)
  ///
  /// In en, this message translates to:
  /// **'Current pregnancy'**
  String get profileCurrentPregnancy;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:377)
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get profileDate;

  /// Input label text (lib/features/profile/presentation/family_profiles_screen.dart:247)
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDateOfBirth;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:514)
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDateOfBirth2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1139)
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get profileDays;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:136)
  ///
  /// In en, this message translates to:
  /// **'dd/MM/yyyy'**
  String get profileDdMmYyyy;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:159)
  ///
  /// In en, this message translates to:
  /// **'dd/MM/yyyy'**
  String get profileDdMmYyyy2;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:182)
  ///
  /// In en, this message translates to:
  /// **'dd/MM/yyyy'**
  String get profileDdMmYyyy3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:18)
  ///
  /// In en, this message translates to:
  /// **'dd/MM/yyyy'**
  String get profileDdMmYyyy4;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:330)
  ///
  /// In en, this message translates to:
  /// **'dd/MM/yyyy'**
  String get profileDdMmYyyy5;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:268)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get profileDdMmmYyyy;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:22)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get profileDdMmmYyyy2;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:97)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get profileDdMmmYyyy3;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1115)
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get profileDosage;

  /// Input label text (lib/features/profile/presentation/vaccination_history_screen.dart:372)
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get profileDose;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:75)
  ///
  /// In en, this message translates to:
  /// **'Each profile has separate data, screenings, and recaps. Select the one to use now.'**
  String get profileEachProfileHasSeparateDataScreenings;

  /// Tooltip (lib/features/profile/presentation/clinical_episodes_screen.dart:337)
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:60)
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:159)
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit3;

  /// Tooltip (lib/features/profile/presentation/vaccination_history_screen.dart:192)
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit4;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:101)
  ///
  /// In en, this message translates to:
  /// **'Edit clinical issue'**
  String get profileEditClinicalIssue;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:350)
  ///
  /// In en, this message translates to:
  /// **'Edit vaccine'**
  String get profileEditVaccine;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:14)
  ///
  /// In en, this message translates to:
  /// **'Emilia-Romagna'**
  String get profileEmiliaRomagna;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:227)
  ///
  /// In en, this message translates to:
  /// **'Enter a title for the clinical issue.'**
  String get profileEnterATitleForTheClinical;

  /// Snackbar message (lib/features/profile/presentation/vaccination_history_screen.dart:307)
  ///
  /// In en, this message translates to:
  /// **'Enter the vaccine name.'**
  String get profileEnterTheVaccineName;

  /// Input hint text (lib/features/profile/presentation/vaccination_history_screen.dart:366)
  ///
  /// In en, this message translates to:
  /// **'Example: Influenza'**
  String get profileExampleInfluenza;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:787)
  ///
  /// In en, this message translates to:
  /// **'Falls in the last year'**
  String get profileFallsInTheLastYear;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1865)
  ///
  /// In en, this message translates to:
  /// **'Falls last year'**
  String get profileFallsLastYear;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1686)
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get profileFamily;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:116)
  ///
  /// In en, this message translates to:
  /// **'Family history'**
  String get profileFamilyHistory;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1362)
  ///
  /// In en, this message translates to:
  /// **'Family history'**
  String get profileFamilyHistory2;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1394)
  ///
  /// In en, this message translates to:
  /// **'Family history'**
  String get profileFamilyHistory3;

  /// Title text (lib/features/profile/presentation/family_profiles_screen.dart:26)
  ///
  /// In en, this message translates to:
  /// **'Family profiles'**
  String get profileFamilyProfiles;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:269)
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profileFemale;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:548)
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profileFemale2;

  /// Input label text (lib/features/profile/presentation/family_profiles_screen.dart:204)
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get profileFirstName;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:502)
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get profileFirstName2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1862)
  ///
  /// In en, this message translates to:
  /// **'Folate'**
  String get profileFolate;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:602)
  ///
  /// In en, this message translates to:
  /// **'Former smoker'**
  String get profileFormerSmoker;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2055)
  ///
  /// In en, this message translates to:
  /// **'Former smoker'**
  String get profileFormerSmoker2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1858)
  ///
  /// In en, this message translates to:
  /// **'Former smoking'**
  String get profileFormerSmoking;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1863)
  ///
  /// In en, this message translates to:
  /// **'Fractures'**
  String get profileFractures;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1120)
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get profileFrequency;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get profileFri;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:15)
  ///
  /// In en, this message translates to:
  /// **'Friuli Venezia Giulia'**
  String get profileFriuliVeneziaGiulia;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:723)
  ///
  /// In en, this message translates to:
  /// **'Functional limitations'**
  String get profileFunctionalLimitations;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:132)
  ///
  /// In en, this message translates to:
  /// **'Go straight to what you need:'**
  String get profileGoStraightToWhatYouNeed;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Habits, triggers, and limits used to add context.'**
  String get profileHabitsTriggersAndLimitsUsedTo;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1848)
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get profileHeight;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:564)
  ///
  /// In en, this message translates to:
  /// **'Height cm'**
  String get profileHeightCm;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:664)
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get profileHigh;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:773)
  ///
  /// In en, this message translates to:
  /// **'I take folate / folic acid'**
  String get profileITakeFolateFolicAcid;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1866)
  ///
  /// In en, this message translates to:
  /// **'Instability'**
  String get profileInstability;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:797)
  ///
  /// In en, this message translates to:
  /// **'Instability or fear of falling'**
  String get profileInstabilityOrFearOfFalling;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:273)
  ///
  /// In en, this message translates to:
  /// **'Intersex'**
  String get profileIntersex;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:552)
  ///
  /// In en, this message translates to:
  /// **'Intersex'**
  String get profileIntersex2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1678)
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get profileIssues;

  /// Title text (lib/features/profile/presentation/clinical_episodes_screen.dart:297)
  ///
  /// In en, this message translates to:
  /// **'Issues and episodes'**
  String get profileIssuesAndEpisodes;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:9)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get profileIt;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:175)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get profileIt2;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:297)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get profileIt3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:475)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get profileIt4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:685)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get profileIt5;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:10)
  ///
  /// In en, this message translates to:
  /// **'IT-ABR'**
  String get profileItAbr;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:11)
  ///
  /// In en, this message translates to:
  /// **'IT-BAS'**
  String get profileItBas;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:12)
  ///
  /// In en, this message translates to:
  /// **'IT-CAL'**
  String get profileItCal;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:13)
  ///
  /// In en, this message translates to:
  /// **'IT-CAM'**
  String get profileItCam;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:14)
  ///
  /// In en, this message translates to:
  /// **'IT-EMR'**
  String get profileItEmr;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:15)
  ///
  /// In en, this message translates to:
  /// **'IT-FVG'**
  String get profileItFvg;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:16)
  ///
  /// In en, this message translates to:
  /// **'IT-LAZ'**
  String get profileItLaz;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:17)
  ///
  /// In en, this message translates to:
  /// **'IT-LIG'**
  String get profileItLig;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:18)
  ///
  /// In en, this message translates to:
  /// **'IT-LOM'**
  String get profileItLom;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:19)
  ///
  /// In en, this message translates to:
  /// **'IT-MAR'**
  String get profileItMar;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:20)
  ///
  /// In en, this message translates to:
  /// **'IT-MOL'**
  String get profileItMol;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:21)
  ///
  /// In en, this message translates to:
  /// **'IT-PIE'**
  String get profileItPie;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:22)
  ///
  /// In en, this message translates to:
  /// **'IT-PUG'**
  String get profileItPug;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:23)
  ///
  /// In en, this message translates to:
  /// **'IT-SAR'**
  String get profileItSar;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:24)
  ///
  /// In en, this message translates to:
  /// **'IT-SIC'**
  String get profileItSic;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:26)
  ///
  /// In en, this message translates to:
  /// **'IT-TAA'**
  String get profileItTaa;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:25)
  ///
  /// In en, this message translates to:
  /// **'IT-TOS'**
  String get profileItTos;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:27)
  ///
  /// In en, this message translates to:
  /// **'IT-UMB'**
  String get profileItUmb;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:28)
  ///
  /// In en, this message translates to:
  /// **'IT-VDA'**
  String get profileItVda;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:29)
  ///
  /// In en, this message translates to:
  /// **'IT-VEN'**
  String get profileItVen;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:9)
  ///
  /// In en, this message translates to:
  /// **'Italia (generale)'**
  String get profileItaliaGenerale;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1380)
  ///
  /// In en, this message translates to:
  /// **'Known conditions'**
  String get profileKnownConditions;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:715)
  ///
  /// In en, this message translates to:
  /// **'Known symptom triggers'**
  String get profileKnownSymptomTriggers;

  /// Input label text (lib/features/profile/presentation/family_profiles_screen.dart:210)
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get profileLastName;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:507)
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get profileLastName2;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:16)
  ///
  /// In en, this message translates to:
  /// **'Lazio'**
  String get profileLazio;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:622)
  ///
  /// In en, this message translates to:
  /// **'Leave blank if still smoking or not applicable.'**
  String get profileLeaveBlankIfStillSmokingOr;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:637)
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileLight;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:17)
  ///
  /// In en, this message translates to:
  /// **'Liguria'**
  String get profileLiguria;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1791)
  ///
  /// In en, this message translates to:
  /// **'Limitations'**
  String get profileLimitations;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1867)
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get profileLocalOnly;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:18)
  ///
  /// In en, this message translates to:
  /// **'Lombardia'**
  String get profileLombardia;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:270)
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profileMale;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:549)
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profileMale2;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:19)
  ///
  /// In en, this message translates to:
  /// **'Marche'**
  String get profileMarche;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1109)
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get profileMedicationName;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:972)
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get profileMild;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:640)
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get profileModerate;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:662)
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get profileModerate2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:975)
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get profileModerate3;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:20)
  ///
  /// In en, this message translates to:
  /// **'Molise'**
  String get profileMolise;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get profileMon;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:120)
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get profileMonitoring;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1044)
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get profileMonitoring2;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:838)
  ///
  /// In en, this message translates to:
  /// **'MSM context / sex between men'**
  String get profileMsmContextSexBetweenMen;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:513)
  ///
  /// In en, this message translates to:
  /// **'Name, date, dose and next booster stay together here.'**
  String get profileNameDateDoseAndNextBooster;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:958)
  ///
  /// In en, this message translates to:
  /// **'New allergy'**
  String get profileNewAllergy;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:101)
  ///
  /// In en, this message translates to:
  /// **'New clinical issue'**
  String get profileNewClinicalIssue;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1025)
  ///
  /// In en, this message translates to:
  /// **'New condition'**
  String get profileNewCondition;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1239)
  ///
  /// In en, this message translates to:
  /// **'New family history'**
  String get profileNewFamilyHistory;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1100)
  ///
  /// In en, this message translates to:
  /// **'New medication'**
  String get profileNewMedication;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:824)
  ///
  /// In en, this message translates to:
  /// **'New or multiple partners'**
  String get profileNewOrMultiplePartners;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:42)
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profileNewProfile;

  /// Title text (lib/features/profile/presentation/family_profiles_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profileNewProfile2;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:386)
  ///
  /// In en, this message translates to:
  /// **'Next booster'**
  String get profileNextBooster;

  /// Title text (lib/features/profile/presentation/clinical_episodes_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'Next review'**
  String get profileNextReview;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1857)
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get profileNo;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1388)
  ///
  /// In en, this message translates to:
  /// **'No allergy recorded.'**
  String get profileNoAllergyRecorded;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1374)
  ///
  /// In en, this message translates to:
  /// **'No chronic medication recorded.'**
  String get profileNoChronicMedicationRecorded;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:304)
  ///
  /// In en, this message translates to:
  /// **'No clinical issue recorded.'**
  String get profileNoClinicalIssueRecorded;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1381)
  ///
  /// In en, this message translates to:
  /// **'No condition recorded.'**
  String get profileNoConditionRecorded;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1164)
  ///
  /// In en, this message translates to:
  /// **'No day selected: ClinDiary treats the reminder as daily.'**
  String get profileNoDaySelectedClindiaryTreatsThe;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1395)
  ///
  /// In en, this message translates to:
  /// **'No family history recorded.'**
  String get profileNoFamilyHistoryRecorded;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:94)
  ///
  /// In en, this message translates to:
  /// **'No profile selected'**
  String get profileNoProfileSelected;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:159)
  ///
  /// In en, this message translates to:
  /// **'No vaccination recorded.'**
  String get profileNoVaccinationRecorded;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:133)
  ///
  /// In en, this message translates to:
  /// **'No vaccination summary available.'**
  String get profileNoVaccinationSummaryAvailable;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:655)
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get profileNone;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:813)
  ///
  /// In en, this message translates to:
  /// **'Not active'**
  String get profileNotActive;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:135)
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:158)
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet2;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:181)
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet3;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:277)
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get profileNotSpecified;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:556)
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get profileNotSpecified2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1910)
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get profileNotSpecified3;

  /// Input label text (lib/features/profile/presentation/clinical_episodes_screen.dart:209)
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get profileNote;

  /// Input label text (lib/features/profile/presentation/vaccination_history_screen.dart:402)
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get profileNote2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:658)
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get profileOccasional;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1861)
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get profileOngoing;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:357)
  ///
  /// In en, this message translates to:
  /// **'Only the name is required. You can add dates later.'**
  String get profileOnlyTheNameIsRequiredYou;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1342)
  ///
  /// In en, this message translates to:
  /// **'Open only the section you need.'**
  String get profileOpenOnlyTheSectionYouNeed;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:388)
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get profileOptional;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:805)
  ///
  /// In en, this message translates to:
  /// **'Optional data used only for personalized STI prevention.'**
  String get profileOptionalDataUsedOnlyForPersonalized;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1852)
  ///
  /// In en, this message translates to:
  /// **'Pack-years'**
  String get profilePackYears;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:831)
  ///
  /// In en, this message translates to:
  /// **'Partner with known STI'**
  String get profilePartnerWithKnownSti;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:316)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:204)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync10;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:349)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:174)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:190)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:210)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync5;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:227)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync6;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1506)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync7;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1518)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync8;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:171)
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get profilePendingSync9;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:21)
  ///
  /// In en, this message translates to:
  /// **'Piemonte'**
  String get profilePiemonte;

  /// Input label text (lib/features/profile/presentation/vaccination_history_screen.dart:396)
  ///
  /// In en, this message translates to:
  /// **'Place or doctor'**
  String get profilePlaceOrDoctor;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:742)
  ///
  /// In en, this message translates to:
  /// **'Post-menopause'**
  String get profilePostMenopause;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1859)
  ///
  /// In en, this message translates to:
  /// **'Post-menopause'**
  String get profilePostMenopause2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1860)
  ///
  /// In en, this message translates to:
  /// **'Preconception'**
  String get profilePreconception;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2073)
  ///
  /// In en, this message translates to:
  /// **'Preconception active'**
  String get profilePreconceptionActive;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:810)
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get profilePreferNotToSay;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1861)
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get profilePregnancy;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2076)
  ///
  /// In en, this message translates to:
  /// **'Pregnancy ongoing'**
  String get profilePregnancyOngoing;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1863)
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get profilePrevious;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:781)
  ///
  /// In en, this message translates to:
  /// **'Previous fragility fracture'**
  String get profilePreviousFragilityFracture;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:397)
  ///
  /// In en, this message translates to:
  /// **'Primary profile'**
  String get profilePrimaryProfile;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1695)
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacy;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:24)
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileProfile;

  /// Title text (lib/features/profile/presentation/family_profiles_screen.dart:104)
  ///
  /// In en, this message translates to:
  /// **'Profile list'**
  String get profileProfileList;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:22)
  ///
  /// In en, this message translates to:
  /// **'Puglia'**
  String get profilePuglia;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:140)
  ///
  /// In en, this message translates to:
  /// **'Quick facts'**
  String get profileQuickFacts;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:152)
  ///
  /// In en, this message translates to:
  /// **'Recorded vaccinations'**
  String get profileRecordedVaccinations;

  /// Input label text (lib/features/profile/presentation/family_profiles_screen.dart:287)
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get profileRegion;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1846)
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get profileRegion2;

  /// Input label text (lib/features/profile/presentation/family_profiles_screen.dart:217)
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get profileRelationship;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1246)
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get profileRelationship2;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1125)
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get profileReminderTime;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:57)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileRemove;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:350)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileRemove2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:403)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileRemove3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1519)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileRemove4;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:60)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileRemove5;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:205)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileRemove6;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:276)
  ///
  /// In en, this message translates to:
  /// **'Remove allergy?'**
  String get profileRemoveAllergy;

  /// Title text (lib/features/profile/presentation/clinical_episodes_screen.dart:46)
  ///
  /// In en, this message translates to:
  /// **'Remove clinical issue?'**
  String get profileRemoveClinicalIssue;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:300)
  ///
  /// In en, this message translates to:
  /// **'Remove condition?'**
  String get profileRemoveCondition;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:367)
  ///
  /// In en, this message translates to:
  /// **'Remove family history?'**
  String get profileRemoveFamilyHistory;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:324)
  ///
  /// In en, this message translates to:
  /// **'Remove medication?'**
  String get profileRemoveMedication;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:47)
  ///
  /// In en, this message translates to:
  /// **'Remove vaccination?'**
  String get profileRemoveVaccination;

  /// Title text (lib/features/profile/presentation/clinical_episodes_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Resolution date'**
  String get profileResolutionDate;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:124)
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get profileResolved;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1048)
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get profileResolved2;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:23)
  ///
  /// In en, this message translates to:
  /// **'Sardegna'**
  String get profileSardegna;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get profileSat;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:252)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:357)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:939)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1006)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1078)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave5;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1221)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave6;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1277)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave7;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:418)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave8;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:672)
  ///
  /// In en, this message translates to:
  /// **'Screening region'**
  String get profileScreeningRegion;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:635)
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get profileSedentary;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:288)
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get profileSelectDate;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:234)
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get profileSelectDateOfBirth;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:529)
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get profileSelectDateOfBirth2;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:288)
  ///
  /// In en, this message translates to:
  /// **'Select next booster'**
  String get profileSelectNextBooster;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:191)
  ///
  /// In en, this message translates to:
  /// **'Select next review'**
  String get profileSelectNextReview;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:168)
  ///
  /// In en, this message translates to:
  /// **'Select resolution date'**
  String get profileSelectResolutionDate;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:145)
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get profileSelectStartDate;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:399)
  ///
  /// In en, this message translates to:
  /// **'Separate clinical profile'**
  String get profileSeparateClinicalProfile;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1694)
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileSetupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Profile setup in progress'**
  String get profileSetupInProgress;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:977)
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get profileSevere;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:970)
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get profileSeverity;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1844)
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get profileSex;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:803)
  ///
  /// In en, this message translates to:
  /// **'Sexual activity'**
  String get profileSexualActivity;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:24)
  ///
  /// In en, this message translates to:
  /// **'Sicilia'**
  String get profileSicilia;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1788)
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get profileSleep;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:588)
  ///
  /// In en, this message translates to:
  /// **'Smoker'**
  String get profileSmoker;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2052)
  ///
  /// In en, this message translates to:
  /// **'Smoker'**
  String get profileSmoker2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1857)
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get profileSmoking;

  /// Input hint text (lib/features/profile/presentation/family_profiles_screen.dart:218)
  ///
  /// In en, this message translates to:
  /// **'Son, daughter, mother, father...'**
  String get profileSonDaughterMotherFather;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1787)
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get profileSport;

  /// Title text (lib/features/profile/presentation/clinical_episodes_screen.dart:132)
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get profileStartDate;

  /// Input label text (lib/features/profile/presentation/clinical_episodes_screen.dart:115)
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatus;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:1039)
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatus2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:35)
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get profileSummary;

  /// Input label text (lib/features/profile/presentation/clinical_episodes_screen.dart:202)
  ///
  /// In en, this message translates to:
  /// **'Summary / description'**
  String get profileSummaryDescription;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:131)
  ///
  /// In en, this message translates to:
  /// **'Summary status derived from history.'**
  String get profileSummaryStatusDerivedFromHistory;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get profileSun;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:846)
  ///
  /// In en, this message translates to:
  /// **'Symptoms or STI exposures to discuss'**
  String get profileSymptomsOrStiExposuresToDiscuss;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1868)
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get profileSync;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2080)
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get profileSyncPending;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:238)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:241)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT2;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:245)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT3;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:240)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT4;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:423)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT5;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:535)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT6;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:313)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT7;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:317)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get profileT8;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1862)
  ///
  /// In en, this message translates to:
  /// **'Taking'**
  String get profileTaking;

  /// Input hint text (lib/features/profile/presentation/family_profiles_screen.dart:248)
  ///
  /// In en, this message translates to:
  /// **'Tap to pick'**
  String get profileTapToPick;

  /// User-facing UI text (lib/features/profile/presentation/family_profiles_screen.dart:256)
  ///
  /// In en, this message translates to:
  /// **'Tap to pick'**
  String get profileTapToPick2;

  /// Input hint text (lib/features/profile/presentation/profile_screen.dart:515)
  ///
  /// In en, this message translates to:
  /// **'Tap to pick'**
  String get profileTapToPick3;

  /// User-facing UI text (lib/features/profile/presentation/clinical_episodes_screen.dart:47)
  ///
  /// In en, this message translates to:
  /// **'The item will be removed from the dossier.'**
  String get profileTheItemWillBeRemovedFrom;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:277)
  ///
  /// In en, this message translates to:
  /// **'The item will be removed from the clinical profile.'**
  String get profileTheItemWillBeRemovedFrom2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:301)
  ///
  /// In en, this message translates to:
  /// **'The item will be removed from the clinical profile.'**
  String get profileTheItemWillBeRemovedFrom3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:368)
  ///
  /// In en, this message translates to:
  /// **'The item will be removed from the clinical profile.'**
  String get profileTheItemWillBeRemovedFrom4;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:49)
  ///
  /// In en, this message translates to:
  /// **'The item will be removed from the vaccination history.'**
  String get profileTheItemWillBeRemovedFrom5;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:325)
  ///
  /// In en, this message translates to:
  /// **'The medication and its linked local schedules will be removed.'**
  String get profileTheMedicationAndItsLinkedLocal;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get profileThu;

  /// Input label text (lib/features/profile/presentation/clinical_episodes_screen.dart:110)
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get profileTitle;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:549)
  ///
  /// In en, this message translates to:
  /// **'to do'**
  String get profileToDo;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1866)
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get profileToReview;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:551)
  ///
  /// In en, this message translates to:
  /// **'to review'**
  String get profileToReview2;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:608)
  ///
  /// In en, this message translates to:
  /// **'Tobacco pack-years'**
  String get profileTobaccoPackYears;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:25)
  ///
  /// In en, this message translates to:
  /// **'Toscana'**
  String get profileToscana;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:26)
  ///
  /// In en, this message translates to:
  /// **'Trentino-Alto Adige/Südtirol'**
  String get profileTrentinoAltoAdigeSDtirol;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1790)
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get profileTrigger;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:754)
  ///
  /// In en, this message translates to:
  /// **'Trying to conceive'**
  String get profileTryingToConceive;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get profileTue;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:27)
  ///
  /// In en, this message translates to:
  /// **'Umbria'**
  String get profileUmbria;

  /// User-facing UI text (lib/features/profile/presentation/vaccination_history_screen.dart:548)
  ///
  /// In en, this message translates to:
  /// **'up to date'**
  String get profileUpToDate;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:494)
  ///
  /// In en, this message translates to:
  /// **'Update profile'**
  String get profileUpdateProfile;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:788)
  ///
  /// In en, this message translates to:
  /// **'Used for fall risk and functional prevention.'**
  String get profileUsedForFallRiskAndFunctional;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:674)
  ///
  /// In en, this message translates to:
  /// **'Used to show screening, prevention, and local notifications.'**
  String get profileUsedToShowScreeningPreventionAnd;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:610)
  ///
  /// In en, this message translates to:
  /// **'Useful for lung and aortic aneurysm screening.'**
  String get profileUsefulForLungAndAorticAneurysm;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:691)
  ///
  /// In en, this message translates to:
  /// **'Usual exercise or physical activity'**
  String get profileUsualExerciseOrPhysicalActivity;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:699)
  ///
  /// In en, this message translates to:
  /// **'Usual sleep pattern'**
  String get profileUsualSleepPattern;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:101)
  ///
  /// In en, this message translates to:
  /// **'Vaccination history'**
  String get profileVaccinationHistory;

  /// Title text (lib/features/profile/presentation/vaccination_history_screen.dart:130)
  ///
  /// In en, this message translates to:
  /// **'Vaccination registry'**
  String get profileVaccinationRegistry;

  /// Input label text (lib/features/profile/presentation/vaccination_history_screen.dart:365)
  ///
  /// In en, this message translates to:
  /// **'Vaccine name'**
  String get profileVaccineName;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1670)
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get profileVaccines;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:28)
  ///
  /// In en, this message translates to:
  /// **'Valle d\'\'Aosta'**
  String get profileValleDAosta;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:141)
  ///
  /// In en, this message translates to:
  /// **'Values and settings used in recaps.'**
  String get profileValuesAndSettingsUsedInRecaps;

  /// User-facing UI text (lib/features/profile/domain/italian_regions.dart:29)
  ///
  /// In en, this message translates to:
  /// **'Veneto'**
  String get profileVeneto;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:645)
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get profileVeryActive;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:2008)
  ///
  /// In en, this message translates to:
  /// **'very active'**
  String get profileVeryActive2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1996)
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get profileWed;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1850)
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get profileWeight;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:572)
  ///
  /// In en, this message translates to:
  /// **'Weight kg'**
  String get profileWeightKg;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1789)
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get profileWork;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:707)
  ///
  /// In en, this message translates to:
  /// **'Work or daily context'**
  String get profileWorkOrDailyContext;

  /// Input label text (lib/features/profile/presentation/profile_screen.dart:620)
  ///
  /// In en, this message translates to:
  /// **'Years since quitting'**
  String get profileYearsSinceQuitting;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1857)
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileYes;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1858)
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileYes2;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:1859)
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileYes3;

  /// User-facing UI text (lib/features/profile/presentation/profile_screen.dart:82)
  ///
  /// In en, this message translates to:
  /// **'Your clinical profile starts here.'**
  String get profileYourClinicalProfileStartsHere;

  /// Title text (lib/features/profile/presentation/profile_screen.dart:1687)
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// User-facing UI text (lib/app/providers.dart:86)
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get providersIt;

  /// User-facing UI text (lib/app/providers.dart:111)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile;

  /// User-facing UI text (lib/app/providers.dart:496)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile10;

  /// User-facing UI text (lib/app/providers.dart:123)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile2;

  /// User-facing UI text (lib/app/providers.dart:135)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile3;

  /// User-facing UI text (lib/app/providers.dart:150)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile4;

  /// User-facing UI text (lib/app/providers.dart:184)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile5;

  /// User-facing UI text (lib/app/providers.dart:244)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile6;

  /// User-facing UI text (lib/app/providers.dart:259)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile7;

  /// User-facing UI text (lib/app/providers.dart:319)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile'**
  String get providersSessioneNonDisponibile8;

  /// User-facing UI text (lib/app/providers.dart:374)
  ///
  /// In en, this message translates to:
  /// **'Sessione non disponibile.'**
  String get providersSessioneNonDisponibile9;

  /// No description provided for @redirectingToLogin.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to sign in...'**
  String get redirectingToLogin;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String registrationFailed(Object error);

  /// User-facing UI text (lib/features/dossier/presentation/health_dossier_screen.dart:443)
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:111)
  ///
  /// In en, this message translates to:
  /// **'AI reports are used to organize information and clinical trends. They are not equivalent to a medical assessment or prescription.'**
  String get reportsAiReportsAreUsedToOrganize;

  /// Title text (lib/features/reports/presentation/reports_screen.dart:117)
  ///
  /// In en, this message translates to:
  /// **'Choose the period and create an ordered report.'**
  String get reportsChooseThePeriodAndCreateAn;

  /// Title text (lib/features/reports/presentation/reports_screen.dart:95)
  ///
  /// In en, this message translates to:
  /// **'Clinical reports'**
  String get reportsClinicalReports;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:76)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy, HH:mm'**
  String get reportsDdMmmYyyyHhMm;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:98)
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get reportsGenerate;

  /// Title text (lib/features/reports/presentation/reports_screen.dart:116)
  ///
  /// In en, this message translates to:
  /// **'Generate report'**
  String get reportsGenerateReport;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get reportsGenerating;

  /// Title text (lib/features/reports/presentation/reports_screen.dart:109)
  ///
  /// In en, this message translates to:
  /// **'Informational report'**
  String get reportsInformationalReport;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:99)
  ///
  /// In en, this message translates to:
  /// **'Latest report'**
  String get reportsLatestReport;

  /// Title text (lib/features/reports/presentation/reports_screen.dart:220)
  ///
  /// In en, this message translates to:
  /// **'Latest report'**
  String get reportsLatestReport2;

  /// Title text (lib/features/reports/presentation/reports_screen.dart:169)
  ///
  /// In en, this message translates to:
  /// **'Latest report available for the active profile.'**
  String get reportsLatestReportAvailableForTheActive;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:133)
  ///
  /// In en, this message translates to:
  /// **'Monthly recap'**
  String get reportsMonthlyRecap;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:237)
  ///
  /// In en, this message translates to:
  /// **'Monthly recap'**
  String get reportsMonthlyRecap2;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:175)
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get reportsOpenPdf;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:141)
  ///
  /// In en, this message translates to:
  /// **'Prevention status'**
  String get reportsPreventionStatus;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:241)
  ///
  /// In en, this message translates to:
  /// **'Prevention status'**
  String get reportsPreventionStatus2;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Regenerate report'**
  String get reportsRegenerateReport;

  /// Input label text (lib/features/reports/presentation/reports_screen.dart:124)
  ///
  /// In en, this message translates to:
  /// **'Report type'**
  String get reportsReportType;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:189)
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get reportsT;

  /// Snackbar message (lib/features/reports/presentation/reports_screen.dart:69)
  ///
  /// In en, this message translates to:
  /// **'Unable to open the report.'**
  String get reportsUnableToOpenTheReport;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:137)
  ///
  /// In en, this message translates to:
  /// **'Visit preparation'**
  String get reportsVisitPreparation;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:239)
  ///
  /// In en, this message translates to:
  /// **'Visit preparation'**
  String get reportsVisitPreparation2;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:129)
  ///
  /// In en, this message translates to:
  /// **'Weekly recap'**
  String get reportsWeeklyRecap;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:243)
  ///
  /// In en, this message translates to:
  /// **'Weekly recap'**
  String get reportsWeeklyRecap2;

  /// User-facing UI text (lib/features/reports/presentation/reports_screen.dart:222)
  ///
  /// In en, this message translates to:
  /// **'You have not generated a report for this profile yet.'**
  String get reportsYouHaveNotGeneratedAReport;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// User-facing UI text (lib/shared/widgets/root_shell.dart:32)
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get rootShellAi;

  /// User-facing UI text (lib/shared/widgets/root_shell.dart:321)
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get rootShellAi2;

  /// User-facing UI text (lib/shared/widgets/root_shell.dart:27)
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get rootShellCheckIn;

  /// User-facing UI text (lib/shared/widgets/root_shell.dart:38)
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get rootShellFiles;

  /// User-facing UI text (lib/shared/widgets/root_shell.dart:22)
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get rootShellHome;

  /// User-facing UI text (lib/shared/widgets/root_shell.dart:43)
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get rootShellProfile;

  /// User-facing UI text (lib/app/router.dart:260)
  ///
  /// In en, this message translates to:
  /// **'documentId'**
  String get routerDocumentid;

  /// User-facing UI text (lib/app/router.dart:298)
  ///
  /// In en, this message translates to:
  /// **':documentId'**
  String get routerDocumentid2;

  /// User-facing UI text (lib/app/router.dart:300)
  ///
  /// In en, this message translates to:
  /// **'documentId'**
  String get routerDocumentid3;

  /// User-facing UI text (lib/app/router.dart:306)
  ///
  /// In en, this message translates to:
  /// **'documentId'**
  String get routerDocumentid4;

  /// User-facing UI text (lib/app/router.dart:245)
  ///
  /// In en, this message translates to:
  /// **'entryId'**
  String get routerEntryid;

  /// User-facing UI text (lib/app/router.dart:243)
  ///
  /// In en, this message translates to:
  /// **':entryId/symptom'**
  String get routerEntryidSymptom;

  /// User-facing UI text (lib/app/router.dart:276)
  ///
  /// In en, this message translates to:
  /// **'folderId'**
  String get routerFolderid;

  /// User-facing UI text (lib/app/router.dart:291)
  ///
  /// In en, this message translates to:
  /// **'folderId'**
  String get routerFolderid2;

  /// User-facing UI text (lib/app/router.dart:278)
  ///
  /// In en, this message translates to:
  /// **'folderName'**
  String get routerFoldername;

  /// User-facing UI text (lib/app/router.dart:293)
  ///
  /// In en, this message translates to:
  /// **'folderName'**
  String get routerFoldername2;

  /// User-facing UI text (lib/app/router.dart:236)
  ///
  /// In en, this message translates to:
  /// **'sourceEntryId'**
  String get routerSourceentryid;

  /// User-facing UI text (lib/app/router.dart:238)
  ///
  /// In en, this message translates to:
  /// **'sourceSymptomId'**
  String get routerSourcesymptomid;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:619)
  ///
  /// In en, this message translates to:
  /// **'All available catalog items.'**
  String get screeningsAllAvailableCatalogItems;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:138)
  ///
  /// In en, this message translates to:
  /// **'Annual visit, checks, and useful notes.'**
  String get screeningsAnnualVisitChecksAndUsefulNotes;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:401)
  ///
  /// In en, this message translates to:
  /// **'Areas where a clinician discussion matters.'**
  String get screeningsAreasWhereAClinicianDiscussionMatters;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:144)
  ///
  /// In en, this message translates to:
  /// **'Checks adapted to the profile and region.'**
  String get screeningsChecksAdaptedToTheProfileAnd;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:838)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary stays cautious here: the purpose of the check depends on a shared decision, not a strong automatic reminder.'**
  String get screeningsClindiaryStaysCautiousHereThePurpose;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:189)
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get screeningsCompleted;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:564)
  ///
  /// In en, this message translates to:
  /// **'Copertura pubblica'**
  String get screeningsCoperturaPubblica;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:528)
  ///
  /// In en, this message translates to:
  /// **'Da definire'**
  String get screeningsDaDefinire;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:21)
  ///
  /// In en, this message translates to:
  /// **'dd MMM'**
  String get screeningsDdMmm;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:17)
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get screeningsDdMmmYyyy;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:160)
  ///
  /// In en, this message translates to:
  /// **'For your profile'**
  String get screeningsForYourProfile;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:164)
  ///
  /// In en, this message translates to:
  /// **'For your profile'**
  String get screeningsForYourProfile2;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:305)
  ///
  /// In en, this message translates to:
  /// **'For your profile'**
  String get screeningsForYourProfile3;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:311)
  ///
  /// In en, this message translates to:
  /// **'For your profile'**
  String get screeningsForYourProfile4;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:172)
  ///
  /// In en, this message translates to:
  /// **'Full catalog'**
  String get screeningsFullCatalog;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:176)
  ///
  /// In en, this message translates to:
  /// **'Full catalog'**
  String get screeningsFullCatalog2;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:618)
  ///
  /// In en, this message translates to:
  /// **'Full catalog'**
  String get screeningsFullCatalog3;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:342)
  ///
  /// In en, this message translates to:
  /// **'General check.'**
  String get screeningsGeneralCheck;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:379)
  ///
  /// In en, this message translates to:
  /// **'Gia registrati'**
  String get screeningsGiaRegistrati;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:842)
  ///
  /// In en, this message translates to:
  /// **'Here you will find specific tests and checks to evaluate with the doctor based on the profile.'**
  String get screeningsHereYouWillFindSpecificTests;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:590)
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get screeningsMarkCompleted;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:199)
  ///
  /// In en, this message translates to:
  /// **'Never done'**
  String get screeningsNeverDone;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:306)
  ///
  /// In en, this message translates to:
  /// **'No personalized checks to show.'**
  String get screeningsNoPersonalizedChecksToShow;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:799)
  ///
  /// In en, this message translates to:
  /// **'Not routine'**
  String get screeningsNotRoutine;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:827)
  ///
  /// In en, this message translates to:
  /// **'Not routine'**
  String get screeningsNotRoutine2;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:191)
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get screeningsOverdue;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:137)
  ///
  /// In en, this message translates to:
  /// **'Prevention catalog'**
  String get screeningsPreventionCatalog;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:578)
  ///
  /// In en, this message translates to:
  /// **'Raccomandazione disponibile.'**
  String get screeningsRaccomandazioneDisponibile;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:142)
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get screeningsRecalculate;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:195)
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get screeningsRecommended;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:341)
  ///
  /// In en, this message translates to:
  /// **'Recommended annual visit'**
  String get screeningsRecommendedAnnualVisit;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:823)
  ///
  /// In en, this message translates to:
  /// **'Recommended annual visit'**
  String get screeningsRecommendedAnnualVisit2;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:801)
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get screeningsRoutine;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:590)
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get screeningsSaving;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:193)
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get screeningsScheduled;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:400)
  ///
  /// In en, this message translates to:
  /// **'Shared decisions'**
  String get screeningsSharedDecisions;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:825)
  ///
  /// In en, this message translates to:
  /// **'Shared decisions'**
  String get screeningsSharedDecisions2;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:197)
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get screeningsSkipped;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:705)
  ///
  /// In en, this message translates to:
  /// **'Solo informativo'**
  String get screeningsSoloInformativo;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:360)
  ///
  /// In en, this message translates to:
  /// **'Tests and checks to discuss with the doctor'**
  String get screeningsTestsAndChecksToDiscussWith;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:829)
  ///
  /// In en, this message translates to:
  /// **'Tests and checks to discuss with the doctor'**
  String get screeningsTestsAndChecksToDiscussWith2;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:836)
  ///
  /// In en, this message translates to:
  /// **'The annual general check helps organize prevention, lifestyle, and clinical priorities.'**
  String get screeningsTheAnnualGeneralCheckHelpsOrganize;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:840)
  ///
  /// In en, this message translates to:
  /// **'These items remain informational and should not be proposed as routine for asymptomatic users.'**
  String get screeningsTheseItemsRemainInformationalAndShould;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:797)
  ///
  /// In en, this message translates to:
  /// **'To evaluate'**
  String get screeningsToEvaluate;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:361)
  ///
  /// In en, this message translates to:
  /// **'To evaluate together.'**
  String get screeningsToEvaluateTogether;

  /// User-facing UI text (lib/features/screenings/presentation/screenings_screen.dart:142)
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get screeningsUpdating;

  /// Title text (lib/features/screenings/presentation/screenings_screen.dart:312)
  ///
  /// In en, this message translates to:
  /// **'What matters now.'**
  String get screeningsWhatMattersNow;

  /// No description provided for @secondaryTools.
  ///
  /// In en, this message translates to:
  /// **'Secondary Tools'**
  String get secondaryTools;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:192)
  ///
  /// In en, this message translates to:
  /// **'A small example of the current look.'**
  String get settingsASmallExampleOfTheCurrent;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:382)
  ///
  /// In en, this message translates to:
  /// **'Account control'**
  String get settingsAccountControl;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:103)
  ///
  /// In en, this message translates to:
  /// **'Adjust the overall readability.'**
  String get settingsAdjustTheOverallReadability;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:203)
  ///
  /// In en, this message translates to:
  /// **'AI note'**
  String get settingsAiNote;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:177)
  ///
  /// In en, this message translates to:
  /// **'All AI processing stays on your device.'**
  String get settingsAllAiProcessingStaysOnYour;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:154)
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// Snackbar message (lib/features/settings/presentation/app_settings_screen.dart:423)
  ///
  /// In en, this message translates to:
  /// **'App lock disabled.'**
  String get settingsAppLockDisabled;

  /// Snackbar message (lib/features/settings/presentation/app_settings_screen.dart:380)
  ///
  /// In en, this message translates to:
  /// **'App lock enabled.'**
  String get settingsAppLockEnabled;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:65)
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:352)
  ///
  /// In en, this message translates to:
  /// **'Backup JSON'**
  String get settingsBackupJson;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:406)
  ///
  /// In en, this message translates to:
  /// **'Before production, a full legal review is still required for privacy, DPIA, DPA, and extra-EU transfers.'**
  String get settingsBeforeProductionAFullLegalReview;

  /// Title text (lib/features/settings/presentation/legal_document_screen.dart:13)
  ///
  /// In en, this message translates to:
  /// **'Beta AI note'**
  String get settingsBetaAiNote;

  /// Title text (lib/features/settings/presentation/legal_center_screen.dart:17)
  ///
  /// In en, this message translates to:
  /// **'Beta documents'**
  String get settingsBetaDocuments;

  /// Title text (lib/features/settings/presentation/legal_document_screen.dart:18)
  ///
  /// In en, this message translates to:
  /// **'Beta portability and retention'**
  String get settingsBetaPortabilityAndRetention;

  /// Title text (lib/features/settings/presentation/legal_document_screen.dart:8)
  ///
  /// In en, this message translates to:
  /// **'Beta privacy notice'**
  String get settingsBetaPrivacyNotice;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:349)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:405)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel2;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:112)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel3;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:285)
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsChangePin;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:34)
  ///
  /// In en, this message translates to:
  /// **'Choose the app language.'**
  String get settingsChooseTheAppLanguage;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:66)
  ///
  /// In en, this message translates to:
  /// **'Choose the app theme.'**
  String get settingsChooseTheAppTheme;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:363)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary emergency card'**
  String get settingsClindiaryEmergencyCard;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:364)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary emergency card'**
  String get settingsClindiaryEmergencyCard2;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:329)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary health dossier'**
  String get settingsClindiaryHealthDossier;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:330)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary health dossier'**
  String get settingsClindiaryHealthDossier2;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:346)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary structured backup'**
  String get settingsClindiaryStructuredBackup;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:347)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary structured backup'**
  String get settingsClindiaryStructuredBackup2;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:400)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary will no longer ask for PIN or biometrics on this device.'**
  String get settingsClindiaryWillNoLongerAskFor;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:225)
  ///
  /// In en, this message translates to:
  /// **'Clinical context'**
  String get settingsClinicalContext;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:140)
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsCompact;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:429)
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsCompact2;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:25)
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in to manage settings.'**
  String get settingsCompleteSignInToManageSettings;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:168)
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in to manage settings.'**
  String get settingsCompleteSignInToManageSettings2;

  /// Input label text (lib/features/settings/presentation/app_settings_screen.dart:340)
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get settingsConfirmPin;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:85)
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// User-facing UI text (lib/features/settings/presentation/legal_document_screen.dart:10)
  ///
  /// In en, this message translates to:
  /// **'Data handling and product structure.'**
  String get settingsDataHandlingAndProductStructure;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:304)
  ///
  /// In en, this message translates to:
  /// **'Data portability'**
  String get settingsDataPortability;

  /// Input hint text (lib/features/settings/presentation/privacy_ai_screen.dart:102)
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get settingsDelete;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:115)
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get settingsDelete2;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:84)
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:121)
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount2;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:395)
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount3;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:395)
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get settingsDeleting;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:388)
  ///
  /// In en, this message translates to:
  /// **'Deleting the account removes all local data, tokens, AI recaps, cache, reminders, and local documents on this device.'**
  String get settingsDeletingTheAccountRemovesAllLocal;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:226)
  ///
  /// In en, this message translates to:
  /// **'Diary and symptoms'**
  String get settingsDiaryAndSymptoms;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:409)
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get settingsDisable;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:398)
  ///
  /// In en, this message translates to:
  /// **'Disable app lock?'**
  String get settingsDisableAppLock;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:292)
  ///
  /// In en, this message translates to:
  /// **'Disable lock'**
  String get settingsDisableLock;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:234)
  ///
  /// In en, this message translates to:
  /// **'Distinct payloads for day, week, month, and pre-visit recaps. All processing runs locally — Gemma runs on-device via LiteRT.'**
  String get settingsDistinctPayloadsForDayWeekMonth;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:281)
  ///
  /// In en, this message translates to:
  /// **'Document search models'**
  String get settingsDocumentSearchModels;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:335)
  ///
  /// In en, this message translates to:
  /// **'Dossier PDF'**
  String get settingsDossierPdf;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:332)
  ///
  /// In en, this message translates to:
  /// **'Dossier PDF exported and shared.'**
  String get settingsDossierPdfExportedAndShared;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:137)
  ///
  /// In en, this message translates to:
  /// **'ELIMINA'**
  String get settingsElimina;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:290)
  ///
  /// In en, this message translates to:
  /// **'Embedding: Gemma 300M'**
  String get settingsEmbeddingGemma300m;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:369)
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get settingsEmergencyCard;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:366)
  ///
  /// In en, this message translates to:
  /// **'Emergency card exported and shared.'**
  String get settingsEmergencyCardExportedAndShared;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:43)
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// User-facing UI text (lib/features/settings/presentation/legal_document_screen.dart:20)
  ///
  /// In en, this message translates to:
  /// **'Export, account deletion, and data lifecycle.'**
  String get settingsExportAccountDeletionAndDataLifecycle;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:306)
  ///
  /// In en, this message translates to:
  /// **'Export dossier, emergency data, and structured backups.'**
  String get settingsExportDossierEmergencyDataAndStructured;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:375)
  ///
  /// In en, this message translates to:
  /// **'Exports are generated locally from on-device data.'**
  String get settingsExportsAreGeneratedLocallyFromOn;

  /// Title text (lib/features/settings/presentation/legal_center_screen.dart:18)
  ///
  /// In en, this message translates to:
  /// **'In-app internal texts for privacy, AI, and portability.'**
  String get settingsInAppInternalTextsForPrivacy;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:48)
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get settingsItaliano;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:349)
  ///
  /// In en, this message translates to:
  /// **'JSON backup exported and shared.'**
  String get settingsJsonBackupExportedAndShared;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:33)
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:144)
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsLarge;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:432)
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsLarge2;

  /// Title text (lib/features/settings/presentation/legal_center_screen.dart:12)
  ///
  /// In en, this message translates to:
  /// **'Legal center'**
  String get settingsLegalCenter;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:80)
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:163)
  ///
  /// In en, this message translates to:
  /// **'Local AI'**
  String get settingsLocalAi;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:176)
  ///
  /// In en, this message translates to:
  /// **'Local AI'**
  String get settingsLocalAi2;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:161)
  ///
  /// In en, this message translates to:
  /// **'Local AI and legal notes.'**
  String get settingsLocalAiAndLegalNotes;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:169)
  ///
  /// In en, this message translates to:
  /// **'Local AI only'**
  String get settingsLocalAiOnly;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:185)
  ///
  /// In en, this message translates to:
  /// **'Local AI only'**
  String get settingsLocalAiOnly2;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:242)
  ///
  /// In en, this message translates to:
  /// **'Local-first execution readiness.'**
  String get settingsLocalFirstExecutionReadiness;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:258)
  ///
  /// In en, this message translates to:
  /// **'Local-only: always active'**
  String get settingsLocalOnlyAlwaysActive;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:383)
  ///
  /// In en, this message translates to:
  /// **'Manage the lifecycle of your data.'**
  String get settingsManageTheLifecycleOfYourData;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:217)
  ///
  /// In en, this message translates to:
  /// **'Minimum context passed to the on-device model.'**
  String get settingsMinimumContextPassedToTheOn;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:187)
  ///
  /// In en, this message translates to:
  /// **'No data leaves device'**
  String get settingsNoDataLeavesDevice;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:170)
  ///
  /// In en, this message translates to:
  /// **'No external providers'**
  String get settingsNoExternalProviders;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:186)
  ///
  /// In en, this message translates to:
  /// **'No external providers'**
  String get settingsNoExternalProviders2;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:273)
  ///
  /// In en, this message translates to:
  /// **'No on-device provider detected yet.'**
  String get settingsNoOnDeviceProviderDetectedYet;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:254)
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get settingsNotAvailable;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:262)
  ///
  /// In en, this message translates to:
  /// **'On-device AI: checking...'**
  String get settingsOnDeviceAiChecking;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:265)
  ///
  /// In en, this message translates to:
  /// **'On-device AI: not ready'**
  String get settingsOnDeviceAiNotReady;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:264)
  ///
  /// In en, this message translates to:
  /// **'On-device AI: ready'**
  String get settingsOnDeviceAiReady;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:241)
  ///
  /// In en, this message translates to:
  /// **'On-device AI status'**
  String get settingsOnDeviceAiStatus;

  /// User-facing UI text (lib/features/settings/presentation/legal_center_screen.dart:32)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsOpen;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:184)
  ///
  /// In en, this message translates to:
  /// **'Open Legal Center'**
  String get settingsOpenLegalCenter;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:178)
  ///
  /// In en, this message translates to:
  /// **'Open Local AI'**
  String get settingsOpenLocalAi;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:403)
  ///
  /// In en, this message translates to:
  /// **'Operational note'**
  String get settingsOperationalNote;

  /// Input label text (lib/features/settings/presentation/app_settings_screen.dart:329)
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get settingsPin;

  /// Snackbar message (lib/features/settings/presentation/app_settings_screen.dart:357)
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get settingsPinsDoNotMatch;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:191)
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get settingsPreview;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:160)
  ///
  /// In en, this message translates to:
  /// **'Privacy and AI'**
  String get settingsPrivacyAndAi;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:198)
  ///
  /// In en, this message translates to:
  /// **'Privacy notice'**
  String get settingsPrivacyNotice;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:155)
  ///
  /// In en, this message translates to:
  /// **'Protect local health data with a device lock.'**
  String get settingsProtectLocalHealthDataWithA;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:291)
  ///
  /// In en, this message translates to:
  /// **'Provider: MediaPipe'**
  String get settingsProviderMediapipe;

  /// User-facing UI text (lib/features/settings/presentation/legal_document_screen.dart:15)
  ///
  /// In en, this message translates to:
  /// **'Prudent AI use and external providers.'**
  String get settingsPrudentAiUseAndExternalProviders;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:292)
  ///
  /// In en, this message translates to:
  /// **'Ranking: On-device'**
  String get settingsRankingOnDevice;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:313)
  ///
  /// In en, this message translates to:
  /// **'Read portability and retention'**
  String get settingsReadPortabilityAndRetention;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:209)
  ///
  /// In en, this message translates to:
  /// **'Recaps are generated on-device by Gemma via LiteRT. No recap content or health data is sent to any external server.'**
  String get settingsRecapsAreGeneratedOnDeviceBy;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:228)
  ///
  /// In en, this message translates to:
  /// **'Recent tests'**
  String get settingsRecentTests;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:249)
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get settingsRefresh;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:404)
  ///
  /// In en, this message translates to:
  /// **'Reminder for production use.'**
  String get settingsReminderForProductionUse;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:251)
  ///
  /// In en, this message translates to:
  /// **'Require unlock when opening ClinDiary'**
  String get settingsRequireUnlockWhenOpeningClindiary;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:108)
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:363)
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:282)
  ///
  /// In en, this message translates to:
  /// **'Semantic search and ranking for clinical documents.'**
  String get settingsSemanticSearchAndRankingForClinical;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:255)
  ///
  /// In en, this message translates to:
  /// **'Set a 6 digit PIN before enabling the app lock.'**
  String get settingsSetA6DigitPinBefore;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:314)
  ///
  /// In en, this message translates to:
  /// **'Set app PIN'**
  String get settingsSetAppPin;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:285)
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get settingsSetPin;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:19)
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSettings;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:119)
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get settingsSize;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:216)
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get settingsSleep;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:434)
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsStandard;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:215)
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get settingsSteps;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:75)
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// Title text (lib/features/settings/presentation/app_settings_screen.dart:102)
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get settingsText;

  /// User-facing UI text (lib/features/settings/presentation/legal_center_screen.dart:20)
  ///
  /// In en, this message translates to:
  /// **'These documents make the current app behavior transparent. Before go-live they must be replaced with the final legally validated versions.'**
  String get settingsTheseDocumentsMakeTheCurrentApp;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:90)
  ///
  /// In en, this message translates to:
  /// **'This action deletes the account, profiles, AI recaps, share links, and associated local data on this device.'**
  String get settingsThisActionDeletesTheAccountProfiles;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:298)
  ///
  /// In en, this message translates to:
  /// **'This is a local access lock. The document vault remains AES-GCM encrypted; the main SQLite diary database is not SQLCipher encrypted yet.'**
  String get settingsThisIsALocalAccessLock;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:93)
  ///
  /// In en, this message translates to:
  /// **'To confirm, type DELETE.'**
  String get settingsToConfirmTypeDelete;

  /// User-facing UI text (lib/features/settings/presentation/app_settings_screen.dart:319)
  ///
  /// In en, this message translates to:
  /// **'Use a 6 digit PIN as a fallback when biometrics are unavailable.'**
  String get settingsUseA6DigitPinAs;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:227)
  ///
  /// In en, this message translates to:
  /// **'Wearable'**
  String get settingsWearable;

  /// Title text (lib/features/settings/presentation/privacy_ai_screen.dart:216)
  ///
  /// In en, this message translates to:
  /// **'What AI can see'**
  String get settingsWhatAiCanSee;

  /// User-facing UI text (lib/features/settings/presentation/privacy_ai_screen.dart:297)
  ///
  /// In en, this message translates to:
  /// **'When you ask questions about your documents, the app uses Gecko 110M (via LiteRT-LM TextEmbedder) to understand semantic meaning. The embedding model runs entirely on-device — your question and document context are never sent to external servers. Results are ranked locally and passed to Gemma 4 for answer generation with citations.'**
  String get settingsWhenYouAskQuestionsAboutYour;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String signInFailed(Object error);

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal health diary.'**
  String get signInSubtitle;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @signingInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signing in with Google...'**
  String get signingInWithGoogle;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:174)
  ///
  /// In en, this message translates to:
  /// **'Smartwatch'**
  String get smartwatch;

  /// No description provided for @startingApp.
  ///
  /// In en, this message translates to:
  /// **'Starting ClinDiary...'**
  String get startingApp;

  /// User-facing UI text (lib/shared/widgets/summary_content_view.dart:567)
  ///
  /// In en, this message translates to:
  /// **': r'**
  String get summaryContentViewR;

  /// Title text (lib/features/timeline/presentation/timeline_screen.dart:25)
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:412)
  ///
  /// In en, this message translates to:
  /// **'Adherence'**
  String get timelineAdherence;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:100)
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get timelineAlert;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:404)
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get timelineAlert2;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:71)
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get timelineAll;

  /// Title text (lib/features/timeline/data/timeline_repository.dart:41)
  ///
  /// In en, this message translates to:
  /// **'Daily check-in'**
  String get timelineDailyCheckIn;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:21)
  ///
  /// In en, this message translates to:
  /// **'dd MMM · HH:mm'**
  String get timelineDdMmmHhMm;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:398)
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get timelineDocument;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:166)
  ///
  /// In en, this message translates to:
  /// **'EEEE dd MMMM'**
  String get timelineEeeeDdMmmm;

  /// Title text (lib/features/timeline/presentation/timeline_screen.dart:47)
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get timelineEvents;

  /// Title text (lib/features/timeline/presentation/timeline_screen.dart:65)
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get timelineFilters;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:231)
  ///
  /// In en, this message translates to:
  /// **'HH:mm'**
  String get timelineHhMm;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:402)
  ///
  /// In en, this message translates to:
  /// **'Imaging'**
  String get timelineImaging;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:400)
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get timelineLab;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:118)
  ///
  /// In en, this message translates to:
  /// **'No events for this filter.'**
  String get timelineNoEventsForThisFilter;

  /// Title text (lib/features/timeline/presentation/timeline_screen.dart:48)
  ///
  /// In en, this message translates to:
  /// **'Organized by day.'**
  String get timelineOrganizedByDay;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:106)
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get timelineReport;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:406)
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get timelineReport2;

  /// Title text (lib/features/timeline/presentation/timeline_screen.dart:117)
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get timelineResult;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:408)
  ///
  /// In en, this message translates to:
  /// **'Screening'**
  String get timelineScreening;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:416)
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get timelineSymptom;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:36)
  ///
  /// In en, this message translates to:
  /// **'Timeline is empty.'**
  String get timelineTimelineIsEmpty;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:418)
  ///
  /// In en, this message translates to:
  /// **'Vital'**
  String get timelineVital;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:355)
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timelineYesterday;

  /// Title text (lib/features/daily_journal/presentation/diary_screen.dart:243)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// User-facing UI text (lib/features/history/presentation/history_screen.dart:163)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle2;

  /// Title text (lib/features/home/presentation/home_screen.dart:1083)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle3;

  /// User-facing UI text (lib/features/timeline/presentation/timeline_screen.dart:352)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle4;

  /// No description provided for @treatments.
  ///
  /// In en, this message translates to:
  /// **'Treatments'**
  String get treatments;

  /// User-facing UI text (lib/features/auth/presentation/session_gate_screen.dart:59)
  ///
  /// In en, this message translates to:
  /// **'Verifying session...'**
  String get verifyingSession;

  /// User-facing UI text (lib/features/auth/presentation/session_gate_screen.dart:69)
  ///
  /// In en, this message translates to:
  /// **'Verifying session...'**
  String get verifyingSession2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:564)
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get wearablesActivity;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:584)
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get wearablesActivity2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:600)
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get wearablesActivity3;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:239)
  ///
  /// In en, this message translates to:
  /// **'Activity recognition denied'**
  String get wearablesActivityRecognitionDenied;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:238)
  ///
  /// In en, this message translates to:
  /// **'Activity recognition OK'**
  String get wearablesActivityRecognitionOk;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:607)
  ///
  /// In en, this message translates to:
  /// **'available in the device health repository.'**
  String get wearablesAvailableInTheDeviceHealthRepository;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:611)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary is receiving mostly activity metrics, while'**
  String get wearablesClindiaryIsReceivingMostlyActivityMetrics;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:258)
  ///
  /// In en, this message translates to:
  /// **'ClinDiary only uses aggregated daily summaries.'**
  String get wearablesClindiaryOnlyUsesAggregatedDailySummaries;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:283)
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get wearablesConnect;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:193)
  ///
  /// In en, this message translates to:
  /// **'Connect the provider and sync daily summaries.'**
  String get wearablesConnectTheProviderAndSyncDaily;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:409)
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get wearablesCopyDiagnostics;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:170)
  ///
  /// In en, this message translates to:
  /// **'dd MMM'**
  String get wearablesDdMmm;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:338)
  ///
  /// In en, this message translates to:
  /// **'Detected sources'**
  String get wearablesDetectedSources;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:567)
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get wearablesDistance;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:585)
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get wearablesDistance2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:600)
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get wearablesDistance3;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:602)
  ///
  /// In en, this message translates to:
  /// **'Google Fit'**
  String get wearablesGoogleFit;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:624)
  ///
  /// In en, this message translates to:
  /// **'Google Fit'**
  String get wearablesGoogleFit2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:231)
  ///
  /// In en, this message translates to:
  /// **'Health Connect denied'**
  String get wearablesHealthConnectDenied;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:605)
  ///
  /// In en, this message translates to:
  /// **'Health Connect is exposing only activity data from Google Fit to ClinDiary'**
  String get wearablesHealthConnectIsExposingOnlyActivity;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:230)
  ///
  /// In en, this message translates to:
  /// **'Health Connect OK'**
  String get wearablesHealthConnectOk;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:192)
  ///
  /// In en, this message translates to:
  /// **'Health connection'**
  String get wearablesHealthConnection;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:417)
  ///
  /// In en, this message translates to:
  /// **'Health connection'**
  String get wearablesHealthConnection2;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:421)
  ///
  /// In en, this message translates to:
  /// **'Health connection'**
  String get wearablesHealthConnection3;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:97)
  ///
  /// In en, this message translates to:
  /// **'Health settings opened.'**
  String get wearablesHealthSettingsOpened;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:555)
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get wearablesHeartRate;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:581)
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get wearablesHeartRate2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:246)
  ///
  /// In en, this message translates to:
  /// **'History limited'**
  String get wearablesHistoryLimited;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:245)
  ///
  /// In en, this message translates to:
  /// **'History OK'**
  String get wearablesHistoryOk;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:570)
  ///
  /// In en, this message translates to:
  /// **'HRV'**
  String get wearablesHrv;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:586)
  ///
  /// In en, this message translates to:
  /// **'HRV'**
  String get wearablesHrv2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:273)
  ///
  /// In en, this message translates to:
  /// **'Install provider'**
  String get wearablesInstallProvider;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:428)
  ///
  /// In en, this message translates to:
  /// **'Latest synced daily summaries.'**
  String get wearablesLatestSyncedDailySummaries;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:371)
  ///
  /// In en, this message translates to:
  /// **'Metrics still missing'**
  String get wearablesMetricsStillMissing;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:364)
  ///
  /// In en, this message translates to:
  /// **'No recent metrics'**
  String get wearablesNoRecentMetrics;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:432)
  ///
  /// In en, this message translates to:
  /// **'No synced data yet.'**
  String get wearablesNoSyncedDataYet;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:124)
  ///
  /// In en, this message translates to:
  /// **'No wearable data available in the last 30 days.'**
  String get wearablesNoWearableDataAvailableInThe;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:291)
  ///
  /// In en, this message translates to:
  /// **'Open permissions'**
  String get wearablesOpenPermissions;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:73)
  ///
  /// In en, this message translates to:
  /// **'Opening the store to install or update Health Connect.'**
  String get wearablesOpeningTheStoreToInstallOr;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:223)
  ///
  /// In en, this message translates to:
  /// **'Permissions missing'**
  String get wearablesPermissionsMissing;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:222)
  ///
  /// In en, this message translates to:
  /// **'Permissions OK'**
  String get wearablesPermissionsOk;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:216)
  ///
  /// In en, this message translates to:
  /// **'Provider unavailable'**
  String get wearablesProviderUnavailable;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:309)
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get wearablesQuickCheck;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:353)
  ///
  /// In en, this message translates to:
  /// **'Recently found metrics'**
  String get wearablesRecentlyFoundMetrics;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:558)
  ///
  /// In en, this message translates to:
  /// **'Resting HR'**
  String get wearablesRestingHr;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:582)
  ///
  /// In en, this message translates to:
  /// **'Resting HR'**
  String get wearablesRestingHr2;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:310)
  ///
  /// In en, this message translates to:
  /// **'Shows where the connection breaks down.'**
  String get wearablesShowsWhereTheConnectionBreaksDown;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:552)
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get wearablesSleep;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:580)
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get wearablesSleep2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:612)
  ///
  /// In en, this message translates to:
  /// **'sleep, heart rate, and SpO2 are still not exposed.'**
  String get wearablesSleepHeartRateAndSpo2Are;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:561)
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get wearablesSpo2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:583)
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get wearablesSpo22;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:549)
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get wearablesSteps;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:579)
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get wearablesSteps2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:600)
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get wearablesSteps3;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:606)
  ///
  /// In en, this message translates to:
  /// **'(steps, distance, or intensity). Sleep, heart rate, and SpO2 are not'**
  String get wearablesStepsDistanceOrIntensitySleepHeart;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get wearablesSync;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:296)
  ///
  /// In en, this message translates to:
  /// **'Sync 30 days'**
  String get wearablesSync30Days;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:518)
  ///
  /// In en, this message translates to:
  /// **'Synced aggregated data'**
  String get wearablesSyncedAggregatedData;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:196)
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get wearablesSyncing;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:610)
  ///
  /// In en, this message translates to:
  /// **'The data available from Health Connect is only partial.'**
  String get wearablesTheDataAvailableFromHealthConnect;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:98)
  ///
  /// In en, this message translates to:
  /// **'Unable to open health settings from ClinDiary.'**
  String get wearablesUnableToOpenHealthSettingsFrom;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:390)
  ///
  /// In en, this message translates to:
  /// **'Useful only for support and debugging.'**
  String get wearablesUsefulOnlyForSupportAndDebugging;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:43)
  ///
  /// In en, this message translates to:
  /// **'Wearable access enabled. No new data to sync right now.'**
  String get wearablesWearableAccessEnabledNoNewData;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:389)
  ///
  /// In en, this message translates to:
  /// **'Wearable diagnostics'**
  String get wearablesWearableDiagnostics;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:156)
  ///
  /// In en, this message translates to:
  /// **'Wearable diagnostics copied to clipboard.'**
  String get wearablesWearableDiagnosticsCopiedToClipboard;

  /// Title text (lib/features/wearables/presentation/wearables_screen.dart:427)
  ///
  /// In en, this message translates to:
  /// **'Wearable history'**
  String get wearablesWearableHistory;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:44)
  ///
  /// In en, this message translates to:
  /// **'Wearable permissions not granted.'**
  String get wearablesWearablePermissionsNotGranted;

  /// User-facing UI text (lib/features/wearables/data/wearable_health_service_impl_io.dart:89)
  ///
  /// In en, this message translates to:
  /// **'Wearable sync disponibile solo su Android e iPhone.'**
  String get wearablesWearableSyncDisponibileSoloSuAndroid;

  /// User-facing UI text (lib/features/wearables/data/wearable_health_service_impl_stub.dart:19)
  ///
  /// In en, this message translates to:
  /// **'Wearable sync is not available on this platform.'**
  String get wearablesWearableSyncIsNotAvailableOn;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:259)
  ///
  /// In en, this message translates to:
  /// **'Wearable sync is not available on this platform.'**
  String get wearablesWearableSyncIsNotAvailableOn2;

  /// User-facing UI text (lib/features/wearables/presentation/wearables_screen.dart:628)
  ///
  /// In en, this message translates to:
  /// **'Xiaomi Fitness'**
  String get wearablesXiaomiFitness;

  /// No description provided for @documentsResultNumber.
  ///
  /// In en, this message translates to:
  /// **'Result {number}'**
  String documentsResultNumber(Object number);

  /// No description provided for @historyDailyReportRegeneratedFor.
  ///
  /// In en, this message translates to:
  /// **'Daily report regenerated for {formattedDate}.'**
  String historyDailyReportRegeneratedFor(Object formattedDate);

  /// No description provided for @historyDocumentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} documents'**
  String historyDocumentsCount(Object count);

  /// No description provided for @historyEnergyValue.
  ///
  /// In en, this message translates to:
  /// **'Energy {value}/10'**
  String historyEnergyValue(Object value);

  /// No description provided for @historyEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String historyEventsCount(Object count);

  /// No description provided for @historyHeartRateValue.
  ///
  /// In en, this message translates to:
  /// **'HR {value}'**
  String historyHeartRateValue(Object value);

  /// No description provided for @historyMoodValue.
  ///
  /// In en, this message translates to:
  /// **'Mood {value}/10'**
  String historyMoodValue(Object value);

  /// No description provided for @historyPainValue.
  ///
  /// In en, this message translates to:
  /// **'Pain {value}/10'**
  String historyPainValue(Object value);

  /// No description provided for @historyRegenerationFailedError.
  ///
  /// In en, this message translates to:
  /// **'Regeneration failed: {error}'**
  String historyRegenerationFailedError(Object error);

  /// No description provided for @historyRestingValue.
  ///
  /// In en, this message translates to:
  /// **'Resting {value}'**
  String historyRestingValue(Object value);

  /// No description provided for @historySleepValue.
  ///
  /// In en, this message translates to:
  /// **'Sleep {hours} h'**
  String historySleepValue(Object hours);

  /// No description provided for @historySpo2Value.
  ///
  /// In en, this message translates to:
  /// **'SpO2 {value}'**
  String historySpo2Value(Object value);

  /// No description provided for @historyStepsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} steps'**
  String historyStepsValue(Object value);

  /// No description provided for @historyStressValue.
  ///
  /// In en, this message translates to:
  /// **'Stress {value}/10'**
  String historyStressValue(Object value);

  /// No description provided for @notificationsChannelStatus.
  ///
  /// In en, this message translates to:
  /// **'{channel}: {status} ({provider})'**
  String notificationsChannelStatus(Object channel, Object status, Object provider);

  /// No description provided for @notificationsChannelStatusWithError.
  ///
  /// In en, this message translates to:
  /// **'{channel}: {status} ({provider}) - {error}'**
  String notificationsChannelStatusWithError(Object channel, Object status, Object provider, Object error);

  /// No description provided for @notificationsError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get notificationsError;

  /// No description provided for @notificationsOk.
  ///
  /// In en, this message translates to:
  /// **'ok'**
  String get notificationsOk;

  /// No description provided for @notificationsRemindersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reminders'**
  String notificationsRemindersCount(Object count);

  /// No description provided for @notificationsSyncAt.
  ///
  /// In en, this message translates to:
  /// **'Sync {formattedDate}'**
  String notificationsSyncAt(Object formattedDate);

  /// No description provided for @notificationsTotalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String notificationsTotalCount(Object count);

  /// No description provided for @notificationsUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String notificationsUnreadCount(Object count);

  /// No description provided for @profileItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String profileItemsCount(Object count);

  /// No description provided for @documentsFolderCreated.
  ///
  /// In en, this message translates to:
  /// **'Folder \"{folderName}\" created.'**
  String documentsFolderCreated(Object folderName);

  /// No description provided for @documentsWaitingCount.
  ///
  /// In en, this message translates to:
  /// **'Waiting: {count}'**
  String documentsWaitingCount(Object count);

  /// No description provided for @documentsBackgroundParsingCount.
  ///
  /// In en, this message translates to:
  /// **'Background parsing: {count}'**
  String documentsBackgroundParsingCount(Object count);

  /// No description provided for @documentsFoldersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} folders'**
  String documentsFoldersCount(Object count);

  /// No description provided for @documentsSubfoldersFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{folders} subfolders • {files} files'**
  String documentsSubfoldersFilesCount(Object folders, Object files);

  /// No description provided for @documentsTryDifferentWordsOrClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Try different words or clear the search.'**
  String get documentsTryDifferentWordsOrClearSearch;

  /// No description provided for @documentsStartBySavingFileOrCreatingFolder.
  ///
  /// In en, this message translates to:
  /// **'Start by saving a file or creating a folder.'**
  String get documentsStartBySavingFileOrCreatingFolder;

  /// No description provided for @documentsTryAnotherFilterOrClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Try another filter or clear the search.'**
  String get documentsTryAnotherFilterOrClearSearch;

  /// No description provided for @documentsFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder: {folderName}'**
  String documentsFolderLabel(Object folderName);

  /// No description provided for @documentsParsingPercent.
  ///
  /// In en, this message translates to:
  /// **'Parsing {percent}%'**
  String documentsParsingPercent(Object percent);

  /// No description provided for @documentsDeleteDocumentBody.
  ///
  /// In en, this message translates to:
  /// **'The document will be deleted permanently. Do you want to continue?'**
  String get documentsDeleteDocumentBody;

  /// No description provided for @documentsOpenManualReviewToAddOrConfirmKeyValues.
  ///
  /// In en, this message translates to:
  /// **'Open Manual review to add or confirm key values.'**
  String get documentsOpenManualReviewToAddOrConfirmKeyValues;

  /// No description provided for @documentsOpenTheFileAndConfirmDetailsIfNeeded.
  ///
  /// In en, this message translates to:
  /// **'Open the file and confirm details if needed.'**
  String get documentsOpenTheFileAndConfirmDetailsIfNeeded;

  /// No description provided for @documentsOpenItMoveItOrAskForAQuickExplanation.
  ///
  /// In en, this message translates to:
  /// **'Open it, move it, or ask for a quick explanation.'**
  String get documentsOpenItMoveItOrAskForAQuickExplanation;

  /// No description provided for @documentsClassificationPercent.
  ///
  /// In en, this message translates to:
  /// **'Classification {percent}%'**
  String documentsClassificationPercent(Object percent);

  /// No description provided for @documentsThisDocumentIsMarkedAsOldAnd.
  ///
  /// In en, this message translates to:
  /// **'This document is marked as old and is not included in AI recaps.'**
  String get documentsThisDocumentIsMarkedAsOldAnd;

  /// No description provided for @documentsYouCanOpenItReviewItOrAskForASimpleExplanation.
  ///
  /// In en, this message translates to:
  /// **'You can open it, review it, or ask for a simple explanation.'**
  String get documentsYouCanOpenItReviewItOrAskForASimpleExplanation;

  /// No description provided for @documentsYouCanReadThisFileButEditingIsDisabled.
  ///
  /// In en, this message translates to:
  /// **'You can read this file, but editing is disabled right now.'**
  String get documentsYouCanReadThisFileButEditingIsDisabled;

  /// No description provided for @documentsTheExtractedTextStaysHiddenUntilView.
  ///
  /// In en, this message translates to:
  /// **'The extracted text is ready but stays hidden until you choose to view it.'**
  String get documentsTheExtractedTextStaysHiddenUntilView;

  /// No description provided for @documentsRangeWithoutUnit.
  ///
  /// In en, this message translates to:
  /// **'Range {min}-{max}'**
  String documentsRangeWithoutUnit(Object min, Object max);

  /// No description provided for @documentsRangeWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Range {min}-{max} {unit}'**
  String documentsRangeWithUnit(Object min, Object max, Object unit);

  /// No description provided for @documentsBodyArea.
  ///
  /// In en, this message translates to:
  /// **'Body area: {bodyPart}'**
  String documentsBodyArea(Object bodyPart);

  /// No description provided for @documentsConclusion.
  ///
  /// In en, this message translates to:
  /// **'Conclusion: {text}'**
  String documentsConclusion(Object text);

  /// No description provided for @profileProfilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles total'**
  String profileProfilesCount(Object count);

  /// No description provided for @profileActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get profileActivate;

  /// No description provided for @profileBornDate.
  ///
  /// In en, this message translates to:
  /// **'Born {date}'**
  String profileBornDate(Object date);

  /// No description provided for @profileTheItemWillBeRemovedFromTheDossier.
  ///
  /// In en, this message translates to:
  /// **'The item will be removed from the dossier.'**
  String get profileTheItemWillBeRemovedFromTheDossier;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'it': return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
