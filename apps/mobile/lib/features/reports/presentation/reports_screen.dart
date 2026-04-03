import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/reports/domain/clinical_report.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/feature_lock_card.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _reportType = 'weekly_summary';
  ClinicalReport? _latestReport;
  bool _isGenerating = false;
  String? _observedActiveProfileId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final report = await ref
          .read(reportsRepositoryProvider)
          .readCachedLatestReport();
      if (mounted) {
        setState(() => _latestReport = report);
      }
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    try {
      final report = await ref
          .read(reportsRepositoryProvider)
          .generateReport(reportType: _reportType);
      ref.invalidate(timelineEventsProvider);
      if (!mounted) return;
      setState(() => _latestReport = report);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isFeatureLocked) {
        context.push(
          '/app/home/billing?feature=${error.featureCode ?? 'ai_report_generation'}',
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _openReport(ClinicalReport report) async {
    if (report.downloadUrl == null || report.downloadUrl!.isEmpty) {
      return;
    }
    final config = ref.read(appConfigProvider);
    final uri = report.downloadUrl!.startsWith('http')
        ? Uri.parse(report.downloadUrl!)
        : Uri.parse('${config.apiBaseUrl}${report.downloadUrl!}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');
    final activeProfileId = ref.watch(activeProfileIdProvider).asData?.value;
    final billingStatusAsync = ref.watch(billingStatusProvider);
    final requiresAiPlan = _reportType != 'screening_status_report';
    final proactiveLock =
        requiresAiPlan &&
        billingStatusAsync.asData?.value?.hasFeature('ai_report_generation') ==
            false;

    if (_observedActiveProfileId != activeProfileId) {
      _observedActiveProfileId = activeProfileId;
      Future<void>.microtask(() async {
        final report = await ref
            .read(reportsRepositoryProvider)
            .readCachedLatestReport();
        if (mounted) {
          setState(() => _latestReport = report);
        }
      });
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Report clinici'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Genera'),
              Tab(text: 'Ultimo report'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ClinicalScopeNotice(
                  title: 'Report informativo',
                  message:
                      'I report AI servono per organizzare informazioni e andamento clinico. Non equivalgono a una valutazione medica o a una prescrizione.',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Genera report',
                  subtitle: 'Scegli il periodo e crea un report ordinato.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _reportType,
                        decoration: const InputDecoration(labelText: 'Tipo report'),
                        items: const [
                          DropdownMenuItem(
                            value: 'weekly_summary',
                            child: Text('Recap settimanale'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly_summary',
                            child: Text('Recap mensile'),
                          ),
                          DropdownMenuItem(
                            value: 'pre_visit_report',
                            child: Text('Preparazione visita'),
                          ),
                          DropdownMenuItem(
                            value: 'screening_status_report',
                            child: Text('Stato prevenzione'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _reportType = value ?? 'weekly_summary');
                        },
                      ),
                      const SizedBox(height: 16),
                      if (proactiveLock)
                        FeatureLockCard(
                          title: 'AI Plus richiesto',
                          compact: true,
                          featureLabel: 'Report AI',
                          message:
                              'I report narrativi AI fanno parte di ClinDiary AI Plus. Il report prevenzione deterministico resta disponibile anche nel piano Free.',
                          onOpenBilling: () => context.push(
                            '/app/home/billing?feature=ai_report_generation',
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _isGenerating ? null : _generateReport,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(
                            _isGenerating ? 'Generazione...' : 'Rigenera report',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_latestReport != null)
                  SectionCard(
                    title: _latestReport!.title,
                    subtitle: 'Ultimo report disponibile per il profilo attivo.',
                    action: FilledButton.tonalIcon(
                      onPressed: _latestReport!.downloadUrl == null
                          ? null
                          : () => _openReport(_latestReport!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Apri PDF'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(_labelFor(_latestReport!.reportType))),
                            Chip(
                              label: Text(
                                '${_latestReport!.periodStart.toIso8601String().split('T').first} - ${_latestReport!.periodEnd.toIso8601String().split('T').first}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                dateFormat.format(
                                  _latestReport!.generatedAt.toLocal(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_latestReport!.processingError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _latestReport!.processingError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SummaryContentView(
                          content: _latestReport!.contentText,
                          maxHeightFactor: 0.7,
                        ),
                      ],
                    ),
                  )
                else
                  const SectionCard(
                    title: 'Ultimo report',
                    child: Text(
                      'Non hai ancora generato report per questo profilo.',
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

String _labelFor(String reportType) {
  switch (reportType) {
    case 'monthly_summary':
      return 'Recap mensile';
    case 'pre_visit_report':
      return 'Preparazione visita';
    case 'screening_status_report':
      return 'Stato prevenzione';
    default:
      return 'Recap settimanale';
  }
}
