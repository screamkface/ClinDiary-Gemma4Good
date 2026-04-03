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
        const SnackBar(content: Text('Accesso AI Plus attivato in demo.')),
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
        const SnackBar(content: Text('AI Plus demo disattivato.')),
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
              title: 'Piano attuale',
              subtitle: featureLabel == null
                  ? 'Il core clinico resta gratuito. Le funzioni AI si sbloccano con AI Plus.'
                  : 'Per usare "$featureLabel" serve AI Plus.',
              child: billingAsync.when(
                data: (status) {
                  if (status == null) {
                    return const Text('Accedi per vedere il tuo piano.');
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
              title: 'Cosa include',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('Archivio documenti cloud')),
                  Chip(label: Text('Recap giornaliero AI')),
                  Chip(label: Text('Recap settimana e mese')),
                  Chip(label: Text('Pre-visita prudente')),
                  Chip(label: Text('Chiedi ai documenti')),
                  Chip(label: Text('Report AI')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            billingAsync.when(
              data: (status) {
                if (status == null) {
                  return const SectionCard(
                    title: 'Piani',
                    child: Text('Accedi per caricare i piani disponibili.'),
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
                title: 'Piani',
                child: LinearProgressIndicator(),
              ),
              error: (error, _) =>
                  SectionCard(title: 'Piani', child: Text(error.toString())),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Checkout',
              subtitle:
                  'StoreKit e Google Play Billing arrivano nel passo successivo. Qui il paywall e gia pronto lato prodotto e backend.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kDebugMode
                        ? 'In debug puoi attivare AI Plus in demo per testare il gating server-side.'
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
                        label: const Text('Nota AI beta'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/legal/privacy'),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Privacy beta'),
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
                status.hasActivePaidSubscription ? 'AI attiva' : 'Solo core free',
              ),
            ),
          ],
        ),
        if (status.activeSubscription?.currentPeriodEnd != null) ...[
          const SizedBox(height: 12),
          Text(
            'Attivo fino al ${_shortDate(status.activeSubscription!.currentPeriodEnd!)}',
          ),
        ],
        if (kDebugMode && status.hasActivePaidSubscription) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isUpdatingPlan ? null : onCancel,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Torna al piano Free'),
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
          ? const Chip(label: Text('Attuale'))
          : (kDebugMode && !plan.isFree)
                ? FilledButton.tonalIcon(
                    onPressed: isUpdatingPlan ? null : () => onActivate(plan.code),
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('Attiva demo'),
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
      return 'Recap giornaliero';
    case 'cloud_document_storage':
      return 'Archivio documenti cloud';
    case 'ai_periodic_summaries':
      return 'Recap settimana e mese';
    case 'ai_previsit_summary':
      return 'Recap pre-visita';
    case 'ai_document_query':
      return 'Domande ai documenti';
    case 'ai_report_generation':
      return 'Report AI';
    default:
      return null;
  }
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
