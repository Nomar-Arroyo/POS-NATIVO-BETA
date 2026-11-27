// Pruebas de integración del backend sobre PostgreSQL real.
// Requisitos: bootstrap.sql + migraciones 0001-0004 + seed/demo.sql aplicados.
// Conexión: DATABASE_URL (por defecto postgres://postgres:postgres@127.0.0.1:5432/amalfi).
// Cada prueba abre una transacción, actúa con roles anon/authenticated y hace
// rollback, de modo que la suite es repetible sobre la misma base.

import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

const { Client } = pg;

const ORG_A = '11111111-1111-4111-8111-111111111111';
const ORG_B = '22222222-2222-4222-8222-222222222222';
const BRANCH_A1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
const BRANCH_A2 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
const WH_A1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01';
const REGISTER_A1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02';
const TABLE_1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11';
const TABLE_2 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa12';
const ADMIN_A = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';
const CASHIER_A = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc2';
const KITCHEN_A = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3';
const WAITER_A = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc4';
const ADMIN_B = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1';
const LATTE_V = '44444444-4444-4444-8444-444444444441';
const AREPA_V = '44444444-4444-4444-8444-444444444442';
const AGUA_V = '44444444-4444-4444-8444-444444444443';
const MILK_EXTRA = '66666666-6666-4666-8666-666666666661';

const client = new Client({
  connectionString:
    process.env.DATABASE_URL ||
    'postgres://postgres:postgres@127.0.0.1:5432/amalfi',
});

const key = (prefix) => `${prefix}-${randomUUID()}`;

async function withTx(fn) {
  await client.query('begin');
  try {
    await fn();
  } finally {
    await client.query('rollback');
  }
}

async function asUser(profileId) {
  await client.query('set local role authenticated');
  await client.query("select set_config('request.jwt.claim.sub', $1, true)", [
    profileId,
  ]);
}

async function asAnon() {
  await client.query('set local role anon');
}

async function asOwner() {
  await client.query('reset role');
}

async function rpc(fn, payload) {
  const res = await client.query(`select public.${fn}($1::jsonb) as result`, [
    JSON.stringify(payload),
  ]);
  return res.rows[0].result;
}

async function expectReject(sql, params, pattern) {
  try {
    await client.query(sql, params);
    assert.fail(`se esperaba rechazo: ${sql}`);
  } catch (error) {
    if (error.code === 'ERR_ASSERTION') throw error;
    assert.match(error.message, pattern);
    return error;
  }
}

async function scalar(sql, params = []) {
  const res = await client.query(sql, params);
  const row = res.rows[0];
  return row ? row[Object.keys(row)[0]] : undefined;
}

async function registerTerminal(name = `Terminal ${randomUUID().slice(0, 8)}`) {
  return rpc('rpc_register_terminal', {
    branch_id: BRANCH_A1,
    name,
    platform: 'windows',
    app_version: '0.1.0-test',
    idempotency_key: key('term'),
  });
}

async function openCash(terminalId) {
  return rpc('rpc_open_cash_session', {
    schema_version: 'cash.v1',
    cash_register_id: REGISTER_A1,
    terminal_id: terminalId,
    idempotency_key: key('cash'),
    opening_minor: { usd_minor: '10000' },
  });
}

function salePayload({
  terminalId,
  cashSessionId = null,
  diningSessionId = null,
  idempotencyKey,
  saleId = randomUUID(),
  unitPrice = 350,
  quantity = '2',
  total = 700,
  method = 'EFECTIVO_USD',
  consumptions = [],
}) {
  return {
    idempotency_key: idempotencyKey,
    schema_version: 'sale.v1',
    sale: {
      id: saleId,
      branch_id: BRANCH_A1,
      terminal_id: terminalId,
      cash_session_id: cashSessionId,
      dining_session_id: diningSessionId,
      sale_number: `T-${saleId.slice(0, 8)}`,
      total_currency: 'USD',
      total_minor: String(total),
    },
    items: [
      {
        variant_id: LATTE_V,
        quantity,
        unit_price_minor: String(unitPrice),
        subtotal_minor: String(total),
        tax_minor: '0',
      },
    ],
    payments: [
      {
        method,
        amount_minor: String(total),
        currency_code: 'USD',
        original_amount_minor: String(total),
        original_currency_code: 'USD',
      },
    ],
    inventory_consumptions: consumptions,
  };
}

async function newDevice(tableId = TABLE_1, label = 'Tablet Test') {
  await asUser(ADMIN_A);
  const created = await rpc('rpc_create_pairing_code', {
    branch_id: BRANCH_A1,
    dining_table_id: tableId,
    idempotency_key: key('pair'),
  });
  await asAnon();
  const claimed = await rpc('rpc_claim_pairing_code', {
    pairing_code: created.pairing_code,
    device_fingerprint: `fp-${randomUUID()}`,
    label,
  });
  return { created, claimed, token: claimed.session_token, deviceId: claimed.device_id };
}

async function submitOrder(token, items, orderKey = key('ord')) {
  return rpc('rpc_submit_customer_order', {
    session_token: token,
    idempotency_key: orderKey,
    items,
  });
}

test.before(async () => {
  await client.connect();
  const orgs = await scalar('select count(*)::int from public.organizations');
  assert.equal(orgs, 2, 'Ejecuta bootstrap.sql, migraciones y seed/demo.sql antes de probar');
});

test.after(async () => {
  await client.end();
});

test('esquema aplicado con RLS y privilegios mínimos', async () => {
  const withoutRls = await scalar(`
    select count(*)::int
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  `);
  assert.equal(withoutRls, 0);

  const anonGrants = await scalar(`
    select count(*)::int from information_schema.role_table_grants
     where grantee = 'anon' and table_schema = 'public'
  `);
  assert.equal(anonGrants, 0);

  const staffWrites = await scalar(`
    select count(*)::int from information_schema.role_table_grants
     where grantee = 'authenticated' and table_schema = 'public'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  `);
  assert.equal(staffWrites, 0);

  const publicWrites = await scalar(`
    select count(*)::int from information_schema.role_table_grants
     where grantee = 'PUBLIC' and table_schema = 'public'
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  `);
  assert.equal(publicWrites, 0);
});

test('anon no lee tablas ni ejecuta RPC de personal', async () => {
  await withTx(async () => {
    await asAnon();
    await expectReject('select * from public.products', [], /permission denied/i);
  });

  await withTx(async () => {
    await asAnon();
    await expectReject(
      "select public.rpc_confirm_sale('{}'::jsonb)",
      [],
      /permission denied/i,
    );
  });

  await withTx(async () => {
    await asAnon();
    await expectReject(
      "select public.rpc_create_pairing_code('{}'::jsonb)",
      [],
      /permission denied/i,
    );
  });
});

test('helpers internos de app no son ejecutables por roles de cliente', async () => {
  assert.equal(
    await scalar(`
      select count(*)::int from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'app' and has_function_privilege('anon', p.oid, 'execute')
    `),
    0,
  );
  assert.equal(
    await scalar("select has_schema_privilege('anon', 'app', 'usage')"),
    false,
  );

  await withTx(async () => {
    await asAnon();
    await expectReject(
      `select app.record_receipt($1, null, 'test', 'sale', gen_random_uuid(),
                                 'anon-key', 'v1', '{}'::jsonb, 1)`,
      [ORG_A],
      /permission denied|does not exist/i,
    );
  });

  assert.equal(
    await scalar(`
      select count(*)::int from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'app'
         and p.proname in ('current_organization_id', 'current_profile_id',
                           'branch_allowed', 'has_permission_in',
                           'production_station_allows')
         and not has_function_privilege('authenticated', p.oid, 'execute')
    `),
    0,
  );
});

test('aislamiento por organización y denegación de escritura directa', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    assert.equal(
      await scalar('select count(*)::int from public.products'),
      4,
    );
    assert.equal(
      await scalar('select count(*)::int from public.branches'),
      2,
    );
    assert.equal(
      await scalar(
        `select count(*)::int from public.products where organization_id = $1`,
        [ORG_B],
      ),
      0,
    );
  });

  await withTx(async () => {
    await asUser(ADMIN_A);
    await expectReject(
      `insert into public.products(id, organization_id, name)
       values (gen_random_uuid(), $1, 'Intruso')`,
      [ORG_A],
      /permission denied/i,
    );
  });

  await withTx(async () => {
    await asUser(ADMIN_B);
    await expectReject(
      'select public.rpc_register_terminal($1::jsonb)',
      [
        JSON.stringify({
          branch_id: BRANCH_A1,
          name: 'Terminal cruzado',
          idempotency_key: key('term'),
        }),
      ],
      /BRANCH_INVALID/,
    );
  });
});

test('cajero no administra configuración ni tablets', async () => {
  await withTx(async () => {
    await asUser(CASHIER_A);
    await expectReject(
      `select public.rpc_register_terminal($1::jsonb)`,
      [JSON.stringify({ branch_id: BRANCH_A1, name: 'X', idempotency_key: key('t') })],
      /FORBIDDEN/,
    );
  });

  await withTx(async () => {
    await asUser(CASHIER_A);
    await expectReject(
      `select public.rpc_create_pairing_code($1::jsonb)`,
      [JSON.stringify({ branch_id: BRANCH_A1, dining_table_id: TABLE_1 })],
      /FORBIDDEN/,
    );
  });
});

test('venta atómica, idempotente y con recibo verificable', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    assert.equal(terminal.accepted, true);
    const terminalId = terminal.entity_id;
    assert.match(terminal.terminal_token, /^[0-9a-f]{64}$/);

    await asOwner();
    const storedHash = await scalar(
      'select token_hash from public.terminals where id = $1',
      [terminalId],
    );
    assert.notEqual(storedHash, terminal.terminal_token);
    assert.match(storedHash, /^[0-9a-f]{64}$/);

    await asUser(CASHIER_A);
    const cash = await openCash(terminalId);
    assert.equal(cash.accepted, true);

    const saleId = randomUUID();
    const orderKey = key('sale');
    const payload = salePayload({
      terminalId,
      cashSessionId: cash.entity_id,
      idempotencyKey: orderKey,
      saleId,
      consumptions: [{ warehouse_id: WH_A1, variant_id: LATTE_V, quantity: '2000' }],
    });
    const sale = await rpc('rpc_confirm_sale', payload);
    assert.equal(sale.accepted, true);
    assert.equal(sale.duplicate, false);
    assert.equal(sale.entity_id, saleId);

    const dup = await rpc('rpc_confirm_sale', payload);
    assert.equal(dup.accepted, true);
    assert.equal(dup.duplicate, true);
    assert.equal(dup.entity_id, saleId);

    await asOwner();
    assert.equal(await scalar('select count(*)::int from public.sales'), 1);
    assert.equal(await scalar('select count(*)::int from public.payments'), 1);
    assert.equal(await scalar('select count(*)::int from public.cash_movements'), 1);
    assert.equal(
      await scalar(
        'select quantity_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '3000',
    );
    assert.equal(
      await scalar(
        `select count(*)::int from public.inventory_movements
          where movement_type = 'SALE_CONSUMPTION' and sale_id = $1`,
        [saleId],
      ),
      1,
    );
    assert.equal(
      await scalar(
        `select count(*)::int from public.sync_receipts
          where idempotency_key = $1 and accepted`,
        [orderKey],
      ),
      1,
    );
    assert.equal(
      await scalar(
        `select count(*)::int from public.audit_logs
          where action = 'SALE_CONFIRMED_REMOTE' and entity_id = $1`,
        [saleId],
      ),
      1,
    );
  });
});

test('precio manipulado se rechaza, se audita y exige nueva clave', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    await asUser(CASHIER_A);
    const cash = await openCash(terminal.entity_id);

    const badKey = key('sale');
    const bad = salePayload({
      terminalId: terminal.entity_id,
      cashSessionId: cash.entity_id,
      idempotencyKey: badKey,
      unitPrice: 1,
    });
    const res = await rpc('rpc_confirm_sale', bad);
    assert.equal(res.accepted, false);
    assert.equal(res.code, 'PRICE_CHANGED');

    await asOwner();
    assert.equal(await scalar('select count(*)::int from public.sales'), 0);
    assert.equal(
      await scalar(
        `select count(*)::int from public.sync_operations
          where idempotency_key = $1 and status = 'CONFLICT'
            and conflict_code = 'PRICE_CHANGED'`,
        [badKey],
      ),
      1,
    );
    assert.equal(
      await scalar(
        `select count(*)::int from public.audit_logs
          where action = 'SYNC_OPERATION_CONFLICT' and reason = 'PRICE_CHANGED'`,
      ),
      1,
    );

    await asUser(CASHIER_A);
    const corrected = salePayload({
      terminalId: terminal.entity_id,
      cashSessionId: cash.entity_id,
      idempotencyKey: badKey,
      unitPrice: 350,
    });
    const replay = await rpc('rpc_confirm_sale', corrected);
    assert.equal(replay.accepted, false);
    assert.equal(replay.code, 'PRICE_CHANGED');
    assert.equal(replay.idempotency_key, badKey);
    assert.equal(typeof replay.operation_id, 'string');

    await asOwner();
    assert.equal(await scalar('select count(*)::int from public.sales'), 0);
    assert.equal(
      await scalar(
        `select count(*)::int from public.sync_operations
          where idempotency_key = $1 and status = 'CONFLICT'`,
        [badKey],
      ),
      1,
    );
  });

  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    await asUser(CASHIER_A);
    const cash = await openCash(terminal.entity_id);
    const good = salePayload({
      terminalId: terminal.entity_id,
      cashSessionId: cash.entity_id,
      idempotencyKey: key('sale'),
    });
    const res = await rpc('rpc_confirm_sale', good);
    assert.equal(res.accepted, true);
  });
});

test('stock insuficiente revierte la venta completa', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    await asUser(CASHIER_A);
    const cash = await openCash(terminal.entity_id);

    const res = await rpc(
      'rpc_confirm_sale',
      salePayload({
        terminalId: terminal.entity_id,
        cashSessionId: cash.entity_id,
        idempotencyKey: key('sale'),
        consumptions: [
          { warehouse_id: WH_A1, variant_id: LATTE_V, quantity: '999000' },
        ],
      }),
    );
    assert.equal(res.accepted, false);
    assert.equal(res.code, 'INSUFFICIENT_STOCK');

    await asOwner();
    assert.equal(await scalar('select count(*)::int from public.sales'), 0);
    assert.equal(await scalar('select count(*)::int from public.payments'), 0);
    assert.equal(
      await scalar(
        'select quantity_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '5000',
    );
  });

  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    await asUser(CASHIER_A);
    const cash = await openCash(terminal.entity_id);
    const res = await rpc(
      'rpc_confirm_sale',
      salePayload({
        terminalId: terminal.entity_id,
        cashSessionId: cash.entity_id,
        idempotencyKey: key('sale'),
        consumptions: [
          { warehouse_id: WH_A1, variant_id: LATTE_V, quantity: '1000' },
        ],
      }),
    );
    assert.equal(res.accepted, true);
  });
});

test('venta de mesa cierra sesión y libera la mesa', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();

    await asUser(WAITER_A);
    const dining = await rpc('rpc_open_dining_session', {
      schema_version: 'dining.v1',
      dining_table_id: TABLE_2,
      terminal_id: terminal.entity_id,
      idempotency_key: key('dining'),
    });
    assert.equal(dining.accepted, true);

    const sale = await rpc(
      'rpc_confirm_sale',
      salePayload({
        terminalId: terminal.entity_id,
        diningSessionId: dining.entity_id,
        idempotencyKey: key('sale'),
        method: 'TARJETA',
      }),
    );
    assert.equal(sale.accepted, true);

    await asOwner();
    assert.equal(
      await scalar('select status from public.dining_sessions where id = $1', [
        dining.entity_id,
      ]),
      'CLOSED',
    );
    assert.equal(
      await scalar('select status from public.dining_tables where id = $1', [
        TABLE_2,
      ]),
      'FREE',
    );
    assert.equal(
      await scalar('select sale_kind from public.sales where id = $1', [
        sale.entity_id,
      ]),
      'dining',
    );
  });
});

test('terminal revocado no puede confirmar ventas', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    const revoked = await rpc('rpc_revoke_terminal', {
      terminal_id: terminal.entity_id,
      idempotency_key: key('revoke'),
    });
    assert.equal(revoked.accepted, true);

    await asUser(CASHIER_A);
    const res = await rpc(
      'rpc_confirm_sale',
      salePayload({
        terminalId: terminal.entity_id,
        idempotencyKey: key('sale'),
        method: 'TARJETA',
      }),
    );
    assert.equal(res.accepted, false);
    assert.equal(res.code, 'TERMINAL_INVALID');

    await asOwner();
    assert.equal(await scalar('select count(*)::int from public.sales'), 0);
  });
});

test('perfil deshabilitado no opera', async () => {
  await withTx(async () => {
    await asOwner();
    await client.query(
      "update public.profiles set status = 'disabled' where id = $1",
      [CASHIER_A],
    );
    await asUser(CASHIER_A);
    await expectReject(
      `select public.rpc_open_cash_session($1::jsonb)`,
      [
        JSON.stringify({
          schema_version: 'cash.v1',
          cash_register_id: REGISTER_A1,
          terminal_id: randomUUID(),
          idempotency_key: key('cash'),
        }),
      ],
      /UNAUTHENTICATED/,
    );
  });
});

test('pairing: código de un solo uso, hash persistido y vencimiento', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    assert.equal(device.claimed.accepted, true);
    assert.match(device.claimed.session_token, /^[0-9a-f]{64}$/);
    assert.equal(device.claimed.table.name, 'Mesa 1');

    await asOwner();
    const stored = await client.query(
      'select code_hash, status from public.device_pairing_codes where id = $1',
      [device.created.pairing_code_id],
    );
    assert.equal(stored.rows[0].status, 'USED');
    assert.match(stored.rows[0].code_hash, /^[0-9a-f]{64}$/);
    assert.notEqual(stored.rows[0].code_hash, device.created.pairing_code);

    await asAnon();
    await expectReject(
      'select public.rpc_claim_pairing_code($1::jsonb)',
      [
        JSON.stringify({
          pairing_code: device.created.pairing_code,
          device_fingerprint: `fp-${randomUUID()}`,
        }),
      ],
      /PAIRING_CODE_INVALID/,
    );
  });

  await withTx(async () => {
    await asUser(ADMIN_A);
    const created = await rpc('rpc_create_pairing_code', {
      branch_id: BRANCH_A1,
      dining_table_id: TABLE_2,
      idempotency_key: key('pair'),
    });
    await asOwner();
    await client.query(
      "update public.device_pairing_codes set expires_at = now() - interval '1 minute' where id = $1",
      [created.pairing_code_id],
    );
    await asAnon();
    await expectReject(
      'select public.rpc_claim_pairing_code($1::jsonb)',
      [
        JSON.stringify({
          pairing_code: created.pairing_code,
          device_fingerprint: `fp-${randomUUID()}`,
        }),
      ],
      /PAIRING_CODE_EXPIRED/,
    );
  });
});

test('dispositivo revocado pierde acceso al menú', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    await asUser(ADMIN_A);
    const revoked = await rpc('rpc_revoke_customer_device', {
      device_id: device.deviceId,
      idempotency_key: key('revoke-device'),
      reason: 'prueba',
    });
    assert.equal(revoked.accepted, true);

    await asAnon();
    await expectReject(
      'select public.rpc_device_menu($1::jsonb)',
      [JSON.stringify({ session_token: device.token })],
      /DEVICE_SESSION_INVALID/,
    );
  });
});

test('menú de tablet sin productos sintéticos y con precios de servidor', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const menu = await rpc('rpc_device_menu', { session_token: device.token });
    assert.equal(menu.table.name, 'Mesa 1');
    assert.equal(menu.categories.length, 2);
    assert.equal(menu.products.length, 3);
    assert.ok(menu.products.every((product) => product.name !== 'Ajuste interno'));
    const latte = menu.products.find((product) => product.id === '33333333-3333-4333-8333-333333333331');
    assert.equal(latte.variants.length, 1);
    assert.equal(latte.variants[0].price_minor, 350);
    assert.equal(latte.modifiers.length, 2);
    assert.equal(latte.station, 'BAR');
  });
});

test('pedido de cliente: totales de servidor, producción y sin venta/pagos', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const orderKey = key('order');
    const first = await submitOrder(
      device.token,
      [
        {
          variant_id: LATTE_V,
          quantity: '2',
          unit_price_minor: '1',
          modifier_ids: [MILK_EXTRA],
        },
        { variant_id: AREPA_V, quantity: '1' },
      ],
      orderKey,
    );
    assert.equal(first.accepted, true);
    assert.equal(first.total_minor, 1400);
    assert.equal(first.total_currency, 'USD');
    assert.equal(first.status, 'RECEIVED');

    const dup = await submitOrder(device.token, [], orderKey);
    assert.equal(dup.duplicate, true);
    assert.equal(dup.order_id, first.order_id);

    await asOwner();
    assert.equal(await scalar('select count(*)::int from public.customer_orders'), 1);
    assert.equal(await scalar('select count(*)::int from public.customer_order_items'), 2);
    assert.equal(await scalar('select count(*)::int from public.customer_order_modifiers'), 1);
    assert.equal(
      await scalar('select total_minor from public.customer_orders where id = $1', [
        first.order_id,
      ]),
      '1400',
    );
    assert.equal(await scalar('select count(*)::int from public.sales'), 0);
    assert.equal(await scalar('select count(*)::int from public.payments'), 0);
    assert.equal(
      await scalar(
        'select count(distinct station)::int from public.production_orders where customer_order_id = $1',
        [first.order_id],
      ),
      2,
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.production_orders where customer_order_id = $1 and status = 'PENDING'",
        [first.order_id],
      ),
      2,
    );
    assert.equal(
      await scalar('select status from public.dining_tables where id = $1', [TABLE_1]),
      'OCCUPIED',
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.dining_sessions where dining_table_id = $1 and status = 'OPEN'",
        [TABLE_1],
      ),
      1,
    );
    assert.equal(
      await scalar(
        'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '2000',
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.inventory_reservations where customer_order_id = $1 and status = 'ACTIVE'",
        [first.order_id],
      ),
      2,
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.audit_logs where action = 'CUSTOMER_ORDER_SUBMITTED' and entity_id = $1",
        [first.order_id],
      ),
      1,
    );

    await asAnon();
    const status = await rpc('rpc_customer_order_status', {
      session_token: device.token,
    });
    assert.equal(status.orders.length, 1);
    assert.equal(status.orders[0].status, 'RECEIVED');
    assert.equal(status.orders[0].production.length, 2);
  });
});

test('cocina/barra actualizan el estado visible del pedido', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
      { variant_id: AREPA_V, quantity: '1' },
    ]);

    await asOwner();
    const production = await client.query(
      "select id, station from public.production_orders where customer_order_id = $1 order by station",
      [order.order_id],
    );
    const bar = production.rows.find((row) => row.station === 'BAR');
    const kitchen = production.rows.find((row) => row.station === 'KITCHEN');

    await asUser(KITCHEN_A);
    await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: bar.id,
      status: 'PREPARING',
      idempotency_key: key('prod'),
    });

    await asAnon();
    let status = await rpc('rpc_customer_order_status', {
      session_token: device.token,
      order_id: order.order_id,
    });
    assert.equal(status.orders[0].status, 'PREPARING');

    await asUser(KITCHEN_A);
    await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: bar.id,
      status: 'READY',
      idempotency_key: key('prod'),
    });
    await asAnon();
    status = await rpc('rpc_customer_order_status', {
      session_token: device.token,
      order_id: order.order_id,
    });
    assert.equal(status.orders[0].status, 'PREPARING');

    await asUser(KITCHEN_A);
    await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: kitchen.id,
      status: 'PREPARING',
      idempotency_key: key('prod'),
    });
    await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: kitchen.id,
      status: 'READY',
      idempotency_key: key('prod'),
    });

    await asAnon();
    status = await rpc('rpc_customer_order_status', {
      session_token: device.token,
      order_id: order.order_id,
    });
    assert.equal(status.orders[0].status, 'READY');
  });
});

test('estación de producción limita lectura, envío y cambio de estado', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
      { variant_id: AREPA_V, quantity: '1' },
    ]);

    await asOwner();
    const production = await client.query(
      "select id, station from public.production_orders where customer_order_id = $1",
      [order.order_id],
    );
    const bar = production.rows.find((row) => row.station === 'BAR');
    const kitchen = production.rows.find((row) => row.station === 'KITCHEN');
    const diningSessionId = await scalar(
      "select id from public.dining_sessions where dining_table_id = $1 and status = 'OPEN'",
      [TABLE_1],
    );
    await client.query(
      "update public.profiles set production_station = 'KITCHEN' where id = $1",
      [KITCHEN_A],
    );

    await asUser(KITCHEN_A);
    const visible = await client.query(
      'select station from public.production_orders order by station',
    );
    assert.deepEqual(visible.rows.map((row) => row.station), ['KITCHEN']);
    const visibleItems = await client.query(
      'select count(*)::int as total from public.production_order_items',
    );
    assert.equal(visibleItems.rows[0].total, 1);

    await client.query('savepoint station_denied');
    await expectReject(
      'select public.rpc_update_production_status($1::jsonb)',
      [
        JSON.stringify({
          schema_version: 'production.v1',
          production_order_id: bar.id,
          status: 'PREPARING',
          idempotency_key: key('prod'),
        }),
      ],
      /FORBIDDEN/,
    );
    await client.query('rollback to savepoint station_denied');

    const kitchenUpdate = await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: kitchen.id,
      status: 'PREPARING',
      idempotency_key: key('prod'),
    });
    assert.equal(kitchenUpdate.accepted, true);

    await asOwner();
    await client.query(
      "update public.profiles set production_station = 'KITCHEN' where id = $1",
      [ADMIN_A],
    );
    await asUser(ADMIN_A);
    const sendKey = key('send');
    await client.query('savepoint send_denied');
    await expectReject(
      'select public.rpc_send_production($1::jsonb)',
      [
        JSON.stringify({
          schema_version: 'production.v1',
          dining_session_id: diningSessionId,
          station: 'BAR',
          idempotency_key: sendKey,
        }),
      ],
      /FORBIDDEN/,
    );
    await client.query('rollback to savepoint send_denied');

    await asOwner();
    assert.equal(
      await scalar('select status from public.production_orders where id = $1', [
        bar.id,
      ]),
      'PENDING',
    );
    assert.equal(
      await scalar(
        'select count(*)::int from public.sync_operations where idempotency_key = $1',
        [sendKey],
      ),
      0,
    );
  });
});

test('venta de mesa consume las reservas del pedido sin liberarlas dos veces', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
      { variant_id: AREPA_V, quantity: '1' },
    ]);
    assert.equal(order.accepted, true);

    await asOwner();
    const diningSessionId = await scalar(
      "select id from public.dining_sessions where dining_table_id = $1 and status = 'OPEN'",
      [TABLE_1],
    );
    assert.ok(diningSessionId);
    assert.equal(
      await scalar(
        'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '1000',
    );
    assert.equal(
      await scalar(
        'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, AREPA_V],
      ),
      '1000',
    );

    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    const saleId = randomUUID();
    const payload = {
      idempotency_key: key('sale'),
      schema_version: 'sale.v1',
      sale: {
        id: saleId,
        branch_id: BRANCH_A1,
        terminal_id: terminal.entity_id,
        cash_session_id: null,
        dining_session_id: diningSessionId,
        sale_number: `T-${saleId.slice(0, 8)}`,
        total_currency: 'USD',
        total_minor: '850',
      },
      items: [
        {
          variant_id: LATTE_V,
          quantity: '1',
          unit_price_minor: '350',
          tax_minor: '0',
        },
        {
          variant_id: AREPA_V,
          quantity: '1',
          unit_price_minor: '500',
          tax_minor: '0',
        },
      ],
      payments: [
        { method: 'TARJETA', amount_minor: '850', currency_code: 'USD' },
      ],
      inventory_consumptions: [
        { warehouse_id: WH_A1, variant_id: LATTE_V, quantity: '1000' },
        { warehouse_id: WH_A1, variant_id: AREPA_V, quantity: '1000' },
      ],
    };

    const sale = await rpc('rpc_confirm_sale', payload);
    assert.equal(sale.accepted, true);
    assert.equal(sale.entity_id, saleId);

    const dup = await rpc('rpc_confirm_sale', payload);
    assert.equal(dup.accepted, true);
    assert.equal(dup.duplicate, true);

    await asOwner();
    assert.equal(
      await scalar(
        "select count(*)::int from public.inventory_reservations where customer_order_id = $1 and status = 'CONSUMED'",
        [order.order_id],
      ),
      2,
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.inventory_reservations where customer_order_id = $1 and status = 'RELEASED'",
        [order.order_id],
      ),
      0,
    );
    assert.equal(
      await scalar(
        'select quantity_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '4000',
    );
    assert.equal(
      await scalar(
        'select quantity_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, AREPA_V],
      ),
      '2000',
    );
    for (const variant of [LATTE_V, AREPA_V]) {
      assert.equal(
        await scalar(
          'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
          [WH_A1, variant],
        ),
        '0',
      );
    }
    assert.equal(
      await scalar(
        `select after_json->>'reservations_consumed'
           from public.audit_logs
          where action = 'SALE_CONFIRMED_REMOTE' and entity_id = $1`,
        [saleId],
      ),
      '2',
    );
    assert.equal(
      await scalar('select status from public.dining_sessions where id = $1', [
        diningSessionId,
      ]),
      'CLOSED',
    );
  });
});

test('venta directa no consume ni libera reservas de una mesa', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
    ]);
    assert.equal(order.accepted, true);

    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    const sale = await rpc('rpc_confirm_sale', {
      idempotency_key: key('sale'),
      schema_version: 'sale.v1',
      sale: {
        id: randomUUID(),
        branch_id: BRANCH_A1,
        terminal_id: terminal.entity_id,
        cash_session_id: null,
        dining_session_id: null,
        sale_number: `T-${randomUUID().slice(0, 8)}`,
        total_currency: 'USD',
        total_minor: '350',
      },
      items: [
        {
          variant_id: LATTE_V,
          quantity: '1',
          unit_price_minor: '350',
          tax_minor: '0',
        },
      ],
      payments: [
        { method: 'TARJETA', amount_minor: '350', currency_code: 'USD' },
      ],
      inventory_consumptions: [
        { warehouse_id: WH_A1, variant_id: LATTE_V, quantity: '1000' },
      ],
    });
    assert.equal(sale.accepted, true);

    await asOwner();
    assert.equal(
      await scalar(
        "select count(*)::int from public.inventory_reservations where customer_order_id = $1 and status = 'ACTIVE'",
        [order.order_id],
      ),
      1,
    );
    assert.equal(
      await scalar(
        'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '1000',
    );
  });
});

test('venta de mesa libera las reservas de líneas no vendidas', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_2);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
      { variant_id: AREPA_V, quantity: '1' },
    ]);
    assert.equal(order.accepted, true);

    await asOwner();
    const diningSessionId = await scalar(
      "select id from public.dining_sessions where dining_table_id = $1 and status = 'OPEN'",
      [TABLE_2],
    );
    assert.ok(diningSessionId);

    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    const saleId = randomUUID();
    const sale = await rpc('rpc_confirm_sale', {
      idempotency_key: key('sale'),
      schema_version: 'sale.v1',
      sale: {
        id: saleId,
        branch_id: BRANCH_A1,
        terminal_id: terminal.entity_id,
        cash_session_id: null,
        dining_session_id: diningSessionId,
        sale_number: `T-${saleId.slice(0, 8)}`,
        total_currency: 'USD',
        total_minor: '350',
      },
      items: [
        {
          variant_id: LATTE_V,
          quantity: '1',
          unit_price_minor: '350',
          tax_minor: '0',
        },
      ],
      payments: [
        { method: 'TARJETA', amount_minor: '350', currency_code: 'USD' },
      ],
      inventory_consumptions: [
        { warehouse_id: WH_A1, variant_id: LATTE_V, quantity: '1000' },
      ],
    });
    assert.equal(sale.accepted, true);

    await asOwner();
    const states = await client.query(
      `select variant_id, status from public.inventory_reservations
        where customer_order_id = $1 order by variant_id`,
      [order.order_id],
    );
    assert.equal(
      states.rows.find((row) => row.variant_id === LATTE_V).status,
      'CONSUMED',
    );
    assert.equal(
      states.rows.find((row) => row.variant_id === AREPA_V).status,
      'RELEASED',
    );
    assert.equal(
      await scalar(
        'select quantity_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '4000',
    );
    assert.equal(
      await scalar(
        'select quantity_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, AREPA_V],
      ),
      '3000',
    );
    for (const variant of [LATTE_V, AREPA_V]) {
      assert.equal(
        await scalar(
          'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
          [WH_A1, variant],
        ),
        '0',
      );
    }
    assert.equal(
      await scalar(
        `select after_json->>'reservations_consumed'
           from public.audit_logs
          where action = 'SALE_CONFIRMED_REMOTE' and entity_id = $1`,
        [saleId],
      ),
      '1',
    );
    assert.equal(
      await scalar('select status from public.dining_sessions where id = $1', [
        diningSessionId,
      ]),
      'CLOSED',
    );
  });
});

test('estación autorizada envía y avanza su comanda; el replay es idempotente', async () => {
  await withTx(async () => {
    await asUser(ADMIN_A);
    const terminal = await registerTerminal();
    const opened = await rpc('rpc_open_dining_session', {
      schema_version: 'dining.v1',
      dining_table_id: TABLE_1,
      terminal_id: terminal.entity_id,
      idempotency_key: key('dining'),
    });
    assert.equal(opened.accepted, true);
    const diningSessionId = opened.entity_id;

    for (const variant of [LATTE_V, AREPA_V]) {
      const added = await rpc('rpc_add_dining_item', {
        schema_version: 'dining.v1',
        dining_session_id: diningSessionId,
        variant_id: variant,
        quantity: '1',
        idempotency_key: key('item'),
      });
      assert.equal(added.accepted, true);
    }

    await asOwner();
    await client.query(
      "update public.profiles set production_station = 'BAR' where id = $1",
      [ADMIN_A],
    );

    await asUser(ADMIN_A);
    const sendKey = key('send');
    const send = await rpc('rpc_send_production', {
      schema_version: 'production.v1',
      dining_session_id: diningSessionId,
      station: 'BAR',
      idempotency_key: sendKey,
    });
    assert.equal(send.accepted, true);

    const visible = await client.query(
      'select distinct station from public.production_orders',
    );
    assert.deepEqual(
      visible.rows.map((row) => row.station),
      ['BAR'],
    );

    const replay = await rpc('rpc_send_production', {
      schema_version: 'production.v1',
      dining_session_id: diningSessionId,
      station: 'BAR',
      idempotency_key: sendKey,
    });
    assert.equal(replay.duplicate, true);
    assert.equal(replay.operation_id, send.operation_id);

    await asOwner();
    const sentOrder = await scalar(
      `select id from public.production_orders
        where dining_session_id = $1 and station = 'BAR'
          and customer_order_id is null`,
      [diningSessionId],
    );
    assert.ok(sentOrder);

    await asUser(ADMIN_A);
    const advanced = await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: sentOrder,
      status: 'PREPARING',
      idempotency_key: key('prod'),
    });
    assert.equal(advanced.accepted, true);

    await client.query('savepoint station_denied_positive');
    await expectReject(
      'select public.rpc_send_production($1::jsonb)',
      [
        JSON.stringify({
          schema_version: 'production.v1',
          dining_session_id: diningSessionId,
          station: 'KITCHEN',
          idempotency_key: key('send'),
        }),
      ],
      /FORBIDDEN/,
    );
    await client.query('rollback to savepoint station_denied_positive');

    await asOwner();
    await client.query(
      "update public.profiles set production_station = 'BOTH' where id = $1",
      [ADMIN_A],
    );
    await asUser(ADMIN_A);
    const kitchenSend = await rpc('rpc_send_production', {
      schema_version: 'production.v1',
      dining_session_id: diningSessionId,
      station: 'KITCHEN',
      idempotency_key: key('send'),
    });
    assert.equal(kitchenSend.accepted, true);
    const stations = await client.query(
      'select distinct station from public.production_orders',
    );
    assert.deepEqual(
      stations.rows.map((row) => row.station).sort(),
      ['BAR', 'KITCHEN'],
    );
  });
});

test('cancelación del cliente libera reservas y es idempotente', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
    ]);
    const cancelKey = key('cancel');

    const cancelled = await rpc('rpc_cancel_customer_order', {
      session_token: device.token,
      order_id: order.order_id,
      reason: 'cambio de opinión',
      idempotency_key: cancelKey,
    });
    assert.equal(cancelled.accepted, true);
    assert.equal(cancelled.status, 'CANCELLED');

    const dup = await rpc('rpc_cancel_customer_order', {
      session_token: device.token,
      order_id: order.order_id,
      idempotency_key: cancelKey,
    });
    assert.equal(dup.duplicate, true);

    await asOwner();
    assert.equal(
      await scalar('select status from public.customer_orders where id = $1', [
        order.order_id,
      ]),
      'CANCELLED',
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.inventory_reservations where customer_order_id = $1 and status = 'RELEASED'",
        [order.order_id],
      ),
      1,
    );
    assert.equal(
      await scalar(
        'select reserved_minor from public.inventory_balances where warehouse_id = $1 and variant_id = $2',
        [WH_A1, LATTE_V],
      ),
      '0',
    );
    assert.equal(
      await scalar(
        "select count(*)::int from public.production_orders where customer_order_id = $1 and status = 'CANCELLED'",
        [order.order_id],
      ),
      1,
    );

    await asAnon();
    await expectReject(
      'select public.rpc_cancel_customer_order($1::jsonb)',
      [
        JSON.stringify({
          session_token: device.token,
          order_id: order.order_id,
          idempotency_key: key('cancel'),
        }),
      ],
      /ORDER_ALREADY_CANCELLED/,
    );
  });
});

test('no se cancela un pedido que ya está en preparación', async () => {
  await withTx(async () => {
    const device = await newDevice(TABLE_1);
    const order = await submitOrder(device.token, [
      { variant_id: LATTE_V, quantity: '1' },
    ]);

    await asOwner();
    const bar = await scalar(
      "select id from public.production_orders where customer_order_id = $1 and station = 'BAR'",
      [order.order_id],
    );
    await asUser(KITCHEN_A);
    await rpc('rpc_update_production_status', {
      schema_version: 'production.v1',
      production_order_id: bar,
      status: 'PREPARING',
      idempotency_key: key('prod'),
    });

    await asAnon();
    await expectReject(
      'select public.rpc_cancel_customer_order($1::jsonb)',
      [
        JSON.stringify({
          session_token: device.token,
          order_id: order.order_id,
          idempotency_key: key('cancel'),
        }),
      ],
      /ORDER_NOT_CANCELLABLE/,
    );
  });
});

test('descarga incremental de catálogo con cursor y alcance de sucursal', async () => {
  await withTx(async () => {
    await asUser(CASHIER_A);
    const full = await rpc('rpc_pull_catalog', {});
    assert.ok(full.cursor);
    assert.equal(full.products.length, 4);
    assert.equal(full.categories.length, 2);
    assert.equal(full.tables.length, 2);
    assert.ok(full.tables.every((table) => table.branch_id === BRANCH_A1));

    const delta = await rpc('rpc_pull_catalog', { since: full.cursor });
    assert.equal(delta.products.length, 0);
    assert.equal(delta.categories.length, 0);
  });

  await withTx(async () => {
    await asUser(ADMIN_B);
    const pull = await rpc('rpc_pull_catalog', {});
    assert.equal(pull.products.length, 1);
    assert.equal(pull.products[0].organization_id, ORG_B);
    assert.equal(pull.tables.length, 1);
  });

  await withTx(async () => {
    await asAnon();
    await expectReject(
      "select public.rpc_pull_catalog('{}'::jsonb)",
      [],
      /permission denied/i,
    );
  });
});

test('auditoría y movimientos son append-only', async () => {
  await withTx(async () => {
    await asOwner();
    await client.query(
      `insert into public.audit_logs(organization_id, action, entity_type)
       values ($1, 'TEST_ROW', 'test')`,
      [ORG_A],
    );
    await expectReject(
      "update public.audit_logs set reason = 'alterado'",
      [],
      /APPEND_ONLY/,
    );
  });

  await withTx(async () => {
    await asOwner();
    await client.query(
      `insert into public.inventory_movements(
         organization_id, warehouse_id, variant_id, movement_type,
         quantity_minor, idempotency_key)
       values ($1, $2, $3, 'ADJUSTMENT', 1, $4)`,
      [ORG_A, WH_A1, AGUA_V, key('mov')],
    );
    await expectReject(
      'delete from public.inventory_movements',
      [],
      /APPEND_ONLY/,
    );
  });
});