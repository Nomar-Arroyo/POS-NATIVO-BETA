-- Datos sintéticos para demo y pruebas. No contener información real.
-- Requiere migraciones 0001-0004 aplicadas y ejecutarse como owner/servicio.
-- Las identidades de auth.users solo se insertan en entornos de prueba: en
-- Supabase crea los usuarios con Auth y enlaza su UUID en public.profiles.

-- Organizaciones ----------------------------------------------------------

insert into public.organizations(id, name, tax_id, status) values
  ('11111111-1111-4111-8111-111111111111', 'Café Amalfi (demo)', 'J-DEMO-0001', 'active'),
  ('22222222-2222-4222-8222-222222222222', 'Organización Aislada (demo)', 'J-DEMO-0002', 'active')
on conflict (id) do nothing;

insert into public.branches(id, organization_id, name, code) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111', 'Sede Centro', 'A1'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', '11111111-1111-4111-8111-111111111111', 'Sede Playa', 'A2'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', '22222222-2222-4222-8222-222222222222', 'Sede Ajena', 'B1')
on conflict (id) do nothing;

insert into public.warehouses(id, organization_id, branch_id, name, code) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Almacén Centro', 'WH-A1'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01', '22222222-2222-4222-8222-222222222222',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'Almacén Ajeno', 'WH-B1')
on conflict (id) do nothing;

insert into public.cash_registers(id, organization_id, branch_id, name) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Caja Centro 1')
on conflict (id) do nothing;

insert into public.dining_tables(id, organization_id, branch_id, name, capacity) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Mesa 1', 4),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa12', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Mesa 2', 2),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb11', '22222222-2222-4222-8222-222222222222',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'Mesa Ajena 1', 4)
on conflict (id) do nothing;

insert into public.exchange_rates(
  id, organization_id, base_currency, quote_currency, rate_numerator,
  rate_denominator, effective_from, source
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa31', '11111111-1111-4111-8111-111111111111',
  'USD', 'VES', 365000, 10000, '2026-01-01T00:00:00Z', 'demo'
)
on conflict (id) do nothing;

-- Identidades (solo pruebas) ---------------------------------------------

insert into auth.users(id, email) values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'admin@amalfi.demo'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'cajero@amalfi.demo'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'cocina@amalfi.demo'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', 'mesonero@amalfi.demo'),
  ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1', 'admin@ajena.demo')
on conflict (id) do nothing;

insert into public.profiles(id, organization_id, display_name) values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', '11111111-1111-4111-8111-111111111111', 'Admin Demo'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', '11111111-1111-4111-8111-111111111111', 'Cajero Demo'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', '11111111-1111-4111-8111-111111111111', 'Cocina Demo'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', '11111111-1111-4111-8111-111111111111', 'Mesonero Demo'),
  ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1', '22222222-2222-4222-8222-222222222222', 'Admin Ajena')
on conflict (id) do nothing;

select app.install_default_roles('11111111-1111-4111-8111-111111111111');
select app.install_default_roles('22222222-2222-4222-8222-222222222222');

insert into public.profile_roles(profile_id, role_id, organization_id)
select v.profile_id, r.id, v.organization_id
  from (values
    ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1'::uuid, '11111111-1111-4111-8111-111111111111'::uuid, 'org_admin'),
    ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2'::uuid, '11111111-1111-4111-8111-111111111111'::uuid, 'cashier'),
    ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3'::uuid, '11111111-1111-4111-8111-111111111111'::uuid, 'kitchen'),
    ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4'::uuid, '11111111-1111-4111-8111-111111111111'::uuid, 'waiter'),
    ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1'::uuid, '22222222-2222-4222-8222-222222222222'::uuid, 'org_admin')
  ) as v(profile_id, organization_id, role_code)
  join public.roles r
    on r.organization_id = v.organization_id and r.code = v.role_code
on conflict do nothing;

insert into public.profile_branches(profile_id, branch_id, organization_id) values
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
   '11111111-1111-4111-8111-111111111111'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
   '11111111-1111-4111-8111-111111111111'),
  ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
   '11111111-1111-4111-8111-111111111111')
on conflict do nothing;

-- Catálogo ----------------------------------------------------------------

insert into public.categories(id, organization_id, name, sort_order) values
  ('55555555-5555-4555-8555-555555555551', '11111111-1111-4111-8111-111111111111', 'Bebidas', 10),
  ('55555555-5555-4555-8555-555555555552', '11111111-1111-4111-8111-111111111111', 'Comidas', 20),
  ('55555555-5555-4555-8555-55555555555b', '22222222-2222-4222-8222-222222222222', 'Bebidas', 10)
on conflict (id) do nothing;

insert into public.products(
  id, organization_id, category_id, sku, name, base_currency, price_minor,
  fulfillment_station, is_synthetic
) values
  ('33333333-3333-4333-8333-333333333331', '11111111-1111-4111-8111-111111111111',
   '55555555-5555-4555-8555-555555555551', 'LATTE', 'Café Latte', 'USD', 350, 'BAR', false),
  ('33333333-3333-4333-8333-333333333332', '11111111-1111-4111-8111-111111111111',
   '55555555-5555-4555-8555-555555555552', 'AREPA', 'Arepa de queso', 'USD', 500, 'KITCHEN', false),
  ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111',
   '55555555-5555-4555-8555-555555555551', 'AGUA', 'Agua mineral', 'USD', 150, 'UNASSIGNED', false),
  ('33333333-3333-4333-8333-333333333334', '11111111-1111-4111-8111-111111111111',
   null, 'SYNTH', 'Ajuste interno', 'USD', 0, 'UNASSIGNED', true),
  ('33333333-3333-4333-8333-33333333333b', '22222222-2222-4222-8222-222222222222',
   '55555555-5555-4555-8555-55555555555b', 'B-LATTE', 'Latte ajeno', 'USD', 400, 'BAR', false)
on conflict (id) do nothing;

insert into public.product_variants(
  id, organization_id, product_id, sku, name, price_minor
) values
  ('44444444-4444-4444-8444-444444444441', '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333331', 'LATTE-REG', 'Regular', 350),
  ('44444444-4444-4444-8444-444444444442', '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333332', 'AREPA-Q', 'Regular', 500),
  ('44444444-4444-4444-8444-444444444443', '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333333', 'AGUA-500', '500 ml', 150),
  ('44444444-4444-4444-8444-444444444444', '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333334', 'SYNTH-REG', 'Regular', 0),
  ('44444444-4444-4444-8444-44444444444b', '22222222-2222-4222-8222-222222222222',
   '33333333-3333-4333-8333-33333333333b', 'B-LATTE-REG', 'Regular', 400)
on conflict (id) do nothing;

insert into public.product_modifiers(
  id, organization_id, product_id, group_name, name, price_delta_minor,
  min_select, max_select
) values
  ('66666666-6666-4666-8666-666666666661', '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333331', 'Leche', 'Extra leche', 100, 0, 1),
  ('66666666-6666-4666-8666-666666666662', '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333331', 'Leche', 'Sin lactosa', 0, 0, 1)
on conflict (id) do nothing;

insert into public.inventory_balances(
  organization_id, warehouse_id, variant_id, quantity_minor, reserved_minor
) values
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
   '44444444-4444-4444-8444-444444444441', 5000, 0),
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
   '44444444-4444-4444-8444-444444444442', 3000, 0),
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
   '44444444-4444-4444-8444-444444444443', 10000, 0)
on conflict (warehouse_id, variant_id) do nothing;