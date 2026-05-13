import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

AppLocalizations _notificationsL10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

DateFormat _notificationsDateFormat(BuildContext context) {
  final localeName = appDateFormattingLocaleName(
    appLanguageCodeFromLocale(Localizations.localeOf(context)),
  );
  final l10n = _notificationsL10nOf(context);
  try {
    return DateFormat(l10n.notificationsDdMmmYyyyHhMm, localeName);
  } catch (_) {
    return DateFormat(l10n.notificationsDdMmmYyyyHhMm);
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _markingReadId;
  bool _savingPreferences = false;
  bool _syncingLocalReminders = false;
  bool _sendingTestDelivery = false;

  Future<void> _markRead(AppNotificationItem item) async {
    setState(() => _markingReadId = item.id);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(item.id);
      ref.invalidate(notificationsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _markingReadId = null);
      }
    }
  }

  Future<void> _updatePreference(String field, bool value) async {
    setState(() => _savingPreferences = true);
    try {
      await ref.read(notificationsRepositoryProvider).updatePreferences({
        field: value,
      });
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(notificationsProvider);
      if (field == 'medication_reminders_enabled') {
        await _syncLocalMedicationReminders(showFeedback: false);
      }
      if (field == 'daily_checkin_enabled') {
        // Sync daily check-in reminders to device whenever user toggles this preference
        await ref
            .read(localMedicationReminderServiceProvider)
            .syncDailyCheckInReminders(enabled: value, completedToday: false);
        ref.invalidate(localMedicationReminderStatusProvider);
      }
      if (field == 'symptom_follow_up_enabled') {
        final entries = await ref.read(dailyEntriesProvider.future);
        await ref
            .read(localMedicationReminderServiceProvider)
            .syncSymptomFollowUpReminders(entries: entries, enabled: value);
        ref.invalidate(localMedicationReminderStatusProvider);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _savingPreferences = false);
      }
    }
  }

  Future<void> _syncLocalMedicationReminders({bool showFeedback = true}) async {
    setState(() => _syncingLocalReminders = true);
    try {
      final l10n = _notificationsL10nOf(context);
      final bundle = await ref.read(profileBundleProvider.future);
      final preferences = await ref.read(
        notificationPreferencesProvider.future,
      );
      final logs = await ref.read(medicationLogsProvider.future);
      if (bundle == null) {
        return;
      }

      final status = await ref
          .read(localMedicationReminderServiceProvider)
          .syncMedicationReminders(
            medications: bundle.medications,
            preferences: preferences,
            logs: logs,
          );
      final entries = await ref.read(dailyEntriesProvider.future);
      final completedToday = entries.any(
        (entry) => DateUtils.isSameDay(entry.entryDate, DateTime.now()),
      );
      await ref
          .read(localMedicationReminderServiceProvider)
          .syncDailyCheckInReminders(
            enabled: preferences.dailyCheckinEnabled,
            completedToday: completedToday,
          );
      await ref
          .read(localMedicationReminderServiceProvider)
          .syncSymptomFollowUpReminders(
            entries: entries,
            enabled: preferences.symptomFollowUpEnabled,
          );
      ref.invalidate(localMedicationReminderStatusProvider);
      if (!mounted || !showFeedback) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.message ??
                l10n.notificationsRemindersCount(status.scheduledCount),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _syncingLocalReminders = false);
      }
    }
  }

  Future<void> _sendTestDelivery() async {
    setState(() => _sendingTestDelivery = true);
    try {
      final preferences = await ref.read(
        notificationPreferencesProvider.future,
      );
      if (!preferences.pushEnabled && !preferences.emailEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _notificationsL10nOf(
                context,
              ).notificationsEnableAtLeastPushOrEmail,
            ),
          ),
        );
        return;
      }

      final report = await ref
          .read(notificationsRepositoryProvider)
          .sendTestDelivery(
            body: {
              'include_push': preferences.pushEnabled,
              'include_email': preferences.emailEnabled,
              'email_address': preferences.emailAddress,
            },
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatDeliveryReport(context, report))),
      );
      ref.invalidate(notificationsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _sendingTestDelivery = false);
      }
    }
  }

  Future<void> _requestLocalPermission() async {
    setState(() => _syncingLocalReminders = true);
    try {
      final status = await ref
          .read(localMedicationReminderServiceProvider)
          .requestPermission();
      ref.invalidate(localMedicationReminderStatusProvider);
      if (status.permissionGranted) {
        await _syncLocalMedicationReminders(showFeedback: false);
      }
      if (!mounted) return;
      final l10n = _notificationsL10nOf(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.permissionGranted
                ? l10n.notificationsNotificationPermissionEnabled
                : (status.message ??
                      l10n.notificationsNotificationPermissionNotGranted),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncingLocalReminders = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _notificationsL10nOf(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final localRemindersAsync = ref.watch(
      localMedicationReminderStatusProvider,
    );
    final profileAsync = ref.watch(profileBundleProvider);
    final dateFormat = _notificationsDateFormat(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications2),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(notificationsProvider);
              ref.invalidate(notificationPreferencesProvider);
              ref.invalidate(localMedicationReminderStatusProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          notificationsAsync.when(
            data: (items) => SectionCard(
              title: l10n.notificationsOverview,
              subtitle: l10n.notificationsNotificationAndReminderStatus,
              action: Tooltip(
                message: l10n.notificationsSendTestNotifications,
                child: FilledButton.tonalIcon(
                  onPressed: _sendingTestDelivery ? null : _sendTestDelivery,
                  icon: _sendingTestDelivery
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(l10n.notificationsTestNotifications),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(l10n.notificationsTotalCount(items.length)),
                      ),
                      Chip(
                        label: Text(
                          l10n.notificationsUnreadCount(
                            items.where((item) => item.isUnread).length,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          items.any((item) => item.isUnread)
                              ? l10n.notificationsNeedAttention
                              : l10n.notificationsAllRead,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => SectionCard(
              title: l10n.notificationsOverview2,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: l10n.notificationsOverview3,
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 16),
          preferencesAsync.when(
            data: (preferences) => SectionCard(
              title: l10n.notificationsReminderPreferences,
              subtitle: l10n.notificationsEnableOnlyWhatYouNeed,
              child: Column(
                children: [
                  if (_savingPreferences)
                    const LinearProgressIndicator(minHeight: 2),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.inAppEnabled,
                    onChanged: (value) =>
                        _updatePreference('in_app_enabled', value),
                    title: Text(l10n.notificationsNotificationsEnabled),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.dailyCheckinEnabled,
                    onChanged: (value) =>
                        _updatePreference('daily_checkin_enabled', value),
                    title: Text(l10n.notificationsCheckInReminders),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.symptomFollowUpEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) => _updatePreference(
                            'symptom_follow_up_enabled',
                            value,
                          )
                        : null,
                    title: Text(l10n.notificationsSymptomFollowUpReminders),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.medicationRemindersEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) => _updatePreference(
                            'medication_reminders_enabled',
                            value,
                          )
                        : null,
                    title: Text(l10n.notificationsMedicationReminders),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.screeningRemindersEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) => _updatePreference(
                            'screening_reminders_enabled',
                            value,
                          )
                        : null,
                    title: Text(l10n.notificationsScreeningReminders),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.documentFollowUpEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) => _updatePreference(
                            'document_follow_up_enabled',
                            value,
                          )
                        : null,
                    title: Text(l10n.notificationsDocumentFollowUp),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.reportReadyEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) =>
                              _updatePreference('report_ready_enabled', value)
                        : null,
                    title: Text(l10n.notificationsReportsReady),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.clinicalAlertsEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) => _updatePreference(
                            'clinical_alerts_enabled',
                            value,
                          )
                        : null,
                    title: Text(
                      l10n.notificationsClinicalAlertsInNotifications,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.preventionTipsEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) => _updatePreference(
                            'prevention_tips_enabled',
                            value,
                          )
                        : null,
                    title: Text(l10n.notificationsPreventionTips),
                  ),
                ],
              ),
            ),
            loading: () => SectionCard(
              title: l10n.notificationsReminderPreferences2,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: l10n.notificationsReminderPreferences3,
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 16),
          localRemindersAsync.when(
            data: (status) => SectionCard(
              title: l10n.notificationsLocalReminders,
              subtitle: l10n.notificationsCreatedOnTheDevice,
              action: TextButton(
                onPressed: _syncingLocalReminders
                    ? null
                    : () => _syncLocalMedicationReminders(),
                child: Text(
                  _syncingLocalReminders ? '...' : l10n.notificationsSync,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_syncingLocalReminders)
                    const LinearProgressIndicator(minHeight: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          status.permissionGranted
                              ? l10n.notificationsPermissionGranted
                              : l10n.notificationsPermissionNeedsToBeEnabled,
                        ),
                      ),
                      Chip(
                        label: Text(
                          l10n.notificationsRemindersCount(
                            status.scheduledCount,
                          ),
                        ),
                      ),
                      if (status.lastSyncedAt != null)
                        Chip(
                          label: Text(
                            l10n.notificationsSyncAt(
                              dateFormat.format(status.lastSyncedAt!.toLocal()),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (status.message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      status.message!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (status.isSupported && !status.permissionGranted) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _syncingLocalReminders
                          ? null
                          : _requestLocalPermission,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(l10n.notificationsEnableNotifications),
                    ),
                  ],
                ],
              ),
            ),
            loading: () => SectionCard(
              title: l10n.notificationsLocalReminders2,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: l10n.notificationsLocalReminders3,
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 16),
          notificationsAsync.when(
            data: (items) {
              final profileLabels = _profileLabelsById(
                profileAsync.asData?.value,
                context,
              );

              if (items.isEmpty) {
                return SectionCard(
                  title: l10n.notifications3,
                  child: Text(l10n.notificationsNoActiveNotifications),
                );
              }

              return SectionCard(
                title: l10n.notificationsLatestNotifications,
                subtitle: l10n.notificationsMostRecentFirst,
                child: Column(
                  children: items.take(12).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card.outlined(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            child: Icon(
                              _iconFor(item.notificationType),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(item.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (profileLabels[item.patientId] != null)
                                    Chip(
                                      label: Text(
                                        profileLabels[item.patientId]!,
                                      ),
                                    ),
                                  Chip(
                                    label: Text(
                                      _priorityLabel(context, item.priority),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      dateFormat.format(
                                        item.createdAt.toLocal(),
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      item.isUnread
                                          ? l10n.notificationsUnread
                                          : l10n.notificationsRead,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: item.isUnread
                              ? FilledButton.tonal(
                                  onPressed: _markingReadId == item.id
                                      ? null
                                      : () => _markRead(item),
                                  child: Text(
                                    _markingReadId == item.id
                                        ? '...'
                                        : l10n.notificationsMarkAsRead,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String notificationType) {
  switch (notificationType) {
    case 'clinical_alert':
      return Icons.notification_important_outlined;
    case 'medication_reminder':
      return Icons.medication_outlined;
    case 'screening_reminder':
      return Icons.health_and_safety_outlined;
    case 'report_ready':
      return Icons.picture_as_pdf_outlined;
    case 'document_follow_up':
      return Icons.upload_file_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

String _priorityLabel(BuildContext context, String priority) {
  final l10n = _notificationsL10nOf(context);
  switch (priority) {
    case 'urgent':
      return l10n.notificationsUrgent;
    case 'high':
      return l10n.notificationsHigh;
    case 'low':
      return l10n.notificationsLow;
    default:
      return l10n.notificationsNormal;
  }
}

Map<String, String> _profileLabelsById(
  ProfileBundle? bundle,
  BuildContext context,
) {
  if (bundle == null) {
    return const {};
  }
  final profiles = bundle.managedProfiles.isNotEmpty
      ? bundle.managedProfiles
      : <PatientProfile>[bundle.profile];
  return {
    for (final profile in profiles) profile.id: _profileLabel(context, profile),
  };
}

String _profileLabel(BuildContext context, PatientProfile profile) {
  final l10n = _notificationsL10nOf(context);
  final parts = <String>[profile.displayName];
  if (profile.relationshipLabel != null &&
      profile.relationshipLabel!.isNotEmpty) {
    parts.add(profile.relationshipLabel!);
  }
  if (profile.isPrimary) {
    parts.add(l10n.primaryProfileLabel.toLowerCase());
  }
  return parts.join(' · ');
}

String _formatDeliveryReport(
  BuildContext context,
  NotificationDeliveryReport report,
) {
  final l10n = _notificationsL10nOf(context);
  final parts = <String>[];
  void appendChannel(NotificationDeliveryChannelResult? result) {
    if (result == null) {
      return;
    }
    final status = result.delivered
        ? l10n.notificationsOk
        : l10n.notificationsError;
    if (result.error != null && result.error!.isNotEmpty) {
      parts.add(
        l10n.notificationsChannelStatusWithError(
          result.channel,
          status,
          result.provider,
          result.error!,
        ),
      );
    } else {
      parts.add(
        l10n.notificationsChannelStatus(
          result.channel,
          status,
          result.provider,
        ),
      );
    }
  }

  appendChannel(report.push);
  appendChannel(report.email);

  if (parts.isEmpty) {
    return l10n.notificationsTestDeliveryCompleted;
  }
  return parts.join(' · ');
}
