-- 0002: identidad, permisos, RLS y endurecimiento de privilegios.
-- Modelo: lecturas por RLS y permiso; escrituras solo por RPC SECURITY DEFINER.

create table public.profile_branches (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  primary key (profile_id, branch_id)
);

-- Helpers de identidad -----------------------------------------------------

create or replace function app.current_profile_id() returns uuid
language sql stable security definer
set search_path = public, pg_temp
as $$
  select p.id
  from public.profiles p
  where p.id = auth.uid()
    and p.status = 'active'
    and p.deleted_at is null
  limit 1;
$$;

create or replace function app.current_organization_id() returns uuid
language sql stable security definer
set search_path = public, pg_temp
as $$
  select p.organization_id
  from public.profiles p
  where p.id = app.current_profile_id()
  limit 1;
$$;

create or replace function app.has_permission_in(p_organization uuid, p_code text)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profile_roles pr
    join public.role_permissions rp on rp.role_id = pr.role_id
    join public.permissions p on p.id = rp.permission_id
    where pr.profile_id = app.current_profile_id()
      and pr.organization_id = p_organization
      and p.code = p_code
  );
$$;

create or replace function app.has_permission(p_code text) returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select app.has_permission_in(app.current_organization_id(), p_code);
$$;

create or replace function app.branch_allowed(p_organization uuid, p_branch uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    app.has_permission_in(p_organization, 'org.read')
    and (
      not exists (
        select 1 from public.profile_branches pb
        where pb.profile_id = app.current_profile_id()
          and pb.organization_id = p_organization
      )
      or exists (
        select 1 from public.profile_branches pb
        where pb.profile_id = app.current_profile_id()
          and pb.organization_id = p_organization
          and pb.branch_id = p_branch
      )
    );
$$;

create or replace function app.assert_permission(p_code text) returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if not app.has_permission(p_code) then
    raise exception 'FORBIDDEN: permiso % requerido', p_code
      using errcode = 'P0001', hint = 'FORBIDDEN';
  end if;
end;
$$;

create or replace function app.require_profile() returns uuid
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.current_profile_id();
begin
  if v_profile is null then
    raise exception 'UNAUTHENTICATED: perfil activo requerido'
      using errcode = 'P0001', hint = 'UNAUTHENTICATED';
  end if;
  return v_profile;
end;
$$;

create or replace function app.conflict(p_code text, p_message text) returns void
language plpgsql as $$
begin
  raise exception '%: %', p_code, p_message
    using errcode = 'P0001', hint = p_code;
end;
$$;

create or replace function app.assert_active_terminal(p_terminal uuid, p_branch uuid)
returns void
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.terminals t
    where t.id = p_terminal
      and t.organization_id = app.current_organization_id()
      and t.branch_id = p_branch
      and t.status = 'active'
  ) then
    perform app.conflict('TERMINAL_INVALID', 'Terminal inexistente, de otra sucursal o revocado');
  end if;
end;
$$;

create or replace function app.lookup_receipt(p_organization uuid, p_key text)
returns jsonb
language sql stable security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'accepted', true,
    'duplicate', true,
    'operation_id', o.id,
    'operation_type', o.operation_type,
    'entity_id', o.entity_id,
    'idempotency_key', o.idempotency_key,
    'remote_version', r.remote_version,
    'applied_at', o.applied_at
  )
  from public.sync_receipts r
  join public.sync_operations o on o.id = r.sync_operation_id
  where r.organization_id = p_organization
    and r.idempotency_key = p_key
    and r.accepted
  limit 1;
$$;

create or replace function app.record_receipt(
  p_organization uuid,
  p_terminal uuid,
  p_operation_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_idempotency_key text,
  p_schema_version text,
  p_payload jsonb,
  p_remote_version bigint default 1
) returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_operation uuid;
begin
  insert into public.sync_operations(
    organization_id, terminal_id, operation_type, entity_type, entity_id,
    idempotency_key, schema_version, payload, status, applied_at
  ) values (
    p_organization, p_terminal, p_operation_type, p_entity_type, p_entity_id,
    p_idempotency_key, p_schema_version, coalesce(p_payload, '{}'::jsonb),
    'APPLIED', now()
  ) returning id into v_operation;

  insert into public.sync_receipts(
    organization_id, terminal_id, sync_operation_id, idempotency_key,
    operation_type, entity_id, result_status, remote_version, accepted
  ) values (
    p_organization, p_terminal, v_operation, p_idempotency_key,
    p_operation_type, p_entity_id, 'accepted', p_remote_version, true
  );

  return jsonb_build_object(
    'accepted', true,
    'duplicate', false,
    'operation_id', v_operation,
    'operation_type', p_operation_type,
    'entity_id', p_entity_id,
    'idempotency_key', p_idempotency_key,
    'remote_version', p_remote_version,
    'applied_at', now()
  );
end;
$$;

create or replace function app.write_audit(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_branch uuid default null,
  p_terminal uuid default null,
  p_profile uuid default null,
  p_device uuid default null,
  p_reason text default null,
  p_before jsonb default null,
  p_after jsonb default null
) returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.audit_logs(
    organization_id, branch_id, terminal_id, profile_id, customer_device_id,
    action, entity_type, entity_id, reason, before_json, after_json, occurred_at
  ) values (
    app.current_organization_id(), p_branch, p_terminal, p_profile, p_device,
    p_action, p_entity_type, p_entity_id, p_reason, p_before, p_after, now()
  );
end;
$$;

-- Instalación de roles y permisos -----------------------------------------

create or replace function app.install_default_roles(p_organization uuid)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.permissions(code, description) values
    ('org.read', 'Ver datos básicos de la organización'),
    ('settings.read', 'Ver configuración, terminales y perfiles'),
    ('settings.manage', 'Administrar configuración, terminales y sucursales'),
    ('profiles.read', 'Ver perfiles de la organización'),
    ('profiles.manage', 'Crear y administrar perfiles y roles'),
    ('devices.manage', 'Emparejar y revocar tablets de clientes'),
    ('catalog.read', 'Ver catálogo y precios'),
    ('catalog.manage', 'Administrar catálogo y modificadores'),
    ('inventory.read', 'Ver existencias y movimientos'),
    ('inventory.manage', 'Ajustar inventario'),
    ('cash.read', 'Ver caja y movimientos'),
    ('cash.manage', 'Abrir, cerrar y ajustar caja'),
    ('tables.read', 'Ver mesas y sesiones'),
    ('tables.manage', 'Abrir y cerrar mesas y comandas'),
    ('sales.read', 'Ver ventas y pagos'),
    ('sales.create', 'Confirmar ventas y pagos'),
    ('production.read', 'Ver comandas de cocina y barra'),
    ('production.send', 'Enviar comandas a producción'),
    ('production.update', 'Actualizar estados de producción'),
    ('audit.read', 'Ver auditoría'),
    ('reports.read', 'Ver reportes'),
    ('sync.read', 'Ver operaciones y recibos de sincronización')
  on conflict (code) do nothing;

  insert into public.roles(organization_id, code, name, is_system) values
    (p_organization, 'org_admin', 'Administrador', true),
    (p_organization, 'manager', 'Gerente', true),
    (p_organization, 'cashier', 'Cajero', true),
    (p_organization, 'waiter', 'Mesonero', true),
    (p_organization, 'kitchen', 'Cocina', true),
    (p_organization, 'bar', 'Barra', true)
  on conflict (organization_id, code) do nothing;

  insert into public.role_permissions(role_id, permission_id, scope)
  select r.id, p.id, 'organization'
  from (values
    ('org_admin', 'org.read'), ('org_admin', 'settings.read'),
    ('org_admin', 'settings.manage'), ('org_admin', 'profiles.read'),
    ('org_admin', 'profiles.manage'), ('org_admin', 'devices.manage'),
    ('org_admin', 'catalog.read'), ('org_admin', 'catalog.manage'),
    ('org_admin', 'inventory.read'), ('org_admin', 'inventory.manage'),
    ('org_admin', 'cash.read'), ('org_admin', 'cash.manage'),
    ('org_admin', 'tables.read'), ('org_admin', 'tables.manage'),
    ('org_admin', 'sales.read'), ('org_admin', 'sales.create'),
    ('org_admin', 'production.read'), ('org_admin', 'production.send'),
    ('org_admin', 'production.update'), ('org_admin', 'audit.read'),
    ('org_admin', 'reports.read'), ('org_admin', 'sync.read'),
    ('manager', 'org.read'), ('manager', 'settings.read'),
    ('manager', 'settings.manage'), ('manager', 'profiles.read'),
    ('manager', 'devices.manage'), ('manager', 'catalog.read'),
    ('manager', 'catalog.manage'), ('manager', 'inventory.read'),
    ('manager', 'inventory.manage'), ('manager', 'cash.read'),
    ('manager', 'cash.manage'), ('manager', 'tables.read'),
    ('manager', 'tables.manage'), ('manager', 'sales.read'),
    ('manager', 'sales.create'), ('manager', 'production.read'),
    ('manager', 'production.send'), ('manager', 'production.update'),
    ('manager', 'audit.read'), ('manager', 'reports.read'),
    ('manager', 'sync.read'),
    ('cashier', 'org.read'), ('cashier', 'settings.read'),
    ('cashier', 'profiles.read'), ('cashier', 'catalog.read'),
    ('cashier', 'inventory.read'), ('cashier', 'cash.read'),
    ('cashier', 'cash.manage'), ('cashier', 'tables.read'),
    ('cashier', 'sales.read'), ('cashier', 'sales.create'),
    ('cashier', 'production.read'),
    ('waiter', 'org.read'), ('waiter', 'settings.read'),
    ('waiter', 'profiles.read'), ('waiter', 'catalog.read'),
    ('waiter', 'tables.read'), ('waiter', 'tables.manage'),
    ('waiter', 'sales.read'), ('waiter', 'sales.create'),
    ('waiter', 'production.read'), ('waiter', 'production.send'),
    ('kitchen', 'org.read'), ('kitchen', 'settings.read'),
    ('kitchen', 'profiles.read'), ('kitchen', 'catalog.read'),
    ('kitchen', 'tables.read'), ('kitchen', 'production.read'),
    ('kitchen', 'production.update'),
    ('bar', 'org.read'), ('bar', 'settings.read'),
    ('bar', 'profiles.read'), ('bar', 'catalog.read'),
    ('bar', 'tables.read'), ('bar', 'production.read'),
    ('bar', 'production.update')
  ) as v(role_code, permission_code)
  join public.roles r
    on r.organization_id = p_organization and r.code = v.role_code
  join public.permissions p on p.code = v.permission_code
  on conflict do nothing;
end;
$$;

-- RLS ---------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.branches enable row level security;
alter table public.warehouses enable row level security;
alter table public.terminals enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_branches enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.profile_roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.cash_registers enable row level security;
alter table public.cash_sessions enable row level security;
alter table public.cash_movements enable row level security;
alter table public.exchange_rates enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_modifiers enable row level security;
alter table public.inventory_balances enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.inventory_reservations enable row level security;
alter table public.dining_tables enable row level security;
alter table public.dining_sessions enable row level security;
alter table public.dining_session_items enable row level security;
alter table public.production_orders enable row level security;
alter table public.production_order_items enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;
alter table public.audit_logs enable row level security;
alter table public.sync_operations enable row level security;
alter table public.sync_receipts enable row level security;
alter table public.sync_events enable row level security;
alter table public.customer_devices enable row level security;
alter table public.device_pairing_codes enable row level security;
alter table public.customer_device_sessions enable row level security;
alter table public.customer_table_bindings enable row level security;
alter table public.customer_orders enable row level security;
alter table public.customer_order_items enable row level security;
alter table public.customer_order_modifiers enable row level security;

create policy organizations_select on public.organizations
  for select to authenticated
  using (id = app.current_organization_id()
         and app.has_permission_in(id, 'org.read'));

create policy branches_select on public.branches
  for select to authenticated
  using (app.branch_allowed(organization_id, id)
         and app.has_permission_in(organization_id, 'settings.read'));

create policy warehouses_select on public.warehouses
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'settings.read'));

create policy terminals_select on public.terminals
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'settings.read'));

create policy profiles_self_select on public.profiles
  for select to authenticated
  using (id = app.current_profile_id());

create policy profiles_staff_select on public.profiles
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'profiles.read'));

create policy profile_branches_select on public.profile_branches
  for select to authenticated
  using ((profile_id = app.current_profile_id()
          or app.has_permission_in(organization_id, 'settings.read'))
         and organization_id = app.current_organization_id());

create policy roles_select on public.roles
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'settings.read'));

create policy permissions_select on public.permissions
  for select to authenticated
  using (app.current_profile_id() is not null);

create policy profile_roles_select on public.profile_roles
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and (profile_id = app.current_profile_id()
              or app.has_permission_in(organization_id, 'settings.read')));

create policy role_permissions_select on public.role_permissions
  for select to authenticated
  using (exists (
    select 1 from public.roles r
    where r.id = role_id
      and r.organization_id = app.current_organization_id()
      and app.has_permission_in(r.organization_id, 'settings.read')
  ));

create policy cash_registers_select on public.cash_registers
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'cash.read'));

create policy cash_sessions_select on public.cash_sessions
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'cash.read'));

create policy cash_movements_select on public.cash_movements
  for select to authenticated
  using (app.has_permission_in(organization_id, 'cash.read')
         and exists (
           select 1 from public.cash_sessions cs
           where cs.id = cash_session_id
             and app.branch_allowed(cs.organization_id, cs.branch_id)
         ));

create policy exchange_rates_select on public.exchange_rates
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'settings.read'));

create policy categories_select on public.categories
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'catalog.read'));

create policy products_select on public.products
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'catalog.read'));

create policy product_variants_select on public.product_variants
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'catalog.read'));

create policy product_modifiers_select on public.product_modifiers
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'catalog.read'));

create policy inventory_balances_select on public.inventory_balances
  for select to authenticated
  using (app.has_permission_in(organization_id, 'inventory.read')
         and exists (
           select 1 from public.warehouses w
           where w.id = warehouse_id
             and app.branch_allowed(w.organization_id, w.branch_id)
         ));

create policy inventory_movements_select on public.inventory_movements
  for select to authenticated
  using (app.has_permission_in(organization_id, 'inventory.read')
         and exists (
           select 1 from public.warehouses w
           where w.id = warehouse_id
             and app.branch_allowed(w.organization_id, w.branch_id)
         ));

create policy inventory_reservations_select on public.inventory_reservations
  for select to authenticated
  using (app.has_permission_in(organization_id, 'inventory.read')
         and exists (
           select 1 from public.warehouses w
           where w.id = warehouse_id
             and app.branch_allowed(w.organization_id, w.branch_id)
         ));

create policy dining_tables_select on public.dining_tables
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'tables.read'));

create policy dining_sessions_select on public.dining_sessions
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'tables.read'));

create policy dining_session_items_select on public.dining_session_items
  for select to authenticated
  using (app.has_permission_in(organization_id, 'tables.read')
         and exists (
           select 1 from public.dining_sessions ds
           where ds.id = dining_session_id
             and app.branch_allowed(ds.organization_id, ds.branch_id)
         ));

create policy production_orders_select on public.production_orders
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'production.read'));

create policy production_order_items_select on public.production_order_items
  for select to authenticated
  using (app.has_permission_in(organization_id, 'production.read')
         and exists (
           select 1 from public.production_orders po
           where po.id = production_order_id
             and app.branch_allowed(po.organization_id, po.branch_id)
         ));

create policy sales_select on public.sales
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'sales.read'));

create policy sale_items_select on public.sale_items
  for select to authenticated
  using (app.has_permission_in(organization_id, 'sales.read')
         and exists (
           select 1 from public.sales s
           where s.id = sale_id
             and app.branch_allowed(s.organization_id, s.branch_id)
         ));

create policy payments_select on public.payments
  for select to authenticated
  using (app.has_permission_in(organization_id, 'sales.read')
         and exists (
           select 1 from public.sales s
           where s.id = sale_id
             and app.branch_allowed(s.organization_id, s.branch_id)
         ));

create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (app.has_permission_in(organization_id, 'audit.read')
         and (branch_id is null
              or app.branch_allowed(organization_id, branch_id)));

create policy sync_operations_select on public.sync_operations
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'sync.read'));

create policy sync_receipts_select on public.sync_receipts
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'sync.read'));

create policy sync_events_select on public.sync_events
  for select to authenticated
  using (organization_id = app.current_organization_id()
         and app.has_permission_in(organization_id, 'sync.read'));

create policy customer_devices_select on public.customer_devices
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'devices.manage'));

create policy pairing_codes_select on public.device_pairing_codes
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'devices.manage'));

create policy customer_bindings_select on public.customer_table_bindings
  for select to authenticated
  using (app.has_permission_in(organization_id, 'devices.manage')
         and exists (
           select 1 from public.dining_tables t
           where t.id = dining_table_id
             and app.branch_allowed(t.organization_id, t.branch_id)
         ));

create policy customer_orders_select on public.customer_orders
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'tables.read'));

create policy customer_order_items_select on public.customer_order_items
  for select to authenticated
  using (app.has_permission_in(organization_id, 'tables.read')
         and exists (
           select 1 from public.customer_orders o
           where o.id = customer_order_id
             and app.branch_allowed(o.organization_id, o.branch_id)
         ));

create policy customer_order_modifiers_select on public.customer_order_modifiers
  for select to authenticated
  using (app.has_permission_in(organization_id, 'tables.read')
         and exists (
           select 1
           from public.customer_order_items i
           join public.customer_orders o on o.id = i.customer_order_id
           where i.id = customer_order_item_id
             and app.branch_allowed(o.organization_id, o.branch_id)
         ));

-- customer_device_sessions no tiene política: acceso solo por RPC con token.

-- Privilegios -------------------------------------------------------------

revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
grant select on all tables in schema public to authenticated;
grant usage on schema app to authenticated, anon;

alter default privileges for role postgres in schema public
  revoke insert, update, delete, truncate on tables from anon, authenticated;

grant execute on all functions in schema app to authenticated;