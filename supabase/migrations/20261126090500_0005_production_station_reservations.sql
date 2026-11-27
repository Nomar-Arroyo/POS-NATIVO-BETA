-- 0005: alcance por estación de producción y consumo de reservas al vender.
-- 1) profiles.production_station limita qué estación puede operar y leer cada
--    perfil (KITCHEN, BAR o BOTH). La autorización vive en el backend: cambiar
--    una preferencia en Flutter no otorga alcance.
-- 2) rpc_confirm_sale resuelve las reservas activas de la sesión de mesa:
--    las consume en lugar de descontarlas a ciegas y libera las restantes.
-- 3) app.lookup_receipt replica también los conflictos registrados, de modo
--    que reintentar la misma clave nunca produce un error de clave duplicada.

alter table public.profiles
  add column production_station text not null default 'BOTH'
  check (production_station in ('KITCHEN', 'BAR', 'BOTH'));

create or replace function app.current_production_station() returns text
language sql stable security definer
set search_path = public, pg_temp
as $$
  select p.production_station
  from public.profiles p
  where p.id = app.current_profile_id()
  limit 1;
$$;

create or replace function app.production_station_allows(p_station text)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select coalesce(app.current_production_station() in ('BOTH', p_station), false);
$$;

create or replace function app.assert_production_station(p_station text)
returns void
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
begin
  if not app.production_station_allows(p_station) then
    raise exception 'FORBIDDEN: estación % no autorizada para el perfil', p_station
      using errcode = 'P0001', hint = 'FORBIDDEN';
  end if;
end;
$$;

revoke execute on function app.current_production_station() from public;
revoke execute on function app.production_station_allows(text) from public;
revoke execute on function app.assert_production_station(text) from public;
grant execute on function app.current_production_station() to authenticated;
grant execute on function app.production_station_allows(text) to authenticated;

-- RLS: cocina solo ve comandas de cocina y barra solo las suyas. Los perfiles
-- con 'BOTH' (administración, caja, mesoneros) conservan la vista completa.
drop policy if exists production_orders_select on public.production_orders;
create policy production_orders_select on public.production_orders
  for select to authenticated
  using (app.branch_allowed(organization_id, branch_id)
         and app.has_permission_in(organization_id, 'production.read')
         and app.production_station_allows(station));

drop policy if exists production_order_items_select on public.production_order_items;
create policy production_order_items_select on public.production_order_items
  for select to authenticated
  using (app.has_permission_in(organization_id, 'production.read')
         and exists (
           select 1 from public.production_orders po
           where po.id = production_order_id
             and app.branch_allowed(po.organization_id, po.branch_id)
             and app.production_station_allows(po.station)
         ));

-- Replay de conflictos: una clave en conflicto devuelve el mismo resultado en
-- lugar de intentar aplicar de nuevo. La operación local debe reconciliarse y
-- reenviarse con una clave nueva.
create or replace function app.lookup_receipt(p_organization uuid, p_key text)
returns jsonb
language sql stable security definer
set search_path = public, pg_temp
as $$
  with applied as (
    select o.id, o.operation_type, o.entity_id, o.idempotency_key,
           o.applied_at, r.remote_version
    from public.sync_receipts r
    join public.sync_operations o on o.id = r.sync_operation_id
    where r.organization_id = p_organization
      and r.idempotency_key = p_key
      and r.accepted
    limit 1
  ),
  conflicted as (
    select o.id, o.idempotency_key, o.conflict_code
    from public.sync_operations o
    where o.organization_id = p_organization
      and o.idempotency_key = p_key
      and o.status = 'CONFLICT'
    limit 1
  )
  select case
    when exists (select 1 from applied) then (
      select jsonb_build_object(
        'accepted', true,
        'duplicate', true,
        'operation_id', a.id,
        'operation_type', a.operation_type,
        'entity_id', a.entity_id,
        'idempotency_key', a.idempotency_key,
        'remote_version', a.remote_version,
        'applied_at', a.applied_at
      )
      from applied a
    )
    when exists (select 1 from conflicted) then (
      select jsonb_build_object(
        'accepted', false,
        'code', c.conflict_code,
        'message', coalesce(
          (
            select al.after_json->>'message'
            from public.audit_logs al
            where al.action = 'SYNC_OPERATION_CONFLICT'
              and al.entity_id = c.id
            order by al.occurred_at desc
            limit 1
          ),
          'Conflicto registrado: ' || c.conflict_code
        ),
        'operation_id', c.id,
        'idempotency_key', c.idempotency_key
      )
      from conflicted c
    )
  end;
$$;

-- Envío a producción: el permiso se evalúa junto con la estación del perfil.
create or replace function public.rpc_send_production(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_session uuid := (p_payload->>'dining_session_id')::uuid;
  v_station text := p_payload->>'station';
  v_table uuid;
  v_branch uuid;
  v_order uuid := gen_random_uuid();
  v_number text;
  v_count integer;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('production.send');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'production.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba production.v1');
    end if;
    if v_station not in ('KITCHEN', 'BAR') then
      perform app.conflict('STATION_INVALID', 'Estación inválida');
    end if;
    perform app.assert_production_station(v_station);

    select dining_table_id, branch_id into v_table, v_branch
      from public.dining_sessions
     where id = v_session and organization_id = v_org and status = 'OPEN'
     for update;
    if v_table is null then
      perform app.conflict('DINING_SESSION_INVALID', 'Sesión cerrada o ajena');
    end if;

    select count(*) into v_count
      from public.dining_session_items
     where dining_session_id = v_session and fulfillment_station = v_station
       and status = 'PENDING';
    if v_count = 0 then
      perform app.conflict('NOTHING_TO_SEND', 'No hay líneas pendientes en la estación');
    end if;

    v_number := 'P-' || to_char(now(), 'YYMMDDHH24MISS')
                || '-' || left(v_station, 1) || '-' || floor(random() * 900 + 100);

    insert into public.production_orders(
      id, organization_id, branch_id, dining_session_id, dining_table_id,
      order_number, station, status, created_by
    ) values (
      v_order, v_org, v_branch, v_session, v_table, v_number, v_station,
      'PENDING', v_profile
    );

    insert into public.production_order_items(
      organization_id, production_order_id, dining_session_item_id
    )
    select v_org, v_order, i.id
      from public.dining_session_items i
     where i.dining_session_id = v_session
       and i.fulfillment_station = v_station
       and i.status = 'PENDING';

    update public.dining_session_items
       set status = 'SENT', sent_at = now()
     where dining_session_id = v_session
       and fulfillment_station = v_station
       and status = 'PENDING';

    perform app.write_audit(
      'PRODUCTION_ORDER_SENT', 'production_order', v_order, v_branch, null,
      v_profile, null, null, null,
      jsonb_build_object('station', v_station, 'lines', v_count)
    );
    return app.record_receipt(
      v_org, null, 'send_production', 'production_order', v_order,
      v_key, 'production.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, null, 'send_production', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

-- Actualización de comandas: nadie opera una comanda de otra estación.
create or replace function public.rpc_update_production_status(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_order uuid := (p_payload->>'production_order_id')::uuid;
  v_status text := upper(p_payload->>'status');
  v_current text;
  v_station text;
  v_branch uuid;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('production.update');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'production.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba production.v1');
    end if;

    select status, station, branch_id into v_current, v_station, v_branch
      from public.production_orders
     where id = v_order and organization_id = v_org
     for update;
    if v_current is null then
      perform app.conflict('PRODUCTION_INVALID', 'Comanda inexistente');
    end if;
    perform app.assert_production_station(v_station);

    if not (
      (v_current = 'PENDING' and v_status in ('PREPARING', 'CANCELLED'))
      or (v_current = 'PREPARING' and v_status in ('READY', 'CANCELLED'))
      or (v_current = 'READY' and v_status = 'DELIVERED')
    ) then
      perform app.conflict(
        'TRANSITION_INVALID',
        format('Transición %s -> %s no permitida', v_current, v_status)
      );
    end if;

    update public.production_orders
       set status = v_status,
           ready_at = case when v_status = 'READY' then now() else ready_at end,
           delivered_at = case when v_status = 'DELIVERED' then now() else delivered_at end,
           updated_at = now(),
           base_version = base_version + 1
     where id = v_order;

    update public.dining_session_items i
       set status = v_status,
           updated_at = now()
      from public.production_order_items poi
     where poi.production_order_id = v_order
       and poi.dining_session_item_id = i.id;

    perform app.write_audit(
      'PRODUCTION_STATUS_CHANGED', 'production_order', v_order, v_branch, null,
      v_profile, null, null,
      jsonb_build_object('from', v_current), jsonb_build_object('to', v_status)
    );
    return app.record_receipt(
      v_org, null, 'update_production_status', 'production_order', v_order,
      v_key, 'production.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, null, 'update_production_status', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

-- Venta: consume las reservas activas de la sesión de mesa antes de descontar
-- existencias. Una venta directa ya no reduce reserved_minor de otras mesas.
create or replace function public.rpc_confirm_sale(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_sale_id uuid := (p_payload->'sale'->>'id')::uuid;
  v_branch uuid := (p_payload->'sale'->>'branch_id')::uuid;
  v_terminal uuid := (p_payload->'sale'->>'terminal_id')::uuid;
  v_cash uuid := nullif(p_payload->'sale'->>'cash_session_id', '')::uuid;
  v_dining uuid := nullif(p_payload->'sale'->>'dining_session_id', '')::uuid;
  v_currency text := p_payload->'sale'->>'total_currency';
  v_total bigint := (p_payload->'sale'->>'total_minor')::bigint;
  v_items jsonb := coalesce(p_payload->'items', '[]'::jsonb);
  v_payments jsonb := coalesce(p_payload->'payments', '[]'::jsonb);
  v_consumptions jsonb := coalesce(p_payload->'inventory_consumptions', '[]'::jsonb);
  v_receipt jsonb;
  v_item jsonb;
  v_payment jsonb;
  v_consumption jsonb;
  v_index integer := 0;
  v_qty numeric;
  v_price bigint;
  v_line bigint;
  v_sum bigint := 0;
  v_paid bigint := 0;
  v_variant record;
  v_balance record;
  v_hint text;
  v_message text;
  v_table uuid;
  v_warehouse uuid;
  v_reserved_for_sale bigint;
  v_reservations_consumed integer := 0;
  v_rows integer;
  v_leftover record;
begin
  perform app.assert_permission('sales.create');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then
    return v_receipt;
  end if;

  begin
    if v_schema is distinct from 'sale.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba sale.v1');
    end if;
    perform app.assert_active_terminal(v_terminal, v_branch);

    if jsonb_array_length(v_items) = 0 then
      perform app.conflict('ITEM_INVALID', 'La venta requiere al menos una línea');
    end if;
    if jsonb_array_length(v_payments) = 0 then
      perform app.conflict('PAYMENT_INVALID', 'La venta requiere al menos un pago');
    end if;

    for v_item in select * from jsonb_array_elements(v_items) loop
      v_qty := (v_item->>'quantity')::numeric;
      if v_qty is null or v_qty <= 0 then
        perform app.conflict('ITEM_INVALID', 'Cantidad inválida');
      end if;

      select v.id, v.price_minor, v.active, v.deleted_at,
             p.name, p.base_currency, p.active as product_active,
             p.deleted_at as product_deleted, p.is_synthetic
        into v_variant
        from public.product_variants v
        join public.products p on p.id = v.product_id
       where v.id = (v_item->>'variant_id')::uuid
         and v.organization_id = v_org;

      if not found or not v_variant.active or v_variant.deleted_at is not null
         or not v_variant.product_active or v_variant.product_deleted is not null
         or v_variant.is_synthetic then
        perform app.conflict('ITEM_INVALID', 'Variante inexistente, inactiva o sintética');
      end if;
      if v_variant.base_currency <> v_currency then
        perform app.conflict('CURRENCY_MISMATCH', 'Moneda de línea distinta a la venta');
      end if;
      if (v_item->>'unit_price_minor')::bigint <> v_variant.price_minor then
        perform app.conflict(
          'PRICE_CHANGED',
          format('Precio vigente %s distinto al enviado %s',
                 v_variant.price_minor, v_item->>'unit_price_minor')
        );
      end if;

      v_price := v_variant.price_minor;
      v_line := round(v_price * v_qty)::bigint;
      v_sum := v_sum + v_line;
    end loop;

    if v_sum <> v_total then
      perform app.conflict('TOTAL_MISMATCH', 'El total no coincide con las líneas');
    end if;

    for v_payment in select * from jsonb_array_elements(v_payments) loop
      if (v_payment->>'amount_minor')::bigint <= 0 then
        perform app.conflict('PAYMENT_INVALID', 'Importe de pago inválido');
      end if;
      if (v_payment->>'currency_code') <> v_currency then
        perform app.conflict('PAYMENT_CURRENCY_MISMATCH', 'Moneda de pago distinta');
      end if;
      v_paid := v_paid + (v_payment->>'amount_minor')::bigint;
    end loop;
    if v_paid <> v_total then
      perform app.conflict('PAYMENT_MISMATCH', 'Los pagos no igualan el total');
    end if;

    if v_cash is not null and not exists (
      select 1 from public.cash_sessions cs
      where cs.id = v_cash and cs.organization_id = v_org
        and cs.terminal_id = v_terminal and cs.status = 'OPEN'
    ) then
      perform app.conflict('CASH_SESSION_INVALID', 'Sesión de caja cerrada o ajena');
    end if;
    if v_cash is null and exists (
      select 1 from jsonb_array_elements(v_payments) e
      where upper(e->>'method') like 'EFECTIVO%'
    ) then
      perform app.conflict('CASH_SESSION_REQUIRED', 'Pago en efectivo requiere caja abierta');
    end if;

    if v_dining is not null then
      select ds.dining_table_id into v_table
        from public.dining_sessions ds
        join public.dining_tables dt on dt.id = ds.dining_table_id
       where ds.id = v_dining
         and ds.organization_id = v_org
         and ds.branch_id = v_branch
         and ds.status = 'OPEN'
         and dt.branch_id = v_branch
       for update of ds;
      if v_table is null then
        perform app.conflict('DINING_SESSION_INVALID', 'Sesión de mesa cerrada o ajena');
      end if;
    end if;

    insert into public.sales(
      id, organization_id, branch_id, terminal_id, cash_session_id,
      dining_session_id, sale_number, status, sale_kind, total_currency,
      total_minor, exchange_rate_snapshot_id, beta_origin_id, idempotency_key,
      created_by, closed_at
    ) values (
      v_sale_id, v_org, v_branch, v_terminal, v_cash, v_dining,
      p_payload->'sale'->>'sale_number', 'paid',
      case when v_dining is null then 'direct' else 'dining' end,
      v_currency, v_total,
      nullif(p_payload->'sale'->>'exchange_rate_snapshot_id', '')::uuid,
      p_payload->'sale'->>'beta_origin_id', v_key, v_profile, now()
    );

    for v_item in select * from jsonb_array_elements(v_items) loop
      select p.name into v_variant
        from public.product_variants v
        join public.products p on p.id = v.product_id
       where v.id = (v_item->>'variant_id')::uuid;

      insert into public.sale_items(
        id, organization_id, sale_id, variant_id, product_name, quantity,
        unit_price_minor, subtotal_minor, tax_minor, line_currency
      ) values (
        coalesce(nullif(v_item->>'id', '')::uuid, gen_random_uuid()),
        v_org, v_sale_id, (v_item->>'variant_id')::uuid, v_variant.name,
        (v_item->>'quantity')::numeric,
        round((v_item->>'unit_price_minor')::bigint * (v_item->>'quantity')::numeric)::bigint,
        round((v_item->>'unit_price_minor')::bigint * (v_item->>'quantity')::numeric)::bigint,
        coalesce((v_item->>'tax_minor')::bigint, 0), v_currency
      );
    end loop;

    v_index := 0;
    for v_payment in select * from jsonb_array_elements(v_payments) loop
      v_index := v_index + 1;
      insert into public.payments(
        id, organization_id, sale_id, method, amount_minor, currency_code,
        exchange_rate_snapshot_id, original_amount_minor, original_currency_code,
        reference, status, idempotency_key
      ) values (
        coalesce(nullif(v_payment->>'id', '')::uuid, gen_random_uuid()),
        v_org, v_sale_id, v_payment->>'method',
        (v_payment->>'amount_minor')::bigint, v_payment->>'currency_code',
        nullif(v_payment->>'exchange_rate_snapshot_id', '')::uuid,
        coalesce((v_payment->>'original_amount_minor')::bigint,
                 (v_payment->>'amount_minor')::bigint),
        coalesce(v_payment->>'original_currency_code', v_payment->>'currency_code'),
        v_payment->>'reference', 'confirmed',
        v_key || ':pay:' || v_index
      );

      if v_cash is not null and upper(v_payment->>'method') like 'EFECTIVO%' then
        insert into public.cash_movements(
          id, organization_id, cash_session_id, movement_type, category,
          amount_minor, currency_code, sale_id, reason, idempotency_key, created_by
        ) values (
          gen_random_uuid(), v_org, v_cash, 'income', 'sale',
          (v_payment->>'amount_minor')::bigint, v_payment->>'currency_code',
          v_sale_id, 'Cobro de venta', v_key || ':cash:' || v_index, v_profile
        );
      end if;
    end loop;

    for v_consumption in select * from jsonb_array_elements(v_consumptions) loop
      v_qty := (v_consumption->>'quantity')::numeric;
      v_warehouse := (v_consumption->>'warehouse_id')::uuid;

      select b.id, b.quantity_minor, b.reserved_minor, b.version
        into v_balance
        from public.inventory_balances b
       where b.organization_id = v_org
         and b.warehouse_id = v_warehouse
         and b.variant_id = (v_consumption->>'variant_id')::uuid
       for update;

      if not found then
        perform app.conflict('INSUFFICIENT_STOCK', 'Existencias insuficientes para consumir');
      end if;

      v_reserved_for_sale := 0;
      v_rows := 0;
      if v_dining is not null then
        perform 1
          from public.inventory_reservations r
          join public.customer_orders o on o.id = r.customer_order_id
         where r.organization_id = v_org
           and r.warehouse_id = v_warehouse
           and r.variant_id = (v_consumption->>'variant_id')::uuid
           and r.status = 'ACTIVE'
           and o.dining_session_id = v_dining
         for update of r;

        select coalesce(sum(r.quantity_minor), 0)
          into v_reserved_for_sale
          from public.inventory_reservations r
          join public.customer_orders o on o.id = r.customer_order_id
         where r.organization_id = v_org
           and r.warehouse_id = v_warehouse
           and r.variant_id = (v_consumption->>'variant_id')::uuid
           and r.status = 'ACTIVE'
           and o.dining_session_id = v_dining;
      end if;

      if v_balance.quantity_minor - v_balance.reserved_minor
         + v_reserved_for_sale < v_qty then
        perform app.conflict('INSUFFICIENT_STOCK', 'Existencias insuficientes para consumir');
      end if;

      if v_dining is not null and v_reserved_for_sale > 0 then
        update public.inventory_reservations r
           set status = 'CONSUMED'
          from public.customer_orders o
         where o.id = r.customer_order_id
           and r.organization_id = v_org
           and r.warehouse_id = v_warehouse
           and r.variant_id = (v_consumption->>'variant_id')::uuid
           and r.status = 'ACTIVE'
           and o.dining_session_id = v_dining;
        get diagnostics v_rows = row_count;
        v_reservations_consumed := v_reservations_consumed + v_rows;
      end if;

      update public.inventory_balances
         set quantity_minor = quantity_minor - v_qty,
             reserved_minor = greatest(0, reserved_minor - v_reserved_for_sale),
             version = version + 1,
             updated_at = now()
       where id = v_balance.id;

      insert into public.inventory_movements(
        id, organization_id, warehouse_id, variant_id, sale_id, movement_type,
        quantity_minor, reason, source_terminal_id, idempotency_key,
        before_version, created_by
      ) values (
        gen_random_uuid(), v_org, v_warehouse,
        (v_consumption->>'variant_id')::uuid, v_sale_id, 'SALE_CONSUMPTION',
        -v_qty, 'Consumo por venta', v_terminal,
        v_key || ':inv:' || (v_consumption->>'variant_id') || ':' ||
        (v_consumption->>'warehouse_id'),
        v_balance.version, v_profile
      );
    end loop;

    -- La sesión se cierra: toda reserva activa que no se consumió se libera
    -- para que no quede stock retenido por una mesa ya cobrada.
    if v_dining is not null then
      for v_leftover in
        select r.warehouse_id, r.variant_id,
               sum(r.quantity_minor)::bigint as quantity_minor
          from public.inventory_reservations r
          join public.customer_orders o on o.id = r.customer_order_id
         where r.organization_id = v_org
           and r.status = 'ACTIVE'
           and o.dining_session_id = v_dining
         group by r.warehouse_id, r.variant_id
      loop
        update public.inventory_reservations r
           set status = 'RELEASED', released_at = now()
          from public.customer_orders o
         where o.id = r.customer_order_id
           and r.organization_id = v_org
           and r.status = 'ACTIVE'
           and r.warehouse_id = v_leftover.warehouse_id
           and r.variant_id = v_leftover.variant_id
           and o.dining_session_id = v_dining;

        update public.inventory_balances
           set reserved_minor = greatest(0, reserved_minor - v_leftover.quantity_minor),
               version = version + 1,
               updated_at = now()
         where organization_id = v_org
           and warehouse_id = v_leftover.warehouse_id
           and variant_id = v_leftover.variant_id;
      end loop;

      update public.dining_sessions
         set status = 'CLOSED', closed_at = now(), sale_id = v_sale_id,
             base_version = base_version + 1
       where id = v_dining
      ;
      update public.dining_tables
         set status = 'FREE', updated_at = now(), version = version + 1
       where id = v_table;
    end if;

    perform app.write_audit(
      'SALE_CONFIRMED_REMOTE', 'sale', v_sale_id, v_branch, v_terminal, v_profile,
      null, null, null,
      jsonb_build_object('total_minor', v_total, 'currency', v_currency,
                         'dining_session_id', v_dining,
                         'reservations_consumed', v_reservations_consumed)
    );

    return app.record_receipt(
      v_org, v_terminal, 'confirm_sale', 'sale', v_sale_id, v_key,
      'sale.v1', p_payload, 1
    );
  exception
    when unique_violation then
      v_receipt := app.lookup_receipt(v_org, v_key);
      if v_receipt is not null then
        return v_receipt;
      end if;
      raise;
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, v_terminal, 'confirm_sale', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;
