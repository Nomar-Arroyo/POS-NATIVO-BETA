# Tablets de autoservicio para clientes

Estado: **backend implementado y probado**. La app Flutter de tablet aún debe
consumir estos contratos. No requiere Supabase Auth para el cliente: usa pairing
con código y un token de dispositivo.

## 1. Flujo implementado

1. Un perfil con `devices.manage` llama `rpc_create_pairing_code` con
   `branch_id` y `dining_table_id`. Recibe un código de 8 dígitos válido 2–15
   minutos (10 por defecto), de un solo uso.
2. La tablet envía `rpc_claim_pairing_code` con el código y una huella de
   dispositivo estable (`device_fingerprint`, 8–200 caracteres). El servidor
   hashea la huella, crea o reutiliza el dispositivo y devuelve:
   `device_id`, `table`, `session_token` y `session_expires_at`.
3. La tablet consulta `rpc_device_menu` con el `session_token`. Recibe solo el
   menú activo y no sintético de su organización, con variantes y modificadores.
4. El cliente arma el pedido y llama `rpc_submit_customer_order` con
   `session_token`, `idempotency_key` e `items` (variante, cantidad, notas,
   modificadores). El servidor calcula precios, total, reservas y comandas.
5. La tablet consulta `rpc_customer_order_status` para ver el estado agregado y
   la producción por estación.
6. Mientras el pedido siga `RECEIVED`, la tablet puede cancelarlo con
   `rpc_cancel_customer_order`; después debe pedirlo al personal.
7. La sesión se renueva con `rpc_renew_device_session` y late con
   `rpc_device_heartbeat`.

## 2. Seguridad

- El código de pairing se guarda hasheado (SHA-256) y solo se muestra una vez.
- Crear un código nuevo revoca los códigos activos de esa mesa.
- El token de sesión es opaco, de 32 bytes hex; solo se persiste su hash, tiene
  vigencia deslizante de 8 horas y se revoca al re-vincular o revocar.
- Una sola vinculación activa por dispositivo; una sola sesión de mesa abierta
  por mesa.
- El dispositivo solo puede operar sobre su mesa; no puede enviar
  `organization_id`, `branch_id`, `dining_table_id`, `terminal_id` ni rol.
- No hay grants de tabla para `anon`: incluso si el cliente conoce el esquema,
  no puede leer ni escribir directamente.
- `customer_device_sessions` no es legible por ningún rol autenticado.
- Un dispositivo revocado pierde menú, pedidos y estado; para reactivarlo se
  requiere un alta administrativa, no un nuevo pairing.
- El servidor rechaza variantes inactivas, sintéticas o de otra organización y
  valida modificadores y cantidades.

## 3. Precios y totales

La tablet puede mostrar un total orientativo, pero el servidor ignora cualquier
precio o total enviado. El costo de una línea es
`round(quantity * (variant.price_minor + sum(modifier.price_delta_minor)))` y el
total del pedido es la suma de líneas. La moneda debe ser consistente en todo el
pedido (`CURRENCY_MISMATCH`).

## 4. Pedidos, producción e inventario

- El pedido no crea venta ni pago; se cobra después desde el POS.
- Se reutiliza la sesión de mesa abierta o se crea una nueva, y la mesa pasa a
  `OCCUPIED`.
- Las líneas de productos `KITCHEN`/`BAR` nacen `SENT` y generan una
  `production_orders` por estación; las `UNASSIGNED` quedan `PENDING` sin orden.
- Se reserva inventario en el primer almacén de la sucursal con bloqueo; si no
  alcanza, todo el pedido se revierte con `INSUFFICIENT_STOCK`.
- Al cancelar se liberan reservas, se registran movimientos `RELEASE` y se
  cancelan comandas y líneas.
- Al cambiar el estado de una orden de producción, un trigger agrega el estado a
  `customer_orders`: `PREPARING`, `READY`, `DELIVERED` o `CANCELLED`.
- Repetir la misma `idempotency_key` devuelve el mismo pedido; no duplica
  comandas, reservas ni producción.

## 5. Pendiente en el cliente Flutter

- Almacenamiento seguro del `session_token` (no en logs ni preferencias
  planas).
- Manejo de expiración/revocación y reintentos idempotentes del pedido.
- Carrito persistente y UX de modificadores; el backend ya valida el contrato.
- Realtime no está implementado: el seguimiento usa sondeo de
  `rpc_customer_order_status` hasta que se acuerde la suscripción.
- Identificación del cliente, pago en línea, propina y pedidos sin mesa siguen
  fuera de alcance.