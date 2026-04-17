import 'dart:convert';

import 'package:clindiary/app/core/app_config.dart';
import 'package:clindiary/app/core/network/session_expiry_notifier.dart';
import 'package:clindiary/app/core/storage/active_profile_store.dart';
import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/secure_token_storage.dart';
import 'package:clindiary/features/auth/domain/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class MultipartUploadFile {
  const MultipartUploadFile({
    required this.fieldName,
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String fieldName;
  final String filename;
  final List<int> bytes;
  final String contentType;
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.details});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;

  bool get isFeatureLocked => code == 'feature_locked';
  String? get featureCode => details?['feature_code']?.toString();
  String? get recommendedPlanCode =>
      details?['recommended_plan_code']?.toString();

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required http.Client client,
    required AppConfig config,
    required SecureTokenStorage tokenStorage,
    required SessionExpiryNotifier sessionExpiryNotifier,
    LocalDatabase? localDatabase,
  }) : _client = client,
       _config = config,
       _tokenStorage = tokenStorage,
       _sessionExpiryNotifier = sessionExpiryNotifier,
       _localDatabase = localDatabase;

  final http.Client _client;
  final AppConfig _config;
  final SecureTokenStorage _tokenStorage;
  final SessionExpiryNotifier _sessionExpiryNotifier;
  final LocalDatabase? _localDatabase;
  Future<AuthSession>? _refreshSessionInFlight;

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      method: 'GET',
      path: path,
      authenticated: authenticated,
    );
    return _decodeMap(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      method: 'GET',
      path: path,
      authenticated: authenticated,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      method: 'POST',
      path: path,
      authenticated: authenticated,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      method: 'PUT',
      path: path,
      authenticated: authenticated,
      body: jsonEncode(body),
    );
    return _decodeMap(response);
  }

  Future<void> delete(String path, {bool authenticated = true}) async {
    final response = await _send(
      method: 'DELETE',
      path: path,
      authenticated: authenticated,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      method: 'DELETE',
      path: path,
      authenticated: authenticated,
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      method: 'PATCH',
      path: path,
      authenticated: authenticated,
      body: jsonEncode(body),
    );
    return _decodeMap(response);
  }

  Future<Uint8List> getBytes(String path, {bool authenticated = true}) async {
    final response = await _send(
      method: 'GET',
      path: path,
      authenticated: authenticated,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    final dynamic decoded = _decodeBodySafely(response.body);
    throw _buildApiException(decoded, response.statusCode);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<MultipartUploadFile> files,
    bool authenticated = true,
  }) async {
    if (_config.localOnlyMode) {
      throw ApiException(
        'Local-only mode is enabled. Network requests are disabled.',
        statusCode: 503,
        code: 'local_only_mode',
      );
    }
    final request = http.MultipartRequest('POST', _uri(path));
    final headers = await _headers(authenticated: authenticated);
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    request.files.addAll(
      files.map(
        (file) => http.MultipartFile.fromBytes(
          file.fieldName,
          file.bytes,
          filename: file.filename,
          contentType: MediaType.parse(file.contentType),
        ),
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    await _recordTrace(method: 'POST', path: path, response: response);
    return _decodeMap(response);
  }

  Future<int> flushPendingOperations({int limit = 20}) async {
    if (_localDatabase == null) {
      return 0;
    }
    final queued = await _localDatabase.listPendingOperations(limit: limit);
    var synced = 0;
    for (final item in queued) {
      try {
        final response = await _send(
          method: item.method,
          path: item.path,
          authenticated: true,
          body: item.payload,
          activeProfileIdOverride: item.profileId,
        );
        _ensureSuccess(response);
        await _localDatabase.markPendingOperationSynced(item.id);
        synced += 1;
      } catch (error) {
        await _localDatabase.incrementPendingOperationAttempts(
          item.id,
          error.toString(),
        );
      }
    }
    return synced;
  }

  Future<void> enqueueJsonOperation({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    String? lastError,
    bool replaceExisting = false,
  }) async {
    if (_localDatabase == null) {
      return;
    }
    final activeProfileId = await _localDatabase.readCache(
      activeProfileIdCacheKey,
    );
    await _localDatabase.enqueuePendingOperation(
      method: method,
      path: path,
      profileId: activeProfileId?.trim().isEmpty == true
          ? null
          : activeProfileId?.trim(),
      payload: jsonEncode(body),
      lastError: lastError,
      replaceExisting: replaceExisting,
    );
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    String? activeProfileIdOverride,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Platform': _clientPlatformLabel(),
    };

    if (!authenticated) {
      return headers;
    }

    final session = await _ensureValidSession();
    headers['Authorization'] = 'Bearer ${session.accessToken}';
    if (_localDatabase != null) {
      final activeProfileId =
          activeProfileIdOverride ??
          await _localDatabase.readCache(activeProfileIdCacheKey);
      if (activeProfileId != null && activeProfileId.trim().isNotEmpty) {
        headers['X-Patient-Id'] = activeProfileId.trim();
      }
    }
    return headers;
  }

  Future<AuthSession> refreshSession() async {
    final inFlight = _refreshSessionInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final refreshFuture = _refreshSessionInternal();
    _refreshSessionInFlight = refreshFuture;
    refreshFuture.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_refreshSessionInFlight, refreshFuture)) {
        _refreshSessionInFlight = null;
      }
    });
    return refreshFuture;
  }

  Future<AuthSession> _ensureValidSession() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw ApiException('Sessione non disponibile', statusCode: 401);
    }

    final now = DateTime.now().toUtc();
    if (session.accessTokenExpiresAt.isAfter(
      now.add(const Duration(seconds: 30)),
    )) {
      return session;
    }

    return refreshSession();
  }

  Future<AuthSession> _refreshSessionInternal() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw ApiException('Sessione non disponibile', statusCode: 401);
    }

    final now = DateTime.now().toUtc();
    if (session.refreshTokenExpiresAt.isBefore(
      now.add(const Duration(seconds: 30)),
    )) {
      await _handleExpiredSession();
      throw ApiException('Session expired. Sign in again.', statusCode: 401);
    }

    if (session.accessTokenExpiresAt.isAfter(
      now.add(const Duration(seconds: 30)),
    )) {
      return session;
    }

    try {
      final response = await _client.post(
        _uri('/api/v1/auth/refresh'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': session.refreshToken}),
      );

      final decoded = _decodeMap(response);
      final refreshed = AuthSession.fromJson(decoded);
      await _tokenStorage.saveSession(refreshed);
      return refreshed;
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
      await _handleExpiredSession();
      throw ApiException('Session expired. Sign in again.', statusCode: 401);
    }
  }

  Future<void> _handleExpiredSession() async {
    _sessionExpiryNotifier.notifySessionExpired();
    await _tokenStorage.clear();
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    required bool authenticated,
    String? body,
    String? activeProfileIdOverride,
  }) async {
    if (_config.localOnlyMode) {
      throw ApiException(
        'Local-only mode is enabled. Network requests are disabled.',
        statusCode: 503,
        code: 'local_only_mode',
      );
    }
    final request = http.Request(method, _uri(path));
    request.headers.addAll(
      await _headers(
        authenticated: authenticated,
        activeProfileIdOverride: activeProfileIdOverride,
      ),
    );
    if (body != null) {
      request.body = body;
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    await _recordTrace(method: method, path: path, response: response);
    return response;
  }

  Future<void> _recordTrace({
    required String method,
    required String path,
    required http.Response response,
  }) async {
    if (_localDatabase == null) {
      return;
    }
    final responseTimeHeader = response.headers['x-response-time-ms'];
    final responseTimeMs = responseTimeHeader == null
        ? null
        : double.tryParse(responseTimeHeader);
    await _localDatabase.recordTrace(
      method: method,
      path: path,
      statusCode: response.statusCode,
      requestId: response.headers['x-request-id'],
      responseTimeMs: responseTimeMs,
    );
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${_config.apiBaseUrl}$normalized');
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final dynamic decoded = _decodeBodySafely(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    throw _buildApiException(decoded, response.statusCode);
  }

  List<dynamic> _decodeList(http.Response response) {
    final dynamic decoded = _decodeBodySafely(
      response.body,
      fallbackList: true,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as List<dynamic>;
    }
    throw _buildApiException(decoded, response.statusCode);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final dynamic decoded = _decodeBodySafely(response.body);
    throw _buildApiException(decoded, response.statusCode);
  }

  dynamic _decodeBodySafely(String body, {bool fallbackList = false}) {
    if (body.isEmpty) {
      return fallbackList ? <dynamic>[] : <String, dynamic>{};
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return {
        'detail': {
          'message':
              'The server returned an unreadable error. Check the backend logs.',
          'raw_body': body,
        },
      };
    }
  }

  String _extractMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is Map<String, dynamic>) {
        final message = detail['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      if (detail != null) {
        return detail.toString();
      }
    }
    return 'Richiesta non riuscita';
  }

  ApiException _buildApiException(dynamic decoded, int statusCode) {
    final detail = _extractDetailMap(decoded);
    return ApiException(
      _extractMessage(decoded),
      statusCode: statusCode,
      code: detail?['code']?.toString(),
      details: detail,
    );
  }

  Map<String, dynamic>? _extractDetailMap(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final detail = decoded['detail'];
    if (detail is Map<String, dynamic>) {
      return detail;
    }
    return null;
  }
}

String _clientPlatformLabel() {
  if (kIsWeb) {
    return 'web';
  }
  return defaultTargetPlatform.name;
}
