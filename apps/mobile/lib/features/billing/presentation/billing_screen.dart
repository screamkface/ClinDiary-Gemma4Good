import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/billing/domain/billing_status.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({this.featureCode, super.key});

  final String? featureCode;

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  bool _isUpdatingPlan = false;

  Future<void> _activatePlan(String planCode) async {
    setState(() => _isUpdatingPlan = true);
    try {
      await ref.read(billingRepositoryProvider).activateDebugPlan(planCode);
      invalidatePatientScopedProviders(ref);
      ref.invalidate(billingStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Plus access enabled in demo.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPlan = false);
      }
    }
  }

  Future<void> _cancelPlan() async {
    setState(() => _isUpdatingPlan = true);
    try {
      await ref.read(billingRepositoryProvider).cancelDebugPlan();
      invalidatePatientScopedProviders(ref);
      ref.invalidate(billingStatusProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Plus demo disabled.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPlan = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billingAsync = ref.watch(billingStatusProvider);
    final featureLabel = _featureLabel(widget.featureCode);

    return Scaffold(
      appBar: AppBar(title: const Text('ClinDiary AI Plus')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(billingStatusProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
                title: 'Current plan',
              subtitle: featureLabel == null
                  ? 'The clinical core stays free. AI features unlock with AI Plus.'
                  : 'AI Plus is required to use "$featureLabel".',
              child: billingAsync.when(
                data: (status) {
                  if (status == null) {
                    return const Text('Sign in to view your plan.');
                  }
                  return _CurrentPlanBlock(
                    status: status,
                    isUpdatingPlan: _isUpdatingPlan,
                    onCancel: _cancelPlan,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(error.toString()),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'What it includes',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('Cloud document archive')),
                  Chip(label: Text('Daily AI recap')),
                  Chip(label: Text('Weekly and monthly recap')),
                  Chip(label: Text('Cautious pre-visit')),
                  Chip(label: Text('Ask the documents')),
                  Chip(label: Text('AI reports')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            billingAsync.when(
              data: (status) {
                if (status == null) {
                    return const SectionCard(
                    title: 'Plans',
                    child: Text('Sign in to load the available plans.'),
                  );
                }
                return Column(
                  children: status.availablePlans
                      .where((plan) => plan.isPublic)
                      .map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlanCard(
                            plan: plan,
                            currentPlanCode: status.currentPlan.code,
                            isUpdatingPlan: _isUpdatingPlan,
                            onActivate: _activatePlan,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const SectionCard(
                title: 'Plans',
                child: LinearProgressIndicator(),
              ),
              error: (error, _) =>
                  SectionCard(title: 'Piani', child: Text(error.toString())),
            ),
            const SizedBox(height: 12),
            SectionCard(
                title: 'Checkout',
              subtitle:
                  'StoreKit and Google Play Billing arrive in the next step. The paywall is already ready here on the product and backend side.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kDebugMode
                        ? 'In debug, you can enable AI Plus in the demo to test server-side gating.'
                        : 'Checkout nativo in preparazione.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push('/legal/ai'),
                        icon: const Icon(Icons.psychology_alt_outlined),
                        label: const Text('Beta AI note'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/legal/privacy'),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Beta privacy notice'),
                      ),
                    ],
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

class _CurrentPlanBlock extends StatelessWidget {
  const _CurrentPlanBlock({
    required this.status,
    required this.isUpdatingPlan,
    required this.onCancel,
  });

  final BillingStatus status;
  final bool isUpdatingPlan;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final currentPlan = status.currentPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(currentPlan.name)),
            Chip(label: Text(currentPlan.formattedPrice)),
            Chip(
                label: Text(
                status.hasActivePaidSubscription ? 'AI enabled' : 'Free core only',
              ),
            ),
          ],
        ),
        if (status.activeSubscription?.currentPeriodEnd != null) ...[
          const SizedBox(height: 12),
          Text(
            'Active until ${_shortDate(status.activeSubscription!.currentPeriodEnd!)}',
          ),
        ],
        if (kDebugMode && status.hasActivePaidSubscription) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isUpdatingPlan ? null : onCancel,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Switch back to Free'),
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currentPlanCode,
    required this.isUpdatingPlan,
    required this.onActivate,
  });

  final BillingPlan plan;
  final String currentPlanCode;
  final bool isUpdatingPlan;
  final Future<void> Function(String planCode) onActivate;

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentPlanCode == plan.code;

    return SectionCard(
      title: plan.name,
      subtitle: plan.description,
      action: isCurrent
          ? const Chip(label: Text('Current'))
          : (kDebugMode && !plan.isFree)
                ? FilledButton.tonalIcon(
                    onPressed: isUpdatingPlan ? null : () => onActivate(plan.code),
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('Enable demo'),
                  )
                : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(plan.formattedPrice)),
              if (plan.highlightLabel != null && plan.highlightLabel!.isNotEmpty)
                Chip(label: Text(plan.highlightLabel!)),
            ],
          ),
          if (plan.featureCodes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...plan.featureCodes.map((featureCode) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_featureLabel(featureCode) ?? featureCode)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

String? _featureLabel(String? featureCode) {
  switch (featureCode) {
    case 'ai_daily_summary':
      return 'Daily recap';
    case 'cloud_document_storage':
      return 'Cloud document archive';
    case 'ai_periodic_summaries':
      return 'Weekly and monthly recap';
    case 'ai_previsit_summary':
      return 'Pre-visit recap';
    case 'ai_document_query':
      return 'Ask the documents';
    case 'ai_report_generation':
      return 'AI reports';
    default:
      return null;
  }
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
