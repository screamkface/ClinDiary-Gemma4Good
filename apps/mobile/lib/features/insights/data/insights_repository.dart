import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/insights/domain/insight_summary.dart';
import 'package:clindiary/features/insights/domain/local_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_ai_status.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:clindiary/features/insights/domain/on_device_text_prompt.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:intl/intl.dart';

class InsightsRepository {
  InsightsRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
    required OnDeviceAiService onDeviceAiService,
    required OnDevicePromptBuilder onDevicePromptBuilder,
    AppConfig appConfig = defaultAppConfig,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase,
       _onDeviceAiService = onDeviceAiService,
       _onDevicePromptBuilder = onDevicePromptBuilder,
       _appConfig = appConfig;

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;
  final OnDeviceAiService _onDeviceAiService;
  final OnDevicePromptBuilder _onDevicePromptBuilder;
  final AppConfig _appConfig;

  Future<InsightSummary> fetchSummary(InsightSummaryQuery query) async {
    if (_appConfig.localOnlyMode) {
      return _fetchLocalOnlySummary(query);
    }

    if (query.summaryType == 'daily' &&
        query.mode == InsightSummaryMode.onDevice) {
      return _fetchOnDeviceSummary(query);
    }

    final fullPath = _buildPath(query);

    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson(fullPath);
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey(query)),
        payload: jsonEncode(response),
      );
      return InsightSummary.fromJson(response);
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(query),
      );
      if (cached == null) rethrow;
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(query),
      );
      if (cached == null) rethrow;
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
  }

  Future<InsightSummary> regenerateSummary(InsightSummaryQuery query) async {
    if (_appConfig.localOnlyMode) {
      return _fetchLocalOnlySummary(query, forceRegenerate: true);
    }

    if (query.summaryType == 'daily' &&
        query.mode == InsightSummaryMode.onDevice) {
      return _fetchOnDeviceSummary(query);
    }

    final response = await _apiClient.postJson(
      _buildPath(query, regenerate: true),
    );
    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _cacheKey(query)),
      payload: jsonEncode(response),
    );
    return InsightSummary.fromJson(response);
  }

  Future<LocalAiStatus> fetchLocalStatus() async {
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.getJson('/api/v1/insights/local-status');
    return LocalAiStatus.fromJson(response);
  }

  Future<OnDeviceAiStatus> fetchOnDeviceStatus() async {
    return _onDeviceAiService.fetchStatus();
  }

  Future<InsightSummary> _fetchOnDeviceSummary(
    InsightSummaryQuery query,
  ) async {
    try {
      final prompt =
          await _onDevicePromptBuilder.buildDailyRecapPrompt(
            referenceDate: query.referenceDate ?? DateTime.now(),
          ) ??
          await _fetchBackendOnDevicePrompt(query);
      final summary = await _onDeviceAiService.generateDailyRecap(
        prompt: prompt,
      );
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, _cacheKey(query)),
        payload: jsonEncode({
          'id': summary.id,
          'summary_type': summary.summaryType,
          'period_start': summary.periodStart.toIso8601String(),
          'period_end': summary.periodEnd.toIso8601String(),
          'content': summary.content,
          'provider_name': summary.providerName,
          'model_name': summary.modelName,
          'generated_at': summary.generatedAt.toIso8601String(),
        }),
      );
      return summary;
    } on ApiException {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(query),
      );
      if (cached == null) rethrow;
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    } catch (_) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        _cacheKey(query),
      );
      if (cached == null) rethrow;
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
  }

  Future<OnDeviceRecapPrompt> _fetchBackendOnDevicePrompt(
    InsightSummaryQuery query,
  ) async {
    final fullPath = _buildPath(query);
    await _apiClient.flushPendingOperations();
    final response = await _apiClient.getJson(fullPath);
    return OnDeviceRecapPrompt.fromJson(response);
  }

  String _buildPath(InsightSummaryQuery query, {bool regenerate = false}) {
    final summaryType = query.summaryType;
    final basePath =
        summaryType == 'daily' && query.mode == InsightSummaryMode.privateLocal
        ? '/api/v1/insights/daily/private-local'
        : summaryType == 'daily' && query.mode == InsightSummaryMode.onDevice
        ? '/api/v1/insights/daily/on-device-prompt'
        : switch (summaryType) {
            'daily' => '/api/v1/insights/daily',
            'weekly' => '/api/v1/insights/weekly',
            'monthly' => '/api/v1/insights/monthly',
            _ => '/api/v1/insights/pre-visit',
          };
    final path = regenerate ? '$basePath/regenerate' : basePath;
    return query.referenceDate == null
        ? path
        : '$path?reference_date=${DateFormat('yyyy-MM-dd').format(query.referenceDate!)}';
  }

  Future<InsightSummary> _fetchLocalOnlySummary(
    InsightSummaryQuery query, {
    bool forceRegenerate = false,
  }) async {
    final cacheKey = _cacheKey(query);
    if (!forceRegenerate) {
      final cached = await readProfileScopedCache(_localDatabase, cacheKey);
      if (cached != null) {
        return InsightSummary.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    try {
      final summary = query.summaryType == 'daily'
          ? await _generateLocalDailySummary(query)
          : await _generateLocalTextSummary(query);
      await _localDatabase.putCache(
        key: await profileScopedCacheKey(_localDatabase, cacheKey),
        payload: jsonEncode({
          'id': summary.id,
          'summary_type': summary.summaryType,
          'period_start': summary.periodStart.toIso8601String(),
          'period_end': summary.periodEnd.toIso8601String(),
          'content': summary.content,
          'provider_name': summary.providerName,
          'model_name': summary.modelName,
          'generated_at': summary.generatedAt.toIso8601String(),
        }),
      );
      return summary;
    } catch (_) {
      final cached = await readProfileScopedCache(_localDatabase, cacheKey);
      if (cached == null) {
        rethrow;
      }
      return InsightSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
  }

  Future<InsightSummary> _generateLocalDailySummary(
    InsightSummaryQuery query,
  ) async {
    final dailyQuery = InsightSummaryQuery(
      summaryType: 'daily',
      referenceDate: query.referenceDate,
      mode: InsightSummaryMode.onDevice,
    );
    final daily = await _fetchOnDeviceSummary(dailyQuery);
    if (query.mode == InsightSummaryMode.privateLocal) {
      return InsightSummary(
        id: daily.id,
        summaryType: daily.summaryType,
        periodStart: daily.periodStart,
        periodEnd: daily.periodEnd,
        content: daily.content,
        providerName: 'local_gemma4',
        modelName: daily.modelName,
        generatedAt: daily.generatedAt,
      );
    }
    return daily;
  }

  Future<InsightSummary> _generateLocalTextSummary(
    InsightSummaryQuery query,
  ) async {
    final prompt = await _buildPromptForSummary(query);
    final referenceDate = query.referenceDate ?? DateTime.now();
    final now = DateTime.now().toUtc();

    if (prompt != null) {
      final content = await _onDeviceAiService.generateText(
        systemPrompt: prompt.systemPrompt,
        userPrompt: prompt.userPrompt,
      );
      return InsightSummary(
        id: 'local-${query.summaryType}-${now.millisecondsSinceEpoch}',
        summaryType: query.summaryType,
        periodStart: prompt.periodStart,
        periodEnd: prompt.periodEnd,
        content: content,
        providerName: 'on_device_litertlm',
        modelName: 'gemma-4-E2B-it.litertlm',
        generatedAt: now,
      );
    }

    final periodStart = query.summaryType == 'weekly'
        ? referenceDate.subtract(const Duration(days: 6))
        : query.summaryType == 'monthly'
        ? DateTime(referenceDate.year, referenceDate.month, 1)
        : referenceDate.subtract(const Duration(days: 30));

    return InsightSummary(
      id: 'local-${query.summaryType}-${now.millisecondsSinceEpoch}',
      summaryType: query.summaryType,
      periodStart: periodStart,
      periodEnd: referenceDate,
      content:
          'Local-only summary generated in deterministic fallback mode. Review diary entries, documents, wearable signals, and alerts for this period before clinical decisions.',
      providerName: 'local_gemma4',
      modelName: 'fallback-local',
      generatedAt: now,
    );
  }

  Future<OnDeviceTextPrompt?> _buildPromptForSummary(
    InsightSummaryQuery query,
  ) {
    final referenceDate = query.referenceDate ?? DateTime.now();
    switch (query.summaryType) {
      case 'weekly':
      case 'monthly':
        return _onDevicePromptBuilder.buildTrendExplanationPrompt(
          referenceDate: referenceDate,
        );
      case 'pre_visit':
        return _onDevicePromptBuilder.buildPreVisitBriefPrompt(
          referenceDate: referenceDate,
        );
      default:
        return _onDevicePromptBuilder.buildTrendExplanationPrompt(
          referenceDate: referenceDate,
        );
    }
  }

  static String _cacheKey(InsightSummaryQuery query) {
    final suffix = query.referenceDate == null
        ? 'latest'
        : DateFormat('yyyy-MM-dd').format(query.referenceDate!);
    final mode = switch (query.mode) {
      InsightSummaryMode.privateLocal => 'private_local',
      InsightSummaryMode.onDevice => 'on_device',
      InsightSummaryMode.standard => 'default',
    };
    return 'insight_${query.summaryType}_${mode}_$suffix';
  }
}
