import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/features/profile/domain/italian_regions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _occupationController = TextEditingController();
  final _exerciseHabitsController = TextEditingController();
  final _sleepPatternController = TextEditingController();
  final _symptomTriggersController = TextEditingController();
  final _functionalLimitationsController = TextEditingController();
  String _sex = 'female';
  String? _alcoholUse;
  String? _activityLevel;
  bool _smoker = false;
  String _regionCode = 'IT';
  bool _consent = false;
  bool _aiConsent = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _occupationController.dispose();
    _exerciseHabitsController.dispose();
    _sleepPatternController.dispose();
    _symptomTriggersController.dispose();
    _functionalLimitationsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bundle = await ref
          .read(profileRepositoryProvider)
          .completeOnboarding(
            payload: {
              'health_data_consent': _consent,
              'ai_external_consent': _aiConsent,
              'first_name': _firstNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'birth_date': _birthDateController.text.trim(),
              'biological_sex': _sex,
              'height_cm': double.tryParse(_heightController.text.trim()),
              'weight_kg': double.tryParse(_weightController.text.trim()),
              'smoker': _smoker,
              'alcohol_use': _alcoholUse,
              'activity_level': _activityLevel,
              'region_code': _regionCode,
              'occupation': _occupationController.text.trim().isEmpty
                  ? null
                  : _occupationController.text.trim(),
              'exercise_habits': _exerciseHabitsController.text.trim().isEmpty
                  ? null
                  : _exerciseHabitsController.text.trim(),
              'sleep_pattern': _sleepPatternController.text.trim().isEmpty
                  ? null
                  : _sleepPatternController.text.trim(),
              'symptom_triggers': _symptomTriggersController.text.trim().isEmpty
                  ? null
                  : _symptomTriggersController.text.trim(),
              'functional_limitations':
                  _functionalLimitationsController.text.trim().isEmpty
                  ? null
                  : _functionalLimitationsController.text.trim(),
            },
          );
      final currentSession = ref.read(authControllerProvider).valueOrNull;
      if (currentSession != null) {
        final updatedUser = UserSummary(
          id: currentSession.user.id,
          email: currentSession.user.email,
          role: currentSession.user.role,
          onboardingCompleted: true,
          healthDataConsent: bundle.onboarding.healthDataConsent,
          aiExternalConsent: bundle.onboarding.aiExternalConsent,
          authProvider: currentSession.user.authProvider,
        );
        await ref.read(authControllerProvider.notifier).updateUser(updatedUser);
      }
      ref.invalidate(profileBundleProvider);
      ref.invalidate(screeningCatalogProvider);
      ref.invalidate(myScreeningsProvider);
      ref.invalidate(preventionCenterProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      context.go('/app/home');
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clinical onboarding')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let\'s set up your clinical baseline',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text('Essential data to get started.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Required field'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Required field'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _birthDateController,
                      decoration: const InputDecoration(
                        labelText: 'Birth date (YYYY-MM-DD)',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required field';
                        }
                        if (DateTime.tryParse(value) == null) {
                          return 'Invalid format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _sex,
                      decoration: const InputDecoration(
                        labelText: 'Biological sex',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'intersex',
                          child: Text('Intersex'),
                        ),
                        DropdownMenuItem(
                          value: 'unknown',
                          child: Text('Prefer not to say'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _sex = value ?? 'female'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _smoker,
                      onChanged: (value) => setState(() => _smoker = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Smoker'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _activityLevel,
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
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'very_active',
                          child: Text('Very active'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _activityLevel = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _regionCode,
                      decoration: const InputDecoration(
                        labelText: 'Screening region',
                        helperText:
                            'Used to adapt screenings and prevention to your area.',
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
                          setState(() => _regionCode = value ?? 'IT'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _alcoholUse,
                      decoration: const InputDecoration(
                        labelText: 'Alcohol use',
                      ),
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
                      onChanged: (value) => setState(() => _alcoholUse = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _exerciseHabitsController,
                      decoration: const InputDecoration(
                        labelText: 'Usual exercise or physical activity',
                        hintText: 'E.g. running 3 times a week',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sleepPatternController,
                      decoration: const InputDecoration(
                        labelText: 'Usual sleep pattern',
                        hintText: 'E.g. irregular sleep due to shifts',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _occupationController,
                      decoration: const InputDecoration(
                        labelText: 'Work or daily context',
                        hintText: 'E.g. sedentary job / night shifts',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _symptomTriggersController,
                      decoration: const InputDecoration(
                        labelText: 'Known symptom triggers',
                        hintText: 'E.g. stress, little sleep, intense exertion',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _functionalLimitationsController,
                      decoration: const InputDecoration(
                        labelText: 'Functional limitations',
                        hintText: 'E.g. trouble with stairs or prolonged work',
                      ),
                      maxLines: 2,
                    ),
                    CheckboxListTile(
                      value: _consent,
                      onChanged: (value) =>
                          setState(() => _consent = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I consent to the processing of health data',
                      ),
                      subtitle: const Text('Required to use ClinDiary.'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.push('/legal/privacy'),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Read the beta privacy notice'),
                      ),
                    ),
                    CheckboxListTile(
                      value: _aiConsent,
                      onChanged: (value) =>
                          setState(() => _aiConsent = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I consent to the use of external AI providers',
                      ),
                      subtitle: const Text(
                        'If enabled, recaps can use external AI providers configured by the backend. If disabled, ClinDiary stays on the local cautious engine.',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.push('/legal/ai'),
                        icon: const Icon(Icons.psychology_alt_outlined),
                        label: const Text('Read the beta AI note'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(
                          _isSubmitting ? 'Saving...' : 'Complete onboarding',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
