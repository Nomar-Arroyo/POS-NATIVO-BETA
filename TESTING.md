# Estrategia de pruebas de Etapas 1 y 2

## Beta React/Tauri

La Beta quedó aislada en `apps/beta`; ejecuta las pruebas desde esa carpeta:

```powershell
Set-Location apps/beta
npm ci
npm run typecheck
npm run test:all
npm run build
```

El workflow de Windows usa el mismo directorio y el lockfile de la Beta.

## Entregable A

El entregable A no requiere ejecutar infraestructura. Sus criterios son:

- documentos revisados;
- diagrama consistente;
- claves e índices definidos;
- estados y políticas documentados;
- matriz actualizada.

## Núcleo monetario

Implementado y validado en `packages/core_money`:

- límites y escapes;
- redondeo;
- conversiones;
- pagos mixtos;
- histórico de tasa;
- anulaciones.

Ejecutar:

```powershell
cd packages/core_money
dart pub get
dart analyze
dart test
```

## Aplicación Flutter Desktop

Pruebas iniciales:

- renderizado sin base local;
- formulario de primera configuración local;
- cambio de módulo de navegación;
- integración de migración SQLite y políticas de venta offline;
- alta de producto, apertura/cierre de caja y venta local atómica;
- compilación Windows.
- pantalla de mesas/comandas y diálogo de pagos divididos en métodos USD.
- ingreso/egreso de caja y outbox transaccional.
- generación de comprobantes PDF; el diálogo y hardware de impresión requieren prueba manual.
- renderizado de dashboard, inventario con catálogo sintético, POS, caja,
  reportes, auditoría y configuración en resolución desktop.
- login local por PIN, roles Cajero/Administrador y permisos.
- el catálogo sintético permanece no vendible en la base real; en la base demo
  aislada se permiten ventas simuladas sin afectar la base real.
- salida de comandas a pantalla local o al diálogo de impresión por estación.
- preferencias Sistema/Claro/Oscuro persistidas sin contaminar datos al alternar
  entre la base real y la demo.
- marca en logos, SVG, imágenes de aplicación e icono del ejecutable Windows.

Ejecutar:

```powershell
cd apps/desktop
flutter pub get
flutter analyze
flutter test
flutter build windows
```

## Recursos de marca compartidos

`packages/amalfi_brand_assets` contiene logos, fondos, SVG, PNG e iconos de
aplicación. Sus pruebas verifican la carga de las imágenes y todos los SVG.

```powershell
Set-Location packages/amalfi_brand_assets
flutter pub get
flutter analyze
flutter test
```

La app Desktop genera el icono Windows desde el recurso de 1024 px:

```powershell
Set-Location apps/desktop
flutter pub run flutter_launcher_icons
```

## Importador piloto

`packages/data_migration` valida exportaciones Beta sintéticas:

- rechazo de datos reales en modo sintético;
- checksum y cambio de contenido;
- identificadores duplicados;
- referencias de categoría;
- importación transaccional;
- UUID deterministas;
- reimportación sin duplicados;
- informe de conciliación.

Ejecutar:

```powershell
cd packages/data_migration
dart pub get
dart analyze
dart test
```

## Motor core_sync

Validación implementada:

- jitter acotado y backoff exponencial;
- límite máximo de intentos;
- recibos idempotentes;
- reenvío bloqueado;
- errores persistidos y fecha de siguiente intento;
- conflicto comercial revisable;
- ventas distintas con payload equivalente;
- cursores por stream.

Ejecutar:

```powershell
cd packages/core_sync
dart pub get
dart analyze
dart test
```

## SQLite

Implementado y validado en `packages/data_local`:

- creación y migración desde todas las versiones soportadas;
- rollback de venta + pagos + inventario;
- apertura/cierre de caja, movimientos manuales y outbox local;
- reserva/liberación de inventario, mesas, precuenta, comandas y checkout atómico;
- outbox persistido;
- recuperación ante cierre inesperado;
- claves duplicadas.

Última validación:

- `dart analyze`: sin incidencias.
- `dart test`: 15 pruebas aprobadas.

Pruebas cubiertas:

- aplicación única de migración;
- reapertura de base SQLite;
- configuración inicial y creación de catálogo;
- bloqueo de productos no habilitados para venta offline;
- apertura/cierre, egreso/ingreso y cálculo del efectivo esperado;
- ajuste de stock, auditoría, outbox y rollback al respetar reservas de mesas;
- venta local con outbox;
- rollback por stock insuficiente;
- idempotencia;
- ventas distintas con igual total;
- recibos y cursores;
- sesión de mesa, reserva de stock, comanda por estación, precuenta y pago/cierre atómico;
- carga repetible de catálogo sintético, sin outbox de catálogo y con venta
  bloqueada en el terminal real.
- almacenamiento hash de PIN, autenticación de perfiles y permisos locales.
- venta sintética habilitada únicamente en la base demo en memoria.

Ejecutar:

```powershell
cd packages/data_local
dart pub get
dart analyze
dart test
```

Última validación de escritorio:

- `flutter analyze`: sin incidencias.
- `flutter test`: 8 pruebas aprobadas; incluye acceso y salida de demo aislada,
  navegación a 1365×768, 900×600 y
  720×600, cambio entre temas claro/oscuro, apertura de modal y conservación de
  la búsqueda POS al cambiar de módulo y fallback de impresión por estación.
- `flutter build windows`: compilación Release aprobada con perfiles y sesiones locales.
- Impresión física y diálogo interactivo no probados; la salida generada es PDF
  operativo y no tiene validez fiscal.

## Sincronización

- reintentos y backoff;
- interrupción entre outbox e inbox;
- eventos repetidos;
- cursor incompleto;
- conflictos por stock y caja;
- ventas distintas con valores iguales.

## Supabase

- RLS por organización y rol;
- terminal revocado;
- venta RPC atómica;
- doble entrega idempotente;
- permisos offline vencidos.
