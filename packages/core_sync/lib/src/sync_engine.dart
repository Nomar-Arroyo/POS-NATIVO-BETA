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

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'attempt_count': attemptCount,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
        'error': error?.toJson(),
      };

  factory SyncOperationState.fromJson(Map<String, dynamic> json) =>
      SyncOperationState(
        status: SyncStatus.values.byName(json['status'] as String),
        attemptCount: (json['attempt_count'] as num).toInt(),
        nextAttemptAt: json['next_attempt_at'] == null
            ? null
            : DateTime.parse(json['next_attempt_at'] as String),
        error: json['error'] == null
            ? null
            : SyncError.fromJson(
                Map<String, dynamic>.from(json['error'] as Map),
              ),
      );
}

class SyncEngineSnapshot {
  const SyncEngineSnapshot({
    required this.operations,
    required this.receipts,
    required this.cursors,
    required this.conflicts,
  });

  final Map<String, SyncOperationState> operations;
  final List<SyncReceipt> receipts;
  final List<ChangeCursor> cursors;
  final List<SyncConflict> conflicts;

  static const empty = SyncEngineSnapshot(
    operations: {},
    receipts: [],
    cursors: [],
    conflicts: [],
  );

  static const version = 1;

  Map<String, dynamic> toJson() => {
        'version': version,
        'operations': {
          for (final entry in operations.entries)
            entry.key: entry.value.toJson(),
        },
        'receipts': [for (final receipt in receipts) receipt.toJson()],
        'cursors': [
          for (final cursor in cursors)
            {'stream': cursor.stream, 'value': cursor.value},
        ],
        'conflicts': [for (final conflict in conflicts) conflict.toJson()],
      };

  factory SyncEngineSnapshot.fromJson(Map<String, dynamic> json) {
    if ((json['version'] as num?)?.toInt() != version) {
      throw FormatException(
        'Unsupported sync snapshot version: ${json['version']}',
      );
    }
    final operations = <String, SyncOperationState>{};
    for (final entry
        in (json['operations'] as Map<String, dynamic>? ?? const {}).entries) {
      operations[entry.key] = SyncOperationState.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return SyncEngineSnapshot(
      operations: operations,
      receipts: [
        for (final receipt in json['receipts'] as List<dynamic>? ?? const [])
          SyncReceipt.fromJson(Map<String, dynamic>.from(receipt as Map)),
      ],
      cursors: [
        for (final cursor in json['cursors'] as List<dynamic>? ?? const [])
          ChangeCursor(
            stream: (cursor as Map)['stream'] as String,
            value: cursor['value'] as String,
          ),
      ],
      conflicts: [
        for (final conflict in json['conflicts'] as List<dynamic>? ?? const [])
          SyncConflict.fromJson(Map<String, dynamic>.from(conflict as Map)),
      ],
    );
  }
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
    final existingReceipt =
        inbox.findByIdempotencyKey(envelope.idempotencyKey);
    if (existingReceipt != null) {
      final mismatch = _receiptMismatch(envelope, existingReceipt);
      if (mismatch != null) {
        final state = SyncOperationState(
          status: SyncStatus.error,
          attemptCount: stateFor(envelope.operationId).attemptCount + 1,
          error: SyncError(
            code: 'RECEIPT_MISMATCH',
            message: mismatch,
            retryable: false,
          ),
        );
        _states[envelope.operationId] = state;
        return state;
      }
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
    final receipt = result.receipt;
    if (receipt != null) {
      final mismatch = _receiptMismatch(envelope, receipt);
      if (mismatch != null) {
        final state = SyncOperationState(
          status: SyncStatus.error,
          attemptCount: previous.attemptCount + 1,
          error: SyncError(
            code: 'RECEIPT_MISMATCH',
            message: mismatch,
            retryable: false,
          ),
        );
        _states[envelope.operationId] = state;
        return state;
      }
      if (!receipt.accepted) {
        final state = SyncOperationState(
          status: SyncStatus.error,
          attemptCount: previous.attemptCount + 1,
          error: const SyncError(
            code: 'RECEIPT_REJECTED',
            message: 'The remote endpoint rejected the operation',
            retryable: false,
          ),
        );
        _states[envelope.operationId] = state;
        return state;
      }
      inbox.receive(receipt);
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

  String? _receiptMismatch(SyncEnvelope envelope, SyncReceipt receipt) {
    if (receipt.idempotencyKey != envelope.idempotencyKey) {
      return 'Receipt idempotency key does not match the operation';
    }
    if (receipt.entityId != envelope.entityId) {
      return 'Receipt entity does not match the operation';
    }
    if (receipt.operationType != null &&
        receipt.operationType != envelope.operationType) {
      return 'Receipt operation type does not match the operation';
    }
    if (receipt.operationId.isEmpty) {
      return 'Receipt is missing the remote operation identifier';
    }
    return null;
  }

  SyncEngineSnapshot exportSnapshot() => SyncEngineSnapshot(
        operations: Map<String, SyncOperationState>.unmodifiable(_states),
        receipts: inbox.receipts.toList(growable: false),
        cursors: cursors.values,
        conflicts: conflicts.toList(growable: false),
      );

  void restoreSnapshot(SyncEngineSnapshot snapshot) {
    _states
      ..clear()
      ..addAll(snapshot.operations);
    inbox.clear();
    for (final receipt in snapshot.receipts) {
      inbox.receive(receipt);
    }
    cursors.restore(snapshot.cursors);
    _conflicts.clear();
    for (final conflict in snapshot.conflicts) {
      _conflicts[conflict.operationId] = conflict;
    }
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
