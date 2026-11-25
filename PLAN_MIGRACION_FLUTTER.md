# Plan de migración a Flutter

## 1. Estrategia

La migración será paralela y incremental. La Beta React/Tauri permanece funcional
y no se elimina hasta aprobar la reproducción de sus flujos críticos.

## 2. Fases técnicas

### Fase A — Demostrador de dominio

Crear paquetes Dart independientes de Flutter para:

- entidades comerciales;
- Decimal/money;
- tasas y historial;
- caja;
- venta/pago;
- mesa/orden;
- sincronización;
- permisos.

Extraer casos de prueba existentes de Vitest y convertirlos a pruebas Dart sin
cambiar sus expectativas comerciales.

### Fase B — Persistencia local

- Implementar migración SQLite versionada.
- Modelar entidades v5+ con UUID y metadatos de sincronización.
- Crear outbox e historial de errores.
- Implementar recuperación ante cierre inesperado.
- Importar exportaciones JSON existentes como lote validado.

### Fase C — Backend

- Crear proyecto Supabase.
- Aplicar migraciones versionadas.
- Implementar perfiles, roles y RLS.
- Implementar RPC de venta, pago, anulación y cierre.
- Implementar sincronización de catálogo y recibos.

### Fase D — Desktop

- Configurar Flutter Windows.
- Migrar tema, navegación y módulos desde React.
- Integrar SQLite y cola.
- Integrar Supabase cuando haya conexión.
- Conservar impresión como adaptadores hasta disponer de hardware real.

### Fase E — Mobile

- Implementar consulta gerencial.
- Exponer solo información permitida por RLS y permisos.
- Conectarse al backend y a Realtime.

## 3. Migración de datos locales

1. Congelar una exportación JSON de la Beta.
2. Validar esquema, referencias e importes.
3. Generar archivo de migración reproducible.
4. Asignar UUID conservando la clave Beta original como alias.
5. Normalizar montos a enteros/Decimal.
6. Separar datos reales de datos demostrativos.
7. Importar en SQLite sin borrar el original.
8. Simular sincronización y reconciliar conteos/totales.
9. Conservar exportación original fuera del repositorio.

No se ejecutará una limpieza destructiva sin respaldo verificable y autorización.

## 4. Reutilización funcional

| Beta | Decisión Flutter |
|---|---|
| Zustand | Riverpod o Bloc |
| Servicios TS | Casos de uso Dart |
| localStorage | SQLite |
| Plantillas React | Widgets/theme/print adapters |
| Tauri BCV | Adapter HTTP/autenticado |
| Tasa configurada | Servicio de tasa con historial |
| Factura simulada | Módulo separado e inactivo por defecto |
| Perfiles locales | Supabase Auth |
| Auditoría local | Auditoría remota + outbox |

## 5. Pruebas obligatorias

- Monetarios: redondeo, impuestos, tasa y vencimiento.
- Pagos: mixtos, vuelto, duplicidad y sobrepago.
- Venta: stock, recursividad, receta y atomicidad.
- Caja: apertura, cierre, diferencias y movimientos.
- Divisiones: parciales, totales y liberación de mesa.
- Offline: desconexión, cierre inesperado y reconexión.
- Sincronización: reintento, idempotencia y conflicto.
- Permisos: backend y cliente.
- Migración: conteo, integridad y restauración.

## 6. Criterios de salida

- Migración exportar/importar aprobada con datos de prueba.
- Sin pérdida de operaciones offline.
- Sin cobros duplicados.
- Auditoría demostrable.
- Reproducción de los flujos críticos aprobada.
- Sin credenciales comprometidas.
