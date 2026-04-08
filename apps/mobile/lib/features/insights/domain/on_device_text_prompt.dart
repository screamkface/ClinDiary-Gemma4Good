class OnDeviceTextPrompt {
  const OnDeviceTextPrompt({
    required this.contextType,
    required this.periodStart,
    required this.periodEnd,
    required this.systemPrompt,
    required this.userPrompt,
    required this.providerName,
    required this.suggestedModelFamily,
    required this.isCloudBypassedForThisRequest,
  });

  final String contextType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String systemPrompt;
  final String userPrompt;
  final String providerName;
  final String suggestedModelFamily;
  final bool isCloudBypassedForThisRequest;
}
