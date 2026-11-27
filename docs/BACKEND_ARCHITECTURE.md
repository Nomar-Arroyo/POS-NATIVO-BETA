# Arquitectura del backend

Estado: **implementado y verificado localmente**, no desplegado a Supabase. La
fuente de verdad son las migraciones de `supabase/migrations/`.

## Componentes

- PostgreSQL como fuente central y transaccional.
- Supabase Auth para identidad del personal (`profiles.id = auth.users.id`).
- RLS de solo lectura para aislar organización y sucursal.
- RPC `SECURITY DEFINER` para toda escritura y operación atómica.
- Token de dispositivo para tablets de cliente, sin Supabase Auth.
- Outbox SQLite + `core_sync` para operación offline del POS.
- Sin Edge Functions ni Realtime en esta etapa; el transporte es RPC.

## Estructura

- `supabase/migrations/`: esquema, RLS/RPC y evolución versionada.
- `supabase/seed/demo.sql`: datos sintéticos idempotentes para desarrollo.
- `supabase/tests/bootstrap.sql`: simulación local de `auth` para PostgreSQL.
- `supabase/tests/backend.test.mjs`: 19 pruebas de integración y seguridad.
- `supabase/functions/`: reservado; no se usa actualmente.

## Límites de confianza

El cliente Flutter no contiene secretos de servicio ni decide autorización.
Cada RPC valida identidad, organización, sucursal, terminal o dispositivo,
permiso, vigencia e idempotencia. Las operaciones confirmadas, sus efectos y su
auditoría se escriben en la misma transacción.

Las escrituras directas están revocadas: incluso un usuario autenticado con
permisos solo puede mutar mediante RPC. Las tablets no tienen grants de tabla y
su alcance se resuelve desde el token de sesión.

El POS puede aceptar operaciones locales autorizadas por la política offline. La
sincronización registra recibos verificables y nunca descarta una operación
pendiente por error de red o conflicto.

## Estado por área

| Área | Estado |
| --- | --- |
| Esquema y migraciones | Implementado (0001–0004) |
| Auth, roles, permisos y RLS | Implementado y probado |
| Ventas, caja, inventario y salón | Implementado y probado |
| Pairing, tablets, menú y pedidos | Implementado y probado |
| Descarga incremental | Implementado y probado |
| Realtime / notificaciones push | No implementado |
| Transporte remoto en Desktop | No implementado |
| Despliegue Supabase | Pendiente de acceso y aprobación |

## Decisiones pendientes

- Confirmar proyecto y ventana de despliegue.
- Aprobar datos iniciales reales (organización, sucursales, catálogo, tasas).
- Definir política de respaldo/restauración y rotación de claves.
- Decidir Realtime o sondeo para seguimiento de pedidos.
- Conectar el outbox de Desktop a `rpc_confirm_sale` y validar recibos (E-04,
  E-05, E-06).

Ver [BACKEND_DEPLOYMENT.md](BACKEND_DEPLOYMENT.md) para el procedimiento.