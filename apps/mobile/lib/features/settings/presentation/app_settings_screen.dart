import 'package:clindiary/app/core/settings/app_display_settings.dart';
import 'package:clindiary/app/core/security/app_lock_controller.dart';
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
                child: Text('Complete sign-in to manage settings.'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Language',
                  subtitle: 'Choose the app language.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompactSegmentedControl<AppLanguagePreference>(
                        options: const [
                          CompactSegmentOption(
                            value: AppLanguagePreference.en,
                            icon: Icons.language_outlined,
                            label: 'English',
                          ),
                          CompactSegmentOption(
                            value: AppLanguagePreference.it,
                            icon: Icons.language_outlined,
                            label: 'Italiano',
                          ),
                        ],
                        selectedValue: settings.language,
                        onChanged: (selection) {
                          ref
                              .read(
                                appDisplaySettingsControllerProvider.notifier,
                              )
                              .setLanguage(selection);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                            label: 'System',
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
                  subtitle: 'Adjust the overall readability.',
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
                  title: 'App lock',
                  subtitle: 'Protect local health data with a device lock.',
                  child: const _AppLockSettingsSection(),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Privacy and AI',
                  subtitle: 'Local AI and legal notes.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Local AI only')),
                          Chip(label: Text('No external providers')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/app/profile/settings/privacy-ai'),
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Open Local AI'),
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
                  subtitle: 'A small example of the current look.',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
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

class _AppLockSettingsSection extends ConsumerWidget {
  const _AppLockSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(appLockControllerProvider);
    return lockState.when(
      data: (state) {
        final settings = state.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require unlock when opening ClinDiary'),
              subtitle: Text(
                settings.pinSet
                    ? 'PIN fallback is configured. Biometrics: ${settings.biometricAvailable ? 'available' : 'not available'}.'
                    : 'Set a 6 digit PIN before enabling the app lock.',
              ),
              value: settings.enabled,
              onChanged: (enabled) async {
                if (enabled && !settings.pinSet) {
                  await _showSetPinDialog(context, ref);
                  return;
                }
                try {
                  await ref
                      .read(appLockControllerProvider.notifier)
                      .setEnabled(enabled);
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _showSetPinDialog(context, ref),
                  icon: const Icon(Icons.pin_outlined),
                  label: Text(settings.pinSet ? 'Change PIN' : 'Set PIN'),
                ),
                OutlinedButton.icon(
                  onPressed: settings.pinSet
                      ? () => _showDisableLockDialog(context, ref)
                      : null,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Disable lock'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This is a local access lock. The document vault remains AES-GCM encrypted; the main SQLite diary database is not SQLCipher encrypted yet.',
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(error.toString()),
    );
  }

  Future<void> _showSetPinDialog(BuildContext context, WidgetRef ref) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set app PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use a 6 digit PIN as a fallback when biometrics are unavailable.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin != confirm) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('PINs do not match.')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(pin);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    pinController.dispose();
    confirmController.dispose();
    if (result == null) {
      return;
    }
    try {
      await ref.read(appLockControllerProvider.notifier).setPin(result);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App lock enabled.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showDisableLockDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable app lock?'),
        content: const Text(
          'ClinDiary will no longer ask for PIN or biometrics on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(appLockControllerProvider.notifier).disable();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App lock disabled.')));
  }
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
