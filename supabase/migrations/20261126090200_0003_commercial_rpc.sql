-- 0003: RPC comerciales atómicas.
-- Reglas comunes: perfil activo, permiso efectivo, terminal vigente, clave
-- idempotente y recibo correlacionado. Los conflictos comerciales se registran
-- y se devuelven como {accepted:false}; los fallos de autorización se elevan.

create or replace function app.new_token() returns text
language sql volatile
set search_path = public, extensions, pg_temp
as $$ select encode(extensions.gen_random_bytes(32), 'hex'); $$;

create or replace function app.hash_token(p_value text) returns text
language sql immutable
set search_path = public, extensions, pg_temp
as $$ select encode(extensions.digest(p_value, 'sha256'), 'hex'); $$;

create or replace function app.finish_conflict(
  p_organization uuid,
  p_terminal uuid,
  p_operation_type text,
  p_key text,
  p_schema_version text,
  p_payload jsonb,
  p_hint text,
  p_message text
) returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_operation uuid;
begin
  if p_key is null or p_key = '' then
    return jsonb_build_object('accepted', false, 'code', p_hint, 'message', p_message);
  end if;

  insert into public.sync_operations(
    organization_id, terminal_id, operation_type, entity_type, entity_id,
    idempotency_key, schema_version, payload, status, conflict_code
  ) values (
    p_organization, p_terminal, p_operation_type, 'operation', gen_random_uuid(),
    p_key, coalesce(p_schema_version, 'unknown'), coalesce(p_payload, '{}'::jsonb),
    'CONFLICT', p_hint
  )
  on conflict (organization_id, idempotency_key) do update
    set status = 'CONFLICT', conflict_code = excluded.conflict_code
  returning id into v_operation;

  insert into public.audit_logs(
    organization_id, terminal_id, profile_id, action, entity_type, entity_id,
    reason, after_json, occurred_at
  ) values (
    p_organization, p_terminal, app.current_profile_id(),
    'SYNC_OPERATION_CONFLICT', p_operation_type, v_operation, p_hint,
    jsonb_build_object('code', p_hint, 'message', p_message), now()
  );

  return jsonb_build_object(
    'accepted', false,
    'code', p_hint,
    'message', p_message,
    'operation_id', v_operation,
    'idempotency_key', p_key
  );
end;
$$;

-- Terminales --------------------------------------------------------------

create or replace function public.rpc_register_terminal(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_branch uuid := (p_payload->>'branch_id')::uuid;
  v_terminal uuid;
  v_token text := app.new_token();
  v_key text := p_payload->>'idempotency_key';
begin
  perform app.assert_permission('settings.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  if exists (select 1 from public.sync_receipts r
             where r.organization_id = v_org and r.idempotency_key = v_key) then
    return app.lookup_receipt(v_org, v_key);
  end if;
  if not exists (select 1 from public.branches b
                 where b.id = v_branch and b.organization_id = v_org) then
    perform app.conflict('BRANCH_INVALID', 'Sucursal inexistente');
  end if;

  insert into public.terminals(
    organization_id, branch_id, name, token_hash, platform, app_version, status
  ) values (
    v_org, v_branch, p_payload->>'name', app.hash_token(v_token),
    p_payload->>'platform', p_payload->>'app_version', 'active'
  ) returning id into v_terminal;

  perform app.write_audit(
    'TERMINAL_REGISTERED', 'terminal', v_terminal, v_branch, v_terminal, v_profile,
    null, null, null, jsonb_build_object('name', p_payload->>'name')
  );

  return app.record_receipt(
    v_org, v_terminal, 'register_terminal', 'terminal', v_terminal, v_key,
    'terminal.v1', p_payload, 1
  ) || jsonb_build_object('terminal_token', v_token);
end;
$$;

create or replace function public.rpc_revoke_terminal(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_terminal uuid := (p_payload->>'terminal_id')::uuid;
  v_key text := p_payload->>'idempotency_key';
  v_branch uuid;
begin
  perform app.assert_permission('settings.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  if app.lookup_receipt(v_org, v_key) is not null then
    return app.lookup_receipt(v_org, v_key);
  end if;

  update public.terminals
     set status = 'revoked', revoked_at = now()
   where id = v_terminal and organization_id = v_org and status = 'active'
   returning branch_id into v_branch;
  if v_branch is null then
    perform app.conflict('TERMINAL_INVALID', 'Terminal inexistente o ya revocado');
  end if;

  perform app.write_audit(
    'TERMINAL_REVOKED', 'terminal', v_terminal, v_branch, v_terminal, v_profile
  );
  return app.record_receipt(
    v_org, v_terminal, 'revoke_terminal', 'terminal', v_terminal, v_key,
    'terminal.v1', p_payload, 1
  );
end;
$$;

-- Venta -------------------------------------------------------------------

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
      select b.id, b.quantity_minor, b.reserved_minor, b.version
        into v_balance
        from public.inventory_balances b
       where b.organization_id = v_org
         and b.warehouse_id = (v_consumption->>'warehouse_id')::uuid
         and b.variant_id = (v_consumption->>'variant_id')::uuid
       for update;

      if not found or v_balance.quantity_minor - v_balance.reserved_minor < v_qty then
        perform app.conflict('INSUFFICIENT_STOCK', 'Existencias insuficientes para consumir');
      end if;

      update public.inventory_balances
         set quantity_minor = quantity_minor - v_qty,
             reserved_minor = greatest(0, reserved_minor - v_qty),
             version = version + 1,
             updated_at = now()
       where id = v_balance.id;

      insert into public.inventory_movements(
        id, organization_id, warehouse_id, variant_id, sale_id, movement_type,
        quantity_minor, reason, source_terminal_id, idempotency_key,
        before_version, created_by
      ) values (
        gen_random_uuid(), v_org, (v_consumption->>'warehouse_id')::uuid,
        (v_consumption->>'variant_id')::uuid, v_sale_id, 'SALE_CONSUMPTION',
        -v_qty, 'Consumo por venta', v_terminal,
        v_key || ':inv:' || (v_consumption->>'variant_id') || ':' ||
        (v_consumption->>'warehouse_id'),
        v_balance.version, v_profile
      );
    end loop;

    if v_dining is not null then
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
                         'dining_session_id', v_dining)
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

-- Inventario --------------------------------------------------------------

create or replace function public.rpc_adjust_inventory(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_warehouse uuid := (p_payload->>'warehouse_id')::uuid;
  v_variant uuid := (p_payload->>'variant_id')::uuid;
  v_delta bigint := (p_payload->>'quantity_delta_minor')::bigint;
  v_balance uuid;
  v_quantity bigint;
  v_reserved bigint;
  v_version bigint;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('inventory.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'inventory.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba inventory.v1');
    end if;
    if v_delta = 0 then
      perform app.conflict('VALIDATION', 'El ajuste no puede ser cero');
    end if;
    if not exists (select 1 from public.warehouses w
                   where w.id = v_warehouse and w.organization_id = v_org) then
      perform app.conflict('WAREHOUSE_INVALID', 'Almacén inexistente');
    end if;
    if not exists (select 1 from public.product_variants v
                   where v.id = v_variant and v.organization_id = v_org) then
      perform app.conflict('VARIANT_INVALID', 'Variante inexistente');
    end if;

    insert into public.inventory_balances(
      organization_id, warehouse_id, variant_id, quantity_minor
    ) values (v_org, v_warehouse, v_variant, 0)
    on conflict (warehouse_id, variant_id) do nothing;

    select id, quantity_minor, reserved_minor, version
      into v_balance, v_quantity, v_reserved, v_version
      from public.inventory_balances
     where warehouse_id = v_warehouse and variant_id = v_variant
     for update;

    if v_quantity + v_delta < v_reserved then
      perform app.conflict('INSUFFICIENT_STOCK',
        'El ajuste dejaría menos existencias que reservas activas');
    end if;

    update public.inventory_balances
       set quantity_minor = quantity_minor + v_delta,
           version = version + 1, updated_at = now()
     where id = v_balance;

    insert into public.inventory_movements(
      organization_id, warehouse_id, variant_id, movement_type, quantity_minor,
      reason, source_terminal_id, idempotency_key, before_version, created_by
    ) values (
      v_org, v_warehouse, v_variant, 'ADJUSTMENT', v_delta,
      p_payload->>'reason',
      nullif(p_payload->>'terminal_id', '')::uuid,
      v_key, v_version, v_profile
    );

    perform app.write_audit(
      'INVENTORY_ADJUSTED', 'inventory_balance', v_balance,
      null, null, v_profile, null, p_payload->>'reason', null,
      jsonb_build_object('quantity_delta_minor', v_delta)
    );

    return app.record_receipt(
      v_org, nullif(p_payload->>'terminal_id', '')::uuid, 'adjust_inventory',
      'inventory_balance', v_balance, v_key, 'inventory.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, nullif(p_payload->>'terminal_id', '')::uuid, 'adjust_inventory',
          v_key, v_schema, p_payload, v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

-- Caja --------------------------------------------------------------------

create or replace function public.rpc_open_cash_session(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_register uuid := (p_payload->>'cash_register_id')::uuid;
  v_terminal uuid := (p_payload->>'terminal_id')::uuid;
  v_branch uuid;
  v_session uuid;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('cash.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'cash.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba cash.v1');
    end if;
    select branch_id into v_branch from public.cash_registers
     where id = v_register and organization_id = v_org and status = 'active';
    if v_branch is null then
      perform app.conflict('REGISTER_INVALID', 'Caja inexistente o inactiva');
    end if;
    perform app.assert_active_terminal(v_terminal, v_branch);
    if exists (select 1 from public.cash_sessions cs
               where cs.cash_register_id = v_register and cs.status = 'OPEN') then
      perform app.conflict('CASH_SESSION_OPEN', 'La caja ya tiene una sesión abierta');
    end if;

    insert into public.cash_sessions(
      organization_id, branch_id, cash_register_id, terminal_id, profile_id,
      opening_minor, status, idempotency_key
    ) values (
      v_org, v_branch, v_register, v_terminal, v_profile,
      coalesce(p_payload->'opening_minor', '{}'::jsonb), 'OPEN', v_key
    ) returning id into v_session;

    perform app.write_audit(
      'CASH_SESSION_OPENED', 'cash_session', v_session, v_branch, v_terminal,
      v_profile, null, null, null, p_payload->'opening_minor'
    );
    return app.record_receipt(
      v_org, v_terminal, 'open_cash_session', 'cash_session', v_session,
      v_key, 'cash.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, v_terminal, 'open_cash_session', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

create or replace function public.rpc_close_cash_session(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_session uuid := (p_payload->>'cash_session_id')::uuid;
  v_register uuid;
  v_branch uuid;
  v_expected bigint := 0;
  v_closing bigint;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('cash.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'cash.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba cash.v1');
    end if;

    select cash_register_id, branch_id into v_register, v_branch
      from public.cash_sessions
     where id = v_session and organization_id = v_org and status = 'OPEN'
     for update;
    if v_register is null then
      perform app.conflict('CASH_SESSION_INVALID', 'Sesión de caja cerrada o ajena');
    end if;

    select coalesce(sum(amount_minor), 0) into v_expected
      from public.cash_movements
     where cash_session_id = v_session and currency_code = 'USD';

    v_closing := coalesce((p_payload->'closing_minor'->>'usd_minor')::bigint, v_expected);

    update public.cash_sessions
       set status = 'CLOSED', closed_at = now(),
           closing_minor = coalesce(p_payload->'closing_minor', '{}'::jsonb),
           expected_usd_minor = v_expected,
           difference_usd_minor = v_closing - v_expected,
           base_version = base_version + 1
     where id = v_session;

    perform app.write_audit(
      'CASH_SESSION_CLOSED', 'cash_session', v_session, v_branch, null,
      v_profile, null, null, null,
      jsonb_build_object('expected_usd_minor', v_expected,
                         'difference_usd_minor', v_closing - v_expected)
    );
    return app.record_receipt(
      v_org, null, 'close_cash_session', 'cash_session', v_session,
      v_key, 'cash.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, null, 'close_cash_session', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

-- Salón y producción ------------------------------------------------------

create or replace function public.rpc_open_dining_session(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_key text := p_payload->>'idempotency_key';
  v_schema text := p_payload->>'schema_version';
  v_table uuid := (p_payload->>'dining_table_id')::uuid;
  v_terminal uuid := (p_payload->>'terminal_id')::uuid;
  v_branch uuid;
  v_session uuid;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('tables.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'dining.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba dining.v1');
    end if;
    select branch_id into v_branch from public.dining_tables
     where id = v_table and organization_id = v_org and active;
    if v_branch is null then
      perform app.conflict('TABLE_INVALID', 'Mesa inexistente o inactiva');
    end if;
    perform app.assert_active_terminal(v_terminal, v_branch);
    if exists (select 1 from public.dining_sessions ds
               where ds.dining_table_id = v_table and ds.status = 'OPEN') then
      perform app.conflict('DINING_SESSION_OPEN', 'La mesa ya tiene una sesión abierta');
    end if;

    insert into public.dining_sessions(
      organization_id, branch_id, dining_table_id, terminal_id, profile_id,
      status, idempotency_key
    ) values (
      v_org, v_branch, v_table, v_terminal, v_profile, 'OPEN', v_key
    ) returning id into v_session;

    update public.dining_tables
       set status = 'OCCUPIED', updated_at = now(), version = version + 1
     where id = v_table;

    perform app.write_audit(
      'DINING_SESSION_OPENED', 'dining_session', v_session, v_branch, v_terminal,
      v_profile
    );
    return app.record_receipt(
      v_org, v_terminal, 'open_dining_session', 'dining_session', v_session,
      v_key, 'dining.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, v_terminal, 'open_dining_session', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

create or replace function public.rpc_add_dining_item(p_payload jsonb)
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
  v_variant uuid := (p_payload->>'variant_id')::uuid;
  v_qty numeric := (p_payload->>'quantity')::numeric;
  v_item uuid := gen_random_uuid();
  v_branch uuid;
  v_record record;
  v_receipt jsonb;
  v_hint text;
  v_message text;
begin
  perform app.assert_permission('tables.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  begin
    if v_schema is distinct from 'dining.v1' then
      perform app.conflict('SCHEMA_VERSION_UNSUPPORTED', 'Se esperaba dining.v1');
    end if;
    if v_qty is null or v_qty <= 0 then
      perform app.conflict('ITEM_INVALID', 'Cantidad inválida');
    end if;
    select branch_id into v_branch from public.dining_sessions
     where id = v_session and organization_id = v_org and status = 'OPEN';
    if v_branch is null then
      perform app.conflict('DINING_SESSION_INVALID', 'Sesión cerrada o ajena');
    end if;

    select v.price_minor, p.name, p.base_currency, p.fulfillment_station
      into v_record
      from public.product_variants v
      join public.products p on p.id = v.product_id
     where v.id = v_variant and v.organization_id = v_org
       and v.active and v.deleted_at is null
       and p.active and p.deleted_at is null;
    if v_record.price_minor is null then
      perform app.conflict('ITEM_INVALID', 'Variante inexistente o inactiva');
    end if;

    insert into public.dining_session_items(
      id, organization_id, dining_session_id, variant_id, product_name,
      quantity, unit_price_minor, currency_code, fulfillment_station, notes
    ) values (
      v_item, v_org, v_session, v_variant, v_record.name, v_qty,
      v_record.price_minor, v_record.base_currency, v_record.fulfillment_station,
      p_payload->>'notes'
    );

    perform app.write_audit(
      'DINING_ITEM_ADDED', 'dining_session_item', v_item, v_branch, null,
      v_profile, null, null, null,
      jsonb_build_object('quantity', v_qty, 'variant_id', v_variant)
    );
    return app.record_receipt(
      v_org, null, 'add_dining_item', 'dining_session_item', v_item,
      v_key, 'dining.v1', p_payload, 1
    );
  exception
    when others then
      get stacked diagnostics v_hint = pg_exception_hint,
                                v_message = message_text;
      if v_hint is not null
         and v_hint not in ('FORBIDDEN', 'UNAUTHENTICATED') then
        return app.finish_conflict(
          v_org, null, 'add_dining_item', v_key, v_schema, p_payload,
          v_hint, v_message
        );
      end if;
      raise;
  end;
end;
$$;

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

    select status, branch_id into v_current, v_branch
      from public.production_orders
     where id = v_order and organization_id = v_org
     for update;
    if v_current is null then
      perform app.conflict('PRODUCTION_INVALID', 'Comanda inexistente');
    end if;

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

grant execute on function public.rpc_register_terminal(jsonb) to authenticated;
grant execute on function public.rpc_revoke_terminal(jsonb) to authenticated;
grant execute on function public.rpc_confirm_sale(jsonb) to authenticated;
grant execute on function public.rpc_adjust_inventory(jsonb) to authenticated;
grant execute on function public.rpc_open_cash_session(jsonb) to authenticated;
grant execute on function public.rpc_close_cash_session(jsonb) to authenticated;
grant execute on function public.rpc_open_dining_session(jsonb) to authenticated;
grant execute on function public.rpc_add_dining_item(jsonb) to authenticated;
grant execute on function public.rpc_send_production(jsonb) to authenticated;
grant execute on function public.rpc_update_production_status(jsonb) to authenticated;