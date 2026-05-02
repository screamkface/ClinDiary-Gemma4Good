import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';

class TimelineRepository {
  TimelineRepository({
    required LocalDatabase localDatabase,
  }) : _localDatabase = localDatabase;

  static const _cacheKey = 'timeline_events';

  final LocalDatabase _localDatabase;

  Future<List<TimelineEventItem>> fetchEvents() async {
    return _buildSyntheticLocalTimeline();
  }

  Future<List<TimelineEventItem>> _buildSyntheticLocalTimeline() async {
    final events = <TimelineEventItem>[];

    final dailyEntries = await readProfileScopedCache(
      _localDatabase,
      'daily_entries',
    );
    if (dailyEntries != null) {
      final decoded = jsonDecode(dailyEntries) as List<dynamic>;
      for (final raw in decoded) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final entryId = item['id']?.toString() ?? 'unknown';
        final notes = item['general_notes']?.toString();
        final date = DateTime.tryParse(item['entry_date']?.toString() ?? '');
        if (date == null) {
          continue;
        }
        events.add(
          TimelineEventItem(
            id: 'local-daily-$entryId',
            eventType: 'daily_entry',
            title: 'Daily check-in',
            description: (notes == null || notes.trim().isEmpty)
                ? 'Check-up saved'
                : notes,
            eventDate: date,
          ),
        );
      }
    }

    final medicationLogs = await readProfileScopedCache(
      _localDatabase,
      'medication_logs',
    );
    if (medicationLogs != null) {
      final decoded = jsonDecode(medicationLogs) as List<dynamic>;
      for (final raw in decoded) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final logId = item['id']?.toString() ?? 'unknown';
        final medicationName =
            item['medication_name']?.toString() ?? 'Medication';
        final status = item['status']?.toString() ?? 'logged';
        final at = DateTime.tryParse(
          item['taken_at']?.toString() ??
              item['scheduled_at']?.toString() ??
              '',
        );
        if (at == null) {
          continue;
        }
        events.add(
          TimelineEventItem(
            id: 'local-med-log-$logId',
            eventType: 'medication_log',
            title: medicationName,
            description: 'Medication status: $status',
            eventDate: at,
          ),
        );
      }
    }

    final alerts = await readProfileScopedCache(_localDatabase, 'alerts_list');
    if (alerts != null) {
      final decoded = jsonDecode(alerts) as List<dynamic>;
      for (final raw in decoded) {
        final item = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final alertId = item['id']?.toString() ?? 'unknown';
        final title = item['title']?.toString() ?? 'Clinical alert';
        final description = item['description']?.toString() ?? 'Alert update';
        final when = DateTime.tryParse(item['triggered_at']?.toString() ?? '');
        if (when == null) {
          continue;
        }
        events.add(
          TimelineEventItem(
            id: 'local-alert-$alertId',
            eventType: 'alert',
            title: title,
            description: description,
            eventDate: when,
            severity: item['severity']?.toString(),
          ),
        );
      }
    }

    events.sort((a, b) => b.eventDate.compareTo(a.eventDate));

    await _localDatabase.putCache(
      key: await profileScopedCacheKey(_localDatabase, _cacheKey),
      payload: jsonEncode(events.map(_eventToJson).toList()),
    );

    return events;
  }

  Map<String, dynamic> _eventToJson(TimelineEventItem item) {
    return {
      'id': item.id,
      'event_type': item.eventType,
      'title': item.title,
      'description': item.description,
      'event_date': item.eventDate.toUtc().toIso8601String(),
      'severity': item.severity,
    };
  }
}
