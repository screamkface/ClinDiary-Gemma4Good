import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/notifications/domain/app_notification.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _savingPreferences = false);
      }
    }
  }

  Future<void> _syncLocalMedicationReminders({bool showFeedback = true}) async {
    setState(() => _syncingLocalReminders = true);
    try {
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
      ref.invalidate(localMedicationReminderStatusProvider);
      if (!mounted || !showFeedback) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.message ??
                'Medication reminders synced (${status.scheduledCount}).',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
          const SnackBar(
            content: Text('Enable at least push or email to run the test.'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatDeliveryReport(report))));
      ref.invalidate(notificationsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.permissionGranted
                ? 'Notification permission enabled.'
                : (status.message ?? 'Notification permission not granted.'),
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
    final notificationsAsync = ref.watch(notificationsProvider);
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final localRemindersAsync = ref.watch(
      localMedicationReminderStatusProvider,
    );
    final profileAsync = ref.watch(profileBundleProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
              title: 'Overview',
              subtitle: 'Notification and reminder status.',
              action: Tooltip(
                message: 'Send test notifications',
                child: FilledButton.tonalIcon(
                  onPressed: _sendingTestDelivery ? null : _sendTestDelivery,
                  icon: _sendingTestDelivery
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Test notifications'),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('${items.length} total')),
                      Chip(
                        label: Text(
                          '${items.where((item) => item.isUnread).length} unread',
                        ),
                      ),
                      Chip(
                        label: Text(
                          items.any((item) => item.isUnread)
                              ? 'Need attention'
                              : 'All read',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const SectionCard(
              title: 'Overview',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                SectionCard(title: 'Overview', child: Text(error.toString())),
          ),
          const SizedBox(height: 16),
          preferencesAsync.when(
            data: (preferences) => SectionCard(
              title: 'Reminder preferences',
              subtitle: 'Enable only what you need.',
              child: Column(
                children: [
                  if (_savingPreferences)
                    const LinearProgressIndicator(minHeight: 2),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.inAppEnabled,
                    onChanged: (value) =>
                        _updatePreference('in_app_enabled', value),
                    title: const Text('Notifications enabled'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.dailyCheckinEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) =>
                              _updatePreference('daily_checkin_enabled', value)
                        : null,
                    title: const Text('Check-in reminders'),
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
                    title: const Text('Medication reminders'),
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
                    title: const Text('Screening reminders'),
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
                    title: const Text('Document follow-up'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.reportReadyEnabled,
                    onChanged: preferences.inAppEnabled
                        ? (value) =>
                              _updatePreference('report_ready_enabled', value)
                        : null,
                    title: const Text('Reports ready'),
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
                    title: const Text('Clinical alerts in notifications'),
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
                    title: const Text('Prevention tips'),
                  ),
                ],
              ),
            ),
            loading: () => const SectionCard(
              title: 'Reminder preferences',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Reminder preferences',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 16),
          localRemindersAsync.when(
            data: (status) => SectionCard(
              title: 'Local medication reminders',
              subtitle: 'Created on the device.',
              action: TextButton(
                onPressed: _syncingLocalReminders
                    ? null
                    : () => _syncLocalMedicationReminders(),
                child: Text(_syncingLocalReminders ? '...' : 'Sync'),
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
                              ? 'Permission granted'
                              : 'Permission needs to be enabled',
                        ),
                      ),
                      Chip(label: Text('${status.scheduledCount} reminders')),
                      if (status.lastSyncedAt != null)
                        Chip(
                          label: Text(
                            'Sync ${dateFormat.format(status.lastSyncedAt!.toLocal())}',
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
                      label: const Text('Enable notifications'),
                    ),
                  ],
                ],
              ),
            ),
            loading: () => const SectionCard(
              title: 'Local medication reminders',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Local medication reminders',
              child: Text(error.toString()),
            ),
          ),
          const SizedBox(height: 16),
          notificationsAsync.when(
            data: (items) {
              final profileLabels = _profileLabelsById(
                profileAsync.asData?.value,
              );

              if (items.isEmpty) {
                return const SectionCard(
                  title: 'Notifications',
                  child: Text('No active notifications.'),
                );
              }

              return SectionCard(
                title: 'Latest notifications',
                subtitle: 'Most recent first.',
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
                                    label: Text(_priorityLabel(item.priority)),
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
                                      item.isUnread ? 'Unread' : 'Read',
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
                                        : 'Mark as read',
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

String _priorityLabel(String priority) {
  switch (priority) {
    case 'urgent':
      return 'Urgent';
    case 'high':
      return 'High';
    case 'low':
      return 'Low';
    default:
      return 'Normal';
  }
}

Map<String, String> _profileLabelsById(ProfileBundle? bundle) {
  if (bundle == null) {
    return const {};
  }
  final profiles = bundle.managedProfiles.isNotEmpty
      ? bundle.managedProfiles
      : <PatientProfile>[bundle.profile];
  return {for (final profile in profiles) profile.id: _profileLabel(profile)};
}

String _profileLabel(PatientProfile profile) {
  final parts = <String>[profile.displayName];
  if (profile.relationshipLabel != null &&
      profile.relationshipLabel!.isNotEmpty) {
    parts.add(profile.relationshipLabel!);
  }
  if (profile.isPrimary) {
    parts.add('primary');
  }
  return parts.join(' · ');
}

String _formatDeliveryReport(NotificationDeliveryReport report) {
  final parts = <String>[];
  void appendChannel(NotificationDeliveryChannelResult? result) {
    if (result == null) {
      return;
    }
    final status = result.delivered ? 'ok' : 'error';
    final chunk = '${result.channel}: $status (${result.provider})';
    if (result.error != null && result.error!.isNotEmpty) {
      parts.add('$chunk - ${result.error}');
    } else {
      parts.add(chunk);
    }
  }

  appendChannel(report.push);
  appendChannel(report.email);

  if (parts.isEmpty) {
    return 'Invio test completato.';
  }
  return parts.join(' · ');
}
