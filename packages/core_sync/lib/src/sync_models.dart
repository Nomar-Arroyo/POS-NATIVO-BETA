enum SyncStatus {
  local,
  pending,
  synced,
  error,
  conflict,
}

class SyncEnvelope {
  const SyncEnvelope({
    required this.operationId,
    required this.idempotencyKey,
    required this.operationType,
    required this.entityId,
    required this.organizationId,
    required this.terminalId,
    required this.baseVersion,
    required this.payloadJson,
  });

  final String operationId;
  final String idempotencyKey;
  final String operationType;
  final String entityId;
  final String organizationId;
  final String terminalId;
  final int baseVersion;
  final String payloadJson;
}

class SyncReceipt {
  const SyncReceipt({
    required this.idempotencyKey,
    required this.operationId,
    required this.entityId,
    required this.remoteVersion,
    required this.accepted,
  });

  final String idempotencyKey;
  final String operationId;
  final String entityId;
  final int remoteVersion;
  final bool accepted;
}

class SyncError {
  const SyncError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String message;
  final bool retryable;
}
