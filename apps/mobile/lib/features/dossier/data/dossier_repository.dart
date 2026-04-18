import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';

class DossierRepository {
  DossierRepository({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
    AppConfig appConfig = defaultAppConfig,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase,
       _appConfig = appConfig;

  static const _cacheKey = 'health_dossier';
  static const _shareLinksCacheKey = 'dossier_share_links';

  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;
  final AppConfig _appConfig;

  Future<HealthDossier> fetchDossier() async {
    if (_appConfig.localOnlyMode) {
      final cached = await _readCachedDossier();
      if (cached == null) {
        throw ApiException(
          'No local dossier snapshot is available yet. Generate or import a backup first.',
          statusCode: 404,
        );
      }
      return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    try {
      await _apiClient.flushPendingOperations();
      final response = await _apiClient.getJson('/api/v1/dossier');
      await _localDatabase.putCache(
        key: await _cacheKeyForCurrentProfile(),
        payload: jsonEncode(response),
      );
      return HealthDossier.fromJson(response);
    } on ApiException {
      final cached = await _readCachedDossier();
      if (cached == null) rethrow;
      return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } catch (error) {
      final cached = await _readCachedDossier();
      if (cached == null) rethrow;
      return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  Future<List<int>> exportDossier() async {
    if (!_appConfig.localOnlyMode) {
      return _apiClient.getBytes('/api/v1/dossier/export');
    }

    final dossier = await _loadCachedDossierOrThrow();
    final lines = <String>[
      'ClinDiary Health Dossier',
      'Generated at: ${dossier.generatedAt.toIso8601String()}',
      'Profile: ${dossier.displayName}, age ${dossier.age}',
      '',
      'Emergency summary:',
      dossier.emergencySummary.headline,
      ...dossier.emergencySummary.keyPoints.map((item) => '- $item'),
      '',
      'Active medications:',
      ...dossier.emergencySummary.activeMedications.map((item) => '- $item'),
      '',
      'Open alerts:',
      ...dossier.emergencySummary.openAlerts.map((item) => '- $item'),
    ];
    return _buildSimplePdf(lines);
  }

  Future<List<int>> exportDossierJson() async {
    if (!_appConfig.localOnlyMode) {
      return _apiClient.getBytes('/api/v1/dossier/export/json');
    }

    final cached = await _readCachedDossier();
    if (cached == null) {
      throw ApiException(
        'No local dossier snapshot is available yet. Generate or import a backup first.',
        statusCode: 404,
      );
    }
    return utf8.encode(cached);
  }

  Future<List<int>> exportEmergencyDossier() async {
    if (!_appConfig.localOnlyMode) {
      return _apiClient.getBytes('/api/v1/dossier/export/emergency');
    }

    final dossier = await _loadCachedDossierOrThrow();
    final summary = dossier.emergencySummary;
    final lines = <String>[
      'ClinDiary Emergency Card',
      'Generated at: ${summary.generatedAt.toIso8601String()}',
      'Profile: ${dossier.displayName}',
      '',
      summary.headline,
      ...summary.keyPoints.map((item) => '- $item'),
      '',
      'Allergies:',
      ...summary.allergies.map((item) => '- $item'),
      '',
      'Conditions:',
      ...summary.conditions.map((item) => '- $item'),
    ];
    return _buildSimplePdf(lines);
  }

  Future<HealthDossier> importDossier({
    required Map<String, dynamic> snapshot,
    bool replaceExisting = true,
  }) async {
    if (_appConfig.localOnlyMode) {
      final normalized = snapshot['snapshot'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              snapshot['snapshot'] as Map<String, dynamic>,
            )
          : Map<String, dynamic>.from(snapshot);
      final dossier = HealthDossier.fromJson(normalized);
      await _localDatabase.putCache(
        key: await _cacheKeyForCurrentProfile(),
        payload: jsonEncode(normalized),
      );
      return dossier;
    }

    final response = await _apiClient.postJson(
      '/api/v1/dossier/import',
      body: {'snapshot': snapshot, 'replace_existing': replaceExisting},
    );
    final dossier = HealthDossier.fromJson(response);
    await _localDatabase.putCache(
      key: await _cacheKeyForCurrentProfile(),
      payload: jsonEncode(response),
    );
    return dossier;
  }

  Future<List<DossierShareLinkItem>> fetchShareLinks() async {
    if (_appConfig.localOnlyMode) {
      final cached = await _readCachedShareLinks();
      if (cached == null) {
        return const [];
      }
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) =>
                DossierShareLinkItem.fromJson(item as Map<String, dynamic>),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final response = await _apiClient.getJson('/api/v1/dossier/share-links');
    return (response as List<dynamic>)
        .map(
          (item) => DossierShareLinkItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<DossierShareLinkItem> createShareLink({
    required String scope,
    String? label,
    int expiresInDays = 7,
  }) async {
    if (_appConfig.localOnlyMode) {
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(Duration(days: expiresInDays.clamp(1, 365)));
      final item = <String, dynamic>{
        'id': 'local-share-${DateTime.now().microsecondsSinceEpoch}',
        'scope': scope,
        'label': label,
        'share_url': null,
        'filename': scope == 'emergency'
            ? 'dossier-emergency.pdf'
            : 'dossier.pdf',
        'mime_type': 'application/pdf',
        'expires_at': expiresAt.toIso8601String(),
        'revoked_at': null,
        'last_accessed_at': null,
        'created_at': now.toIso8601String(),
      };

      final links =
          await _readCachedShareLinksJson() ?? <Map<String, dynamic>>[];
      links.insert(0, item);
      await _writeCachedShareLinksJson(links);
      return DossierShareLinkItem.fromJson(item);
    }
    final response = await _apiClient.postJson(
      '/api/v1/dossier/share-links',
      body: {'scope': scope, 'label': label, 'expires_in_days': expiresInDays},
    );
    return DossierShareLinkItem.fromJson(response);
  }

  Future<void> revokeShareLink(String shareLinkId) async {
    if (_appConfig.localOnlyMode) {
      final links =
          await _readCachedShareLinksJson() ?? <Map<String, dynamic>>[];
      var changed = false;
      for (final link in links) {
        if (link['id']?.toString() == shareLinkId) {
          link['revoked_at'] = DateTime.now().toUtc().toIso8601String();
          changed = true;
          break;
        }
      }
      if (changed) {
        await _writeCachedShareLinksJson(links);
      }
      return;
    }
    await _apiClient.delete('/api/v1/dossier/share-links/$shareLinkId');
  }

  Future<List<Map<String, dynamic>>?> _readCachedShareLinksJson() async {
    final cached = await _readCachedShareLinks();
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeCachedShareLinksJson(
    List<Map<String, dynamic>> items,
  ) async {
    await _localDatabase.putCache(
      key: await _shareLinksCacheKeyForCurrentProfile(),
      payload: jsonEncode(items),
    );
  }

  Future<String?> _readCachedShareLinks() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return _localDatabase.readCache(
        '$_shareLinksCacheKey::$normalizedActiveId',
      );
    }
    return _localDatabase.readCache(_shareLinksCacheKey);
  }

  Future<String> _shareLinksCacheKeyForCurrentProfile() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return '$_shareLinksCacheKey::$normalizedActiveId';
    }
    return _shareLinksCacheKey;
  }

  Future<HealthDossier> _loadCachedDossierOrThrow() async {
    final cached = await _readCachedDossier();
    if (cached == null) {
      throw ApiException(
        'No local dossier snapshot is available yet. Generate or import a backup first.',
        statusCode: 404,
      );
    }
    return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  List<int> _buildSimplePdf(List<String> lines) {
    final sanitized = lines
        .map((line) => _sanitizePdfText(line))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final contentBuffer = StringBuffer();
    contentBuffer.writeln('BT');
    contentBuffer.writeln('/F1 11 Tf');
    contentBuffer.writeln('50 790 Td');
    for (var index = 0; index < sanitized.length; index++) {
      if (index > 0) {
        contentBuffer.writeln('0 -16 Td');
      }
      contentBuffer.writeln('(${sanitized[index]}) Tj');
    }
    contentBuffer.writeln('ET');

    final content = contentBuffer.toString();
    final object1 = '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n';
    final object2 =
        '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n';
    final object3 =
        '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n';
    final object4 =
        '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n';
    final object5 =
        '5 0 obj\n<< /Length ${utf8.encode(content).length} >>\nstream\n$content\nendstream\nendobj\n';

    final objects = [object1, object2, object3, object4, object5];
    final output = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];

    for (final object in objects) {
      offsets.add(utf8.encode(output.toString()).length);
      output.write(object);
    }

    final xrefStart = utf8.encode(output.toString()).length;
    output.writeln('xref');
    output.writeln('0 6');
    output.writeln('0000000000 65535 f ');
    for (var index = 1; index < offsets.length; index++) {
      output.writeln('${offsets[index].toString().padLeft(10, '0')} 00000 n ');
    }
    output.writeln('trailer');
    output.writeln('<< /Size 6 /Root 1 0 R >>');
    output.writeln('startxref');
    output.writeln(xrefStart);
    output.write('%%EOF');
    return utf8.encode(output.toString());
  }

  String _sanitizePdfText(String value) {
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .trim();
    return escaped.isEmpty ? '-' : escaped;
  }

  Future<String?> _readCachedDossier() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return _localDatabase.readCache('$_cacheKey::$normalizedActiveId');
    }
    return _localDatabase.readCache(_cacheKey);
  }

  Future<String> _cacheKeyForCurrentProfile() async {
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    final normalizedActiveId = activeProfileId?.trim();
    if (normalizedActiveId != null && normalizedActiveId.isNotEmpty) {
      return '$_cacheKey::$normalizedActiveId';
    }
    return _cacheKey;
  }
}
