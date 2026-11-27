# Protocolo de sincronización

Estado: **transporte del POS Desktop implementado** contra las RPC Supabase
(`apps/desktop/lib/services/`), con validación estricta de recibos, persistencia
del estado del motor y snapshot atómico. Hoy solo `confirm_sale` está mapeado a
una RPC publicada; cualquier otra operación se marca `ERROR` no reintentable
(`OPERATION_UNSUPPORTED`) en lugar de declararse sincronizada.

## 1. Estados locales

Toda entidad sincronizable expone `LOCAL`, `PENDING`, `SYNCED`, `ERROR` o
`CONFLICT`.

- **LOCAL:** creada localmente sin intención de envío.
- **PENDING:** confirmada localmente y en outbox.
- **SYNCED:** recibo remoto válido que coincide en operación, entidad y clave.
- **ERROR:** fallo temporal agotado o rechazo no comercial; conserva el original.
- **CONFLICT:** rechazo comercial verificable; exige reconciliación.

Regla: **solo `SYNCED` con recibo válido**. `receipt != null` no basta; el motor
debe comprobar `accepted`, `operation_id`, `entity` e `idempotency_key`.

## 2. Outbox transaccional

SQLite confirma en una transacción:

1. venta, líneas, pagos, movimientos de inventario y efectivo;
2. reservas y cambios de salón/comandas;
3. cierre de sesión de mesa;
4. apertura/cierre y movimientos manuales de caja;
5. auditoría local;
6. registro outbox por operación.

Si falla un paso, rollback completo. El catálogo sintético no genera eventos de
catálogo y no se comparte entre modo demo y operación real.

## 3. Idempotencia

- Cada operación tiene UUID y `idempotency_key` de 8–120 caracteres.
- El servidor busca el recibo **antes** de validar y aplicar.
- Recibo aceptado repetido → devuelve el mismo resultado, sin nuevos efectos.
- Dos ventas iguales en importes no son duplicados: difieren en UUID, terminal,
  usuario y clave.
- La clave es única por organización en `sync_operations`, `sync_receipts`,
  `sales`, `payments`, `cash_sessions`, `cash_movements`, `customer_orders` y
  movimientos de inventario.
- Una clave que quedó en `CONFLICT` se replica: el reintento devuelve el mismo
  `{accepted:false, code}` en lugar de fallar por unicidad. La operación local
  se conserva y se reenvía corregida con una clave nueva.

## 4. `confirm_sale` v1

Contrato completo en [API_CONTRACTS.md](API_CONTRACTS.md#3-rpc_confirm_sale-salev1).
Resumen:

```json
{
  "schema_version": "sale.v1",
  "idempotency_key": "sale-<uuid>",
  "sale": {
    "id": "uuid", "branch_id": "uuid", "terminal_id": "uuid",
    "cash_session_id": "uuid|null", "dining_session_id": "uuid|null",
    "total_currency": "USD", "total_minor": 700
  },
  "items": [{ "variant_id": "uuid", "quantity": 2, "unit_price_minor": 350 }],
  "payments": [{ "method": "cash", "amount_minor": 700, "currency_code": "USD" }],
  "inventory_consumptions": [
    { "warehouse_id": "uuid", "variant_id": "uuid", "quantity": 2 }
  ]
}
```

El servidor valida esquema, terminal, catálogo, precios, totales, pagos, caja,
mesa y stock. La venta, sus efectos y la auditoría son atómicos.

### Recibo válido

```json
{
  "accepted": true,
  "duplicate": false,
  "operation_id": "uuid",
  "operation_type": "confirm_sale",
  "entity_id": "uuid",
  "idempotency_key": "sale-...",
  "remote_version": 1,
  "applied_at": "2026-11-26T20:00:00Z"
}
```

El transporte rechaza el recibo si faltan `operation_id`, `entity_id`,
`idempotency_key` o `remote_version`, o si la clave no coincide con la operación
enviada; en ese caso la fila pasa a `ERROR` terminal.

### Conflicto comercial

```json
{
  "accepted": false,
  "code": "PRICE_CHANGED",
  "message": "Precio vigente 350 distinto al enviado 1",
  "operation_id": "uuid",
  "idempotency_key": "sale-..."
}
```

El conflicto se guarda en `sync_operations` (`CONFLICT`) y se audita. El
reintento con la misma clave devuelve el mismo conflicto; la operación local se
conserva para reconciliación y se reenvía con una clave nueva.

## 5. Conflictos terminales por clave

| Código | Significado |
| --- | --- |
| `SCHEMA_VERSION_UNSUPPORTED` | Versión de contrato no soportada |
| `TERMINAL_INVALID` | Terminal inexistente, de otra sucursal o revocado |
| `ITEM_INVALID` / `VARIANT_INVALID` | Línea o variante no vendible |
| `PRICE_CHANGED` | Precio enviado distinto al vigente |
| `TOTAL_MISMATCH` | Total no coincide con líneas |
| `PAYMENT_INVALID` / `PAYMENT_MISMATCH` | Pago inválido o suma distinta |
| `CURRENCY_MISMATCH` | Monedas inconsistentes |
| `CASH_SESSION_INVALID` | Caja cerrada, ajena o de otro terminal |
| `DINING_SESSION_INVALID` | Mesa cerrada o ajena |
| `INSUFFICIENT_STOCK` | Stock insuficiente; toda la venta revierte |

`TERMINAL_INVALID`, `CASH_SESSION_INVALID` y `DINING_SESSION_INVALID` no se
reintentan sin intervención. `INSUFFICIENT_STOCK` puede resolverse con un
movimiento de inventario y una clave nueva.

## 6. Reintentos

- Backoff exponencial con jitter acotado y `next_attempt_at` persistido.
- Errores permanentes no reintentan sin corrección: la outbox solo selecciona
  `ERROR` con `next_attempt_at` vencido, de modo que un fallo terminal (sin
  fecha) no se reintenta en bucle.
- Reinicio no pierde outbox, recibos, cursores ni conflictos.
- `RetryPolicy` y `CursorStore` de `packages/core_sync` implementan el contrato.

## 7. Descarga incremental

`rpc_pull_catalog` devuelve cambios por `updated_at > since` y
`updated_at <= cursor`, con `cursor` calculado al inicio de la consulta. Incluye
categorías, productos, variantes, modificadores, mesas permitidas y todas las
tasas de cambio. El cliente persiste una página completa antes de guardar el
cursor. Realtime no reemplaza este mecanismo.

## 8. Reconexión

1. Confirmar sesión y permisos.
2. Subir outbox en orden transaccional.
3. Guardar recibos y marcar `SYNCED` solo si son válidos.
4. Descargar cambios y avanzar cursores.
5. Reconciliar inventario y caja; resolver conflictos con operaciones nuevas.
6. No mostrar como sincronizado lo que solo existe localmente.

## 9. Transporte del POS Desktop

- `SupabaseConfig.fromEnvironment()` lee `SUPABASE_URL` y `SUPABASE_ANON_KEY`
  solo desde `--dart-define`; si falta una, la sincronización queda desactivada.
- `SupabaseRpcInvoker` hace `POST /rest/v1/rpc/<función>` con `apikey` +
  `Authorization: Bearer <JWT>`. El JWT se obtiene de la preferencia local
  `supabase.access_token`; sin token no hay llamada (falla cerrado).
- Errores HTTP: 401/408/429/5xx reintentables; 400/404/409 terminales. El código
  prefiere el `hint` del servidor y después el `code`.
- `SupabaseSyncTransport` envuelve el payload como `{p_payload: ...}`, valida
  que la clave y `sale.id` coincidan con la operación y mapea conflictos a
  `ConflictType`.
- `DesktopSyncService` restaura y persiste el estado del motor en
  `sync_state.json` (escritura atómica `.tmp` + rename). Un snapshot ilegible se
  cuarentena (`.corrupt-<epoch>`), nunca se borra.
- Cada entrada procesada actualiza la outbox (`SYNCED`, `CONFLICT` o `ERROR`
  con `next_attempt_at`). `SYNCED` exige recibo correlacionado; un recibo
  ausente o no correlacionado produce `RECEIPT_MISMATCH` terminal.
- El ciclo corre al arrancar y cada 45 s; se omite si no hay token.

## 10. Implementación

- `packages/core_sync`: `SyncEngine`, `SyncTransport`, `SyncInbox`,
  `RetryPolicy`, `CursorStore`, `SyncConflict`, `SyncStatus.conflict`.
- `packages/data_local`: outbox transaccional, recibos, errores, cursores,
  sesiones locales con expiración.
- Desktop: `apps/desktop/lib/services/` (configuración, invoker, transporte,
  orquestador) y `apps/desktop/test/sync_transport_test.dart` +
  `desktop_sync_service_test.dart`.
- Backend: `app.lookup_receipt` (recibos y replay de conflictos),
  `app.record_receipt`, `app.finish_conflict`, triggers append-only y RPC por
  operación.

Pendiente: publicar RPC para el resto de operaciones de la outbox, aplicar la
descarga de catálogo en Desktop, Realtime/notificaciones y despliegue real.