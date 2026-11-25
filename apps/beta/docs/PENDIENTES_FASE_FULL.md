# Pendientes para la Fase Full

La siguiente lista convierte las limitaciones actuales en frentes de trabajo.
El orden es una recomendación de prioridad, no una promesa de fecha ni un
compromiso de certificación.

## 1. Seguridad, usuarios y permisos

- Implementar autenticación real, gestión segura de credenciales, cierre de
  sesión y autorización validada en la capa de servicio/servidor.
- Definir permisos por rol para precios, anulaciones, ajustes de caja,
  configuración y reportes.
- Eliminar perfiles y datos de ejemplo en instalaciones productivas; proteger
  datos personales, secretos y registros de auditoría.
- **Criterio de salida:** pruebas de autorización para cada acción restringida y
  revisión de seguridad antes de usar datos reales.

## 2. Persistencia y operación multi-equipo

- Evaluar una base de datos transaccional y API respaldada, con migraciones,
  control de concurrencia y estrategia de sincronización.
- Definir respaldo cifrado, retención, recuperación probada y herramientas de
  exportación/importación con validación y vista previa.
- Acordar cómo se conserva o migra el `localStorage` existente.
- **Criterio de salida:** restauración comprobada, migración reproducible y
  pruebas de uso concurrente sin pérdida de operaciones.

## 3. Integración fiscal legal

- Recopilar requisitos legales vigentes y seleccionar el proveedor/interfaz
  autorizada para facturación electrónica o fiscal.
- Definir numeración/control, contingencia, anulaciones, exenciones, impuestos,
  almacenamiento de evidencias y tratamiento de errores.
- Separar explícitamente simulación y producción; no habilitar emisión real sin
  aprobación legal y técnica.
- **Criterio de salida:** integración aprobada con proveedor, pruebas de
  certificación y verificación por asesores competentes.

## 4. Caja, pagos e inventario

- Definir conciliación, cierres, anulaciones aprobadas y reportes contables.
- Diseñar integración de pagos con adquirentes autorizados; no almacenar datos
  de tarjetas.
- Añadir el módulo de productos a la navegación principal y completar los
  controles de alta/edición. Implementar el ajuste de stock que actualmente es
  solo visual y registrar cada cambio en un historial de inventario.
- Añadir compras, proveedores, movimientos de inventario, alertas, recetas,
  costos y trazabilidad si forman parte del alcance de negocio.
- **Criterio de salida:** conciliación comprobable y flujos de error/reintento
  cubiertos con datos de prueba.

## 5. Impresión y hardware

- Probar matrices de impresoras, tamaños de papel y controladores en Windows.
- Evaluar ESC/POS, corte, cajón y lectores solo con requisitos de hardware
  definidos y revisión de seguridad.
- Validar vista previa, impresión fallida, cancelación y recuperación.
- **Criterio de salida:** pruebas reproducibles con modelos de hardware
  soportados y documentación por dispositivo.

## 6. Calidad y despliegue

- Aumentar pruebas unitarias de servicios y store; añadir pruebas de UI y
  extremo a extremo para venta, caja, BCV, mesas y persistencia.
- Establecer umbrales de cobertura útiles por módulo, no solo un porcentaje
  global, y mantener regresiones manuales documentadas.
- Formalizar versiones, firma de instaladores, publicación, actualizaciones,
  recuperación de errores y soporte.
- **Criterio de salida:** pipeline reproducible en CI, artefactos firmados y
  pruebas de instalación/actualización en una máquina limpia.

## Decisiones que requieren confirmación de producto

- Si la aplicación será solo local o tendrá operación multi-sucursal.
- Qué roles y aprobaciones necesita cada movimiento crítico.
- Qué impresoras, métodos de pago y proveedores fiscales se soportarán.
- Qué datos se retienen, por cuánto tiempo y con qué requisitos legales.
- Qué política de respaldo y recuperación requiere el negocio.