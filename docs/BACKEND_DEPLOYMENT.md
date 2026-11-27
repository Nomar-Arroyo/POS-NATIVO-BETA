# Despliegue del backend

Este documento describe cómo llevar las migraciones a un proyecto Supabase.
El backend fue verificado localmente contra PostgreSQL 19 con 19 pruebas de
integración y en GitHub Actions contra PostgreSQL 16 con 19/19 pruebas; **no se
ha desplegado a un proyecto Supabase real**.

## 1. Requisitos

- Proyecto Supabase con PostgreSQL 14+ y Auth habilitado.
- Supabase CLI (`supabase link --project-ref ...`) o acceso SQL administrado.
- Node 20+ solo para ejecutar las pruebas.
- Copia de seguridad o proyecto de staging antes del primer `db push`.

## 2. Orden de aplicación

Las migraciones son secuenciales e inmutables. Aplícalas en orden:

1. `20261126090000_0001_core_schema.sql`
2. `20261126090100_0002_authz_rls.sql`
3. `20261126090200_0003_commercial_rpc.sql`
4. `20261126090300_0004_customer_sync.sql`

Con Supabase CLI:

```bash
supabase link --project-ref <ref>
supabase db push
```

`supabase db push` aplica `supabase/migrations/` en orden. **No** apliques
`supabase/tests/bootstrap.sql` en Supabase: crea `auth.users` y `auth.uid()`
ficticios y está pensado para PostgreSQL local.

## 3. Datos iniciales (sin secretos)

1. Crea la organización, sucursal(es), almacén, caja y mesas con SQL
   administrativo (o un seed propio que no se versiona con credenciales).
2. Crea los usuarios en Supabase Auth (Dashboard o Admin API) y sus filas en
   `public.profiles` con el mismo `id`.
3. Ejecuta `select app.install_default_roles('<organization_id>');` para crear
   los 22 permisos y los 6 roles.
4. Asigna roles con `profile_roles` y, si aplica, restringe sucursales con
   `profile_branches`.
5. Crea las tasas de cambio con fracción exacta
   (`rate_numerator / rate_denominator`).

No uses `supabase/seed/demo.sql` en producción: inserta usuarios de Auth
directos con UUID fijos y datos sintéticos.

## 4. Configuración del cliente

- Flutter usa solo `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
- Nunca incluyas `service_role`, JWT secret ni contraseña de base en la app, el
  APK, el repositorio o la documentación.
- El personal inicia sesión con Supabase Auth; el perfil debe existir y estar
  `active`.
- Las tablets de cliente no usan Auth: se vinculan con código y token de
  dispositivo.

## 5. Verificación posterior al despliegue

```sql
-- RLS activo en todas las tablas
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r'
 order by relname;

-- Sin escrituras directas para anon/authenticated
select has_table_privilege('anon', 'public.sales', 'insert');          -- false
select has_table_privilege('authenticated', 'public.sales', 'update'); -- false

-- Roles y permisos por organización
select r.code, count(rp.permission_id)
  from public.roles r
  left join public.role_permissions rp on rp.role_id = r.id
 where r.organization_id = '<organization_id>'
 group by r.code order by r.code;
```

Prueba también desde un cliente con la clave `anon`:

- `rpc_claim_pairing_code` con un código inválido debe devolver
  `PAIRING_CODE_INVALID`.
- `rpc_pull_catalog` con `anon` debe ser denegado por permisos.
- `rpc_confirm_sale` con un perfil sin `sales.create` debe elevar `FORBIDDEN`.

## 6. Staging y CI

- Ejecuta `supabase/tests/backend.test.mjs` contra un PostgreSQL efímero en CI
  (job `backend` de `.github/workflows/ci.yml`).
- Para staging, repite el orden de migraciones en una base vacía y luego carga
  datos de prueba no productivos.
- No ejecutes migraciones destructivas ni borres datos reales sin autorización.
- Toda corrección de esquema va en una migración nueva; no edites migraciones ya
  aplicadas.

## 7. Limitaciones conocidas

- El job de backend en GitHub Actions pasó en PostgreSQL 16; no hay despliegue
  Supabase ejecutado en este entorno.
- No se implementaron Edge Functions ni Realtime; el transporte usa RPC.
- `rpc_register_terminal` y `rpc_revoke_terminal` elevan conflictos en lugar de
  devolver JSON de conflicto.
- Una clave de idempotencia que produjo conflicto es terminal; la reconciliación
  exige una clave nueva.
- `rpc_update_production_status` no valida que el operador pertenezca a la
  estación de la orden; el permiso `production.update` es suficiente.
- El consumo de inventario en `rpc_confirm_sale` compara cantidades en unidades
  de inventario (milésimas); no descuenta reservas de pedidos de cliente
  automáticamente.
- La app Desktop aún no tiene transporte remoto conectado; sus operaciones
  permanecen `PENDING`.

## 8. Respaldos y reversión

- Antes de un `db push`, crea un backup lógico o un snapshot del proyecto.
- Las migraciones no incluyen `DROP`; la reversión se hace restaurando el
  snapshot, no editando migraciones aplicadas.
- Ante un fallo parcial, revisa `supabase_migrations.schema_migrations` y la
  transacción de la migración antes de reintentar.
- Para incidentes de acceso, revoca terminales con `rpc_revoke_terminal` y
  tablets con `rpc_revoke_customer_device`; rota las claves desde el Dashboard.