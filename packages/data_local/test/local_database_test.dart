import 'dart:convert';
import 'dart:io';

import 'package:data_local/data_local.dart';
import 'package:test/test.dart';

const organizationId = 'organization-test';
const branchId = 'branch-test';
const terminalId = 'terminal-test';
const profileId = 'profile-test';
const warehouseId = 'warehouse-test';
const variantId = 'variant-test';

Future<LocalDatabase> seededDatabase() async {
  final database = await LocalDatabase.openInMemory();
  database.createLocalWorkspace(
    const LocalWorkspaceInput(
      organizationId: organizationId,
      organizationName: 'Test Organization',
      branchId: branchId,
      branchName: 'Test Branch',
      terminalId: terminalId,
      terminalName: 'Terminal 1',
      profileId: profileId,
      profileName: 'Administrator',
      profilePin: '1234',
      warehouseId: warehouseId,
      warehouseName: 'Main Warehouse',
      cashRegisterId: 'seeded-register',
      cashRegisterName: 'Register 1',
    ),
  );
  signIn(database);
  database.database.execute(
    'INSERT INTO cash_sessions(id, organization_id, cash_register_id, '
    'terminal_id, profile_id, opening_minor, status, opened_at, idempotency_key) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      'seeded-cash-session',
      organizationId,
      'seeded-register',
      terminalId,
      profileId,
      '{"USD":"0"}',
      'open',
      DateTime.now().toUtc().toIso8601String(),
      'seeded-open-cash',
    ],
  );
  database.seedVariant(
    organizationId: organizationId,
    variantId: variantId,
  );
  // Reset setup side effects so each test asserts only its own transaction.
  database.database.execute(
    "DELETE FROM sync_outbox WHERE operation_type = 'configure_local_workspace'",
  );
  database.database.execute(
    "DELETE FROM audit_logs WHERE action IN "
    "('LOCAL_WORKSPACE_CONFIGURED', 'LOCAL_PROFILE_SESSION_STARTED')",
  );
  return database;
}

String signIn(LocalDatabase database) {
  final sessionId = database.authenticateLocalProfile(
    profileId: profileId,
    pin: '1234',
  );
  expect(sessionId, isNotNull, reason: 'The test profile must authenticate');
  return sessionId!;
}

LocalSaleInput sale({
  required String id,
  required String idempotencyKey,
  required String consumptionQuantity,
  String? saleTerminalId,
  String? cashSessionId = 'seeded-cash-session',
}) =>
    LocalSaleInput(
      id: id,
      organizationId: organizationId,
      branchId: branchId,
      terminalId: saleTerminalId ?? terminalId,
      profileId: profileId,
      cashSessionId: cashSessionId,
      idempotencyKey: idempotencyKey,
      saleNumber: 'TEST-001',
      totalCurrency: 'USD',
      totalMinor: '1000',
      items: const [
        LocalSaleItemInput(
          variantId: variantId,
          quantity: '1',
          unitPriceMinor: '1000',
          subtotalMinor: '1000',
        ),
      ],
      payments: const [
        LocalPaymentInput(
          method: 'EFECTIVO USD',
          amountMinor: '1000',
          currencyCode: 'USD',
          originalAmountMinor: '1000',
          originalCurrencyCode: 'USD',
        ),
      ],
      inventoryConsumptions: [
        LocalInventoryConsumption(
          warehouseId: warehouseId,
          variantId: variantId,
          quantity: consumptionQuantity,
        ),
      ],
    );

void main() {
  group('SQLite migrations', () {
    test('applies migration once and enables foreign keys', () async {
      final database = await LocalDatabase.openInMemory();
      expect(database.migrationCount, 6);
      expect(database.userVersion, 6);
      final foreignKeys = database.database
          .select('PRAGMA foreign_keys')
          .first
          .values
          .first as int;
      expect(foreignKeys, 1);
      database.close();
    });

    test('reopens a file database and preserves migration state', () async {
      final directory =
          await Directory.systemTemp.createTemp('data-local-test');
      final path = '${directory.path}/amalfi.db';
      addTearDown(() => directory.delete(recursive: true));

      final first = await LocalDatabase.open(path);
      expect(first.migrationCount, 6);
      first.close();

      final reopened = await LocalDatabase.open(path);
      expect(reopened.migrationCount, 6);
      expect(reopened.userVersion, 6);
      reopened.close();
    });
  });

  group('local profiles and demo isolation', () {
    test('hashes PINs and enforces a cashier role', () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Administrator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'profile-register',
          cashRegisterName: 'Register 1',
        ),
      );

      signIn(database);
      final credential = database.database
          .select('SELECT pin_salt, pin_hash FROM profiles WHERE id = ?', [
        profileId,
      ]).single;
      expect(credential['pin_salt'], isNotNull);
      expect(credential['pin_hash'], isNot('1234'));
      expect(
        database.authenticateLocalProfile(profileId: profileId, pin: '9999'),
        isNull,
      );

      final cashierId = database.createLocalProfile(
        displayName: 'Cajero',
        roleCode: 'cashier',
        pin: '5678',
      );
      final sessionId = database.authenticateLocalProfile(
        profileId: cashierId,
        pin: '5678',
      );
      expect(sessionId, isNotNull);
      expect(database.localWorkspace?.profileId, cashierId);
      expect(database.hasPermission('sales.create'), isTrue);
      expect(database.hasPermission('settings.manage'), isFalse);
      expect(
        () => database.setStationDisplayEnabled('KITCHEN', false),
        throwsStateError,
      );

      database.endLocalProfileSession(sessionId!);
    });

    test('allows simulated sales only in the isolated demo database', () async {
      final demo = await LocalDatabase.openDemoInMemory();
      addTearDown(demo.close);
      demo.initializeDemoWorkspace();
      final workspace = demo.localWorkspace!;
      final product = demo.getCatalogProducts().first;
      final cash = demo.openLocalCashSession(
        sessionId: 'isolated-demo-cash-session',
        openingUsdMinor: '0',
      );
      final price = product.priceMinor;

      final saleId = demo.confirmSale(
        LocalSaleInput(
          id: 'isolated-demo-sale',
          organizationId: workspace.organizationId,
          branchId: workspace.branchId,
          terminalId: workspace.terminalId,
          profileId: workspace.profileId,
          cashSessionId: cash.id,
          idempotencyKey: 'isolated-demo-sale',
          saleNumber: 'DEMO-001',
          totalCurrency: product.currencyCode,
          totalMinor: price,
          items: [
            LocalSaleItemInput(
              variantId: product.variantId,
              quantity: '1',
              unitPriceMinor: price,
              subtotalMinor: price,
            ),
          ],
          payments: [
            LocalPaymentInput(
              method: 'CASH_USD',
              amountMinor: price,
              currencyCode: product.currencyCode,
              originalAmountMinor: price,
              originalCurrencyCode: product.currencyCode,
            ),
          ],
          inventoryConsumptions: [
            LocalInventoryConsumption(
              warehouseId: workspace.warehouseId,
              variantId: product.variantId,
              quantity: '1',
            ),
          ],
        ),
      );

      expect(saleId, 'isolated-demo-sale');
      expect(demo.tableCount('sales'), 1);
      expect(
        demo.outbox.pending().any(
              (entry) => entry.operationType == 'configure_local_workspace',
            ),
        isFalse,
      );

      final real = await LocalDatabase.openInMemory();
      addTearDown(real.close);
      expect(real.isDemoMode, isFalse);
      expect(real.localWorkspace, isNull);
    });
  });

  group('local workspace and operations', () {
    test('loads clearly marked demo products without making them syncable',
        () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      final workspace = database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'demo-cash-register',
          cashRegisterName: 'Register 1',
        ),
      );

      signIn(database);
      expect(database.loadSyntheticDemoCatalog(), 18);
      expect(database.loadSyntheticDemoCatalog(), 0);
      final products = database.getCatalogProducts(offlineOnly: false);
      expect(products, hasLength(18));
      expect(products.every((product) => product.isSynthetic), isTrue);
      expect(
        database.outbox.pending().where(
              (entry) => entry.operationType == 'create_local_product',
            ),
        isEmpty,
      );
      final table =
          database.createDiningTable(name: 'Mesa de prueba', capacity: 2);
      final diningSession = database.openDiningSession(table.id);
      final pendingBeforeDemoOrder = database.outbox.pending().length;
      expect(
        () => database.addDiningItem(
          sessionId: diningSession.id,
          variantId: 'synthetic-demo-variant-americano',
          quantity: '1',
        ),
        throwsStateError,
      );
      expect(
        database.database
            .select('SELECT COUNT(*) AS count FROM dining_session_items')
            .single['count'],
        0,
      );
      expect(database.outbox.pending(), hasLength(pendingBeforeDemoOrder));

      final cash = database.openLocalCashSession(
        sessionId: 'demo-cash-session',
        openingUsdMinor: '0',
      );
      expect(
        () => database.confirmSale(
          LocalSaleInput(
            id: 'demo-sale',
            organizationId: workspace.organizationId,
            branchId: workspace.branchId,
            terminalId: workspace.terminalId,
            profileId: workspace.profileId,
            cashSessionId: cash.id,
            idempotencyKey: 'demo-sale',
            saleNumber: 'DEMO-001',
            totalCurrency: 'USD',
            totalMinor: '250',
            items: const [
              LocalSaleItemInput(
                variantId: 'synthetic-demo-variant-americano',
                quantity: '1',
                unitPriceMinor: '250',
                subtotalMinor: '250',
              ),
            ],
            payments: const [
              LocalPaymentInput(
                method: 'CASH_USD',
                amountMinor: '250',
                currencyCode: 'USD',
                originalAmountMinor: '250',
                originalCurrencyCode: 'USD',
              ),
            ],
            inventoryConsumptions: const [
              LocalInventoryConsumption(
                warehouseId: warehouseId,
                variantId: 'synthetic-demo-variant-americano',
                quantity: '1',
              ),
            ],
          ),
        ),
        throwsA(
          isA<LocalSaleConflictException>().having(
            (error) => error.code,
            'code',
            'SYNTHETIC_PRODUCT_NOT_SYNCABLE',
          ),
        ),
      );
      expect(database.tableCount('sales'), 0);
    });

    test('stock adjustment is audited and cannot consume reserved inventory',
        () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'adjustment-register',
          cashRegisterName: 'Register 1',
        ),
      );
      signIn(database);
      database.createLocalProduct(
        const LocalProductInput(
          productId: 'adjustment-product',
          variantId: 'adjustment-variant',
          categoryId: 'adjustment-category',
          categoryName: 'Beverages',
          name: 'Tea',
          sku: 'TEA-1',
          priceMinor: '250',
          initialStock: '3',
          offlineSellable: true,
          fulfillmentStation: 'BAR',
        ),
      );
      expect(
        database.adjustLocalInventory(
          variantId: 'adjustment-variant',
          quantityDelta: '2',
          reason: 'Stock count correction',
        ),
        '5',
      );
      final table = database.createDiningTable(name: 'Table 1', capacity: 2);
      final session = database.openDiningSession(table.id);
      final diningItem = database.addDiningItem(
        sessionId: session.id,
        variantId: 'adjustment-variant',
        quantity: '1',
      );
      final pendingBeforeRejectedAdjustment = database.outbox.pending().length;
      expect(
        () => database.adjustLocalInventory(
          variantId: 'adjustment-variant',
          quantityDelta: '-5',
          reason: 'Invalid reduction below reservation',
        ),
        throwsStateError,
      );
      expect(
        database.inventoryQuantity(
          warehouseId: warehouseId,
          variantId: 'adjustment-variant',
        ),
        '5',
      );
      expect(database.tableCount('inventory_movements'), 2);
      expect(
        database.outbox.pending(),
        hasLength(pendingBeforeRejectedAdjustment),
      );

      database.removeUnsentDiningItem(diningItem.id);
      expect(
        database.adjustLocalInventory(
          variantId: 'adjustment-variant',
          quantityDelta: '-5',
          reason: 'Remove counted stock',
        ),
        '0',
      );
      expect(database.tableCount('inventory_movements'), 3);
      expect(
        database.outbox.pending().where(
              (entry) => entry.operationType == 'adjust_inventory',
            ),
        hasLength(2),
      );
    });

    test('configures workspace, creates inventory and records a cash sale',
        () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      final workspace = database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'cash-register-test',
          cashRegisterName: 'Register 1',
        ),
      );
      signIn(database);
      expect(database.localWorkspace?.terminalId, terminalId);

      database.createLocalProduct(
        const LocalProductInput(
          productId: 'product-test',
          variantId: variantId,
          categoryId: 'category-test',
          categoryName: 'Coffee',
          name: 'Espresso',
          sku: 'ESP-001',
          priceMinor: '450',
          initialStock: '3',
          offlineSellable: true,
        ),
      );
      final catalog = database.getCatalogProducts();
      expect(catalog, hasLength(1));
      expect(catalog.single.availableQuantity, '3');
      expect(catalog.single.currencyCode, 'USD');

      final session = database.openLocalCashSession(
        sessionId: 'cash-session-test',
        openingUsdMinor: '1000',
      );
      database.recordLocalCashMovement(
        sessionId: session.id,
        type: 'income',
        amountUsdMinor: '300',
        reason: 'Cambio inicial',
      );
      database.recordLocalCashMovement(
        sessionId: session.id,
        type: 'expense',
        amountUsdMinor: '100',
        reason: 'Compra urgente',
      );
      database.confirmSale(
        LocalSaleInput(
          id: 'local-sale-test',
          organizationId: workspace.organizationId,
          branchId: workspace.branchId,
          terminalId: workspace.terminalId,
          profileId: workspace.profileId,
          cashSessionId: session.id,
          idempotencyKey: 'local-sale-test',
          saleNumber: 'L-001',
          totalCurrency: 'USD',
          totalMinor: '450',
          items: const [
            LocalSaleItemInput(
              variantId: variantId,
              quantity: '1',
              unitPriceMinor: '450',
              subtotalMinor: '450',
            ),
          ],
          payments: const [
            LocalPaymentInput(
              method: 'CASH_USD',
              amountMinor: '450',
              currencyCode: 'USD',
              originalAmountMinor: '450',
              originalCurrencyCode: 'USD',
            ),
          ],
          inventoryConsumptions: const [
            LocalInventoryConsumption(
              warehouseId: warehouseId,
              variantId: variantId,
              quantity: '1',
            ),
          ],
        ),
      );

      expect(database.cashExpectedUsdMinor(session.id), '1650');
      expect(
        database.inventoryQuantity(
          warehouseId: warehouseId,
          variantId: variantId,
        ),
        '2',
      );
      expect(database.recentSales().single.saleNumber, 'L-001');
      expect(database.tableCount('cash_movements'), 4);
      final closed = database.closeLocalCashSession(
        sessionId: session.id,
        closingUsdMinor: '1650',
      );
      expect(closed.status, 'closed');
      expect(database.activeCashSession, isNull);
      expect(database.tableCount('cash_movements'), 5);
      expect(
        database.outbox.pending().map((operation) => operation.operationType),
        containsAll([
          'configure_local_workspace',
          'create_local_product',
          'open_cash_session',
          'record_cash_movement',
          'confirm_sale',
          'close_cash_session',
        ]),
      );
    });

    test('keeps products excluded from offline sale out of POS catalog',
        () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'cash-register-test',
          cashRegisterName: 'Register 1',
        ),
      );
      signIn(database);
      database.createLocalProduct(
        const LocalProductInput(
          productId: 'product-offline-disabled',
          variantId: variantId,
          categoryId: 'category-test',
          categoryName: 'Coffee',
          name: 'Seasonal Coffee',
          sku: null,
          priceMinor: '450',
          initialStock: '3',
          offlineSellable: false,
        ),
      );

      expect(database.getCatalogProducts(), isEmpty);
      expect(database.getCatalogProducts(offlineOnly: false), hasLength(1));
      final session = database.openLocalCashSession(
        sessionId: 'offline-policy-session',
        openingUsdMinor: '0',
      );
      expect(
        () => database.confirmSale(
          LocalSaleInput(
            id: 'blocked-offline-sale',
            organizationId: organizationId,
            branchId: branchId,
            terminalId: terminalId,
            profileId: profileId,
            cashSessionId: session.id,
            idempotencyKey: 'blocked-offline-sale',
            saleNumber: 'L-BLOCKED',
            totalCurrency: 'USD',
            totalMinor: '450',
            items: const [
              LocalSaleItemInput(
                variantId: variantId,
                quantity: '1',
                unitPriceMinor: '450',
                subtotalMinor: '450',
              ),
            ],
            payments: const [
              LocalPaymentInput(
                method: 'CASH_USD',
                amountMinor: '450',
                currencyCode: 'USD',
                originalAmountMinor: '450',
                originalCurrencyCode: 'USD',
              ),
            ],
            inventoryConsumptions: const [
              LocalInventoryConsumption(
                warehouseId: warehouseId,
                variantId: variantId,
                quantity: '1',
              ),
            ],
          ),
        ),
        throwsA(
          isA<LocalSaleConflictException>().having(
            (error) => error.code,
            'code',
            'OFFLINE_SALE_NOT_ALLOWED',
          ),
        ),
      );
      expect(database.tableCount('sales'), 0);
      expect(
        database.inventoryQuantity(
          warehouseId: warehouseId,
          variantId: variantId,
        ),
        '3',
      );
    });
  });

  group('confirmed local sale', () {
    test('writes sale, items, payment, inventory and outbox together',
        () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );

      final saleId = database.confirmSale(
        sale(
          id: 'sale-1',
          idempotencyKey: 'sale-key-1',
          consumptionQuantity: '2',
        ),
      );

      expect(saleId, 'sale-1');
      expect(database.getSyncStatus(saleId), 'PENDING');
      expect(
          database.inventoryQuantity(
            warehouseId: warehouseId,
            variantId: variantId,
          ),
          '3');
      expect(database.tableCount('sales'), 1);
      expect(database.tableCount('sale_items'), 1);
      expect(database.tableCount('payments'), 1);
      expect(database.tableCount('inventory_movements'), 1);
      expect(database.tableCount('audit_logs'), 1);
      expect(database.tableCount('sync_outbox'), 1);
      expect(database.outbox.pending(), hasLength(1));
    });

    test('rolls back every effect when stock is insufficient', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '1',
      );

      expect(
        () => database.confirmSale(
          sale(
            id: 'sale-rollback',
            idempotencyKey: 'sale-key-rollback',
            consumptionQuantity: '2',
          ),
        ),
        throwsA(isA<LocalSaleConflictException>().having(
          (error) => error.code,
          'code',
          'INSUFFICIENT_OFFLINE_STOCK',
        )),
      );

      expect(database.tableCount('sales'), 0);
      expect(database.tableCount('sale_items'), 0);
      expect(database.tableCount('payments'), 0);
      expect(database.tableCount('inventory_movements'), 0);
      expect(database.tableCount('audit_logs'), 0);
      expect(database.tableCount('sync_outbox'), 0);
      expect(
          database.inventoryQuantity(
            warehouseId: warehouseId,
            variantId: variantId,
          ),
          '1');
    });

    test('same idempotency key returns existing sale without duplicate',
        () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );
      final input = sale(
        id: 'sale-idempotent',
        idempotencyKey: 'same-operation',
        consumptionQuantity: '1',
      );

      expect(database.confirmSale(input), 'sale-idempotent');
      expect(database.confirmSale(input), 'sale-idempotent');
      expect(database.tableCount('sales'), 1);
      expect(database.tableCount('payments'), 1);
      expect(database.tableCount('inventory_movements'), 1);
      expect(database.tableCount('sync_outbox'), 1);
      expect(
          database.inventoryQuantity(
            warehouseId: warehouseId,
            variantId: variantId,
          ),
          '4');
    });

    test('does not confuse distinct sales with equal total', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );

      database.confirmSale(
        sale(
          id: 'sale-a',
          idempotencyKey: 'key-a',
          consumptionQuantity: '1',
        ),
      );
      database.confirmSale(
        sale(
          id: 'sale-b',
          idempotencyKey: 'key-b',
          consumptionQuantity: '1',
        ),
      );

      expect(database.tableCount('sales'), 2);
      expect(database.tableCount('sync_outbox'), 2);
    });
  });

  group('outbox and cursors', () {
    test('persists pending state, sync receipt and cursor', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );
      final saleId = database.confirmSale(
        sale(
          id: 'sale-sync',
          idempotencyKey: 'key-sync',
          consumptionQuantity: '1',
        ),
      );
      final pending = database.outbox.pending();
      expect(pending, hasLength(1));

      database.outbox.markSynced(
        outboxId: pending.first.id,
        idempotencyKey: pending.first.idempotencyKey,
        entityId: 'sale-sync',
        operationType: 'confirm_sale',
        organizationId: organizationId,
        terminalId: terminalId,
        remoteVersion: 1,
      );
      expect(database.getSyncStatus(saleId), 'SYNCED');
      expect(database.tableCount('sync_receipts'), 1);
      expect(database.outbox.pending(), isEmpty);

      expect(
        () => database.outbox.markSynced(
          outboxId: pending.first.id,
          idempotencyKey: pending.first.idempotencyKey,
          entityId: 'other-sale',
          operationType: 'confirm_sale',
          organizationId: organizationId,
          terminalId: terminalId,
        ),
        throwsStateError,
      );

      database.outbox.setCursor(
        organizationId: organizationId,
        terminalId: terminalId,
        stream: 'sales',
        cursor: '2026-11-24T12:00:00Z|sale-sync',
      );
      expect(
        database.outbox.getCursor(
          terminalId: terminalId,
          stream: 'sales',
        ),
        '2026-11-24T12:00:00Z|sale-sync',
      );
    });

    test('retains conflicts and stops retrying them', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );
      database.confirmSale(
        sale(
          id: 'sale-conflict',
          idempotencyKey: 'key-conflict',
          consumptionQuantity: '1',
        ),
      );
      final pending = database.outbox.pending().single;
      database.outbox.markConflict(
        outboxId: pending.id,
        organizationId: organizationId,
        terminalId: terminalId,
        operationType: 'confirm_sale',
        code: 'PRICE_CHANGED',
        message: 'Remote price differs from the local snapshot',
      );

      final row = database.database.select(
        'SELECT sync_status, next_attempt_at, last_error_code '
        'FROM sync_outbox WHERE id = ?',
        [pending.id],
      ).single;
      expect(row['sync_status'], 'CONFLICT');
      expect(row['next_attempt_at'], isNull);
      expect(row['last_error_code'], 'PRICE_CHANGED');
      expect(database.tableCount('sync_errors'), 1);
      expect(database.outbox.pending(), isEmpty);
      expect(database.getSyncStatus('sale-conflict'), 'PENDING');
    });
  });

  group('local dining, production and checkout', () {
    test('reserves stock, routes station tickets and atomically pays table',
        () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      final workspace = database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'venue-register',
          cashRegisterName: 'Register 1',
        ),
      );
      signIn(database);
      database.createLocalProduct(
        const LocalProductInput(
          productId: 'venue-product',
          variantId: 'venue-variant',
          categoryId: 'venue-category',
          categoryName: 'Hot Drinks',
          name: 'Cappuccino',
          sku: 'CAP-1',
          priceMinor: '450',
          initialStock: '5',
          offlineSellable: true,
          fulfillmentStation: 'KITCHEN',
        ),
      );
      final table = database.createDiningTable(name: 'Mesa 1', capacity: 4);
      final opened = database.openDiningSession(table.id);
      database.addDiningItem(
        sessionId: opened.id,
        variantId: 'venue-variant',
        quantity: '2',
        notes: 'Leche de avena',
      );
      expect(
        database.getCatalogProducts().single.availableQuantity,
        '3',
      );

      final orders = database.sendDiningOrders(opened.id);
      expect(orders, hasLength(1));
      expect(orders.single.station, 'KITCHEN');
      expect(orders.single.items.single.notes, 'Leche de avena');
      database.transitionProductionOrder(
        orderId: orders.single.id,
        nextStatus: 'PREPARING',
      );
      database.transitionProductionOrder(
        orderId: orders.single.id,
        nextStatus: 'READY',
      );
      database.transitionProductionOrder(
        orderId: orders.single.id,
        nextStatus: 'DELIVERED',
      );
      final precuenta = database.generateLocalPrecuenta(opened.id);
      expect(precuenta.totalUsdMinor, '900');
      expect(database.getDiningTables().single.status, 'PREBILL');

      final cash = database.openLocalCashSession(
        sessionId: 'venue-cash-session',
        openingUsdMinor: '1000',
      );
      final session = database.getDiningSession(opened.id)!;
      final saleId = database.confirmSale(
        LocalSaleInput(
          id: 'venue-table-sale',
          organizationId: workspace.organizationId,
          branchId: workspace.branchId,
          terminalId: workspace.terminalId,
          profileId: workspace.profileId,
          cashSessionId: cash.id,
          diningSessionId: opened.id,
          idempotencyKey: 'venue-table-sale',
          saleNumber: 'M-001',
          totalCurrency: 'USD',
          totalMinor: session.totalUsdMinor,
          items: [
            for (final item in session.activeItems)
              LocalSaleItemInput(
                variantId: item.variantId,
                quantity: item.quantity,
                unitPriceMinor: item.unitPriceMinor,
                subtotalMinor: item.subtotalMinor,
              ),
          ],
          payments: const [
            LocalPaymentInput(
              method: 'CARD_USD',
              amountMinor: '900',
              currencyCode: 'USD',
              originalAmountMinor: '900',
              originalCurrencyCode: 'USD',
            ),
          ],
          inventoryConsumptions: const [
            LocalInventoryConsumption(
              warehouseId: warehouseId,
              variantId: 'venue-variant',
              quantity: '2',
              reservedQuantity: '2',
            ),
          ],
        ),
      );

      expect(saleId, 'venue-table-sale');
      expect(database.getDiningTables().single.status, 'FREE');
      expect(database.getDiningSession(opened.id)!.status, 'CLOSED');
      expect(
        database.inventoryQuantity(
          warehouseId: warehouseId,
          variantId: 'venue-variant',
        ),
        '3',
      );
      expect(
        database.database.select(
          'SELECT reserved_minor FROM inventory_balances WHERE variant_id = ?',
          ['venue-variant'],
        ).single['reserved_minor'],
        '0',
      );
      expect(database.getSyncStatus(saleId), 'PENDING');
      expect(database.tableCount('sales'), 1);
    });

    test('rejects invalid production transitions and releases removed stock',
        () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'venue-register',
          cashRegisterName: 'Register 1',
        ),
      );
      signIn(database);
      database.createLocalProduct(
        const LocalProductInput(
          productId: 'bar-product',
          variantId: 'bar-variant',
          categoryId: 'bar-category',
          categoryName: 'Cold Drinks',
          name: 'Lemonade',
          sku: 'LEM-1',
          priceMinor: '300',
          initialStock: '3',
          offlineSellable: true,
          fulfillmentStation: 'BAR',
        ),
      );
      final table = database.createDiningTable(name: 'Mesa 2', capacity: 2);
      final session = database.openDiningSession(table.id);
      final item = database.addDiningItem(
        sessionId: session.id,
        variantId: 'bar-variant',
        quantity: '2',
      );
      expect(
        database.getCatalogProducts().single.availableQuantity,
        '1',
      );
      database.removeUnsentDiningItem(item.id);
      expect(
        database.getCatalogProducts().single.availableQuantity,
        '3',
      );
      expect(
        () => database.sendDiningOrders(session.id),
        throwsStateError,
      );
      database.closeEmptyDiningSession(session.id);
      expect(database.getDiningTables().single.status, 'FREE');
    });
  });

  group('fail-closed authorization', () {
    test('rejects operations when no local session is active', () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: organizationId,
          organizationName: 'Test Organization',
          branchId: branchId,
          branchName: 'Test Branch',
          terminalId: terminalId,
          terminalName: 'Terminal 1',
          profileId: profileId,
          profileName: 'Operator',
          profilePin: '1234',
          warehouseId: warehouseId,
          warehouseName: 'Main Warehouse',
          cashRegisterId: 'no-session-register',
          cashRegisterName: 'Register 1',
        ),
      );

      expect(database.activeProfileSessionId, isNull);
      expect(
        () => database.confirmSale(
          sale(
            id: 'no-session-sale',
            idempotencyKey: 'no-session-sale',
            consumptionQuantity: '1',
          ),
        ),
        throwsStateError,
      );
      expect(
        () => database.adjustLocalInventory(
          variantId: variantId,
          quantityDelta: '1',
          reason: 'no session',
        ),
        throwsStateError,
      );
      expect(database.tableCount('sales'), 0);
      expect(
        database.outbox.pending().where(
              (entry) => entry.operationType == 'confirm_sale',
            ),
        isEmpty,
      );
    });

    test('rejects operations after the session is revoked', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      expect(database.activeProfileSessionId, isNotNull);

      expect(database.revokeLocalProfileSessions(), 1);
      expect(database.activeProfileSessionId, isNull);
      expect(
        () => database.confirmSale(
          sale(
            id: 'revoked-sale',
            idempotencyKey: 'revoked-sale',
            consumptionQuantity: '1',
          ),
        ),
        throwsStateError,
      );
    });

    test('rejects operations after the session expires', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      final sessionId = database.activeProfileSessionId!;
      database.database.execute(
        'UPDATE local_profile_sessions SET expires_at = ? WHERE id = ?',
        [
          DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          sessionId,
        ],
      );

      expect(database.activeProfileSessionId, isNull);
      expect(
        () => database.adjustLocalInventory(
          variantId: variantId,
          quantityDelta: '1',
          reason: 'expired session',
        ),
        throwsStateError,
      );
    });

    test('rejects sales for another terminal or without a cash session',
        () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );

      expect(
        () => database.confirmSale(
          sale(
            id: 'foreign-terminal-sale',
            idempotencyKey: 'foreign-terminal-sale',
            consumptionQuantity: '1',
            saleTerminalId: 'other-terminal',
          ),
        ),
        throwsA(
          isA<LocalSaleConflictException>().having(
            (error) => error.code,
            'code',
            'WORKSPACE_MISMATCH',
          ),
        ),
      );
      expect(
        () => database.confirmSale(
          sale(
            id: 'no-cash-sale',
            idempotencyKey: 'no-cash-sale',
            consumptionQuantity: '1',
            cashSessionId: null,
          ),
        ),
        throwsA(
          isA<LocalSaleConflictException>().having(
            (error) => error.code,
            'code',
            'CASH_SESSION_REQUIRED',
          ),
        ),
      );
      expect(database.tableCount('sales'), 0);
    });
  });

  group('sale outbox payload', () {
    test('queues the complete sale.v1 contract', () async {
      final database = await seededDatabase();
      addTearDown(database.close);
      database.setInventoryBalance(
        organizationId: organizationId,
        warehouseId: warehouseId,
        variantId: variantId,
        quantityMinor: '5',
      );

      database.confirmSale(
        sale(
          id: 'sale-payload',
          idempotencyKey: 'key-payload',
          consumptionQuantity: '2',
        ),
      );

      final entry = database.outbox.pending().single;
      expect(entry.operationType, 'confirm_sale');
      final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      expect(payload['schema_version'], 'sale.v1');
      expect(payload['idempotency_key'], 'key-payload');

      final saleJson = payload['sale'] as Map<String, dynamic>;
      expect(saleJson['id'], 'sale-payload');
      expect(saleJson['sale_number'], 'TEST-001');
      expect(saleJson['branch_id'], branchId);
      expect(saleJson['terminal_id'], terminalId);
      expect(saleJson['profile_id'], profileId);
      expect(saleJson['cash_session_id'], 'seeded-cash-session');
      expect(saleJson['total_currency'], 'USD');
      expect(saleJson['total_minor'], 1000);

      final items = payload['items'] as List<dynamic>;
      expect(items, hasLength(1));
      final item = items.single as Map<String, dynamic>;
      expect(item['id'], isNotNull);
      expect(item['variant_id'], variantId);
      expect(item['quantity'], 1);
      expect(item['unit_price_minor'], 1000);
      expect(item['tax_minor'], 0);

      final payments = payload['payments'] as List<dynamic>;
      expect(payments, hasLength(1));
      final payment = payments.single as Map<String, dynamic>;
      expect(payment['id'], isNotNull);
      expect(payment['method'], 'EFECTIVO USD');
      expect(payment['amount_minor'], 1000);
      expect(payment['currency_code'], 'USD');
      expect(payment['original_currency_code'], 'USD');

      final consumptions = payload['inventory_consumptions'] as List<dynamic>;
      expect(consumptions, hasLength(1));
      final consumption = consumptions.single as Map<String, dynamic>;
      expect(consumption['warehouse_id'], warehouseId);
      expect(consumption['variant_id'], variantId);
      expect(consumption['quantity'], 2);
    });
  });
}
