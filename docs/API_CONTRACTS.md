# Contratos RPC

Estado: **implementado** en `supabase/migrations/20261126090200_0003_commercial_rpc.sql`
y `20261126090300_0004_customer_sync.sql`. Los clientes llaman
`supabase.rpc(nombre, payload)`; no hay endpoints REST propios ni Edge Functions.

## 1. Reglas comunes

- La identidad del personal sale de `auth.uid()`; la organización, del perfil.
- El personal necesita una fila activa en `profiles` con el permiso indicado.
- Los terminales POS se validan contra `terminals` por ID, sucursal y estado.
- Las tablets se resuelven por `session_token`; su organización, sucursal y mesa
  nunca vienen del payload.
- Toda mutación del personal exige `idempotency_key`; el servidor devuelve el
  recibo previo si la clave ya fue aceptada.
- El servidor calcula precios y totales; los importes del cliente solo se
  comparan.
- Las respuestas aceptadas incluyen `accepted: true` y `receipt_id`.
- Los conflictos controlados devuelven `accepted: false`, `code` y `message`
  (no lanzan error HTTP), salvo `rpc_register_terminal` y
  `rpc_revoke_terminal`, que no capturan conflictos y los elevan como excepción
  PostgreSQL con `hint` = código.
- Un error de autenticación o permiso (`UNAUTHENTICATED`, `FORBIDDEN`) siempre se
  eleva y nunca se convierte en recibo.

### Envoltura de recibo (aceptado)

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

### Envoltura de conflicto (rechazado controlado)

```json
{
  "accepted": false,
  "duplicate": false,
  "code": "PRICE_CHANGED",
  "message": "Precio vigente 350 distinto al enviado 1",
  "idempotency_key": "sale-..."
}
```

El conflicto queda en `sync_operations` con `status='CONFLICT'` y se audita como
`SYNC_OPERATION_CONFLICT`. La clave consumida no puede reutilizarse con otro
payload: un reintento con la misma clave y datos corregidos devuelve error de
unicidad; se debe emitir una clave nueva.

## 2. Personal autenticado

| RPC | Permiso | Payload mínimo | Efecto |
| --- | --- | --- | --- |
| `rpc_register_terminal` | `settings.manage` | `branch_id`, `name`, `platform?`, `app_version?`, `idempotency_key` | Crea terminal y devuelve `terminal_token` una sola vez |
| `rpc_revoke_terminal` | `settings.manage` | `terminal_id`, `reason?`, `idempotency_key` | Revoca terminal; sus RPC fallan |
| `rpc_confirm_sale` | `sales.create` | ver §3 | Venta atómica, pagos, inventario, caja y mesa |
| `rpc_adjust_inventory` | `inventory.manage` | `warehouse_id`, `variant_id`, `quantity_delta_minor`, `reason`, `terminal_id?`, `schema_version: inventory.v1`, `idempotency_key` | Movimiento de ajuste con bloqueo de saldo |
| `rpc_open_cash_session` | `cash.manage` | `cash_register_id`, `terminal_id`, `opening_minor`, `schema_version: cash.v1`, `idempotency_key` | Abre caja (una por registro) |
| `rpc_close_cash_session` | `cash.manage` | `cash_session_id`, `closing_minor: { usd_minor }`, `schema_version: cash.v1`, `idempotency_key` | Cierra caja y calcula diferencia |
| `rpc_open_dining_session` | `tables.manage` | `dining_table_id`, `terminal_id`, `idempotency_key` | Abre sesión de mesa |
| `rpc_add_dining_item` | `tables.manage` | `dining_session_id`, `variant_id`, `quantity`, `notes?`, `idempotency_key` | Agrega línea con precio de servidor |
| `rpc_send_production` | `production.send` | `dining_session_id`, `station KITCHEN|BAR`, `idempotency_key` | Encomienda líneas y crea orden |
| `rpc_update_production_status` | `production.update` | `production_order_id`, `status`, `idempotency_key` | Transición validada de la orden |
| `rpc_create_pairing_code` | `devices.manage` | `branch_id`, `dining_table_id`, `ttl_minutes? 2-15`, `idempotency_key?` | Código de 8 dígitos, válido una vez |
| `rpc_revoke_customer_device` | `devices.manage` | `device_id`, `reason?`, `idempotency_key` | Revoca tablet, sesiones y vinculación |
| `rpc_pull_catalog` | `catalog.read` o `sync.read` | `since?` ISO 8601 | Cambios de catálogo, mesas y tasas con cursor |

`rpc_register_terminal` devuelve el recibo con `entity_id` = terminal y agrega
`terminal_token`. El token no se puede recuperar después.

## 3. `rpc_confirm_sale` (sale.v1)

```json
{
  "schema_version": "sale.v1",
  "idempotency_key": "sale-<uuid>",
  "sale": {
    "id": "uuid",
    "branch_id": "uuid",
    "terminal_id": "uuid",
    "cash_session_id": "uuid|null",
    "dining_session_id": "uuid|null",
    "total_currency": "USD",
    "total_minor": 700
  },
  "items": [
    { "variant_id": "uuid", "quantity": 2, "unit_price_minor": 350 }
  ],
  "payments": [
    { "method": "cash", "amount_minor": 700, "currency_code": "USD" }
  ],
  "inventory_consumptions": [
    { "warehouse_id": "uuid", "variant_id": "uuid", "quantity": 2 }
  ]
}
```

Validaciones en orden: `schema_version`, terminal activo de la sucursal,
líneas no vacías, variante activa/no sintética, moneda, precio de catálogo,
total de líneas, pagos no vacíos, moneda y suma de pagos, caja abierta del
terminal, sesión de mesa abierta, stock disponible con `FOR UPDATE`. Códigos:
`SCHEMA_VERSION_UNSUPPORTED`, `TERMINAL_INVALID`, `ITEM_INVALID`,
`CURRENCY_MISMATCH`, `PRICE_CHANGED`, `TOTAL_MISMATCH`, `PAYMENT_INVALID`,
`PAYMENT_CURRENCY_MISMATCH`, `PAYMENT_MISMATCH`, `CASH_SESSION_INVALID`,
`DINING_SESSION_INVALID`, `INSUFFICIENT_STOCK`.

Efectos: crea `sales` (`paid`), `sale_items`, `payments`, movimientos de
inventario `SALE_CONSUMPTION`, movimiento de caja si hay pago en efectivo,
cierra la sesión de mesa y libera la mesa, audita `SALE_CONFIRMED_REMOTE` y
registra recibo.

## 4. Caja y producción

- `rpc_open_cash_session` guarda `opening_minor` como snapshot y falla con
  `CASH_SESSION_OPEN` si la caja ya tiene una sesión abierta.
- `rpc_close_cash_session` toma `closing_minor.usd_minor`, suma los movimientos
  en USD de la sesión, calcula `expected_usd_minor` y `difference_usd_minor`, y
  no permite cerrar dos veces.
- `rpc_update_production_status` solo acepta `PENDING → PREPARING → READY →
  DELIVERED` y `CANCELLED` desde estados no entregados. La tabla
  `production_orders` dispara la sincronización del estado agregado del pedido
  de cliente.

## 5. Tablets de cliente (rol `anon`)

| RPC | Payload | Resultado |
| --- | --- | --- |
| `rpc_claim_pairing_code` | `pairing_code` (8 dígitos), `device_fingerprint` (8-200), `label?` | `device_id`, `table`, `session_token`, `session_expires_at` |
| `rpc_renew_device_session` | `session_token` | Nueva expiración (+8 h) |
| `rpc_device_heartbeat` | `session_token` | `server_time` |
| `rpc_device_menu` | `session_token` | Organización, sucursal, mesa, categorías, productos, variantes y modificadores activos |
| `rpc_submit_customer_order` | ver §6 | Pedido creado con totales de servidor |
| `rpc_customer_order_status` | `session_token`, `order_id?` | Últimos 20 pedidos del dispositivo/mesa con estado y producción |
| `rpc_cancel_customer_order` | `session_token`, `order_id`, `reason?`, `idempotency_key` | Pedido cancelado y reservas liberadas |

Ninguna de estas RPC acepta `organization_id`, `branch_id`, `dining_table_id`
ni un rol desde el payload. El alcance sale del token.

Códigos: `PAIRING_CODE_INVALID`, `PAIRING_CODE_EXPIRED`, `DEVICE_REVOKED`,
`DEVICE_FINGERPRINT_INVALID`, `DEVICE_SESSION_INVALID`, `TABLE_INVALID`,
`VARIANT_INVALID`, `MODIFIER_INVALID`, `MODIFIER_SELECTION_INVALID`,
`CURRENCY_MISMATCH`, `INSUFFICIENT_STOCK`, `ORDER_INVALID`,
`ORDER_ALREADY_CANCELLED`, `ORDER_NOT_CANCELLABLE`.

## 6. `rpc_submit_customer_order` (customer_order.v1)

```json
{
  "session_token": "<64 hex>",
  "idempotency_key": "order-<uuid>",
  "items": [
    {
      "variant_id": "uuid",
      "quantity": "1.500",
      "notes": "sin hielo",
      "modifier_ids": ["uuid"]
    }
  ]
}
```

- `items` es un arreglo de 1 a 50 líneas; `quantity` acepta hasta 2 enteros y 3
  decimales.
- El servidor ignora cualquier precio enviado y calcula
  `round(quantity * (variant.price_minor + sum(modifier.price_delta_minor)))`.
- Los modificadores deben pertenecer al producto y respetar
  `min_select`/`max_select` por grupo.
- Reutiliza una sesión de mesa abierta o crea una; no crea venta ni pago.
- Inserta líneas en `dining_session_items` y reserva inventario en el primer
  almacén de la sucursal.
- Crea una `production_orders` por estación `KITCHEN`/`BAR` con sus líneas.
- Devuelve `order_id`, `order_number`, `status='RECEIVED'`, `total_minor`,
  `total_currency`, `dining_session_id`.
- Repetir la clave devuelve el mismo pedido con sus datos actuales
  (`duplicate` implícito en el recibo).

## 7. Descarga incremental

`rpc_pull_catalog({ "since": "2026-11-26T00:00:00Z" })` devuelve:

```json
{
  "organization_id": "uuid",
  "cursor": "2026-11-26T20:01:02.123456Z",
  "server_time": "...",
  "categories": [], "products": [], "variants": [], "modifiers": [],
  "tables": [], "exchange_rates": []
}
```

El cliente guarda `cursor` solo después de persistir la página. Las mesas se
filtran por `app.branch_allowed`; el catálogo y las tasas requieren `catalog.read`
o `sync.read`. No se usa Realtime como mecanismo de recuperación.

## 8. Versionado

Cada RPC valida `schema_version` cuando aplica (`sale.v1`, `inventory.v1`,
`cash.v1`, `dining.v1`, `production.v1`, `pairing.v1`, `device.v1`,
`customer_order.v1`). Un cambio incompatible requiere versión nueva y pruebas de
integración en `supabase/tests/backend.test.mjs`.