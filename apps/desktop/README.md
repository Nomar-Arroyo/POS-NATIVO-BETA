# Caffè Amalfi POS — Desktop Flutter

Aplicación Flutter de escritorio, separada de la Beta React/Tauri que se
conserva en `apps/beta`.

## Funcionalidad

- POS local, mesas y salón, precuentas, comandas, cocina/barra, inventario,
  caja, reportes, auditoría y configuración;
- perfiles locales y permisos, con un entorno demo aislado en memoria;
- ventas y movimientos de inventario transaccionales en SQLite;
- tema claro, oscuro y sistema, con preferencia guardada por terminal;
- identidad visual Amalfi con iconos SVG y fotografía de café integrada como
  fondo de pantalla completa, viñeta suave y onda vectorial inferior;
- eslogan del Dashboard y firma de marca del sidebar en tipografía nativa,
  sin usar imágenes rasterizadas de texto;
- Dashboard con tarjetas de superficie limpia, estados vacíos informativos y
  onda inferior vectorial adaptada al tema.

La integración con Supabase está implementada para enviar la outbox de
`confirm_sale` (recibos estrictos, conflictos retenidos y snapshot del motor).
El resto de operaciones de la outbox y la impresión física siguen pendientes.

## Datos locales

La base se crea en el directorio Application Support de Windows, bajo
`Caffe Amalfi POS/amalfi_pos.sqlite3`. La aplicación no lee ni modifica el
`localStorage` de la Beta.

Los recursos visuales compartidos están en
[`packages/amalfi_brand_assets`](../../packages/amalfi_brand_assets/README.md).

## Ejecución

```powershell
Set-Location apps/desktop
flutter pub get
flutter run -d windows
```

Sincronización opcional (sin estas variables la app funciona offline y no
intenta llamar al backend):

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

El JWT del usuario autenticado se guarda en la preferencia local
`supabase.access_token`; sin token el ciclo de sincronización se omite.

## Validación

```powershell
Set-Location apps/desktop
flutter analyze
flutter test
flutter build windows
```
