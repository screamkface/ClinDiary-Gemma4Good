import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
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

  bool get _isEnglish => locale.languageCode.toLowerCase() == 'en';

  String get appTitle => 'ClinDiary';

  String get appSubtitle =>
      _isEnglish ? 'Personal health diary.' : 'Diario clinico personale.';

  String get signInTitle => _isEnglish ? 'Sign in' : 'Accedi';

  String get emailLabel => 'Email';

  String get passwordLabel => _isEnglish ? 'Password' : 'Password';

  String get confirmPasswordLabel =>
      _isEnglish ? 'Confirm password' : 'Conferma password';

  String get passwordsDoNotMatch =>
      _isEnglish ? 'Passwords do not match' : 'Le password non coincidono';

  String get emailInvalid =>
      _isEnglish ? 'Enter a valid email' : 'Inserisci una email valida';

  String get passwordMinLength =>
      _isEnglish ? 'Minimum 8 characters' : 'Minimo 8 caratteri';

  String get signIn => _isEnglish ? 'Sign in' : 'Accedi';

  String get signingIn => _isEnglish ? 'Signing in...' : 'Accesso...';

  String get signInWithGoogle =>
      _isEnglish ? 'Sign in with Google' : 'Accedi con Google';

  String get signingInWithGoogle =>
      _isEnglish ? 'Signing in with Google...' : 'Accesso Google...';

  String get googleAuthNotConfigured => _isEnglish
      ? 'Google auth is not configured in this build.'
      : 'Google auth non configurato in questa build.';

  String get googleIdTokenInvalid => _isEnglish
      ? 'Google did not return a valid ID token.'
      : 'Google non ha restituito un id token valido.';

  String signInFailed(String error) => _isEnglish
      ? 'Sign-in failed: $error'
      : 'Accesso non riuscito: $error';

  String googleSignInFailed(String error) => _isEnglish
      ? 'Google sign-in failed: $error'
      : 'Accesso Google non riuscito: $error';

  String get resetPassword =>
      _isEnglish ? 'Reset password' : 'Avvia reset password';

  String get passwordResetPrompt => _isEnglish
      ? 'Enter your email first to start the reset.'
      : 'Inserisci prima l’email per avviare il reset.';

  String get passwordResetStarted => _isEnglish
      ? 'Reset started. Check the expected channel.'
      : 'Reset avviato. Controlla il canale previsto.';

  String passwordResetStartedToken(String token) => _isEnglish
      ? 'Reset started. Development token: $token'
      : 'Reset avviato. Token sviluppo: $token';

  String passwordResetFailed(String error) => _isEnglish
      ? 'Password reset failed: $error'
      : 'Reset non riuscito: $error';

  String get noAccountPrompt =>
      _isEnglish ? "Don't have an account?" : 'Non hai un account?';

  String get register => _isEnglish ? 'Register' : 'Registrati';

  String get createAccount => _isEnglish ? 'Create account' : 'Crea account';

  String get completeProfileNext => _isEnglish
      ? 'You will complete your profile in the next step.'
      : 'Completerai il profilo nel passo successivo.';

  String get creatingAccount =>
      _isEnglish ? 'Creating account...' : 'Creazione account...';

  String get continueButton => _isEnglish ? 'Continue' : 'Continua';

  String get alreadyHaveAccountSignIn => _isEnglish
      ? 'Already have an account? Sign in'
      : 'Hai già un account? Accedi';

  String registrationFailed(String error) => _isEnglish
      ? 'Registration failed: $error'
      : 'Registrazione non riuscita: $error';

  String get verifyingSession =>
      _isEnglish ? 'Verifying session...' : 'Verifico la sessione...';

  String get startingApp =>
      _isEnglish ? 'Starting ClinDiary...' : 'Avvio ClinDiary...';

  String get redirectingToLogin =>
      _isEnglish ? 'Redirecting to sign in...' : 'Reindirizzo al login...';

  String get discoverAiPlus =>
      _isEnglish ? 'Discover AI Plus' : 'Scopri AI Plus';

  String get todayTitle => _isEnglish ? 'Today' : 'Oggi';

  String get profileSetupInProgress => _isEnglish
      ? 'Profile setup in progress'
      : 'Profilo in configurazione';

  String get completeOnboardingToStart => _isEnglish
      ? 'Complete onboarding to get started.'
      : 'Completa l\'onboarding per iniziare.';

  String get chooseRecapOrSaveCheckUp => _isEnglish
      ? 'Choose a recap or save a check-up.'
      : 'Scegli un recap oppure salva un check-up.';

  String get alertsAllClear => _isEnglish ? 'All clear' : 'Alert ok';

  String alertsCountLabel(int count) => _isEnglish
      ? '$count alerts'
      : '$count alert';

  String get notificationsUnread => _isEnglish
      ? 'Unread'
      : 'Da leggere';

  String get notificationsAllCaughtUp => _isEnglish
      ? 'All caught up'
      : 'Notifiche ok';

  String get medicationsDue => _isEnglish
      ? 'Medications due'
      : 'Terapie da fare';

  String get medicationsAllCaughtUp => _isEnglish
      ? 'All set'
      : 'Terapie ok';

  String get aiRecap => _isEnglish ? 'AI Recap' : 'Recap AI';

  String get checkUp => _isEnglish ? 'Check-up' : 'Check-up';

  String get demoScenarios => _isEnglish ? 'Demo scenarios' : 'Scenari demo';

  String get judgeModeSubtitle => _isEnglish
      ? 'Judge mode active. Switch scenario and open the local recap right away.'
      : 'Judge mode attivo. Cambia scenario e apri subito il recap locale.';

  String get openAiRecap => _isEnglish ? 'Open AI Recap' : 'Apri Recap AI';

  String get goTo => _isEnglish ? 'Go to' : 'Vai a';

  String get documents => _isEnglish ? 'Documents' : 'Documenti';

  String get reports => _isEnglish ? 'Reports' : 'Referti';

  String get medications => _isEnglish ? 'Medications' : 'Farmaci';

  String get treatments => _isEnglish ? 'Treatments' : 'Terapie';

  String get prevention => _isEnglish ? 'Prevention' : 'Prevenzione';

  String get checkups => _isEnglish ? 'Checkups' : 'Controlli';

  String get devices => _isEnglish ? 'Devices' : 'Dispositivi';

  String get dossier => _isEnglish ? 'Dossier' : 'Dossier';

  String get history => _isEnglish ? 'History' : 'Storico';

  String get profiles => _isEnglish ? 'Profiles' : 'Profili';

  String get manage => _isEnglish ? 'Manage' : 'Gestisci';

  String get add => _isEnglish ? 'Add' : 'Aggiungi';

  String get more => _isEnglish ? 'More' : 'Altro';

  String get secondaryTools => _isEnglish ? 'Secondary tools' : 'Strumenti secondari';

  String get timeline => _isEnglish ? 'Timeline' : 'Timeline';

  String get notifications => _isEnglish ? 'Notifications' : 'Notifiche';

  String get smartwatch => _isEnglish ? 'Smartwatch' : 'Smartwatch';

  String get aiPlus => _isEnglish ? 'AI Plus' : 'AI Plus';

  String get alerts => _isEnglish ? 'Alerts' : 'Alert';

  String get primaryProfileLabel => _isEnglish ? 'primary' : 'principale';

  String activeProfileLabel(String profileName) => _isEnglish
      ? 'You are using $profileName'
      : 'Stai usando $profileName';
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