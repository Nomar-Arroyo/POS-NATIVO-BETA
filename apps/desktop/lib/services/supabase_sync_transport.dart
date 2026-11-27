import 'dart:async';
import 'dart:convert';

import 'package:core_sync/core_sync.dart';

import 'rpc_invoker.dart';

/// Maps local outbox operations to the backend RPC contracts that are already
/// published and receipt-compatible.
///
/// Only `confirm_sale` qualifies today: its receipt returns the same
/// `entity_id` that the outbox stores. Operations without a matching RPC keep
/// their local state and produce a non-retryable `OPERATION_UNSUPPORTED` error
/// so they are never reported as `SYNCED`.
class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport({
    required this.invoker,
    Map<String, String>? functionByOperation,
  }) : _functionByOperation = Map.unmodifiable(
          functionByOperation ?? defaultFunctionByOperation,
        );

  final RpcInvoker invoker;
  final Map<String, String> _functionByOperation;

  static const defaultFunctionByOperation = {
    'confirm_sale': 'rpc_confirm_sale',
  };

  @override
  Future<SyncTransportResult> send(SyncEnvelope envelope) async {
    final function = _functionByOperation[envelope.operationType];
    if (function == null) {
      return SyncTransportResult(
        error: SyncError(
          code: 'OPERATION_UNSUPPORTED',
          message: 'No hay contrato remoto publicado para '
              '${envelope.operationType}',
          retryable: false,
        ),
      );
    }

    final decodedPayload = _decodePayload(envelope);
    if (decodedPayload is SyncError) {
      return SyncTransportResult(error: decodedPayload);
    }
    final payload = decodedPayload as Map<String, dynamic>;

    try {
      final response = await invoker.invoke(function, payload);
      return _result(envelope, response);
    } on RpcException catch (error) {
      return SyncTransportResult(
        error: SyncError(
          code: error.code,
          message: error.message,
          retryable: error.retryable,
        ),
      );
    } on TimeoutException {
      return SyncTransportResult(
        error: SyncError(
          code: 'NETWORK_TIMEOUT',
          message: 'Tiempo de espera agotado al sincronizar '
              '${envelope.operationType}',
          retryable: true,
        ),
      );
    } catch (error) {
      return SyncTransportResult(
        error: SyncError(
          code: 'REMOTE_UNAVAILABLE',
          message: 'Fallo remoto inesperado: $error',
          retryable: true,
        ),
      );
    }
  }

  Object _decodePayload(SyncEnvelope envelope) {
    final Object? decoded;
    try {
      decoded = jsonDecode(envelope.payloadJson);
    } on FormatException {
      return SyncError(
        code: 'PAYLOAD_INVALID',
        message: 'El payload local de ${envelope.operationType} no es JSON',
        retryable: false,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return SyncError(
        code: 'PAYLOAD_INVALID',
        message: 'El payload local de ${envelope.operationType} no es un objeto',
        retryable: false,
      );
    }
    if (decoded['idempotency_key'] != envelope.idempotencyKey) {
      return SyncError(
        code: 'PAYLOAD_MISMATCH',
        message: 'La clave idempotente del payload no coincide con la outbox',
        retryable: false,
      );
    }
    if (envelope.operationType == 'confirm_sale') {
      final sale = decoded['sale'];
      if (sale is! Map || sale['id'] != envelope.entityId) {
        return SyncError(
          code: 'PAYLOAD_MISMATCH',
          message: 'La venta del payload no coincide con la entidad en outbox',
          retryable: false,
        );
      }
    }
    return decoded;
  }

  SyncTransportResult _result(
    SyncEnvelope envelope,
    Map<String, dynamic> response,
  ) {
    final accepted = response['accepted'];
    if (accepted == true) {
      final receiptResult = _receipt(envelope, response);
      if (receiptResult is SyncError) {
        return SyncTransportResult(error: receiptResult);
      }
      return SyncTransportResult(receipt: receiptResult as SyncReceipt);
    }
    if (accepted == false) {
      final code = response['code'];
      if (code is! String || code.trim().isEmpty) {
        return SyncTransportResult(
          error: const SyncError(
            code: 'CONFLICT_INVALID',
            message: 'El servidor rechazó la operación sin código de conflicto',
            retryable: false,
          ),
        );
      }
      final message = response['message'];
      return SyncTransportResult(
        conflict: SyncConflict(
          operationId: envelope.operationId,
          entityId: envelope.entityId,
          idempotencyKey: envelope.idempotencyKey,
          type: _conflictType(code.trim()),
          message: message is String && message.trim().isNotEmpty
              ? message.trim()
              : 'Conflicto remoto ${code.trim()}',
          localValue: 'base_version=${envelope.baseVersion}',
          remoteValue: code.trim(),
        ),
      );
    }
    return SyncTransportResult(
      error: const SyncError(
        code: 'RECEIPT_INVALID',
        message: 'La respuesta remota no declara accepted',
        retryable: false,
      ),
    );
  }

  Object _receipt(SyncEnvelope envelope, Map<String, dynamic> response) {
    final idempotencyKey = response['idempotency_key'];
    final operationId = response['operation_id'];
    final entityId = response['entity_id'];
    final remoteVersion = response['remote_version'];
    final operationType = response['operation_type'];
    if (idempotencyKey is! String ||
        idempotencyKey.trim().isEmpty ||
        operationId is! String ||
        operationId.trim().isEmpty ||
        entityId is! String ||
        entityId.trim().isEmpty ||
        remoteVersion is! num ||
        remoteVersion.toInt() < 0 ||
        (operationType != null && operationType is! String)) {
      return const SyncError(
        code: 'RECEIPT_INVALID',
        message: 'El recibo remoto no incluye operación, entidad ni versión',
        retryable: false,
      );
    }
    return SyncReceipt(
      idempotencyKey: idempotencyKey,
      operationId: operationId,
      operationType: operationType as String?,
      entityId: entityId,
      remoteVersion: remoteVersion.toInt(),
      accepted: true,
    );
  }

  static ConflictType _conflictType(String code) {
    const types = {
      'INSUFFICIENT_STOCK': ConflictType.stockMismatch,
      'CASH_SESSION_INVALID': ConflictType.closedCashSession,
      'TERMINAL_INVALID': ConflictType.revokedTerminal,
      'PRICE_CHANGED': ConflictType.staleCatalogVersion,
      'TOTAL_MISMATCH': ConflictType.staleCatalogVersion,
      'CURRENCY_MISMATCH': ConflictType.staleCatalogVersion,
      'PAYMENT_CURRENCY_MISMATCH': ConflictType.staleCatalogVersion,
      'ITEM_INVALID': ConflictType.staleCatalogVersion,
      'VARIANT_INVALID': ConflictType.staleCatalogVersion,
      'SCHEMA_VERSION_UNSUPPORTED': ConflictType.staleOperation,
      'STALE_VERSION': ConflictType.staleOperation,
      'VERSION_CONFLICT': ConflictType.staleOperation,
      'EXCHANGE_RATE_INVALID': ConflictType.expiredRate,
      'RATE_EXPIRED': ConflictType.expiredRate,
    };
    return types[code] ?? ConflictType.staleOperation;
  }
}
