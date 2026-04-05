class OnDeviceRecapPrompt {
  const OnDeviceRecapPrompt({
    required this.summaryType,
    required this.periodStart,
    required this.periodEnd,
    required this.systemPrompt,
    required this.userPrompt,
    required this.providerName,
    required this.suggestedModelFamily,
    required this.isCloudBypassedForThisRequest,
  });

  final String summaryType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String systemPrompt;
  final String userPrompt;
  final String providerName;
  final String suggestedModelFamily;
  final bool isCloudBypassedForThisRequest;

  factory OnDeviceRecapPrompt.fromJson(Map<String, dynamic> json) {
    return OnDeviceRecapPrompt(
      summaryType: json['summary_type'].toString(),
      periodStart: DateTime.parse(json['period_start'].toString()),
      periodEnd: DateTime.parse(json['period_end'].toString()),
      systemPrompt: json['system_prompt'].toString(),
      userPrompt: json['user_prompt'].toString(),
      providerName: json['provider_name']?.toString() ?? 'on_device_litertlm',
      suggestedModelFamily:
          json['suggested_model_family']?.toString() ?? 'Gemma 4',
      isCloudBypassedForThisRequest:
          json['is_cloud_bypassed_for_this_request'] as bool? ?? true,
    );
  }
}
