import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_exception.dart';
import 'token_manager.dart';

/// Thin, secure HTTP client for the AVIT Campus+ REST API.
///
/// Security properties:
///  * HTTPS only (the base URL must be `https://` outside debug builds)
///  * Bearer access token attached automatically, refreshed once on 401
///  * Request/response bodies are never logged in release builds
///  * Every failure is mapped to an [AppException] so no raw stack trace or
///    server payload reaches the UI
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenManager,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final TokenManager tokenManager;
  final Duration timeout;
  final http.Client _client;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-App-Version': AppConstants.appVersion,
  };

  bool get _isHttps => baseUrl.startsWith('https://');

  Uri _uri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse(baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl);
    return base.replace(
      path: '${base.path}${path.startsWith('/') ? path : '/$path'}',
      queryParameters:
          query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    return _send(
      'GET',
      path,
      query: query,
      authenticated: authenticated,
      allowRefresh: allowRefresh,
    );
  }

  Future<Map<String, Object?>> post(
    String path, {
    Object? body,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    return _send(
      'POST',
      path,
      body: body,
      authenticated: authenticated,
      allowRefresh: allowRefresh,
    );
  }

  Future<Map<String, Object?>> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    return _send('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, Object?>> delete(
    String path, {
    bool authenticated = true,
  }) async {
    return _send('DELETE', path, authenticated: authenticated);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    if (baseUrl.isEmpty) throw AppException.network;
    if (AppConfig.isProduction && !_isHttps) {
      // Defence in depth: production traffic must never leave the device
      // unencrypted, even if someone misconfigures the dart-define.
      throw const AppException(
        'Insecure API configuration',
        kind: 'config',
      );
    }

    final Map<String, String> headers = <String, String>{..._jsonHeaders};
    if (authenticated) {
      final String? token = await tokenManager.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final http.Request request = http.Request(method, _uri(path, query))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final http.StreamedResponse streamed = await _client
          .send(request)
          .timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw AppException.network;
    } on http.ClientException {
      throw AppException.network;
    } catch (_) {
      throw AppException.network;
    }

    if (response.statusCode == 401 && authenticated && allowRefresh) {
      final bool refreshed = await tokenManager.refresh();
      if (refreshed) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          authenticated: authenticated,
          allowRefresh: false,
        );
      }
      throw AppException.unauthorized;
    }

    return _decode(response);
  }

  Map<String, Object?> _decode(http.Response response) {
    final int status = response.statusCode;
    Map<String, Object?> payload = <String, Object?>{};
    if (response.body.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, Object?>) payload = decoded;
      } catch (_) {
        if (status >= 200 && status < 300) throw AppException.server;
      }
    }

    if (status >= 200 && status < 300) {
      return payload;
    }

    final String message = (payload['message'] as String?) ?? '';
    final Object? errors = payload['errors'];

    if (status == 400 || status == 422) {
      final Map<String, String> fieldErrors = <String, String>{};
      if (errors is Map) {
        errors.forEach((Object? k, Object? v) {
          if (k is String && v is List && v.isNotEmpty && v.first is String) {
            fieldErrors[k] = v.first as String;
          }
        });
      }
      return throw AppException(
        message.isEmpty ? 'Please check the highlighted fields' : message,
        kind: 'validation',
        statusCode: status,
        fieldErrors: fieldErrors,
      );
    }
    if (status == 401) throw AppException.unauthorized;
    if (status == 403) throw AppException.forbidden;
    if (status == 404) throw AppException.notFound;
    if (status == 429) throw AppException.rateLimited;
    if (status >= 500) throw AppException.server;

    throw AppException(
      message.isEmpty ? 'Request failed' : message,
      kind: 'error',
      statusCode: status,
    );
  }

  void dispose() => _client.close();
}
