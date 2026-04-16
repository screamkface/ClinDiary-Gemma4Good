import 'package:clindiary/app/core/settings/app_display_settings.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/shared/widgets/compact_segmented_control.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appDisplaySettingsControllerProvider);
    final profileAsync = ref.watch(profileBundleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (settings) => profileAsync.when(
          data: (bundle) {
            if (bundle == null) {
              return const Center(
                child: Text(
                  'Complete sign-in to manage settings.',
                ),
              );
            }

            final aiConsent = bundle.onboarding.aiExternalConsent;
            final aiConsentAt = bundle.onboarding.aiExternalConsentedAt;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Appearance',
                  subtitle: 'Choose the app theme.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompactSegmentedControl<AppThemePreference>(
                        options: const [
                          CompactSegmentOption(
                            value: AppThemePreference.system,
                            icon: Icons.brightness_auto_outlined,
                            label: 'Auto',
                          ),
                          CompactSegmentOption(
                            value: AppThemePreference.light,
                            icon: Icons.light_mode_outlined,
                            label: 'Light',
                          ),
                          CompactSegmentOption(
                            value: AppThemePreference.dark,
                            icon: Icons.dark_mode_outlined,
                            label: 'Dark',
                          ),
                        ],
                        selectedValue: settings.themePreference,
                        onChanged: (selection) {
                          ref
                              .read(
                                appDisplaySettingsControllerProvider.notifier,
                              )
                              .setThemePreference(selection);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Text',
                  subtitle: 'Adjust overall readability.',
                  action: TextButton(
                    onPressed: () => ref
                        .read(appDisplaySettingsControllerProvider.notifier)
                        .reset(),
                    child: const Text('Reset'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Size',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Chip(label: Text(_fontLabel(settings.textScale))),
                        ],
                      ),
                      Slider(
                        value: settings.textScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label: settings.textScale.toStringAsFixed(2),
                        onChanged: (value) => ref
                            .read(appDisplaySettingsControllerProvider.notifier)
                            .setTextScale(value),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Compact',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Large',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Privacy and AI',
                  subtitle: 'Consent, export, and beta legal notes.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              aiConsent
                                  ? 'External AI enabled'
                                  : 'External AI disabled',
                            ),
                          ),
                          if (aiConsent && aiConsentAt != null)
                            Chip(
                              label: Text(
                                'Last consent ${_dateLabel(aiConsentAt.toLocal())}',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/app/profile/settings/privacy-ai'),
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Open Privacy AI'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/legal'),
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Open Legal Center'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Preview',
                  subtitle: 'A small preview of the current look.',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ClinDiary',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            Chip(label: Text('Steps')),
                            Chip(label: Text('Sleep')),
                            Chip(label: Text('AI Recap')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _fontLabel(double scale) {
  if (scale <= 0.95) {
    return 'Compact';
  }
  if (scale >= 1.2) {
    return 'Large';
  }
  return 'Standard';
}
