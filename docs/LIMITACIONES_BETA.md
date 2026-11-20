# Limitaciones de la Beta

Esta versión está destinada a demostración y pruebas controladas. No la uses como
único sistema de registro para operaciones comerciales, fiscales o contables.

## Fiscalidad

- La opción fiscal solo simula un tiempo de procesamiento, cálculo y asignación
  de números. No transmite información al SENIAT ni a un proveedor fiscal.
- Las facturas generadas llevan `simulated: true`; sus números de factura/control
  no son documentos válidos, autorizaciones ni correlativos fiscales oficiales.
- Los cálculos de IVA/IGTF son una simplificación configurable. El modelo actual
  considera todos los productos gravados y no implementa exenciones, reglas
  fiscales completas ni validación legal vigente.
- Los datos fiscales de establecimiento y cliente no deben usarse para emitir
  documentos oficiales.

## Datos, seguridad y continuidad

- No hay backend, base de datos compartida ni sincronización. Cada equipo/perfil
  mantiene sus propios datos locales en `localStorage` del navegador/WebView.
- Los perfiles y roles locales no incluyen autenticación de usuario, contraseñas,
  sesiones seguras ni autorización de servidor. No equivalen a controles de
  seguridad frente a una persona con acceso al equipo.
- Los datos locales no están cifrados por la aplicación. No guardes información
  sensible ni uses cuentas/terminales compartidas sin controles del sistema.
- Existe exportación/importación JSON y una copia local programada, pero no hay
  servicio remoto de respaldo, política de retención, recuperación ante desastre
  ni garantía de migración entre instalaciones. Prueba las copias con datos
  ficticios y conserva una exportación fuera del equipo.
- No hay garantías de concurrencia, transacciones o consistencia entre varios
  operadores simultáneos.

## Operación e integraciones

- La tasa depende de disponibilidad y estructura de la página pública del BCV.
  La aplicación conserva la tasa activa si falla la consulta y no aplica una
  cotización antes de su fecha de vigencia.
- El inventario solo presenta existencias; el botón de ajuste de stock no tiene
  una operación implementada. El módulo de alta/edición de productos no está
  conectado a la navegación principal. Tampoco hay compras, proveedores,
  recetas, costos, lotes, trazabilidad ni control completo de movimientos.
- La impresión usa el diálogo/controladores del sistema. No hay integración
  directa certificada con impresoras fiscales, ESC/POS, cajones, balanzas,
  lectores ni terminales bancarios.
- Los pagos se registran en la aplicación, pero no se procesan con bancos,
  adquirentes, pago móvil ni billeteras.

## Calidad y distribución

- La cobertura global automatizada verificada es 14,58 % de sentencias y 15,10 %
  de líneas (28 pruebas). Varias pantallas y operaciones requieren ampliar
  pruebas de integración, UI y extremo a extremo.
- La revisión responsive y de temas no sustituye la regresión manual de todos
  los flujos, impresoras, WebView e instaladores en equipos reales.
- Los instaladores de Windows no están firmados por defecto. SmartScreen puede
  mostrar advertencias y aún no hay un proceso formal de actualización automática.

Antes de una operación real se necesita cerrar los pendientes de
[PENDIENTES_FASE_FULL.md](./PENDIENTES_FASE_FULL.md), definir requisitos legales y
validar la solución con usuarios y asesores competentes.