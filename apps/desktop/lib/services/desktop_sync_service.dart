import 'dart:convert';
import 'dart:io';

import 'package:core_sync/core_sync.dart';
import 'package:data_local/data_local.dart';

class SyncRunSummary {
  const SyncRunSummary({
    required this.processed,
    required this.synced,
    required this.conflicts,
    required this.errors,
    required this.unsupported,
    required this.skipped,
    this.warning,
  });

  const SyncRunSummary.empty()
      : processed = 0,
        synced = 0,
        conflicts = 0,
        errors = 0,
        unsupported = 0,
        skipped = 0,
        warning = null;

  final int processed;
  final int synced;
  final int conflicts;
  final int errors;
  final int unsupported;
  final int skipped;
  final String? warning;

  bool get didProcess => processed > 0;
  bool get hasFailures => conflicts > 0 || errors > 0 || unsupported > 0;

  @override
  String toString() =>
      'SyncRunSummary(processed: $processed, synced: $synced, '
      'conflicts: $conflicts, errors: $errors, unsupported: $unsupported, '
      'skipped: $skipped${warning == null ? '' : ', warning: $warning'})';
}

/// Orchestrates the local outbox against a [SyncTransport].
///
/// `SYNCED` is only written after the engine accepted a receipt that matches
/// the operation, entity and idempotency key. Commercial conflicts stay in the
/// outbox as `CONFLICT`; permanent failures stay as `ERROR` without a retry
/// date until an operator reconciles them. The engine state (receipts,
/// cursors, conflicts and retry schedule) is persisted atomically so a restart
/// cannot silently resend or lose an operation.
class DesktopSyncService {
  DesktopSyncService({
    required this.database,
    required this.transport,
    required String snapshotPath,
    SyncEngine? engine,
  })  : _snapshotFile = File(snapshotPath),
        engine = engine ?? SyncEngine();

  final LocalDatabase database;
  final SyncTransport transport;
  final SyncEngine engine;
  final File _snapshotFile;

  Future<SyncRunSummary>? _activeRun;
  String? _restoreWarning;

  String? get restoreWarning => _restoreWarning;

  static Future<DesktopSyncService> open({
    required LocalDatabase database,
    required SyncTransport transport,
    required String snapshotPath,
    SyncEngine? engine,
  }) async {
    final service = DesktopSyncService(
      database: database,
      transport: transport,
      snapshotPath: snapshotPath,
      engine: engine,
    );
    await service._restore();
    return service;
  }

  /// Processes the outbox in creation order. Concurrent calls share the same
  /// in-flight run so two timers cannot mark the same operation twice.
  Future<SyncRunSummary> synchronize({int limit = 100}) {
    final active = _activeRun;
    if (active != null) return active;
    final run = _run(limit).whenComplete(() => _activeRun = null);
    _activeRun = run;
    return run;
  }

  Future<SyncRunSummary> _run(int limit) async {
    final workspace = database.localWorkspace;
    if (workspace == null) {
      return const SyncRunSummary.empty();
    }
    final entries = database.outbox.pending(limit: limit);
    var processed = 0;
    var synced = 0;
    var conflicts = 0;
    var errors = 0;
    var unsupported = 0;
    var skipped = 0;

    for (final entry in entries) {
      final envelope = SyncEnvelope(
        operationId: entry.id,
        idempotencyKey: entry.idempotencyKey,
        operationType: entry.operationType,
        entityId: entry.entityId,
        organizationId: workspace.organizationId,
        terminalId: workspace.terminalId,
        baseVersion: entry.baseVersion,
        payloadJson: entry.payloadJson,
      );
      final state = await engine.synchronize(
        envelope: envelope,
        transport: transport,
      );
      processed++;
      switch (state.status) {
        case SyncStatus.synced:
          final receipt =
              engine.inbox.findByIdempotencyKey(entry.idempotencyKey);
          if (receipt == null) {
            _recordError(
              entry: entry,
              workspace: workspace,
              code: 'RECEIPT_MISSING',
              message: 'El motor aceptó la operación sin guardar el recibo',
            );
            errors++;
          } else {
            try {
              database.outbox.markSynced(
                outboxId: entry.id,
                idempotencyKey: receipt.idempotencyKey,
                entityId: receipt.entityId,
                operationType: receipt.operationType ?? entry.operationType,
                organizationId: workspace.organizationId,
                terminalId: workspace.terminalId,
                remoteVersion: receipt.remoteVersion,
              );
              synced++;
            } on StateError catch (error) {
              _recordError(
                entry: entry,
                workspace: workspace,
                code: 'RECEIPT_MISMATCH',
                message: error.message,
              );
              errors++;
            }
          }
        case SyncStatus.conflict:
          final conflict = _conflictFor(entry.id);
          database.outbox.markConflict(
            outboxId: entry.id,
            organizationId: workspace.organizationId,
            terminalId: workspace.terminalId,
            operationType: entry.operationType,
            code: conflict?.remoteValue.isNotEmpty == true
                ? conflict!.remoteValue
                : 'COMMERCIAL_CONFLICT',
            message: conflict?.message ??
                'El servidor rechazó la operación; requiere conciliación',
          );
          conflicts++;
        case SyncStatus.error:
          final error = state.error ??
              const SyncError(
                code: 'UNKNOWN_SYNC_ERROR',
                message: 'El motor no devolvió detalle del fallo',
                retryable: false,
              );
          _recordError(
            entry: entry,
            workspace: workspace,
            code: error.code,
            message: error.message,
            retryable: error.retryable,
          );
          if (error.code == 'OPERATION_UNSUPPORTED') {
            unsupported++;
          } else {
            errors++;
          }
        case SyncStatus.pending:
        case SyncStatus.local:
          skipped++;
      }
      await _persistSnapshot();
    }

    return SyncRunSummary(
      processed: processed,
      synced: synced,
      conflicts: conflicts,
      errors: errors,
      unsupported: unsupported,
      skipped: skipped,
      warning: _restoreWarning,
    );
  }

  void _recordError({
    required OutboxEntry entry,
    required LocalWorkspace workspace,
    required String code,
    required String message,
    bool retryable = false,
  }) {
    database.outbox.recordError(
      outboxId: entry.id,
      organizationId: workspace.organizationId,
      terminalId: workspace.terminalId,
      operationType: entry.operationType,
      code: code,
      message: message,
      retryable: retryable,
    );
  }

  SyncConflict? _conflictFor(String operationId) {
    for (final conflict in engine.conflicts) {
      if (conflict.operationId == operationId) return conflict;
    }
    return null;
  }

  Future<void> _restore() async {
    if (!await _snapshotFile.exists()) return;
    try {
      final decoded = jsonDecode(await _snapshotFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('El estado de sincronización no es objeto');
      }
      engine.restoreSnapshot(SyncEngineSnapshot.fromJson(decoded));
    } on FormatException catch (error) {
      await _quarantineSnapshot(error.message);
    } on TypeError catch (error) {
      await _quarantineSnapshot(error.toString());
    }
  }

  Future<void> _quarantineSnapshot(String reason) async {
    final suffix = DateTime.now().toUtc().millisecondsSinceEpoch;
    final aside = '${_snapshotFile.path}.corrupt-$suffix';
    try {
      await _snapshotFile.rename(aside);
      _restoreWarning =
          'El estado de sincronización era ilegible ($reason); '
          'se conservó en $aside y se reinició el motor';
    } on FileSystemException catch (error) {
      _restoreWarning =
          'El estado de sincronización era ilegible ($reason) y no se pudo '
          'mover a un lado: ${error.message}';
    }
  }

  Future<void> _persistSnapshot() async {
    final encoded = jsonEncode(engine.exportSnapshot().toJson());
    await _snapshotFile.parent.create(recursive: true);
    final temporary = File('${_snapshotFile.path}.tmp');
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(_snapshotFile.path);
  }
}
