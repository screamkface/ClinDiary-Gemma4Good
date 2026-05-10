import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/l10n/app_localizations.dart';
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

AppLocalizations _l10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

DateFormat _safeDateFormat(String pattern, String localeName) {
  try {
    return DateFormat(pattern, localeName);
  } catch (_) {
    return DateFormat(pattern);
  }
}

bool _vaccinationIsItalian(BuildContext context) {
  return isItalianLanguageCode(
    appLanguageCodeFromLocale(Localizations.localeOf(context)),
  );
}

String _vaccinationStatusLabel(BuildContext context, String status) {
  final l10n = _l10nOf(context);
  return switch (status) {
    'up_to_date' => l10n.profileUpToDate,
    'recommended' => l10n.profileToDo,
    'attention' => _vaccinationIsItalian(context) ? 'attenzione' : 'attention',
    _ => l10n.profileToReview2,
  };
}

String _administeredLabel(BuildContext context, String formattedDate) {
  return _vaccinationIsItalian(context)
      ? 'Somministrato $formattedDate'
      : 'Administered $formattedDate';
}

String _doseLabel(BuildContext context, Object doseNumber) {
  return '${_l10nOf(context).profileDose} $doseNumber';
}

String _boosterLabel(BuildContext context, String formattedDate) {
  return _vaccinationIsItalian(context)
      ? 'Richiamo $formattedDate'
      : 'Booster $formattedDate';
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteVaccination(VaccinationRecordItem item) async {
    final l10n = _l10nOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileRemoveVaccination),
        content: Text(l10n.profileTheItemWillBeRemovedFrom5),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(l10n.profileCancel10),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: Text(l10n.profileRemove5),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<Map<String, dynamic>?> _showVaccinationDialog({
    VaccinationRecordItem? initial,
  }) async {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VaccinationFormSheet(initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final profileAsync = ref.watch(profileBundleProvider);
    final preventionAsync = ref.watch(preventionCenterProvider);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final dateFormat = _safeDateFormat(l10n.profileDdMmmYyyy3, localeName);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileVaccinationHistory),
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
            return Center(
              child: Text(l10n.profileCompleteTheProfileToManageVaccinations),
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
                _VaccinationHeroCard(onAdd: () => _saveVaccination()),
                const SizedBox(height: 12),
                preventionAsync.when(
                  data: (center) => SectionCard(
                    title: l10n.profileVaccinationRegistry,
                    subtitle: l10n.profileSummaryStatusDerivedFromHistory,
                    child: center.vaccineRegistry.isEmpty
                        ? Text(l10n.profileNoVaccinationSummaryAvailable)
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
                  title: l10n.profileRecordedVaccinations,
                  action: FilledButton.tonalIcon(
                    onPressed: () => _saveVaccination(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.add),
                  ),
                  child: bundle.vaccinations.isEmpty
                      ? Text(l10n.profileNoVaccinationRecorded)
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
                                            l10n.profilePendingSync9,
                                          if (item.administeredOn != null)
                                            _administeredLabel(
                                              context,
                                              dateFormat.format(
                                                item.administeredOn!,
                                              ),
                                            ),
                                          if (item.doseNumber != null)
                                            _doseLabel(
                                              context,
                                              item.doseNumber!,
                                            ),
                                          if (item.nextDueDate != null)
                                            _boosterLabel(
                                              context,
                                              dateFormat.format(
                                                item.nextDueDate!,
                                              ),
                                            ),
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
                                              tooltip: l10n.profileEdit4,
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
                                                  ? l10n.profilePendingSync10
                                                  : l10n.profileRemove6,
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

class _VaccinationFormSheet extends StatefulWidget {
  const _VaccinationFormSheet({this.initial});

  final VaccinationRecordItem? initial;

  @override
  State<_VaccinationFormSheet> createState() => _VaccinationFormSheetState();
}

class _VaccinationFormSheetState extends State<_VaccinationFormSheet> {
  late final TextEditingController _vaccineNameController;
  late final TextEditingController _doseNumberController;
  late final TextEditingController _providerController;
  late final TextEditingController _notesController;
  DateTime? _administeredOn;
  DateTime? _nextDueDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _vaccineNameController = TextEditingController(
      text: initial?.vaccineName ?? '',
    );
    _doseNumberController = TextEditingController(
      text: initial?.doseNumber?.toString() ?? '',
    );
    _providerController = TextEditingController(
      text: initial?.providerName ?? '',
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _administeredOn = initial?.administeredOn;
    _nextDueDate = initial?.nextDueDate;
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _doseNumberController.dispose();
    _providerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool nextBooster}) async {
    final l10n = _l10nOf(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: nextBooster
          ? _nextDueDate ?? DateTime.now()
          : _administeredOn ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: Localizations.localeOf(context),
      helpText: nextBooster
          ? l10n.profileSelectNextBooster
          : l10n.profileSelectDate,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      if (nextBooster) {
        _nextDueDate = picked;
      } else {
        _administeredOn = picked;
      }
    });
  }

  void _save() {
    final l10n = _l10nOf(context);
    final name = _vaccineNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileEnterTheVaccineName)));
      return;
    }

    Navigator.of(context).pop({
      'vaccine_name': name,
      'administered_on': _administeredOn?.toIso8601String().split('T').first,
      'dose_number': _doseNumberController.text.trim().isEmpty
          ? null
          : int.tryParse(_doseNumberController.text.trim()),
      'next_due_date': _nextDueDate?.toIso8601String().split('T').first,
      'provider_name': _providerController.text.trim().isEmpty
          ? null
          : _providerController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final dateFormat = _safeDateFormat(l10n.profileDdMmYyyy5, localeName);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initial == null
                  ? l10n.profileAddVaccine
                  : l10n.profileEditVaccine,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.profileOnlyTheNameIsRequiredYou,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vaccineNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.profileVaccineName,
                hintText: l10n.profileExampleInfluenza,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doseNumberController,
              decoration: InputDecoration(labelText: l10n.profileDose),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _VaccinationDateTile(
              title: l10n.profileDate,
              value: _administeredOn == null
                  ? l10n.profileChooseDate
                  : dateFormat.format(_administeredOn!),
              icon: Icons.event_outlined,
              onTap: () => _pickDate(nextBooster: false),
            ),
            const SizedBox(height: 8),
            _VaccinationDateTile(
              title: l10n.profileNextBooster,
              value: _nextDueDate == null
                  ? l10n.profileOptional
                  : dateFormat.format(_nextDueDate!),
              icon: Icons.schedule_outlined,
              onTap: () => _pickDate(nextBooster: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _providerController,
              decoration: InputDecoration(labelText: l10n.profilePlaceOrDoctor),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: l10n.profileNote2),
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(l10n.profileCancel11),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(l10n.profileSave8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VaccinationDateTile extends StatelessWidget {
  const _VaccinationDateTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _VaccinationHeroCard extends StatelessWidget {
  const _VaccinationHeroCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFFFF7A59);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.98, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.vaccines_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileAddAVaccineInSeconds,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.profileNameDateDoseAndNextBooster,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.profileAddVaccine2),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      _ => _vaccinationStatusLabel(context, status),
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
