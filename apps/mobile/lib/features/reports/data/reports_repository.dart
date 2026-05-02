import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:clindiary/features/insights/domain/on_device_text_prompt.dart';
import 'package:clindiary/features/reports/domain/clinical_report.dart';

class ReportsRepository {
  ReportsRepository({
    required LocalDatabase localDatabase,
    AppConfig appConfig = defaultAppConfig,
    OnDeviceAiService? onDeviceAiService,
    OnDevicePromptBuilder? onDevicePromptBuilder,
  }) : _localDatabase = localDatabase,
       _appConfig = appConfig,
       _onDeviceAiService = onDeviceAiService ?? OnDeviceAiService(),
       _onDevicePromptBuilder =
           onDevicePromptBuilder ??
           OnDevicePromptBuilder(localDatabase: localDatabase);

  static const _lastReportCacheKey = 'reports_last_generated';

  final LocalDatabase _localDatabase;
  final AppConfig _appConfig;
  final OnDeviceAiService _onDeviceAiService;
  final OnDevicePromptBuilder _onDevicePromptBuilder;

  Future<ClinicalReport> generateReport({
    required String reportType,
    DateTime? referenceDate,
  }) async {
    final response = _buildReportJson(
      await _generateLocalReport(
        reportType: reportType,
        referenceDate: referenceDate ?? DateTime.now(),
      ),
    );
    await _localDatabase.putCache(
      key: await _cacheKeyForCurrentProfile(),
      payload: jsonEncode(response),
    );
    return ClinicalReport.fromJson(response);
  }

  Future<ClinicalReport?> readCachedLatestReport() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      final cached = await _localDatabase.readCache(
        '$_lastReportCacheKey::$normalizedActiveId',
      );
      if (cached == null) {
        return null;
      }
      return ClinicalReport.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
    final cached = await _localDatabase.readCache(_lastReportCacheKey);
    if (cached == null) {
      return null;
    }
    return ClinicalReport.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  Future<String> _cacheKeyForCurrentProfile() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return '$_lastReportCacheKey::$normalizedActiveId';
    }
    return _lastReportCacheKey;
  }

  Future<ClinicalReport> _generateLocalReport({
    required String reportType,
    required DateTime referenceDate,
  }) async {
    final now = DateTime.now().toUtc();
    final normalizedDate = DateTime.utc(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    final period = _resolvePeriod(reportType, normalizedDate);
    final prompt = await _buildPromptForReport(
      reportType: reportType,
      referenceDate: normalizedDate,
    );

    final content = await _generateReportContent(
      reportType: reportType,
      prompt: prompt,
      periodStart: period.$1,
      periodEnd: period.$2,
    );

    return ClinicalReport(
      id: 'local-report-${now.millisecondsSinceEpoch}',
      reportType: reportType,
      status: 'generated',
      title: _titleForReportType(reportType),
      periodStart: period.$1,
      periodEnd: period.$2,
      summaryExcerpt: content.length > 180
          ? '${content.substring(0, 180)}...'
          : content,
      contentText: content,
      generatedAt: now,
      processingError: null,
      downloadUrl: null,
    );
  }

  Future<OnDeviceTextPrompt?> _buildPromptForReport({
    required String reportType,
    required DateTime referenceDate,
  }) {
    switch (reportType) {
      case 'pre_visit_report':
        return _onDevicePromptBuilder.buildPreVisitBriefPrompt(
          referenceDate: referenceDate,
        );
      case 'screening_status_report':
        return _onDevicePromptBuilder.buildClinicalQuestionPrompt(
          question:
              'Summarize prevention status, pending screenings, and practical follow-up actions for this profile.',
          referenceDate: referenceDate,
        );
      case 'monthly_summary':
      case 'weekly_summary':
      default:
        return _onDevicePromptBuilder.buildTrendExplanationPrompt(
          referenceDate: referenceDate,
        );
    }
  }

  Future<String> _generateReportContent({
    required String reportType,
    required OnDeviceTextPrompt? prompt,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    if (prompt != null) {
      try {
        return await _onDeviceAiService.generateText(
          systemPrompt: prompt.systemPrompt,
          userPrompt: prompt.userPrompt,
        );
      } catch (_) {
        // Fallback is intentionally deterministic for local-only mode.
      }
    }

    final reportLabel = _titleForReportType(reportType);
    return 'Local $reportLabel generated in deterministic fallback mode. '
        'Period: ${periodStart.toIso8601String().split('T').first} to '
        '${periodEnd.toIso8601String().split('T').first}. '
        'Review diary entries, medications, documents, and prevention tasks before sharing this report with a clinician.';
  }

  (DateTime, DateTime) _resolvePeriod(
    String reportType,
    DateTime referenceDate,
  ) {
    switch (reportType) {
      case 'pre_visit_report':
        return (
          referenceDate.subtract(const Duration(days: 30)),
          referenceDate,
        );
      case 'monthly_summary':
        final start = DateTime.utc(referenceDate.year, referenceDate.month, 1);
        final nextMonth = referenceDate.month == 12
            ? DateTime.utc(referenceDate.year + 1, 1, 1)
            : DateTime.utc(referenceDate.year, referenceDate.month + 1, 1);
        return (start, nextMonth.subtract(const Duration(days: 1)));
      case 'screening_status_report':
        return (
          referenceDate.subtract(const Duration(days: 90)),
          referenceDate,
        );
      case 'weekly_summary':
      default:
        return (referenceDate.subtract(const Duration(days: 6)), referenceDate);
    }
  }

  String _titleForReportType(String reportType) {
    switch (reportType) {
      case 'monthly_summary':
        return 'Monthly clinical report';
      case 'pre_visit_report':
        return 'Pre-visit preparation report';
      case 'screening_status_report':
        return 'Prevention status report';
      case 'weekly_summary':
      default:
        return 'Weekly clinical report';
    }
  }

  Map<String, dynamic> _buildReportJson(ClinicalReport report) {
    return {
      'id': report.id,
      'report_type': report.reportType,
      'status': report.status,
      'title': report.title,
      'period_start': report.periodStart.toUtc().toIso8601String(),
      'period_end': report.periodEnd.toUtc().toIso8601String(),
      'summary_excerpt': report.summaryExcerpt,
      'content_text': report.contentText,
      'generated_at': report.generatedAt.toUtc().toIso8601String(),
      'processing_error': report.processingError,
      'download_url': report.downloadUrl,
    };
  }
}
