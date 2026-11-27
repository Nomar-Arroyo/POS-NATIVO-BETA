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
    this.operationType,
  });

  final String idempotencyKey;
  final String operationId;
  final String entityId;
  final int remoteVersion;
  final bool accepted;
  final String? operationType;

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'operation_id': operationId,
        'operation_type': operationType,
        'entity_id': entityId,
        'remote_version': remoteVersion,
        'accepted': accepted,
      };

  factory SyncReceipt.fromJson(Map<String, dynamic> json) => SyncReceipt(
        idempotencyKey: json['idempotency_key'] as String,
        operationId: json['operation_id'] as String,
        operationType: json['operation_type'] as String?,
        entityId: json['entity_id'] as String,
        remoteVersion: (json['remote_version'] as num).toInt(),
        accepted: json['accepted'] as bool,
      );
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

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'retryable': retryable,
      };

  factory SyncError.fromJson(Map<String, dynamic> json) => SyncError(
        code: json['code'] as String,
        message: json['message'] as String,
        retryable: json['retryable'] as bool,
      );
}
