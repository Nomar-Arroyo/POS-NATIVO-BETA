# Modelo de datos

## Almacenamiento

Los datos se serializan como JSON en `localStorage` bajo la clave
`pos_nativo_beta_v2`. El documento declara la versión de esquema **4** y contiene
usuarios locales, configuración, productos, categorías, mesas, órdenes,
divisiones, precuentas, pagos, facturas, auditoría, sesiones de caja y
movimientos. No hay una base de datos relacional ni un servidor central.

Al cargar, el servicio completa colecciones ausentes con valores por defecto y
normaliza sesiones y movimientos de caja. La migración actual reconoce el esquema
1 para añadir categorías y posteriormente actualiza la versión al esquema
vigente. Mantén una exportación JSON antes de cambiar de entorno o restablecer los
datos.

## Entidades principales

| Entidad | Información y relaciones |
| --- | --- |
| `User` | Identificador, nombre, rol local (`admin`, `cashier`, `waiter`, `chef`) y estado activo. No contiene credenciales. |
| `Config` | Establecimiento, RIF, moneda, tasa activa y su fuente, última tasa/fecha BCV, IVA, IGTF, modo fiscal y ancho de impresión. |
| `Product` / `Category` | Catálogo, precio en USD, estación (COCINA/BARRA), disponibilidad, existencia opcional y categoría. |
| `Table` / `TableSession` | Estado y capacidad de mesa; sesión activa, artículos, totales USD/Bs y marcas de tiempo. |
| `AccountItem` | Producto, cantidad, precio unitario, notas y estados de envío/anulación dentro de una sesión. |
| `Order` / `OrderItem` | Comanda asociada a una mesa y estación, productos, cantidades, estado y usuario que la envía. |
| `SplitBill` / `Split` / `SplitPayment` | División asociada a mesa/sesión, partes, artículos, subtotales, pagos y estado de cada cuenta. |
| `Precuenta` | Copia de artículos y totales de una sesión para presentar antes del pago. |
| `Pago` | Método, importe, moneda y referencia opcional; se relaciona con una factura o una parte según el flujo. |
| `Factura` | Artículos, subtotal, base imponible, impuestos, total, pagos, datos opcionales del cliente, número y marca `simulated`. |
| `CashSession` / `CashMovement` | Usuario, apertura/cierre, balances esperados/reales, movimientos por moneda y reportes X/Z. |
| `AuditLog` | Acción, fecha, usuario, categoría, severidad y referencias opcionales a objetos operativos. |

Las fechas y relaciones se guardan dentro del documento JSON; no se aplican
restricciones referenciales de una base de datos. Los identificadores y las
validaciones de negocio se generan en los servicios.

## Reglas de moneda y fiscalidad

- Los precios del catálogo se interpretan en USD.
- Los importes en Bs son conversiones con la tasa activa guardada en `Config`.
- `exchangeRateSource` distingue BCV de MANUAL. `bcvRate` y `bcvRateDate`
  guardan la última cotización incluso cuando aún no es efectiva.
- La factura contiene `simulated: true`; sus números no tienen garantía de
  unicidad legal ni son correlativos fiscales oficiales.
- Los porcentajes de IVA/IGTF son parámetros de simulación y no deben tomarse
  como determinación legal de impuestos.

## Copias e intercambio

El servicio permite exportar e importar el documento JSON y crear/restaurar una
copia local. También programa una copia local periódica. Estas funciones no
constituyen respaldo externo ni garantizan retención, cifrado o recuperación
ante fallo del equipo. Conserva exportaciones independientes en una ubicación
segura y comprueba su restauración con datos de prueba.