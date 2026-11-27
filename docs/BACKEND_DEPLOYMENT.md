# Despliegue del backend

Este documento describe cómo llevar las migraciones a un proyecto Supabase.
El backend fue verificado localmente contra PostgreSQL 19 con 19 pruebas de
integración y en GitHub Actions contra PostgreSQL 16 con 19/19 pruebas
(migraciones 0001–0004). La suite ampliada a 25 pruebas con las migraciones 0005
y 0006 pasó localmente en PostgreSQL 17 en dos ejecuciones consecutivas, pero
todavía no se ha ejecutado en GitHub Actions. **No se ha desplegado a un
proyecto Supabase real** desde este entorno.

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
5. `20261126090500_0005_production_station_reservations.sql`
6. `20261126090600_0006_harden_app_grants.sql`

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
5. Ajusta `profiles.production_station` (`KITCHEN`, `BAR` o `BOTH`, por defecto)
   para cocina y barra; sin este ajuste ambos ven todas las comandas.
6. Crea las tasas de cambio con fracción exacta
   (`rate_numerator / rate_denominator`).

No uses `supabase/seed/demo.sql` en producción: inserta usuarios de Auth
directos con UUID fijos y datos sintéticos.

## 4. Configuración del cliente

- Flutter usa solo `SUPABASE_URL` y `SUPABASE_ANON_KEY`, inyectadas en compilación:

  ```bash
  flutter run -d windows \
    --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=<anon-key>
  ```

  `SupabaseConfig.fromEnvironment()` devuelve `null` si falta una; en ese caso el
  Desktop opera offline y no intenta sincronizar.
- Nunca incluyas `service_role`, JWT secret ni contraseña de base en la app, el
  APK, el repositorio o la documentación.
- El personal inicia sesión con Supabase Auth; el perfil debe existir y estar
  `active`. El Desktop guarda el JWT de la sesión en la preferencia local
  `supabase.access_token`; sin token el ciclo de sincronización se omite y las
  llamadas fallan cerradas (`AUTH_REQUIRED`).
- El JWT se envía como `Authorization: Bearer <token>` y la clave `anon` como
  `apikey`; el backend autoriza por `auth.uid()` y permisos, nunca por el
  payload.
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

-- Helpers internos fuera del alcance de los clientes
select has_schema_privilege('anon', 'app', 'usage');                   -- false
select has_function_privilege(
  'authenticated',
  'app.record_receipt(uuid,uuid,text,text,uuid,text,text,jsonb,bigint)',
  'execute'
);                                                                     -- false

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

- El job de backend de GitHub Actions pasó 19/19 en PostgreSQL 16 con las
  migraciones 0001–0004; la suite de 25 pruebas con 0005/0006 aún no se ha
  corrido en CI.
- No hay despliegue Supabase ejecutado en este entorno.
- No se implementaron Edge Functions ni Realtime; el transporte usa RPC y el
  cliente consulta el estado.
- `rpc_register_terminal` y `rpc_revoke_terminal` elevan conflictos en lugar de
  devolver JSON de conflicto.
- Una clave que produjo conflicto devuelve siempre el mismo conflicto; la
  reconciliación exige corregir la operación local y emitir una clave nueva.
- Las órdenes de cocina/barra quedan acotadas por `profiles.production_station`;
  por defecto `BOTH`, así que hay que configurarlo para obtener separación real.
- El Desktop solo mapea `confirm_sale` a RPC; el resto de operaciones de la
  outbox queda `ERROR`/`OPERATION_UNSUPPORTED` hasta publicar su RPC y mapearla.
- `rpc_confirm_sale` consume reservas de la sesión de mesa, pero la descarga de
  catálogo aún no se aplica en Desktop.
- El inventario usa milésimas (backend) mientras algunos fixtures locales usan
  unidades; unificar la escala sigue pendiente.

## 8. Respaldos y reversión

- Antes de un `db push`, crea un backup lógico o un snapshot del proyecto.
- Las migraciones no incluyen `DROP`; la reversión se hace restaurando el
  snapshot, no editando migraciones aplicadas.
- Ante un fallo parcial, revisa `supabase_migrations.schema_migrations` y la
  transacción de la migración antes de reintentar.
- Para incidentes de acceso, revoca terminales con `rpc_revoke_terminal` y
  tablets con `rpc_revoke_customer_device`; rota las claves desde el Dashboard.