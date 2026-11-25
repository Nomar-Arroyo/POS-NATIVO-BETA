import 'dart:convert';
import 'dart:math';

import 'package:core_sync/core_sync.dart';
import 'package:test/test.dart';

SyncEnvelope envelope({
  required String operationId,
  required String idempotencyKey,
}) =>
    SyncEnvelope(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      operationType: 'confirm_sale',
      entityId: 'sale-$operationId',
      organizationId: 'organization-test',
      terminalId: 'terminal-test',
      baseVersion: 1,
      payloadJson: jsonEncode({'synthetic': true}),
    );

class TransportStub implements SyncTransport {
  TransportStub(this.results);

  final List<SyncTransportResult> results;
  int calls = 0;

  @override
  Future<SyncTransportResult> send(SyncEnvelope envelope) async {
    final index = calls;
    calls++;
    return results[index];
  }
}

void main() {
  group('RetryPolicy', () {
    test('uses exponential backoff and bounded jitter', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 2),
        maximumDelay: Duration(seconds: 30),
        jitterFraction: 0.20,
      );
      final random = RandomForTests([0, 10, 20]);

      final first = policy.delayForAttempt(1, random);
      final second = policy.delayForAttempt(2, random);
      final capped = policy.delayForAttempt(20, random);

      expect(first.inMilliseconds, inInclusiveRange(1600, 2400));
      expect(second.inMilliseconds, inInclusiveRange(3200, 4800));
      expect(capped.inMilliseconds, inInclusiveRange(24000, 30000));
    });

    test('stops at configured attempt limit', () {
      const policy = RetryPolicy(maximumAttempts: 3);
      expect(policy.mayRetry(1), isTrue);
      expect(policy.mayRetry(3), isFalse);
    });
  });

  group('SyncInbox', () {
    test('returns the original receipt for repeated idempotency key', () {
      final inbox = SyncInbox();
      const first = SyncReceipt(
        idempotencyKey: 'same-operation',
        operationId: 'operation-1',
        entityId: 'sale-1',
        remoteVersion: 2,
        accepted: true,
      );
      const repeated = SyncReceipt(
        idempotencyKey: 'same-operation',
        operationId: 'operation-1',
        entityId: 'sale-1',
        remoteVersion: 2,
        accepted: true,
      );

      expect(inbox.receive(first), same(first));
      expect(inbox.receive(repeated), same(first));
      expect(inbox.receipts, hasLength(1));
    });
  });

  group('SyncEngine', () {
    test('stores a receipt and marks operation synced', () async {
      final engine = SyncEngine();
      final transport = TransportStub([
        const SyncTransportResult(
          receipt: SyncReceipt(
            idempotencyKey: 'key-1',
            operationId: 'operation-1',
            entityId: 'sale-1',
            remoteVersion: 7,
            accepted: true,
          ),
        ),
      ]);
      final state = await engine.synchronize(
        envelope: envelope(
          operationId: 'operation-1',
          idempotencyKey: 'key-1',
        ),
        transport: transport,
      );

      expect(state.status, SyncStatus.synced);
      expect(engine.inbox.contains('key-1'), isTrue);
    });

    test('does not resend an already received idempotency key', () async {
      final engine = SyncEngine();
      final transport = TransportStub([
        const SyncTransportResult(
          receipt: SyncReceipt(
            idempotencyKey: 'duplicate-key',
            operationId: 'operation-2',
            entityId: 'sale-2',
            remoteVersion: 8,
            accepted: true,
          ),
        ),
      ]);
      final input = envelope(
        operationId: 'operation-2',
        idempotencyKey: 'duplicate-key',
      );

      await engine.synchronize(
        envelope: input,
        transport: transport,
      );
      await engine.synchronize(
        envelope: input,
        transport: transport,
      );

      expect(transport.calls, 1);
    });

    test('persists errors and schedules the next attempt', () async {
      final engine = SyncEngine(
        retryPolicy: const RetryPolicy(
          initialDelay: Duration(milliseconds: 10),
          jitterFraction: 0,
        ),
      );
      final transport = TransportStub([
        const SyncTransportResult(
          error: SyncError(
            code: 'NETWORK',
            message: 'Connection unavailable',
            retryable: true,
          ),
        ),
      ]);
      final state = await engine.synchronize(
        envelope: envelope(
          operationId: 'operation-error',
          idempotencyKey: 'key-error',
        ),
        transport: transport,
      );

      expect(state.status, SyncStatus.error);
      expect(state.nextAttemptAt, isNotNull);
      expect(state.error!.code, 'NETWORK');
    });

    test('creates a reviewable commercial conflict', () async {
      final engine = SyncEngine();
      const conflict = SyncConflict(
        operationId: 'operation-stock',
        entityId: 'sale-stock',
        idempotencyKey: 'key-stock',
        type: ConflictType.stockMismatch,
        message: 'Remote stock no longer matches',
        localValue: '3',
        remoteValue: '1',
      );
      final transport = TransportStub([
        const SyncTransportResult(conflict: conflict),
      ]);
      final state = await engine.synchronize(
        envelope: envelope(
          operationId: 'operation-stock',
          idempotencyKey: 'key-stock',
        ),
        transport: transport,
      );

      expect(state.status, SyncStatus.conflict);
      expect(engine.conflicts, hasLength(1));
      expect(conflict.toJson()['type'], 'stockMismatch');
    });

    test('does not confuse distinct sales with equal payload', () async {
      final engine = SyncEngine();
      final transport = TransportStub([
        SyncTransportResult(
          receipt: SyncReceipt(
            idempotencyKey: 'key-a',
            operationId: 'operation-a',
            entityId: 'sale-a',
            remoteVersion: 1,
            accepted: true,
          ),
        ),
        SyncTransportResult(
          receipt: SyncReceipt(
            idempotencyKey: 'key-b',
            operationId: 'operation-b',
            entityId: 'sale-b',
            remoteVersion: 1,
            accepted: true,
          ),
        ),
      ]);

      await engine.synchronize(
        envelope: envelope(
          operationId: 'operation-a',
          idempotencyKey: 'key-a',
        ),
        transport: transport,
      );
      await engine.synchronize(
        envelope: envelope(
          operationId: 'operation-b',
          idempotencyKey: 'key-b',
        ),
        transport: transport,
      );

      expect(engine.inbox.receipts, hasLength(2));
    });

    test('persists cursor only as a ChangeCursor value', () {
      final engine = SyncEngine();
      engine.advanceCursor(
        const ChangeCursor(
          stream: 'sales',
          value: '2026-11-24T12:00:00Z|sale-a',
        ),
      );
      expect(
        engine.cursors.get('sales')?.value,
        '2026-11-24T12:00:00Z|sale-a',
      );
    });
  });
}

class RandomForTests implements Random {
  RandomForTests(this.values);

  final List<int> values;
  int index = 0;

  @override
  int nextInt(int max) {
    final value = values[index++ % values.length];
    return value.clamp(0, max - 1);
  }

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
