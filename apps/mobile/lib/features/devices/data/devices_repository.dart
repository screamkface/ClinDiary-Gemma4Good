import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/devices/domain/device_hub.dart';

class DevicesRepository {
  DevicesRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DeviceOverview> fetchOverview() async {
    final response = await _apiClient.getJson('/api/v1/devices/overview');
    return DeviceOverview.fromJson(response);
  }

  Future<DeviceLinkResult> linkProvider({
    required String providerCode,
    Map<String, dynamic> payload = const {},
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/devices/providers/$providerCode/link',
      body: payload,
    );
    return DeviceLinkResult.fromJson(response);
  }

  Future<void> disconnectConnection(String connectionId) {
    return _apiClient.delete('/api/v1/devices/connections/$connectionId');
  }

  Future<DeviceSyncResult> syncConnection(String connectionId) async {
    final response = await _apiClient.postJson(
      '/api/v1/devices/connections/$connectionId/sync',
    );
    return DeviceSyncResult.fromJson(response);
  }

  Future<int> ingestMeasurements({
    required String connectionId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/devices/connections/$connectionId/measurements',
      body: {
        'items': items,
      },
    );
    return response['created_count'] as int? ?? 0;
  }
}
