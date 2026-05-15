import 'dart:convert';

import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';

class DossierRepository {
  DossierRepository({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  static const _cacheKey = 'health_dossier';
  static const _shareLinksCacheKey = 'dossier_share_links';

  final LocalDatabase _localDatabase;

  Future<HealthDossier> fetchDossier() async {
    final cached = await _readCachedDossier();
    if (cached == null) {
      throw Exception(
        'No local dossier snapshot is available yet. Generate or import a backup first.',
      );
    }
    return HealthDossier.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  Future<List<int>> exportDossier() async {
    final dossier = await _loadCachedDossierOrThrow();
    return exportDossierFromSnapshot(dossier);
  }

  List<int> exportDossierFromSnapshot(HealthDossier dossier) {
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
    final cached = await _readCachedDossier();
    if (cached == null) {
      throw Exception(
        'No local dossier snapshot is available yet. Generate or import a backup first.',
      );
    }
    return utf8.encode(cached);
  }

  List<int> exportDossierJsonFromSnapshot(HealthDossier dossier) {
    return utf8.encode(jsonEncode(_snapshotJson(dossier)));
  }

  Future<List<int>> exportEmergencyDossier() async {
    final dossier = await _loadCachedDossierOrThrow();
    return exportEmergencyDossierFromSnapshot(dossier);
  }

  List<int> exportEmergencyDossierFromSnapshot(HealthDossier dossier) {
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

  Map<String, dynamic> _snapshotJson(HealthDossier dossier) {
    final summary = dossier.emergencySummary;
    return <String, dynamic>{
      'generated_at': dossier.generatedAt.toIso8601String(),
      'display_name': dossier.displayName,
      'age': dossier.age,
      'biological_sex': dossier.biologicalSex,
      'profile_facts': dossier.profileFacts
          .map((item) => {'label': item.label, 'value': item.value})
          .toList(),
      'provenance_facts': dossier.provenanceFacts
          .map((item) => {'label': item.label, 'value': item.value})
          .toList(),
      'emergency_summary': <String, dynamic>{
        'generated_at': summary.generatedAt.toIso8601String(),
        'headline': summary.headline,
        'key_points': summary.keyPoints,
        'active_problems': summary.activeProblems,
        'active_medications': summary.activeMedications,
        'allergies': summary.allergies,
        'conditions': summary.conditions,
        'open_alerts': summary.openAlerts,
        'latest_wearable_summary': summary.latestWearableSummary,
        'latest_report_summary': summary.latestReportSummary,
      },
      'allergies': const <Map<String, dynamic>>[],
      'medical_conditions': const <Map<String, dynamic>>[],
      'medications': const <Map<String, dynamic>>[],
      'family_history': const <Map<String, dynamic>>[],
      'vaccinations': const <Map<String, dynamic>>[],
      'clinical_episodes': const <Map<String, dynamic>>[],
      'recent_daily_entries': const <Map<String, dynamic>>[],
      'recent_documents': const <Map<String, dynamic>>[],
      'recent_lab_panels': const <Map<String, dynamic>>[],
      'recent_imaging_reports': const <Map<String, dynamic>>[],
      'device_measurement_summaries': const <Map<String, dynamic>>[],
      'recent_insights': const <Map<String, dynamic>>[],
      'recent_reports': const <Map<String, dynamic>>[],
      'alerts': const <Map<String, dynamic>>[],
      'wearable_summaries': const <Map<String, dynamic>>[],
    };
  }

  Future<HealthDossier> importDossier({
    required Map<String, dynamic> snapshot,
    bool replaceExisting = true,
  }) async {
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

  Future<List<DossierShareLinkItem>> fetchShareLinks() async {
    final cached = await _readCachedShareLinks();
    if (cached == null) {
      return const [];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map(
          (item) => DossierShareLinkItem.fromJson(item as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<DossierShareLinkItem> createShareLink({
    required String scope,
    String? label,
    int expiresInDays = 7,
  }) async {
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

    final links = await _readCachedShareLinksJson() ?? <Map<String, dynamic>>[];
    links.insert(0, item);
    await _writeCachedShareLinksJson(links);
    return DossierShareLinkItem.fromJson(item);
  }

  Future<void> revokeShareLink(String shareLinkId) async {
    final links = await _readCachedShareLinksJson() ?? <Map<String, dynamic>>[];
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
      throw Exception(
        'No local dossier snapshot is available yet. Generate or import a backup first.',
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
