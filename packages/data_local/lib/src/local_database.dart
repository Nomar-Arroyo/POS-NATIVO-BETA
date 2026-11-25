import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:core_money/core_money.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'migrations.dart';
import 'models.dart';
import 'outbox.dart';

class LocalDatabase {
  LocalDatabase._(this.database, {required this.isDemoMode})
      : outbox = LocalOutbox(database);

  final Database database;
  final LocalOutbox outbox;
  final bool isDemoMode;

  static const _pinIterations = 120000;
  static const _roleNames = {
    'admin': 'Administrador',
    'cashier': 'Cajero',
    'kitchen': 'Cocina',
    'bar': 'Barra',
  };
  static const _rolePermissions = {
    'admin': [
      'dashboard.view',
      'tables.manage',
      'sales.create',
      'production.view',
      'production.send',
      'production.update',
      'inventory.manage',
      'cash.manage',
      'reports.view',
      'audit.view',
      'settings.manage',
      'profiles.manage',
    ],
    'cashier': [
      'dashboard.view',
      'tables.manage',
      'sales.create',
      'production.view',
      'production.send',
      'cash.manage',
    ],
    'kitchen': ['production.view', 'production.update'],
    'bar': ['production.view', 'production.update'],
  };

  static Future<LocalDatabase> open(
    String path, {
    bool demoMode = false,
  }) async {
    if (demoMode && path != ':memory:') {
      throw ArgumentError('Demo mode requires an in-memory SQLite database');
    }
    final database = sqlite3.open(path);
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA journal_mode = WAL');
    database.execute('PRAGMA busy_timeout = 5000');
    final local = LocalDatabase._(database, isDemoMode: demoMode);
    await SQLiteMigrations(database).migrate();
    local._ensureExistingWorkspaceRoles();
    return local;
  }

  static Future<LocalDatabase> openInMemory() => open(':memory:');

  static Future<LocalDatabase> openDemoInMemory() =>
      open(':memory:', demoMode: true);

  void close() => database.dispose();

  int get migrationCount => (database
      .select(
        'SELECT COUNT(*) AS value FROM schema_migrations',
      )
      .first['value'] as int);

  int get userVersion =>
      (database.select('PRAGMA user_version').first.values.first as int);

  String getSyncStatus(String saleId) {
    final rows = database.select(
      'SELECT sync_status FROM sales WHERE id = ?',
      [saleId],
    );
    return rows.isEmpty ? 'LOCAL' : rows.first['sync_status'] as String;
  }

  LocalWorkspace? get localWorkspace {
    final rows = database.select(
      'SELECT s.organization_id, o.name AS organization_name, '
      's.branch_id, b.name AS branch_name, s.terminal_id, t.name AS terminal_name, '
      's.profile_id, p.display_name AS profile_name, s.warehouse_id, w.name AS warehouse_name, '
      's.cash_register_id, c.name AS cash_register_name '
      'FROM local_setup s '
      'JOIN organizations o ON o.id = s.organization_id '
      'JOIN branches b ON b.id = s.branch_id '
      'JOIN terminals t ON t.id = s.terminal_id '
      'JOIN profiles p ON p.id = s.profile_id '
      'JOIN warehouses w ON w.id = s.warehouse_id '
      'JOIN cash_registers c ON c.id = s.cash_register_id '
      'WHERE s.id = 1',
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return LocalWorkspace(
      organizationId: row['organization_id'] as String,
      organizationName: row['organization_name'] as String,
      branchId: row['branch_id'] as String,
      branchName: row['branch_name'] as String,
      terminalId: row['terminal_id'] as String,
      terminalName: row['terminal_name'] as String,
      profileId: row['profile_id'] as String,
      profileName: row['profile_name'] as String,
      warehouseId: row['warehouse_id'] as String,
      warehouseName: row['warehouse_name'] as String,
      cashRegisterId: row['cash_register_id'] as String,
      cashRegisterName: row['cash_register_name'] as String,
    );
  }

  List<LocalProfile> getLocalProfiles() {
    final workspace = localWorkspace;
    if (workspace == null) return const [];
    final rows = database.select(
      'SELECT p.id, p.display_name, p.pin_hash, r.code AS role_code, '
      'r.name AS role_name FROM profiles p '
      'LEFT JOIN profile_roles pr ON pr.profile_id = p.id '
      'LEFT JOIN roles r ON r.id = pr.role_id '
      'WHERE p.organization_id = ? AND p.status = ? AND p.deleted_at IS NULL '
      'ORDER BY p.display_name COLLATE NOCASE',
      [workspace.organizationId, 'active'],
    );
    return rows
        .map(
          (row) => LocalProfile(
            id: row['id'] as String,
            displayName: row['display_name'] as String,
            roleCode: row['role_code'] as String? ?? 'cashier',
            roleName: row['role_name'] as String? ?? 'Cajero',
            hasPin: row['pin_hash'] != null,
          ),
        )
        .toList(growable: false);
  }

  bool hasPermission(String permissionCode, {String? profileId}) {
    final workspace = localWorkspace;
    if (workspace == null) return false;
    final rows = database.select(
      'SELECT 1 FROM profile_roles pr '
      'JOIN role_permissions rp ON rp.role_id = pr.role_id '
      'JOIN permissions p ON p.id = rp.permission_id '
      'WHERE pr.profile_id = ? AND pr.organization_id = ? AND p.code = ? '
      'LIMIT 1',
      [
        profileId ?? workspace.profileId,
        workspace.organizationId,
        permissionCode
      ],
    );
    return rows.isNotEmpty;
  }

  void requireCurrentPermission(String permissionCode) {
    final workspace = localWorkspace;
    if (workspace == null) return;
    final sessions = database.select(
      'SELECT 1 FROM local_profile_sessions WHERE terminal_id = ? '
      'AND ended_at IS NULL LIMIT 1',
      [workspace.terminalId],
    );
    if (sessions.isNotEmpty && !hasPermission(permissionCode)) {
      throw StateError('El perfil actual no tiene permiso: $permissionCode');
    }
  }

  List<String> get currentRoleCodes {
    final workspace = localWorkspace;
    if (workspace == null) return const [];
    return database
        .select(
          'SELECT r.code FROM profile_roles pr JOIN roles r ON r.id = pr.role_id '
          'WHERE pr.profile_id = ? AND pr.organization_id = ?',
          [workspace.profileId, workspace.organizationId],
        )
        .map((row) => row['code'] as String)
        .toList(growable: false);
  }

  String createLocalProfile({
    required String displayName,
    required String roleCode,
    required String pin,
  }) {
    final workspace = _requiredWorkspace();
    if (!hasPermission('profiles.manage')) {
      throw StateError('El perfil actual no puede administrar operadores');
    }
    if (!_roleNames.containsKey(roleCode)) {
      throw ArgumentError.value(roleCode, 'roleCode', 'Rol no permitido');
    }
    final name = displayName.trim();
    _validatePin(pin);
    if (name.isEmpty) throw ArgumentError('El nombre es obligatorio');
    final credentials = _hashPin(pin);
    final profileId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final role = database.select(
      'SELECT id FROM roles WHERE organization_id = ? AND code = ?',
      [workspace.organizationId, roleCode],
    );
    if (role.isEmpty) {
      throw StateError('El rol local no está configurado: $roleCode');
    }
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        'INSERT INTO profiles(id, organization_id, display_name, status, '
        'created_at, updated_at, pin_salt, pin_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          profileId,
          workspace.organizationId,
          name,
          'active',
          now,
          now,
          credentials.salt,
          credentials.hash,
        ],
      );
      database.execute(
        'INSERT INTO profile_roles(profile_id, role_id, organization_id, assigned_at) '
        'VALUES (?, ?, ?, ?)',
        [profileId, role.first['id'], workspace.organizationId, now],
      );
      _writeAuthAudit(
        profileId: workspace.profileId,
        action: 'LOCAL_PROFILE_CREATED',
        entityId: profileId,
        details: {'role': roleCode},
        occurredAt: now,
      );
      database.execute('COMMIT');
      return profileId;
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void configureInitialProfilePin({
    required String profileId,
    required String pin,
  }) {
    final workspace = _requiredWorkspace();
    _validatePin(pin);
    if (profileId != workspace.profileId) {
      throw StateError(
          'Solo puede configurarse el PIN inicial del operador actual');
    }
    final profile = database.select(
      'SELECT pin_hash FROM profiles WHERE id = ? AND organization_id = ? '
      'AND status = ?',
      [profileId, workspace.organizationId, 'active'],
    );
    if (profile.isEmpty || profile.first['pin_hash'] != null) {
      throw StateError('El PIN de este perfil ya está configurado');
    }
    final credentials = _hashPin(pin);
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute(
      'UPDATE profiles SET pin_salt = ?, pin_hash = ?, updated_at = ? WHERE id = ?',
      [credentials.salt, credentials.hash, now, profileId],
    );
    _writeAuthAudit(
      profileId: profileId,
      action: 'LOCAL_PROFILE_PIN_CONFIGURED',
      entityId: profileId,
      details: const {},
      occurredAt: now,
    );
  }

  String? authenticateLocalProfile({
    required String profileId,
    required String pin,
  }) {
    final workspace = _requiredWorkspace();
    final profile = database.select(
      'SELECT p.pin_salt, p.pin_hash FROM profiles p '
      'WHERE p.id = ? AND p.organization_id = ? AND p.status = ? '
      'AND p.deleted_at IS NULL',
      [profileId, workspace.organizationId, 'active'],
    );
    if (profile.isEmpty || profile.first['pin_hash'] == null) return null;
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(minutes: 15)).toIso8601String();
    final failures = database.select(
      'SELECT COUNT(*) AS count FROM audit_logs WHERE profile_id = ? '
      'AND action = ? AND occurred_at >= ?',
      [profileId, 'LOCAL_PROFILE_LOGIN_FAILED', cutoff],
    ).first['count'] as int;
    if (failures >= 5) return null;

    final salt = _decodeHex(profile.first['pin_salt'] as String);
    final actual = _derivePinHash(pin, salt);
    final expected = _decodeHex(profile.first['pin_hash'] as String);
    if (!_constantTimeEquals(actual, expected)) {
      _writeAuthAudit(
        profileId: profileId,
        action: 'LOCAL_PROFILE_LOGIN_FAILED',
        entityId: profileId,
        details: const {},
        occurredAt: now.toIso8601String(),
      );
      return null;
    }
    return _startProfileSession(
      profileId: profileId,
      occurredAt: now.toIso8601String(),
    );
  }

  String startDemoProfileSession(String profileId) {
    if (!isDemoMode) {
      throw StateError('El acceso automático está limitado al entorno demo');
    }
    final workspace = _requiredWorkspace();
    if (profileId != workspace.profileId) {
      throw StateError('Perfil demo inválido');
    }
    return _startProfileSession(
      profileId: profileId,
      occurredAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  void endLocalProfileSession(String sessionId, {String reason = 'logout'}) {
    final workspace = localWorkspace;
    if (workspace == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final sessions = database.select(
      'SELECT profile_id FROM local_profile_sessions WHERE id = ? '
      'AND ended_at IS NULL',
      [sessionId],
    );
    if (sessions.isEmpty) return;
    final profileId = sessions.first['profile_id'] as String;
    database.execute(
      'UPDATE local_profile_sessions SET ended_at = ?, end_reason = ? '
      'WHERE id = ? AND ended_at IS NULL',
      [now, reason, sessionId],
    );
    _writeAuthAudit(
      profileId: profileId,
      action: 'LOCAL_PROFILE_SESSION_ENDED',
      entityId: sessionId,
      details: {'reason': reason},
      occurredAt: now,
    );
  }

  bool isStationDisplayEnabled(String station) {
    final key = _stationPreferenceKey(station);
    return getLocalPreference(key) != '0';
  }

  void setStationDisplayEnabled(String station, bool enabled) {
    if (!hasPermission('settings.manage')) {
      throw StateError('El perfil actual no puede cambiar las salidas');
    }
    final key = _stationPreferenceKey(station);
    setLocalPreference(key, enabled ? '1' : '0');
  }

  String? getLocalPreference(String key) {
    final rows = database.select(
      'SELECT value FROM local_preferences WHERE key = ?',
      [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setLocalPreference(String key, String value) {
    database.execute(
      'INSERT INTO local_preferences(key, value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, '
      'updated_at = excluded.updated_at',
      [
        key,
        value,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  void initializeDemoWorkspace() {
    if (!isDemoMode) {
      throw StateError('El espacio demo requiere una base aislada');
    }
    if (localWorkspace != null) return;
    createLocalWorkspace(
      LocalWorkspaceInput(
        organizationId: 'demo-organization',
        organizationName: 'Caffè Amalfi · Entorno demo',
        branchId: 'demo-branch',
        branchName: 'Sucursal de prueba',
        terminalId: 'demo-terminal',
        terminalName: 'Terminal de demostración',
        profileId: 'demo-admin',
        profileName: 'Administrador demo',
        warehouseId: 'demo-warehouse',
        warehouseName: 'Almacén demo',
        cashRegisterId: 'demo-cash-register',
        cashRegisterName: 'Caja demo',
        profilePin: List.generate(
          8,
          (_) => Random.secure().nextInt(10),
        ).join(),
      ),
    );
    loadSyntheticDemoCatalog();
  }

  LocalWorkspace createLocalWorkspace(LocalWorkspaceInput input) {
    if (localWorkspace != null) {
      throw StateError('Local workspace is already configured');
    }
    final values = [
      input.organizationName,
      input.branchName,
      input.terminalName,
      input.profileName,
      input.warehouseName,
      input.cashRegisterName,
    ];
    if (values.any((value) => value.trim().isEmpty)) {
      throw ArgumentError('All workspace names are required');
    }
    _validatePin(input.profilePin);
    final credentials = _hashPin(input.profilePin);

    final now = DateTime.now().toUtc().toIso8601String();
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        'INSERT INTO organizations(id, name, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          input.organizationId,
          input.organizationName.trim(),
          'active',
          now,
          now
        ],
      );
      database.execute(
        'INSERT INTO branches(id, organization_id, name, code, timezone, '
        'default_currency, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          input.branchId,
          input.organizationId,
          input.branchName.trim(),
          'BRANCH-${input.branchId.substring(0, 8)}',
          'America/Caracas',
          'USD',
          'active',
          now,
          now,
        ],
      );
      database.execute(
        'INSERT INTO terminals(id, organization_id, branch_id, name, status, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          input.terminalId,
          input.organizationId,
          input.branchId,
          input.terminalName.trim(),
          'active',
          now,
          now,
        ],
      );
      database.execute(
        'INSERT INTO profiles(id, organization_id, display_name, status, created_at, updated_at, '
        'pin_salt, pin_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          input.profileId,
          input.organizationId,
          input.profileName.trim(),
          'active',
          now,
          now,
          credentials.salt,
          credentials.hash,
        ],
      );
      database.execute(
        'INSERT INTO warehouses(id, organization_id, branch_id, name, code, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          input.warehouseId,
          input.organizationId,
          input.branchId,
          input.warehouseName.trim(),
          'WAREHOUSE-${input.warehouseId.substring(0, 8)}',
          'active',
          now,
          now,
        ],
      );
      database.execute(
        'INSERT INTO cash_registers(id, organization_id, branch_id, name, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          input.cashRegisterId,
          input.organizationId,
          input.branchId,
          input.cashRegisterName.trim(),
          'active',
          now,
          now,
        ],
      );
      database.execute(
        'INSERT INTO local_setup(id, organization_id, branch_id, terminal_id, '
        'profile_id, warehouse_id, cash_register_id, created_at) '
        'VALUES (1, ?, ?, ?, ?, ?, ?, ?)',
        [
          input.organizationId,
          input.branchId,
          input.terminalId,
          input.profileId,
          input.warehouseId,
          input.cashRegisterId,
          now,
        ],
      );
      _ensureOrganizationRoles(input.organizationId, input.profileId, now);
      database.execute(
        'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, '
        'profile_id, action, entity_type, entity_id, after_json, occurred_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          input.organizationId,
          input.branchId,
          input.terminalId,
          input.profileId,
          'LOCAL_WORKSPACE_CONFIGURED',
          'terminal',
          input.terminalId,
          jsonEncode({'mode': isDemoMode ? 'isolated_demo' : 'local_only'}),
          now,
        ],
      );
      if (!isDemoMode)
        database.execute(
          'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
          'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
          'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            input.organizationId,
            'configure_local_workspace',
            input.terminalId,
            'local-workspace:${input.terminalId}',
            1,
            jsonEncode({
              'organization_id': input.organizationId,
              'organization_name': input.organizationName.trim(),
              'branch_id': input.branchId,
              'branch_name': input.branchName.trim(),
              'terminal_id': input.terminalId,
              'terminal_name': input.terminalName.trim(),
              'profile_id': input.profileId,
              'profile_name': input.profileName.trim(),
              'warehouse_id': input.warehouseId,
              'warehouse_name': input.warehouseName.trim(),
              'cash_register_id': input.cashRegisterId,
              'cash_register_name': input.cashRegisterName.trim(),
            }),
            'PENDING',
            0,
            now,
            now,
          ],
        );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
    return localWorkspace!;
  }

  List<LocalCatalogProduct> getCatalogProducts({bool offlineOnly = true}) {
    final workspace = localWorkspace;
    if (workspace == null) return const [];
    final rows = database.select(
      'SELECT p.id AS product_id, v.id AS variant_id, p.name, '
      'COALESCE(c.name, ?) AS category_name, v.sku, v.price_minor, '
      'b.quantity_minor, b.reserved_minor, p.base_currency, p.fulfillment_station, '
      'p.is_synthetic '
      'FROM products p '
      'JOIN product_variants v ON v.product_id = p.id '
      'LEFT JOIN categories c ON c.id = p.category_id '
      'LEFT JOIN inventory_balances b ON b.variant_id = v.id AND b.warehouse_id = ? '
      'WHERE p.organization_id = ? AND p.active = 1 AND v.active = 1 '
      'AND (? = 0 OR p.offline_sellable = 1) '
      'AND p.deleted_at IS NULL AND v.deleted_at IS NULL '
      'ORDER BY c.sort_order, p.name',
      [
        'Sin categoría',
        workspace.warehouseId,
        workspace.organizationId,
        offlineOnly ? 1 : 0,
      ],
    );
    return rows
        .map(
          (row) => LocalCatalogProduct(
            productId: row['product_id'] as String,
            variantId: row['variant_id'] as String,
            name: row['name'] as String,
            categoryName: row['category_name'] as String,
            sku: row['sku'] as String?,
            priceMinor: row['price_minor'] as String,
            availableQuantity: row['quantity_minor'] == null
                ? null
                : (BigInt.parse(row['quantity_minor'] as String) -
                        BigInt.parse(row['reserved_minor'] as String))
                    .toString(),
            currencyCode: row['base_currency'] as String,
            fulfillmentStation: row['fulfillment_station'] as String,
            isSynthetic: row['is_synthetic'] == 1,
          ),
        )
        .toList(growable: false);
  }

  void createLocalProduct(LocalProductInput input) {
    requireCurrentPermission('inventory.manage');
    final workspace = localWorkspace;
    if (workspace == null) {
      throw StateError('Configure the local workspace first');
    }

    if (input.name.trim().isEmpty || input.categoryName.trim().isEmpty) {
      throw ArgumentError('Product name and category are required');
    }
    final price = BigInt.parse(input.priceMinor);
    final stock = BigInt.parse(input.initialStock);
    if (price < BigInt.zero || stock < BigInt.zero) {
      throw ArgumentError('Price and initial stock must not be negative');
    }
    if (!const {'KITCHEN', 'BAR', 'UNASSIGNED'}
        .contains(input.fulfillmentStation)) {
      throw ArgumentError.value(
        input.fulfillmentStation,
        'fulfillmentStation',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute('BEGIN IMMEDIATE');
    try {
      var categoryId = input.categoryId;
      final categories = database.select(
        'SELECT id FROM categories WHERE organization_id = ? AND name = ?',
        [workspace.organizationId, input.categoryName.trim()],
      );
      if (categories.isNotEmpty) {
        categoryId = categories.first['id'] as String;
      } else {
        database.execute(
          'INSERT INTO categories(id, organization_id, name, sort_order, active, created_at, updated_at, version) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            categoryId,
            workspace.organizationId,
            input.categoryName.trim(),
            0,
            1,
            now,
            now,
            1,
          ],
        );
      }
      database.execute(
        'INSERT INTO products(id, organization_id, category_id, sku, name, '
        'base_currency, price_minor, cost_minor, offline_sellable, active, '
        'created_at, updated_at, version, fulfillment_station, is_synthetic) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          input.productId,
          workspace.organizationId,
          categoryId,
          input.sku,
          input.name.trim(),
          'USD',
          price.toString(),
          '0',
          input.offlineSellable ? 1 : 0,
          1,
          now,
          now,
          1,
          input.fulfillmentStation,
          input.isSynthetic ? 1 : 0,
        ],
      );
      database.execute(
        'INSERT INTO product_variants(id, organization_id, product_id, sku, '
        'name, price_minor, cost_minor, active, created_at, updated_at, version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          input.variantId,
          workspace.organizationId,
          input.productId,
          input.sku,
          input.name.trim(),
          price.toString(),
          '0',
          1,
          now,
          now,
          1,
        ],
      );
      database.execute(
        'INSERT INTO inventory_balances(id, organization_id, warehouse_id, '
        'variant_id, quantity_minor, reserved_minor, version, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'balance-${input.variantId}',
          workspace.organizationId,
          workspace.warehouseId,
          input.variantId,
          stock.toString(),
          '0',
          1,
          now,
        ],
      );
      if (stock > BigInt.zero) {
        database.execute(
          'INSERT INTO inventory_movements(id, organization_id, warehouse_id, '
          'variant_id, movement_type, quantity_minor, reason, source_terminal_id, '
          'idempotency_key, before_version, created_by, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            workspace.organizationId,
            workspace.warehouseId,
            input.variantId,
            'opening_balance',
            stock.toString(),
            'Initial stock entered during local catalog setup',
            workspace.terminalId,
            'initial-stock:${input.variantId}',
            0,
            workspace.profileId,
            now,
          ],
        );
      }
      database.execute(
        'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, '
        'profile_id, action, entity_type, entity_id, after_json, occurred_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          workspace.organizationId,
          workspace.branchId,
          workspace.terminalId,
          workspace.profileId,
          input.isSynthetic
              ? 'LOCAL_SYNTHETIC_PRODUCT_CREATED'
              : 'LOCAL_PRODUCT_CREATED',
          'product',
          input.productId,
          jsonEncode({
            'name': input.name.trim(),
            'price_minor': price.toString(),
            'initial_stock': stock.toString(),
            'fulfillment_station': input.fulfillmentStation,
            'synthetic': input.isSynthetic,
          }),
          now,
        ],
      );
      if (!input.isSynthetic) {
        database.execute(
          'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
          'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
          'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            workspace.organizationId,
            'create_local_product',
            input.productId,
            'local-product:${input.variantId}',
            1,
            jsonEncode({
              'product_id': input.productId,
              'variant_id': input.variantId,
              'category_id': categoryId,
              'category_name': input.categoryName.trim(),
              'name': input.name.trim(),
              'sku': input.sku,
              'currency_code': 'USD',
              'price_minor': price.toString(),
              'initial_stock': stock.toString(),
              'offline_sellable': input.offlineSellable,
              'fulfillment_station': input.fulfillmentStation,
            }),
            'PENDING',
            0,
            now,
            now,
          ],
        );
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  int loadSyntheticDemoCatalog() {
    final workspace = localWorkspace;
    if (workspace == null) {
      throw StateError('Configure the local workspace first');
    }
    final products = <LocalProductInput>[
      _demoProduct('sugar', 'Azúcar', 'Extras', '0.25', 500, 'BAR'),
      _demoProduct('sweetener', 'Edulzante', 'Extras', '0.30', 300, 'BAR'),
      _demoProduct(
          'extra-coffee', 'Extra de Café', 'Extras', '1.00', 200, 'BAR'),
      _demoProduct(
          'americano', 'Café Americano', 'Bebidas', '2.50', 100, 'BAR'),
      _demoProduct(
          'mineral-water', 'Agua Mineral', 'Aguas', '1.50', 100, 'BAR'),
      _demoProduct(
          'milk-coffee', 'Café con Leche', 'Bebidas', '3.00', 80, 'BAR'),
      _demoProduct(
          'sparkling-water', 'Agua con Gas', 'Aguas', '1.80', 80, 'BAR'),
      _demoProduct('cappuccino', 'Capuchino', 'Bebidas', '3.50', 60, 'BAR'),
      _demoProduct('black-tea', 'Té Negro', 'Bebidas', '2.00', 50, 'BAR'),
      _demoProduct(
          'orange-juice', 'Jugo de Naranja', 'Jugos', '3.00', 50, 'BAR'),
      _demoProduct('passion-fruit-juice', 'Jugo de Parchita', 'Jugos', '3.50',
          45, 'BAR'),
      _demoProduct('mango-juice', 'Jugo de Mango', 'Jugos', '3.20', 40, 'BAR'),
      _demoProduct(
          'hot-chocolate', 'Chocolate Caliente', 'Bebidas', '3.20', 40, 'BAR'),
      _demoProduct('chicken-panini', 'Panini de Pollo', 'Paninis', '5.50', 30,
          'KITCHEN'),
      _demoProduct('ham-cheese-panini', 'Panini de Jamón y Queso', 'Paninis',
          '4.50', 35, 'KITCHEN'),
      _demoProduct('vegetarian-panini', 'Panini de Vegetariano', 'Paninis',
          '5.00', 25, 'KITCHEN'),
      _demoProduct('criollo-breakfast', 'Desayuno Criollo', 'Comida', '6.00',
          20, 'KITCHEN'),
      _demoProduct('tequenos', 'Tequeños', 'Pasapalos', '3.50', 50, 'KITCHEN'),
    ];
    var loaded = 0;
    for (final product in products) {
      final exists = database.select(
        'SELECT 1 FROM products WHERE id = ? AND organization_id = ?',
        [product.productId, workspace.organizationId],
      );
      if (exists.isNotEmpty) continue;
      createLocalProduct(product);
      loaded++;
    }
    return loaded;
  }

  LocalProductInput _demoProduct(
    String key,
    String name,
    String category,
    String price,
    int stock,
    String station,
  ) =>
      LocalProductInput(
        productId: 'synthetic-demo-$key',
        variantId: 'synthetic-demo-variant-$key',
        categoryId: 'synthetic-demo-category-$category',
        categoryName: category,
        name: name,
        sku: 'DEMO-${key.toUpperCase()}',
        priceMinor: Money.parse(price, Currency.usd).minorUnits.toString(),
        initialStock: '$stock',
        offlineSellable: true,
        fulfillmentStation: station,
        isSynthetic: true,
      );

  String cashExpectedUsdMinor(String sessionId) {
    final rows = database.select(
      'SELECT opening_minor FROM cash_sessions WHERE id = ?',
      [sessionId],
    );
    if (rows.isEmpty) throw StateError('Cash session not found');
    final opening = BigInt.parse(
      (jsonDecode(rows.first['opening_minor'] as String) as Map)['USD']
          as String,
    );
    final movements = database.select(
      'SELECT movement_type, amount_minor FROM cash_movements '
      'WHERE cash_session_id = ?',
      [sessionId],
    );
    var expected = opening;
    for (final movement in movements) {
      final type = movement['movement_type'] as String;
      final amount = BigInt.parse(movement['amount_minor'] as String);
      if (type == 'income') expected += amount;
      if (type == 'expense') expected -= amount;
    }
    return expected.toString();
  }

  bool _sameBigIntMap(Map<String, BigInt> left, Map<String, BigInt> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  List<LocalSaleSummary> recentSales({int limit = 10}) {
    final workspace = localWorkspace;
    if (workspace == null) return const [];
    return database
        .select(
          'SELECT id, sale_number, total_currency, total_minor, sync_status, created_at '
          'FROM sales WHERE organization_id = ? ORDER BY created_at DESC LIMIT ?',
          [workspace.organizationId, limit],
        )
        .map(
          (row) => LocalSaleSummary(
            id: row['id'] as String,
            saleNumber: row['sale_number'] as String,
            totalCurrency: row['total_currency'] as String,
            totalMinor: row['total_minor'] as String,
            syncStatus: row['sync_status'] as String,
            createdAt: row['created_at'] as String,
          ),
        )
        .toList(growable: false);
  }

  LocalCashSession? get activeCashSession {
    final workspace = localWorkspace;
    if (workspace == null) return null;
    final rows = database.select(
      'SELECT * FROM cash_sessions WHERE cash_register_id = ? AND status = ?',
      [workspace.cashRegisterId, 'open'],
    );
    if (rows.isEmpty) return null;
    return _cashSessionFromRow(rows.first);
  }

  void recordLocalCashMovement({
    required String sessionId,
    required String type,
    required String amountUsdMinor,
    required String reason,
  }) {
    requireCurrentPermission('cash.manage');
    if (type != 'income' && type != 'expense') {
      throw ArgumentError.value(type, 'type', 'Use income or expense');
    }
    final amount = BigInt.parse(amountUsdMinor);
    if (amount <= BigInt.zero || reason.trim().isEmpty) {
      throw ArgumentError('Positive amount and reason are required');
    }
    final workspace = localWorkspace;
    if (workspace == null)
      throw StateError('Configure the local workspace first');
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();
    database.execute('BEGIN IMMEDIATE');
    try {
      final sessions = database.select(
        'SELECT id FROM cash_sessions WHERE id = ? AND organization_id = ? '
        'AND cash_register_id = ? AND terminal_id = ? AND status = ?',
        [
          sessionId,
          workspace.organizationId,
          workspace.cashRegisterId,
          workspace.terminalId,
          'open',
        ],
      );
      if (sessions.isEmpty) throw StateError('Cash session is not open here');
      final idempotencyKey = 'cash-movement:$id';
      database.execute(
        'INSERT INTO cash_movements(id, organization_id, cash_session_id, '
        'movement_type, category, amount_minor, currency_code, reason, '
        'idempotency_key, created_by, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          workspace.organizationId,
          sessionId,
          type,
          'manual',
          amount.toString(),
          'USD',
          reason.trim(),
          idempotencyKey,
          workspace.profileId,
          now,
        ],
      );
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
          'LOCAL_CASH_MOVEMENT_RECORDED',
          'cash_movement',
          id,
          jsonEncode({
            'type': type,
            'amount_usd_minor': amount.toString(),
            'reason': reason.trim(),
          }),
          now,
        ],
      );
      database.execute(
        'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
        'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          workspace.organizationId,
          'record_cash_movement',
          id,
          idempotencyKey,
          1,
          jsonEncode({
            'id': id,
            'cash_session_id': sessionId,
            'movement_type': type,
            'amount_minor': amount.toString(),
            'currency_code': 'USD',
            'reason': reason.trim(),
          }),
          'PENDING',
          0,
          now,
          now,
        ],
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  LocalCashSession openLocalCashSession({
    required String sessionId,
    required String openingUsdMinor,
  }) {
    requireCurrentPermission('cash.manage');
    final workspace = localWorkspace;
    if (workspace == null) {
      throw StateError('Configure the local workspace first');
    }
    if (activeCashSession != null) {
      throw StateError('There is already an open cash session');
    }
    final opening = BigInt.parse(openingUsdMinor);
    if (opening < BigInt.zero) {
      throw ArgumentError('Opening balance cannot be negative');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        'INSERT INTO cash_sessions(id, organization_id, cash_register_id, terminal_id, '
        'profile_id, opening_minor, status, opened_at, idempotency_key) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          sessionId,
          workspace.organizationId,
          workspace.cashRegisterId,
          workspace.terminalId,
          workspace.profileId,
          jsonEncode({'USD': opening.toString()}),
          'open',
          now,
          'open-cash:$sessionId',
        ],
      );
      database.execute(
        'INSERT INTO cash_movements(id, organization_id, cash_session_id, '
        'movement_type, category, amount_minor, currency_code, reason, '
        'idempotency_key, created_by, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          workspace.organizationId,
          sessionId,
          'opening',
          'opening_balance',
          opening.toString(),
          'USD',
          'Opening cash balance',
          'opening-cash:$sessionId',
          workspace.profileId,
          now,
        ],
      );
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
          'LOCAL_CASH_SESSION_OPENED',
          'cash_session',
          sessionId,
          jsonEncode({'opening_usd_minor': opening.toString()}),
          now,
        ],
      );
      database.execute(
        'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
        'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          workspace.organizationId,
          'open_cash_session',
          sessionId,
          'open-cash:$sessionId',
          1,
          jsonEncode({
            'cash_session_id': sessionId,
            'cash_register_id': workspace.cashRegisterId,
            'opening_usd_minor': opening.toString(),
          }),
          'PENDING',
          0,
          now,
          now,
        ],
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
    return activeCashSession!;
  }

  LocalCashSession closeLocalCashSession({
    required String sessionId,
    required String closingUsdMinor,
  }) {
    requireCurrentPermission('cash.manage');
    final amount = BigInt.parse(closingUsdMinor);
    if (amount < BigInt.zero) {
      throw ArgumentError('Closing balance cannot be negative');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute('BEGIN IMMEDIATE');
    try {
      final expected = BigInt.parse(cashExpectedUsdMinor(sessionId));
      final result = database.select(
        'UPDATE cash_sessions SET status = ?, closed_at = ?, closing_minor = ?, '
        'base_version = base_version + 1 WHERE id = ? AND status = ? RETURNING *',
        [
          'closed',
          now,
          jsonEncode({'USD': amount.toString()}),
          sessionId,
          'open'
        ],
      );
      if (result.isEmpty) throw StateError('Cash session is not open');
      final session = result.first;
      database.execute(
        'INSERT INTO cash_movements(id, organization_id, cash_session_id, '
        'movement_type, category, amount_minor, currency_code, reason, '
        'idempotency_key, created_by, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          session['organization_id'],
          sessionId,
          'closing',
          'closing_balance',
          amount.toString(),
          'USD',
          'Closing cash count',
          'closing-cash:$sessionId',
          session['profile_id'],
          now,
        ],
      );
      database.execute(
        'INSERT INTO audit_logs(id, organization_id, terminal_id, profile_id, action, '
        'entity_type, entity_id, after_json, occurred_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          session['organization_id'],
          session['terminal_id'],
          session['profile_id'],
          'LOCAL_CASH_SESSION_CLOSED',
          'cash_session',
          sessionId,
          jsonEncode({
            'expected_usd_minor': expected.toString(),
            'counted_usd_minor': amount.toString(),
            'difference_usd_minor': (amount - expected).toString(),
          }),
          now,
        ],
      );
      database.execute(
        'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
        'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          session['organization_id'],
          'close_cash_session',
          sessionId,
          'close-cash:$sessionId',
          session['base_version'],
          jsonEncode({
            'cash_session_id': sessionId,
            'expected_usd_minor': expected.toString(),
            'counted_usd_minor': amount.toString(),
            'difference_usd_minor': (amount - expected).toString(),
          }),
          'PENDING',
          0,
          now,
          now,
        ],
      );
      database.execute('COMMIT');
      return _cashSessionFromRow(
        session,
        expectedUsdMinor: expected.toString(),
        differenceUsdMinor: (amount - expected).toString(),
      );
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  LocalCashSession _cashSessionFromRow(
    Row row, {
    String? expectedUsdMinor,
    String? differenceUsdMinor,
  }) =>
      LocalCashSession(
        id: row['id'] as String,
        cashRegisterId: row['cash_register_id'] as String,
        profileId: row['profile_id'] as String,
        status: row['status'] as String,
        openingMinor: row['opening_minor'] as String,
        openedAt: row['opened_at'] as String,
        closedAt: row['closed_at'] as String?,
        closingMinor: row['closing_minor'] as String?,
        expectedUsdMinor: expectedUsdMinor,
        differenceUsdMinor: differenceUsdMinor,
      );

  String confirmSale(LocalSaleInput sale) {
    requireCurrentPermission('sales.create');
    if (sale.items.isEmpty) {
      throw const LocalSaleConflictException(
        'EMPTY_SALE',
        'A sale must contain at least one item',
      );
    }
    if (sale.payments.isEmpty) {
      throw const LocalSaleConflictException(
        'NO_PAYMENTS',
        'A sale must contain at least one payment',
      );
    }

    final total = BigInt.parse(sale.totalMinor);
    if (total <= BigInt.zero) {
      throw const LocalSaleConflictException(
        'INVALID_SALE_TOTAL',
        'Sale total must be greater than zero',
      );
    }
    var paid = BigInt.zero;
    for (final payment in sale.payments) {
      final amount = BigInt.parse(payment.amountMinor);
      if (amount <= BigInt.zero || payment.currencyCode != sale.totalCurrency) {
        throw const LocalSaleConflictException(
          'INVALID_PAYMENT',
          'Payments must be positive and use the sale currency',
        );
      }
      paid += amount;
    }
    if (paid != total) {
      throw const LocalSaleConflictException(
        'PAYMENT_TOTAL_MISMATCH',
        'Payment allocations must exactly equal the sale total',
      );
    }
    var itemTotal = BigInt.zero;
    for (final item in sale.items) {
      final quantity = BigInt.parse(item.quantity);
      final unitPrice = BigInt.parse(item.unitPriceMinor);
      final subtotal = BigInt.parse(item.subtotalMinor);
      final tax = BigInt.parse(item.taxMinor);
      if (quantity <= BigInt.zero ||
          unitPrice < BigInt.zero ||
          tax != BigInt.zero ||
          unitPrice * quantity != subtotal) {
        throw const LocalSaleConflictException(
          'INVALID_SALE_ITEM',
          'Sale items must have valid quantities and untaxed subtotals',
        );
      }
      itemTotal += subtotal;
    }
    if (itemTotal != total) {
      throw const LocalSaleConflictException(
        'SALE_TOTAL_MISMATCH',
        'Sale total must equal the untaxed item subtotal',
      );
    }

    final existing = database.select(
      'SELECT id FROM sales WHERE idempotency_key = ?',
      [sale.idempotencyKey],
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }
    for (final item in sale.items) {
      final products = database.select(
        'SELECT p.is_synthetic FROM product_variants v '
        'JOIN products p ON p.id = v.product_id WHERE v.id = ?',
        [item.variantId],
      );
      if (!isDemoMode &&
          products.isNotEmpty &&
          products.first['is_synthetic'] == 1) {
        throw const LocalSaleConflictException(
          'SYNTHETIC_PRODUCT_NOT_SYNCABLE',
          'Demonstration catalog items cannot be used for a real sale',
        );
      }
    }

    database.execute('BEGIN IMMEDIATE');
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final workspace = localWorkspace;
      if (workspace != null &&
          (sale.organizationId != workspace.organizationId ||
              sale.branchId != workspace.branchId ||
              sale.terminalId != workspace.terminalId ||
              sale.profileId != workspace.profileId)) {
        throw const LocalSaleConflictException(
          'WORKSPACE_MISMATCH',
          'Sale identity does not match the configured local terminal',
        );
      }
      if (workspace != null && sale.cashSessionId == null) {
        throw const LocalSaleConflictException(
          'CASH_SESSION_REQUIRED',
          'A local cash session is required for this sale',
        );
      }
      if (sale.cashSessionId != null) {
        final sessions = database.select(
          'SELECT id, cash_register_id, terminal_id FROM cash_sessions '
          'WHERE id = ? AND status = ?',
          [sale.cashSessionId, 'open'],
        );
        if (sessions.isEmpty ||
            (workspace != null &&
                (sessions.first['cash_register_id'] !=
                        workspace.cashRegisterId ||
                    sessions.first['terminal_id'] != workspace.terminalId))) {
          throw const LocalSaleConflictException(
            'CASH_SESSION_CLOSED',
            'Sale cannot be attached to a closed or unrelated cash session',
          );
        }
      }
      String? diningTableId;
      if (sale.diningSessionId != null) {
        final sessions = database.select(
          'SELECT s.dining_table_id FROM dining_sessions s '
          'JOIN dining_tables t ON t.id = s.dining_table_id '
          'WHERE s.id = ? AND s.organization_id = ? AND s.terminal_id = ? '
          'AND s.status = ? AND t.status IN (?, ?)',
          [
            sale.diningSessionId,
            sale.organizationId,
            sale.terminalId,
            'OPEN',
            'OCCUPIED',
            'PREBILL',
          ],
        );
        if (sessions.isEmpty) {
          throw const LocalSaleConflictException(
            'DINING_SESSION_CLOSED',
            'Table sale requires an open session on this terminal',
          );
        }
        diningTableId = sessions.first['dining_table_id'] as String;
        final expectedItems = database.select(
          'SELECT variant_id, unit_price_minor, quantity FROM dining_session_items '
          'WHERE dining_session_id = ? AND status != ?',
          [sale.diningSessionId, 'CANCELLED'],
        );
        final expectedLines = <String, BigInt>{};
        final expectedReservations = <String, BigInt>{};
        var expectedTotal = BigInt.zero;
        for (final item in expectedItems) {
          final variantId = item['variant_id'] as String;
          final quantity = BigInt.parse(item['quantity'] as String);
          final price = item['unit_price_minor'] as String;
          final key = '$variantId|$price';
          expectedLines.update(
            key,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
          expectedReservations.update(
            variantId,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
          expectedTotal += quantity * BigInt.parse(price);
        }
        final saleLines = <String, BigInt>{};
        for (final item in sale.items) {
          final key = '${item.variantId}|${item.unitPriceMinor}';
          final quantity = BigInt.parse(item.quantity);
          saleLines.update(
            key,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
        final saleReservations = <String, BigInt>{};
        for (final consumption in sale.inventoryConsumptions) {
          final quantity = BigInt.parse(consumption.quantity);
          final reserved = BigInt.parse(consumption.reservedQuantity);
          if (quantity != reserved) {
            throw const LocalSaleConflictException(
              'DINING_RESERVATION_MISMATCH',
              'Table sales must consume their full stock reservations',
            );
          }
          saleReservations.update(
            consumption.variantId,
            (value) => value + reserved,
            ifAbsent: () => reserved,
          );
        }
        if (!_sameBigIntMap(expectedLines, saleLines) ||
            !_sameBigIntMap(expectedReservations, saleReservations) ||
            sale.totalCurrency != 'USD' ||
            expectedTotal != total) {
          throw const LocalSaleConflictException(
            'DINING_SESSION_CONTENT_MISMATCH',
            'Table checkout must include the exact current session items',
          );
        }
      }
      database.execute(
        'INSERT INTO sales(id, organization_id, branch_id, terminal_id, '
        'profile_id, cash_session_id, sale_number, status, sale_kind, '
        'total_currency, total_minor, exchange_rate_snapshot_id, beta_origin_id, '
        'idempotency_key, base_version, sync_status, created_by, created_at, updated_at, '
        'dining_session_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          sale.id,
          sale.organizationId,
          sale.branchId,
          sale.terminalId,
          sale.profileId,
          sale.cashSessionId,
          sale.saleNumber,
          'paid',
          sale.diningSessionId == null ? 'direct' : 'table',
          sale.totalCurrency,
          sale.totalMinor,
          sale.exchangeRateSnapshotId,
          sale.betaOriginId,
          sale.idempotencyKey,
          1,
          'PENDING',
          sale.profileId,
          now,
          now,
          sale.diningSessionId,
        ],
      );

      for (final item in sale.items) {
        final quantity = BigInt.parse(item.quantity);
        if (quantity <= BigInt.zero) {
          throw const LocalSaleConflictException(
            'INVALID_ITEM_QUANTITY',
            'Item quantity must be greater than zero',
          );
        }
        database.execute(
          'INSERT INTO sale_items(id, organization_id, sale_id, variant_id, '
          'quantity, unit_price_minor, subtotal_minor, tax_minor, line_currency, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            sale.organizationId,
            sale.id,
            item.variantId,
            item.quantity,
            item.unitPriceMinor,
            item.subtotalMinor,
            item.taxMinor,
            sale.totalCurrency,
            now,
          ],
        );
      }

      for (final consumption in sale.inventoryConsumptions) {
        final quantity = BigInt.parse(consumption.quantity);
        if (quantity <= BigInt.zero) {
          throw const LocalSaleConflictException(
            'INVALID_INVENTORY_QUANTITY',
            'Inventory consumption must be greater than zero',
          );
        }
        final productPolicy = database.select(
          'SELECT p.offline_sellable, p.active, v.active AS variant_active '
          'FROM product_variants v JOIN products p ON p.id = v.product_id '
          'WHERE v.id = ? AND v.organization_id = ? '
          'AND p.deleted_at IS NULL AND v.deleted_at IS NULL',
          [consumption.variantId, sale.organizationId],
        );
        if (productPolicy.isEmpty ||
            productPolicy.first['offline_sellable'] != 1 ||
            productPolicy.first['active'] != 1 ||
            productPolicy.first['variant_active'] != 1) {
          throw LocalSaleConflictException(
            'OFFLINE_SALE_NOT_ALLOWED',
            'Product ${consumption.variantId} is not enabled for offline sales',
          );
        }
        final balances = database.select(
          'SELECT id, quantity_minor, reserved_minor, version '
          'FROM inventory_balances '
          'WHERE warehouse_id = ? AND variant_id = ?',
          [consumption.warehouseId, consumption.variantId],
        );
        if (balances.isEmpty) {
          throw LocalSaleConflictException(
            'INVENTORY_BALANCE_NOT_FOUND',
            'No known balance for ${consumption.variantId} '
                'at ${consumption.warehouseId}',
          );
        }

        final balance = balances.first;
        final knownQuantity = BigInt.parse(balance['quantity_minor'] as String);
        final reserved = BigInt.parse(balance['reserved_minor'] as String);
        final reservedToConsume = BigInt.parse(consumption.reservedQuantity);
        if (reservedToConsume < BigInt.zero || reservedToConsume > reserved) {
          throw LocalSaleConflictException(
            'INVALID_INVENTORY_RESERVATION',
            'Invalid stock reservation for ${consumption.variantId}',
          );
        }
        final available = knownQuantity - reserved + reservedToConsume;
        if (available < quantity) {
          throw LocalSaleConflictException(
            'INSUFFICIENT_OFFLINE_STOCK',
            'Available ${consumption.variantId}: $available, '
                'requested: $quantity',
          );
        }

        final remaining = knownQuantity - quantity;
        final remainingReserved = reserved - reservedToConsume;
        final nextVersion = (balance['version'] as int) + 1;
        database.execute(
          'UPDATE inventory_balances SET quantity_minor = ?, '
          'reserved_minor = ?, version = ?, updated_at = ? '
          'WHERE id = ?',
          [
            remaining.toString(),
            remainingReserved.toString(),
            nextVersion,
            now,
            balance['id'] as String,
          ],
        );
        database.execute(
          'INSERT INTO inventory_movements(id, organization_id, warehouse_id, '
          'variant_id, sale_id, movement_type, quantity_minor, reason, '
          'source_terminal_id, idempotency_key, before_version, created_by, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            sale.organizationId,
            consumption.warehouseId,
            consumption.variantId,
            sale.id,
            'sale',
            (-quantity).toString(),
            'Local confirmed sale',
            sale.terminalId,
            '${sale.idempotencyKey}:inventory:${consumption.warehouseId}:${consumption.variantId}',
            balance['version'] as int,
            sale.profileId,
            now,
          ],
        );
      }

      for (final payment in sale.payments) {
        if (BigInt.parse(payment.amountMinor) <= BigInt.zero) {
          throw const LocalSaleConflictException(
            'INVALID_PAYMENT',
            'Payment amount must be greater than zero',
          );
        }
        final paymentIdempotency =
            '${sale.idempotencyKey}:payment:${payment.method}:${payment.currencyCode}';
        database.execute(
          'INSERT INTO payments(id, organization_id, sale_id, method, '
          'amount_minor, currency_code, exchange_rate_snapshot_id, '
          'original_amount_minor, original_currency_code, reference, '
          'status, idempotency_key, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            sale.organizationId,
            sale.id,
            payment.method,
            payment.amountMinor,
            payment.currencyCode,
            payment.exchangeRateSnapshotId,
            payment.originalAmountMinor,
            payment.originalCurrencyCode,
            payment.reference,
            'confirmed',
            paymentIdempotency,
            now,
          ],
        );
        if (payment.method == 'CASH_USD' && sale.cashSessionId != null) {
          database.execute(
            'INSERT INTO cash_movements(id, organization_id, cash_session_id, '
            'movement_type, category, amount_minor, currency_code, sale_id, '
            'reason, idempotency_key, created_by, created_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              const Uuid().v4(),
              sale.organizationId,
              sale.cashSessionId,
              'income',
              'sale',
              payment.originalAmountMinor,
              payment.originalCurrencyCode,
              sale.id,
              'Cash payment for ${sale.saleNumber}',
              '$paymentIdempotency:cash-movement',
              sale.profileId,
              now,
            ],
          );
        }
      }

      database.execute(
        'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, '
        'profile_id, action, entity_type, entity_id, reason, after_json, occurred_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          sale.organizationId,
          sale.branchId,
          sale.terminalId,
          sale.profileId,
          'SALE_CONFIRMED_LOCAL',
          'sale',
          sale.id,
          null,
          jsonEncode({
            'id': sale.id,
            'idempotency_key': sale.idempotencyKey,
            'total_minor': sale.totalMinor,
            'total_currency': sale.totalCurrency,
            'beta_origin_id': sale.betaOriginId,
          }),
          now,
        ],
      );

      database.execute(
        'INSERT INTO sync_outbox(id, organization_id, operation_type, '
        'entity_id, idempotency_key, base_version, payload_json, sync_status, '
        'attempt_count, next_attempt_at, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          sale.organizationId,
          'confirm_sale',
          sale.id,
          sale.idempotencyKey,
          1,
          jsonEncode({
            'sale': {
              'id': sale.id,
              'sale_number': sale.saleNumber,
              'total_minor': sale.totalMinor,
              'total_currency': sale.totalCurrency,
              'exchange_rate_snapshot_id': sale.exchangeRateSnapshotId,
              'beta_origin_id': sale.betaOriginId,
              'dining_session_id': sale.diningSessionId,
            },
          }),
          'PENDING',
          0,
          null,
          now,
          now,
        ],
      );

      if (sale.diningSessionId != null) {
        database.execute(
          'UPDATE dining_sessions SET status = ?, closed_at = ?, '
          'base_version = base_version + 1 WHERE id = ? AND status = ?',
          ['CLOSED', now, sale.diningSessionId, 'OPEN'],
        );
        database.execute(
          'UPDATE dining_tables SET status = ?, updated_at = ? WHERE id = ?',
          ['FREE', now, diningTableId],
        );
        database.execute(
          'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, profile_id, '
          'action, entity_type, entity_id, after_json, occurred_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            const Uuid().v4(),
            sale.organizationId,
            sale.branchId,
            sale.terminalId,
            sale.profileId,
            'LOCAL_DINING_SESSION_CLOSED',
            'dining_session',
            sale.diningSessionId,
            jsonEncode({'sale_id': sale.id}),
            now,
          ],
        );
      }

      database.execute('COMMIT');
      return sale.id;
    } on LocalSaleConflictException {
      database.execute('ROLLBACK');
      rethrow;
    } catch (error) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void setInventoryBalance({
    required String organizationId,
    required String warehouseId,
    required String variantId,
    required String quantityMinor,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute(
      'INSERT INTO inventory_balances(id, organization_id, warehouse_id, '
      'variant_id, quantity_minor, reserved_minor, version, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(warehouse_id, variant_id) DO UPDATE SET '
      'quantity_minor = excluded.quantity_minor, '
      'reserved_minor = inventory_balances.reserved_minor, '
      'version = inventory_balances.version + 1, '
      'updated_at = excluded.updated_at',
      [
        'balance-$warehouseId-$variantId',
        organizationId,
        warehouseId,
        variantId,
        quantityMinor,
        '0',
        1,
        now,
      ],
    );
  }

  String adjustLocalInventory({
    required String variantId,
    required String quantityDelta,
    required String reason,
  }) {
    requireCurrentPermission('inventory.manage');
    final workspace = localWorkspace;
    if (workspace == null) {
      throw StateError('Configure the local workspace first');
    }
    final delta = BigInt.parse(quantityDelta);
    final trimmedReason = reason.trim();
    if (delta == BigInt.zero || trimmedReason.isEmpty) {
      throw ArgumentError('A non-zero adjustment and reason are required');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final movementId = const Uuid().v4();
    database.execute('BEGIN IMMEDIATE');
    try {
      final productRows = database.select(
        'SELECT p.is_synthetic FROM product_variants v '
        'JOIN products p ON p.id = v.product_id '
        'WHERE v.id = ? AND p.organization_id = ?',
        [variantId, workspace.organizationId],
      );
      if (productRows.isEmpty) throw StateError('Product variant not found');
      if (!isDemoMode && productRows.first['is_synthetic'] == 1) {
        throw StateError('Demonstration catalog stock cannot be adjusted');
      }
      final balances = database.select(
        'SELECT id, quantity_minor, reserved_minor, version FROM inventory_balances '
        'WHERE organization_id = ? AND warehouse_id = ? AND variant_id = ?',
        [
          workspace.organizationId,
          workspace.warehouseId,
          variantId,
        ],
      );
      if (balances.isEmpty) {
        throw StateError(
            'Inventory balance is not configured for this product');
      }
      final balance = balances.first;
      final current = BigInt.parse(balance['quantity_minor'] as String);
      final reserved = BigInt.parse(balance['reserved_minor'] as String);
      final next = current + delta;
      if (next < reserved) {
        throw StateError('Adjustment cannot reduce stock below reserved units');
      }
      final nextVersion = (balance['version'] as int) + 1;
      database.execute(
        'UPDATE inventory_balances SET quantity_minor = ?, version = ?, updated_at = ? '
        'WHERE id = ? AND version = ?',
        [
          next.toString(),
          nextVersion,
          now,
          balance['id'],
          balance['version'],
        ],
      );
      final idempotencyKey = 'inventory-adjust:$movementId';
      database.execute(
        'INSERT INTO inventory_movements(id, organization_id, warehouse_id, '
        'variant_id, movement_type, quantity_minor, reason, source_terminal_id, '
        'idempotency_key, before_version, created_by, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          movementId,
          workspace.organizationId,
          workspace.warehouseId,
          variantId,
          'stock_adjustment',
          delta.toString(),
          trimmedReason,
          workspace.terminalId,
          idempotencyKey,
          balance['version'],
          workspace.profileId,
          now,
        ],
      );
      database.execute(
        'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, profile_id, '
        'action, entity_type, entity_id, reason, after_json, occurred_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          workspace.organizationId,
          workspace.branchId,
          workspace.terminalId,
          workspace.profileId,
          'LOCAL_INVENTORY_ADJUSTED',
          'inventory_balance',
          balance['id'],
          trimmedReason,
          jsonEncode({
            'variant_id': variantId,
            'before_quantity': current.toString(),
            'quantity_delta': delta.toString(),
            'after_quantity': next.toString(),
          }),
          now,
        ],
      );
      database.execute(
        'INSERT INTO sync_outbox(id, organization_id, operation_type, entity_id, '
        'idempotency_key, base_version, payload_json, sync_status, attempt_count, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v4(),
          workspace.organizationId,
          'adjust_inventory',
          movementId,
          idempotencyKey,
          nextVersion,
          jsonEncode({
            'movement_id': movementId,
            'warehouse_id': workspace.warehouseId,
            'variant_id': variantId,
            'quantity_delta': delta.toString(),
            'reason': trimmedReason,
          }),
          'PENDING',
          0,
          now,
          now,
        ],
      );
      database.execute('COMMIT');
      return next.toString();
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  String inventoryQuantity({
    required String warehouseId,
    required String variantId,
  }) {
    final rows = database.select(
      'SELECT quantity_minor FROM inventory_balances '
      'WHERE warehouse_id = ? AND variant_id = ?',
      [warehouseId, variantId],
    );
    return rows.isEmpty ? '0' : rows.first['quantity_minor'] as String;
  }

  int tableCount(String table) {
    final allowed = {
      'sales',
      'sale_items',
      'payments',
      'inventory_movements',
      'inventory_balances',
      'categories',
      'products',
      'profiles',
      'audit_logs',
      'sync_outbox',
      'sync_receipts',
      'sync_errors',
      'cash_sessions',
      'cash_movements',
    };
    if (!allowed.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Table is not allowed');
    }
    return database
        .select('SELECT COUNT(*) AS value FROM $table')
        .first['value'] as int;
  }

  void seedOrganization({
    required String organizationId,
    required String branchId,
    required String terminalId,
    required String profileId,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute(
      'INSERT OR IGNORE INTO organizations(id, name, status, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [organizationId, 'Synthetic Organization', 'active', now, now],
    );
    database.execute(
      'INSERT OR IGNORE INTO branches(id, organization_id, name, code, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [branchId, organizationId, 'Synthetic Branch', 'TEST', now, now],
    );
    database.execute(
      'INSERT OR IGNORE INTO terminals(id, organization_id, branch_id, name, status, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        terminalId,
        organizationId,
        branchId,
        'Synthetic Terminal',
        'active',
        now,
        now
      ],
    );
    database.execute(
      'INSERT OR IGNORE INTO profiles(id, organization_id, display_name, status, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [profileId, organizationId, 'Synthetic Profile', 'active', now, now],
    );
  }

  void seedVariant({
    required String organizationId,
    required String variantId,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final productId = 'synthetic-product-$variantId';
    database.execute(
      'INSERT OR IGNORE INTO products(id, organization_id, name, base_currency, '
      'offline_sellable, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [productId, organizationId, 'Synthetic Product', 'USD', 1, now, now],
    );
    database.execute(
      'INSERT OR IGNORE INTO product_variants(id, organization_id, product_id, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [variantId, organizationId, productId, 'Synthetic Variant', now, now],
    );
  }

  void seedWarehouse({
    required String organizationId,
    required String branchId,
    required String warehouseId,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.execute(
      'INSERT OR IGNORE INTO warehouses(id, organization_id, branch_id, name, code, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        warehouseId,
        organizationId,
        branchId,
        'Synthetic Warehouse',
        'TEST',
        now,
        now
      ],
    );
  }

  LocalWorkspace _requiredWorkspace() {
    final workspace = localWorkspace;
    if (workspace == null) {
      throw StateError('Configure the local workspace first');
    }
    return workspace;
  }

  String _startProfileSession({
    required String profileId,
    required String occurredAt,
  }) {
    final workspace = _requiredWorkspace();
    final sessionId = const Uuid().v4();
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        'UPDATE local_profile_sessions SET ended_at = ?, end_reason = ? '
        'WHERE terminal_id = ? AND ended_at IS NULL',
        [occurredAt, 'replaced', workspace.terminalId],
      );
      database.execute(
        'UPDATE local_setup SET profile_id = ? WHERE id = 1',
        [profileId],
      );
      database.execute(
        'INSERT INTO local_profile_sessions(id, profile_id, terminal_id, started_at) '
        'VALUES (?, ?, ?, ?)',
        [sessionId, profileId, workspace.terminalId, occurredAt],
      );
      _writeAuthAudit(
        profileId: profileId,
        action: 'LOCAL_PROFILE_SESSION_STARTED',
        entityId: sessionId,
        details: const {},
        occurredAt: occurredAt,
      );
      database.execute('COMMIT');
      return sessionId;
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _writeAuthAudit({
    required String profileId,
    required String action,
    required String entityId,
    required Map<String, Object?> details,
    required String occurredAt,
  }) {
    final workspace = localWorkspace;
    if (workspace == null) return;
    database.execute(
      'INSERT INTO audit_logs(id, organization_id, branch_id, terminal_id, '
      'profile_id, action, entity_type, entity_id, after_json, occurred_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        const Uuid().v4(),
        workspace.organizationId,
        workspace.branchId,
        workspace.terminalId,
        profileId,
        action,
        action.startsWith('LOCAL_PROFILE_LOGIN')
            ? 'profile'
            : 'profile_session',
        entityId,
        jsonEncode(details),
        occurredAt,
      ],
    );
  }

  void _ensureExistingWorkspaceRoles() {
    final rows = database.select(
      'SELECT organization_id, profile_id FROM local_setup WHERE id = 1',
    );
    if (rows.isEmpty) return;
    _ensureOrganizationRoles(
      rows.first['organization_id'] as String,
      rows.first['profile_id'] as String,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  void _ensureOrganizationRoles(
    String organizationId,
    String initialProfileId,
    String now,
  ) {
    const descriptions = {
      'dashboard.view': 'Consultar el resumen operativo',
      'tables.manage': 'Administrar mesas y cuentas',
      'sales.create': 'Registrar ventas y pagos',
      'production.view': 'Consultar comandas de cocina y barra',
      'production.send': 'Enviar comandas a las estaciones',
      'production.update': 'Actualizar estados de producción',
      'inventory.manage': 'Administrar catálogo e inventario',
      'cash.manage': 'Administrar caja y cierres',
      'reports.view': 'Consultar reportes',
      'audit.view': 'Consultar auditoría',
      'settings.manage': 'Administrar configuración y perfiles',
      'profiles.manage': 'Crear perfiles locales',
    };
    for (final entry in descriptions.entries) {
      database.execute(
        'INSERT OR IGNORE INTO permissions(id, code, description, created_at) '
        'VALUES (?, ?, ?, ?)',
        [const Uuid().v4(), entry.key, entry.value, now],
      );
    }

    final roleIds = <String, String>{};
    for (final entry in _roleNames.entries) {
      final existing = database.select(
        'SELECT id FROM roles WHERE organization_id = ? AND code = ?',
        [organizationId, entry.key],
      );
      final roleId =
          existing.isEmpty ? const Uuid().v4() : existing.first['id'] as String;
      if (existing.isEmpty) {
        database.execute(
          'INSERT INTO roles(id, organization_id, code, name, is_system, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [roleId, organizationId, entry.key, entry.value, 1, now, now],
        );
      }
      roleIds[entry.key] = roleId;

      for (final permissionCode in _rolePermissions[entry.key]!) {
        final permission = database.select(
          'SELECT id FROM permissions WHERE code = ?',
          [permissionCode],
        );
        database.execute(
          'INSERT OR IGNORE INTO role_permissions(role_id, permission_id, scope) '
          'VALUES (?, ?, ?)',
          [roleId, permission.first['id'], 'branch'],
        );
      }
    }

    final assignments = database.select(
      'SELECT 1 FROM profile_roles WHERE profile_id = ? LIMIT 1',
      [initialProfileId],
    );
    if (assignments.isEmpty) {
      database.execute(
        'INSERT INTO profile_roles(profile_id, role_id, organization_id, assigned_at) '
        'VALUES (?, ?, ?, ?)',
        [initialProfileId, roleIds['admin'], organizationId, now],
      );
    }
  }

  static ({String salt, String hash}) _hashPin(String pin) {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return (
      salt: _encodeHex(bytes),
      hash: _encodeHex(_derivePinHash(pin, bytes))
    );
  }

  static List<int> _derivePinHash(String pin, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final output = List<int>.from(block);
    for (var iteration = 1; iteration < _pinIterations; iteration++) {
      block = hmac.convert(block).bytes;
      for (var index = 0; index < output.length; index++) {
        output[index] ^= block[index];
      }
    }
    return output;
  }

  static void _validatePin(String pin) {
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(pin)) {
      throw ArgumentError('El PIN debe tener entre 4 y 8 dígitos');
    }
  }

  static String _encodeHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _decodeHex(String value) => [
        for (var index = 0; index < value.length; index += 2)
          int.parse(value.substring(index, index + 2), radix: 16),
      ];

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static String _stationPreferenceKey(String station) => switch (station) {
        'KITCHEN' => 'station_display_kitchen',
        'BAR' => 'station_display_bar',
        _ =>
          throw ArgumentError.value(station, 'station', 'Use KITCHEN or BAR'),
      };
}
