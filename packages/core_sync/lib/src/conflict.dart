enum ConflictType {
  stockMismatch,
  closedCashSession,
  revokedTerminal,
  staleCatalogVersion,
  staleOperation,
  expiredRate,
  duplicateConflict,
}

class SyncConflict {
  const SyncConflict({
    required this.operationId,
    required this.entityId,
    required this.idempotencyKey,
    required this.type,
    required this.message,
    required this.localValue,
    required this.remoteValue,
  });

  final String operationId;
  final String entityId;
  final String idempotencyKey;
  final ConflictType type;
  final String message;
  final String localValue;
  final String remoteValue;

  Map<String, dynamic> toJson() => {
        'operation_id': operationId,
        'entity_id': entityId,
        'idempotency_key': idempotencyKey,
        'type': type.name,
        'message': message,
        'local_value': localValue,
        'remote_value': remoteValue,
      };

  factory SyncConflict.fromJson(Map<String, dynamic> json) => SyncConflict(
        operationId: json['operation_id'] as String,
        entityId: json['entity_id'] as String,
        idempotencyKey: json['idempotency_key'] as String,
        type: ConflictType.values.byName(json['type'] as String),
        message: json['message'] as String,
        localValue: json['local_value'] as String,
        remoteValue: json['remote_value'] as String,
      );
}
