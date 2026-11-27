import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

class LocalOutbox {
  LocalOutbox(this.database);

  final Database database;

  List<OutboxEntry> pending({int limit = 100}) {
    final rows = database.select(
      'SELECT id, entity_id, idempotency_key, operation_type, base_version, '
      'sync_status, attempt_count, payload_json '
      'FROM sync_outbox '
      'WHERE sync_status = ? '
      'OR (sync_status = ? AND next_attempt_at IS NOT NULL '
      'AND next_attempt_at <= ?) '
      'ORDER BY created_at ASC LIMIT ?',
      ['PENDING', 'ERROR', DateTime.now().toUtc().toIso8601String(), limit],
    );
    return rows
        .map(
          (row) => OutboxEntry(
            id: row['id'] as String,
            entityId: row['entity_id'] as String,
            idempotencyKey: row['idempotency_key'] as String,
            operationType: row['operation_type'] as String,
            baseVersion: row['base_version'] as int,
            status: row['sync_status'] as String,
            attemptCount: row['attempt_count'] as int,
            payloadJson: row['payload_json'] as String,
          ),
        )
        .toList(growable: false);
  }

  void recordError({
    required String outboxId,
    required String organizationId,
    required String terminalId,
    required String operationType,
    required String code,
    required String message,
    bool retryable = true,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final attemptRows = database.select(
      'SELECT attempt_count FROM sync_outbox WHERE id = ?',
      [outboxId],
    );
    final attemptCount = attemptRows.isEmpty
        ? 1
        : (attemptRows.first['attempt_count'] as int) + 1;
    database.execute(
      'UPDATE sync_outbox SET sync_status = ?, attempt_count = attempt_count + 1, '
      'next_attempt_at = ?, last_error_code = ?, last_error_message = ?, '
      'updated_at = ? WHERE id = ?',
      [
        'ERROR',
        retryable ? _nextAttemptAt(attemptCount).toIso8601String() : null,
        code,
        message,
        now,
        outboxId
      ],
    );
    _insertError(
      outboxId: outboxId,
      organizationId: organizationId,
      terminalId: terminalId,
      operationType: operationType,
      code: code,
      message: message,
      now: now,
    );
  }

  void markConflict({
    required String outboxId,
    required String organizationId,
    required String terminalId,
    required String operationType,
    required String code,
    required String message,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute(
      'UPDATE sync_outbox SET sync_status = ?, attempt_count = attempt_count + 1, '
      'next_attempt_at = NULL, last_error_code = ?, last_error_message = ?, '
      'updated_at = ? WHERE id = ?',
      ['CONFLICT', code, message, now, outboxId],
    );
    _insertError(
      outboxId: outboxId,
      organizationId: organizationId,
      terminalId: terminalId,
      operationType: operationType,
      code: code,
      message: message,
      now: now,
    );
  }

  void _insertError({
    required String outboxId,
    required String organizationId,
    required String terminalId,
    required String operationType,
    required String code,
    required String message,
    required String now,
  }) {
    database.execute(
      'INSERT INTO sync_errors(id, outbox_id, organization_id, terminal_id, '
      'operation_type, error_code, error_message, occurred_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'sync-error-${DateTime.now().microsecondsSinceEpoch}',
        outboxId,
        organizationId,
        terminalId,
        operationType,
        code,
        message,
        now,
      ],
    );
  }

  bool markSynced({
    required String outboxId,
    required String idempotencyKey,
    required String entityId,
    required String operationType,
    required String organizationId,
    required String terminalId,
    int? remoteVersion,
  }) {
    final row = database.select(
      'SELECT entity_id, operation_type, idempotency_key, sync_status '
      'FROM sync_outbox WHERE id = ?',
      [outboxId],
    );
    if (row.isEmpty) return false;
    if (row.first['idempotency_key'] != idempotencyKey ||
        row.first['entity_id'] != entityId ||
        row.first['operation_type'] != operationType) {
      throw StateError(
        'Receipt does not correlate with the outbox operation',
      );
    }
    if (row.first['sync_status'] == 'CONFLICT') {
      throw StateError(
        'A conflicted operation requires reconciliation before it can sync',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute(
      'UPDATE sync_outbox SET sync_status = ?, last_error_code = NULL, '
      'last_error_message = NULL, updated_at = ? WHERE id = ?',
      ['SYNCED', now, outboxId],
    );
    if (operationType == 'confirm_sale') {
      database.execute(
        'UPDATE sales SET sync_status = ?, updated_at = ? WHERE id = ?',
        ['SYNCED', now, entityId],
      );
    }
    database.execute(
      'INSERT OR IGNORE INTO sync_receipts(id, organization_id, terminal_id, '
      'idempotency_key, operation_type, entity_id, result_status, '
      'remote_version, received_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'receipt-$idempotencyKey',
        organizationId,
        terminalId,
        idempotencyKey,
        operationType,
        entityId,
        'accepted',
        remoteVersion,
        now,
      ],
    );
    return true;
  }

  void setCursor({
    required String organizationId,
    required String terminalId,
    required String stream,
    required String cursor,
  }) {
    database.execute(
      'INSERT INTO sync_cursors(id, organization_id, terminal_id, stream, cursor, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(terminal_id, stream) DO UPDATE SET '
      'cursor = excluded.cursor, updated_at = excluded.updated_at',
      [
        'cursor-$terminalId-$stream',
        organizationId,
        terminalId,
        stream,
        cursor,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  String? getCursor({
    required String terminalId,
    required String stream,
  }) {
    final rows = database.select(
      'SELECT cursor FROM sync_cursors WHERE terminal_id = ? AND stream = ?',
      [terminalId, stream],
    );
    return rows.isEmpty ? null : rows.first['cursor'] as String?;
  }

  DateTime _nextAttemptAt(int attemptCount) {
    final seconds = (1 << attemptCount).clamp(2, 300);
    return DateTime.now().toUtc().add(Duration(seconds: seconds));
  }
}
