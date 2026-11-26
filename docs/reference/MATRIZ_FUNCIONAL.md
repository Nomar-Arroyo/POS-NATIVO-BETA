# Matriz funcional

Estados permitidos: **Pendiente, En desarrollo, Implementado, Validado, Bloqueado**.

| ID | Requisito | Módulo Beta | Implementación actual | Prueba | Estado |
|---|---|---|---|---|---|
| MF-01 | Dashboard | Dashboard | React/Zustand/localStorage | Sin automatizar | Implementado |
| MF-02 | Usuarios/roles | Configuración/perfiles | PIN local con hash, sesiones auditadas y roles Administrador/Cajero/Cocina/Barra; permisos offline en UI y operaciones | SQLite y widgets | Validado localmente; Supabase pendiente |
| MF-03 | Supabase Auth | Backend | No existe | Ninguna | Pendiente |
| MF-04 | RLS | Backend | No existe | Ninguna | Pendiente |
| MF-05 | Caja | Cash | Apertura/cierre e ingresos/egresos manuales USD; audita y encola localmente | 11 pruebas SQLite | Validado |
| MF-06 | Venta directa | POS | Venta local USD con pagos distribuidos por método y stock offline permitido | SQLite + widget pagos | Validado |
| MF-07 | Mesas/sesiones | Salon | Sesiones y cierre locales | Integración | Validado |
| MF-08 | Comandas | Orders/Kitchen/Bar | Flujo por estación | Integración | Validado |
| MF-09 | Precuenta | Salon | Generación local | Integración | Validado |
| MF-10 | Pagos mixtos | POS/Split | Reparto exacto por método de pago en USD; sin conversión de moneda | Widget y validación SQLite | Validado |
| MF-11 | Vuelto | POS/Checkout | No implementado en checkout de escritorio | Ninguna | Pendiente |
| MF-12 | División de cuentas | Split | No se divide una cuenta por persona/selección de artículos | Ninguna | Pendiente |
| MF-13 | Anulación | Cancellation | Servicio/auditoría | Sin integración completa | En desarrollo |
| MF-14 | Productos/categorías | Products/Inventory | CRUD parcial | Sin automatizar | En desarrollo |
| MF-15 | SKU/variantes | Productos | No existe | Ninguna | Pendiente |
| MF-16 | Inventario básico | Inventory | Tabla local de productos, existencias, categorías y disponibilidad | Integración SQLite y UI | Validado |
| MF-17 | Ajuste de stock | Inventory | Entrada/salida con motivo, reserva protegida, auditoría y outbox atómico | Pruebas SQLite | Validado |
| MF-18 | Recetas/insumos | Ninguno | No existe | Ninguna | Pendiente |
| MF-19 | Compras/proveedores | Ninguno | No existe | Ninguna | Pendiente |
| MF-20 | Cuentas por cobrar/pagar | Accounts | Pantalla/esqueleto por validar | Ninguna | Pendiente |
| MF-21 | Contabilidad | Ninguno | No existe | Ninguna | Pendiente |
| MF-22 | Reportes | Reports | Ventas/caja locales | Manual | Implementado |
| MF-23 | Auditoría | Audit | Log local | Unitarias parciales | Implementado |
| MF-24 | BCV/historial | ExchangeRate | Tasa activa sin historial formal | Unitarias | Implementado |
| MF-25 | Precisión decimal | Cálculos | Number con redondeo | Unitarias | Pendiente |
| MF-26 | IGTF legal | Configuración | Configurable, 3% predeterminado en datos | Ninguna legal | Bloqueado |
| MF-27 | Offline-first | Ninguno | localStorage operativo sin cola | Ninguna offline | Bloqueado |
| MF-28 | SQLite | Ninguno | No existe | Ninguna | Pendiente |
| MF-29 | Cola/sync | Ninguno | No existe | Ninguna | Pendiente |
| MF-30 | Idempotencia | Sales | Duplicado básico por factura, sin red | Ninguna distrib. | Pendiente |
| MF-31 | Conflictos | Ninguno | No existe | Ninguna | Pendiente |
| MF-32 | Backup/restauración | Storage | Exportación/copia local | Manual | En desarrollo |
| MF-33 | Impresión | Printing | PDF operativo con diálogo de impresión del sistema; no protocolo ESC/POS nativo | Build Windows; hardware sin probar | Implementado |
| MF-34 | 58/80 mm | Printing | Formato PDF configurable a 58/80 mm en precuenta/comanda/comprobante/cierre | Build Windows; hardware sin probar | Implementado |
| MF-35 | Lectores/barcode | Ninguno | No existe | Ninguna | Pendiente |
| MF-36 | Fiscalidad | Fiscal | Simulación marcada | Ninguna legal | Bloqueado |
| MF-37 | SENIAT/libros | Ninguno | No existe | Ninguna legal | Bloqueado |
| MF-38 | Mobile gerencial | Ninguno | No existe | Ninguna | Pendiente |
| MF-39 | Branding/UX | Components | Responsive y tema | Manual | Implementado |
| MF-40 | Accesibilidad | Layout/Common | Controles básicos | Manual | En desarrollo |

## Cobertura de nueva infraestructura — Etapa 1

| ID | Requisito | Implementación Flutter/Beta | Prueba | Estado |
|---|---|---|---|---|
| E1-01 | Modelo organization/branch/terminal/warehouse | Diseño relacional | Revisión de esquema | En desarrollo |
| E1-02 | Identidad persistente | Diseño de terminal | Pendiente | Pendiente |
| E1-03 | Core monetario | Paquete Dart `packages/core_money` | 12 pruebas Dart y analyze | Validado |
| E1-04 | SQLite versionado | Paquete Dart `packages/data_local` | 15 pruebas SQLite y analyze | Validado |
| E1-05 | Outbox/Inbox | Persistencia e outbox locales | Pruebas de pendiente, recibo y cursor | Validado |
| E1-06 | Idempotencia | Llaves únicas y comprobación previa | Prueba de operación repetida | Validado |
| E1-07 | Supabase Auth/RLS | Especificación | Pendiente | Pendiente |
| E1-08 | RPC comerciales | Diseño | Pendiente | Pendiente |
| E1-09 | Importador Beta | Diseño | Pendiente | Pendiente |
| E1-10 | Inventario offline | Diseño | Pendiente | Pendiente |

| E1-11 | Backoff y jitter persistidos | Paquete `core_sync` y outbox local | Pruebas de retry policy | Validado |
| E1-12 | Inbox idempotente | `SyncInbox` y recibos SQLite | Prueba de llave repetida | Validado |
| E1-13 | Cursores de cambios | `CursorStore` y tablas SQLite | Pruebas de cursor | Validado |
| E1-14 | Conflictos comerciales | `SyncConflict` y estado conflict | Prueba stockMismatch | Validado |
| E1-15 | Importador piloto sintético | `packages/data_migration` | 6 pruebas de validación e importación | Validado |
| E1-16 | Conservación de ID Beta | `beta_origin_id` y mapa UUID | Prueba de catálogo importado | Validado |
| E1-17 | Conciliación posterior | Informes y conteos | Prueba de reimportación | Validado |

## Cobertura Flutter — Etapa 2 Escritorio

| ID | Requisito | Implementación | Prueba | Estado |
|---|---|---|---|---|
| E2-01 | Configuración local inicial | Formulario y creación transaccional de empresa, sucursal, terminal, administrador con PIN, almacén y caja | Widget de primer inicio y SQLite | Validado |
| E2-02 | Catálogo local | Alta y ajuste de stock; productos sintéticos identificados, no cobrables en datos reales y habilitados para simulación solo en demo aislada | SQLite y UI | Validado |
| E2-03 | Caja de escritorio | Apertura/cierre, conteo e ingresos/egresos manuales USD con outbox | Prueba de integración SQLite | Validado |
| E2-04 | Venta directa escritorio | Venta USD con reparto exacto por métodos; pago, inventario, caja y outbox atómicos | Integración SQLite/rollback y widget de pagos | Validado |
| E2-05 | Dashboard local | Estado de caja, productos, pendientes y ventas recientes | Flutter analyze/tests | Validado |
| E2-06 | Sincronización remota | Supabase no disponible; no se reporta ninguna venta como sincronizada | No aplica hasta habilitar backend | Bloqueado |
| E2-07 | Mesas, precuentas y comandas | Sesiones, reservas, estados de cocina/barra y checkout atómico | Integración SQLite y widgets de navegación | Validado |
| E2-08 | Impresión operativa | PDF no fiscal de venta, precuenta, comanda y cierre; fallback a diálogo de impresión por estación | Tests y build Windows; hardware real pendiente | Validado en software |
| E2-09 | Pagos en moneda extranjera, vuelto y fiscalidad | No implementados; pagos solo USD y sin reglas fiscales | Pendiente de alcance/legal | Pendiente |
| E2-10 | Reportes locales | Resumen de ventas por período y exportación CSV al portapapeles | Widget y lógica local | Implementado |
| E2-11 | Auditoría local | Búsqueda, filtro por entidad y exportación CSV | Widget y SQLite | Implementado |
| E2-12 | Configuración local | Datos del terminal de solo lectura y reglas fiscales deshabilitadas | Widget y prueba de navegación | Validado |
| E2-13 | Sesiones y perfiles | PIN local, permisos offline, perfil inicial Admin y alta de perfiles por administrador; demo SQLite aislada en memoria | Tests de auth/roles/demo y widgets | Validado localmente |
