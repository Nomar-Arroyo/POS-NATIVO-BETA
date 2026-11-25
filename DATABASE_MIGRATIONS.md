# Política de migraciones

## PostgreSQL

- Migraciones secuenciales, inmutables y revisables.
- Convención: `0001_initial_identity.sql`, `0002_catalog_inventory.sql`.
- Nunca modificar una migración aplicada; crear una nueva compensatoria.
- No usar `DROP TABLE`, truncado o borrado destructivo en despliegues normales.
- Un script de migración debe incluir reversión documentada y plan de restauración.
- Las migraciones destructivas requieren respaldo verificable y autorización.

## SQLite

- Tabla `schema_migrations(version, checksum, applied_at)`.
- Migraciones monotónicas desde la versión 1.
- Añadir columnas solo con valores por defecto compatibles.
- Reconstruir tabla solo cuando sea necesario, dentro de una transacción.
- Habilitar `WAL`, `foreign_keys`, busy timeout y retry controlado.
- Probar migración desde cada versión anterior soportada.

## Datos existentes

- `beta_origin_id` conserva la clave JSON original.
- UUID se genera una sola vez y se persiste en el mapa de migración.
- Datos sintéticos deben llevar `synthetic=true` o prefijo controlado.
- La migración real no inicia sin autorización y exportación verificable.

## Estado de implementación SQLite

Las migraciones SQLite v1-v5 están implementadas en
`packages/data_local/lib/src/migrations.dart`.

- Aplica una sola vez por número de versión.
- v1 crea el esquema comercial local.
- v2 agrega la configuración única del terminal y la restricción de una sesión
  abierta por caja.
- v3 agrega mesas, sesiones, ítems de salón, comandas y asignación de estación,
  además de la referencia opcional de venta a una sesión de mesa.
- v4 agrega `products.is_synthetic` con valor predeterminado compatible para
  marcar los fixtures visuales de demostración y bloquear su uso comercial.
- v5 agrega `profiles.pin_salt`/`pin_hash`, sesiones locales auditables y
  preferencias locales de salida por estación; no elimina perfiles ni datos
  comerciales existentes.
- Las migraciones son aditivas; v3-v5 no eliminan ni reescriben datos existentes.
- Registra nombre, checksum textual y fecha.
- Usa `PRAGMA foreign_keys = ON`.
- Usa `journal_mode = WAL` y `busy_timeout = 5000`.
- Actualiza `PRAGMA user_version`.
- Ejecuta el bloque dentro de una transacción.

La versión activa de esquema es 5. La migración remota PostgreSQL todavía no
está implementada ni aplicada.

Los datos de las pruebas son sintéticos y no se incluyen como catálogo de
producción.
