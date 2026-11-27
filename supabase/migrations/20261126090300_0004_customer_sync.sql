-- 0004: tablets de cliente, menú, pedidos de mesa y descarga incremental.
-- Las tablets no usan Supabase Auth: se identifican con un token opaco emitido
-- al canjear un código temporal de un solo uso. No reciben permisos de staff,
-- no acceden a tablas directas y solo operan sobre la mesa vinculada.
-- Los RPC de staff de 0003 ya están concedidos a authenticated; aquí se retira
-- el EXECUTE implícito de PUBLIC y se concede solo lo necesario a anon.

revoke execute on all functions in schema public from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from public;

-- Contexto de dispositivo -------------------------------------------------

create or replace function app.issue_device_session(p_device uuid)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid;
  v_token text := app.new_token();
  v_session uuid;
  v_expires timestamptz := now() + interval '8 hours';
begin
  select d.organization_id into v_org
    from public.customer_devices d
   where d.id = p_device and d.status = 'ACTIVE';
  if v_org is null then
    perform app.conflict('DEVICE_INVALID', 'Dispositivo revocado o inexistente');
  end if;

  insert into public.customer_device_sessions(
    organization_id, customer_device_id, token_hash, expires_at
  ) values (
    v_org, p_device, app.hash_token(v_token), v_expires
  ) returning id into v_session;

  return jsonb_build_object(
    'session_id', v_session,
    'session_token', v_token,
    'session_expires_at', v_expires
  );
end;
$$;

create or replace function app.resolve_device(p_token text)
returns table (
  organization_id uuid,
  branch_id uuid,
  device_id uuid,
  table_id uuid,
  table_name text,
  session_id uuid
)
language plpgsql volatile security definer
set search_path = public, pg_temp
as $$
begin
  if p_token is null or length(p_token) < 16 then
    perform app.conflict('DEVICE_SESSION_INVALID', 'Token de dispositivo requerido');
  end if;

  return query
  select s.organization_id, d.branch_id, d.id, b.dining_table_id, t.name, s.id
    from public.customer_device_sessions s
    join public.customer_devices d on d.id = s.customer_device_id
    join public.customer_table_bindings b
      on b.customer_device_id = d.id and b.status = 'ACTIVE'
    join public.dining_tables t on t.id = b.dining_table_id
   where s.token_hash = app.hash_token(p_token)
     and s.status = 'ACTIVE'
     and s.expires_at > now()
     and d.status = 'ACTIVE';

  if not found then
    perform app.conflict(
      'DEVICE_SESSION_INVALID',
      'Sesión de dispositivo inválida, vencida o revocada'
    );
  end if;
end;
$$;

create or replace function public.rpc_renew_device_session(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_session uuid;
  v_expires timestamptz := now() + interval '8 hours';
begin
  select c.session_id into v_session
    from app.resolve_device(p_payload->>'session_token') c;

  update public.customer_device_sessions s
     set expires_at = v_expires,
         last_seen_at = now()
   where s.id = v_session;

  return jsonb_build_object(
    'accepted', true,
    'session_id', v_session,
    'session_expires_at', v_expires
  );
end;
$$;

create or replace function public.rpc_device_heartbeat(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_device uuid;
  v_session uuid;
begin
  select c.device_id, c.session_id into v_device, v_session
    from app.resolve_device(p_payload->>'session_token') c;

  update public.customer_device_sessions
     set last_seen_at = now()
   where id = v_session;
  update public.customer_devices
     set last_seen_at = now()
   where id = v_device;

  return jsonb_build_object('accepted', true, 'server_time', now());
end;
$$;

-- Pairing -----------------------------------------------------------------

create or replace function public.rpc_create_pairing_code(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_branch uuid := (p_payload->>'branch_id')::uuid;
  v_table uuid := (p_payload->>'dining_table_id')::uuid;
  v_table_name text;
  v_key text := p_payload->>'idempotency_key';
  v_receipt jsonb;
  v_ttl integer := coalesce((p_payload->>'ttl_minutes')::integer, 10);
  v_code text;
  v_pairing uuid;
  v_expires timestamptz;
  v_attempt integer;
begin
  perform app.assert_permission('devices.manage');
  if v_key is not null and v_key <> '' then
    v_receipt := app.lookup_receipt(v_org, v_key);
    if v_receipt is not null then
      return v_receipt || jsonb_build_object(
        'duplicate', true,
        'pairing_code_id', v_receipt->>'entity_id',
        'pairing_code', null
      );
    end if;
  end if;

  if v_ttl < 2 or v_ttl > 15 then
    perform app.conflict('VALIDATION', 'ttl_minutes debe estar entre 2 y 15');
  end if;

  select t.name into v_table_name
    from public.dining_tables t
   where t.id = v_table
     and t.branch_id = v_branch
     and t.organization_id = v_org
     and t.active;
  if v_table_name is null then
    perform app.conflict('TABLE_INVALID', 'Mesa inexistente o de otra sucursal');
  end if;
  if not app.branch_allowed(v_org, v_branch) then
    perform app.conflict('BRANCH_FORBIDDEN', 'Sucursal fuera del alcance del perfil');
  end if;

  update public.device_pairing_codes
     set status = 'REVOKED'
   where dining_table_id = v_table
     and status = 'ACTIVE';

  v_expires := now() + make_interval(mins => v_ttl);
  for v_attempt in 1..5 loop
    v_code := lpad(
      (((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint)
        % 90000000) + 10000000)::text,
      8, '0'
    );
    begin
      insert into public.device_pairing_codes(
        organization_id, branch_id, dining_table_id, code_hash,
        expires_at, created_by
      ) values (
        v_org, v_branch, v_table, app.hash_token(v_code),
        v_expires, v_profile
      ) returning id into v_pairing;
      exit;
    exception when unique_violation then
      if v_attempt = 5 then
        perform app.conflict('PAIRING_CODE_COLLISION', 'No se pudo generar un código único');
      end if;
    end;
  end loop;

  perform app.write_audit(
    'PAIRING_CODE_CREATED', 'device_pairing_code', v_pairing, v_branch, null,
    v_profile, null, null, null,
    jsonb_build_object('table_id', v_table, 'expires_at', v_expires)
  );

  v_receipt := jsonb_build_object(
    'accepted', true,
    'duplicate', false,
    'pairing_code_id', v_pairing,
    'pairing_code', v_code,
    'expires_at', v_expires,
    'branch_id', v_branch,
    'table', jsonb_build_object('id', v_table, 'name', v_table_name)
  );
  if v_key is not null and v_key <> '' then
    v_receipt := app.record_receipt(
      v_org, null, 'create_pairing_code', 'device_pairing_code', v_pairing,
      v_key, 'pairing.v1', jsonb_build_object('table_id', v_table), 1
    ) || v_receipt;
  end if;
  return v_receipt;
end;
$$;

create or replace function public.rpc_claim_pairing_code(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_code text := trim(coalesce(p_payload->>'pairing_code', ''));
  v_fingerprint text := p_payload->>'device_fingerprint';
  v_label text := nullif(trim(p_payload->>'label'), '');
  v_pairing uuid;
  v_org uuid;
  v_branch uuid;
  v_table uuid;
  v_table_name text;
  v_expires timestamptz;
  v_status text;
  v_device uuid;
  v_device_status text;
  v_fingerprint_hash text;
  v_session jsonb;
begin
  if v_code !~ '^[0-9]{8}$' then
    perform app.conflict('PAIRING_CODE_INVALID', 'Código de vinculación inválido');
  end if;
  if v_fingerprint is null or length(v_fingerprint) < 8 or length(v_fingerprint) > 200 then
    perform app.conflict('DEVICE_FINGERPRINT_INVALID', 'Huella de dispositivo inválida');
  end if;
  if v_label is not null and length(v_label) > 60 then
    perform app.conflict('VALIDATION', 'label excede 60 caracteres');
  end if;

  select c.id, c.organization_id, c.branch_id, c.dining_table_id,
         c.expires_at, c.status, t.name
    into v_pairing, v_org, v_branch, v_table, v_expires, v_status, v_table_name
    from public.device_pairing_codes c
    join public.dining_tables t on t.id = c.dining_table_id
   where c.code_hash = app.hash_token(v_code)
   for update of c;

  if v_pairing is null or v_status <> 'ACTIVE' then
    perform app.conflict('PAIRING_CODE_INVALID', 'Código inexistente o ya utilizado');
  end if;
  if v_expires <= now() then
    update public.device_pairing_codes set status = 'EXPIRED' where id = v_pairing;
    perform app.conflict('PAIRING_CODE_EXPIRED', 'Código de vinculación vencido');
  end if;

  v_fingerprint_hash := app.hash_token(v_fingerprint);

  select d.id, d.status into v_device, v_device_status
    from public.customer_devices d
   where d.organization_id = v_org
     and d.device_fingerprint_hash = v_fingerprint_hash
   for update;

  if v_device is null then
    insert into public.customer_devices(
      organization_id, branch_id, label, device_fingerprint_hash, last_seen_at
    ) values (
      v_org, v_branch, coalesce(v_label, 'Tablet ' || v_table_name),
      v_fingerprint_hash, now()
    ) returning id into v_device;
  elsif v_device_status = 'REVOKED' then
    perform app.conflict('DEVICE_REVOKED', 'Dispositivo revocado; requiere alta administrativa');
  else
    update public.customer_devices
       set label = coalesce(v_label, label),
           branch_id = v_branch,
           last_seen_at = now()
     where id = v_device;
    update public.customer_device_sessions
       set status = 'REVOKED', revoked_at = now()
     where customer_device_id = v_device and status = 'ACTIVE';
    update public.customer_table_bindings
       set status = 'REVOKED', revoked_at = now()
     where customer_device_id = v_device and status = 'ACTIVE';
  end if;

  insert into public.customer_table_bindings(
    organization_id, customer_device_id, dining_table_id
  ) values (
    v_org, v_device, v_table
  );

  update public.device_pairing_codes
     set status = 'USED', used_at = now(), claimed_device_id = v_device
   where id = v_pairing;

  insert into public.audit_logs(
    organization_id, branch_id, customer_device_id, action, entity_type,
    entity_id, after_json, occurred_at
  ) values (
    v_org, v_branch, v_device, 'DEVICE_PAIRED', 'customer_device',
    v_device,
    jsonb_build_object('pairing_code_id', v_pairing, 'table_id', v_table),
    now()
  );

  v_session := app.issue_device_session(v_device);
  return jsonb_build_object(
    'accepted', true,
    'duplicate', false,
    'device_id', v_device,
    'organization_id', v_org,
    'branch_id', v_branch,
    'table', jsonb_build_object('id', v_table, 'name', v_table_name)
  ) || v_session;
end;
$$;

create or replace function public.rpc_revoke_customer_device(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_profile uuid := app.require_profile();
  v_org uuid := app.current_organization_id();
  v_device uuid := (p_payload->>'device_id')::uuid;
  v_key text := p_payload->>'idempotency_key';
  v_receipt jsonb;
  v_branch uuid;
begin
  perform app.assert_permission('devices.manage');
  if v_key is null or v_key = '' then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  update public.customer_devices d
     set status = 'REVOKED', revoked_at = now()
   where d.id = v_device and d.organization_id = v_org and d.status = 'ACTIVE'
   returning branch_id into v_branch;
  if v_branch is null then
    perform app.conflict('DEVICE_INVALID', 'Dispositivo inexistente o ya revocado');
  end if;

  update public.customer_device_sessions
     set status = 'REVOKED', revoked_at = now()
   where customer_device_id = v_device and status = 'ACTIVE';
  update public.customer_table_bindings
     set status = 'REVOKED', revoked_at = now()
   where customer_device_id = v_device and status = 'ACTIVE';

  perform app.write_audit(
    'DEVICE_REVOKED', 'customer_device', v_device, v_branch, null,
    v_profile, v_device, p_payload->>'reason', null,
    jsonb_build_object('status', 'REVOKED')
  );

  return app.record_receipt(
    v_org, null, 'revoke_customer_device', 'customer_device', v_device,
    v_key, 'device.v1', p_payload, 1
  ) || jsonb_build_object('device_id', v_device, 'status', 'REVOKED');
end;
$$;

-- Menú --------------------------------------------------------------------

create or replace function public.rpc_device_menu(p_payload jsonb)
returns jsonb
language plpgsql volatile security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid;
  v_branch uuid;
  v_device uuid;
  v_table uuid;
  v_table_name text;
  v_session uuid;
begin
  select c.organization_id, c.branch_id, c.device_id, c.table_id, c.table_name,
         c.session_id
    into v_org, v_branch, v_device, v_table, v_table_name, v_session
    from app.resolve_device(p_payload->>'session_token') c;

  return jsonb_build_object(
    'organization_id', v_org,
    'branch_id', v_branch,
    'table', jsonb_build_object('id', v_table, 'name', v_table_name),
    'server_time', now(),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'parent_id', c.parent_id,
        'sort_order', c.sort_order
      ) order by c.sort_order, c.name)
      from public.categories c
      where c.organization_id = v_org and c.active and c.deleted_at is null
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'category_id', p.category_id,
        'name', p.name,
        'description', p.description,
        'currency', p.base_currency,
        'station', p.fulfillment_station,
        'variants', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', v.id, 'name', v.name, 'sku', v.sku,
            'price_minor', v.price_minor
          ) order by v.name), '[]'::jsonb)
          from public.product_variants v
          where v.product_id = p.id and v.active and v.deleted_at is null
        ),
        'modifiers', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', m.id, 'group', m.group_name, 'name', m.name,
            'price_delta_minor', m.price_delta_minor,
            'min_select', m.min_select, 'max_select', m.max_select
          ) order by m.group_name, m.name), '[]'::jsonb)
          from public.product_modifiers m
          where m.product_id = p.id and m.active and m.deleted_at is null
        )
      ) order by p.name)
      from public.products p
      where p.organization_id = v_org
        and p.active
        and p.deleted_at is null
        and not p.is_synthetic
        and exists (
          select 1 from public.product_variants v
          where v.product_id = p.id and v.active and v.deleted_at is null
        )
    ), '[]'::jsonb)
  );
end;
$$;

-- Pedidos de cliente ------------------------------------------------------

create or replace function public.rpc_submit_customer_order(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid;
  v_branch uuid;
  v_device uuid;
  v_table uuid;
  v_table_name text;
  v_session uuid;

  v_key text := p_payload->>'idempotency_key';
  v_items jsonb := p_payload->'items';
  v_order uuid := gen_random_uuid();
  v_number text;
  v_receipt jsonb;
  v_dining uuid;

  v_line jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_variant uuid;
  v_product uuid;
  v_name text;
  v_quantity numeric(18,3);
  v_unit bigint;
  v_delta bigint;
  v_subtotal bigint;
  v_total bigint := 0;
  v_currency text;
  v_line_currency text;
  v_station text;
  v_notes text;
  v_mods jsonb;
  v_mod_count integer;
  v_dining_item uuid;
  v_dining_items uuid[] := '{}';
  v_warehouse uuid;
  v_balance record;
  v_need bigint;
  v_station_loop text;
  v_production uuid;

  v_item jsonb;
  v_customer_item uuid;
  v_item_index integer := 0;
  v_reserve_index integer := 0;
begin
  select c.organization_id, c.branch_id, c.device_id, c.table_id, c.table_name,
         c.session_id
    into v_org, v_branch, v_device, v_table, v_table_name, v_session
    from app.resolve_device(p_payload->>'session_token') c;

  if v_key is null or length(v_key) < 8 or length(v_key) > 120 then
    perform app.conflict('VALIDATION', 'idempotency_key requerida (8-120 caracteres)');
  end if;
  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then
    return v_receipt || coalesce((
      select jsonb_build_object(
        'order_id', o.id, 'order_number', o.order_number, 'status', o.status,
        'total_minor', o.total_minor, 'total_currency', o.total_currency
      )
      from public.customer_orders o
      where o.id = (v_receipt->>'entity_id')::uuid
    ), '{}'::jsonb);
  end if;

  if v_items is null or jsonb_typeof(v_items) <> 'array'
     or jsonb_array_length(v_items) = 0 then
    perform app.conflict('VALIDATION', 'items debe ser un arreglo no vacío');
  end if;
  if jsonb_array_length(v_items) > 50 then
    perform app.conflict('VALIDATION', 'Máximo 50 líneas por pedido');
  end if;

  -- 1) Validar líneas y calcular importes con precios de servidor.
  for v_line in select e.value from jsonb_array_elements(v_items) e loop
    v_item_index := v_item_index + 1;
    if jsonb_typeof(v_line) <> 'object' then
      perform app.conflict('VALIDATION', format('Línea %s inválida', v_item_index));
    end if;
    if coalesce(v_line->>'variant_id', '') !~ '^[0-9a-fA-F-]{36}$' then
      perform app.conflict('VALIDATION', format('Línea %s: variant_id inválido', v_item_index));
    end if;
    if coalesce(v_line->>'quantity', '') !~ '^\d{1,2}(\.\d{1,3})?$' then
      perform app.conflict('VALIDATION', format('Línea %s: cantidad inválida', v_item_index));
    end if;

    v_variant := (v_line->>'variant_id')::uuid;
    v_quantity := (v_line->>'quantity')::numeric(18,3);
    if v_quantity <= 0 then
      perform app.conflict('VALIDATION', format('Línea %s: cantidad debe ser positiva', v_item_index));
    end if;
    v_notes := nullif(left(trim(coalesce(v_line->>'notes', '')), 280), '');

    select v.price_minor, p.id, p.name, p.base_currency, p.fulfillment_station
      into v_unit, v_product, v_name, v_line_currency, v_station
      from public.product_variants v
      join public.products p on p.id = v.product_id
     where v.id = v_variant
       and v.organization_id = v_org
       and v.active
       and v.deleted_at is null
       and p.active
       and p.deleted_at is null
       and not p.is_synthetic;
    if v_product is null then
      perform app.conflict(
        'VARIANT_INVALID',
        format('Línea %s: variante inexistente o no vendible', v_item_index)
      );
    end if;
    if v_currency is null then
      v_currency := v_line_currency;
    elsif v_currency <> v_line_currency then
      perform app.conflict('CURRENCY_MISMATCH', 'Monedas distintas en el pedido');
    end if;

    v_delta := 0;
    v_mods := '[]'::jsonb;
    if v_line ? 'modifier_ids' then
      if jsonb_typeof(v_line->'modifier_ids') <> 'array' then
        perform app.conflict(
          'MODIFIER_INVALID',
          format('Línea %s: modifier_ids debe ser un arreglo', v_item_index)
        );
      end if;
      if exists (
        select 1 from jsonb_array_elements(v_line->'modifier_ids') e
        where (e.value #>> '{}') !~ '^[0-9a-fA-F-]{36}$'
      ) then
        perform app.conflict(
          'MODIFIER_INVALID',
          format('Línea %s: modifier_ids contiene un identificador inválido', v_item_index)
        );
      end if;
    end if;
    if v_line ? 'modifier_ids'
       and jsonb_typeof(v_line->'modifier_ids') = 'array'
       and jsonb_array_length(v_line->'modifier_ids') > 0 then
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', m.id, 'name', m.name, 'delta', m.price_delta_minor
             )), '[]'::jsonb),
             count(*),
             coalesce(sum(m.price_delta_minor), 0)
        into v_mods, v_mod_count, v_delta
        from public.product_modifiers m
       where m.id in (
               select (e.value #>> '{}')::uuid
               from jsonb_array_elements(v_line->'modifier_ids') e
             )
         and m.product_id = v_product
         and m.organization_id = v_org
         and m.active
         and m.deleted_at is null;
      if v_mod_count <> jsonb_array_length(v_line->'modifier_ids') then
        perform app.conflict(
          'MODIFIER_INVALID',
          format('Línea %s: modificador inexistente o ajeno al producto', v_item_index)
        );
      end if;
      if exists (
        select 1 from (
          select m.group_name,
                 count(*) as selected,
                 min(m.min_select) as min_sel,
                 max(m.max_select) as max_sel
            from public.product_modifiers m
           where m.id in (
                   select (e.value #>> '{}')::uuid
                   from jsonb_array_elements(v_line->'modifier_ids') e
                 )
           group by m.group_name
        ) g
        where g.selected < g.min_sel or g.selected > g.max_sel
      ) then
        perform app.conflict(
          'MODIFIER_SELECTION_INVALID',
          format('Línea %s: cantidad de opciones fuera del mínimo/máximo', v_item_index)
        );
      end if;
    end if;

    v_subtotal := round(v_quantity * (v_unit + v_delta))::bigint;
    v_total := v_total + v_subtotal;
    v_lines := v_lines || jsonb_build_object(
      'variant_id', v_variant,
      'product_id', v_product,
      'name', v_name,
      'quantity', v_quantity::text,
      'unit_minor', v_unit + v_delta,
      'subtotal_minor', v_subtotal,
      'currency', v_currency,
      'station', v_station,
      'notes', v_notes,
      'modifiers', v_mods
    );
  end loop;

  v_number := 'C' || to_char(now(), 'YYMMDDHH24MISS') || '-'
              || lpad((floor(random() * 900) + 100)::text, 3, '0');

  -- 2) Sesión de mesa: reutiliza la abierta o crea una nueva.
  select s.id into v_dining
    from public.dining_sessions s
   where s.dining_table_id = v_table and s.status = 'OPEN'
   for update;
  if v_dining is null then
    insert into public.dining_sessions(
      organization_id, branch_id, dining_table_id, customer_device_id,
      status, idempotency_key
    ) values (
      v_org, v_branch, v_table, v_device, 'OPEN', 'DEVOPEN:' || v_key
    ) on conflict do nothing
    returning id into v_dining;
    if v_dining is null then
      select s.id into v_dining
        from public.dining_sessions s
       where s.dining_table_id = v_table and s.status = 'OPEN';
    end if;
    if v_dining is null then
      perform app.conflict('DINING_SESSION_INVALID', 'No se pudo abrir la mesa');
    end if;
  end if;

  insert into public.customer_orders(
    id, organization_id, branch_id, customer_device_id, dining_table_id,
    dining_session_id, order_number, status, total_currency, total_minor,
    idempotency_key
  ) values (
    v_order, v_org, v_branch, v_device, v_table,
    v_dining, v_number, 'RECEIVED', v_currency, v_total, v_key
  );

  -- 3) Persistir líneas y enrutar a cocina/barra.
  for v_item in select e.value from jsonb_array_elements(v_lines) e loop
    v_subtotal := (v_item->>'subtotal_minor')::bigint;
    v_station := v_item->>'station';

    insert into public.dining_session_items(
      organization_id, dining_session_id, variant_id, product_name, quantity,
      unit_price_minor, currency_code, fulfillment_station, notes, status,
      sent_at
    ) values (
      v_org, v_dining, (v_item->>'variant_id')::uuid, v_item->>'name',
      (v_item->>'quantity')::numeric(18,3),
      (v_item->>'unit_minor')::bigint,
      v_item->>'currency',
      v_station,
      nullif(v_item->>'notes', ''),
      case when v_station in ('KITCHEN', 'BAR') then 'SENT' else 'PENDING' end,
      case when v_station in ('KITCHEN', 'BAR') then now() else null end
    ) returning id into v_dining_item;
    v_dining_items := v_dining_items || v_dining_item;

    insert into public.customer_order_items(
      organization_id, customer_order_id, variant_id, product_name, quantity,
      unit_price_minor, subtotal_minor, line_currency, notes
    ) values (
      v_org, v_order, (v_item->>'variant_id')::uuid, v_item->>'name',
      (v_item->>'quantity')::numeric(18,3),
      (v_item->>'unit_minor')::bigint, v_subtotal,
      v_item->>'currency', nullif(v_item->>'notes', '')
    ) returning id into v_customer_item;

    insert into public.customer_order_modifiers(
      organization_id, customer_order_item_id, modifier_id, modifier_name,
      price_delta_minor
    )
    select v_org, v_customer_item, (m.value->>'id')::uuid, m.value->>'name',
           (m.value->>'delta')::bigint
      from jsonb_array_elements(v_item->'modifiers') m;
  end loop;

  update public.dining_tables
     set status = 'OCCUPIED', updated_at = now()
   where id = v_table and status = 'FREE';

  -- 4) Reservas de inventario sobre el almacén principal de la sucursal.
  select w.id into v_warehouse
    from public.warehouses w
   where w.organization_id = v_org and w.branch_id = v_branch
   order by w.created_at
   limit 1;

  if v_warehouse is not null then
    for v_item in select e.value from jsonb_array_elements(v_lines) e loop
      v_reserve_index := v_reserve_index + 1;
      v_variant := (v_item->>'variant_id')::uuid;
      v_need := round((v_item->>'quantity')::numeric * 1000)::bigint;

      select b.quantity_minor, b.reserved_minor
        into v_balance
        from public.inventory_balances b
       where b.warehouse_id = v_warehouse and b.variant_id = v_variant
       for update;
      if found then
        if v_balance.quantity_minor - v_balance.reserved_minor < v_need then
          perform app.conflict(
            'INSUFFICIENT_STOCK',
            format('Sin existencias suficientes para %s', v_item->>'name')
          );
        end if;
        update public.inventory_balances
           set reserved_minor = reserved_minor + v_need,
               version = version + 1,
               updated_at = now()
         where warehouse_id = v_warehouse and variant_id = v_variant;

        insert into public.inventory_reservations(
          organization_id, warehouse_id, variant_id, customer_order_id,
          quantity_minor, status, expires_at
        ) values (
          v_org, v_warehouse, v_variant, v_order, v_need, 'ACTIVE',
          now() + interval '30 minutes'
        );

        insert into public.inventory_movements(
          organization_id, warehouse_id, variant_id, customer_order_id,
          movement_type, quantity_minor, reason, idempotency_key
        ) values (
          v_org, v_warehouse, v_variant, v_order, 'RESERVATION', v_need,
          'PEDIDO_CLIENTE',
          'RES:' || v_key || ':' || v_reserve_index::text
        );
      end if;
    end loop;
  end if;

  -- 5) Comandas de producción por estación (sin venta ni pagos).
  for v_station_loop in
    select distinct i.fulfillment_station
      from public.dining_session_items i
     where i.id = any(v_dining_items)
       and i.status = 'SENT'
       and i.fulfillment_station in ('KITCHEN', 'BAR')
  loop
    v_production := gen_random_uuid();
    insert into public.production_orders(
      id, organization_id, branch_id, dining_session_id, dining_table_id,
      customer_order_id, order_number, station, status
    ) values (
      v_production, v_org, v_branch, v_dining, v_table, v_order,
      'P' || to_char(now(), 'YYMMDDHH24MISS') || '-'
        || left(v_station_loop, 1) || '-'
        || lpad((floor(random() * 900) + 100)::text, 3, '0'),
      v_station_loop, 'PENDING'
    );

    insert into public.production_order_items(
      organization_id, production_order_id, dining_session_item_id
    )
    select v_org, v_production, i.id
      from public.dining_session_items i
     where i.id = any(v_dining_items)
       and i.status = 'SENT'
       and i.fulfillment_station = v_station_loop;
  end loop;

  insert into public.audit_logs(
    organization_id, branch_id, customer_device_id, action, entity_type,
    entity_id, after_json, occurred_at
  ) values (
    v_org, v_branch, v_device, 'CUSTOMER_ORDER_SUBMITTED', 'customer_order',
    v_order,
    jsonb_build_object(
      'order_number', v_number, 'total_minor', v_total,
      'total_currency', v_currency, 'dining_session_id', v_dining,
      'lines', jsonb_array_length(v_lines)
    ),
    now()
  );

  return app.record_receipt(
    v_org, null, 'submit_customer_order', 'customer_order', v_order,
    v_key, 'customer_order.v1', p_payload, 1
  ) || jsonb_build_object(
    'order_id', v_order,
    'order_number', v_number,
    'status', 'RECEIVED',
    'total_minor', v_total,
    'total_currency', v_currency,
    'dining_session_id', v_dining
  );
end;
$$;

create or replace function public.rpc_customer_order_status(p_payload jsonb)
returns jsonb
language plpgsql volatile security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid;
  v_branch uuid;
  v_device uuid;
  v_table uuid;
  v_table_name text;
  v_session uuid;
  v_order uuid;
begin
  select c.organization_id, c.branch_id, c.device_id, c.table_id, c.table_name,
         c.session_id
    into v_org, v_branch, v_device, v_table, v_table_name, v_session
    from app.resolve_device(p_payload->>'session_token') c;

  if p_payload ? 'order_id' and coalesce(p_payload->>'order_id', '') <> '' then
    v_order := (p_payload->>'order_id')::uuid;
  end if;

  return jsonb_build_object(
    'table', jsonb_build_object('id', v_table, 'name', v_table_name),
    'server_time', now(),
    'orders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id,
        'order_number', o.order_number,
        'status', o.status,
        'total_minor', o.total_minor,
        'total_currency', o.total_currency,
        'created_at', o.created_at,
        'updated_at', o.updated_at,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', i.product_name,
            'quantity', i.quantity,
            'unit_price_minor', i.unit_price_minor,
            'subtotal_minor', i.subtotal_minor,
            'notes', i.notes,
            'station', (
              select p.fulfillment_station
                from public.product_variants v
                join public.products p on p.id = v.product_id
               where v.id = i.variant_id
            )
          ) order by i.created_at)
          from public.customer_order_items i
          where i.customer_order_id = o.id
        ), '[]'::jsonb),
        'production', coalesce((
          select jsonb_agg(jsonb_build_object(
            'station', po.station,
            'status', po.status,
            'order_number', po.order_number
          ) order by po.station)
          from public.production_orders po
          where po.customer_order_id = o.id
        ), '[]'::jsonb)
      ) order by o.created_at desc)
      from (
        select *
          from public.customer_orders o
         where o.organization_id = v_org
           and o.customer_device_id = v_device
           and o.dining_table_id = v_table
           and (v_order is null or o.id = v_order)
         order by o.created_at desc
         limit 20
      ) o
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.rpc_cancel_customer_order(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid;
  v_branch uuid;
  v_device uuid;
  v_table uuid;
  v_table_name text;
  v_session uuid;

  v_key text := p_payload->>'idempotency_key';
  v_order uuid := (p_payload->>'order_id')::uuid;
  v_status text;
  v_receipt jsonb;
  v_reason text := nullif(left(trim(coalesce(p_payload->>'reason', '')), 280), '');
  v_res public.inventory_reservations;
begin
  select c.organization_id, c.branch_id, c.device_id, c.table_id, c.table_name,
         c.session_id
    into v_org, v_branch, v_device, v_table, v_table_name, v_session
    from app.resolve_device(p_payload->>'session_token') c;

  if v_key is null or length(v_key) < 8 then
    perform app.conflict('VALIDATION', 'idempotency_key requerida');
  end if;
  if v_order is null then
    perform app.conflict('VALIDATION', 'order_id requerido');
  end if;

  v_receipt := app.lookup_receipt(v_org, v_key);
  if v_receipt is not null then return v_receipt; end if;

  select o.status into v_status
    from public.customer_orders o
   where o.id = v_order
     and o.organization_id = v_org
     and o.customer_device_id = v_device
     and o.dining_table_id = v_table
   for update;
  if v_status is null then
    perform app.conflict('ORDER_INVALID', 'Pedido inexistente o de otro dispositivo');
  end if;
  if v_status = 'CANCELLED' then
    perform app.conflict('ORDER_ALREADY_CANCELLED', 'El pedido ya fue cancelado');
  end if;
  if v_status <> 'RECEIVED' then
    perform app.conflict(
      'ORDER_NOT_CANCELLABLE',
      'El pedido ya está en preparación; solicita cancelación al personal'
    );
  end if;

  for v_res in
    select r.* from public.inventory_reservations r
     where r.customer_order_id = v_order and r.status = 'ACTIVE'
     for update
  loop
    update public.inventory_reservations
       set status = 'RELEASED', released_at = now()
     where id = v_res.id;
    update public.inventory_balances
       set reserved_minor = greatest(0, reserved_minor - v_res.quantity_minor),
           version = version + 1,
           updated_at = now()
     where warehouse_id = v_res.warehouse_id and variant_id = v_res.variant_id;
    insert into public.inventory_movements(
      organization_id, warehouse_id, variant_id, customer_order_id,
      movement_type, quantity_minor, reason, idempotency_key
    ) values (
      v_org, v_res.warehouse_id, v_res.variant_id, v_order, 'RELEASE',
      -v_res.quantity_minor, 'CANCELACION_CLIENTE',
      'RELEASE:' || v_key || ':' || v_res.id::text
    ) on conflict (organization_id, idempotency_key) do nothing;
  end loop;

  update public.production_orders
     set status = 'CANCELLED',
         updated_at = now(),
         base_version = base_version + 1
   where customer_order_id = v_order and status <> 'CANCELLED';

  update public.dining_session_items i
     set status = 'CANCELLED', updated_at = now()
    from public.production_order_items poi
    join public.production_orders po on po.id = poi.production_order_id
   where po.customer_order_id = v_order
     and poi.dining_session_item_id = i.id
     and i.status <> 'CANCELLED';

  update public.customer_orders
     set status = 'CANCELLED', updated_at = now()
   where id = v_order;

  insert into public.audit_logs(
    organization_id, branch_id, customer_device_id, action, entity_type,
    entity_id, reason, before_json, after_json, occurred_at
  ) values (
    v_org, v_branch, v_device, 'CUSTOMER_ORDER_CANCELLED', 'customer_order',
    v_order, v_reason,
    jsonb_build_object('status', v_status),
    jsonb_build_object('status', 'CANCELLED'), now()
  );

  return app.record_receipt(
    v_org, null, 'cancel_customer_order', 'customer_order', v_order,
    v_key, 'customer_order.v1', p_payload, 1
  ) || jsonb_build_object(
    'order_id', v_order,
    'status', 'CANCELLED'
  );
end;
$$;

-- Estado de pedido de cliente según producción --------------------------

create or replace function app.sync_customer_order_status() returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if new.customer_order_id is null then
    return new;
  end if;
  update public.customer_orders o
     set status = (
           select case
             when count(*) filter (where po.status <> 'CANCELLED') = 0
               then 'CANCELLED'
             when count(*) filter (
                    where po.status not in ('CANCELLED', 'DELIVERED')) = 0
               then 'DELIVERED'
             when count(*) filter (
                    where po.status not in ('CANCELLED', 'READY', 'DELIVERED')) = 0
               then 'READY'
             when count(*) filter (
                    where po.status in ('PREPARING', 'READY', 'DELIVERED')) > 0
               then 'PREPARING'
             else 'RECEIVED'
           end
           from public.production_orders po
          where po.customer_order_id = o.id
         ),
         updated_at = now()
   where o.id = new.customer_order_id
     and o.status <> 'CANCELLED';
  return new;
end;
$$;

create trigger production_orders_sync_customer
  after update of status on public.production_orders
  for each row execute function app.sync_customer_order_status();

-- Descarga incremental ----------------------------------------------------

create or replace function public.rpc_pull_catalog(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid := app.current_organization_id();
  v_since timestamptz;
  v_cursor timestamptz := clock_timestamp();
begin
  if not (app.has_permission('sync.read') or app.has_permission('catalog.read')) then
    perform app.conflict('FORBIDDEN', 'catalog.read requerido para descargar catálogo');
  end if;

  if p_payload ? 'since' and coalesce(p_payload->>'since', '') <> '' then
    v_since := (p_payload->>'since')::timestamptz;
  else
    v_since := 'epoch'::timestamptz;
  end if;

  return jsonb_build_object(
    'organization_id', v_org,
    'cursor', v_cursor,
    'server_time', now(),
    'categories', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.updated_at)
        from public.categories c
       where c.organization_id = v_org
         and c.updated_at > v_since and c.updated_at <= v_cursor
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(to_jsonb(p) order by p.updated_at)
        from public.products p
       where p.organization_id = v_org
         and p.updated_at > v_since and p.updated_at <= v_cursor
    ), '[]'::jsonb),
    'variants', coalesce((
      select jsonb_agg(to_jsonb(v) order by v.updated_at)
        from public.product_variants v
       where v.organization_id = v_org
         and v.updated_at > v_since and v.updated_at <= v_cursor
    ), '[]'::jsonb),
    'modifiers', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.updated_at)
        from public.product_modifiers m
       where m.organization_id = v_org
         and m.updated_at > v_since and m.updated_at <= v_cursor
    ), '[]'::jsonb),
    'tables', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.updated_at)
        from public.dining_tables t
       where t.organization_id = v_org
         and app.branch_allowed(v_org, t.branch_id)
         and t.updated_at > v_since and t.updated_at <= v_cursor
    ), '[]'::jsonb),
    'exchange_rates', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.effective_from)
        from public.exchange_rates r
       where r.organization_id = v_org
    ), '[]'::jsonb)
  );
end;
$$;

-- Permisos de ejecución ---------------------------------------------------

grant execute on function public.rpc_renew_device_session(jsonb) to anon, authenticated;
grant execute on function public.rpc_device_heartbeat(jsonb) to anon, authenticated;
grant execute on function public.rpc_claim_pairing_code(jsonb) to anon, authenticated;
grant execute on function public.rpc_device_menu(jsonb) to anon, authenticated;
grant execute on function public.rpc_submit_customer_order(jsonb) to anon, authenticated;
grant execute on function public.rpc_customer_order_status(jsonb) to anon, authenticated;
grant execute on function public.rpc_cancel_customer_order(jsonb) to anon, authenticated;

grant execute on function public.rpc_create_pairing_code(jsonb) to authenticated;
grant execute on function public.rpc_revoke_customer_device(jsonb) to authenticated;
grant execute on function public.rpc_pull_catalog(jsonb) to authenticated;

-- Las funciones creadas después del revoke inicial vuelven a heredar EXECUTE
-- de PUBLIC; se retira al final sin afectar las concesiones explícitas.
revoke execute on all functions in schema public from public;