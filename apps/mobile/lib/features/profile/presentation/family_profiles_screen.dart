import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/profile/domain/italian_regions.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FamilyProfilesScreen extends ConsumerStatefulWidget {
  const FamilyProfilesScreen({super.key});

  @override
  ConsumerState<FamilyProfilesScreen> createState() =>
      _FamilyProfilesScreenState();
}

class _FamilyProfilesScreenState extends ConsumerState<FamilyProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(profileBundleProvider);
    final activeProfileIdAsync = ref.watch(activeProfileIdProvider);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili familiari'),
        actions: [
          IconButton(
            onPressed: () {
              invalidatePatientScopedProviders(ref);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: bundleAsync.maybeWhen(
        data: (bundle) => bundle == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showCreateProfileDialog(context, bundle),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Nuovo profilo'),
              ),
        orElse: () => null,
      ),
      body: bundleAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return const Center(
              child: Text('Completa l\'onboarding per gestire i profili.'),
            );
          }

          final profiles = bundle.managedProfiles.isNotEmpty
              ? bundle.managedProfiles
              : <PatientProfile>[bundle.profile];
          final selectedId =
              activeProfileIdAsync.asData?.value?.trim().isNotEmpty == true
              ? activeProfileIdAsync.asData!.value!.trim()
              : bundle.profile.id;

          return RefreshIndicator(
            onRefresh: () async {
              invalidatePatientScopedProviders(ref);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                SectionCard(
                  title: 'Stato attivo',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ogni profilo ha dati, screening e recap separati. Seleziona quello da usare ora.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              '${profiles.length} profili ${profiles.length == 1 ? 'totale' : 'totali'}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              profiles.any(
                                    (profile) => profile.id == selectedId,
                                  )
                                  ? 'Profilo attivo pronto'
                                  : 'Nessun profilo selezionato',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Elenco profili',
                  child: Column(
                    children: profiles.map((profile) {
                      final isSelected = profile.id == selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card.outlined(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            onTap: () => _activateProfile(profile.id),
                            leading: CircleAvatar(
                              child: Text(
                                profile.displayName.isEmpty
                                    ? '?'
                                    : profile.displayName[0].toUpperCase(),
                              ),
                            ),
                            title: Text(profile.displayName),
                            subtitle: Text(
                              _profileSubtitle(profile, dateFormat),
                            ),
                            trailing: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: isSelected
                                  ? const Chip(label: Text('Attivo'))
                                  : TextButton(
                                      onPressed: () =>
                                          _activateProfile(profile.id),
                                      child: const Text('Attiva'),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

  Future<void> _activateProfile(String profileId) async {
    try {
      await ref.read(profileRepositoryProvider).setActiveProfileId(profileId);
      invalidatePatientScopedProviders(ref);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showCreateProfileDialog(
    BuildContext context,
    ProfileBundle bundle,
  ) async {
    var firstName = '';
    var lastName = bundle.profile.lastName ?? '';
    var relationshipLabel = '';
    String? birthDateValue;
    String? biologicalSex = bundle.profile.biologicalSex;
    String regionCode = bundle.profile.regionCode ?? 'IT';
    var submitting = false;
    String? createdProfileId;

    DateTime fallbackBirthDate() {
      final now = DateTime.now();
      final candidate = DateTime(now.year - 30, now.month, now.day);
      return candidate.isBefore(DateTime(1900, 1, 1))
          ? DateTime(2000, 1, 1)
          : candidate;
    }

    createdProfileId = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBodyContext, dialogSetState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Nuovo profilo'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: firstName,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  onChanged: (value) => firstName = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: lastName,
                  decoration: const InputDecoration(labelText: 'Cognome'),
                  onChanged: (value) => lastName = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: relationshipLabel,
                  decoration: const InputDecoration(
                    labelText: 'Relazione',
                    hintText: 'Figlio, figlia, madre, padre...',
                  ),
                  onChanged: (value) => relationshipLabel = value,
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: birthDateValue?.trim().isNotEmpty == true
                          ? DateTime.tryParse(birthDateValue!.trim()) ??
                                fallbackBirthDate()
                          : fallbackBirthDate(),
                      firstDate: DateTime(1900, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      helpText: 'Seleziona data di nascita',
                    );
                    if (picked != null && dialogBodyContext.mounted) {
                      dialogSetState(() {
                        birthDateValue = picked.toIso8601String().split('T').first;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data di nascita',
                      hintText: 'Tocca per scegliere',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        birthDateValue?.trim().isNotEmpty == true
                            ? birthDateValue!
                            : 'Tocca per scegliere',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: biologicalSex,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sesso biologico',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'female', child: Text('Femmina')),
                    DropdownMenuItem(value: 'male', child: Text('Maschio')),
                    DropdownMenuItem(
                      value: 'intersex',
                      child: Text('Intersex'),
                    ),
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text('Non indicato'),
                    ),
                  ],
                  onChanged: (value) =>
                      dialogSetState(() => biologicalSex = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: regionCode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Regione'),
                  items: italianRegionOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.code,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => dialogSetState(() {
                    regionCode = value ?? 'IT';
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
                rootNavigator: true,
              ).maybePop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      var dialogClosed = false;
                      dialogSetState(() => submitting = true);
                      try {
                        final bundle = await ref
                            .read(profileRepositoryProvider)
                            .createManagedProfile({
                              'first_name': firstName.trim(),
                              'last_name': lastName.trim().isEmpty
                                  ? null
                                  : lastName.trim(),
                              'relationship_label':
                                  relationshipLabel.trim().isEmpty
                                  ? null
                                  : relationshipLabel.trim(),
                              'birth_date':
                                  birthDateValue?.trim().isNotEmpty == true
                                  ? birthDateValue!.trim()
                                  : null,
                              'biological_sex': biologicalSex,
                              'region_code': regionCode,
                            });
                        final createdProfile = bundle.managedProfiles.isNotEmpty
                            ? bundle.managedProfiles.last
                            : bundle.profile;
                        if (dialogContext.mounted) {
                          dialogClosed = true;
                          Navigator.of(dialogContext, rootNavigator: true).pop(
                            createdProfile.id,
                          );
                        }
                      } catch (error) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      } finally {
                        if (!dialogClosed && dialogBodyContext.mounted) {
                          dialogSetState(() => submitting = false);
                        }
                      }
                    },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    final selectedProfileId = createdProfileId;
    if (!mounted || selectedProfileId == null || selectedProfileId.isEmpty) {
      return;
    }

    try {
      await ref
          .read(profileRepositoryProvider)
          .setActiveProfileId(selectedProfileId);
      invalidatePatientScopedProviders(ref);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _profileSubtitle(PatientProfile profile, DateFormat dateFormat) {
    final parts = <String>[];
    if (profile.relationshipLabel != null &&
        profile.relationshipLabel!.isNotEmpty) {
      parts.add(profile.relationshipLabel!);
    }
    if (profile.birthDate != null) {
      parts.add('Nato/a il ${dateFormat.format(profile.birthDate!)}');
    }
    if (profile.regionCode != null) {
      parts.add(italianRegionLabel(profile.regionCode));
    }
    if (profile.isPrimary) {
      parts.add('Profilo principale');
    }
    return parts.isEmpty ? 'Profilo clinico separato' : parts.join(' / ');
  }
}
