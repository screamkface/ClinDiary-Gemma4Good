import 'package:clindiary/app/core/localization/app_language.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/l10n/app_localizations.dart';
import 'package:clindiary/shared/widgets/compact_segmented_control.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

AppLocalizations _profileL10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

String _profileBiologicalSexLabel(BuildContext context, String value) {
  final l10n = _profileL10nOf(context);
  return switch (value) {
    'female' => l10n.profileFemale2,
    'male' => l10n.profileMale2,
    'intersex' => l10n.profileIntersex2,
    'unknown' => l10n.profileNotSpecified2,
    _ => value,
  };
}

String _profileActivityLevelLabel(BuildContext context, String value) {
  final l10n = _profileL10nOf(context);
  return switch (value) {
    'sedentary' => l10n.profileSedentary,
    'light' => l10n.profileLight,
    'moderate' => l10n.profileModerate,
    'active' => l10n.profileActive2,
    'very_active' => l10n.profileVeryActive,
    _ => value,
  };
}

String _profileAlcoholUseLabel(BuildContext context, String value) {
  final l10n = _profileL10nOf(context);
  return switch (value) {
    'none' => l10n.profileNone,
    'occasional' => l10n.profileOccasional,
    'moderate' => l10n.profileModerate2,
    'high' => l10n.profileHigh,
    _ => value,
  };
}

String _profileConditionStatusLabel(BuildContext context, String value) {
  final l10n = _profileL10nOf(context);
  return switch (value) {
    'active' => l10n.profileActive4,
    'monitoring' => l10n.profileMonitoring2,
    'resolved' => l10n.profileResolved2,
    _ => value,
  };
}

String _profileSeverityLabel(BuildContext context, String value) {
  final l10n = _profileL10nOf(context);
  return switch (value) {
    'mild' => l10n.profileMild,
    'moderate' => l10n.profileModerate3,
    'severe' => l10n.profileSevere,
    _ => value,
  };
}

List<String> _profileWeekdayLabels(BuildContext context) {
  final l10n = _profileL10nOf(context);
  return [
    l10n.profileMon,
    l10n.profileTue,
    l10n.profileWed,
    l10n.profileThu,
    l10n.profileFri,
    l10n.profileSat,
    l10n.profileSun,
  ];
}

String _profileItemsCountLabel(BuildContext context, int count) {
  final l10n = _profileL10nOf(context);
  if (count == 0) {
    return l10n.profile0Items;
  }
  return l10n.profileItemsCount(count);
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = _l10nOf(context);
    final profileAsync = ref.watch(profileBundleProvider);
    final pendingOperationsAsync = ref.watch(pendingOperationsProvider);
    final localeName = appDateFormattingLocaleName(
      appLanguageCodeFromLocale(Localizations.localeOf(context)),
    );
    final dateFormat = _safeDateFormat(l10n.profileDdMmYyyy4, localeName);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileProfile),
          actions: [
            IconButton(
              onPressed: () => ref.invalidate(profileBundleProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.profileSummary),
              Tab(text: l10n.profileContext),
              Tab(text: l10n.profileClinical),
            ],
          ),
        ),
        body: profileAsync.when(
          data: (bundle) {
            if (bundle == null) {
              return Center(
                child: Text(l10n.profileCompleteAuthenticationToViewTheProfile),
              );
            }
            final pendingCount =
                pendingOperationsAsync.asData?.value.length ?? 0;
            return TabBarView(
              children: [
                _ProfileTabList(
                  children: [
                    SectionCard(
                      title: l10n.profileActiveProfile,
                      action: TextButton.icon(
                        onPressed: () =>
                            _showEditProfileDialog(context, ref, bundle),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.profileEdit2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bundle.profile.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.profileYourClinicalProfileStartsHere,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _ProfileHeaderAvatar(
                                label: bundle.profile.displayName,
                                isPrimary: bundle.profile.isPrimary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ProfileMetricCard(
                                label: l10n.profileAllergies,
                                value: bundle.allergies.length.toString(),
                              ),
                              _ProfileMetricCard(
                                label: l10n.profileConditions,
                                value: bundle.medicalConditions.length
                                    .toString(),
                              ),
                              _ProfileMetricCard(
                                label: l10n.medications,
                                value: bundle.medications.length.toString(),
                              ),
                              _ProfileMetricCard(
                                label: l10n.profileFamilyHistory,
                                value: bundle.familyHistory.length.toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _summaryFacts(
                              context,
                              bundle,
                              pendingOperations: pendingCount,
                              dateFormat: dateFormat,
                            ).map((label) => _InfoChip(label: label)).toList(),
                          ),
                          const SizedBox(height: 14),
                          Text(l10n.profileGoStraightToWhatYouNeed),
                          const SizedBox(height: 10),
                          const _ProfileShortcutGrid(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: l10n.profileQuickFacts,
                      subtitle: l10n.profileValuesAndSettingsUsedInRecaps,
                      child: _ProfileQuickFactsSection(
                        bundle: bundle,
                        pendingOperations: pendingCount,
                        dateFormat: dateFormat,
                      ),
                    ),
                  ],
                ),
                _ProfileTabList(
                  children: [
                    SectionCard(
                      title: l10n.profileContext2,
                      subtitle: l10n.profileHabitsTriggersAndLimitsUsedTo,
                      action: TextButton(
                        onPressed: () =>
                            _showEditProfileDialog(context, ref, bundle),
                        child: Text(l10n.profileEdit3),
                      ),
                      child: _ProfileContextSection(profile: bundle.profile),
                    ),
                  ],
                ),
                _ProfileTabList(
                  children: [
                    _ProfileClinicalSwitcher(
                      allergies: bundle.allergies
                          .map(
                            (item) => _ResourceItem(
                              id: item.id,
                              title: item.allergen,
                              subtitle: [
                                if (item.pendingSync) l10n.profilePendingSync,
                                if (item.severity != null)
                                  _profileSeverityLabel(
                                    context,
                                    item.severity!,
                                  ),
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty)
                                  item.notes!,
                              ].join(' • '),
                              pendingSync: item.pendingSync,
                            ),
                          )
                          .toList(),
                      conditions: bundle.medicalConditions
                          .map(
                            (item) => _ResourceItem(
                              id: item.id,
                              title: item.name,
                              subtitle: [
                                if (item.pendingSync) l10n.profilePendingSync,
                                if (item.status != null)
                                  _profileConditionStatusLabel(
                                    context,
                                    item.status!,
                                  ),
                                if (item.diagnosisDate != null)
                                  dateFormat.format(item.diagnosisDate!),
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty)
                                  item.notes!,
                              ].join(' • '),
                              pendingSync: item.pendingSync,
                            ),
                          )
                          .toList(),
                      medications: bundle.medications.map((item) {
                        final schedule = item.schedules.isEmpty
                            ? null
                            : item.schedules.first.compactLabel;
                        return _ResourceItem(
                          id: item.id,
                          title: item.name,
                          subtitle: [
                            if (item.pendingSync) l10n.profilePendingSync,
                            if (item.dosage != null && item.dosage!.isNotEmpty)
                              item.dosage!,
                            if (item.frequency != null &&
                                item.frequency!.isNotEmpty)
                              item.frequency!,
                            if (schedule != null) schedule,
                          ].join(' • '),
                          pendingSync: item.pendingSync,
                        );
                      }).toList(),
                      familyHistory: bundle.familyHistory
                          .map(
                            (item) => _ResourceItem(
                              id: item.id,
                              title: item.conditionName,
                              subtitle: [
                                if (item.pendingSync) l10n.profilePendingSync,
                                item.relation,
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty)
                                  item.notes!,
                              ].join(' • '),
                              pendingSync: item.pendingSync,
                            ),
                          )
                          .toList(),
                      onAddAllergy: () =>
                          _showCreateAllergyDialog(context, ref),
                      onDeleteAllergy: (itemId) =>
                          _deleteAllergy(context, ref, allergyId: itemId),
                      onAddCondition: () =>
                          _showCreateConditionDialog(context, ref),
                      onDeleteCondition: (itemId) =>
                          _deleteCondition(context, ref, conditionId: itemId),
                      onAddMedication: () =>
                          _showCreateMedicationDialog(context, ref),
                      onDeleteMedication: (itemId) =>
                          _deleteMedication(context, ref, medicationId: itemId),
                      onAddFamilyHistory: () =>
                          _showCreateFamilyHistoryDialog(context, ref),
                      onDeleteFamilyHistory: (itemId) => _deleteFamilyHistory(
                        context,
                        ref,
                        familyHistoryId: itemId,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }

  Future<void> _deleteAllergy(
    BuildContext context,
    WidgetRef ref, {
    required String allergyId,
  }) async {
    final l10n = _l10nOf(context);
    final confirmed = await _confirmDeletion(
      context,
      title: l10n.profileRemoveAllergy,
      message: l10n.profileTheItemWillBeRemovedFrom2,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(profileRepositoryProvider).deleteAllergy(allergyId);
      ref.invalidate(profileBundleProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteCondition(
    BuildContext context,
    WidgetRef ref, {
    required String conditionId,
  }) async {
    final l10n = _l10nOf(context);
    final confirmed = await _confirmDeletion(
      context,
      title: l10n.profileRemoveCondition,
      message: l10n.profileTheItemWillBeRemovedFrom3,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(profileRepositoryProvider).deleteCondition(conditionId);
      ref.invalidate(profileBundleProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteMedication(
    BuildContext context,
    WidgetRef ref, {
    required String medicationId,
  }) async {
    final l10n = _l10nOf(context);
    final confirmed = await _confirmDeletion(
      context,
      title: l10n.profileRemoveMedication,
      message: l10n.profileTheMedicationAndItsLinkedLocal,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(profileRepositoryProvider).deleteMedication(medicationId);
      final bundle = await ref.read(profileBundleProvider.future);
      final preferences = await ref.read(
        notificationPreferencesProvider.future,
      );
      final logs = await ref.read(medicationLogsProvider.future);
      if (bundle != null) {
        await ref
            .read(localMedicationReminderServiceProvider)
            .syncMedicationReminders(
              medications: bundle.medications
                  .where((item) => item.id != medicationId)
                  .toList(),
              preferences: preferences,
              logs: logs,
            );
      }
      ref.invalidate(profileBundleProvider);
      ref.invalidate(localMedicationReminderStatusProvider);
      ref.invalidate(medicationLogsProvider);
      ref.invalidate(timelineEventsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteFamilyHistory(
    BuildContext context,
    WidgetRef ref, {
    required String familyHistoryId,
  }) async {
    final l10n = _l10nOf(context);
    final confirmed = await _confirmDeletion(
      context,
      title: l10n.profileRemoveFamilyHistory,
      message: l10n.profileTheItemWillBeRemovedFrom4,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteFamilyHistory(familyHistoryId);
      ref.invalidate(profileBundleProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<bool> _confirmDeletion(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final l10n = _l10nOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileCancel4),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileRemove3),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    ProfileBundle bundle,
  ) async {
    final l10n = _l10nOf(context);
    final firstNameController = TextEditingController(
      text: bundle.profile.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: bundle.profile.lastName ?? '',
    );
    final birthDateController = TextEditingController(
      text: bundle.profile.birthDate?.toIso8601String().split('T').first ?? '',
    );
    final heightController = TextEditingController(
      text: bundle.profile.heightCm?.toStringAsFixed(0) ?? '',
    );
    final weightController = TextEditingController(
      text: bundle.profile.weightKg?.toStringAsFixed(0) ?? '',
    );
    final smokingPackYearsController = TextEditingController(
      text: bundle.profile.smokingPackYears?.toStringAsFixed(0) ?? '',
    );
    final yearsSinceQuittingController = TextEditingController(
      text: bundle.profile.yearsSinceQuitting?.toString() ?? '',
    );
    final fallsLastYearController = TextEditingController(
      text: bundle.profile.fallsLastYear?.toString() ?? '',
    );
    final occupationController = TextEditingController(
      text: bundle.profile.occupation ?? '',
    );
    final exerciseHabitsController = TextEditingController(
      text: bundle.profile.exerciseHabits ?? '',
    );
    final sleepPatternController = TextEditingController(
      text: bundle.profile.sleepPattern ?? '',
    );
    final symptomTriggersController = TextEditingController(
      text: bundle.profile.symptomTriggers ?? '',
    );
    final functionalLimitationsController = TextEditingController(
      text: bundle.profile.functionalLimitations ?? '',
    );
    var smoker = bundle.profile.smoker;
    var formerSmoker = bundle.profile.formerSmoker;
    var biologicalSex = bundle.profile.biologicalSex ?? 'unknown';
    var alcoholUse = bundle.profile.alcoholUse ?? 'none';
    var activityLevel = bundle.profile.activityLevel ?? 'sedentary';
    var postmenopausal = bundle.profile.postmenopausal;
    var fragilityFractureHistory = bundle.profile.fragilityFractureHistory;
    var feelsUnsteady = bundle.profile.feelsUnsteady;
    var newOrMultiplePartners = bundle.profile.newOrMultiplePartners;
    var partnerWithSti = bundle.profile.partnerWithSti;
    var sexWithMen = bundle.profile.sexWithMen;
    var stiOrExposureConcerns = bundle.profile.stiOrExposureConcerns;
    var tryingToConceive = bundle.profile.tryingToConceive;
    var currentlyPregnant = bundle.profile.currentlyPregnant;
    var takingFolicAcid = bundle.profile.takingFolicAcid;
    var sexualActivity = switch (bundle.profile.sexuallyActive) {
      true => 'yes',
      false => 'no',
      _ => 'unknown',
    };
    DateTime fallbackBirthDate() {
      final now = DateTime.now();
      final candidate = DateTime(now.year - 30, now.month, now.day);
      return candidate.isBefore(DateTime(1900, 1, 1))
          ? DateTime(2000, 1, 1)
          : candidate;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(l10n.profileUpdateProfile),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: l10n.profileFirstName2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(labelText: l10n.profileLastName2),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: birthDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: l10n.profileDateOfBirth2,
                    hintText: l10n.profileTapToPick3,
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: birthDateController.text.trim().isNotEmpty
                          ? DateTime.tryParse(
                                  birthDateController.text.trim(),
                                ) ??
                                fallbackBirthDate()
                          : fallbackBirthDate(),
                      firstDate: DateTime(1900, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      helpText: l10n.profileSelectDateOfBirth2,
                    );
                    if (picked != null) {
                      setState(() {
                        birthDateController.text = picked
                            .toIso8601String()
                            .split('T')
                            .first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: biologicalSex,
                  decoration: InputDecoration(
                    labelText: l10n.profileBiologicalSex2,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'female',
                      child: Text(l10n.profileFemale2),
                    ),
                    DropdownMenuItem(
                      value: 'male',
                      child: Text(l10n.profileMale2),
                    ),
                    DropdownMenuItem(
                      value: 'intersex',
                      child: Text(l10n.profileIntersex2),
                    ),
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text(l10n.profileNotSpecified2),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => biologicalSex = value ?? 'unknown'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  decoration: InputDecoration(labelText: l10n.profileHeightCm),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  decoration: InputDecoration(labelText: l10n.profileWeightKg),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: smoker,
                  onChanged: (value) => setState(() {
                    smoker = value;
                    if (value) {
                      formerSmoker = false;
                      yearsSinceQuittingController.clear();
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileSmoker),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: formerSmoker,
                  onChanged: (value) => setState(() {
                    formerSmoker = value;
                    if (value) {
                      smoker = false;
                    } else {
                      yearsSinceQuittingController.clear();
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileFormerSmoker),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: smokingPackYearsController,
                  decoration: InputDecoration(
                    labelText: l10n.profileTobaccoPackYears,
                    helperText: l10n.profileUsefulForLungAndAorticAneurysm,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearsSinceQuittingController,
                  decoration: InputDecoration(
                    labelText: l10n.profileYearsSinceQuitting,
                    helperText: l10n.profileLeaveBlankIfStillSmokingOr,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: activityLevel,
                  decoration: InputDecoration(
                    labelText: l10n.profileActivityLevel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'sedentary',
                      child: Text(l10n.profileSedentary),
                    ),
                    DropdownMenuItem(
                      value: 'light',
                      child: Text(l10n.profileLight),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text(l10n.profileModerate),
                    ),
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(l10n.profileActive2),
                    ),
                    DropdownMenuItem(
                      value: 'very_active',
                      child: Text(l10n.profileVeryActive),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => activityLevel = value ?? 'sedentary'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: alcoholUse,
                  decoration: InputDecoration(
                    labelText: l10n.profileAlcoholUse,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(l10n.profileNone),
                    ),
                    DropdownMenuItem(
                      value: 'occasional',
                      child: Text(l10n.profileOccasional),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text(l10n.profileModerate2),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text(l10n.profileHigh),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => alcoholUse = value ?? 'none'),
                ),

                TextField(
                  controller: exerciseHabitsController,
                  decoration: InputDecoration(
                    labelText: l10n.profileUsualExerciseOrPhysicalActivity,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sleepPatternController,
                  decoration: InputDecoration(
                    labelText: l10n.profileUsualSleepPattern,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: occupationController,
                  decoration: InputDecoration(
                    labelText: l10n.profileWorkOrDailyContext,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: symptomTriggersController,
                  decoration: InputDecoration(
                    labelText: l10n.profileKnownSymptomTriggers,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: functionalLimitationsController,
                  decoration: InputDecoration(
                    labelText: l10n.profileFunctionalLimitations,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.profileAdvancedPrevention,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: postmenopausal,
                  onChanged: (value) => setState(() => postmenopausal = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profilePostMenopause),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: tryingToConceive,
                  onChanged: (value) => setState(() {
                    tryingToConceive = value;
                    if (value) {
                      currentlyPregnant = false;
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileTryingToConceive),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: currentlyPregnant,
                  onChanged: (value) => setState(() {
                    currentlyPregnant = value;
                    if (value) {
                      tryingToConceive = false;
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileCurrentPregnancy),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: takingFolicAcid,
                  onChanged: (value) => setState(() => takingFolicAcid = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileITakeFolateFolicAcid),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: fragilityFractureHistory,
                  onChanged: (value) =>
                      setState(() => fragilityFractureHistory = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profilePreviousFragilityFracture),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fallsLastYearController,
                  decoration: InputDecoration(
                    labelText: l10n.profileFallsInTheLastYear,
                    helperText: l10n.profileUsedForFallRiskAndFunctional,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: feelsUnsteady,
                  onChanged: (value) => setState(() => feelsUnsteady = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileInstabilityOrFearOfFalling),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: sexualActivity,
                  decoration: InputDecoration(
                    labelText: l10n.profileSexualActivity,
                    helperText: l10n.profileOptionalDataUsedOnlyForPersonalized,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text(l10n.profilePreferNotToSay),
                    ),
                    DropdownMenuItem(
                      value: 'yes',
                      child: Text(l10n.profileActive3),
                    ),
                    DropdownMenuItem(
                      value: 'no',
                      child: Text(l10n.profileNotActive),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => sexualActivity = value ?? 'unknown'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: newOrMultiplePartners,
                  onChanged: (value) =>
                      setState(() => newOrMultiplePartners = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileNewOrMultiplePartners),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: partnerWithSti,
                  onChanged: (value) => setState(() => partnerWithSti = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profilePartnerWithKnownSti),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: sexWithMen,
                  onChanged: (value) => setState(() => sexWithMen = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileMsmContextSexBetweenMen),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: stiOrExposureConcerns,
                  onChanged: (value) =>
                      setState(() => stiOrExposureConcerns = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileSymptomsOrStiExposuresToDiscuss),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).maybePop(),
              child: Text(l10n.profileCancel5),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(profileRepositoryProvider).updateProfile({
                    'first_name': firstNameController.text.trim().isEmpty
                        ? null
                        : firstNameController.text.trim(),
                    'last_name': lastNameController.text.trim().isEmpty
                        ? null
                        : lastNameController.text.trim(),
                    'birth_date': birthDateController.text.trim().isEmpty
                        ? null
                        : birthDateController.text.trim(),
                    'biological_sex': biologicalSex,
                    'height_cm': double.tryParse(heightController.text.trim()),
                    'weight_kg': double.tryParse(weightController.text.trim()),
                    'smoker': smoker,
                    'former_smoker': formerSmoker && !smoker,
                    'smoking_pack_years': double.tryParse(
                      smokingPackYearsController.text.trim(),
                    ),
                    'years_since_quitting': smoker || !formerSmoker
                        ? null
                        : int.tryParse(
                            yearsSinceQuittingController.text.trim(),
                          ),
                    'alcohol_use': alcoholUse,
                    'activity_level': activityLevel,
                    'postmenopausal': postmenopausal,
                    'fragility_fracture_history': fragilityFractureHistory,
                    'falls_last_year': int.tryParse(
                      fallsLastYearController.text.trim(),
                    ),
                    'feels_unsteady': feelsUnsteady,
                    'sexually_active': switch (sexualActivity) {
                      'yes' => true,
                      'no' => false,
                      _ => null,
                    },
                    'new_or_multiple_partners': newOrMultiplePartners,
                    'partner_with_sti': partnerWithSti,
                    'sex_with_men': sexWithMen,
                    'sti_or_exposure_concerns': stiOrExposureConcerns,
                    'trying_to_conceive': tryingToConceive,
                    'currently_pregnant': currentlyPregnant,
                    'taking_folic_acid': takingFolicAcid,
                    'exercise_habits':
                        exerciseHabitsController.text.trim().isEmpty
                        ? null
                        : exerciseHabitsController.text.trim(),
                    'sleep_pattern': sleepPatternController.text.trim().isEmpty
                        ? null
                        : sleepPatternController.text.trim(),
                    'occupation': occupationController.text.trim().isEmpty
                        ? null
                        : occupationController.text.trim(),
                    'symptom_triggers':
                        symptomTriggersController.text.trim().isEmpty
                        ? null
                        : symptomTriggersController.text.trim(),
                    'functional_limitations':
                        functionalLimitationsController.text.trim().isEmpty
                        ? null
                        : functionalLimitationsController.text.trim(),
                  });
                  ref.invalidate(profileBundleProvider);
                  ref.invalidate(screeningCatalogProvider);
                  ref.invalidate(myScreeningsProvider);
                  ref.invalidate(preventionCenterProvider);
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(timelineEventsProvider);
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).maybePop();
                  }
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: Text(l10n.profileSave3),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateAllergyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = _l10nOf(context);
    final allergenController = TextEditingController();
    String severity = 'moderate';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.profileNewAllergy),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: allergenController,
                  decoration: InputDecoration(labelText: l10n.profileAllergen),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: InputDecoration(labelText: l10n.profileSeverity),
                  items: [
                    DropdownMenuItem(
                      value: 'mild',
                      child: Text(l10n.profileMild),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text(l10n.profileModerate3),
                    ),
                    DropdownMenuItem(
                      value: 'severe',
                      child: Text(l10n.profileSevere),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => severity = value ?? 'moderate'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.profileCancel6),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(profileRepositoryProvider).addAllergy({
                    'allergen': allergenController.text.trim(),
                    'severity': severity,
                  });
                  ref.invalidate(profileBundleProvider);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: Text(l10n.profileSave4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateConditionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = _l10nOf(context);
    final nameController = TextEditingController();
    String status = 'active';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.profileNewCondition),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.profileConditionName,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: l10n.profileStatus2),
                  items: [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(l10n.profileActive4),
                    ),
                    DropdownMenuItem(
                      value: 'monitoring',
                      child: Text(l10n.profileMonitoring2),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text(l10n.profileResolved2),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => status = value ?? 'active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.profileCancel7),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(profileRepositoryProvider).addCondition({
                    'name': nameController.text.trim(),
                    'status': status,
                  });
                  ref.invalidate(profileBundleProvider);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: Text(l10n.profileSave5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateMedicationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = _l10nOf(context);
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    var reminderTime = const TimeOfDay(hour: 8, minute: 0);
    final selectedDays = <int>{};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.profileNewMedication),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.profileMedicationName,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageController,
                  decoration: InputDecoration(labelText: l10n.profileDosage),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: frequencyController,
                  decoration: InputDecoration(labelText: l10n.profileFrequency),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.profileReminderTime),
                  subtitle: Text(_formatTimeOfDay(reminderTime)),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminderTime,
                    );
                    if (picked != null) {
                      setState(() => reminderTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profileDays,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    _profileWeekdayLabels(context).length,
                    (index) {
                      final selected = selectedDays.contains(index);
                      return FilterChip(
                        label: Text(_profileWeekdayLabels(context)[index]),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              selectedDays.add(index);
                            } else {
                              selectedDays.remove(index);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedDays.isEmpty
                      ? l10n.profileNoDaySelectedClindiaryTreatsThe
                      : '${l10n.profileDays}: ${selectedDays.map((item) => _profileWeekdayLabels(context)[item]).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.profileCancel8),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final bundle = await ref
                      .read(profileRepositoryProvider)
                      .addMedication({
                        'name': nameController.text.trim(),
                        'dosage': dosageController.text.trim().isEmpty
                            ? null
                            : dosageController.text.trim(),
                        'frequency': frequencyController.text.trim().isEmpty
                            ? null
                            : frequencyController.text.trim(),
                        'schedules': [
                          {
                            'scheduled_time':
                                '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}:00',
                            'instructions': l10n.profileClindiaryLocalReminder,
                            'days_of_week': selectedDays.toList()..sort(),
                          },
                        ],
                      });
                  final preferences = await ref.read(
                    notificationPreferencesProvider.future,
                  );
                  final logs = await ref.read(medicationLogsProvider.future);
                  await ref
                      .read(localMedicationReminderServiceProvider)
                      .syncMedicationReminders(
                        medications: bundle.medications,
                        preferences: preferences,
                        logs: logs,
                      );
                  ref.invalidate(profileBundleProvider);
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(localMedicationReminderStatusProvider);
                  ref.invalidate(timelineEventsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: Text(l10n.profileSave6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateFamilyHistoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = _l10nOf(context);
    final relationController = TextEditingController();
    final conditionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileNewFamilyHistory),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: relationController,
                decoration: InputDecoration(
                  labelText: l10n.profileRelationship2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conditionController,
                decoration: InputDecoration(labelText: l10n.profileCondition),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.profileCancel9),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(profileRepositoryProvider).addFamilyHistory({
                  'relation': relationController.text.trim(),
                  'condition_name': conditionController.text.trim(),
                });
                ref.invalidate(profileBundleProvider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: Text(l10n.profileSave7),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabList extends StatelessWidget {
  const _ProfileTabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

enum _ProfileClinicalTab { medications, conditions, allergies, familyHistory }

class _ProfileClinicalSwitcher extends StatefulWidget {
  const _ProfileClinicalSwitcher({
    required this.allergies,
    required this.conditions,
    required this.medications,
    required this.familyHistory,
    required this.onAddAllergy,
    required this.onDeleteAllergy,
    required this.onAddCondition,
    required this.onDeleteCondition,
    required this.onAddMedication,
    required this.onDeleteMedication,
    required this.onAddFamilyHistory,
    required this.onDeleteFamilyHistory,
  });

  final List<_ResourceItem> allergies;
  final List<_ResourceItem> conditions;
  final List<_ResourceItem> medications;
  final List<_ResourceItem> familyHistory;
  final VoidCallback onAddAllergy;
  final ValueChanged<String> onDeleteAllergy;
  final VoidCallback onAddCondition;
  final ValueChanged<String> onDeleteCondition;
  final VoidCallback onAddMedication;
  final ValueChanged<String> onDeleteMedication;
  final VoidCallback onAddFamilyHistory;
  final ValueChanged<String> onDeleteFamilyHistory;

  @override
  State<_ProfileClinicalSwitcher> createState() =>
      _ProfileClinicalSwitcherState();
}

class _ProfileClinicalSwitcherState extends State<_ProfileClinicalSwitcher> {
  _ProfileClinicalTab _selected = _ProfileClinicalTab.medications;

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: l10n.profileClinicalArea,
          subtitle: l10n.profileOpenOnlyTheSectionYouNeed,
          child: CompactSegmentedControl<_ProfileClinicalTab>(
            options: [
              CompactSegmentOption(
                value: _ProfileClinicalTab.medications,
                label: l10n.medications,
                icon: Icons.medication_outlined,
              ),
              CompactSegmentOption(
                value: _ProfileClinicalTab.conditions,
                label: l10n.profileConditions2,
                icon: Icons.health_and_safety_outlined,
              ),
              CompactSegmentOption(
                value: _ProfileClinicalTab.allergies,
                label: l10n.profileAllergies2,
                icon: Icons.warning_amber_outlined,
              ),
              CompactSegmentOption(
                value: _ProfileClinicalTab.familyHistory,
                label: l10n.profileFamilyHistory2,
                icon: Icons.family_restroom_outlined,
              ),
            ],
            selectedValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
          ),
        ),
        const SizedBox(height: 16),
        switch (_selected) {
          _ProfileClinicalTab.medications => _ResourceSection(
            title: l10n.medications,
            emptyText: l10n.profileNoChronicMedicationRecorded,
            items: widget.medications,
            onAdd: widget.onAddMedication,
            onDelete: widget.onDeleteMedication,
          ),
          _ProfileClinicalTab.conditions => _ResourceSection(
            title: l10n.profileKnownConditions,
            emptyText: l10n.profileNoConditionRecorded,
            items: widget.conditions,
            onAdd: widget.onAddCondition,
            onDelete: widget.onDeleteCondition,
          ),
          _ProfileClinicalTab.allergies => _ResourceSection(
            title: l10n.profileAllergies3,
            emptyText: l10n.profileNoAllergyRecorded,
            items: widget.allergies,
            onAdd: widget.onAddAllergy,
            onDelete: widget.onDeleteAllergy,
          ),
          _ProfileClinicalTab.familyHistory => _ResourceSection(
            title: l10n.profileFamilyHistory3,
            emptyText: l10n.profileNoFamilyHistoryRecorded,
            items: widget.familyHistory,
            onAdd: widget.onAddFamilyHistory,
            onDelete: widget.onDeleteFamilyHistory,
          ),
        },
      ],
    );
  }
}

class _ResourceSection extends StatelessWidget {
  const _ResourceSection({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });

  final String title;
  final String emptyText;
  final List<_ResourceItem> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    return SectionCard(
      title: title,
      subtitle: _profileItemsCountLabel(context, items.length),
      action: FilledButton.tonalIcon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: Text(l10n.add3),
      ),
      child: items.isEmpty
          ? _EmptyResourceState(message: emptyText)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (item.pendingSync) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (item.subtitle != null &&
                                      item.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.subtitle!,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ] else if (item.pendingSync) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.profilePendingSync8,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: item.pendingSync
                                  ? l10n.profilePendingSync7
                                  : l10n.profileRemove4,
                              onPressed: item.pendingSync
                                  ? null
                                  : () => onDelete(item.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ResourceItem {
  const _ResourceItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.pendingSync = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool pendingSync;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _ProfileHeaderAvatar extends StatelessWidget {
  const _ProfileHeaderAvatar({required this.label, required this.isPrimary});

  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    final initials = parts.isEmpty
        ? l10n.profileCd
        : parts.map((part) => part.substring(0, 1).toUpperCase()).join();

    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Text(
              initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isPrimary)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star, size: 12, color: colorScheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProfileShortcutGrid extends StatelessWidget {
  const _ProfileShortcutGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _ProfileActionChip(
              width: width,
              label: l10n.profileVaccines,
              subtitle: l10n.history5,
              icon: Icons.vaccines_rounded,
              color: const Color(0xFFFF7A59),
              onPressed: () => context.push('/app/profile/vaccinations'),
            ),
            _ProfileActionChip(
              width: width,
              label: l10n.profileIssues,
              subtitle: l10n.profileClinical2,
              icon: Icons.topic_rounded,
              color: const Color(0xFF5B5CE2),
              onPressed: () => context.push('/app/profile/problems'),
            ),
            _ProfileActionChip(
              width: width,
              label: l10n.profileFamily,
              subtitle: l10n.profiles,
              icon: Icons.groups_rounded,
              color: const Color(0xFF18A999),
              onPressed: () => context.push('/app/profile/family'),
            ),
            _ProfileActionChip(
              width: width,
              label: l10n.profileSettings,
              subtitle: l10n.profilePrivacy,
              icon: Icons.tune_rounded,
              color: const Color(0xFFF4A62A),
              onPressed: () => context.push('/app/profile/settings'),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileActionChip extends StatelessWidget {
  const _ProfileActionChip({
    required this.width,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final double width;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Material(
        color: color.withValues(alpha: isDark ? 0.22 : 0.1),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContextSection extends StatelessWidget {
  const _ProfileContextSection({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    final entries =
        [
              (l10n.profileSport, profile.exerciseHabits),
              (l10n.profileSleep, profile.sleepPattern),
              (l10n.profileWork, profile.occupation),
              (l10n.profileTrigger, profile.symptomTriggers),
              (l10n.profileLimitations, profile.functionalLimitations),
            ]
            .where((entry) => entry.$2 != null && entry.$2!.trim().isNotEmpty)
            .toList();

    if (entries.isEmpty) {
      return _EmptyResourceState(
        message: l10n.profileAddUsefulDetailsToGiveRecaps,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final itemWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries
              .map(
                (entry) => SizedBox(
                  width: itemWidth,
                  child: _ProfileContextLine(label: entry.$1, value: entry.$2),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ProfileQuickFactsSection extends StatelessWidget {
  const _ProfileQuickFactsSection({
    required this.bundle,
    required this.pendingOperations,
    required this.dateFormat,
  });

  final ProfileBundle bundle;
  final int pendingOperations;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    final profile = bundle.profile;
    final facts = <(String, String)>[
      if (profile.birthDate != null)
        (l10n.profileBirth, dateFormat.format(profile.birthDate!)),
      if (profile.biologicalSex != null && profile.biologicalSex!.isNotEmpty)
        (
          l10n.profileSex,
          _profileBiologicalSexLabel(context, profile.biologicalSex!),
        ),
      if (profile.heightCm != null)
        (l10n.profileHeight, '${profile.heightCm!.toStringAsFixed(0)} cm'),
      if (profile.weightKg != null)
        (l10n.profileWeight, '${profile.weightKg!.toStringAsFixed(0)} kg'),
      if (profile.smokingPackYears != null)
        (l10n.profilePackYears, profile.smokingPackYears!.toStringAsFixed(0)),
      if (profile.activityLevel != null)
        (
          l10n.profileActivity,
          _profileActivityLevelLabel(context, profile.activityLevel!),
        ),
      if (profile.alcoholUse != null)
        (
          l10n.profileAlcohol,
          _profileAlcoholUseLabel(context, profile.alcoholUse!),
        ),
      (l10n.profileSmoking, profile.smoker ? l10n.profileYes : l10n.profileNo),
      if (profile.formerSmoker) (l10n.profileFormerSmoking, l10n.profileYes2),
      if (profile.postmenopausal)
        (l10n.profilePostMenopause2, l10n.profileYes3),
      if (profile.tryingToConceive)
        (l10n.profilePreconception, l10n.profileActive5),
      if (profile.currentlyPregnant)
        (l10n.profilePregnancy, l10n.profileOngoing),
      if (profile.takingFolicAcid) (l10n.profileFolate, l10n.profileTaking),
      if (profile.fragilityFractureHistory)
        (l10n.profileFractures, l10n.profilePrevious),
      if (profile.fallsLastYear != null)
        (l10n.profileFallsLastYear, profile.fallsLastYear.toString()),
      if (profile.feelsUnsteady)
        (l10n.profileInstability, l10n.profileToReview),
      (l10n.profileAi, l10n.profileLocalOnly),
      if (pendingOperations > 0) (l10n.profileSync, l10n.profileSyncPending),
    ];

    if (facts.isEmpty) {
      return _EmptyResourceState(
        message: l10n.profileAddTheEssentialProfileData,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final itemWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: facts
              .map(
                (entry) => SizedBox(
                  width: itemWidth,
                  child: _QuickFactTile(label: entry.$1, value: entry.$2),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ProfileContextLine extends StatelessWidget {
  const _ProfileContextLine({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final l10n = _profileL10nOf(context);
    final text = value == null || value!.trim().isEmpty
        ? l10n.profileNotSpecified3
        : value!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }
}

class _QuickFactTile extends StatelessWidget {
  const _QuickFactTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyResourceState extends StatelessWidget {
  const _EmptyResourceState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

String _formatTimeOfDay(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

List<String> _summaryFacts(
  BuildContext context,
  ProfileBundle bundle, {
  required int pendingOperations,
  required DateFormat dateFormat,
}) {
  final l10n = _profileL10nOf(context);
  final facts = <String>[];
  final birthDate = bundle.profile.birthDate;
  if (birthDate != null) {
    facts.add('${l10n.profileBirth} ${dateFormat.format(birthDate)}');
  }
  if (bundle.profile.biologicalSex != null &&
      bundle.profile.biologicalSex!.trim().isNotEmpty) {
    facts.add(
      '${l10n.profileSex} ${_profileBiologicalSexLabel(context, bundle.profile.biologicalSex!)}',
    );
  }
  if (bundle.profile.heightCm != null || bundle.profile.weightKg != null) {
    final details = [
      if (bundle.profile.heightCm != null)
        '${bundle.profile.heightCm!.toStringAsFixed(0)} cm',
      if (bundle.profile.weightKg != null)
        '${bundle.profile.weightKg!.toStringAsFixed(0)} kg',
    ].join(' · ');
    if (details.isNotEmpty) {
      facts.add(details);
    }
  }
  if (bundle.profile.smoker) {
    facts.add(l10n.profileSmoker2);
  }
  if (bundle.profile.formerSmoker) {
    facts.add(l10n.profileFormerSmoker2);
  }
  if (bundle.profile.smokingPackYears != null) {
    facts.add(
      '${l10n.profilePackYears} ${bundle.profile.smokingPackYears!.toStringAsFixed(0)}',
    );
  }
  if (bundle.profile.activityLevel != null) {
    facts.add(
      '${l10n.profileActivity} ${_profileActivityLevelLabel(context, bundle.profile.activityLevel!)}',
    );
  }
  if (bundle.profile.alcoholUse != null) {
    facts.add(
      '${l10n.profileAlcohol} ${_profileAlcoholUseLabel(context, bundle.profile.alcoholUse!)}',
    );
  }
  if (bundle.profile.fallsLastYear != null &&
      bundle.profile.fallsLastYear! > 0) {
    facts.add('${l10n.profileFallsLastYear} ${bundle.profile.fallsLastYear}');
  }
  if (bundle.profile.tryingToConceive) {
    facts.add(l10n.profilePreconceptionActive);
  }
  if (bundle.profile.currentlyPregnant) {
    facts.add(l10n.profilePregnancyOngoing);
  }
  facts.add(l10n.profileAiLocalOnly);
  if (pendingOperations > 0) {
    facts.add(l10n.profileSyncPending);
  }
  return facts.take(6).toList();
}
