# Arquitectura del backend

Este documento describe la arquitectura objetivo; no implica que exista un
backend desplegado. La integración con Supabase queda pendiente de acceso al
proyecto y aprobación del esquema.

## Componentes previstos

- PostgreSQL como fuente central y transaccional.
- Supabase Auth para identidad de personas y sesiones.
- Row Level Security (RLS) para aislar organizaciones, sucursales y roles.
- RPC o Edge Functions para operaciones que requieren validación y atomicidad.
- Realtime como aviso de cambios, no como único mecanismo de recuperación.
- SQLite y outbox local para mantener el POS desktop operativo sin conexión.

## Estructura del repositorio

- `supabase/migrations/`: cambios versionados del esquema.
- `supabase/functions/`: pairing de tablets, pedidos, inventario y notificaciones.
- `supabase/tests/`: pruebas de RLS, RPC, clientes e inventario.
- `supabase/seed/`: datos sintéticos aislados de cualquier catálogo real.

Las carpetas están reservadas; no se deben desplegar ni tratar como servicio
activo hasta implementar y validar las migraciones, políticas y funciones.

## Límites de confianza

El cliente Flutter no contiene secretos de servicio ni decide autorización por
su interfaz. Las funciones del servidor validan identidad, organización,
sucursal, terminal, rol, permisos, vigencia e idempotencia. Las operaciones
confirmadas y su auditoría se escriben en la misma transacción.

El POS puede aceptar operaciones locales autorizadas por la política offline.
La sincronización remota registra recibos verificables y nunca descarta una
operación pendiente por un error de red o conflicto.

## Decisiones pendientes

- Confirmar proyecto y acceso a la base de datos.
- Revisar el esquema propuesto en [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md).
- Aprobar roles, políticas RLS y límites multi-organización.
- Acordar contratos en [API_CONTRACTS.md](API_CONTRACTS.md).
- Probar restauración, revocación de terminales y operación offline antes de
  producción.
