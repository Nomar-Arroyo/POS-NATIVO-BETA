# Plan de trabajo compartido

Documento de coordinación para backend y frontend de Café Amalfi POS. Es la
fuente común de tareas, dependencias y criterios de aceptación. Se actualiza
en el mismo PR que cambia el estado de una tarea.

- Fecha de apertura: 26 de noviembre de 2026.
- Documentos de contexto: [Arquitectura objetivo](../ARQUITECTURA_OBJETIVO.md),
  [Roadmap](../ROADMAP.md), [Seguridad](../SECURITY.md) y
  [documentación de referencia](reference/).

## 1. Cómo usar este documento

1. Cada tarea tiene un ID estable (`E-01`, `K-01`, `B-01`, `M-01`, `Q-01`).
   Las ramas y PR usan ese ID: `feat/E-02-fail-closed`.
2. Una tarea solo pasa a "Hecho" cuando cumple todos sus criterios de
   aceptación y el CI está verde sobre el commit.
3. Los cambios de contrato (`docs/SYNC_PROTOCOL.md`, `docs/API_CONTRACTS.md`,
   `docs/AUTHORIZATION.md`, `docs/CUSTOMER_TABLETS.md`) requieren aprobación de
   ambos responsables antes de mezclarse.
4. No se mueven carpetas ni se renombran paquetes sin actualizar imports,
   workspaces y CI en el mismo PR.
5. Las migraciones aplicadas son inmutables; toda corrección es una migración
   nueva y secuencial.
6. La Beta (`apps/beta`) no se modifica salvo corrección crítica acordada; su
   persistencia no se mezcla con la de Flutter.

Leyenda de estado: `Hecho`, `En curso`, `Pendiente`, `Bloqueado`.

## 2. Estado de partida verificado

Verificado el 26 de noviembre de 2026 ejecutando analyze y pruebas locales.

| Componente | Estado | Evidencia |
| --- | --- | --- |
| `core_money` | Implementado | analyze limpio, 12 pruebas |
| `core_sync` | Modelado, sin transporte | analyze limpio, 9 pruebas |
| `data_local` | Implementado | analyze limpio, 15 pruebas |
| `data_migration` | Implementado | analyze limpio, 6 pruebas |
| `amalfi_brand_assets` | Implementado | analyze limpio, 1 prueba |
| `apps/desktop` | Funcional en desarrollo | analyze limpio, 8 pruebas |
| `apps/mobile` | Scaffold | analyze limpio, 1 prueba |
| CI | Paquetes, Desktop, Mobile y backend | `.github/workflows/ci.yml` (backend pendiente de primera ejecución en GitHub) |
| Backend | Implementado y probado localmente | 4 migraciones, 19 pruebas en PostgreSQL 19; no desplegado a Supabase |

Separación que debe mantenerse en la comunicación del proyecto:

- **Implementado:** paquetes locales, backend PostgreSQL/RLS/RPC, tablets de
  cliente y descarga incremental, con pruebas de integración.
- **Diseñado:** transporte remoto del POS, Realtime y flujos móviles.
- **No existe todavía:** despliegue Supabase real, transporte de sincronización
  en Desktop y aplicación móvil funcional.

## 3. Hallazgos que originan las tareas P0

| ID | Hallazgo | Ubicación |
| --- | --- | --- |
| E-02 | `requireCurrentPermission()` permite operar sin workspace y sin sesión; además desactiva las validaciones de identidad de `confirmSale` cuando el workspace es nulo | `packages/data_local/lib/src/local_database.dart` |
| E-03 | El esquema de sesiones no tiene expiración ni revocación | `packages/data_local/lib/src/migrations.dart` |
| E-04 | El payload de outbox de venta solo lleva la cabecera | `packages/data_local/lib/src/local_database.dart` |
| E-05 | El motor acepta cualquier recibo con `receipt != null` | `packages/core_sync/lib/src/sync_engine.dart` |
| E-06 | Estado del motor de sync en memoria; sin persistencia inyectada | `packages/core_sync/lib/src/sync_engine.dart` |

## 4. Reparto de responsabilidad

| Rol | Foco |
| --- | --- |
| Tú (frontend móvil) | `apps/mobile`, presentación, sesión de UI, aislación de modos, pruebas de widget |
| Compañero (backend/DB) | `supabase/`, Auth, RLS, RPC, pairing, transporte |
| Ambos | Contratos de datos, permisos, estados de pedido y criterios de aceptación |

Regla de oro: una tablet de cliente jamás obtiene capacidades administrativas
por cambiar una opción en Flutter. La frontera la impone el backend mediante
identidad de dispositivo, vinculación y permisos efectivos.

## 5. Fases e hitos

| Hito | Contenido | Criterio de salida |
| --- | --- | --- |
| M0 · Estabilización | E-01 a E-08 | Toda operación protegida deniega sin sesión válida; contrato de venta aprobado; recibos verificados; CI de Dart/Flutter verde |
| M1 · Backend base | B-01 a B-04 | Auth, roles, RLS y aislamiento multi-organización probados en servidor |
| M2 · Integración POS | B-05, B-06, E-04, E-06 | Una venta offline llega al servidor de forma atómica, sin duplicados ni pérdidas |
| M3 · Tablets cliente | B-07 a B-09, K-02, K-03 | Un pedido de tablet llega a cocina/barra una sola vez, con precio validado por servidor |
| M4 · Móvil | M-01 a M-09 | Modos gerencial y cliente aislados y probados; pairing revocable |
| M5 · Producción | Q-01 a Q-06 | Backup/restore probado, hardware validado y checklist de despliegue |

## 6. Tareas

### 6.1 Estabilización local (M0)

| ID | Tarea | Responsable | Depende de | Criterios de aceptación | Estado |
| --- | --- | --- | --- | --- | --- |
| E-01 | Matriz de CI para paquetes Dart, Desktop y Mobile | Ambos | — | Workflow corre en PR y push; analyze, tests y builds de la matriz en verde | Hecho |
| E-02 | Fail-closed en autorización local | Ambos | E-03 | Sin workspace, sin sesión, sesión finalizada, perfil inactivo o permiso ausente → `StateError`; identidad de venta validada siempre | Pendiente |
| E-03 | Migración v6: expiración y revocación de sesiones | Compañero | — | `expires_at` y `revoked_at` en sesiones; login fija expiración; migración probada sobre v5 | Pendiente |
| E-04 | Contrato versionado de outbox de venta | Ambos | K-01 | Payload incluye cabecera, líneas, pagos, snapshots de tasa, inventario, caja, mesa, usuario, terminal e idempotency key | Pendiente |
| E-05 | Validación estricta de recibos en `SyncEngine` | Ambos | E-04 | Solo pasa a `SYNCED` si `accepted == true` y coinciden `operationId`, `entity` e `idempotencyKey` | Pendiente |
| E-06 | Persistencia del motor de sincronización | Ambos | E-05 | Estados, recibos, cursores, reintentos y conflictos sobreviven al reinicio | Pendiente |
| E-07 | Pruebas negativas de autorización | Ambos | E-02 | Un test por caso de denegación: sin workspace, sin sesión, expirada, revocada, perfil inactivo, permiso ausente | Pendiente |
| E-08 | Separar SQL de la UI y preparar capas | Ambos | — | Ningún widget ejecuta SQL; `audit_screen` usa método del paquete; propuesta `domain`/`application` aprobada | Pendiente |

Notas de ejecución de E-02/E-03: cambiar el contrato de autorización exige
actualizar el setup de las 15 pruebas de `data_local` (hoy operan sin sesión) y
las aserciones de conteo de auditoría. Debe hacerse en un PR único con E-07.

### 6.2 Contratos compartidos (M0–M3)

| ID | Contrato | Responsable | Depende de | Criterios de aceptación | Estado |
| --- | --- | --- | --- | --- | --- |
| K-01 | `confirm_sale` v1 | Ambos | — | Documento firmado en `docs/SYNC_PROTOCOL.md` y `docs/API_CONTRACTS.md` con todos los campos y `schema_version` | Hecho |
| K-02 | Pedido de cliente v1 | Ambos | K-01 | Contrato de envío, estados y errores idempotentes documentado | Hecho |
| K-03 | Pairing y sesión de dispositivo v1 | Ambos | — | Contrato de código de un solo uso, expiración, vinculación a mesa, revocación y capacidades mínimas | Hecho |
| K-04 | Recepción y cursores v1 | Ambos | K-01 | Formato de recibo, correlación y cursores incrementales documentado | Hecho |
| K-05 | Reglas monetarias y fiscales | Ambos | — | Política de redondeo única, snapshots por venta/pago, regla de vuelto; IGTF sujeto a revisión legal | Pendiente |

Los contratos se aprueban antes de escribir RPC o UI que dependa de ellos.

### 6.3 Backend (M1–M3)

| ID | Tarea | Responsable | Depende de | Criterios de aceptación | Estado |
| --- | --- | --- | --- | --- | --- |
| B-01 | Esquema PostgreSQL y migraciones | Compañero | K-01 | Migraciones secuenciales inmutables; FKs, índices, timestamps y UUID; CI de migraciones | Hecho |
| B-02 | Auth, perfiles, roles y permisos | Compañero | B-01 | `profiles.id` = `auth.users.id`; roles efectivos resueltos en servidor | Hecho |
| B-03 | RLS por organización y sucursal | Compañero | B-02 | Pruebas por rol, organización cruzada, sucursal cruzada y usuario anónimo | Hecho |
| B-04 | RPC de venta, caja e inventario | Compañero | B-01, K-01 | Aplicación atómica; idempotencia por clave; recibo correlacionado | Hecho |
| B-05 | RPC de mesas y comandas | Compañero | B-04 | Estados de sesión y comanda; rollback ante fallo | Hecho |
| B-06 | Transporte de sincronización | Compañero | B-04, K-04 | La outbox se procesa con reintentos; duplicados rechazados; cursores incrementales | En curso (backend listo; transporte Desktop pendiente) |
| B-07 | Dispositivos, pairing y sesiones | Compañero | B-02, K-03 | Código de un solo uso, expiración breve, revocación, credencial de alcance mínimo | Hecho |
| B-08 | Pedidos de cliente | Compañero | B-07, K-02 | Pedido creado atómicamente; precio y disponibilidad validados en servidor; enrutamiento a cocina/barra | Hecho |
| B-09 | Realtime y notificaciones | Compañero | B-08 | Estado de pedido observable por tablet sin acceso a datos administrativos | Pendiente (se usa sondeo por RPC) |
| B-10 | CI de backend | Compañero | B-01 | Migraciones, RPC y RLS ejecutadas en CI con base efímera | Hecho (19/19 pruebas PostgreSQL pasan en GitHub Actions) |

### 6.4 Aplicación móvil (M4)

| ID | Tarea | Responsable | Depende de | Criterios de aceptación | Estado |
| --- | --- | --- | --- | --- | --- |
| M-01 | Estructura, rutas y tema | Tú | — | Estructura de `docs/MOBILE_APP.md`; tema claro/oscuro/sistema con marca Amalfi | Pendiente |
| M-02 | Sesión y seguridad de presentación | Tú | K-03 | Estados de sesión visibles; expiración manejada; sin selector libre de rol | Pendiente |
| M-03 | Modo gerencial | Tú | M-01, B-04 | Dashboard, ventas, inventario, auditoría y reportes con mocks aislados tipados | Pendiente |
| M-04 | Pairing de tablet | Tú | K-03 | Código de un solo uso; errores de expiración y revocación manejados | Pendiente |
| M-05 | Menú y detalle de producto | Tú | K-02 | Categorías, variantes y modificadores desde contrato; sin precios inventados | Pendiente |
| M-06 | Carrito y confirmación | Tú | M-05, K-02 | Total orientativo; envío idempotente; doble toque no duplica pedido | Pendiente |
| M-07 | Seguimiento de pedido | Tú | M-06, B-09 | Estados recibido, preparación, listo, entregado y cancelado | Pendiente |
| M-08 | Aislación de modos | Tú | M-02, M-04 | Tests demuestran que el modo cliente no accede a rutas ni datos administrativos | Pendiente |
| M-09 | Compatibilidad SQLite en Android/iOS | Tú | M-03 | Driver nativo validado en ambas plataformas; no se asume la configuración Windows | Pendiente |

El frontend puede avanzar con mocks aislados sobre los contratos, pero no debe
inventar endpoints ni asumir que el backend está listo.

### 6.5 Integración, calidad y operación (M4–M5)

| ID | Tarea | Responsable | Depende de | Criterios de aceptación | Estado |
| --- | --- | --- | --- | --- | --- |
| Q-01 | E2E tablet → cocina/barra → cobro en Desktop | Ambos | M-07, B-05 | Un pedido llega una sola vez y se cobra desde Desktop sin duplicar la venta | Pendiente |
| Q-02 | Backup y restauración locales | Compañero | E-03 | Restore probado con outbox pendiente y sin pérdida de recibos | Pendiente |
| Q-03 | Cifrado local y secretos del terminal | Compañero | Q-02 | Decisión documentada; DB y backups protegidos; secretos fuera de Flutter | Pendiente |
| Q-04 | Hardware real | Ambos | Q-01 | Impresora ESC/POS, cajón y lector validados mediante adaptadores | Pendiente |
| Q-05 | Pruebas de rendimiento y concurrencia | Ambos | M2 | Mesas simultáneas y reintentos sin bloqueos ni duplicados | Pendiente |
| Q-06 | Checklist de despliegue y piloto | Ambos | Q-02, Q-04 | Checklist firmado; piloto con datos reales controlado | Pendiente |

## 7. CI y verificación

Workflow activo: `.github/workflows/ci.yml`.

| Proyecto | Validación en CI |
| --- | --- |
| `core_money` | analyze y tests |
| `core_sync` | analyze y tests |
| `data_local` | analyze y tests (SQLite en Ubuntu) |
| `data_migration` | analyze y tests (SQLite en Ubuntu) |
| `amalfi_brand_assets` | analyze y tests |
| `desktop` | analyze, tests y build Windows |
| `mobile` | analyze, tests, build Android y build iOS sin firma |
| Backend | job `backend`: PostgreSQL 16, bootstrap, migraciones, seed y `npm test` |

Reglas:

- Un PR no se mezcla con el CI en rojo.
- `build-windows.yml` sigue siendo el empaquetado de la Beta y no sustituye
  esta matriz.
- No se declaran pruebas "aprobadas" sin un enlace al run que las ejecutó.
- SQLite en Android/iOS no se da por compatible por analogía con Windows
  (tarea M-09).

## 8. Definition of Ready / Done

Una tarea está **lista** si: tiene criterio de aceptación verificable, contrato
aprobado si lo requiere, y no tiene dependencias abiertas.

Una tarea está **hecha** si: cumple criterios, tiene pruebas automatizadas
cuando aplique, CI verde en el commit, documentación actualizada y sin cambios
de alcance escondidos en el PR.

## 9. Decisiones abiertas (requieren acuerdo)

| Tema | Pregunta | Responsable | Relacionado |
| --- | --- | --- | --- |
| Inventario | ¿La reserva ocurre al enviar, al aceptar o al iniciar preparación? Expiración y liberación | Ambos | K-02, B-08 |
| Vuelto | Reglas de vuelto en pagos mixtos y moneda | Ambos | K-05 |
| IGTF / impuestos | Habilitación sujeta a revisión legal | Compañero | K-05 |
| Offline gerencial | ¿Qué operaciones permite el modo gerencial sin red? | Ambos | M-02 |
| Sesión local | Duración de sesión de terminal y de tablet | Ambos | E-03, K-03 |
| Cursores | Estrategia incremental por entidad y retención | Compañero | K-04 |
| Capas | Crear `domain`, `application` y `data_remote` según auditoría | Ambos | E-08 |

## 10. Riesgos y mitigación

| Riesgo | Mitigación |
| --- | --- |
| Construir UI sobre endpoints no acordados | K-01 a K-05 antes de M-03/M-05 |
| Autorización permisiva que permite operar sin sesión | E-02, E-03, E-07 |
| Payload incompleto que impide conciliar ventas | E-04, K-01 |
| Confiar en precios o totales enviados por la tablet | B-08: servidor calcula y valida |
| Tablet cliente mal vinculada con acceso a otras mesas | K-03, B-03, B-07 |
| Declarar pruebas aprobadas sin ejecutarlas | CI obligatorio y enlace al run |
| Pérdida o robo del equipo con datos expuestos | Q-02, Q-03 |

## 11. Bitácora

- **2026-11-26** · Se crea este plan. Baseline verificado localmente: analyze
  limpio en los cinco paquetes y en Desktop/Mobile; 43 pruebas de paquetes,
  8 de Desktop y 1 de Mobile en verde. Se añade `.github/workflows/ci.yml`
  (pendiente de su primera ejecución en GitHub). Se mantienen como P0 las
  correcciones de autorización local, contrato de outbox y validación de
  recibos.
- **2026-11-26** · Backend implementado: migraciones 0001–0004 (esquema, RLS,
  RPC comerciales, tablets y descarga), `seed/demo.sql` idempotente y 19 pruebas
  de integración en PostgreSQL 19 en verde. Se documentan contratos, seguridad,
  tablets, sincronización y despliegue. B-01 a B-05, B-07, B-08, K-01 a K-04
  quedan Hechos; B-06 en curso (transporte Desktop); B-09 pendiente. No se
  desplegó a Supabase ni se conectó el outbox de Desktop.
- **2026-11-27** · El job backend de GitHub Actions aplicó bootstrap, las cuatro
  migraciones y seed en PostgreSQL 16; las 19 pruebas pasaron. El workflow
  Flutter falló en Analyze porque `stable` avanzó a 3.50.1, que depreca
  `package:flutter/material.dart`; se fija Flutter 3.47.7 para reproducir la
  versión validada localmente. La matriz completa queda pendiente de una nueva
  ejecución del workflow.
