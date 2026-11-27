# Protocolo de sincronización

Estado del backend: **transporte RPC implementado y probado** (idempotencia,
recibos, conflictos terminales y descarga incremental). El POS Desktop todavía
no tiene transporte remoto conectado; sus operaciones quedan `PENDING`.

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
  "receipt_id": "uuid",
  "entity_type": "sale",
  "entity_id": "uuid",
  "idempotency_key": "sale-...",
  "schema_version": "sale.v1",
  "remote_version": 1,
  "received_at": "2026-11-26T20:00:00Z"
}
```

### Conflicto comercial

```json
{
  "accepted": false,
  "duplicate": false,
  "code": "PRICE_CHANGED",
  "message": "Precio vigente 350 distinto al enviado 1",
  "idempotency_key": "sale-..."
}
```

El conflicto se guarda en `sync_operations` (`CONFLICT`), se audita y **consume
la clave**: un reintento con la misma clave no se reaplica. Para reconciliar se
corrige localmente y se emite una clave nueva; la operación original no se
borra.

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
- Errores permanentes no reintentan sin corrección.
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

## 9. Implementación

- `packages/core_sync`: `SyncEngine`, `SyncTransport`, `SyncInbox`,
  `RetryPolicy`, `CursorStore`, `SyncConflict`, `SyncStatus.conflict`.
- `packages/data_local`: outbox transaccional, recibos, errores, cursores.
- Backend: `app.lookup_receipt`, `app.record_receipt`,
  `app.finish_conflict`, triggers append-only y RPC por operación.

Pendiente en clientes: transporte Supabase real, persistencia del estado del
motor, validación estricta de recibos (E-05) y contrato de outbox completo
(E-04).