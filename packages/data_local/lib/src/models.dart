class LocalSaleItemInput {
  const LocalSaleItemInput({
    required this.variantId,
    required this.quantity,
    required this.unitPriceMinor,
    required this.subtotalMinor,
    this.taxMinor = '0',
  });

  final String variantId;
  final String quantity;
  final String unitPriceMinor;
  final String subtotalMinor;
  final String taxMinor;
}

class LocalInventoryConsumption {
  const LocalInventoryConsumption({
    required this.warehouseId,
    required this.variantId,
    required this.quantity,
    this.reservedQuantity = '0',
  });

  final String warehouseId;
  final String variantId;
  final String quantity;
  final String reservedQuantity;
}

class LocalPaymentInput {
  const LocalPaymentInput({
    required this.method,
    required this.amountMinor,
    required this.currencyCode,
    required this.originalAmountMinor,
    required this.originalCurrencyCode,
    this.exchangeRateSnapshotId,
    this.reference,
  });

  final String method;
  final String amountMinor;
  final String currencyCode;
  final String originalAmountMinor;
  final String originalCurrencyCode;
  final String? exchangeRateSnapshotId;
  final String? reference;
}

class LocalSaleInput {
  const LocalSaleInput({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.terminalId,
    required this.profileId,
    required this.idempotencyKey,
    required this.saleNumber,
    required this.totalCurrency,
    required this.totalMinor,
    required this.items,
    required this.payments,
    required this.inventoryConsumptions,
    this.cashSessionId,
    this.diningSessionId,
    this.exchangeRateSnapshotId,
    this.betaOriginId,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String terminalId;
  final String profileId;
  final String? cashSessionId;
  final String? diningSessionId;
  final String idempotencyKey;
  final String saleNumber;
  final String totalCurrency;
  final String totalMinor;
  final String? exchangeRateSnapshotId;
  final String? betaOriginId;
  final List<LocalSaleItemInput> items;
  final List<LocalPaymentInput> payments;
  final List<LocalInventoryConsumption> inventoryConsumptions;
}

class LocalSaleConflictException implements Exception {
  const LocalSaleConflictException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'LocalSaleConflictException($code): $message';
}

class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entityId,
    required this.idempotencyKey,
    required this.operationType,
    required this.baseVersion,
    required this.status,
    required this.attemptCount,
    required this.payloadJson,
  });

  final String id;
  final String entityId;
  final String idempotencyKey;
  final String operationType;
  final int baseVersion;
  final String status;
  final int attemptCount;
  final String payloadJson;
}

class LocalWorkspace {
  const LocalWorkspace({
    required this.organizationId,
    required this.organizationName,
    required this.branchId,
    required this.branchName,
    required this.terminalId,
    required this.terminalName,
    required this.profileId,
    required this.profileName,
    required this.warehouseId,
    required this.warehouseName,
    required this.cashRegisterId,
    required this.cashRegisterName,
  });

  final String organizationId;
  final String organizationName;
  final String branchId;
  final String branchName;
  final String terminalId;
  final String terminalName;
  final String profileId;
  final String profileName;
  final String warehouseId;
  final String warehouseName;
  final String cashRegisterId;
  final String cashRegisterName;
}

class LocalCatalogProduct {
  const LocalCatalogProduct({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.categoryName,
    required this.sku,
    required this.priceMinor,
    required this.availableQuantity,
    required this.currencyCode,
    required this.fulfillmentStation,
    required this.isSynthetic,
  });

  final String productId;
  final String variantId;
  final String name;
  final String categoryName;
  final String? sku;
  final String priceMinor;
  final String? availableQuantity;
  final String currencyCode;
  final String fulfillmentStation;
  final bool isSynthetic;
}

class LocalCashSession {
  const LocalCashSession({
    required this.id,
    required this.cashRegisterId,
    required this.profileId,
    required this.status,
    required this.openingMinor,
    required this.openedAt,
    this.closedAt,
    this.closingMinor,
    this.expectedUsdMinor,
    this.differenceUsdMinor,
  });

  final String id;
  final String cashRegisterId;
  final String profileId;
  final String status;
  final String openingMinor;
  final String openedAt;
  final String? closedAt;
  final String? closingMinor;
  final String? expectedUsdMinor;
  final String? differenceUsdMinor;
}

class LocalSaleSummary {
  const LocalSaleSummary({
    required this.id,
    required this.saleNumber,
    required this.totalCurrency,
    required this.totalMinor,
    required this.syncStatus,
    required this.createdAt,
  });

  final String id;
  final String saleNumber;
  final String totalCurrency;
  final String totalMinor;
  final String syncStatus;
  final String createdAt;
}

class LocalWorkspaceInput {
  const LocalWorkspaceInput({
    required this.organizationId,
    required this.organizationName,
    required this.branchId,
    required this.branchName,
    required this.terminalId,
    required this.terminalName,
    required this.profileId,
    required this.profileName,
    required this.warehouseId,
    required this.warehouseName,
    required this.cashRegisterId,
    required this.cashRegisterName,
    required this.profilePin,
  });

  final String organizationId;
  final String organizationName;
  final String branchId;
  final String branchName;
  final String terminalId;
  final String terminalName;
  final String profileId;
  final String profileName;
  final String warehouseId;
  final String warehouseName;
  final String cashRegisterId;
  final String cashRegisterName;
  final String profilePin;
}

class LocalProfile {
  const LocalProfile({
    required this.id,
    required this.displayName,
    required this.roleCode,
    required this.roleName,
    required this.hasPin,
  });

  final String id;
  final String displayName;
  final String roleCode;
  final String roleName;
  final bool hasPin;
}

class LocalProductInput {
  const LocalProductInput({
    required this.productId,
    required this.variantId,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.sku,
    required this.priceMinor,
    required this.initialStock,
    required this.offlineSellable,
    this.fulfillmentStation = 'UNASSIGNED',
    this.isSynthetic = false,
  });

  final String productId;
  final String variantId;
  final String categoryId;
  final String categoryName;
  final String name;
  final String? sku;
  final String priceMinor;
  final String initialStock;
  final bool offlineSellable;
  final String fulfillmentStation;
  final bool isSynthetic;
}

class LocalDiningTable {
  const LocalDiningTable({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    this.openSessionId,
  });

  final String id;
  final String name;
  final int capacity;
  final String status;
  final String? openSessionId;
}

class LocalDiningItem {
  const LocalDiningItem({
    required this.id,
    required this.variantId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.currencyCode,
    required this.station,
    required this.status,
    required this.createdAt,
    this.notes,
    this.sentAt,
  });

  final String id;
  final String variantId;
  final String productName;
  final String quantity;
  final String unitPriceMinor;
  final String currencyCode;
  final String station;
  final String status;
  final String createdAt;
  final String? notes;
  final String? sentAt;

  String get subtotalMinor =>
      (BigInt.parse(quantity) * BigInt.parse(unitPriceMinor)).toString();
}

class LocalDiningSession {
  const LocalDiningSession({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.status,
    required this.openedAt,
    required this.items,
  });

  final String id;
  final String tableId;
  final String tableName;
  final String status;
  final String openedAt;
  final List<LocalDiningItem> items;

  List<LocalDiningItem> get activeItems =>
      items.where((item) => item.status != 'CANCELLED').toList(growable: false);

  String get totalUsdMinor => activeItems
      .fold(
        BigInt.zero,
        (total, item) => total + BigInt.parse(item.subtotalMinor),
      )
      .toString();
}

class LocalProductionOrder {
  const LocalProductionOrder({
    required this.id,
    required this.orderNumber,
    required this.tableName,
    required this.station,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String orderNumber;
  final String tableName;
  final String station;
  final String status;
  final String createdAt;
  final List<LocalDiningItem> items;
}

class LocalPrecuenta {
  const LocalPrecuenta({
    required this.id,
    required this.tableName,
    required this.generatedAt,
    required this.items,
    required this.totalUsdMinor,
  });

  final String id;
  final String tableName;
  final String generatedAt;
  final List<LocalDiningItem> items;
  final String totalUsdMinor;
}
