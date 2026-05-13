import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/alerts/presentation/alert_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String? _resolvingAlertId;

  Future<void> _resolveAlert(ClinicalAlert alert) async {
    setState(() => _resolvingAlertId = alert.id);
    try {
      await ref.read(alertsRepositoryProvider).resolveAlert(alert.id);
      ref.invalidate(alertsProvider);
      ref.invalidate(timelineEventsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _resolvingAlertId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert center'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(alertsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No open clinical alerts.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final severityColor = alertSeverityColor(context, alert.severity);

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: severityColor.withValues(alpha: 0.14),
                    child: Icon(
                      alertSeverityIcon(alert.severity),
                      color: severityColor,
                    ),
                  ),
                  title: Text(alert.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        alert.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(alertSeverityLabel(alert.severity))),
                          Chip(
                            label: Text(
                              dateFormat.format(alert.triggeredAt.toLocal()),
                            ),
                          ),
                          Chip(
                            label: Text(alert.isResolved ? 'Resolved' : 'Open'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: alert.isResolved
                      ? null
                      : FilledButton.tonal(
                          onPressed: _resolvingAlertId == alert.id
                              ? null
                              : () => _resolveAlert(alert),
                          child: Text(
                            _resolvingAlertId == alert.id
                                ? '...'
                                : 'Mark resolved',
                          ),
                        ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
