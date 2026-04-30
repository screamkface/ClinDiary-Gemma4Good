import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(deviceOverviewProvider);
    await ref.read(deviceOverviewProvider.future);
  }

  Future<void> _linkProvider(
    DeviceProviderItem provider, {
    DeviceConnectionItem? existingConnection,
  }) async {
    final result = await showModalBottomSheet<_ProviderSetupPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProviderSetupSheet(
        provider: provider,
        existingConnection: existingConnection,
      ),
    );
    if (result == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await ref
          .read(devicesRepositoryProvider)
          .linkProvider(providerCode: provider.code, payload: result.toJson());
      ref.invalidate(deviceOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _syncConnection(DeviceConnectionItem connection) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(devicesRepositoryProvider)
          .syncConnection(connection.id);
      ref.invalidate(deviceOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnectConnection(DeviceConnectionItem connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove the connector?'),
        content: Text(
          'The connection ${connection.providerName} will be removed from this profile. '
          'Already imported measurements will remain in the clinical history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(devicesRepositoryProvider)
          .disconnectConnection(connection.id);
      ref.invalidate(deviceOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connector removed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _manualIngest(DeviceConnectionItem connection) async {
    final payload = await showModalBottomSheet<_ManualMeasurementPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ManualMeasurementSheet(connection: connection),
    );
    if (payload == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final created = await ref
          .read(devicesRepositoryProvider)
          .ingestMeasurements(
            connectionId: connection.id,
            items: [payload.toJson()],
          );
      ref.invalidate(deviceOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == 1
                ? 'Measurement recorded.'
                : '$created measurements recorded.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(deviceOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (overview) => DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: SectionCard(
                  title: 'Wave 1 clinical',
                  subtitle:
                      'OMRON, Withings, iHealth, A&D, and Dexcom in one unified module.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryChip(
                        icon: Icons.device_hub_outlined,
                        label: '${overview.providers.length} provider',
                      ),
                      _SummaryChip(
                        icon: Icons.link_outlined,
                        label: '${overview.connectedCount} connected',
                      ),
                      _SummaryChip(
                        icon: Icons.pending_actions_outlined,
                        label: '${overview.pendingCount} in setup',
                      ),
                      _SummaryChip(
                        icon: Icons.monitor_heart_outlined,
                        label:
                            '${overview.recentMeasurements.length} recent measurements',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  tabs: const [
                    Tab(text: 'Provider'),
                    Tab(text: 'Connected'),
                    Tab(text: 'Measurements'),
                    Tab(text: 'Import'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _ProvidersTab(
                      providers: overview.providers,
                      connections: overview.connections,
                      onConfigure: (provider, connection) => _linkProvider(
                        provider,
                        existingConnection: connection,
                      ),
                    ),
                    _ConnectionsTab(
                      connections: overview.connections,
                      onConfigure: (connection, provider) => _linkProvider(
                        provider,
                        existingConnection: connection,
                      ),
                      onManualIngest: _manualIngest,
                      onSync: _syncConnection,
                      onDisconnect: _disconnectConnection,
                      providers: overview.providers,
                    ),
                    _MeasurementsTab(
                      measurements: overview.recentMeasurements,
                      providers: overview.providers,
                    ),
                    _JobsTab(
                      jobs: overview.recentJobs,
                      providers: overview.providers,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvidersTab extends StatelessWidget {
  const _ProvidersTab({
    required this.providers,
    required this.connections,
    required this.onConfigure,
  });

  final List<DeviceProviderItem> providers;
  final List<DeviceConnectionItem> connections;
  final void Function(
    DeviceProviderItem provider,
    DeviceConnectionItem? existing,
  )
  onConfigure;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: providers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final provider = providers[index];
        final connection = connections
            .where((item) => item.providerCode == provider.code)
            .firstOrNull;
        return SectionCard(
          title: provider.displayName,
          subtitle: provider.summary,
          action: FilledButton.tonal(
            onPressed: () => onConfigure(provider, connection),
            child: Text(connection == null ? 'Configure' : 'Update'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProviderBadge(label: _categoryLabel(provider.category)),
                  _ProviderBadge(
                    label: _integrationLabel(provider.integrationKind),
                  ),
                  _ProviderBadge(
                    label: provider.providerConfigured
                        ? 'Server ready'
                        : 'Server to configure',
                    tone: provider.providerConfigured
                        ? _BadgeTone.positive
                        : _BadgeTone.warning,
                  ),
                  if (provider.requiresVendorContract)
                    const _ProviderBadge(
                      label: 'Partner required',
                      tone: _BadgeTone.warning,
                    ),
                  if (provider.supportsManualIngest)
                    const _ProviderBadge(
                      label: 'SDK ingest',
                      tone: _BadgeTone.info,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Key metrics',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: provider.capabilities
                    .map((capability) => Chip(label: Text(capability)))
                    .toList(),
              ),
              if (connection != null) ...[
                const SizedBox(height: 12),
                Text(
                  connection.isConnected
                      ? 'Connected to this profile'
                      : 'Connector saved for this profile',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionsTab extends StatelessWidget {
  const _ConnectionsTab({
    required this.connections,
    required this.providers,
    required this.onConfigure,
    required this.onManualIngest,
    required this.onSync,
    required this.onDisconnect,
  });

  final List<DeviceConnectionItem> connections;
  final List<DeviceProviderItem> providers;
  final void Function(
    DeviceConnectionItem connection,
    DeviceProviderItem provider,
  )
  onConfigure;
  final void Function(DeviceConnectionItem connection) onManualIngest;
  final void Function(DeviceConnectionItem connection) onSync;
  final void Function(DeviceConnectionItem connection) onDisconnect;

  @override
  Widget build(BuildContext context) {
    if (connections.isEmpty) {
      return const _EmptyState(
        title: 'No connector saved yet',
        message: 'Open the Provider tab and set up the first clinical device.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: connections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final connection = connections[index];
        final provider = providers.firstWhere(
          (item) => item.code == connection.providerCode,
        );
        final latest = connection.latestMeasurement;
        return SectionCard(
          title: connection.providerName,
          subtitle:
              connection.accountLabel ?? _connectionStatusLabel(connection),
          action: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'configure':
                  onConfigure(connection, provider);
                  break;
                case 'sync':
                  onSync(connection);
                  break;
                case 'remove':
                  onDisconnect(connection);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'configure', child: Text('Configure')),
              PopupMenuItem(
                value: 'sync',
                enabled: connection.supportsLiveSync,
                child: const Text('Sync'),
              ),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProviderBadge(
                    label: _connectionStatusLabel(connection),
                    tone: connection.isConnected
                        ? _BadgeTone.positive
                        : _BadgeTone.warning,
                  ),
                  _ProviderBadge(
                    label: connection.supportsLiveSync
                        ? 'Sync live'
                        : 'Live sync not ready',
                    tone: connection.supportsLiveSync
                        ? _BadgeTone.info
                        : _BadgeTone.neutral,
                  ),
                  if (connection.supportsManualIngest)
                    const _ProviderBadge(
                      label: 'SDK ready',
                      tone: _BadgeTone.info,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (latest != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(latest.displayTitle),
                  subtitle: Text(
                    DateFormat(
                      'dd MMM yyyy, HH:mm',
                      'en_US',
                    ).format(latest.measuredAt.toLocal()),
                  ),
                  trailing: Text(
                    latest.displayValue,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  'No measurements imported yet for this connector.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (connection.supportsManualIngest) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => onManualIngest(connection),
                  icon: const Icon(Icons.add_chart_outlined),
                  label: const Text('Record measurement'),
                ),
              ],
              if (connection.lastError != null &&
                  connection.lastError!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  connection.lastError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MeasurementsTab extends StatelessWidget {
  const _MeasurementsTab({required this.measurements, required this.providers});

  final List<DeviceMeasurementItem> measurements;
  final List<DeviceProviderItem> providers;

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return const _EmptyState(
        title: 'No device measurements available yet',
        message:
            'Measurements imported from Wave 1 providers will appear here in chronological order.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: measurements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final measurement = measurements[index];
        final providerName = providers
            .where((item) => item.code == measurement.providerCode)
            .map((item) => item.displayName)
            .firstOrNull;
        return SectionCard(
          title: measurement.displayTitle,
          subtitle: providerName ?? measurement.providerCode,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              measurement.displayValue,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              DateFormat(
                'dd MMM yyyy, HH:mm',
                'en_US',
              ).format(measurement.measuredAt.toLocal()),
            ),
            trailing: measurement.sourceDeviceModel == null
                ? null
                : Text(
                    measurement.sourceDeviceModel!,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        );
      },
    );
  }
}

class _JobsTab extends StatelessWidget {
  const _JobsTab({required this.jobs, required this.providers});

  final List<DeviceImportJobItem> jobs;
  final List<DeviceProviderItem> providers;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const _EmptyState(
        title: 'No recent imports',
        message:
            'Imports, syncs, and bootstrap runs from Wave 1 providers will appear here with their results.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        final providerName = providers
            .where((item) => item.code == job.providerCode)
            .map((item) => item.displayName)
            .firstOrNull;
        return SectionCard(
          title: providerName ?? job.providerCode,
          subtitle: _jobStatusLabel(job.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProviderBadge(
                    label: _jobStatusLabel(job.status),
                    tone: _jobBadgeTone(job.status),
                  ),
                  _ProviderBadge(
                    label: '${job.itemCount} items',
                    tone: _BadgeTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat(
                  'dd MMM yyyy, HH:mm',
                  'en_US',
                ).format(job.startedAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (job.summary != null && job.summary!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(job.summary!),
              ],
              if (job.errorMessage != null &&
                  job.errorMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  job.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProviderSetupSheet extends ConsumerStatefulWidget {
  const _ProviderSetupSheet({required this.provider, this.existingConnection});

  final DeviceProviderItem provider;
  final DeviceConnectionItem? existingConnection;

  @override
  ConsumerState<_ProviderSetupSheet> createState() =>
      _ProviderSetupSheetState();
}

class _ManualMeasurementPayload {
  const _ManualMeasurementPayload({
    required this.metricType,
    required this.measuredAt,
    this.unit,
    this.primaryValue,
    this.secondaryValue,
    this.tertiaryValue,
    this.sourceDeviceModel,
    this.notes,
  });

  final String metricType;
  final DateTime measuredAt;
  final String? unit;
  final double? primaryValue;
  final double? secondaryValue;
  final double? tertiaryValue;
  final String? sourceDeviceModel;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'metric_type': metricType,
    'measured_at': measuredAt.toUtc().toIso8601String(),
    if ((unit ?? '').trim().isNotEmpty) 'unit': unit!.trim(),
    if (primaryValue != null) 'primary_value': primaryValue,
    if (secondaryValue != null) 'secondary_value': secondaryValue,
    if (tertiaryValue != null) 'tertiary_value': tertiaryValue,
    if ((sourceDeviceModel ?? '').trim().isNotEmpty)
      'source_device_model': sourceDeviceModel!.trim(),
    if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
  };
}

class _ManualMeasurementSheet extends StatefulWidget {
  const _ManualMeasurementSheet({required this.connection});

  final DeviceConnectionItem connection;

  @override
  State<_ManualMeasurementSheet> createState() =>
      _ManualMeasurementSheetState();
}

class _ManualMeasurementSheetState extends State<_ManualMeasurementSheet> {
  late String _metricType;
  late final TextEditingController _primaryController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _tertiaryController;
  late final TextEditingController _deviceModelController;
  late final TextEditingController _notesController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _metricType = _manualMetricOptions.first.value;
    _primaryController = TextEditingController();
    _secondaryController = TextEditingController();
    _tertiaryController = TextEditingController();
    _deviceModelController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _tertiaryController.dispose();
    _deviceModelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final primary = double.tryParse(
      _primaryController.text.replaceAll(',', '.'),
    );
    final secondary = double.tryParse(
      _secondaryController.text.replaceAll(',', '.'),
    );
    final tertiary = double.tryParse(
      _tertiaryController.text.replaceAll(',', '.'),
    );
    final fields = _manualFieldsFor(_metricType);

    if (primary == null) {
      _showError('Enter ${fields.primaryLabel.toLowerCase()}.');
      return;
    }
    if (fields.secondaryRequired && secondary == null) {
      _showError('Enter ${fields.secondaryLabel!.toLowerCase()}.');
      return;
    }

    setState(() => _submitting = true);
    try {
      Navigator.of(context).pop(
        _ManualMeasurementPayload(
          metricType: _metricType,
          measuredAt: DateTime.now(),
          unit: fields.defaultUnit,
          primaryValue: primary,
          secondaryValue: secondary,
          tertiaryValue: tertiary,
          sourceDeviceModel: _deviceModelController.text,
          notes: _notesController.text,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final fields = _manualFieldsFor(_metricType);
    return Material(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Record measurement',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.connection.providerName),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _metricType,
                  decoration: const InputDecoration(labelText: 'Metric'),
                  items: _manualMetricOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.value,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _metricType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _primaryController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: fields.primaryLabel,
                    suffixText: fields.defaultUnit,
                  ),
                ),
                if (fields.secondaryLabel != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secondaryController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: fields.secondaryLabel,
                      suffixText: fields.defaultUnit,
                    ),
                  ),
                ],
                if (fields.tertiaryLabel != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tertiaryController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: fields.tertiaryLabel,
                      suffixText: fields.tertiaryUnit,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _deviceModelController,
                  decoration: const InputDecoration(
                    labelText: 'Device model (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The measurement is saved with the device current time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: const Text('Save measurement'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderSetupSheetState extends ConsumerState<_ProviderSetupSheet> {
  late final TextEditingController _accountLabelController;
  late final TextEditingController _externalUserIdController;
  late final TextEditingController _accessTokenController;
  late final TextEditingController _refreshTokenController;
  late final TextEditingController _apiKeyController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _accountLabelController = TextEditingController(
      text: widget.existingConnection?.accountLabel ?? '',
    );
    _externalUserIdController = TextEditingController(
      text: widget.existingConnection?.externalUserId ?? '',
    );
    _accessTokenController = TextEditingController();
    _refreshTokenController = TextEditingController();
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _accountLabelController.dispose();
    _externalUserIdController.dispose();
    _accessTokenController.dispose();
    _refreshTokenController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _openDocs() async {
    final uri = Uri.tryParse(widget.provider.docsUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      Navigator.of(context).pop(
        _ProviderSetupPayload(
          accountLabel: _accountLabelController.text.trim(),
          externalUserId: _externalUserIdController.text.trim(),
          accessToken: _accessTokenController.text.trim(),
          refreshToken: _refreshTokenController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final title = widget.existingConnection == null
        ? 'Set up ${provider.displayName}'
        : 'Update ${provider.displayName}';
    return Material(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(provider.summary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.capabilities
                      .map((item) => Chip(label: Text(item)))
                      .toList(),
                ),
                const SizedBox(height: 12),
                for (final note in provider.setupNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $note'),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountLabelController,
                  decoration: const InputDecoration(
                    labelText: 'Account or device label',
                  ),
                ),
                const SizedBox(height: 12),
                if (provider.isOauthFlow) ...[
                  TextField(
                    controller: _externalUserIdController,
                    decoration: const InputDecoration(
                      labelText: 'External user ID (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _accessTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Manual access token',
                      hintText:
                          'Paste the token here if you get it from the partner portal',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _refreshTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Refresh token (optional)',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ],
                if (provider.isApiKeyFlow) ...[
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Vendor API key',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _openDocs,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Documentation'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(
                        provider.isPartnerSetup ? 'Save setup' : 'Save',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderSetupPayload {
  const _ProviderSetupPayload({
    required this.accountLabel,
    required this.externalUserId,
    required this.accessToken,
    required this.refreshToken,
    required this.apiKey,
  });

  final String accountLabel;
  final String externalUserId;
  final String accessToken;
  final String refreshToken;
  final String apiKey;

  Map<String, dynamic> toJson() => {
    if (accountLabel.isNotEmpty) 'account_label': accountLabel,
    if (externalUserId.isNotEmpty) 'external_user_id': externalUserId,
    if (accessToken.isNotEmpty) 'access_token': accessToken,
    if (refreshToken.isNotEmpty) 'refresh_token': refreshToken,
    if (apiKey.isNotEmpty) 'api_key': apiKey,
  };
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

enum _BadgeTone { neutral, positive, warning, info }

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.label, this.tone = _BadgeTone.neutral});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    switch (tone) {
      case _BadgeTone.positive:
        background = colorScheme.primaryContainer;
        foreground = colorScheme.onPrimaryContainer;
        break;
      case _BadgeTone.warning:
        background = colorScheme.tertiaryContainer;
        foreground = colorScheme.onTertiaryContainer;
        break;
      case _BadgeTone.info:
        background = colorScheme.secondaryContainer;
        foreground = colorScheme.onSecondaryContainer;
        break;
      case _BadgeTone.neutral:
        background = colorScheme.surfaceContainerHighest;
        foreground = colorScheme.onSurfaceVariant;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.device_hub_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(String value) {
  switch (value) {
    case 'clinical_device':
      return 'Clinical device';
    case 'diabetes':
      return 'Diabetes';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _integrationLabel(String value) {
  switch (value) {
    case 'cloud_api':
      return 'Remote API';
    case 'api_key':
      return 'API key';
    case 'partner_platform':
      return 'Partner platform';
    case 'sdk_bridge':
      return 'SDK/BLE';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _connectionStatusLabel(DeviceConnectionItem connection) {
  switch (connection.status) {
    case 'connected':
      return 'Connected';
    case 'pending':
      return 'Setting up';
    case 'error':
      return 'Error';
    case 'disconnected':
      return 'Disconnected';
    default:
      return connection.status;
  }
}

String _jobStatusLabel(String status) {
  switch (status) {
    case 'running':
      return 'Running';
    case 'succeeded':
      return 'Completed';
    case 'failed':
      return 'Failed';
    case 'pending':
      return 'Pending';
    default:
      return status;
  }
}

_BadgeTone _jobBadgeTone(String status) {
  switch (status) {
    case 'succeeded':
      return _BadgeTone.positive;
    case 'failed':
      return _BadgeTone.warning;
    case 'running':
      return _BadgeTone.info;
    case 'pending':
      return _BadgeTone.neutral;
    default:
      return _BadgeTone.neutral;
  }
}

class _ManualMetricOption {
  const _ManualMetricOption(this.value, this.label);

  final String value;
  final String label;
}

class _ManualMetricFields {
  const _ManualMetricFields({
    required this.primaryLabel,
    this.secondaryLabel,
    this.tertiaryLabel,
    this.defaultUnit,
    this.tertiaryUnit,
    this.secondaryRequired = false,
  });

  final String primaryLabel;
  final String? secondaryLabel;
  final String? tertiaryLabel;
  final String? defaultUnit;
  final String? tertiaryUnit;
  final bool secondaryRequired;
}

const _manualMetricOptions = [
  _ManualMetricOption('blood_pressure', 'Blood pressure'),
  _ManualMetricOption('body_weight', 'Weight'),
  _ManualMetricOption('spo2', 'Oxygen saturation'),
  _ManualMetricOption('heart_rate', 'Heart rate'),
  _ManualMetricOption('temperature', 'Temperature'),
  _ManualMetricOption('blood_glucose_bgm', 'Capillary glucose'),
];

_ManualMetricFields _manualFieldsFor(String metricType) {
  switch (metricType) {
    case 'blood_pressure':
      return const _ManualMetricFields(
        primaryLabel: 'Systolic',
        secondaryLabel: 'Diastolic',
        tertiaryLabel: 'Heart rate',
        defaultUnit: 'mmHg',
        tertiaryUnit: 'bpm',
        secondaryRequired: true,
      );
    case 'body_weight':
      return const _ManualMetricFields(
        primaryLabel: 'Weight',
        defaultUnit: 'kg',
      );
    case 'spo2':
      return const _ManualMetricFields(primaryLabel: 'SpO2', defaultUnit: '%');
    case 'heart_rate':
      return const _ManualMetricFields(
        primaryLabel: 'Heart rate',
        defaultUnit: 'bpm',
      );
    case 'temperature':
      return const _ManualMetricFields(
        primaryLabel: 'Temperature',
        defaultUnit: '°C',
      );
    case 'blood_glucose_bgm':
      return const _ManualMetricFields(
        primaryLabel: 'Glucose',
        defaultUnit: 'mg/dL',
      );
    default:
      return const _ManualMetricFields(primaryLabel: 'Value');
  }
}
