class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    this.patientId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.priority,
    required this.readStatus,
    this.readAt,
    this.sourceType,
    this.sourceId,
    required this.createdAt,
  });

  final String id;
  final String? patientId;
  final String notificationType;
  final String title;
  final String body;
  final String priority;
  final bool readStatus;
  final DateTime? readAt;
  final String? sourceType;
  final String? sourceId;
  final DateTime createdAt;

  bool get isUnread => !readStatus;

  AppNotificationItem copyWith({
    bool? readStatus,
    DateTime? readAt,
    String? patientId,
  }) {
    return AppNotificationItem(
      id: id,
      patientId: patientId ?? this.patientId,
      notificationType: notificationType,
      title: title,
      body: body,
      priority: priority,
      readStatus: readStatus ?? this.readStatus,
      readAt: readAt ?? this.readAt,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'notification_type': notificationType,
      'title': title,
      'body': body,
      'priority': priority,
      'read_status': readStatus,
      'read_at': readAt?.toIso8601String(),
      'source_type': sourceType,
      'source_id': sourceId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'].toString(),
      patientId: json['patient_id']?.toString(),
      notificationType: json['notification_type'].toString(),
      title: json['title'].toString(),
      body: json['body'].toString(),
      priority: json['priority'].toString(),
      readStatus: json['read_status'] as bool? ?? false,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'].toString()),
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.inAppEnabled,
    required this.dailyCheckinEnabled,
    required this.medicationRemindersEnabled,
    required this.screeningRemindersEnabled,
    required this.documentFollowUpEnabled,
    required this.reportReadyEnabled,
    required this.clinicalAlertsEnabled,
    required this.preventionTipsEnabled,
    required this.pushEnabled,
    required this.emailEnabled,
    this.emailAddress,
  });

  final bool inAppEnabled;
  final bool dailyCheckinEnabled;
  final bool medicationRemindersEnabled;
  final bool screeningRemindersEnabled;
  final bool documentFollowUpEnabled;
  final bool reportReadyEnabled;
  final bool clinicalAlertsEnabled;
  final bool preventionTipsEnabled;
  final bool pushEnabled;
  final bool emailEnabled;
  final String? emailAddress;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      inAppEnabled: json['in_app_enabled'] as bool? ?? true,
      dailyCheckinEnabled: json['daily_checkin_enabled'] as bool? ?? true,
      medicationRemindersEnabled:
          json['medication_reminders_enabled'] as bool? ?? true,
      screeningRemindersEnabled:
          json['screening_reminders_enabled'] as bool? ?? true,
      documentFollowUpEnabled:
          json['document_follow_up_enabled'] as bool? ?? true,
      reportReadyEnabled: json['report_ready_enabled'] as bool? ?? true,
      clinicalAlertsEnabled: json['clinical_alerts_enabled'] as bool? ?? true,
      preventionTipsEnabled: json['prevention_tips_enabled'] as bool? ?? true,
      pushEnabled: json['push_enabled'] as bool? ?? false,
      emailEnabled: json['email_enabled'] as bool? ?? false,
      emailAddress: json['email_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'in_app_enabled': inAppEnabled,
      'daily_checkin_enabled': dailyCheckinEnabled,
      'medication_reminders_enabled': medicationRemindersEnabled,
      'screening_reminders_enabled': screeningRemindersEnabled,
      'document_follow_up_enabled': documentFollowUpEnabled,
      'report_ready_enabled': reportReadyEnabled,
      'clinical_alerts_enabled': clinicalAlertsEnabled,
      'prevention_tips_enabled': preventionTipsEnabled,
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'email_address': emailAddress,
    };
  }

  NotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? dailyCheckinEnabled,
    bool? medicationRemindersEnabled,
    bool? screeningRemindersEnabled,
    bool? documentFollowUpEnabled,
    bool? reportReadyEnabled,
    bool? clinicalAlertsEnabled,
    bool? preventionTipsEnabled,
    bool? pushEnabled,
    bool? emailEnabled,
    Object? emailAddress = _unsetNotificationField,
  }) {
    return NotificationPreferences(
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      dailyCheckinEnabled: dailyCheckinEnabled ?? this.dailyCheckinEnabled,
      medicationRemindersEnabled:
          medicationRemindersEnabled ?? this.medicationRemindersEnabled,
      screeningRemindersEnabled:
          screeningRemindersEnabled ?? this.screeningRemindersEnabled,
      documentFollowUpEnabled:
          documentFollowUpEnabled ?? this.documentFollowUpEnabled,
      reportReadyEnabled: reportReadyEnabled ?? this.reportReadyEnabled,
      clinicalAlertsEnabled:
          clinicalAlertsEnabled ?? this.clinicalAlertsEnabled,
      preventionTipsEnabled:
          preventionTipsEnabled ?? this.preventionTipsEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      emailAddress: identical(emailAddress, _unsetNotificationField)
          ? this.emailAddress
          : emailAddress as String?,
    );
  }
}

const Object _unsetNotificationField = Object();

class NotificationDeliveryChannelResult {
  const NotificationDeliveryChannelResult({
    required this.channel,
    required this.provider,
    required this.attempted,
    required this.delivered,
    required this.targetCount,
    required this.deliveredCount,
    this.error,
  });

  final String channel;
  final String provider;
  final bool attempted;
  final bool delivered;
  final int targetCount;
  final int deliveredCount;
  final String? error;

  factory NotificationDeliveryChannelResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return NotificationDeliveryChannelResult(
      channel: json['channel'].toString(),
      provider: json['provider'].toString(),
      attempted: json['attempted'] as bool? ?? false,
      delivered: json['delivered'] as bool? ?? false,
      targetCount: json['target_count'] as int? ?? 0,
      deliveredCount: json['delivered_count'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

class NotificationDeliveryReport {
  const NotificationDeliveryReport({
    this.push,
    this.email,
    required this.attempted,
    required this.delivered,
    required this.hasErrors,
  });

  final NotificationDeliveryChannelResult? push;
  final NotificationDeliveryChannelResult? email;
  final bool attempted;
  final bool delivered;
  final bool hasErrors;

  factory NotificationDeliveryReport.fromJson(Map<String, dynamic> json) {
    return NotificationDeliveryReport(
      push: json['push'] == null
          ? null
          : NotificationDeliveryChannelResult.fromJson(
              json['push'] as Map<String, dynamic>,
            ),
      email: json['email'] == null
          ? null
          : NotificationDeliveryChannelResult.fromJson(
              json['email'] as Map<String, dynamic>,
            ),
      attempted: json['attempted'] as bool? ?? false,
      delivered: json['delivered'] as bool? ?? false,
      hasErrors: json['has_errors'] as bool? ?? false,
    );
  }
}
