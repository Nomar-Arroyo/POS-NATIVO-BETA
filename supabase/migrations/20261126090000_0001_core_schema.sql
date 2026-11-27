-- 0001: esquema base de Café Amalfi POS.
-- Convenciones: UUID, timestamptz UTC, importes BIGINT en unidades menores,
-- cantidades NUMERIC(18,3), catálogos con deleted_at, operaciones append-only.

create extension if not exists pgcrypto with schema extensions;
create schema if not exists app;

create or replace function app.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  if to_jsonb(new) ? 'version' then
    new.version := coalesce((to_jsonb(old)->>'version')::bigint, 0) + 1;
  end if;
  return new;
end;
$$;

-- Identidad organizacional -------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tax_id text,
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  name text not null,
  code text not null,
  timezone text not null default 'America/Caracas',
  default_currency text not null default 'USD' check (length(default_currency) = 3),
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz,
  unique (organization_id, code)
);

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  name text not null,
  code text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz,
  unique (organization_id, code)
);

create table public.terminals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  name text not null,
  token_hash text,
  platform text,
  app_version text,
  status text not null default 'active' check (status in ('active', 'revoked')),
  registered_at timestamptz not null default now(),
  last_seen_at timestamptz,
  revoked_at timestamptz,
  beta_origin_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (organization_id, name)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  display_name text not null,
  status text not null default 'active' check (status in ('active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index idx_profiles_org on public.profiles(organization_id) where deleted_at is null;

-- Roles y permisos --------------------------------------------------------

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  description text,
  created_at timestamptz not null default now()
);

create table public.profile_roles (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  assigned_by uuid references public.profiles(id),
  assigned_at timestamptz not null default now(),
  primary key (profile_id, role_id)
);

create index idx_profile_roles_role on public.profile_roles(role_id);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  scope text not null default 'branch' check (scope in ('organization', 'branch')),
  primary key (role_id, permission_id)
);

-- Caja y tasas -------------------------------------------------------------

create table public.cash_registers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  name text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz,
  unique (branch_id, name)
);

create table public.cash_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  cash_register_id uuid not null references public.cash_registers(id),
  terminal_id uuid not null references public.terminals(id),
  profile_id uuid not null references public.profiles(id),
  opening_minor jsonb not null default '{}'::jsonb,
  closing_minor jsonb,
  status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  expected_usd_minor bigint,
  difference_usd_minor bigint,
  idempotency_key text not null,
  base_version bigint not null default 1,
  unique (organization_id, idempotency_key)
);

create unique index uq_cash_sessions_open_register
  on public.cash_sessions(cash_register_id) where status = 'OPEN';

create table public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  cash_session_id uuid not null references public.cash_sessions(id),
  movement_type text not null check (movement_type in ('income', 'expense', 'adjustment')),
  category text not null default 'sale',
  amount_minor bigint not null,
  currency_code text not null check (length(currency_code) = 3),
  sale_id uuid,
  reason text,
  idempotency_key text not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create index idx_cash_movements_session on public.cash_movements(cash_session_id, created_at);

create table public.exchange_rates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  base_currency text not null check (length(base_currency) = 3),
  quote_currency text not null check (length(quote_currency) = 3),
  rate_numerator bigint not null check (rate_numerator > 0),
  rate_denominator bigint not null default 1 check (rate_denominator > 0),
  rate_minor_units bigint,
  effective_from timestamptz not null,
  effective_to timestamptz,
  source text not null,
  source_reference text,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id),
  unique (organization_id, base_currency, quote_currency, effective_from)
);

create index idx_rates_effective
  on public.exchange_rates(organization_id, base_currency, quote_currency, effective_from desc);

-- Catálogo ----------------------------------------------------------------

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  parent_id uuid references public.categories(id),
  name text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  beta_origin_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz,
  unique (organization_id, name)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  category_id uuid references public.categories(id),
  sku text,
  name text not null,
  description text,
  base_currency text not null default 'USD' check (length(base_currency) = 3),
  price_minor bigint not null default 0 check (price_minor >= 0),
  cost_minor bigint not null default 0 check (cost_minor >= 0),
  offline_sellable boolean not null default true,
  fulfillment_station text not null default 'UNASSIGNED'
    check (fulfillment_station in ('KITCHEN', 'BAR', 'UNASSIGNED')),
  is_synthetic boolean not null default false,
  active boolean not null default true,
  beta_origin_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create unique index uq_products_org_sku on public.products(organization_id, sku)
  where sku is not null;
create index idx_products_org_active on public.products(organization_id, active) where deleted_at is null;

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  product_id uuid not null references public.products(id) on delete cascade,
  sku text,
  name text not null default 'Default',
  price_minor bigint not null default 0 check (price_minor >= 0),
  cost_minor bigint not null default 0 check (cost_minor >= 0),
  active boolean not null default true,
  beta_origin_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create unique index uq_variants_org_sku on public.product_variants(organization_id, sku)
  where sku is not null;
create index idx_variants_product on public.product_variants(product_id) where deleted_at is null;

create table public.product_modifiers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  product_id uuid not null references public.products(id) on delete cascade,
  group_name text not null default 'Opciones',
  name text not null,
  price_delta_minor bigint not null default 0,
  min_select integer not null default 0 check (min_select >= 0),
  max_select integer not null default 1 check (max_select >= min_select),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create index idx_modifiers_product on public.product_modifiers(product_id) where deleted_at is null;

-- Inventario --------------------------------------------------------------

create table public.inventory_balances (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  warehouse_id uuid not null references public.warehouses(id),
  variant_id uuid not null references public.product_variants(id),
  quantity_minor bigint not null default 0 check (quantity_minor >= 0),
  reserved_minor bigint not null default 0 check (reserved_minor >= 0),
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  unique (warehouse_id, variant_id),
  check (reserved_minor <= quantity_minor)
);

create index idx_balances_variant on public.inventory_balances(variant_id);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  warehouse_id uuid not null references public.warehouses(id),
  variant_id uuid not null references public.product_variants(id),
  sale_id uuid,
  customer_order_id uuid,
  movement_type text not null check (movement_type in
    ('SALE_CONSUMPTION', 'ADJUSTMENT', 'RECEIPT', 'RESERVATION', 'RELEASE')),
  quantity_minor bigint not null,
  unit_cost_minor bigint,
  reason text,
  source_terminal_id uuid references public.terminals(id),
  source_beta_id text,
  idempotency_key text not null,
  before_version bigint,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  synced_at timestamptz,
  unique (organization_id, idempotency_key)
);

create index idx_movements_variant on public.inventory_movements(warehouse_id, variant_id, created_at);

create table public.inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  warehouse_id uuid not null references public.warehouses(id),
  variant_id uuid not null references public.product_variants(id),
  customer_order_id uuid,
  quantity_minor bigint not null check (quantity_minor > 0),
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'RELEASED', 'CONSUMED', 'EXPIRED')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  released_at timestamptz
);

create index idx_reservations_order on public.inventory_reservations(customer_order_id);
create index idx_reservations_active on public.inventory_reservations(expires_at)
  where status = 'ACTIVE';

-- Salón y producción ------------------------------------------------------

create table public.dining_tables (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  name text not null,
  capacity integer not null default 1 check (capacity > 0),
  status text not null default 'FREE' check (status in ('FREE', 'OCCUPIED', 'RESERVED')),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (branch_id, name)
);

create table public.dining_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  dining_table_id uuid not null references public.dining_tables(id),
  terminal_id uuid references public.terminals(id),
  profile_id uuid references public.profiles(id),
  customer_device_id uuid,
  status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  sale_id uuid,
  idempotency_key text not null,
  base_version bigint not null default 1,
  unique (organization_id, idempotency_key)
);

create unique index uq_dining_sessions_open_table
  on public.dining_sessions(dining_table_id) where status = 'OPEN';

create table public.dining_session_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  dining_session_id uuid not null references public.dining_sessions(id) on delete cascade,
  variant_id uuid not null references public.product_variants(id),
  product_name text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  currency_code text not null check (length(currency_code) = 3),
  fulfillment_station text not null default 'UNASSIGNED'
    check (fulfillment_station in ('KITCHEN', 'BAR', 'UNASSIGNED')),
  notes text,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'SENT', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED')),
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_session_items_session on public.dining_session_items(dining_session_id, created_at);

create table public.production_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  dining_session_id uuid not null references public.dining_sessions(id),
  dining_table_id uuid not null references public.dining_tables(id),
  customer_order_id uuid,
  order_number text not null,
  station text not null check (station in ('KITCHEN', 'BAR')),
  status text not null default 'PENDING'
    check (status in ('PENDING', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  ready_at timestamptz,
  delivered_at timestamptz,
  base_version bigint not null default 1
);

create index idx_production_open on public.production_orders(organization_id, station, status);

create table public.production_order_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  production_order_id uuid not null references public.production_orders(id) on delete cascade,
  dining_session_item_id uuid not null unique
    references public.dining_session_items(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Ventas, pagos y auditoría ----------------------------------------------

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  terminal_id uuid not null references public.terminals(id),
  cash_session_id uuid references public.cash_sessions(id),
  dining_session_id uuid references public.dining_sessions(id),
  sale_number text not null,
  status text not null default 'paid'
    check (status in ('open', 'paid', 'void_pending', 'voided', 'sync_conflict', 'closed')),
  sale_kind text not null default 'direct' check (sale_kind in ('direct', 'dining')),
  total_currency text not null check (length(total_currency) = 3),
  total_minor bigint not null check (total_minor >= 0),
  exchange_rate_snapshot_id uuid,
  beta_origin_id text,
  idempotency_key text not null,
  base_version bigint not null default 1,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  unique (organization_id, idempotency_key)
);

create index idx_sales_org_created on public.sales(organization_id, created_at desc);
create index idx_sales_dining_session on public.sales(dining_session_id);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  sale_id uuid not null references public.sales(id) on delete cascade,
  variant_id uuid not null references public.product_variants(id),
  product_name text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null default 0 check (tax_minor >= 0),
  line_currency text not null check (length(line_currency) = 3),
  created_at timestamptz not null default now()
);

create index idx_sale_items_sale on public.sale_items(sale_id);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  sale_id uuid not null references public.sales(id) on delete cascade,
  method text not null,
  amount_minor bigint not null check (amount_minor > 0),
  currency_code text not null check (length(currency_code) = 3),
  exchange_rate_snapshot_id uuid,
  original_amount_minor bigint not null check (original_amount_minor > 0),
  original_currency_code text not null check (length(original_currency_code) = 3),
  reference text,
  status text not null default 'confirmed'
    check (status in ('pending', 'confirmed', 'voided', 'failed')),
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create index idx_payments_sale on public.payments(sale_id);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  terminal_id uuid references public.terminals(id),
  profile_id uuid references public.profiles(id),
  customer_device_id uuid,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  reason text,
  before_json jsonb,
  after_json jsonb,
  occurred_at timestamptz not null default now()
);

create index idx_audit_entity on public.audit_logs(organization_id, entity_type, occurred_at desc);

create or replace function app.reject_mutation() returns trigger
language plpgsql as $$
begin
  raise exception 'APPEND_ONLY: % no admite %', tg_table_name, tg_op
    using errcode = 'P0001';
end;
$$;

create trigger audit_logs_append_only
  before update or delete on public.audit_logs
  for each row execute function app.reject_mutation();

create trigger inventory_movements_append_only
  before update or delete on public.inventory_movements
  for each row execute function app.reject_mutation();

-- Sincronización ----------------------------------------------------------

create table public.sync_operations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  terminal_id uuid references public.terminals(id),
  operation_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  idempotency_key text not null,
  schema_version text not null,
  payload jsonb not null,
  status text not null default 'APPLIED' check (status in ('APPLIED', 'CONFLICT', 'REJECTED')),
  conflict_code text,
  applied_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create index idx_sync_operations_org on public.sync_operations(organization_id, created_at desc);

create table public.sync_receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  terminal_id uuid references public.terminals(id),
  sync_operation_id uuid not null references public.sync_operations(id),
  idempotency_key text not null,
  operation_type text not null,
  entity_id uuid not null,
  result_status text not null default 'accepted' check (result_status in ('accepted', 'rejected')),
  remote_version bigint not null default 1,
  payload_hash text,
  accepted boolean not null default true,
  received_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create table public.sync_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  terminal_id uuid references public.terminals(id),
  operation_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  idempotency_key text,
  event_type text not null,
  event_cursor text,
  base_version bigint,
  payload jsonb,
  received_at timestamptz not null default now(),
  unique (idempotency_key, entity_id)
);

create trigger sync_events_append_only
  before update or delete on public.sync_events
  for each row execute function app.reject_mutation();

-- Tablets de cliente ------------------------------------------------------

create table public.customer_devices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  label text not null,
  device_fingerprint_hash text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'REVOKED')),
  paired_at timestamptz not null default now(),
  revoked_at timestamptz,
  last_seen_at timestamptz,
  unique (organization_id, device_fingerprint_hash)
);

create table public.device_pairing_codes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  dining_table_id uuid not null references public.dining_tables(id),
  code_hash text not null,
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'USED', 'EXPIRED', 'REVOKED')),
  expires_at timestamptz not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  used_at timestamptz,
  claimed_device_id uuid references public.customer_devices(id)
);

create unique index uq_pairing_active_code
  on public.device_pairing_codes(code_hash) where status = 'ACTIVE';
create index idx_pairing_expiry on public.device_pairing_codes(expires_at) where status = 'ACTIVE';

create table public.customer_device_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_device_id uuid not null references public.customer_devices(id) on delete cascade,
  token_hash text not null unique,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'REVOKED', 'EXPIRED')),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  last_seen_at timestamptz
);

create table public.customer_table_bindings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_device_id uuid not null references public.customer_devices(id) on delete cascade,
  dining_table_id uuid not null references public.dining_tables(id),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'REVOKED')),
  bound_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index uq_active_device_binding
  on public.customer_table_bindings(customer_device_id) where status = 'ACTIVE';

create table public.customer_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  customer_device_id uuid not null references public.customer_devices(id),
  dining_table_id uuid not null references public.dining_tables(id),
  dining_session_id uuid not null references public.dining_sessions(id),
  order_number text not null,
  status text not null default 'RECEIVED'
    check (status in ('RECEIVED', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED')),
  total_currency text not null check (length(total_currency) = 3),
  total_minor bigint not null check (total_minor >= 0),
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create index idx_customer_orders_session on public.customer_orders(dining_session_id, created_at);

create table public.customer_order_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_order_id uuid not null references public.customer_orders(id) on delete cascade,
  variant_id uuid not null references public.product_variants(id),
  product_name text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  line_currency text not null check (length(line_currency) = 3),
  notes text,
  created_at timestamptz not null default now()
);

create table public.customer_order_modifiers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_order_item_id uuid not null
    references public.customer_order_items(id) on delete cascade,
  modifier_id uuid not null references public.product_modifiers(id),
  modifier_name text not null,
  price_delta_minor bigint not null default 0,
  created_at timestamptz not null default now()
);

-- Triggers de versión en catálogos y configuración -----------------------

create trigger organizations_touch before update on public.organizations
  for each row execute function app.touch_updated_at();
create trigger branches_touch before update on public.branches
  for each row execute function app.touch_updated_at();
create trigger warehouses_touch before update on public.warehouses
  for each row execute function app.touch_updated_at();
create trigger terminals_touch before update on public.terminals
  for each row execute function app.touch_updated_at();
create trigger profiles_touch before update on public.profiles
  for each row execute function app.touch_updated_at();
create trigger categories_touch before update on public.categories
  for each row execute function app.touch_updated_at();
create trigger products_touch before update on public.products
  for each row execute function app.touch_updated_at();
create trigger variants_touch before update on public.product_variants
  for each row execute function app.touch_updated_at();
create trigger modifiers_touch before update on public.product_modifiers
  for each row execute function app.touch_updated_at();
create trigger cash_registers_touch before update on public.cash_registers
  for each row execute function app.touch_updated_at();
create trigger dining_tables_touch before update on public.dining_tables
  for each row execute function app.touch_updated_at();
create trigger customers_orders_touch before update on public.customer_orders
  for each row execute function app.touch_updated_at();