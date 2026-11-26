# Motor monetario

## API propuesta para core_money

- `Currency`
- `Money`
- `ExchangeRate`
- `Conversion`
- `RoundingPolicy`
- `TaxCalculation`

El paquete será independiente de Flutter y Supabase.

## Representación

Cada `Money` contiene:

- `minorUnits`: entero.
- `currencyCode`: código ISO.
- `scale`: exponentes decimales de la moneda.

No se utilizarán `double`, `parseDouble` ni redondeos binarios en lógica comercial.
Los datos JSON externos se convierten a texto Decimal y luego a enteros.

## ExchangeRate

```text
baseCurrency
quoteCurrency
rateMinorUnits
scale
effectiveFrom
effectiveTo
source
```

La tasa histórica pertenece a la operación y no se busca por cada pantalla.

## Redondeo

Política configurable:

- `HALF_UP` para importes comerciales.
- descuento en céntimos solamente al finalizar cada línea o documento.
- no redondear de forma acumulativa entre pasos salvo política documentada.
- conversiones muestran tasa aplicada y residuo.

La política exacta se aprobará antes de implementar el paquete.

## Impuestos

`TaxCalculation` acepta subtotal, conjunto de reglas y política. El sistema no
activará IVA/IGTF por defecto basado en constantes locales. Toda tasa fiscal
debe provenir de una regla aprobada y validada.

## Pruebas

- límites entero/Decimal;
- redondeo positivo y negativo;
- cero y moneda sin decimales;
- tasa histórica;
- conversión USD/Bs;
- pagos mixtos;
- vuelto;
- sobropago;
- pagos con tasas distintas;
- anulaciones parciales.

## Estado de implementación

El entregable B está implementado en `packages/core_money`.

- `Currency`: código ISO y cantidad de decimales menores.
- `Money`: unidades menores `BigInt` y operaciones exactas.
- `ExchangeRate`: fracción racional y vigencia histórica.
- `Conversion`: conversión y liquidación de pagos mixtos.
- `RoundingPolicy`: half-up, half-even, floor, ceiling y truncamiento.
- `TaxCalculation`: solo calcula reglas proporcionadas explícitamente.
- `Payment`: conserva importe original, método y snapshot de tasa.

Validación ejecutada:

- `dart analyze`: sin incidencias.
- `dart test`: 12 pruebas aprobadas.
- Sin `double`, `parseDouble` ni float como entrada monetaria.
- No existe IVA/IGTF activado por defecto.
