# Aplicación móvil

`apps/mobile` contiene el scaffold Flutter multiplataforma. El alcance contempla
dos contextos móviles que deben mantenerse separados en navegación y permisos:
gerencia y autoservicio de clientes.

## Gerencia

- Inicio de sesión segura y cierre/revocación de sesión.
- Dashboard ejecutivo y ventas autorizadas.
- Inventario, auditoría y reportes según permisos.
- Acciones críticas limitadas hasta que backend y autorización estén listos.

## Autoservicio de clientes

- Pairing de tablet con una sucursal/mesa autorizada.
- Menú, detalle de producto y modificadores.
- Carrito y envío de pedido.
- Seguimiento de pedidos propios.

El flujo de tablets requiere además las decisiones de
[CUSTOMER_TABLETS.md](CUSTOMER_TABLETS.md).

## Organización de código

- `lib/core/routing/`: navegación y límites entre contextos.
- `lib/core/security/`: integración de identidad/autorización del cliente.
- `lib/core/theme/`: tema y marca compartida.
- `lib/core/session/`: ciclo de vida de sesión y alcance de sucursal.
- `lib/features/authentication/`: acceso de personal.
- `lib/features/manager/`: módulos exclusivos de gerencia.
- `lib/features/customer/`: pedido y seguimiento de clientes.

Las carpetas vacías incluyen marcadores para conservar la estructura. El
scaffold actual solo presenta un estado informativo; no hay login, métricas,
pedidos, pairing ni sincronización implementados.

## Preparación

La aplicación comparte recursos visuales y se mantiene separada de los datos
locales del Desktop. Los contratos de [API](API_CONTRACTS.md), la autorización y
las pruebas RLS ya existen en el backend; el scaffold móvil todavía no consume
ninguno. La implementación de los modos gerencial y de cliente sigue en las
tareas M-01 a M-09 de [PLAN_TRABAJO.md](PLAN_TRABAJO.md).
