import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VaccinationHistoryScreen extends ConsumerStatefulWidget {
  const VaccinationHistoryScreen({super.key});

  @override
  ConsumerState<VaccinationHistoryScreen> createState() =>
      _VaccinationHistoryScreenState();
}

class _VaccinationHistoryScreenState
    extends ConsumerState<VaccinationHistoryScreen> {
  Future<void> _saveVaccination({VaccinationRecordItem? initial}) async {
    final result = await _showVaccinationDialog(initial: initial);
    if (!mounted || result == null) {
      return;
    }

    try {
      if (initial == null) {
        await ref.read(profileRepositoryProvider).addVaccination(result);
      } else {
        await ref
            .read(profileRepositoryProvider)
            .updateVaccination(initial.id, result);
      }
      ref.invalidate(profileBundleProvider);
      ref.invalidate(healthDossierProvider);
      ref.invalidate(preventionCenterProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteVaccination(VaccinationRecordItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rimuovere vaccino?'),
        content: const Text('La voce verra rimossa dallo storico vaccinale.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(profileRepositoryProvider).deleteVaccination(item.id);
      ref.invalidate(profileBundleProvider);
      ref.invalidate(healthDossierProvider);
      ref.invalidate(preventionCenterProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<Map<String, dynamic>?> _showVaccinationDialog({
    VaccinationRecordItem? initial,
  }) async {
    final vaccineNameController = TextEditingController(
      text: initial?.vaccineName ?? '',
    );
    final doseNumberController = TextEditingController(
      text: initial?.doseNumber?.toString() ?? '',
    );
    final providerController = TextEditingController(
      text: initial?.providerName ?? '',
    );
    final notesController = TextEditingController(text: initial?.notes ?? '');
    DateTime? administeredOn = initial?.administeredOn;
    DateTime? nextDueDate = initial?.nextDueDate;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(initial == null ? 'Nuovo vaccino' : 'Modifica vaccino'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: vaccineNameController,
                  decoration: const InputDecoration(labelText: 'Nome vaccino'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: doseNumberController,
                  decoration: const InputDecoration(labelText: 'Numero dose'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data somministrazione'),
                  subtitle: Text(
                    administeredOn == null
                        ? 'Non impostata'
                        : DateFormat('dd/MM/yyyy').format(administeredOn!),
                  ),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: administeredOn ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: 'Seleziona data somministrazione',
                    );
                    if (picked != null) {
                      setState(() => administeredOn = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prossimo richiamo'),
                  subtitle: Text(
                    nextDueDate == null
                        ? 'Non impostato'
                        : DateFormat('dd/MM/yyyy').format(nextDueDate!),
                  ),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: nextDueDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      helpText: 'Seleziona prossimo richiamo',
                    );
                    if (picked != null) {
                      setState(() => nextDueDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: providerController,
                  decoration: const InputDecoration(
                    labelText: 'Struttura / operatore',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
                rootNavigator: true,
              ).pop(null),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final name = vaccineNameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inserisci il nome del vaccino.'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext, rootNavigator: true).pop({
                  'vaccine_name': name,
                  'administered_on': administeredOn
                      ?.toIso8601String()
                      .split('T')
                      .first,
                  'dose_number': doseNumberController.text.trim().isEmpty
                      ? null
                      : int.tryParse(doseNumberController.text.trim()),
                  'next_due_date': nextDueDate
                      ?.toIso8601String()
                      .split('T')
                      .first,
                  'provider_name': providerController.text.trim().isEmpty
                      ? null
                      : providerController.text.trim(),
                  'notes': notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                });
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    vaccineNameController.dispose();
    doseNumberController.dispose();
    providerController.dispose();
    notesController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileBundleProvider);
    final preventionAsync = ref.watch(preventionCenterProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico vaccinale'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(profileBundleProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return const Center(
              child: Text('Completa il profilo per gestire i vaccini.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileBundleProvider);
              ref.invalidate(healthDossierProvider);
              ref.invalidate(preventionCenterProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                preventionAsync.when(
                  data: (center) => SectionCard(
                    title: 'Registro vaccinale',
                    subtitle: 'Stato sintetico ricavato dallo storico.',
                    child: center.vaccineRegistry.isEmpty
                        ? const Text('Nessun riepilogo vaccinale disponibile.')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: center.vaccineRegistry
                                .map(
                                  (item) => _VaccineRegistryChip(
                                    title: item.title,
                                    status: item.status,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Vaccini registrati',
                  action: FilledButton.tonalIcon(
                    onPressed: () => _saveVaccination(),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi'),
                  ),
                  child: bundle.vaccinations.isEmpty
                      ? const Text('Nessun vaccino registrato.')
                      : Column(
                          children: bundle.vaccinations
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Card.outlined(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      title: Text(item.vaccineName),
                                      subtitle: Text(
                                        [
                                          if (item.pendingSync)
                                            'In attesa di sincronizzazione',
                                          if (item.administeredOn != null)
                                            'Somministrato ${dateFormat.format(item.administeredOn!)}',
                                          if (item.doseNumber != null)
                                            'Dose ${item.doseNumber}',
                                          if (item.nextDueDate != null)
                                            'Richiamo ${dateFormat.format(item.nextDueDate!)}',
                                          if (item.providerName?.isNotEmpty ==
                                              true)
                                            item.providerName!,
                                          if (item.notes?.isNotEmpty == true)
                                            item.notes!,
                                        ].join(' • '),
                                      ),
                                      trailing: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Modifica',
                                              onPressed: item.pendingSync
                                                  ? null
                                                  : () => _saveVaccination(
                                                      initial: item,
                                                    ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: item.pendingSync
                                                  ? 'In attesa di sincronizzazione'
                                                  : 'Rimuovi',
                                              onPressed: item.pendingSync
                                                  ? null
                                                  : () => _deleteVaccination(
                                                      item,
                                                    ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _VaccineRegistryChip extends StatelessWidget {
  const _VaccineRegistryChip({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'up_to_date' => Colors.green,
      'recommended' => colorScheme.primary,
      'attention' => colorScheme.error,
      _ => colorScheme.secondary,
    };
    final label = switch (status) {
      'up_to_date' => 'in regola',
      'recommended' => 'da fare',
      'attention' => 'attenzione',
      _ => 'da rivedere',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
