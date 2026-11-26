# Plan de migración de datos

## Alcance

Solo datos exportados por la Beta y autorizados explícitamente. Los 317 SKU no
se consideran disponibles hasta recibir una fuente real.

## Importador JSON

Debe producir:

1. versión y checksum;
2. mapa de entidad Beta -> UUID;
3. errores por entidad/campo;
4. duplicados candidatos;
5. resumen previo;
6. informe final transaccional;
7. conteos reconciliados.

## Flujo

1. Congelar exportación Beta.
2. Validar versión JSON.
3. Separar datos sintéticos y reales.
4. Detectar IDs duplicados o referencias rotas.
5. Generar UUID persistente.
6. Previsualizar cambios.
7. Importar en SQLite y PostgreSQL aislados dentro de transacciones.
8. Comparar conteos y totales.
9. Producción solo después de aprobación.

## Sin destrucción

- No modificar la Beta.
- No limpiar `localStorage`.
- No reemplazar identificadores originales sin alias.
- No importar datos ficticios junto con datos reales.

## Entregable G — Importador piloto

Implementado en `packages/data_migration`.

- `BetaImporter.preview` valida JSON y genera mapa Beta→UUID.
- Solo acepta datos marcados `synthetic: true` en modo sintético.
- Detecta IDs duplicados y referencias inexistentes.
- Genera checksum SHA-256.
- Detecta cambios entre vista previa e importación.
- Ejecuta importación transaccional en SQLite.
- Conserva `beta_origin_id`.
- No reemplaza entidades ya importadas.
- Genera conteos de importación, omisiones y conciliación.
- Importación piloto: usuarios/perfiles, categorías, productos y variantes.
