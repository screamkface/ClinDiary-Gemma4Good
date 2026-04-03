import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  String? _busyMedicationId;
  String? _busyScheduleId;

  Future<void> _refreshMedicationState() async {
    ref.invalidate(profileBundleProvider);
    ref.invalidate(medicationLogsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(localMedicationReminderStatusProvider);

    final bundle = await ref.read(profileBundleProvider.future);
    final preferences = await ref.read(notificationPreferencesProvider.future);
    final logs = await ref.read(medicationLogsProvider.future);
    if (bundle == null) {
      return;
    }
    await ref
        .read(localMedicationReminderServiceProvider)
        .syncMedicationReminders(
          medications: bundle.medications,
          preferences: preferences,
          logs: logs,
        );
    ref.invalidate(localMedicationReminderStatusProvider);
  }

  Future<void> _logMedication(
    MedicationItem medication,
    String status, {
    String? notes,
  }) async {
    setState(() => _busyMedicationId = medication.id);
    try {
      final result = await ref
          .read(medicationsRepositoryProvider)
          .logMedication(
            medicationId: medication.id,
            medicationName: medication.name,
            medicationDosage: medication.dosage,
            status: status,
            notes: notes,
          );
      await ref
          .read(localMedicationReminderServiceProvider)
          .cancelMedicationRemindersForDate(
            medicationId: medication.id,
            targetDate: DateTime.now(),
          );
      await _refreshMedicationState();
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      if (result.pendingSync) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Salvato offline. ClinDiary sincronizzera appena torna la rete.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyMedicationId = null);
      }
    }
  }

  Future<void> _updateSchedule(
    MedicationItem medication,
    MedicationScheduleItem schedule,
    Map<String, dynamic> body,
  ) async {
    setState(() => _busyScheduleId = schedule.id);
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .updateSchedule(
            medicationId: medication.id,
            scheduleId: schedule.id,
            body: body,
          );
      await _refreshMedicationState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Orario aggiornato.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyScheduleId = null);
      }
    }
  }

  Future<void> _pauseSchedule(
    MedicationItem medication,
    MedicationScheduleItem schedule,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: schedule.pausedUntil ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) {
      return;
    }
    setState(() => _busyScheduleId = schedule.id);
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .pauseSchedule(
            medicationId: medication.id,
            scheduleId: schedule.id,
            pausedUntil: picked,
          );
      await _refreshMedicationState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Promemoria in pausa fino al ${DateFormat('dd/MM/yyyy').format(picked)}.',
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
        setState(() => _busyScheduleId = null);
      }
    }
  }

  Future<void> _resumeSchedule(
    MedicationItem medication,
    MedicationScheduleItem schedule,
  ) async {
    setState(() => _busyScheduleId = schedule.id);
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .resumeSchedule(medicationId: medication.id, scheduleId: schedule.id);
      await _refreshMedicationState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Promemoria riattivato.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyScheduleId = null);
      }
    }
  }

  Future<void> _deleteSchedule(
    MedicationItem medication,
    MedicationScheduleItem schedule,
  ) async {
    final confirmed = await _confirmRemoval(
      title: 'Rimuovere orario?',
      message: 'L’orario ${schedule.compactLabel} verra eliminato.',
    );
    if (!confirmed) {
      return;
    }

    setState(() => _busyScheduleId = schedule.id);
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .deleteSchedule(medicationId: medication.id, scheduleId: schedule.id);
      await _refreshMedicationState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Orario rimosso.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyScheduleId = null);
      }
    }
  }

  Future<void> _deleteMedication(MedicationItem medication) async {
    final confirmed = await _confirmRemoval(
      title: 'Rimuovere farmaco?',
      message:
          'La terapia ${medication.name} e i relativi promemoria verranno rimossi.',
    );
    if (!confirmed) {
      return;
    }

    setState(() => _busyMedicationId = medication.id);
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .deleteMedication(medication.id);
      await _refreshMedicationState();
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medication.name} rimosso dal profilo.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyMedicationId = null);
      }
    }
  }

  Future<void> _showScheduleEditor(
    MedicationItem medication,
    MedicationScheduleItem schedule,
  ) async {
    final instructionsController = TextEditingController(
      text: schedule.instructions ?? '',
    );
    var selectedTime = _parseScheduleTime(schedule.scheduledTime);
    var active = schedule.active;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text('Orario ${medication.name}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Orario'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: dialogContext,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setModalState(() => selectedTime = picked);
                    }
                  },
                ),
                TextField(
                  controller: instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Istruzioni',
                    hintText: 'Es. dopo cena',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setModalState(() => active = value),
                  title: const Text('Schedule attiva'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).maybePop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                await _updateSchedule(medication, schedule, {
                  'scheduled_time':
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00',
                  'instructions': instructionsController.text.trim().isEmpty
                      ? null
                      : instructionsController.text.trim(),
                  'active': active,
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).maybePop();
                }
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptMedicationLog(
    MedicationItem medication,
    String status,
  ) async {
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          status == 'taken' ? 'Conferma assunzione' : 'Registra dose saltata',
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: status == 'taken'
                  ? 'Note opzionali'
                  : 'Motivo o note opzionali',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).maybePop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              await _logMedication(
                medication,
                status,
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext, rootNavigator: true).maybePop();
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRemoval({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileBundleProvider);
    final logsAsync = ref.watch(medicationLogsProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');
    final recentLogs = logsAsync.asData?.value ?? const <MedicationLogItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmaci'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(profileBundleProvider);
              ref.invalidate(medicationLogsProvider);
              ref.invalidate(notificationsProvider);
              ref.invalidate(localMedicationReminderStatusProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          profileAsync.when(
            data: (bundle) => SectionCard(
              title: 'Terapia',
              subtitle: 'Farmaci attivi e promemoria.',
              child: bundle == null || bundle.medications.isEmpty
                  ? const Text('Nessuna terapia attiva registrata.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                '${bundle.medications.where((item) => item.active).length} attivi',
                              ),
                            ),
                            Chip(
                              label: Text('${recentLogs.length} registrazioni'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...bundle.medications.where((item) => item.active).map((
                          item,
                        ) {
                          final todayLog = _todayLogForMedication(
                            item.id,
                            recentLogs,
                          );
                          final details = [
                            if (item.dosage != null && item.dosage!.isNotEmpty)
                              item.dosage!,
                            if (item.frequency != null &&
                                item.frequency!.isNotEmpty)
                              item.frequency!,
                            if (item.route != null && item.route!.isNotEmpty)
                              item.route!,
                            if (item.pendingSync)
                              'In attesa di sincronizzazione',
                          ];

                          return Card.outlined(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        enabled: !item.pendingSync,
                                        onSelected: (value) {
                                          if (value == 'delete') {
                                            _deleteMedication(item);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Rimuovi farmaco'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final detail in details)
                                        Chip(label: Text(detail)),
                                      if (todayLog != null)
                                        Chip(
                                          label: Text(
                                            'Oggi ${_adherenceLabel(todayLog.status)}',
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (item.schedules.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Column(
                                      children: item.schedules
                                          .where(
                                            (schedule) =>
                                                schedule.active ||
                                                schedule.pausedUntil != null,
                                          )
                                          .map((schedule) {
                                            final scheduleBusy =
                                                _busyScheduleId == schedule.id;
                                            return Card.outlined(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                title: Text(
                                                  schedule.compactLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle: Text(
                                                  schedule.instructions ??
                                                      (schedule.pausedUntil ==
                                                              null
                                                          ? 'Attivo'
                                                          : 'In pausa'),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                trailing: PopupMenuButton<String>(
                                                  enabled:
                                                      !scheduleBusy &&
                                                      !item.pendingSync,
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _showScheduleEditor(
                                                        item,
                                                        schedule,
                                                      );
                                                    } else if (value ==
                                                        'pause') {
                                                      _pauseSchedule(
                                                        item,
                                                        schedule,
                                                      );
                                                    } else if (value ==
                                                        'resume') {
                                                      _resumeSchedule(
                                                        item,
                                                        schedule,
                                                      );
                                                    } else if (value ==
                                                        'delete') {
                                                      _deleteSchedule(
                                                        item,
                                                        schedule,
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('Modifica'),
                                                    ),
                                                    PopupMenuItem(
                                                      value:
                                                          schedule.pausedUntil !=
                                                              null
                                                          ? 'resume'
                                                          : 'pause',
                                                      child: Text(
                                                        schedule.pausedUntil !=
                                                                null
                                                            ? 'Riprendi'
                                                            : 'Metti in pausa',
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text(
                                                        'Rimuovi orario',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      FilledButton.icon(
                                        onPressed:
                                            _busyMedicationId == item.id ||
                                                todayLog != null ||
                                                item.pendingSync
                                            ? null
                                            : () => _promptMedicationLog(
                                                item,
                                                'taken',
                                              ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: Text(
                                          _busyMedicationId == item.id
                                              ? '...'
                                              : (todayLog == null
                                                    ? 'Segna assunta'
                                                    : 'Già registrata'),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _busyMedicationId == item.id ||
                                                todayLog != null ||
                                                item.pendingSync
                                            ? null
                                            : () => _promptMedicationLog(
                                                item,
                                                'skipped',
                                              ),
                                        icon: const Icon(
                                          Icons.event_busy_outlined,
                                        ),
                                        label: const Text('Saltata'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
            loading: () => const SectionCard(
              title: 'Terapia',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                SectionCard(title: 'Terapia', child: Text(error.toString())),
          ),
          const SizedBox(height: 16),
          logsAsync.when(
            data: (logs) => SectionCard(
              title: 'Storico aderenza',
              subtitle: 'Ultime conferme.',
              child: logs.isEmpty
                  ? const Text('Ancora nessuna conferma di assunzione.')
                  : Column(
                      children: logs.take(6).map((log) {
                        return Card.outlined(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text(log.medicationName),
                            subtitle: Text(
                              '${_adherenceLabel(log.status)}${log.pendingSync ? ' • In attesa sync' : ''} • ${dateFormat.format(log.scheduledAt.toLocal())}${log.notes == null ? '' : '\n${log.notes}'}',
                            ),
                            trailing: Text(
                              log.medicationDosage ?? '',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            loading: () => const SectionCard(
              title: 'Storico aderenza',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SectionCard(
              title: 'Storico aderenza',
              child: Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

String _adherenceLabel(String status) {
  switch (status) {
    case 'taken':
      return 'Assunta';
    case 'skipped':
      return 'Saltata';
    case 'missed':
      return 'Non confermata';
    default:
      return status;
  }
}

MedicationLogItem? _todayLogForMedication(
  String medicationId,
  List<MedicationLogItem> logs,
) {
  final today = DateUtils.dateOnly(DateTime.now());
  for (final log in logs) {
    if (log.medicationId != medicationId) {
      continue;
    }
    if (DateUtils.isSameDay(log.scheduledAt.toLocal(), today)) {
      return log;
    }
  }
  return null;
}

TimeOfDay _parseScheduleTime(String raw) {
  final parts = raw.split(':');
  final hour = int.tryParse(parts.first) ?? 8;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour, minute: minute);
}
