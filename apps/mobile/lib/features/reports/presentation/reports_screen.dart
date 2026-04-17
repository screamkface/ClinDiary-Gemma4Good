import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/reports/domain/clinical_report.dart';
import 'package:clindiary/shared/widgets/clinical_scope_notice.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:clindiary/shared/widgets/summary_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
        const SnackBar(content: Text('Unable to open the report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');
    final activeProfileId = ref.watch(activeProfileIdProvider).asData?.value;

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
          title: const Text('Clinical reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Generate'),
              Tab(text: 'Latest report'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ClinicalScopeNotice(
                  title: 'Informational report',
                  message:
                      'AI reports are used to organize information and clinical trends. They are not equivalent to a medical assessment or prescription.',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Generate report',
                  subtitle: 'Choose the period and create an ordered report.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _reportType,
                        decoration: const InputDecoration(
                          labelText: 'Report type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'weekly_summary',
                            child: Text('Weekly recap'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly_summary',
                            child: Text('Monthly recap'),
                          ),
                          DropdownMenuItem(
                            value: 'pre_visit_report',
                            child: Text('Visit preparation'),
                          ),
                          DropdownMenuItem(
                            value: 'screening_status_report',
                            child: Text('Prevention status'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(
                            () => _reportType = value ?? 'weekly_summary',
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isGenerating ? null : _generateReport,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _isGenerating ? 'Generating...' : 'Regenerate report',
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
                    subtitle: 'Latest report available for the active profile.',
                    action: FilledButton.tonalIcon(
                      onPressed: _latestReport!.downloadUrl == null
                          ? null
                          : () => _openReport(_latestReport!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open PDF'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(_labelFor(_latestReport!.reportType)),
                            ),
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
                    title: 'Latest report',
                    child: Text(
                      'You have not generated a report for this profile yet.',
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
      return 'Monthly recap';
    case 'pre_visit_report':
      return 'Visit preparation';
    case 'screening_status_report':
      return 'Prevention status';
    default:
      return 'Weekly recap';
  }
}
