# Funcionalidades

## Operación

- **Dashboard:** resumen de la operación disponible.
- **Salón y mesas:** mesas numeradas, Barra, Para llevar y Delivery; apertura de
  sesión, administración de artículos, envío de comandas, precuenta y cierre.
- **POS y checkout:** venta directa, selección de productos y registro de pagos
  en efectivo USD, efectivo Bs, punto de venta, pago móvil o Zelle, incluidos
  pagos combinados.
- **Comandas:** seguimiento de órdenes y separación por estación de cocina o barra.
- **Inventario:** consulta de productos, categorías, precio, disponibilidad y
  existencia básica.
- **Caja:** sesiones de caja, saldos de apertura/cierre y movimientos de ingreso,
  egreso y ajuste en ambas monedas.
- **Reportes:** reportes de ventas y de caja, incluidos reportes X/Z de sesión.
- **Auditoría:** consulta de acciones operativas registradas por la aplicación.
- **Configuración:** datos del establecimiento, tasas, parámetros fiscales
  simulados, ancho de impresión y reinicio de datos de demostración.

## Mesas, comandas y cuentas

Los artículos de una mesa forman parte de una sesión. Los artículos pueden
enviarse a cocina o barra; las órdenes tienen estados de pendiente, preparación,
listo, entregado o cancelado. Se pueden emitir precuentas y dividir el monto de
una cuenta según las opciones soportadas por la interfaz. El cierre de una mesa
depende del flujo de pago y de que las partes de la división estén saldadas.

## Moneda y tasa BCV

La tasa se consulta en la página oficial del BCV. La aplicación guarda la tasa,
su fecha de vigencia y la hora de consulta. Si la fecha publicada aún es futura,
la tasa queda almacenada, pero se mantiene activa la tasa vigente. Si el
administrador cambió la tasa manualmente, la actualización automática no la
reemplaza; se puede optar por aplicar la tasa BCV vigente desde el control de
tasa.

La conversión de precios a bolívares usa la tasa activa. La fuente (BCV o manual)
y la fecha de actualización se mantienen en la configuración local.

## Catálogo e inventario: alcance de esta entrega

Existe un módulo de productos con formularios de alta/edición y búsqueda, pero no
tiene una entrada en la navegación principal actual. La pantalla Inventario sí
está en el menú, aunque su botón «Ajustar Stock» no tiene una acción implementada.
Por tanto, el catálogo inicial sirve para probar ventas, pero la administración
completa del catálogo y los ajustes de existencias no están listos para el uso
operativo.

## Impresión

Hay plantillas para tickets y documentos de operación. El servicio crea una
ventana de impresión y permite usar anchos configurables de 58 mm u 80 mm. La
impresión final depende del diálogo del sistema, el controlador y el papel
configurado.

## Datos de demostración

En una instalación sin productos se cargan 23 productos de ejemplo y 8
categorías. La configuración inicial incluye 12 mesas numeradas, Barra, Para
llevar y Delivery, además de perfiles locales con roles de administrador,
cajero, mesero y chef. Los perfiles no tienen autenticación por contraseña y
son únicamente datos demostrativos.

## Alcance no incluido

La factura fiscal, el número de control y la transmisión SENIAT son simulados.
No se incluyen sincronización entre equipos, gestión robusta de compras/proveedores,
integración directa con impresoras fiscales, lectores de tarjetas ni una pasarela
de pagos. Ver [LIMITACIONES_BETA.md](./LIMITACIONES_BETA.md).