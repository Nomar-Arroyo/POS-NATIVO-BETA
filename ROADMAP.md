# Roadmap

## Organización por aplicaciones

- [x] React/Tauri Beta aislada en `apps/beta`, conservando su código,
  persistencia, recursos y documentación.
- [x] Flutter Desktop independiente en `apps/desktop`.
- [x] Recursos visuales compartidos centralizados en
  `packages/amalfi_brand_assets`.
- [x] Scaffold Flutter multiplataforma en `apps/mobile`.
- [ ] Acordar alcance y desarrollar las funciones móviles gerenciales y de
  pedidos de clientes.

## Etapa 0 — Auditoría y transición

Estado: **Implementado/Validado** para documentación inicial.

- [x] Inventario del repositorio.
- [x] Validación TypeScript.
- [x] Ejecución de pruebas existentes.
- [x] Identificación de deuda técnica.
- [x] Arquitectura objetivo propuesta.
- [x] Plan de migración.
- [x] Matriz funcional inicial.
- [x] Plan de riesgos.

Salida: decisiones documentadas y plan de Etapa 1.

## Etapa 1 — Backend y base de datos

Estado: **Pendiente**.

### Entregable A — Arquitectura y modelo relacional

Estado: **En desarrollo** — especificación completada; pendiente de aprobación.

- [x] Modelo organization/branch/terminal/warehouse/profile/caja.
- [x] Identidad persistente de terminal.
- [x] Protocolo Outbox/Inbox y cursores.
- [x] Política de conflictos e inventario offline.
- [x] Esquema PostgreSQL implementado en migraciones 0001–0004.
- [x] Esquema SQLite propuesto.
- [x] Política monetaria y permisos.
- [x] Ejecución local de migraciones y pruebas de RLS/RPC (19 en verde).
- [ ] Despliegue de infraestructura Supabase.

### Entregable B — core_money

Estado: **Implementado/Validado**.

- [x] Paquete Dart independiente creado.
- [x] `Money`, `Currency`, `ExchangeRate`, `Conversion`,
  `RoundingPolicy` y `TaxCalculation`.
- [x] Cálculos exactos con `BigInt`; sin `double` ni conversiones binarias.
- [x] Conversión histórica con vigencia.
- [x] Pagos mixtos, vuelto y saldo pendiente.
- [x] Pruebas ejecutadas: 12 aprobadas.
- [x] `dart analyze`: sin incidencias.

### Entregable G — Importador piloto y conciliación

Estado: **Implementado/Validado**.

- [x] Importador JSON separado de la Beta.
- [x] Validación de esquema y referencias.
- [x] Bloqueo de datos reales en modo sintético.
- [x] Detección de IDs duplicados.
- [x] UUID deterministas y `beta_origin_id`.
- [x] Vista previa y checksum.
- [x] Importación transaccional.
- [x] Reimportación sin duplicados.
- [x] Informe de conciliación.
- [x] Pruebas ejecutadas: 6 aprobadas.
- [x] `dart analyze`: sin incidencias.

### Entregable D — Outbox/Inbox y sincronización

Estado: **Implementado/Validado**.

- [x] Paquete `packages/core_sync` creado.
- [x] Estados LOCAL/PENDING/SYNCED/ERROR/CONFLICT.
- [x] Backoff exponencial y jitter acotado.
- [x] Límite configurable de reintentos.
- [x] Inbox y recibos idempotentes.
- [x] Cursores por stream.
- [x] Conflictos comerciales sin sobrescritura.
- [x] Operaciones distintas diferenciadas por ID y llave.
- [x] Pruebas ejecutadas: 9 aprobadas.
- [x] `dart analyze`: sin incidencias.
- [x] Sin reglas fiscales por defecto ni IGTF activado.

### Entregable C — SQLite y migraciones

Estado: **Implementado/Validado**.

- [x] Paquete `packages/data_local` creado.
- [x] Migración SQLite inicial versionada.
- [x] UUID persistentes y claves foráneas.
- [x] Entidades comerciales, caja e inventario.
- [x] Outbox, recibos, cursores y errores.
- [x] Venta local transaccional con pagos e inventario.
- [x] Rollback completo ante stock insuficiente.
- [x] Idempotencia por clave.
- [x] Migración SQLite v5 para credenciales locales, sesiones y preferencias de estación.
- [x] Pruebas ejecutadas: 15 aprobadas, incluidas perfiles, demo aislada, mesas y caja.
- [x] `dart analyze`: sin incidencias.

- [x] Diseño del esquema PostgreSQL, migraciones 0001–0004, RLS, roles y RPC
  implementados y probados localmente (26/11/2026).
- [ ] Aprovisionar Supabase y desplegar las migraciones.
- [ ] Importar catálogo real después de validar aproximadamente 317 SKU.
- Implementar motor decimal.
- Implementar SQLite y outbox.
- Implementar sincronización inicial e idempotencia.
- Ejecutar pruebas de integridad y migración.

Bloqueadores: credenciales, catálogo real, decisión de sucursales y reglas fiscales
validadas.

## Etapa 2 — Escritorio Flutter

Estado: **En desarrollo**.

### Base de aplicación Flutter Windows

Estado: **En desarrollo** — flujo local validado; falta probar impresión en
dispositivo real y conectar backend/sincronización.

- Crear aplicación Flutter Windows.
- [x] Proyecto Windows creado.
- [x] Tokens de marca para temas claro y oscuro.
- [x] Preferencia de tema sistema/claro/oscuro persistida por terminal.
- [x] Paquete compartido de logos, fondos, SVG, PNG e iconos de aplicación.
- [x] Icono Windows de Café Amalfi generado desde el recurso de marca.
- [x] Logo en navegación e inicio de sesión; lema en el Dashboard.
- [x] Iconos SVG de marca en navegación, encabezados y tarjetas de resumen.
- [ ] Sustituir progresivamente iconos restantes de controles y módulos.
- [x] Navegación desktop con módulos principales.
- [x] Marco visual basado en la Beta: barra lateral, encabezado de negocio, estado local y pie persistente.
- [x] Vistas de Dashboard, Mesas, POS, Comandas, Inventario, Caja, Reportes, Auditoría y Configuración.
- [x] Integración con paquetes monetario, SQLite y sincronización.
- [x] Persistencia SQLite separada en Application Support.
- [x] Compilación Release de Windows ejecutable.
- [x] Configuración local inicial de empresa, sucursal, terminal, administrador con PIN, almacén y caja.
- [x] Inicio/cierre de sesión local por perfil y PIN hash, con roles Administrador, Cajero, Cocina y Barra.
- [x] Permisos locales aplicados a módulos y operaciones de venta, caja, inventario, mesas y producción.
- [x] Entorno demo SQLite en memoria, separado de los datos reales; ventas ficticias solo dentro de demo.
- [x] Salida por estación: pantalla local o diálogo de impresión secuencial como alternativa.
- [x] Dashboard local con turno, catálogo y operaciones pendientes.
- [x] Alta local de producto, precio USD, categoría, stock inicial y permiso explícito de venta offline.
- [x] Ajuste manual de inventario con motivo, auditoría, outbox y protección de reservas de mesa.
- [x] Apertura/cierre de caja con conteo local de efectivo USD.
- [x] Ingresos y egresos manuales de caja con auditoría y outbox.
- [x] Venta directa en USD con pagos distribuidos por método, caja abierta y stock habilitado offline.
- [x] Venta, pagos, movimientos de inventario y outbox en una transacción SQLite.
- [x] Mesas, sesiones, reservas de stock, precuenta, comandas y cobro/cierre atómico.
- [x] Colas locales de cocina y barra con transiciones validadas.
- [x] Comprobantes PDF para venta, precuenta, comanda y cierre mediante diálogo del sistema.
- [x] Outbox local para configuración, catálogo, caja, salón y venta.
- [x] Catálogo de 18 productos sintéticos; no vendible en datos reales y habilitado para simulación solo en demo aislada.
- [ ] Pagos en varias monedas, vuelto y división de cuenta por comensal.
- [ ] Impresión física en impresora Windows/térmica.
- [ ] Comandas generadas desde venta directa POS.
- [x] Backend Auth/RLS y RPC implementados en `supabase/` (probados localmente).
- [ ] Conectar el transporte remoto y la reconexión real desde Desktop.
- [x] Validación final: `dart analyze`/`dart test`, `flutter analyze`/`flutter test` y `flutter build windows`.

El flujo comercial real sigue siendo local: las operaciones quedan `PENDING`;
el backend existe pero el transporte remoto del POS sigue sin conectarse. La
demo opera sobre una base temporal en memoria y se descarta al salir. En la base real, productos
sintéticos no se cobran ni se envían a comandas. Las comandas se pueden mostrar
en el módulo local de producción o enviar en orden al diálogo de impresión si
se deshabilita la pantalla de su estación. Los comprobantes son operativos, no
fiscales; no se ha verificado hardware de impresión.

## Etapa 3 — Mobile gerencial

Estado: **Pendiente**.

- Crear Android/iOS.
- Implementar dashboard ejecutivo.
- Implementar ventas, mesa, inventario y auditoría.
- Restringir operaciones críticas.
- Integrar Realtime y notificaciones.

## Etapa 4 — Administración avanzada y fiscal

Estado: **Pendiente**.

- Compras y proveedores.
- Recetas y producción.
- Contabilidad y cuentas.
- Reportes legales y libros.
- Integraciones SENIAT autorizadas.
- Hardware fiscal real.
- Certificación y publicación.

## Dependencias transversales

- Diseño UX final.
- Política de backups.
- Automatización CI/CD.
- Firma de instaladores.
- Pruebas de hardware reales.
- Asesoría fiscal legal.
