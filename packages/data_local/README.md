# data_local

Paquete Dart independiente para persistencia SQLite local y sincronización
Offline-First de Caffè Amalfi POS.

No modifica ni lee el `localStorage` de la Beta React/Tauri.

## Funciones implementadas

- migración SQLite versionada;
- claves UUID;
- claves foráneas y restricciones;
- entidades comerciales mínimas;
- confirmación transaccional de venta;
- venta, ítems, pagos, inventario y auditoría en una misma transacción;
- rollback ante stock insuficiente o datos inválidos;
- outbox persistente;
- recibos de sincronización;
- cursores;
- registro de errores;
- idempotencia por clave;
- estados `PENDING`, `SYNCED` y `ERROR`;
- datos sintéticos únicamente para pruebas.

## Uso

```dart
final database = await LocalDatabase.open(r'C:\pos\amalfi.db');
```

Las migraciones se aplican automáticamente al abrir.
Para pruebas puede usarse `LocalDatabase.openInMemory()`.

## Validación

```powershell
cd packages/data_local
dart pub get
dart analyze
dart test
```
