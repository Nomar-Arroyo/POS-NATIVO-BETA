import 'sync_models.dart';

class SyncInbox {
  final Map<String, SyncReceipt> _receipts = {};

  Iterable<SyncReceipt> get receipts =>
      List<SyncReceipt>.unmodifiable(_receipts.values);

  SyncReceipt? findByIdempotencyKey(String idempotencyKey) =>
      _receipts[idempotencyKey];

  SyncReceipt receive(SyncReceipt receipt) {
    final existing = _receipts[receipt.idempotencyKey];
    if (existing != null) return existing;
    _receipts[receipt.idempotencyKey] = receipt;
    return receipt;
  }

  bool contains(String idempotencyKey) => _receipts.containsKey(idempotencyKey);

  void clear() => _receipts.clear();
}
