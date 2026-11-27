# Autorización y seguridad

Estado: **implementado en PostgreSQL** (`20261126090100_0002_authz_rls.sql` y RPC
`SECURITY DEFINER`), verificado por las pruebas de autorización, aislamiento y
anónimo de `supabase/tests/backend.test.mjs`. No depende de la interfaz: una
tablet o un cliente no obtienen permisos por cambiar una opción en Flutter.

## 1. Modelo

| Contexto | Identidad | Alcance | Escritura |
| --- | --- | --- | --- |
| Personal POS/gerencia | `auth.uid()` → `profiles` activo | Organización y sucursales del perfil | Solo RPC autorizadas |
| Tablet de cliente | `customer_device_sessions.token_hash` | Organización, sucursal y mesa vinculadas | Solo RPC de tablet |
| Anónimo sin pairing | Ninguna | Ninguna tabla | Ninguna RPC de personal |
| `service_role` | Fuera de la app | Total | Uso administrativo, nunca en Flutter/repositorio |

No existe `isAdmin`, `userRole` ni `appMode` como fuente de autorización. El
servidor recalcula permisos en cada llamada.

## 2. Helpers `app.*`

| Función | Uso |
| --- | --- |
| `current_profile_id()` | `auth.uid()` con perfil activo y no borrado |
| `current_organization_id()` | Organización del perfil |
| `has_permission_in(org, code)` | Permiso efectivo vía `profile_roles` → `role_permissions` |
| `has_permission(code)` | Permiso en la organización actual |
| `branch_allowed(org, branch)` | `org.read` y (sin restricciones o sucursal listada) |
| `assert_permission(code)` | Eleva `FORBIDDEN` |
| `require_profile()` | Eleva `UNAUTHENTICATED` |
| `assert_active_terminal(id, branch)` | Terminal activo de la organización/sucursal |
| `conflict(code, msg)` | Eleva `P0001` con `hint = code` |
| `lookup_receipt` / `record_receipt` | Idempotencia y recibo verificable |
| `finish_conflict` | Guarda `sync_operations` CONFLICT + auditoría |
| `issue_device_session` / `resolve_device` | Sesión y alcance de tablet |
| `write_audit` | Auditoría con actor, terminal y organización actuales |

## 3. Permisos

22 códigos: `org.read`, `settings.read`, `settings.manage`, `profiles.read`,
`profiles.manage`, `devices.manage`, `catalog.read`, `catalog.manage`,
`inventory.read`, `inventory.manage`, `cash.read`, `cash.manage`,
`tables.read`, `tables.manage`, `sales.read`, `sales.create`,
`production.read`, `production.send`, `production.update`, `audit.read`,
`reports.read`, `sync.read`.

| Rol | Permisos |
| --- | --- |
| `org_admin` | Todos los 22 |
| `manager` | Todos excepto `profiles.manage` |
| `cashier` | `org.read`, `settings.read`, `profiles.read`, `catalog.read`, `inventory.read`, `cash.read`, `cash.manage`, `tables.read`, `sales.read`, `sales.create`, `production.read` |
| `waiter` | `org.read`, `settings.read`, `profiles.read`, `catalog.read`, `tables.read`, `tables.manage`, `sales.read`, `sales.create`, `production.read`, `production.send` |
| `kitchen` | `org.read`, `settings.read`, `profiles.read`, `catalog.read`, `tables.read`, `production.read`, `production.update` |
| `bar` | Igual que `kitchen` |

`cashier` y `waiter` no tienen `sync.read`; solo gerencia y administración
pueden leer operaciones de sincronización. Los roles se instalan por
organización con `app.install_default_roles(org)`; no se aceptan roles enviados
por el cliente.

## 4. RLS

- RLS habilitado en las 40 tablas de `public`.
- Políticas **solo de lectura** (`FOR SELECT TO authenticated`), una por área,
  con `organization_id = current_organization_id()` y el permiso de lectura
  correspondiente.
- Sucursales, almacenes, terminales, caja, movimientos de caja, ventas, salón y
  producción aplican además `branch_allowed`.
- `profiles` permite leer el propio perfil y, con `profiles.read`, los de la
  organización.
- `role_permissions` exige `settings.read` de la organización dueña del rol.
- `customer_device_sessions` no tiene política: ni siquiera un perfil
  autenticado puede leer tokens o sesiones de tablets.
- No hay políticas de INSERT/UPDATE/DELETE. Las escrituras directas están
  revocadas para `anon` y `authenticated`; cualquier mutación pasa por RPC
  `SECURITY DEFINER` con `search_path` fijo.

Pruebas que cubren esto: “esquema aplicado con RLS y privilegios mínimos”,
“anon no lee tablas ni ejecuta RPC de personal”, “aislamiento por organización y
denegación de escritura directa”, “cajero no administra configuración ni
tablets” y “perfil deshabilitado no opera”.

## 5. Alcance de sucursal

Si un perfil no tiene filas en `profile_branches`, opera en toda la
organización. Si tiene filas, `branch_allowed` solo devuelve verdadero para las
sucursales listadas. Esto afecta lectura, RPC de caja/salón/terminales y la
descarga de mesas en `rpc_pull_catalog`. Un administrador de otra organización no
puede registrar terminales ni leer datos ajenos.

## 6. Terminales

- `rpc_register_terminal` emite un token aleatorio y guarda solo su SHA-256.
- El token se devuelve una vez; no es recuperable.
- Cada RPC de personal que recibe `terminal_id` valida que el terminal exista,
  pertenezca a la organización/sucursal y esté `active`.
- `rpc_revoke_terminal` marca `revoked_at`; las ventas posteriores fallan con
  `TERMINAL_INVALID`.

## 7. Tablets de cliente

- El pairing lo crea un perfil con `devices.manage` para una mesa y sucursal
  concretas.
- El código de 8 dígitos es temporal (2–15 min), de un solo uso y se guarda
  hasheado; crear uno nuevo revoca los activos de la mesa.
- La tablet se identifica por huella de dispositivo hasheada; un dispositivo
  revocado no puede re-vincularse sin alta administrativa.
- La sesión es un token opaco de 32 bytes con hash persistido y vigencia
  deslizante de 8 horas, renovable con `rpc_renew_device_session`.
- La vinculación activa a mesa es única por dispositivo. Repetir el pairing
  revoca sesiones y vinculaciones previas.
- Las RPC de tablet resuelven organización, sucursal y mesa desde el token; el
  payload no puede cambiarlas.
- Una tablet nunca recibe permisos de personal ni acceso a ventas, perfiles,
  auditoría u otras mesas.

## 8. Secretos

No se almacenan ni distribuyen `service_role` keys, JWT secret ni contraseñas de
base en Flutter, APK, repositorio o documentación pública. El cliente usa
únicamente la URL pública y la clave `anon`, que no autoriza escrituras directas.
La `service_role` se reserva para tareas administrativas fuera de la app.