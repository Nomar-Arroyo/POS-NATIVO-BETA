# Riesgos técnicos

| ID | Riesgo | Probabilidad | Impacto | Estado | Mitigación |
|---|---|---|---|---|---|
| RT-01 | Pérdida de datos en migración | Media | Crítico | Abierto | Backup exportado/hash, importación en prueba y restauración comprobada |
| RT-02 | Destruir la Beta o sobrescribir localStorage | Media | Crítico | Mitigado por alcance | Mantener ruta Beta separada y sin restauración destructiva |
| RT-03 | Errores monetarios por float | Alta | Crítico | Abierto | Enteros/Decimal y pruebas exhaustivas |
| RT-04 | Cobro duplicado al sincronizar | Media | Crítico | Abierto | UUID, clave de idempotencia y outbox transaccional |
| RT-05 | Venta local sin stock remoto actualizado | Media | Alto | Abierto | Reservación/transacción remota y reconciliación |
| RT-06 | Conflicto entre dispositivos | Alta | Alto | Abierto | Políticas por entidad y excepciones para operaciones comerciales |
| RT-07 | Eliminación local ante error de sync | Media | Crítico | Abierto | No borrar; estados de error y cola persistente |
| RT-08 | Roles falsamente protegidos solo por UI | Alta | Crítico | Abierto | RLS, RPC y pruebas backend |
| RT-09 | Credenciales comprometidas | Media | Crítico | Abierto | Variables secretas, sin claves privilegiadas en cliente/repositorio |
| RT-10 | Uso del 3% IGTF indebidamente | Media | Crítico | Abierto | Bloquear activación hasta validar normativa y configurar regla |
| RT-11 | Documento fiscal simulado presentado como real | Baja | Crítico | Mitigado | Etiqueta persistente `simulated`, módulo separado y inactivo |
| RT-12 | Hardware no detectado marcado como conectado | Media | Alto | Abierto | Prueba real de detección y diagnóstico por adaptador |
| RT-13 | Datos demo mezclados con datos reales | Media | Crítico | Abierto | Separación explícita, bloqueos de instalación productiva |
| RT-14 | Migración BCV cambia esquema externo | Alta | Medio | Abierto | Adaptador/parser y validación de fecha/rate; conservar última tasa |
| RT-15 | Reintentos sin backoff saturan Supabase | Media | Medio | Abierto | Cola prioritaria, límites, jitter y backoff |
| RT-16 | Exportación/importación JSON maliciosa o corrupta | Media | Alto | Abierto | Validación de esquema, vista previa y transacción |
| RT-17 | Instalación sin respaldo externo | Alta | Alto | Abierto | Exportación fuera del equipo y restauración periódica |
| RT-18 | Cobertura insuficiente de UI/hardware | Alta | Alto | Abierto | Suites UI/E2E y matrices de hardware |
| RT-19 | Dependencia del perfil WebView | Alta | Alto | Abierto | Migrar a SQLite directo en Flutter |
| RT-20 | Inconsistencia React/Flutter | Media | Alto | Abierto | Matriz de trazabilidad y pruebas de contrato compartidas |

## Riesgos residuales del diseño Etapa 1

| ID | Riesgo residual | Consecuencia | Mitigación requerida |
|---|---|---|---|
| E1-R01 | Permiso offline excedido por cambios remotos | Operación puede quedar bloqueada al reconectar | Expirar permisos y ejecutar recepción/reconciliación |
| E1-R02 | Distintos terminales reservan el mismo stock | Venta local posterior se convierte en conflicto | Reservas y reconciliación sin sobrescritura |
| E1-R03 | Snapshot de tasa vencido | Operación conserva dato incorrecto | Capturar vigencia al confirmar y rechazar tasa vencida |
| E1-R04 | RLS incompleto en tablas nuevas | Acceso cruzado entre tenants | Pruebas por organización/rol y seguridad por defecto |
| E1-R05 | Cursor perdido o incompleto | Datos remotos no descargados | Persistir cursor tras página completa y recuperación por cursor |
| E1-R06 | Importación de IDs Beta ambiguos | UUID duplicados o referencias rotas | Vista previa, mapa persistente y rechazo ante ambigüedad |

## Riesgos bloqueantes

- RT-03: precisión monetaria.
- RT-04: idempotencia.
- RT-08: autorización backend.
- RT-10: IGTF normativo.
- RT-11: fiscalidad real.
- RT-12: hardware real.

No iniciar emisión fiscal ni operar contra datos reales hasta cerrar los riesgos
marcados como críticos y bloqueantes.
