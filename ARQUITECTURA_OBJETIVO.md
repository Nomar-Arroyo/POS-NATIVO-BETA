# Arquitectura objetivo

## 1. Principios

- Offline-First: la caja confirma operaciones localmente sin dependencia de red.
- Núcleo compartido: reglas comerciales implementadas una vez y reutilizadas.
- Integridad transaccional: venta y inventario se confirman juntos.
- Seguridad backend: RLS y validación de rol sin confiar en controles visuales.
- Precisión decimal: importes enteros o Decimal, nunca punto flotante binario.
- Sin falsear estados: distinguir local, pendiente, sincronizado y error.
- Reemplazabilidad: hardware y fiscalidad detrás de interfaces/adaptadores.

## 2. Productos objetivo

### Desktop Windows

- Flutter/Dart con soporte táctil y teclado.
- SQLite local.
- Supabase como repositorio central opcionalmente conectado.
- Operaciones POS, mesas, caja, inventario y administración.

### Mobile Android/iOS

- Flutter/Dart gerencial.
- Consulta, resumen ejecutivo, auditoría e inventario.
- Sin operaciones críticas no contempladas en permisos.

## 3. Monorepo recomendado

```text
apps/
  beta/
  desktop/
  mobile/
packages/
  data_local/
  core_money/
  core_sync/
  data_migration/
  amalfi_brand_assets/
supabase/
  migrations/
  functions/
  tests/
```

La Beta React/Tauri se conserva en `apps/beta` con sus propios scripts,
dependencias, documentación y persistencia. Las aplicaciones Flutter consumen
los paquetes compartidos de `packages/`; `apps/mobile` contiene el scaffold
Flutter para las experiencias gerencial y de pedidos de clientes. La
documentación transversal está en `docs/` y los documentos principales
permanecen en la raíz. El backend PostgreSQL está implementado en `supabase/`
(migraciones, RLS, RPC y pruebas), pero aún no está integrado a un proyecto
Supabase desplegado ni conectado al POS.

## 4. Capas

### Dominio

Entidades y reglas puras: venta, pago, caja, mesa, inventario, tasas, anulación,
conciliación e inventario. No debe depender de Flutter, Supabase ni SQLite.

### Aplicación

Casos de uso, orquestación y permisos: abrir caja, confirmar venta, dividir cuenta,
cerrar mesa, ajustar stock y emitir reportes.

### Infraestructura local

SQLite, repositorios locales, cola outbox, metadatos de sincronización y caché.

### Infraestructura remota

Supabase/PostgreSQL, Auth, Realtime y RPC para operaciones críticas.

### Presentación

Riverpod/Bloc, widgets responsive y adaptadores desktop/mobile.

## 5. Backend

- PostgreSQL/Supabase como fuente central de datos consolidados.
- Supabase Auth con perfiles vinculados a `auth.users`.
- Roles `gerente/admin`, `cajero` y `mesonero/barra`.
- RLS en todas las tablas sensibles.
- RPC o Edge Functions para operaciones confirmadas que requieren atomicidad.
- Migraciones versionadas y seeds separados de datos reales.
- Auditoría append-only de acciones críticas.

## 6. Multimoneda

- USD como moneda base.
- Enteros en céntimos o Decimal para importes.
- Tasa activa con vigencia y fuente.
- Historial de tasas.
- La venta conserva total original, pago por moneda y tasa aplicada.
- IGTF configurable y activado solo según una regla normativa validada.

## 7. Offline y sincronización

- UUID para entidades locales y remotas.
- Outbox transaccional junto a la operación local.
- Estados `LOCAL`, `PENDING`, `SYNCED`, `ERROR`.
- Reintentos con backoff y límite.
- Operaciones idempotentes por clave.
- RPCs o tablas de recibo para detectar duplicados.
- Detección de conflicto por `updated_at`, versión o vector de cambios.
- Estrategia predeterminada:
  - ventas, pagos y movimientos son append-only e inmutables;
  - cambios de catálogo usan la versión más nueva con excepción administrativa;
  - conflictos comerciales se convierten en excepción y requieren revisión.
- Fallos nunca eliminan la operación local.

## 8. Integraciones

Interfaces independientes para:

- impresora térmica ESC/POS;
- detección y selección de dispositivo;
- lectura de códigos;
- caja registradora;
- terminal de pago;
- proveedor fiscal o imprenta digital.

La aplicación solo informa “conectado” después de detección y prueba.

## 9. Identidad visual

Conservar turquesa `#159FA2`, turquesa oscuro `#087E83`, azul marino
`#0F2942`, blanco y grafito. Verde y rojo solo semánticamente. Los iconos
lineales de la Beta deben migrarse a un paquete compartido o convertirse a SVG
equivalente sin alterar su significado.

## 10. Seguridad operativa

- Sin credenciales o claves service-role en repositorio.
- Secretos localmente protegidos y variables por entorno.
- Sesiones, expiración y revocación.
- Exportación/importación con validación previa y copia.
- Respaldo remoto cifrado y prueba periódica de restauración.

## 11. Modelo operativo refinado

El alcance comercial se organiza como:

```text
Organization
  └── Branch
       ├── Terminal
       │    └── terminal_id persistente
       ├── Warehouse
       ├── CashRegister
       └── CashSession
Profile -> Auth user -> Roles -> Permissions
```

- **Organization:** tenant y límite de datos entre clientes.
- **Branch:** sucursal con moneda operativa, almacenes y cajas.
- **Terminal:** equipo autorizado y instalado; tiene identidad persistente e
  irreemplazable por un identificador aleatorio generado en cada inicio.
- **Warehouse:** existencia física o virtual dentro de una sucursal.
- **Profile:** identidad operativa vinculada a `auth.users.id`.
- **CashRegister/CashSession:** caja física y turno abierto.

Cada entidad persistente usa UUID `gen_random_uuid()` en PostgreSQL y UUID RFC
4122 en SQLite. Los identificadores generados por la Beta se conservan en
`beta_origin_id`; no se usan como claves primarias nuevas.

## 12. Identidad persistente de dispositivos

Cada terminal almacena:

- `terminal_id`: UUID persistente y secreto firmado por el backend.
- `public_key`: clave pública del dispositivo para validar registro.
- `device_name`, `platform`, `app_version`, `last_seen_at`.
- `status`: pending, active, revoked, retired.

Un terminal no registrado no puede descargar datos ni confirmar operaciones.
La revocación invalida su sesión local y impide nuevas sincronizaciones. Las
claves privadas nunca se almacenan en SQLite sin protección del sistema operativo.

## 13. Autorización offline

El cliente recibe un permiso de operación firmado, breve y asociado al terminal,
con `profile_id`, roles efectivos, sucursal y `expires_at`. Offline puede ejecutar
solo acciones contenidas en ese paquete y dentro de su vigencia.

Durante reconexión, el backend vuelve a validar permisos. Una operación que fue
permitida offline pero ahora excede el rol remoto queda:

- intacta en la cola local;
- marcada `ERROR` o `CONFLICT`;
- revisable por auditoría;
- nunca eliminada ni aplicada silenciosamente.

La fecha futura no sustituye autorización backend.

## 14. Outbox/Inbox

**Outbox local:** una operación comercial y todos sus documentos de efecto se
registran dentro de la misma transacción SQLite que un mensaje outbox.

Campos mínimos:

- `id`, `operation_type`, `entity_id`, `idempotency_key`, `payload_json`;
- `base_version`, `sync_status`, `attempt_count`, `next_attempt_at`;
- `last_error_code`, `last_error_message`, `created_at`, `updated_at`.

**Inbox:** el servidor registra resultados o eventos una sola vez. Cada recibo
contiene `idempotency_key`, operación, entidad remota, resultado y versión.
Si reaparece el mismo recibo, devuelve el resultado anterior sin repetir efectos.

Realtime notificará cambios; nunca será obligatorio para recuperar datos. El
progreso normal se basa en Outbox, cursor y recibos.

## 15. Cursores y recuperación

Cada entidad sincronizable usa `cursor_key = (updated_at, id)` o un cursor de
secuencia monotónico. Los cambios remotos se reciben por páginas; el cliente
persiste el cursor solamente después de completar la transacción de página.

Ante un cierre inesperado:

- SQLite recupera transacciones incompletas con WAL.
- El outbox conserva operaciones confirmadas localmente.
- La aplicación recalcula el siguiente intento.
- No se elimina ni marca como synced hasta obtener recibo verificable.
- Los eventos repetidos se descartan por llave/idempotencia.

## 16. Conflictos comerciales

Las ventas, pagos, anulaciones y movimientos de inventario son append-only o
inmutables una vez confirmados. No se utilizan merges generales sobre totales.

Conflictos previstos:

- stock insuficiente consolidado;
- caja ya cerrada;
- venta ya confirmada con otro recibo;
- tasa aplicada fuera de vigencia;
- catálogo alterado después de la reserva;
- terminal o usuario revocado.

Los conflictos generan `sync_events`/registro revisable y no sobrescriben el
documento original. Una operación distinta con idénticos productos e importes
permanece distinta por UUID e idempotency key.

## 17. Inventario offline

El sistema mantiene cuatro magnitudes separadas:

- existencia remota consolidada;
- existencia local conocida;
- movimientos pendientes;
- reservas disponibles por terminal/almacén.

La venta offline solo puede consumirse si el producto está marcado
`offline_sellable` y dispone de un saldo seguro confirmado en el snapshot local.
Se crea una reserva local y el movimiento se escribe en la misma transacción.

Dos terminales pueden consumir simultáneamente cantidades reservadas; cuando se
excede el stock consolidado, el backend registra la diferencia y no modifica
movimientos históricos. La reparación requiere un movimiento de ajuste autorizado
o una reversión con auditoría.

## 18. Política monetaria

- Moneda base: USD.
- Importes: enteros en unidades mínimas o Decimal; jamás `double`.
- Una moneda tiene `minor_unit_scale` configurable.
- Cada pago conserva `amount_minor`, `currency_code`, tasa aplicada y fecha.
- Las conversiones usan la tasa vigente en UTC y Venezuela para su vigencia.
- Cada operación conserva una copia histórica de tasa.
- IVA/IGTF no se activa por defecto ni por una constante aislada.

## 19. Auditoría inmutable

`audit_logs` solo admite inserción. Contiene actor, terminal, sucursal,
operación, entidad, cambios permitidos por política y hash/cadena opcional.
Anulaciones requieren motivo y autorización. Las correcciones crean eventos
nuevos, no alteran registros anteriores.

## 20. Respaldo y recuperación

- PostgreSQL: backups automáticos, punto de restauración y prueba periódica.
- SQLite: respaldo cifrado o protegido por sistema operativo y archivo de WAL.
- Exportación JSON: manifiesto de versión, conteos, hash y zona horaria.
- Restauración: primero entorno aislado y reconciliación antes de producción.
- Ninguna restauración puede reemplazar el `localStorage` de la Beta.
