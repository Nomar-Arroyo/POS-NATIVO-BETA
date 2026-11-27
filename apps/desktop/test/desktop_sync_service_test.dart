import 'dart:convert';
import 'dart:io';

import 'package:amalfi_pos_desktop/services/desktop_sync_service.dart';
import 'package:amalfi_pos_desktop/services/rpc_invoker.dart';
import 'package:amalfi_pos_desktop/services/supabase_sync_transport.dart';
import 'package:data_local/data_local.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInvoker implements RpcInvoker {
  _FakeInvoker(this._handler);

  final Future<Map<String, dynamic>> Function(
    String function,
    Map<String, dynamic> payload,
  ) _handler;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> payload,
  ) {
    calls++;
    return _handler(function, payload);
  }
}

Map<String, dynamic> _receipt({
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
  late Directory tempDir;
  late LocalDatabase database;
  late String snapshotPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('amalfi_sync_service');
    snapshotPath = '${tempDir.path}/sync_state.json';
    database = await LocalDatabase.openDemoInMemory();
    database.initializeDemoWorkspace();
    database.database.execute('DELETE FROM sync_outbox');
  });

  tearDown(() async {
    database.close();
    await tempDir.delete(recursive: true);
  });

  void insertOutbox({
    String id = 'outbox-1',
    String operationType = 'confirm_sale',
    String entityId = 'sale-1',
    String idempotencyKey = 'sale-key',
    int baseVersion = 1,
    Map<String, dynamic>? payload,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.database.execute(
      'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
      'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        database.localWorkspace!.organizationId,
        operationType,
        entityId,
        idempotencyKey,
        baseVersion,
        jsonEncode(
          payload ??
              {
                'schema_version': 'sale.v1',
                'idempotency_key': idempotencyKey,
                'sale': {'id': entityId},
              },
        ),
        'PENDING',
        0,
        now,
        now,
      ],
    );
  }

  Map<String, Object?> outboxRow(String id) =>
      database.database.select(
        'SELECT sync_status, next_attempt_at, last_error_code, '
        'last_error_message FROM sync_outbox WHERE id = ?',
        [id],
      ).single;

  Future<DesktopSyncService> openService(RpcInvoker invoker) =>
      DesktopSyncService.open(
        database: database,
        transport: SupabaseSyncTransport(invoker: invoker),
        snapshotPath: snapshotPath,
      );

  test('marks SYNCED only with a correlated receipt and persists the engine',
      () async {
    insertOutbox();
    final invoker = _FakeInvoker((function, payload) async => _receipt());
    final service = await openService(invoker);

    final summary = await service.synchronize();

    expect(summary.synced, 1);
    expect(summary.errors, 0);
    expect(summary.conflicts, 0);
    expect(outboxRow('outbox-1')['sync_status'], 'SYNCED');
    final receipt = database.database.select(
      'SELECT operation_type, entity_id, remote_version, result_status '
      'FROM sync_receipts WHERE idempotency_key = ?',
      ['sale-key'],
    ).single;
    expect(receipt['operation_type'], 'confirm_sale');
    expect(receipt['entity_id'], 'sale-1');
    expect(receipt['remote_version'], 1);
    expect(receipt['result_status'], 'accepted');
    final snapshot =
        jsonDecode(await File(snapshotPath).readAsString()) as Map;
    expect(snapshot['version'], 1);
    expect((snapshot['receipts'] as List), hasLength(1));
    expect(invoker.calls, 1);
  });

  test('retains commercial conflicts without retrying them', () async {
    insertOutbox();
    final invoker = _FakeInvoker(
      (function, payload) async => {
        'accepted': false,
        'code': 'CASH_SESSION_INVALID',
        'message': 'Sesión de caja cerrada o ajena',
      },
    );
    final service = await openService(invoker);

    final summary = await service.synchronize();

    expect(summary.conflicts, 1);
    final row = outboxRow('outbox-1');
    expect(row['sync_status'], 'CONFLICT');
    expect(row['last_error_code'], 'CASH_SESSION_INVALID');
    expect(row['next_attempt_at'], isNull);
    final error = database.database.select(
      'SELECT error_code, error_message FROM sync_errors WHERE outbox_id = ?',
      ['outbox-1'],
    ).single;
    expect(error['error_code'], 'CASH_SESSION_INVALID');
    expect(error['error_message'], contains('caja'));

    final second = await service.synchronize();
    expect(second.processed, 0);
    expect(invoker.calls, 1);
  });

  test('schedules retryable transport failures', () async {
    insertOutbox();
    final invoker = _FakeInvoker(
      (function, payload) async => throw const RpcException(
        'NETWORK_TIMEOUT',
        'timeout',
        retryable: true,
      ),
    );
    final service = await openService(invoker);

    final summary = await service.synchronize();

    expect(summary.errors, 1);
    final row = outboxRow('outbox-1');
    expect(row['sync_status'], 'ERROR');
    expect(row['last_error_code'], 'NETWORK_TIMEOUT');
    expect(row['next_attempt_at'], isNotNull);

    final second = await service.synchronize();
    expect(second.processed, 0);
    expect(invoker.calls, 1);
  });

  test('keeps unsupported operations untouched and terminal', () async {
    insertOutbox(
      operationType: 'open_cash_session',
      entityId: 'cash-1',
      idempotencyKey: 'cash-key',
      payload: {'cash_session_id': 'cash-1'},
    );
    final invoker = _FakeInvoker(
      (function, payload) async => throw StateError('must not be sent'),
    );
    final service = await openService(invoker);

    final summary = await service.synchronize();

    expect(summary.unsupported, 1);
    expect(invoker.calls, 0);
    final row = outboxRow('outbox-1');
    expect(row['sync_status'], 'ERROR');
    expect(row['last_error_code'], 'OPERATION_UNSUPPORTED');
    expect(row['next_attempt_at'], isNull);

    final second = await service.synchronize();
    expect(second.processed, 0);
  });

  test('reuses a persisted receipt after a restart without resending',
      () async {
    insertOutbox();
    final invoker = _FakeInvoker((function, payload) async => _receipt());
    final first = await openService(invoker);
    expect((await first.synchronize()).synced, 1);
    expect(invoker.calls, 1);

    database.database.execute(
      "UPDATE sync_outbox SET sync_status = 'PENDING' WHERE id = 'outbox-1'",
    );

    final restarted = await openService(invoker);
    final summary = await restarted.synchronize();

    expect(summary.synced, 1);
    expect(invoker.calls, 1);
    expect(outboxRow('outbox-1')['sync_status'], 'SYNCED');
  });

  test('quarantines a corrupt snapshot instead of deleting it', () async {
    await File(snapshotPath).writeAsString('{not-json');
    insertOutbox();
    final invoker = _FakeInvoker((function, payload) async => _receipt());

    final service = await openService(invoker);

    expect(service.restoreWarning, isNotNull);
    final quarantined = tempDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('.corrupt-'))
        .toList();
    expect(quarantined, hasLength(1));
    expect(await quarantined.single.readAsString(), '{not-json');

    final summary = await service.synchronize();
    expect(summary.synced, 1);
  });
}
