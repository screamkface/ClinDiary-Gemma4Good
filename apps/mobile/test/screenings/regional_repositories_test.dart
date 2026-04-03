import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/prevention_center/data/prevention_center_repository.dart';
import 'package:clindiary/features/screenings/data/screenings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeApiClient extends ApiClient {
  FakeApiClient({required LocalDatabase localDatabase})
    : this._(http.Client(), localDatabase: localDatabase);

  FakeApiClient._(this._client, {required LocalDatabase localDatabase})
    : super(
        client: _client,
        config: defaultAppConfig,
        tokenStorage: SecureTokenStorage(const FlutterSecureStorage()),
        localDatabase: localDatabase,
      );

  final http.Client _client;
  int flushResult = 0;
  List<dynamic>? listResponse;
  Map<String, dynamic>? mapResponse;
  String? lastGetJsonListPath;
  String? lastGetJsonPath;

  void dispose() {
    _client.close();
  }

  @override
  Future<int> flushPendingOperations({int limit = 20}) async {
    return flushResult;
  }

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    bool authenticated = true,
  }) async {
    lastGetJsonListPath = path;
    if (listResponse != null) {
      return listResponse!;
    }
    throw StateError('Unexpected GET list $path');
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    lastGetJsonPath = path;
    if (mapResponse != null) {
      return mapResponse!;
    }
    throw StateError('Unexpected GET $path');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Region-aware repositories', () {
    test('screenings repository uses region-specific cache keys', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      apiClient.listResponse = [
        {
          'id': 'program-1',
          'code': 'cervical_cancer_it',
          'name': 'Screening cervice uterina',
          'description': 'Screening periodico',
          'min_age': 25,
          'max_age': 64,
          'target_sex': 'female',
          'interval_months': 36,
          'public_coverage_flag': true,
          'category': 'oncologia',
          'care_pathway': 'discuss_with_doctor',
          'recommendation_level': 'routine',
          'cadence_label': 'Programma pubblico',
          'catalog_only': false,
          'explanation': 'Consigliato',
          'active': true,
          'regional_availability': [
            {
              'region_code': 'IT-LOM',
              'region_name': 'Lombardia',
              'booking_url': 'https://example.org',
              'notes': 'Prenotazione locale',
              'active': true,
            },
          ],
        },
      ];
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      final repository = ScreeningsRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final items = await repository.fetchCatalog(regionCode: 'IT-LOM');
      final cached = await database.readCache('screenings_catalog::IT-LOM');

      expect(apiClient.lastGetJsonListPath, contains('region_code=IT-LOM'));
      expect(items, hasLength(1));
      expect(items.single.regionalAvailability.single.regionCode, 'IT-LOM');
      expect(cached, isNotNull);
    });

    test('screenings repository falls back to legacy cache for Italy', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      await database.putCache(
        key: 'screenings_catalog',
        payload: jsonEncode([
          {
            'id': 'program-legacy',
            'code': 'blood_pressure_adults',
            'name': 'Controllo pressione arteriosa',
            'description': 'Screening periodico',
            'min_age': 18,
            'max_age': null,
            'target_sex': null,
            'interval_months': 12,
            'public_coverage_flag': false,
            'category': 'cardiometabolico',
            'care_pathway': 'discuss_with_doctor',
            'recommendation_level': 'routine',
            'cadence_label': 'Periodico',
            'catalog_only': false,
            'explanation': null,
            'active': true,
            'regional_availability': const [],
          },
        ]),
      );

      final repository = ScreeningsRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final items = await repository.fetchCatalog(regionCode: 'IT');
      expect(items, hasLength(1));
      expect(items.single.code, 'blood_pressure_adults');
    });

    test('prevention center repository uses region-specific cache keys', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      apiClient.mapResponse = {
        'generated_at': '2026-03-25T15:45:00Z',
        'display_name': 'Anna Bianchi',
        'age': 34,
        'biological_sex': 'female',
        'region_code': 'IT-LOM',
        'region_name': 'Lombardia',
        'overview': {
          'actionable_screenings': 2,
          'vaccine_reviews': 3,
          'seasonal_checks': 1,
          'follow_up_items': 1,
        },
        'annual_visit': null,
        'visits_and_controls': <Map<String, dynamic>>[],
        'vaccines': <Map<String, dynamic>>[],
        'seasonal_checks': <Map<String, dynamic>>[],
        'follow_up_reminders': <Map<String, dynamic>>[],
      };
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      final repository = PreventionCenterRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final center = await repository.fetchCenter(regionCode: 'IT-LOM');
      final cached = await database.readCache('prevention_center::IT-LOM');

      expect(apiClient.lastGetJsonPath, contains('region_code=IT-LOM'));
      expect(center.regionCode, 'IT-LOM');
      expect(center.regionName, 'Lombardia');
      expect(cached, isNotNull);
    });

    test('prevention center repository falls back to legacy cache for Italy', () async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      final apiClient = FakeApiClient(localDatabase: database);
      addTearDown(database.close);
      addTearDown(apiClient.dispose);

      await database.putCache(
        key: 'prevention_center',
        payload: jsonEncode({
          'generated_at': '2026-03-25T15:45:00Z',
          'display_name': 'Anna Bianchi',
          'age': 34,
          'biological_sex': 'female',
          'overview': {
            'actionable_screenings': 1,
            'vaccine_reviews': 2,
            'seasonal_checks': 1,
            'follow_up_items': 0,
          },
          'annual_visit': null,
          'visits_and_controls': <Map<String, dynamic>>[],
          'vaccines': <Map<String, dynamic>>[],
          'seasonal_checks': <Map<String, dynamic>>[],
          'follow_up_reminders': <Map<String, dynamic>>[],
        }),
      );

      final repository = PreventionCenterRepository(
        apiClient: apiClient,
        localDatabase: database,
      );

      final center = await repository.fetchCenter(regionCode: 'IT');
      expect(center.displayName, 'Anna Bianchi');
      expect(center.overview.actionableScreenings, 1);
    });
  });
}
