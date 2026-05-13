import 'package:clindiary/app/bootstrap/gemma_model_background_bootstrap.dart';
import 'package:clindiary/app/bootstrap/gemma_download_notification_bootstrap.dart';
import 'package:clindiary/app/bootstrap/medication_reminder_bootstrap.dart';
import 'package:clindiary/app/bootstrap/wearable_sync_bootstrap.dart';
import 'package:clindiary/app/core/security/app_lock_gate.dart';
import 'package:clindiary/app/core/settings/app_display_settings.dart';
import 'package:clindiary/app/router.dart';
import 'package:clindiary/app/theme/app_theme.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClinDiaryApp extends ConsumerWidget {
  const ClinDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final displaySettings =
        ref.watch(appDisplaySettingsControllerProvider).valueOrNull ??
        const AppDisplaySettings();
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildClinDiaryTheme(brightness: Brightness.light),
      darkTheme: buildClinDiaryTheme(brightness: Brightness.dark),
      themeMode: displaySettings.themeMode,
      scrollBehavior: const _MinimalScrollBehavior(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: displaySettings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(displaySettings.textScale)),
          child: GemmaDownloadNotificationBootstrap(
            child: GemmaModelBackgroundBootstrap(
              child: MedicationReminderBootstrap(
                child: WearableSyncBootstrap(
                  child: AppLockGate(child: appChild),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MinimalScrollBehavior extends MaterialScrollBehavior {
  const _MinimalScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
