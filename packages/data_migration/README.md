# data_migration

Importador piloto de exportaciones JSON de la Beta de Caffè Amalfi POS.

## Protecciones

- requiere `synthetic: true` por defecto;
- rechaza datos reales hasta habilitar explícitamente otro modo;
- no lee ni modifica `localStorage`;
- conserva `beta_origin_id`;
- genera UUID deterministas por tipo y identificador Beta;
- valida esquema, referencias y precios;
- detecta identificadores duplicados;
- exige que el checksum coincida entre vista previa e importación;
- importa categorías, productos, variantes y usuarios/perfiles;
- ejecuta en transacción SQLite;
- no reemplaza entidades ya importadas.

## Uso

```dart
const importer = BetaImporter();
final preview = importer.preview(jsonText, options);
if (!preview.isValid) {
  // Mostrar preview.issues
}
final report = importer.importPreview(
  jsonText,
  preview,
  database,
  options,
);
```
