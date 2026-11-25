import 'dart:math';

import 'conflict.dart';
import 'cursor.dart';
import 'inbox.dart';
import 'retry_policy.dart';
import 'sync_models.dart';

abstract interface class SyncTransport {
  Future<SyncTransportResult> send(SyncEnvelope envelope);
}

class SyncTransportResult {
  const SyncTransportResult({
    this.receipt,
    this.error,
    this.conflict,
  });

  final SyncReceipt? receipt;
  final SyncError? error;
  final SyncConflict? conflict;

  bool get accepted => receipt != null;
  bool get hasConflict => conflict != null;
}

class SyncOperationState {
  const SyncOperationState({
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.error,
  });

  final SyncStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final SyncError? error;
}

class SyncEngine {
  SyncEngine({
    RetryPolicy retryPolicy = const RetryPolicy(),
    Random? random,
  })  : retryPolicy = retryPolicy,
        _random = random ?? Random.secure(),
        inbox = SyncInbox(),
        cursors = CursorStore();

  final RetryPolicy retryPolicy;
  final Random _random;
  final SyncInbox inbox;
  final CursorStore cursors;

  final Map<String, SyncOperationState> _states = {};
  final Map<String, SyncConflict> _conflicts = {};

  SyncOperationState stateFor(String operationId) =>
      _states[operationId] ??
      const SyncOperationState(
        status: SyncStatus.pending,
        attemptCount: 0,
      );

  Iterable<SyncConflict> get conflicts =>
      List<SyncConflict>.unmodifiable(_conflicts.values);

  Future<SyncOperationState> synchronize({
    required SyncEnvelope envelope,
    required SyncTransport transport,
  }) async {
    final existingReceipt = inbox.findByIdempotencyKey(envelope.idempotencyKey);
    if (existingReceipt != null) {
      final state = SyncOperationState(
        status: SyncStatus.synced,
        attemptCount: stateFor(envelope.operationId).attemptCount,
      );
      _states[envelope.operationId] = state;
      return state;
    }

    final now = DateTime.now().toUtc();
    final previous = stateFor(envelope.operationId);
    if (previous.nextAttemptAt != null &&
        now.isBefore(previous.nextAttemptAt!)) {
      return previous;
    }

    final result = await transport.send(envelope);
    if (result.accepted && result.receipt != null) {
      inbox.receive(result.receipt!);
      final state = SyncOperationState(
        status: SyncStatus.synced,
        attemptCount: previous.attemptCount + 1,
      );
      _states[envelope.operationId] = state;
      return state;
    }

    if (result.hasConflict && result.conflict != null) {
      _conflicts[envelope.operationId] = result.conflict!;
      final state = SyncOperationState(
        status: SyncStatus.conflict,
        attemptCount: previous.attemptCount + 1,
        error: const SyncError(
          code: 'COMMERCIAL_CONFLICT',
          message: 'Remote operation requires manual reconciliation',
          retryable: false,
        ),
      );
      _states[envelope.operationId] = state;
      return state;
    }

    final error = result.error ??
        const SyncError(
          code: 'UNKNOWN_SYNC_ERROR',
          message: 'The remote synchronization returned no result',
          retryable: true,
        );
    final attemptCount = previous.attemptCount + 1;
    final mayRetry = error.retryable && retryPolicy.mayRetry(attemptCount);
    final state = SyncOperationState(
      status: mayRetry ? SyncStatus.error : SyncStatus.error,
      attemptCount: attemptCount,
      nextAttemptAt: mayRetry
          ? now.add(retryPolicy.delayForAttempt(
              attemptCount,
              _random,
            ))
          : null,
      error: error,
    );
    _states[envelope.operationId] = state;
    return state;
  }

  void advanceCursor(ChangeCursor cursor) {
    cursors.advance(cursor);
  }

  void recordConflict(SyncConflict conflict) {
    _conflicts[conflict.operationId] = conflict;
  }

  void clearConflict(String operationId) {
    _conflicts.remove(operationId);
  }
}
