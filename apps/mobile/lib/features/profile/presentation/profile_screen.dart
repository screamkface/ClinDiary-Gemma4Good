import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/italian_regions.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/compact_segmented_control.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileBundleProvider);
    final pendingOperationsAsync = ref.watch(pendingOperationsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              onPressed: () => ref.invalidate(profileBundleProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Context'),
              Tab(text: 'Clinical'),
            ],
          ),
        ),
        body: profileAsync.when(
          data: (bundle) {
            if (bundle == null) {
              return const Center(
                child: Text('Complete authentication to view the profile.'),
              );
            }
            final pendingCount =
                pendingOperationsAsync.asData?.value.length ?? 0;
            return TabBarView(
              children: [
                _ProfileTabList(
                  children: [
                    SectionCard(
                      title: 'Active profile',
                      action: TextButton.icon(
                        onPressed: () =>
                            _showEditProfileDialog(context, ref, bundle),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
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
                                      'Your clinical profile starts here.',
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
                                label: 'Allergies',
                                value: bundle.allergies.length.toString(),
                              ),
                              _ProfileMetricCard(
                                label: 'Conditions',
                                value: bundle.medicalConditions.length
                                    .toString(),
                              ),
                              _ProfileMetricCard(
                                label: 'Medications',
                                value: bundle.medications.length.toString(),
                              ),
                              _ProfileMetricCard(
                                label: 'Family history',
                                value: bundle.familyHistory.length.toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _summaryFacts(
                              bundle,
                              pendingOperations: pendingCount,
                              dateFormat: dateFormat,
                            ).map((label) => _InfoChip(label: label)).toList(),
                          ),
                          const SizedBox(height: 14),
                          const Text('Go straight to what you need:'),
                          const SizedBox(height: 10),
                          const _ProfileShortcutGrid(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Quick facts',
                      subtitle: 'Values and settings used in recaps.',
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
                      title: 'Context',
                      subtitle:
                          'Habits, triggers, and limits used to add context.',
                      action: TextButton(
                        onPressed: () =>
                            _showEditProfileDialog(context, ref, bundle),
                        child: const Text('Edit'),
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
                                if (item.pendingSync) 'Pending sync',
                                if (item.severity != null) item.severity!,
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
                                if (item.pendingSync) 'Pending sync',
                                if (item.status != null) item.status!,
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
                            if (item.pendingSync) 'Pending sync',
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
                                if (item.pendingSync) 'Pending sync',
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
    final confirmed = await _confirmDeletion(
      context,
      title: 'Remove allergy?',
      message: 'The item will be removed from the clinical profile.',
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
    final confirmed = await _confirmDeletion(
      context,
      title: 'Remove condition?',
      message: 'The item will be removed from the clinical profile.',
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
    final confirmed = await _confirmDeletion(
      context,
      title: 'Remove medication?',
      message: 'The medication and its linked local schedules will be removed.',
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
    final confirmed = await _confirmDeletion(
      context,
      title: 'Remove family history?',
      message: 'The item will be removed from the clinical profile.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
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
    var biologicalSex = bundle.profile.biologicalSex;
    var alcoholUse = bundle.profile.alcoholUse;
    var activityLevel = bundle.profile.activityLevel;
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
    var regionCode = bundle.profile.regionCode ?? 'IT';

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
          title: const Text('Update profile'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: birthDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    hintText: 'Tap to pick',
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
                      helpText: 'Select date of birth',
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
                  decoration: const InputDecoration(
                    labelText: 'Biological sex',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(
                      value: 'intersex',
                      child: Text('Intersex'),
                    ),
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text('Not specified'),
                    ),
                  ],
                  onChanged: (value) => setState(() => biologicalSex = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  decoration: const InputDecoration(labelText: 'Height cm'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: 'Weight kg'),
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
                  title: const Text('Smoker'),
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
                  title: const Text('Former smoker'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: smokingPackYearsController,
                  decoration: const InputDecoration(
                    labelText: 'Tobacco pack-years',
                    helperText:
                        'Useful for lung and aortic aneurysm screening.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearsSinceQuittingController,
                  decoration: const InputDecoration(
                    labelText: 'Years since quitting',
                    helperText:
                        'Leave blank if still smoking or not applicable.',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: activityLevel,
                  decoration: const InputDecoration(
                    labelText: 'Activity level',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'sedentary',
                      child: Text('Sedentary'),
                    ),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text('Moderate'),
                    ),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'very_active',
                      child: Text('Very active'),
                    ),
                  ],
                  onChanged: (value) => setState(() => activityLevel = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: alcoholUse,
                  decoration: const InputDecoration(labelText: 'Alcohol use'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(
                      value: 'occasional',
                      child: Text('Occasional'),
                    ),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text('Moderate'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) => setState(() => alcoholUse = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: regionCode,
                  decoration: const InputDecoration(
                    labelText: 'Screening region',
                    helperText:
                        'Used to show screening, prevention, and local notifications.',
                  ),
                  items: italianRegionOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option.code,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => regionCode = value ?? 'IT'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exerciseHabitsController,
                  decoration: const InputDecoration(
                    labelText: 'Usual exercise or physical activity',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sleepPatternController,
                  decoration: const InputDecoration(
                    labelText: 'Usual sleep pattern',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: occupationController,
                  decoration: const InputDecoration(
                    labelText: 'Work or daily context',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: symptomTriggersController,
                  decoration: const InputDecoration(
                    labelText: 'Known symptom triggers',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: functionalLimitationsController,
                  decoration: const InputDecoration(
                    labelText: 'Functional limitations',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Advanced prevention',
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
                  title: const Text('Post-menopause'),
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
                  title: const Text('Trying to conceive'),
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
                  title: const Text('Current pregnancy'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: takingFolicAcid,
                  onChanged: (value) => setState(() => takingFolicAcid = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I take folate / folic acid'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: fragilityFractureHistory,
                  onChanged: (value) =>
                      setState(() => fragilityFractureHistory = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Previous fragility fracture'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fallsLastYearController,
                  decoration: const InputDecoration(
                    labelText: "Falls in the last year",
                    helperText: 'Used for fall risk and functional prevention.',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: feelsUnsteady,
                  onChanged: (value) => setState(() => feelsUnsteady = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Instability or fear of falling'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: sexualActivity,
                  decoration: const InputDecoration(
                    labelText: 'Sexual activity',
                    helperText:
                        'Optional data used only for personalized STI prevention.',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text('Prefer not to say'),
                    ),
                    DropdownMenuItem(value: 'yes', child: Text('Active')),
                    DropdownMenuItem(value: 'no', child: Text('Not active')),
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
                  title: const Text('New or multiple partners'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: partnerWithSti,
                  onChanged: (value) => setState(() => partnerWithSti = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Partner with known STI'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: sexWithMen,
                  onChanged: (value) => setState(() => sexWithMen = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('MSM context / sex between men'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: stiOrExposureConcerns,
                  onChanged: (value) =>
                      setState(() => stiOrExposureConcerns = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Symptoms or STI exposures to discuss'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).maybePop(),
              child: const Text('Cancel'),
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
                    'region_code': regionCode,
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
              child: const Text('Save'),
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
    final allergenController = TextEditingController();
    String severity = 'moderate';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New allergy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: allergenController,
                  decoration: const InputDecoration(labelText: 'Allergen'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'mild', child: Text('Mild')),
                    DropdownMenuItem(
                      value: 'moderate',
                      child: Text('Moderate'),
                    ),
                    DropdownMenuItem(value: 'severe', child: Text('Severe')),
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
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
    final nameController = TextEditingController();
    String status = 'active';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New condition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Condition name',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'monitoring',
                      child: Text('Monitoring'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
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
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    var reminderTime = const TimeOfDay(hour: 8, minute: 0);
    final selectedDays = <int>{};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(labelText: 'Dosage'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: frequencyController,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reminder time'),
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
                Text('Days', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_weekdayLabels.length, (index) {
                    final selected = selectedDays.contains(index);
                    return FilterChip(
                      label: Text(_weekdayLabels[index]),
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
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedDays.isEmpty
                      ? 'No day selected: ClinDiary treats the reminder as daily.'
                      : 'Selected: ${selectedDays.map((item) => _weekdayLabels[item]).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
                            'instructions': 'ClinDiary local reminder',
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
              child: const Text('Save'),
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
    final relationController = TextEditingController();
    final conditionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New family history'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: relationController,
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conditionController,
                decoration: const InputDecoration(labelText: 'Condition'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
            child: const Text('Save'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Clinical area',
          subtitle: 'Open only the section you need.',
          child: CompactSegmentedControl<_ProfileClinicalTab>(
            options: const [
              CompactSegmentOption(
                value: _ProfileClinicalTab.medications,
                label: 'Medications',
                icon: Icons.medication_outlined,
              ),
              CompactSegmentOption(
                value: _ProfileClinicalTab.conditions,
                label: 'Conditions',
                icon: Icons.health_and_safety_outlined,
              ),
              CompactSegmentOption(
                value: _ProfileClinicalTab.allergies,
                label: 'Allergies',
                icon: Icons.warning_amber_outlined,
              ),
              CompactSegmentOption(
                value: _ProfileClinicalTab.familyHistory,
                label: 'Family history',
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
            title: 'Medications',
            emptyText: 'No chronic medication recorded.',
            items: widget.medications,
            onAdd: widget.onAddMedication,
            onDelete: widget.onDeleteMedication,
          ),
          _ProfileClinicalTab.conditions => _ResourceSection(
            title: 'Known conditions',
            emptyText: 'No condition recorded.',
            items: widget.conditions,
            onAdd: widget.onAddCondition,
            onDelete: widget.onDeleteCondition,
          ),
          _ProfileClinicalTab.allergies => _ResourceSection(
            title: 'Allergies',
            emptyText: 'No allergy recorded.',
            items: widget.allergies,
            onAdd: widget.onAddAllergy,
            onDelete: widget.onDeleteAllergy,
          ),
          _ProfileClinicalTab.familyHistory => _ResourceSection(
            title: 'Family history',
            emptyText: 'No family history recorded.',
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
    return SectionCard(
      title: title,
      subtitle: items.isEmpty
          ? '0 items'
          : '${items.length} ${items.length == 1 ? 'item' : 'items'}',
      action: FilledButton.tonalIcon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
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
                                      'Pending sync',
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
                                  ? 'Pending sync'
                                  : 'Remove',
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
    final colorScheme = Theme.of(context).colorScheme;
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    final initials = parts.isEmpty
        ? 'CD'
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _ProfileActionChip(
              width: width,
              label: 'Vaccines',
              subtitle: 'History',
              icon: Icons.vaccines_rounded,
              color: const Color(0xFFFF7A59),
              onPressed: () => context.push('/app/profile/vaccinations'),
            ),
            _ProfileActionChip(
              width: width,
              label: 'Issues',
              subtitle: 'Clinical',
              icon: Icons.topic_rounded,
              color: const Color(0xFF5B5CE2),
              onPressed: () => context.push('/app/profile/problems'),
            ),
            _ProfileActionChip(
              width: width,
              label: 'Family',
              subtitle: 'Profiles',
              icon: Icons.groups_rounded,
              color: const Color(0xFF18A999),
              onPressed: () => context.push('/app/profile/family'),
            ),
            _ProfileActionChip(
              width: width,
              label: 'Settings',
              subtitle: 'Privacy',
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
    final entries =
        [
              ('Sport', profile.exerciseHabits),
              ('Sleep', profile.sleepPattern),
              ('Work', profile.occupation),
              ('Trigger', profile.symptomTriggers),
              ('Limitations', profile.functionalLimitations),
            ]
            .where((entry) => entry.$2 != null && entry.$2!.trim().isNotEmpty)
            .toList();

    if (entries.isEmpty) {
      return const _EmptyResourceState(
        message: 'Add useful details to give recaps more context.',
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
    final profile = bundle.profile;
    final facts = <(String, String)>[
      if (profile.birthDate != null)
        ('Birth', dateFormat.format(profile.birthDate!)),
      if (profile.biologicalSex != null && profile.biologicalSex!.isNotEmpty)
        ('Sex', profile.biologicalSex!),
      if (profile.regionCode != null)
        ('Region', italianRegionLabel(profile.regionCode)),
      if (profile.heightCm != null)
        ('Height', '${profile.heightCm!.toStringAsFixed(0)} cm'),
      if (profile.weightKg != null)
        ('Weight', '${profile.weightKg!.toStringAsFixed(0)} kg'),
      if (profile.smokingPackYears != null)
        ('Pack-years', profile.smokingPackYears!.toStringAsFixed(0)),
      if (profile.activityLevel != null)
        ('Activity', _activityLevelLabel(profile.activityLevel!)),
      if (profile.alcoholUse != null)
        ('Alcohol', _alcoholUseLabel(profile.alcoholUse!)),
      ('Smoking', profile.smoker ? 'Yes' : 'No'),
      if (profile.formerSmoker) ('Former smoking', 'Yes'),
      if (profile.postmenopausal) ('Post-menopause', 'Yes'),
      if (profile.tryingToConceive) ('Preconception', 'Active'),
      if (profile.currentlyPregnant) ('Pregnancy', 'Ongoing'),
      if (profile.takingFolicAcid) ('Folate', 'Taking'),
      if (profile.fragilityFractureHistory) ('Fractures', 'Previous'),
      if (profile.fallsLastYear != null)
        ('Falls last year', profile.fallsLastYear.toString()),
      if (profile.feelsUnsteady) ('Instability', 'To review'),
      ('AI', 'Local only'),
      if (pendingOperations > 0) ('Sync', '$pendingOperations pending'),
    ];

    if (facts.isEmpty) {
      return const _EmptyResourceState(
        message: 'Add the essential profile data.',
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
    final text = value == null || value!.trim().isEmpty
        ? 'Not specified'
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

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _formatTimeOfDay(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _activityLevelLabel(String value) {
  return switch (value) {
    'sedentary' => 'sedentary',
    'light' => 'light',
    'moderate' => 'moderate',
    'active' => 'active',
    'very_active' => 'very active',
    _ => value,
  };
}

String _alcoholUseLabel(String value) {
  return switch (value) {
    'none' => 'none',
    'occasional' => 'occasional',
    'moderate' => 'moderate',
    'high' => 'high',
    _ => value,
  };
}

List<String> _summaryFacts(
  ProfileBundle bundle, {
  required int pendingOperations,
  required DateFormat dateFormat,
}) {
  final facts = <String>[];
  final birthDate = bundle.profile.birthDate;
  if (birthDate != null) {
    facts.add('Born ${dateFormat.format(birthDate)}');
  }
  if (bundle.profile.biologicalSex != null &&
      bundle.profile.biologicalSex!.trim().isNotEmpty) {
    facts.add('Sex ${bundle.profile.biologicalSex}');
  }
  if (bundle.profile.regionCode != null) {
    facts.add('Region ${italianRegionLabel(bundle.profile.regionCode)}');
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
    facts.add('Smoker');
  }
  if (bundle.profile.formerSmoker) {
    facts.add('Former smoker');
  }
  if (bundle.profile.smokingPackYears != null) {
    facts.add(
      'Pack-years ${bundle.profile.smokingPackYears!.toStringAsFixed(0)}',
    );
  }
  if (bundle.profile.activityLevel != null) {
    facts.add('Activity ${_activityLevelLabel(bundle.profile.activityLevel!)}');
  }
  if (bundle.profile.alcoholUse != null) {
    facts.add('Alcohol ${_alcoholUseLabel(bundle.profile.alcoholUse!)}');
  }
  if (bundle.profile.fallsLastYear != null &&
      bundle.profile.fallsLastYear! > 0) {
    facts.add('Falls ${bundle.profile.fallsLastYear}');
  }
  if (bundle.profile.tryingToConceive) {
    facts.add('Preconception active');
  }
  if (bundle.profile.currentlyPregnant) {
    facts.add('Pregnancy ongoing');
  }
  facts.add('AI: local only');
  if (pendingOperations > 0) {
    facts.add('Sync pending');
  }
  return facts.take(6).toList();
}
