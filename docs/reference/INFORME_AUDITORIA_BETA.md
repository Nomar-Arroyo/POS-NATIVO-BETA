# Informe de auditoría de la Beta

**Fecha de auditoría:** 2026-11-24
**Versión auditada:** 1.0.0-beta
**Estado:** Etapa 0 completada; sin migración masiva iniciada

## 1. Resumen ejecutivo

La Beta es una aplicación de punto de venta local-first construida con React 18,
TypeScript, Zustand, Vite, Tailwind CSS y Tauri 2/Rust. Está empaquetada como
aplicación Windows mediante MSI/NSIS y contiene módulos operativos útiles para
mesas, ventas, caja, comandas, reportes y configuración.

La solución es adecuada como referencia funcional y fuente de reglas, pero no
como base única de producción: usa `localStorage`, no tiene autenticación real,
backend central, transacciones relacionales, sincronización ni integraciones
fiscales reales.

## 2. Qué existe

### Tecnología

- Frontend React 18 con componentes y módulos TypeScript.
- Zustand para estado central y `storageService` para persistencia local.
- Vite y Tailwind CSS.
- Tauri 2/Rust para empaquetado Windows y consulta al BCV.
- Vitest para pruebas unitarias e integración.
- Script de compilación Windows con MSI y NSIS.

### Funcionalidades observadas

- Dashboard operativo.
- Mesas, sesiones, artículos, precuentas y división de cuentas.
- Venta directa y pagos USD/Bs combinados.
- Comandas separadas para cocina y barra.
- Inventario básico de consulta.
- Apertura/cierre de caja y movimientos.
- Reportes de ventas y caja, reportes X/Z simulados.
- Auditoría local.
- Configuración de establecimiento, tasa, impuestos y impresión.
- Consulta nativa y por proxy de la tasa BCV.
- Plantillas de impresión para diálogo del sistema.
- Exportación/importación JSON y copia local.

### Persistencia

Los datos se guardan en `localStorage` bajo `pos_nativo_beta_v2`, con versión de
esquema 4. Las entidades principales son usuarios, configuración, productos,
categorías, mesas, sesiones, órdenes, divisiones, precuentas, pagos, facturas,
auditoría y caja.

## 3. Qué funciona

La validación de transición confirmó:

- `npm run typecheck`: pasó.
- `npm run test:all`: 8 archivos y 28 pruebas pasaron.
- `npm run build`: pasó.

Las pruebas cubren tipos de cambio BCV, cálculos, pagos mixtos, caja/precuenta,
mesas, órdenes, división de cuenta y verificación básica.

## 4. Qué está incompleto

- Usuarios locales sin contraseña ni autenticación segura.
- Permisos dependientes de cambios de interfaz, sin autorización de backend.
- Sin PostgreSQL/Supabase, RLS ni sincronización.
- Sin SQLite local ni cola offline.
- Sin idempotencia ni control de concurrencia real.
- Monetario implementado con números JavaScript de punto flotante.
- Los impuestos IGTF/IVA usan valores configurables; no existe determinación legal.
- Facturas marcadas como simuladas; no hay emisión fiscal válida.
- Ajuste de stock visible pero sin operación completa.
- Sin recetas, variantes, SKU completos, compras, proveedores, lotes ni movimientos
  avanzados de inventario.
- Sin ESC/POS, cajón, lectores, terminales ni impresoras fiscales reales.
- Sin pasarelas de pago ni procesamiento bancario.
- Sin aplicación móvil.
- Cobertura global limitada y sin pruebas completas de UI/dispositivo.
- Instaladores sin firma predeterminada y sin actualización automática formal.

## 5. Qué puede reutilizarse

Reutilizar conceptualmente:

- Flujos de mesa, POS, caja, precuentas y división de cuenta.
- Separación entre tienda, servicios y componentes.
- Pruebas de cálculos, BCV y workflows integrados.
- Catálogo de demostración y estructura de usuarios locales.
- Plantillas visuales y sistema de iconografía.
- Servicios de impuestos simulados como punto de referencia, no como motor fiscal.
- Consulta BCV como adaptador externo reemplazable.

No deben reutilizarse como implementación final:

- Identificadores aleatorios como fuente de unicidad distribuida.
- Persistencia directa en `localStorage`.
- Control de permisos únicamente en React.
- `number` para cálculo monetario.
- Valores fiscales fijos como determinación normativa.
- Copia local dentro del mismo perfil como único respaldo.

## 6. Qué debe reconstruirse

- Núcleo comercial en Dart con dominio independiente de UI.
- PostgreSQL/Supabase, migraciones, RLS y Supabase Auth.
- SQLite local, cola de sincronización e idempotencia.
- Motor decimal compartido para ventas, pagos y conversiones.
- Estados explícitos local/pending/synced/error.
- Backend transaccional para confirmar ventas y descontar inventario.
- Adaptadores Flutter para hardware y fiscalidad.
- Aplicaciones desktop/móvil sobre servicios compartidos.

## 7. Inventario técnico

| Área | Estado |
|---|---|
| Frontend | React/TS/Tailwind implementado |
| Desktop | Tauri 2/Windows implementado |
| Estado | Zustand implementado |
| Persistencia | localStorage implementado |
| Backend | No existe |
| Base relacional | No existe |
| Autenticación | No existe |
| Sincronización | No existe |
| Pruebas | 28 pruebas automatizadas |
| Documentación | Existe documentación beta básica |
| Fiscalidad | Simulada únicamente |
| Impresión | Diálogo WebView únicamente |

## 8. Riesgos migratorios

1. Pérdida o duplicación de datos por migración no verificable.
2. Cambios incompatibles en identificadores y modelos.
3. Diferencias monetarias por precisión binaria.
4. Divergencia entre reglas Flutter y React.
5. Eliminación accidental de datos locales existentes.
6. Confusión entre facturas simuladas y fiscales.
7. Uso prematuro de datos de demostración en producción.

## 9. Preservación de datos

Antes de cualquier migración:

- Exportar una copia verificable de `localStorage`.
- Conservar hash, fecha y versión de esquema.
- Importar en una base aislada de pruebas.
- Validar conteos y totales por entidad.
- Resolver duplicados e identificadores inválidos antes de sincronizar.
- Mantener la Beta sin escribir en producción hasta finalizar y aprobar un ensayo.
- No añadir datos ficticios a catálogos o operaciones reales.

## 10. Dependencias para Etapa 1

- Confirmar esquema comercial y reglas fiscales validadas.
- Confirmar sucursales, usuarios y política de dispositivos.
- Aprovisionar proyecto Supabase sin credenciales en el repositorio.
- Definir proveedor de identidad y política RLS.
- Seleccionar paquete Dart Decimal y SQLite compatibles.
- Obtener datos reales de catálogo y existencia únicamente por fuentes autorizadas.
- Aprobar estrategia de migración y respaldo verificable.
