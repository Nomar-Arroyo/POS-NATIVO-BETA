import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';
import 'models.dart';

extension LocalVenueOperations on LocalDatabase {
  LocalDiningTable createDiningTable({
    required String name,
    required int capacity,
  }) {
    requireCurrentPermission('tables.manage');
    final workspace = _requireWorkspace();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || capacity <= 0) {
      throw ArgumentError('Table name and positive capacity are required');
    }
    final id = const Uuid().v4();
    final now = _now();
    _transaction(() {
      database.execute(
        'INSERT INTO dining_tables(id, organization_id, branch_id, name, '
        'capacity, status, active, sort_order, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          workspace.organizationId,
          workspace.branchId,
          trimmedName,
          capacity,
          'FREE',
          1,
          0,
          now,
          now,
        ],
      );
      _audit(
        workspace,
        action: 'LOCAL_DINING_TABLE_CREATED',
        entityType: 'dining_table',
        entityId: id,
        after: {'name': trimmedName, 'capacity': capacity},
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'upsert_dining_table',
        entityId: id,
        idempotencyKey: 'dining-table:create:$id',
        payload: {'id': id, 'name': trimmedName, 'capacity': capacity},
        now: now,
      );
    });
    return getDiningTables().singleWhere((table) => table.id == id);
  }

  List<LocalDiningTable> getDiningTables() {
    final workspace = localWorkspace;
    if (workspace == null) return const [];
    final rows = database.select(
      'SELECT t.id, t.name, t.capacity, t.status, s.id AS session_id '
      'FROM dining_tables t LEFT JOIN dining_sessions s '
      'ON s.dining_table_id = t.id AND s.status = ? '
      'WHERE t.organization_id = ? AND t.branch_id = ? AND t.active = 1 '
      'ORDER BY t.sort_order, t.name',
      ['OPEN', workspace.organizationId, workspace.branchId],
    );
    return rows
        .map(
          (row) => LocalDiningTable(
            id: row['id'] as String,
            name: row['name'] as String,
            capacity: row['capacity'] as int,
            status: row['status'] as String,
            openSessionId: row['session_id'] as String?,
          ),
        )
        .toList(growable: false);
  }

  LocalDiningSession openDiningSession(String tableId) {
    requireCurrentPermission('tables.manage');
    final workspace = _requireWorkspace();
    final table = database.select(
      'SELECT id, name, status FROM dining_tables '
      'WHERE id = ? AND organization_id = ? AND branch_id = ? AND active = 1',
      [tableId, workspace.organizationId, workspace.branchId],
    );
    if (table.isEmpty) throw StateError('Dining table not found');
    if (table.first['status'] != 'FREE') {
      throw StateError('Dining table is not free');
    }
    final id = const Uuid().v4();
    final now = _now();
    _transaction(() {
      database.execute(
        'INSERT INTO dining_sessions(id, organization_id, dining_table_id, '
        'terminal_id, profile_id, status, opened_at, idempotency_key) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          workspace.organizationId,
          tableId,
          workspace.terminalId,
          workspace.profileId,
          'OPEN',
          now,
          'dining-session:open:$id',
        ],
      );
      database.execute(
        'UPDATE dining_tables SET status = ?, updated_at = ? WHERE id = ?',
        ['OCCUPIED', now, tableId],
      );
      _audit(
        workspace,
        action: 'LOCAL_DINING_SESSION_OPENED',
        entityType: 'dining_session',
        entityId: id,
        after: {'dining_table_id': tableId},
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'open_dining_session',
        entityId: id,
        idempotencyKey: 'dining-session:open:$id',
        payload: {'id': id, 'dining_table_id': tableId},
        now: now,
      );
    });
    return getDiningSession(id)!;
  }

  LocalDiningSession? getDiningSession(String sessionId) {
    final rows = database.select(
      'SELECT s.id, s.dining_table_id, t.name AS table_name, s.status, s.opened_at '
      'FROM dining_sessions s JOIN dining_tables t ON t.id = s.dining_table_id '
      'WHERE s.id = ?',
      [sessionId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final items = database.select(
      'SELECT id, variant_id, product_name, quantity, unit_price_minor, '
      'currency_code, fulfillment_station, status, created_at, notes, sent_at '
      'FROM dining_session_items WHERE dining_session_id = ? ORDER BY created_at',
      [sessionId],
    );
    return LocalDiningSession(
      id: row['id'] as String,
      tableId: row['dining_table_id'] as String,
      tableName: row['table_name'] as String,
      status: row['status'] as String,
      openedAt: row['opened_at'] as String,
      items: items.map(_diningItemFromRow).toList(growable: false),
    );
  }

  LocalDiningItem addDiningItem({
    required String sessionId,
    required String variantId,
    required String quantity,
    String? notes,
  }) {
    requireCurrentPermission('tables.manage');
    final workspace = _requireWorkspace();
    final amount = BigInt.parse(quantity);
    if (amount <= BigInt.zero) {
      throw ArgumentError('Dining item quantity must be greater than zero');
    }
    final id = const Uuid().v4();
    final now = _now();
    _transaction(() {
      final catalog = database.select(
        'SELECT p.name, p.base_currency, p.offline_sellable, p.active, '
        'p.fulfillment_station, p.is_synthetic, v.price_minor, '
        'v.active AS variant_active '
        'FROM product_variants v JOIN products p ON p.id = v.product_id '
        'WHERE v.id = ? AND v.organization_id = ? AND p.deleted_at IS NULL '
        'AND v.deleted_at IS NULL',
        [variantId, workspace.organizationId],
      );
      if (catalog.isEmpty ||
          catalog.first['active'] != 1 ||
          catalog.first['variant_active'] != 1 ||
          catalog.first['offline_sellable'] != 1) {
        throw StateError('Product is not available for local table service');
      }
      if (catalog.first['base_currency'] != 'USD') {
        throw StateError(
          'Table service currently supports USD catalog prices only',
        );
      }
      if (!isDemoMode && catalog.first['is_synthetic'] == 1) {
        throw StateError(
          'Demonstration catalog items cannot be used in real table orders',
        );
      }
      final station = catalog.first['fulfillment_station'] as String;
      if (station != 'KITCHEN' && station != 'BAR') {
        throw StateError(
            'Assign the product to kitchen or bar before ordering');
      }
      final session = database.select(
        'SELECT id FROM dining_sessions WHERE id = ? AND organization_id = ? '
        'AND terminal_id = ? AND status = ?',
        [sessionId, workspace.organizationId, workspace.terminalId, 'OPEN'],
      );
      if (session.isEmpty) throw StateError('Dining session is not open here');
      final balance = database.select(
        'SELECT id, quantity_minor, reserved_minor FROM inventory_balances '
        'WHERE warehouse_id = ? AND variant_id = ?',
        [workspace.warehouseId, variantId],
      );
      if (balance.isEmpty)
        throw StateError('Known inventory balance not found');
      final known = BigInt.parse(balance.first['quantity_minor'] as String);
      final reserved = BigInt.parse(balance.first['reserved_minor'] as String);
      if (known - reserved < amount) {
        throw StateError('Insufficient known local stock');
      }
      database.execute(
        'UPDATE inventory_balances SET reserved_minor = ?, version = version + 1, '
        'updated_at = ? WHERE id = ?',
        [(reserved + amount).toString(), now, balance.first['id']],
      );
      database.execute(
        'INSERT INTO dining_session_items(id, organization_id, dining_session_id, '
        'variant_id, product_name, quantity, unit_price_minor, currency_code, '
        'fulfillment_station, notes, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          workspace.organizationId,
          sessionId,
          variantId,
          catalog.first['name'],
          amount.toString(),
          catalog.first['price_minor'],
          'USD',
          station,
          _normalizeNotes(notes),
          'UNSENT',
          now,
          now,
        ],
      );
      database.execute(
        'UPDATE dining_tables SET status = ?, updated_at = ? '
        'WHERE id = (SELECT dining_table_id FROM dining_sessions WHERE id = ?)',
        ['OCCUPIED', now, sessionId],
      );
      _audit(
        workspace,
        action: 'LOCAL_DINING_ITEM_ADDED',
        entityType: 'dining_session_item',
        entityId: id,
        after: {
          'variant_id': variantId,
          'quantity': amount.toString(),
          'reserved': true,
        },
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'add_dining_session_item',
        entityId: id,
        idempotencyKey: 'dining-item:add:$id',
        payload: {
          'id': id,
          'dining_session_id': sessionId,
          'variant_id': variantId,
          'quantity': amount.toString(),
        },
        now: now,
      );
    });
    return getDiningSession(sessionId)!
        .items
        .singleWhere((item) => item.id == id);
  }

  void removeUnsentDiningItem(String itemId) {
    requireCurrentPermission('tables.manage');
    final workspace = _requireWorkspace();
    final now = _now();
    _transaction(() {
      final rows = database.select(
        'SELECT i.id, i.dining_session_id, i.variant_id, i.quantity, i.status, '
        'b.id AS balance_id, b.reserved_minor, s.dining_table_id '
        'FROM dining_session_items i '
        'JOIN dining_sessions s ON s.id = i.dining_session_id '
        'JOIN inventory_balances b ON b.variant_id = i.variant_id AND b.warehouse_id = ? '
        'WHERE i.id = ? AND i.organization_id = ? AND s.status = ? '
        'AND s.terminal_id = ?',
        [
          workspace.warehouseId,
          itemId,
          workspace.organizationId,
          'OPEN',
          workspace.terminalId,
        ],
      );
      if (rows.isEmpty) throw StateError('Dining item was not found');
      final row = rows.first;
      if (row['status'] != 'UNSENT') {
        throw StateError(
          'Sent items require an approved cancellation workflow',
        );
      }
      final quantity = BigInt.parse(row['quantity'] as String);
      final reserved = BigInt.parse(row['reserved_minor'] as String);
      if (reserved < quantity) {
        throw StateError('Inventory reservation is inconsistent');
      }
      database.execute(
        'UPDATE inventory_balances SET reserved_minor = ?, version = version + 1, '
        'updated_at = ? WHERE id = ?',
        [(reserved - quantity).toString(), now, row['balance_id']],
      );
      database.execute(
        'UPDATE dining_session_items SET status = ?, updated_at = ? WHERE id = ?',
        ['CANCELLED', now, itemId],
      );
      database.execute(
        'UPDATE dining_tables SET status = ?, updated_at = ? WHERE id = ?',
        ['OCCUPIED', now, row['dining_table_id']],
      );
      _audit(
        workspace,
        action: 'LOCAL_DINING_ITEM_REMOVED',
        entityType: 'dining_session_item',
        entityId: itemId,
        after: {
          'status': 'CANCELLED',
          'released_quantity': quantity.toString()
        },
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'remove_dining_session_item',
        entityId: itemId,
        idempotencyKey: 'dining-item:remove:$itemId',
        payload: {'id': itemId, 'status': 'CANCELLED'},
        now: now,
      );
    });
  }

  LocalPrecuenta generateLocalPrecuenta(String sessionId) {
    requireCurrentPermission('tables.manage');
    final workspace = _requireWorkspace();
    final session = getDiningSession(sessionId);
    if (session == null || session.status != 'OPEN') {
      throw StateError('Open dining session not found');
    }
    final items = session.activeItems;
    if (items.isEmpty) throw StateError('Cannot generate an empty precuenta');
    final id = const Uuid().v4();
    final now = _now();
    _transaction(() {
      database.execute(
        'UPDATE dining_tables SET status = ?, updated_at = ? WHERE id = ?',
        ['PREBILL', now, session.tableId],
      );
      _audit(
        workspace,
        action: 'LOCAL_PRECUENTA_GENERATED',
        entityType: 'dining_session',
        entityId: sessionId,
        after: {
          'precuenta_id': id,
          'total_usd_minor': session.totalUsdMinor,
          'items_count': items.length,
          'document_type': 'NON_FISCAL_PREVIEW',
        },
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'generate_local_precuenta',
        entityId: sessionId,
        idempotencyKey: 'precuenta:$id',
        payload: {
          'id': id,
          'dining_session_id': sessionId,
          'total_usd_minor': session.totalUsdMinor,
        },
        now: now,
      );
    });
    return LocalPrecuenta(
      id: id,
      tableName: session.tableName,
      generatedAt: now,
      items: items,
      totalUsdMinor: session.totalUsdMinor,
    );
  }

  void closeEmptyDiningSession(String sessionId) {
    requireCurrentPermission('tables.manage');
    final workspace = _requireWorkspace();
    final session = database.select(
      'SELECT id, dining_table_id FROM dining_sessions '
      'WHERE id = ? AND organization_id = ? AND terminal_id = ? AND status = ?',
      [sessionId, workspace.organizationId, workspace.terminalId, 'OPEN'],
    );
    if (session.isEmpty) throw StateError('Open dining session not found');
    final activeItems = database.select(
      'SELECT 1 FROM dining_session_items WHERE dining_session_id = ? '
      'AND status != ? LIMIT 1',
      [sessionId, 'CANCELLED'],
    );
    if (activeItems.isNotEmpty) {
      throw StateError('A table with items must be paid before it is closed');
    }
    final tableId = session.first['dining_table_id'] as String;
    final now = _now();
    _transaction(() {
      database.execute(
        'UPDATE dining_sessions SET status = ?, closed_at = ?, '
        'base_version = base_version + 1 WHERE id = ?',
        ['CLOSED', now, sessionId],
      );
      database.execute(
        'UPDATE dining_tables SET status = ?, updated_at = ? WHERE id = ?',
        ['FREE', now, tableId],
      );
      _audit(
        workspace,
        action: 'LOCAL_EMPTY_DINING_SESSION_CLOSED',
        entityType: 'dining_session',
        entityId: sessionId,
        after: {'dining_table_id': tableId},
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'close_empty_dining_session',
        entityId: sessionId,
        idempotencyKey: 'dining-session:close-empty:$sessionId',
        payload: {'id': sessionId},
        now: now,
      );
    });
  }

  List<LocalProductionOrder> sendDiningOrders(String sessionId) {
    requireCurrentPermission('production.send');
    final workspace = _requireWorkspace();
    final session = getDiningSession(sessionId);
    if (session == null || session.status != 'OPEN' || session.items.isEmpty) {
      throw StateError('Open dining session with items is required');
    }
    final unsent = session.activeItems
        .where((item) => item.status == 'UNSENT')
        .toList(growable: false);
    if (unsent.isEmpty) throw StateError('No unsent items to dispatch');
    final groups = <String, List<LocalDiningItem>>{};
    for (final item in unsent) {
      groups.putIfAbsent(item.station, () => []).add(item);
    }
    final ids = <String>[];
    final now = _now();
    _transaction(() {
      for (final entry in groups.entries) {
        final id = const Uuid().v4();
        final orderNumber =
            'CMD-${DateTime.now().toUtc().millisecondsSinceEpoch}-${ids.length + 1}';
        database.execute(
          'INSERT INTO production_orders(id, organization_id, dining_session_id, '
          'dining_table_id, order_number, station, status, created_by, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            workspace.organizationId,
            sessionId,
            session.tableId,
            orderNumber,
            entry.key,
            'PENDING',
            workspace.profileId,
            now,
            now,
          ],
        );
        for (final item in entry.value) {
          database.execute(
            'INSERT INTO production_order_items(id, organization_id, production_order_id, '
            'dining_session_item_id, created_at) VALUES (?, ?, ?, ?, ?)',
            [
              const Uuid().v4(),
              workspace.organizationId,
              id,
              item.id,
              now,
            ],
          );
          database.execute(
            'UPDATE dining_session_items SET status = ?, sent_at = ?, updated_at = ? '
            'WHERE id = ? AND status = ?',
            ['PENDING', now, now, item.id, 'UNSENT'],
          );
        }
        _audit(
          workspace,
          action: 'LOCAL_PRODUCTION_ORDER_SENT',
          entityType: 'production_order',
          entityId: id,
          after: {
            'order_number': orderNumber,
            'station': entry.key,
            'items_count': entry.value.length,
          },
          now: now,
        );
        _outbox(
          workspace.organizationId,
          operationType: 'send_production_order',
          entityId: id,
          idempotencyKey: 'production-order:send:$id',
          payload: {
            'id': id,
            'dining_session_id': sessionId,
            'station': entry.key,
            'item_ids': entry.value.map((item) => item.id).toList(),
          },
          now: now,
        );
        ids.add(id);
      }
    });
    return getProductionOrders()
        .where((order) => ids.contains(order.id))
        .toList();
  }

  List<LocalProductionOrder> getProductionOrders({
    String? station,
    Set<String>? statuses,
  }) {
    final workspace = localWorkspace;
    if (workspace == null) return const [];
    final rows = database.select(
      'SELECT o.id, o.order_number, o.station, o.status, o.created_at, '
      't.name AS table_name FROM production_orders o '
      'JOIN dining_tables t ON t.id = o.dining_table_id '
      'WHERE o.organization_id = ? AND t.branch_id = ? '
      'ORDER BY o.created_at, o.station',
      [workspace.organizationId, workspace.branchId],
    );
    return rows.where((row) {
      final matchesStation = station == null || row['station'] == station;
      final matchesStatus =
          statuses == null || statuses.contains(row['status']);
      return matchesStation && matchesStatus;
    }).map((row) {
      final itemRows = database.select(
        'SELECT i.id, i.variant_id, i.product_name, i.quantity, i.unit_price_minor, '
        'i.currency_code, i.fulfillment_station, i.status, i.created_at, i.notes, i.sent_at '
        'FROM production_order_items oi JOIN dining_session_items i '
        'ON i.id = oi.dining_session_item_id WHERE oi.production_order_id = ? '
        'ORDER BY i.created_at',
        [row['id']],
      );
      return LocalProductionOrder(
        id: row['id'] as String,
        orderNumber: row['order_number'] as String,
        tableName: row['table_name'] as String,
        station: row['station'] as String,
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
        items: itemRows.map(_diningItemFromRow).toList(growable: false),
      );
    }).toList(growable: false);
  }

  LocalProductionOrder transitionProductionOrder({
    required String orderId,
    required String nextStatus,
  }) {
    requireCurrentPermission('production.update');
    const transitions = {
      'PENDING': 'PREPARING',
      'PREPARING': 'READY',
      'READY': 'DELIVERED',
    };
    final workspace = _requireWorkspace();
    final now = _now();
    _transaction(() {
      final order = database.select(
        'SELECT o.* FROM production_orders o '
        'JOIN dining_sessions s ON s.id = o.dining_session_id '
        'WHERE o.id = ? AND o.organization_id = ? AND s.terminal_id = ?',
        [orderId, workspace.organizationId, workspace.terminalId],
      );
      if (order.isEmpty) throw StateError('Production order not found');
      final row = order.first;
      final previousStatus = row['status'] as String;
      if (transitions[previousStatus] != nextStatus) {
        throw StateError('Invalid production order state transition');
      }
      final updated = database.select(
        'UPDATE production_orders SET status = ?, updated_at = ?, '
        'ready_at = CASE WHEN ? = ? THEN ? ELSE ready_at END, '
        'delivered_at = CASE WHEN ? = ? THEN ? ELSE delivered_at END, '
        'base_version = base_version + 1 WHERE id = ? AND status = ? RETURNING id',
        [
          nextStatus,
          now,
          nextStatus,
          'READY',
          now,
          nextStatus,
          'DELIVERED',
          now,
          orderId,
          previousStatus,
        ],
      );
      if (updated.isEmpty) {
        throw StateError('Production order changed before this update');
      }
      database.execute(
        'UPDATE dining_session_items SET status = ?, updated_at = ? '
        'WHERE id IN (SELECT dining_session_item_id FROM production_order_items '
        'WHERE production_order_id = ?)',
        [nextStatus, now, orderId],
      );
      _audit(
        workspace,
        action: 'LOCAL_PRODUCTION_ORDER_STATUS_CHANGED',
        entityType: 'production_order',
        entityId: orderId,
        after: {'status': nextStatus},
        now: now,
      );
      _outbox(
        workspace.organizationId,
        operationType: 'update_production_order',
        entityId: orderId,
        idempotencyKey: 'production-order:status:$orderId:$nextStatus',
        payload: {'id': orderId, 'status': nextStatus},
        now: now,
      );
    });
    return getProductionOrders().singleWhere((item) => item.id == orderId);
  }

  LocalWorkspace _requireWorkspace() {
    final workspace = localWorkspace;
    if (workspace == null)
      throw StateError('Configure the local workspace first');
    return workspace;
  }

  void _transaction(void Function() action) {
    database.execute('BEGIN IMMEDIATE');
    try {
      action();
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _audit(
    LocalWorkspace workspace, {
    required String action,
    required String entityType,
    required String entityId,
    required Map<String, Object?> after,
    required String now,
  }) {
    database.execute(
      'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, profile_id, '
      'action, entity_type, entity_id, after_json, occurred_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        const Uuid().v4(),
        workspace.organizationId,
        workspace.branchId,
        workspace.terminalId,
        workspace.profileId,
        action,
        entityType,
        entityId,
        jsonEncode(after),
        now,
      ],
    );
  }

  void _outbox(
    String organizationId, {
    required String operationType,
    required String entityId,
    required String idempotencyKey,
    required Map<String, Object?> payload,
    required String now,
  }) {
    database.execute(
      'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
      'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
      'next_attempt_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        const Uuid().v4(),
        organizationId,
        operationType,
        entityId,
        idempotencyKey,
        1,
        jsonEncode(payload),
        'PENDING',
        0,
        null,
        now,
        now,
      ],
    );
  }

  LocalDiningItem _diningItemFromRow(Row row) => LocalDiningItem(
        id: row['id'] as String,
        variantId: row['variant_id'] as String,
        productName: row['product_name'] as String,
        quantity: row['quantity'] as String,
        unitPriceMinor: row['unit_price_minor'] as String,
        currencyCode: row['currency_code'] as String,
        station: row['fulfillment_station'] as String,
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
        notes: row['notes'] as String?,
        sentAt: row['sent_at'] as String?,
      );

  String _normalizeNotes(String? notes) {
    final normalized = notes?.trim();
    return normalized == null || normalized.isEmpty ? '' : normalized;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
