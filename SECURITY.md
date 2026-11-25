# Seguridad

## Autenticación

- Supabase Auth para usuarios.
- `profiles.id` coincide con `auth.users.id`.
- Refresh/revocación administrada por Supabase.
- Sesiones terminales separadas de identidad humana.

### Escritorio local actual

- El primer administrador establece un PIN de 4–8 dígitos durante la
  configuración del terminal; un administrador puede crear perfiles locales
  Cajero, Administrador, Cocina o Barra.
- El PIN no se guarda en claro: SQLite almacena un salt aleatorio de 16 bytes y
  un derivado PBKDF2-HMAC-SHA256 (120 000 iteraciones).
- Cinco intentos fallidos por perfil bloquean nuevos intentos durante 15
  minutos. Inicio, cierre y fallos se registran en la auditoría local.
- Las funciones comerciales comprueban permisos locales cuando existe una
  sesión autenticada; la navegación también oculta módulos no autorizados.
- Esta autenticación no equivale a Supabase Auth ni protege contra un usuario
  con acceso al archivo SQLite o a la cuenta del sistema operativo. La base no
  está cifrada; el control depende de proteger el terminal y su perfil de SO.
- La demo abre otra base SQLite en memoria y descarta sus cambios al salir.
  Permite ventas simuladas únicamente dentro de ese entorno y no utiliza datos
  ni credenciales de la base real.

## Roles

- `org_admin`: administración global del tenant.
- `manager`: operación y aprobaciones.
- `cashier`: caja y pagos.
- `waiter`: mesas y pedidos.
- `kitchen`/`bar`: comandas de su estación.

Permisos se almacenan en tabla, asignan por rol y se verifican en RLS/RPC.
Los perfiles y permisos locales de escritorio son solo una política offline
temporal; se deberán vincular a Auth/RLS cuando Supabase esté disponible.

## RLS

Toda tabla sensible filtra por `organization_id` y perfil autorizado. Las políticas
deben ser verificadas con usuarios sintéticos de cada rol.

## Terminales

- UUID persistente.
- Registro firmado y revocable.
- Permisos offline de corta vigencia.
- El backend revalida al reconectar.

## Operaciones críticas

Venta, pago, caja y anulación se ejecutan mediante RPC autenticada y transacción
PostgreSQL. La interfaz no puede confiar en una validación local.

## Secretos

- Service-role key únicamente servidor/CI autorizado.
- Nunca dentro de Flutter, repositorio, APK o instalador.
- Variables por entorno y rotación.

## Auditoría

- Insert-only.
- Motivo obligatorio para anulaciones.
- Snapshot antes/después limitado a datos autorizados.
- Terminal y usuario registrados.
