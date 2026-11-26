# Contratos de API propuestos

Los siguientes contratos son una guía de diseño, no endpoints disponibles. Se
ajustarán con acceso a la base, al proyecto Supabase y a las reglas de producto.

## Principios comunes

- Toda solicitud autenticada deriva la identidad de la sesión del servidor.
- El servidor valida organización, sucursal, rol, permisos y estado del terminal.
- Las operaciones mutables reciben una clave de idempotencia.
- Errores tienen códigos estables; una respuesta fallida no representa éxito.
- Las escrituras críticas incluyen auditoría y efectos comerciales en una
  transacción.
- El cliente nunca recibe ni almacena una service-role key.

## Operaciones objetivo

| Área | Operación | Tipo previsto | Idempotencia |
|---|---|---|---|
| Terminales | Vincular tablet por código de un solo uso | Función/RPC | Código de pairing |
| Gerencia | Consultar resumen, ventas y reportes | Lectura RLS/RPC | No aplica |
| Inventario | Consultar existencias y registrar ajuste autorizado | RPC | Obligatoria para ajuste |
| Clientes | Consultar menú público habilitado | Lectura limitada | No aplica |
| Clientes | Crear pedido asociado a una tablet/mesa | RPC | Obligatoria |
| Clientes | Consultar estado de pedido propio | Lectura limitada | No aplica |
| Notificaciones | Entregar cambios de estado permitidos | Realtime/función | ID de evento |

## Respuesta y errores

Cada operación define su payload tipado, validación, permisos y códigos de
error antes de implementarse. Como mínimo se distinguirán autenticación
requerida, acceso denegado, recurso inexistente, validación fallida, conflicto
de versión, clave idempotente repetida y error temporal. Las respuestas de
mutación incluirán el identificador de operación y el estado confirmado por el
servidor.

## Versionado y pruebas

Los cambios incompatibles requieren una versión de contrato explícita y pruebas
de integración. Los contratos de pairing, pedidos de clientes e inventario se
validarán con políticas RLS y pruebas RPC en `supabase/tests/` antes de que un
cliente dependa de ellos.
