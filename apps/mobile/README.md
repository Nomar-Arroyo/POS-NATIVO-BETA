# Café Amalfi — Aplicación móvil

Scaffold Flutter para las experiencias móviles de gerencia y pedidos de
clientes. La aplicación inicia y tiene pruebas de widget; sus flujos comerciales
y conexión al backend aún no están implementados.

## Estructura

- `lib/core/`: routing, seguridad, tema y sesión.
- `lib/features/authentication/`: autenticación.
- `lib/features/manager/`: dashboard, ventas, inventario, auditoría y reportes.
- `lib/features/customer/`: vinculación de tablet, menú, producto, modificadores,
  carrito, pedidos y seguimiento.
- `android/` y `ios/`: proyectos nativos generados por Flutter.

## Desarrollo

```powershell
Set-Location apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

La app consume los recursos compartidos de `packages/amalfi_brand_assets`.
Todavía no tiene autenticación de servidor, RLS ni integración Supabase.
Consulta [el alcance móvil](../../docs/MOBILE_APP.md) y
[la arquitectura del backend](../../docs/BACKEND_ARCHITECTURE.md).
