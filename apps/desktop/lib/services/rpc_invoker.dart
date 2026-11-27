import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'supabase_config.dart';

/// Supplies the Supabase Auth access token for the current staff session.
///
/// The token must be a user JWT: the backend RPCs resolve the profile and
/// permissions from it. Returning `null` means there is no authenticated
/// session and the call must not be attempted.
typedef AccessTokenProvider = Future<String?> Function();

abstract interface class RpcInvoker {
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> payload,
  );
}

class RpcException implements Exception {
  const RpcException(
    this.code,
    this.message, {
    required this.retryable,
    this.statusCode,
  });

  final String code;
  final String message;
  final bool retryable;
  final int? statusCode;

  @override
  String toString() => 'RpcException($code, status: $statusCode): $message';
}

/// Calls a Supabase/PostgREST RPC through `POST /rest/v1/rpc/<function>`.
///
/// The body is always wrapped as `{"p_payload": ...}` because every backend
/// function receives a single JSON payload. Errors are normalised into
/// [RpcException] with an explicit retry decision; no token is ever logged.
class SupabaseRpcInvoker implements RpcInvoker {
  SupabaseRpcInvoker({
    required this.config,
    required this.accessTokenProvider,
    HttpClient? client,
  })  : _client = client ?? HttpClient(),
        _ownsClient = client == null;

  final SupabaseConfig config;
  final AccessTokenProvider accessTokenProvider;
  final HttpClient _client;
  final bool _ownsClient;

  static final _functionPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> payload,
  ) async {
    if (!_functionPattern.hasMatch(function)) {
      throw ArgumentError.value(function, 'function', 'invalid RPC name');
    }
    final token = await accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const RpcException(
        'AUTH_REQUIRED',
        'No hay una sesión de Supabase Auth activa en este terminal',
        retryable: true,
      );
    }

    final uri = Uri.parse('${config.baseUrl}/rest/v1/rpc/$function');
    final HttpClientRequest request;
    try {
      request = await _client.postUrl(uri).timeout(config.timeout);
    } on TimeoutException {
      throw RpcException(
        'NETWORK_TIMEOUT',
        'Tiempo de conexión agotado con ${config.baseUrl.host}',
        retryable: true,
      );
    } on SocketException catch (error) {
      throw RpcException(
        'NETWORK_UNAVAILABLE',
        error.message,
        retryable: true,
      );
    }

    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set('apikey', config.anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer ${token.trim()}');
    request.add(utf8.encode(jsonEncode({'p_payload': payload})));

    final HttpClientResponse response;
    final String body;
    try {
      response = await request.close().timeout(config.timeout);
      body = await utf8.decoder.bind(response).join().timeout(config.timeout);
    } on TimeoutException {
      throw RpcException(
        'NETWORK_TIMEOUT',
        'La respuesta de ${config.baseUrl.host} excedió el tiempo límite',
        retryable: true,
      );
    } on SocketException catch (error) {
      throw RpcException(
        'NETWORK_UNAVAILABLE',
        error.message,
        retryable: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromStatus(response.statusCode, body);
    }
    if (body.trim().isEmpty) {
      throw RpcException(
        'RPC_EMPTY_RESPONSE',
        'La función $function no devolvió un recibo',
        retryable: false,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw RpcException(
        'RPC_INVALID_RESPONSE',
        'La función $function devolvió un JSON no objeto',
        retryable: false,
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  RpcException _errorFromStatus(int statusCode, String body) {
    var code = 'HTTP_$statusCode';
    var message = body.trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final hint = decoded['hint'];
        final serverCode = decoded['code'];
        final serverMessage = decoded['message'];
        if (hint is String && hint.trim().isNotEmpty) {
          code = hint.trim();
        } else if (serverCode is String && serverCode.trim().isNotEmpty) {
          code = serverCode.trim();
        }
        if (serverMessage is String && serverMessage.trim().isNotEmpty) {
          message = serverMessage.trim();
        }
      }
    } on FormatException {
      // Non-JSON gateway errors keep the raw body as the message.
    }
    if (statusCode == 401) code = 'AUTH_EXPIRED';
    if (message.isEmpty) message = 'HTTP $statusCode';
    final retryable =
        statusCode >= 500 || statusCode == 408 || statusCode == 429 ||
            statusCode == 401;
    return RpcException(
      code,
      message,
      retryable: retryable,
      statusCode: statusCode,
    );
  }

  void close() {
    if (_ownsClient) _client.close(force: true);
  }
}
