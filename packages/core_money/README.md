# core_money

Núcleo Dart independiente para cálculos monetarios exactos de Caffè Amalfi POS.

No depende de Flutter, Supabase ni almacenamiento local.

## API

- `Currency`
- `Money`
- `ExchangeRate`
- `Conversion`
- `RoundingPolicy`
- `TaxCalculation`
- `Payment`

Todos los importes usan `BigInt` en unidades menores. Las tasas se representan
como fracciones exactas y se conservan con vigencia, fuente y snapshot histórico.

## Impuestos

No hay porcentajes fiscales activos por defecto. `TaxCalculation` solo aplica
reglas explícitas que hayan sido aprobadas y validadas.

## Validación

```powershell
dart pub get
dart analyze
dart test
```
