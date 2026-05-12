import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:clindiary/shared/widgets/clin_diary_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _lastStep = 4;

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

  int _currentStep = 0;
  String _sex = 'female';
  String? _alcoholUse;
  String? _activityLevel;
  bool _smoker = false;
  bool _consent = false;
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 35, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked == null) {
      return;
    }
    _birthDateController.text = _formatDate(picked);
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bundle = await ref
          .read(profileRepositoryProvider)
          .completeOnboarding(
            payload: {
              'health_data_consent': _consent,
              'ai_external_consent': false,
              'first_name': _firstNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'birth_date': _birthDateController.text.trim(),
              'biological_sex': _sex,
              'height_cm': double.tryParse(_heightController.text.trim()),
              'weight_kg': double.tryParse(_weightController.text.trim()),
              'smoker': _smoker,
              'alcohol_use': _alcoholUse,
              'activity_level': _activityLevel,
              'occupation': _nullableText(_occupationController),
              'exercise_habits': _nullableText(_exerciseHabitsController),
              'sleep_pattern': _nullableText(_sleepPatternController),
              'symptom_triggers': _nullableText(_symptomTriggersController),
              'functional_limitations': _nullableText(
                _functionalLimitationsController,
              ),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == _lastStep && !_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health data consent is required to use ClinDiary.'),
        ),
      );
      return false;
    }
    return _formKey.currentState?.validate() ?? true;
  }

  void _goNext() {
    if (!_validateCurrentStep()) {
      return;
    }
    if (_currentStep == _lastStep) {
      _submit();
      return;
    }
    setState(() => _currentStep += 1);
  }

  void _goBack() {
    if (_currentStep == 0) {
      return;
    }
    setState(() => _currentStep -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: _OnboardingHeader(
                      currentStep: _currentStep,
                      totalSteps: _lastStep + 1,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(_currentStep),
                                child: _buildCurrentStep(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          TextButton.icon(
                            onPressed: _isSubmitting ? null : _goBack,
                            icon: const Icon(Icons.arrow_back_outlined),
                            label: const Text('Back'),
                          )
                        else
                          const Spacer(),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _goNext,
                          icon: Icon(
                            _currentStep == _lastStep
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward_outlined,
                          ),
                          label: Text(
                            _isSubmitting
                                ? 'Saving...'
                                : _currentStep == _lastStep
                                ? 'Start using ClinDiary'
                                : 'Continue',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    return switch (_currentStep) {
      0 => _buildWelcomeStep(context),
      1 => _buildIdentityStep(context),
      2 => _buildClinicalBaselineStep(context),
      3 => _buildLifestyleStep(context),
      _ => _buildPrivacyStep(context),
    };
  }

  Widget _buildWelcomeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: ClinDiaryLogo(size: 84)),
        const SizedBox(height: 18),
        Text(
          'Welcome to ClinDiary',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'In a few guided steps we will create your local clinical diary, explain the main areas, and keep your data on this device by default.',
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FeatureIntroCard(
              icon: Icons.today_outlined,
              title: 'Daily diary',
              body: 'Track symptoms, vitals, notes, sleep and daily context.',
            ),
            _FeatureIntroCard(
              icon: Icons.folder_copy_outlined,
              title: 'Encrypted vault',
              body: 'Keep documents in a local AES-GCM encrypted archive.',
            ),
            _FeatureIntroCard(
              icon: Icons.psychology_alt_outlined,
              title: 'On-device AI',
              body:
                  'Generate cautious summaries without delegating safety rules.',
            ),
            _FeatureIntroCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Prevention',
              body:
                  'Use deterministic local logic for screenings and reminders.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdentityStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.person_outline,
          title: 'Your personal baseline',
          subtitle:
              'These fields personalize diary views and prevention logic.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(labelText: 'First name'),
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(labelText: 'Last name'),
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _birthDateController,
          decoration: InputDecoration(
            labelText: 'Birth date (YYYY-MM-DD)',
            suffixIcon: IconButton(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Required field';
            }
            if (DateTime.tryParse(value.trim()) == null) {
              return 'Invalid format';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(labelText: 'Biological sex'),
          items: const [
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'intersex', child: Text('Intersex')),
            DropdownMenuItem(
              value: 'unknown',
              child: Text('Prefer not to say'),
            ),
          ],
          onChanged: (value) => setState(() => _sex = value ?? 'female'),
        ),
      ],
    );
  }

  Widget _buildClinicalBaselineStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.monitor_heart_outlined,
          title: 'Clinical context',
          subtitle:
              'Optional values help trends, reports and prevention cards.',
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
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          value: _smoker,
          onChanged: (value) => setState(() => _smoker = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Current smoker'),
          subtitle: const Text('Used only for local prevention logic.'),
        ),
      ],
    );
  }

  Widget _buildLifestyleStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.directions_walk_outlined,
          title: 'Lifestyle and symptom context',
          subtitle:
              'You can complete or edit these later from the profile area.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _activityLevel,
          decoration: const InputDecoration(labelText: 'Activity level'),
          items: const [
            DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'very_active', child: Text('Very active')),
          ],
          onChanged: (value) => setState(() => _activityLevel = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _alcoholUse,
          decoration: const InputDecoration(labelText: 'Alcohol use'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'occasional', child: Text('Occasional')),
            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
            DropdownMenuItem(value: 'high', child: Text('High')),
          ],
          onChanged: (value) => setState(() => _alcoholUse = value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _exerciseHabitsController,
          decoration: const InputDecoration(
            labelText: 'Usual exercise or physical activity',
            hintText: 'E.g. walking 30 minutes most days',
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
            hintText: 'E.g. trouble with stairs or prolonged standing',
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
      ],
    );
  }

  Widget _buildPrivacyStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy and safety',
          subtitle: 'ClinDiary is local-first and keeps AI output assistive.',
        ),
        const SizedBox(height: 16),
        const _PrivacyPoint(
          icon: Icons.storage_outlined,
          title: 'Local diary data',
          body: 'Health diary data is stored locally on this device.',
        ),
        const _PrivacyPoint(
          icon: Icons.lock_outline,
          title: 'Encrypted document vault',
          body: 'Uploaded documents are stored in the encrypted local vault.',
        ),
        const _PrivacyPoint(
          icon: Icons.health_and_safety_outlined,
          title: 'No AI diagnosis',
          body: 'Generated summaries do not diagnose, prescribe or triage.',
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _consent,
          onChanged: (value) => setState(() => _consent = value ?? false),
          contentPadding: EdgeInsets.zero,
          title: const Text('I consent to the processing of health data'),
          subtitle: const Text('Required to use ClinDiary on this device.'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => context.push('/legal/privacy'),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Read privacy notice'),
            ),
            TextButton.icon(
              onPressed: () => context.push('/legal/ai'),
              icon: const Icon(Icons.psychology_alt_outlined),
              label: const Text('Read AI note'),
            ),
          ],
        ),
      ],
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ClinDiaryLogo(size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set up ClinDiary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('Step ${currentStep + 1} of $totalSteps'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Icon(icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureIntroCard extends StatelessWidget {
  const _FeatureIntroCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}
