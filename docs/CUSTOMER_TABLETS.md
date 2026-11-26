# Tablets de autoservicio para clientes

Este documento reserva el alcance de tablets para explorar el menú y enviar
pedidos. No existe todavía pairing, menú remoto, carrito persistente ni envío de
pedidos desde la app.

## Flujo objetivo

1. Un administrador registra una tablet para una sucursal y mesa o zona.
2. La tablet muestra un código temporal de vinculación.
3. Un perfil autorizado confirma el código y asigna su alcance.
4. El cliente consulta únicamente el menú publicado para esa sucursal.
5. El cliente revisa productos, modificadores, cantidades y total antes de
   enviar el pedido.
6. La tablet muestra el estado comunicado por cocina/barra cuando el backend
   disponga de esa actualización.

## Seguridad y privacidad

- El código de pairing será temporal, de un solo uso y revocable.
- Una tablet queda limitada a una organización, sucursal y ubicación.
- La interfaz de cliente no expone ventas, perfiles, auditoría ni datos de otras
  mesas.
- El servidor valida disponibilidad, precio y modificadores al recibir cada
  pedido; no confía en totales calculados por el dispositivo.
- La configuración no almacena credenciales administrativas permanentes en la
  tablet.

## Decisiones pendientes

Definir si se requiere identificación del cliente, pago en línea, pedidos sin
mesa, propina, cancelación, idiomas, modo offline y política de retención. No se
deben asumir estos comportamientos hasta aprobarlos.
