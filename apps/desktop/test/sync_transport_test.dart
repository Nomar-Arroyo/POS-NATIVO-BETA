import 'dart:convert';
import 'dart:io';

import 'package:amalfi_pos_desktop/services/rpc_invoker.dart';
import 'package:amalfi_pos_desktop/services/supabase_config.dart';
import 'package:amalfi_pos_desktop/services/supabase_sync_transport.dart';
import 'package:core_sync/core_sync.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInvoker implements RpcInvoker {
  _FakeInvoker(this._handler);

  final Future<Map<String, dynamic>> Function(
    String function,
    Map<String, dynamic> payload,
  ) _handler;
  final List<({String function, Map<String, dynamic> payload})> calls = [];

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> payload,
  ) {
    calls.add((function: function, payload: payload));
    return _handler(function, payload);
  }
}

SyncEnvelope _saleEnvelope({
  String operationType = 'confirm_sale',
  String idempotencyKey = 'sale-key',
  String entityId = 'sale-1',
  Map<String, dynamic>? payload,
}) {
  final body = payload ??
      {
        'schema_version': 'sale.v1',
        'idempotency_key': idempotencyKey,
        'sale': {'id': entityId},
      };
  return SyncEnvelope(
    operationId: 'outbox-1',
    idempotencyKey: idempotencyKey,
    operationType: operationType,
    entityId: entityId,
    organizationId: 'org-1',
    terminalId: 'terminal-1',
    baseVersion: 1,
    payloadJson: jsonEncode(body),
  );
}

Map<String, dynamic> _acceptedReceipt({
  String idempotencyKey = 'sale-key',
  String entityId = 'sale-1',
}) =>
    {
      'accepted': true,
      'duplicate': false,
      'operation_id': 'op-1',
      'operation_type': 'confirm_sale',
      'entity_id': entityId,
      'idempotency_key': idempotencyKey,
      'remote_version': 1,
      'applied_at': '2026-11-27T00:00:00Z',
    };

void main() {
  group('SupabaseConfig', () {
    test('normalises trailing slashes', () {
      final config = SupabaseConfig(
        url: 'https://example.supabase.co/',
        anonKey: 'public-anon-key',
      );
      expect(config.baseUrl.toString(), 'https://example.supabase.co');
    });

    test('rejects non http(s) URLs and empty keys', () {
      expect(
        () => SupabaseConfig(url: 'example.supabase.co', anonKey: 'key'),
        throwsArgumentError,
      );
      expect(
        () => SupabaseConfig(url: 'https://example.supabase.co', anonKey: ' '),
        throwsArgumentError,
      );
    });

    test('returns null when compile-time values are absent', () {
      expect(SupabaseConfig.fromEnvironment(), isNull);
    });
  });

  group('SupabaseRpcInvoker', () {
    late HttpServer server;
    late SupabaseRpcInvoker invoker;
    final requests = <HttpRequest>[];
    final bodies = <String>[];

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      requests.clear();
      bodies.clear();
      final config = SupabaseConfig(
        url: 'http://127.0.0.1:${server.port}',
        anonKey: 'anon-key',
      );
      invoker = SupabaseRpcInvoker(
        config: config,
        accessTokenProvider: () async => 'user-token',
      );
    });

    tearDown(() async {
      invoker.close();
      await server.close(force: true);
    });

    test('posts the wrapped payload with auth headers', () async {
      server.listen((request) async {
        requests.add(request);
        bodies.add(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_acceptedReceipt()));
        await request.response.close();
      });

      final response = await invoker.invoke(
        'rpc_confirm_sale',
        {'idempotency_key': 'sale-key'},
      );

      expect(response['accepted'], isTrue);
      expect(requests.single.method, 'POST');
      expect(requests.single.uri.path, '/rest/v1/rpc/rpc_confirm_sale');
      expect(requests.single.headers.value('apikey'), 'anon-key');
      expect(
        requests.single.headers.value(HttpHeaders.authorizationHeader),
        'Bearer user-token',
      );
      expect(jsonDecode(bodies.single), {
        'p_payload': {'idempotency_key': 'sale-key'},
      });
    });

    test('maps an expired token to a retryable auth error', () async {
      server.listen((request) async {
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 'P0001',
            'message': 'JWT expired',
            'hint': 'AUTH_EXPIRED',
          }),
        );
        await request.response.close();
      });

      await expectLater(
        invoker.invoke('rpc_confirm_sale', const {}),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', 'AUTH_EXPIRED')
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('keeps server errors retryable and client errors terminal', () async {
      var status = 500;
      server.listen((request) async {
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'message': 'failure'}));
        await request.response.close();
      });

      await expectLater(
        invoker.invoke('rpc_confirm_sale', const {}),
        throwsA(
          isA<RpcException>()
              .having((error) => error.statusCode, 'statusCode', 500)
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );

      status = 400;
      await expectLater(
        invoker.invoke('rpc_confirm_sale', const {}),
        throwsA(
          isA<RpcException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('refuses to call without an access token', () async {
      final unauthenticated = SupabaseRpcInvoker(
        config: SupabaseConfig(
          url: 'http://127.0.0.1:${server.port}',
          anonKey: 'anon-key',
        ),
        accessTokenProvider: () async => null,
      );
      addTearDown(unauthenticated.close);

      await expectLater(
        unauthenticated.invoke('rpc_confirm_sale', const {}),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', 'AUTH_REQUIRED')
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('rejects an invalid RPC name before any network call', () async {
      await expectLater(
        invoker.invoke('rpc_confirm_sale; drop table sales', const {}),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  });

  group('SupabaseSyncTransport', () {
    test('maps confirm_sale and builds a correlated receipt', () async {
      final invoker = _FakeInvoker((function, payload) async {
        expect(function, 'rpc_confirm_sale');
        expect(payload['idempotency_key'], 'sale-key');
        return _acceptedReceipt();
      });
      final transport = SupabaseSyncTransport(invoker: invoker);

      final result = await transport.send(_saleEnvelope());

      expect(result.receipt, isNotNull);
      final receipt = result.receipt!;
      expect(receipt.accepted, isTrue);
      expect(receipt.operationId, 'op-1');
      expect(receipt.operationType, 'confirm_sale');
      expect(receipt.entityId, 'sale-1');
      expect(receipt.idempotencyKey, 'sale-key');
      expect(receipt.remoteVersion, 1);
      expect(invoker.calls, hasLength(1));
    });

    test('turns a commercial rejection into a retained conflict', () async {
      final invoker = _FakeInvoker(
        (function, payload) async => {
          'accepted': false,
          'code': 'PRICE_CHANGED',
          'message': 'Precio vigente 350 distinto al enviado 1',
          'operation_id': 'op-1',
          'idempotency_key': 'sale-key',
        },
      );
      final transport = SupabaseSyncTransport(invoker: invoker);

      final result = await transport.send(_saleEnvelope());

      expect(result.receipt, isNull);
      expect(result.conflict, isNotNull);
      final conflict = result.conflict!;
      expect(conflict.type, ConflictType.staleCatalogVersion);
      expect(conflict.remoteValue, 'PRICE_CHANGED');
      expect(conflict.idempotencyKey, 'sale-key');
      expect(conflict.operationId, 'outbox-1');
      expect(conflict.message, contains('Precio vigente'));
    });

    test('maps terminal conflict codes to specific conflict types', () async {
      Future<ConflictType> typeFor(String code) async {
        final transport = SupabaseSyncTransport(
          invoker: _FakeInvoker(
            (function, payload) async => {
              'accepted': false,
              'code': code,
              'message': 'conflict',
            },
          ),
        );
        final result = await transport.send(_saleEnvelope());
        return result.conflict!.type;
      }

      expect(
        await typeFor('INSUFFICIENT_STOCK'),
        ConflictType.stockMismatch,
      );
      expect(
        await typeFor('CASH_SESSION_INVALID'),
        ConflictType.closedCashSession,
      );
      expect(
        await typeFor('TERMINAL_INVALID'),
        ConflictType.revokedTerminal,
      );
    });

    test('does not send operations without a published RPC contract', () async {
      final invoker = _FakeInvoker(
        (function, payload) async => throw StateError('must not be called'),
      );
      final transport = SupabaseSyncTransport(invoker: invoker);

      final result = await transport.send(
        _saleEnvelope(operationType: 'open_cash_session'),
      );

      expect(invoker.calls, isEmpty);
      expect(result.receipt, isNull);
      expect(result.error!.code, 'OPERATION_UNSUPPORTED');
      expect(result.error!.retryable, isFalse);
    });

    test('rejects a receipt without operation or entity', () async {
      final invoker = _FakeInvoker(
        (function, payload) async => {
          'accepted': true,
          'idempotency_key': 'sale-key',
          'entity_id': 'sale-1',
          'remote_version': 1,
        },
      );
      final transport = SupabaseSyncTransport(invoker: invoker);

      final result = await transport.send(_saleEnvelope());

      expect(result.receipt, isNull);
      expect(result.error!.code, 'RECEIPT_INVALID');
      expect(result.error!.retryable, isFalse);
    });

    test('rejects a payload whose key or sale does not match the outbox',
        () async {
      final invoker = _FakeInvoker(
        (function, payload) async => _acceptedReceipt(),
      );
      final transport = SupabaseSyncTransport(invoker: invoker);

      final wrongKey = await transport.send(
        _saleEnvelope(
          payload: {
            'idempotency_key': 'another-key',
            'sale': {'id': 'sale-1'},
          },
        ),
      );
      expect(wrongKey.error!.code, 'PAYLOAD_MISMATCH');

      final wrongSale = await transport.send(
        _saleEnvelope(
          payload: {
            'idempotency_key': 'sale-key',
            'sale': {'id': 'another-sale'},
          },
        ),
      );
      expect(wrongSale.error!.code, 'PAYLOAD_MISMATCH');
      expect(invoker.calls, isEmpty);
    });

    test('propagates RPC errors with their retry decision', () async {
      final transport = SupabaseSyncTransport(
        invoker: _FakeInvoker(
          (function, payload) async => throw const RpcException(
            'NETWORK_TIMEOUT',
            'timeout',
            retryable: true,
          ),
        ),
      );

      final result = await transport.send(_saleEnvelope());

      expect(result.error!.code, 'NETWORK_TIMEOUT');
      expect(result.error!.retryable, isTrue);
    });
  });
}
