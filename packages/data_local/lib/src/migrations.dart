import 'package:sqlite3/sqlite3.dart';

typedef SQLiteMigration = ({int version, String name, String sql});

class SQLiteMigrations {
  SQLiteMigrations(this.database);

  final Database database;

  static final migrations = <SQLiteMigration>[
    (
      version: 1,
      name: '0001_initial_commercial_schema',
      sql: r'''
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  checksum TEXT NOT NULL,
  applied_at TEXT NOT NULL
);

CREATE TABLE organizations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  tax_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE branches (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'America/Caracas',
  default_currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  UNIQUE (organization_id, code)
);

CREATE TABLE terminals (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  branch_id TEXT NOT NULL,
  name TEXT NOT NULL,
  public_key TEXT,
  platform TEXT,
  app_version TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  last_seen_at TEXT,
  revoked_at TEXT,
  beta_origin_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id)
);

CREATE TABLE warehouses (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  branch_id TEXT NOT NULL,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id),
  UNIQUE (branch_id, code)
);

CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id)
);

CREATE TABLE roles (
  id TEXT PRIMARY KEY,
  organization_id TEXT,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  is_system INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (organization_id, code)
);

CREATE TABLE permissions (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE profile_roles (
  profile_id TEXT NOT NULL,
  role_id TEXT NOT NULL,
  organization_id TEXT NOT NULL,
  assigned_at TEXT NOT NULL,
  PRIMARY KEY (profile_id, role_id),
  FOREIGN KEY (profile_id) REFERENCES profiles(id),
  FOREIGN KEY (role_id) REFERENCES roles(id)
);

CREATE TABLE role_permissions (
  role_id TEXT NOT NULL,
  permission_id TEXT NOT NULL,
  scope TEXT NOT NULL DEFAULT 'branch',
  PRIMARY KEY (role_id, permission_id),
  FOREIGN KEY (role_id) REFERENCES roles(id),
  FOREIGN KEY (permission_id) REFERENCES permissions(id)
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  parent_id TEXT,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  beta_origin_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (parent_id) REFERENCES categories(id)
);

CREATE TABLE products (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  category_id TEXT,
  sku TEXT,
  name TEXT NOT NULL,
  description TEXT,
  base_currency TEXT NOT NULL DEFAULT 'USD',
  price_minor TEXT NOT NULL DEFAULT '0',
  cost_minor TEXT NOT NULL DEFAULT '0',
  offline_sellable INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  beta_origin_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (category_id) REFERENCES categories(id),
  UNIQUE (organization_id, sku)
);

CREATE TABLE product_variants (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  sku TEXT,
  name TEXT,
  price_minor TEXT NOT NULL DEFAULT '0',
  cost_minor TEXT NOT NULL DEFAULT '0',
  active INTEGER NOT NULL DEFAULT 1,
  beta_origin_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (product_id) REFERENCES products(id),
  UNIQUE (organization_id, sku)
);

CREATE TABLE inventory_balances (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  warehouse_id TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  quantity_minor TEXT NOT NULL DEFAULT '0',
  reserved_minor TEXT NOT NULL DEFAULT '0',
  version INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(id),
  UNIQUE (warehouse_id, variant_id)
);

CREATE TABLE inventory_movements (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  warehouse_id TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  sale_id TEXT,
  movement_type TEXT NOT NULL,
  quantity_minor TEXT NOT NULL,
  unit_cost_minor TEXT NOT NULL DEFAULT '0',
  reason TEXT,
  source_terminal_id TEXT,
  source_beta_id TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  before_version INTEGER,
  created_by TEXT,
  created_at TEXT NOT NULL,
  synced_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(id),
  FOREIGN KEY (sale_id) REFERENCES sales(id)
);

CREATE TABLE sales (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  branch_id TEXT NOT NULL,
  terminal_id TEXT NOT NULL,
  profile_id TEXT,
  cash_session_id TEXT,
  sale_number TEXT,
  status TEXT NOT NULL,
  sale_kind TEXT NOT NULL DEFAULT 'direct',
  total_currency TEXT NOT NULL,
  total_minor TEXT NOT NULL,
  exchange_rate_snapshot_id TEXT,
  beta_origin_id TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  base_version INTEGER NOT NULL DEFAULT 1,
  sync_status TEXT NOT NULL DEFAULT 'PENDING',
  created_by TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  closed_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id),
  FOREIGN KEY (terminal_id) REFERENCES terminals(id),
  FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

CREATE TABLE sale_items (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  sale_id TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  quantity TEXT NOT NULL,
  unit_price_minor TEXT NOT NULL,
  subtotal_minor TEXT NOT NULL,
  tax_minor TEXT NOT NULL DEFAULT '0',
  line_currency TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (sale_id) REFERENCES sales(id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(id)
);

CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  sale_id TEXT NOT NULL,
  method TEXT NOT NULL,
  amount_minor TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  exchange_rate_snapshot_id TEXT,
  original_amount_minor TEXT NOT NULL,
  original_currency_code TEXT NOT NULL,
  reference TEXT,
  status TEXT NOT NULL DEFAULT 'confirmed',
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (sale_id) REFERENCES sales(id)
);

CREATE TABLE cash_registers (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  branch_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id)
);

CREATE TABLE cash_sessions (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  cash_register_id TEXT NOT NULL,
  terminal_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  opening_minor TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'open',
  opened_at TEXT NOT NULL,
  closed_at TEXT,
  closing_minor TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  base_version INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (cash_register_id) REFERENCES cash_registers(id),
  FOREIGN KEY (terminal_id) REFERENCES terminals(id),
  FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

CREATE TABLE cash_movements (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  cash_session_id TEXT NOT NULL,
  movement_type TEXT NOT NULL,
  category TEXT NOT NULL,
  amount_minor TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  sale_id TEXT,
  reason TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  created_by TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (cash_session_id) REFERENCES cash_sessions(id),
  FOREIGN KEY (sale_id) REFERENCES sales(id)
);

CREATE TABLE exchange_rates (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  base_currency TEXT NOT NULL,
  quote_currency TEXT NOT NULL,
  rate_numerator TEXT NOT NULL,
  rate_denominator TEXT NOT NULL,
  effective_from TEXT NOT NULL,
  effective_to TEXT,
  source TEXT NOT NULL,
  source_reference TEXT,
  created_at TEXT NOT NULL,
  created_by TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  UNIQUE (organization_id, base_currency, quote_currency, effective_from)
);

CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  branch_id TEXT,
  terminal_id TEXT,
  profile_id TEXT,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  reason TEXT,
  before_json TEXT,
  after_json TEXT,
  occurred_at TEXT NOT NULL,
  immutable_hash TEXT,
  FOREIGN KEY (organization_id) REFERENCES organizations(id)
);

CREATE TABLE sync_outbox (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  base_version INTEGER NOT NULL DEFAULT 1,
  payload_json TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'PENDING',
  attempt_count INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT,
  last_error_code TEXT,
  last_error_message TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE sync_receipts (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  terminal_id TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  operation_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  result_status TEXT NOT NULL,
  remote_version INTEGER,
  payload_hash TEXT,
  received_at TEXT NOT NULL
);

CREATE TABLE sync_events (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  terminal_id TEXT,
  operation_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_cursor TEXT,
  base_version INTEGER,
  payload_json TEXT,
  received_at TEXT NOT NULL,
  UNIQUE (idempotency_key, entity_id)
);

CREATE TABLE sync_cursors (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  terminal_id TEXT NOT NULL,
  stream TEXT NOT NULL,
  cursor TEXT,
  updated_at TEXT NOT NULL,
  UNIQUE (terminal_id, stream)
);

CREATE TABLE sync_errors (
  id TEXT PRIMARY KEY,
  outbox_id TEXT,
  organization_id TEXT NOT NULL,
  terminal_id TEXT,
  operation_type TEXT,
  error_code TEXT NOT NULL,
  error_message TEXT NOT NULL,
  payload_hash TEXT,
  occurred_at TEXT NOT NULL,
  FOREIGN KEY (outbox_id) REFERENCES sync_outbox(id)
);

CREATE INDEX idx_sales_org_branch_created
  ON sales(organization_id, branch_id, created_at);
CREATE INDEX idx_inventory_movements_org_sale
  ON inventory_movements(organization_id, sale_id);
CREATE INDEX idx_payments_sale
  ON payments(sale_id);
CREATE INDEX idx_outbox_status_attempt
  ON sync_outbox(sync_status, next_attempt_at);
CREATE INDEX idx_audit_entity
  ON audit_logs(entity_type, entity_id, occurred_at);
CREATE INDEX idx_exchange_rate_effective
  ON exchange_rates(organization_id, effective_from, effective_to);
''',
    ),
    (
      version: 2,
      name: '0002_local_workspace_configuration',
      sql: r'''
CREATE TABLE local_setup (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  organization_id TEXT NOT NULL,
  branch_id TEXT NOT NULL,
  terminal_id TEXT NOT NULL UNIQUE,
  profile_id TEXT NOT NULL,
  warehouse_id TEXT NOT NULL,
  cash_register_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id),
  FOREIGN KEY (terminal_id) REFERENCES terminals(id),
  FOREIGN KEY (profile_id) REFERENCES profiles(id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
  FOREIGN KEY (cash_register_id) REFERENCES cash_registers(id)
);

CREATE UNIQUE INDEX idx_one_open_cash_session_per_register
  ON cash_sessions(cash_register_id)
  WHERE status = 'open';
''',
    ),
    (
      version: 3,
      name: '0003_local_tables_orders_and_stations',
      sql: r'''
CREATE TABLE dining_tables (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  branch_id TEXT NOT NULL,
  name TEXT NOT NULL,
  capacity INTEGER NOT NULL CHECK (capacity > 0),
  status TEXT NOT NULL DEFAULT 'FREE'
    CHECK (status IN ('FREE', 'OCCUPIED', 'PREBILL')),
  active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id),
  UNIQUE (branch_id, name)
);

CREATE TABLE dining_sessions (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  dining_table_id TEXT NOT NULL,
  terminal_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
  opened_at TEXT NOT NULL,
  closed_at TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  base_version INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (dining_table_id) REFERENCES dining_tables(id),
  FOREIGN KEY (terminal_id) REFERENCES terminals(id),
  FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

CREATE UNIQUE INDEX idx_one_open_dining_session_per_table
  ON dining_sessions(dining_table_id) WHERE status = 'OPEN';

CREATE TABLE dining_session_items (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  dining_session_id TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity TEXT NOT NULL,
  unit_price_minor TEXT NOT NULL,
  currency_code TEXT NOT NULL DEFAULT 'USD',
  fulfillment_station TEXT NOT NULL
    CHECK (fulfillment_station IN ('KITCHEN', 'BAR')),
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'UNSENT'
    CHECK (status IN ('UNSENT', 'PENDING', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED')),
  sent_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (dining_session_id) REFERENCES dining_sessions(id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(id)
);

CREATE TABLE production_orders (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  dining_session_id TEXT NOT NULL,
  dining_table_id TEXT NOT NULL,
  order_number TEXT NOT NULL,
  station TEXT NOT NULL CHECK (station IN ('KITCHEN', 'BAR')),
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED')),
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  ready_at TEXT,
  delivered_at TEXT,
  base_version INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (dining_session_id) REFERENCES dining_sessions(id),
  FOREIGN KEY (dining_table_id) REFERENCES dining_tables(id),
  FOREIGN KEY (created_by) REFERENCES profiles(id)
);

CREATE TABLE production_order_items (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  production_order_id TEXT NOT NULL,
  dining_session_item_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  FOREIGN KEY (production_order_id) REFERENCES production_orders(id),
  FOREIGN KEY (dining_session_item_id) REFERENCES dining_session_items(id)
);

ALTER TABLE products ADD COLUMN fulfillment_station TEXT NOT NULL
  DEFAULT 'UNASSIGNED'
  CHECK (fulfillment_station IN ('KITCHEN', 'BAR', 'UNASSIGNED'));
ALTER TABLE sales ADD COLUMN dining_session_id TEXT
  REFERENCES dining_sessions(id);

CREATE INDEX idx_dining_tables_status
  ON dining_tables(branch_id, status, sort_order);
CREATE INDEX idx_dining_items_session
  ON dining_session_items(dining_session_id, status);
CREATE INDEX idx_production_orders_queue
  ON production_orders(organization_id, station, status, created_at);
''',
    ),
    (
      version: 4,
      name: '0004_synthetic_demo_catalog',
      sql: r'''
ALTER TABLE products ADD COLUMN is_synthetic INTEGER NOT NULL DEFAULT 0
  CHECK (is_synthetic IN (0, 1));
CREATE INDEX idx_products_synthetic
  ON products(organization_id, is_synthetic, active);
''',
    ),
    (
      version: 5,
      name: '0005_local_profiles_and_station_preferences',
      sql: r'''
ALTER TABLE profiles ADD COLUMN pin_salt TEXT;
ALTER TABLE profiles ADD COLUMN pin_hash TEXT;

CREATE TABLE local_profile_sessions (
  id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  terminal_id TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  end_reason TEXT,
  FOREIGN KEY (profile_id) REFERENCES profiles(id),
  FOREIGN KEY (terminal_id) REFERENCES terminals(id)
);

CREATE INDEX idx_local_profile_sessions_profile
  ON local_profile_sessions(profile_id, started_at);

CREATE TABLE local_preferences (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_auth_failures
  ON audit_logs(profile_id, action, occurred_at);
''',
    ),
    (
      version: 6,
      name: '0006_local_session_expiry_and_revocation',
      sql: r'''
ALTER TABLE local_profile_sessions ADD COLUMN expires_at TEXT;
ALTER TABLE local_profile_sessions ADD COLUMN revoked_at TEXT;

CREATE INDEX idx_local_profile_sessions_active
  ON local_profile_sessions(terminal_id, ended_at, revoked_at, expires_at);
''',
    ),
  ];

  Future<void> migrate() async {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA journal_mode = WAL');
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute(
      'CREATE TABLE IF NOT EXISTS schema_migrations ('
      'version INTEGER PRIMARY KEY, name TEXT NOT NULL, '
      'checksum TEXT NOT NULL, applied_at TEXT NOT NULL)',
    );

    for (final migration in migrations) {
      final existing = database.select(
        'SELECT 1 FROM schema_migrations WHERE version = ?',
        [migration.version],
      );
      if (existing.isNotEmpty) continue;

      database.execute('BEGIN');
      try {
        for (final statement
            in migration.sql.split(';').map((value) => value.trim()).where(
                  (value) => value.isNotEmpty,
                )) {
          database.execute('$statement;');
        }
        database.execute(
          'INSERT INTO schema_migrations(version, name, checksum, applied_at) '
          'VALUES (?, ?, ?, ?)',
          [
            migration.version,
            migration.name,
            migration.name.hashCode.toString(),
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
        database.execute('COMMIT');
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
    }

    final latest = migrations.isEmpty
        ? 0
        : migrations.map((migration) => migration.version).reduce(
              (value, element) => value > element ? value : element,
            );
    database.execute('PRAGMA user_version = $latest');
  }

  int get userVersion {
    final row = database.select('PRAGMA user_version').first;
    return row.values.first as int;
  }

  int get migrationCount {
    return database
        .select('SELECT COUNT(*) AS count FROM schema_migrations')
        .first['count'] as int;
  }
}
