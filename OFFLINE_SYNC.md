# Arquitectura Offline/Sync

## Estados

Toda entidad sincronizable expone `LOCAL`, `PENDING`, `SYNCED` o `ERROR`.

- **LOCAL:** creada localmente y sin intención de envío.
- **PENDING:** confirmada localmente y pendiente de outbox.
- **SYNCED:** recibo remoto verificable y confirmado.
- **ERROR:** solicitud remota rechazada o fallida; conserva el original.

## Outbox transaccional

SQLite confirma en una transacción:

1. configuración inicial y alta de catálogo local, cuando corresponda;
2. venta, movimientos de inventario y efectivo;
3. reservas y cambios de salón/comandas;
4. pagos y cierre de sesión de mesa;
5. apertura/cierre y movimientos manuales de caja;
6. auditoría local;
7. registro outbox de cada operación.

Si falla cualquier paso, rollback completo.

La app de escritorio aún no configura un transporte remoto. Estas operaciones
permanecen pendientes localmente y no se marcan como sincronizadas.

El catálogo sintético no crea eventos de catálogo en la outbox. En la base de
operación real, sus productos no se pueden vender ni agregar a comandas. El
modo demo usa una base SQLite `:memory:` separada: allí se permiten ventas y
comandas simuladas, pero la base y su outbox no se comparten con el entorno real
ni se conectan a un transporte remoto. Al salir del modo demo, la base temporal
se descarta.

Las pantallas locales de cocina/barra se habilitan por estación. Si una estación
se deshabilita en Configuración, las comandas ya persistidas se envían en orden
al diálogo de impresión del sistema; cancelar o fallar una impresión no revierte
ni elimina la comanda. El destino remoto entre terminales requiere backend y
sincronización, aún pausados.

## Inbox y idempotencia

Toda operación tiene UUID e `idempotency_key`. El servidor busca el recibo antes
de validar y aplicar efectos. Si existe, devuelve el resultado previo.

Dos ventas con los mismos productos e importes no son duplicados: difieren por
UUID, terminal, usuario y clave. El único duplicado es la misma operación repetida
con la misma clave.

## Reintentos

- Backoff exponencial.
- Jitter aleatorio acotado.
- Máximo configurable de intentos.
- `next_attempt_at` persistido.
- Errores permanentes no reintentan sin intervención o corrección.
- Reanudar después de reinicio sin depender de memoria.

## Cursores

El servidor entrega cambios paginados usando `(updated_at, id)`. El cliente
completa una página transaccionalmente antes de persistir el cursor. Realtime
puede anticipar una descarga, pero no reemplaza el cursor.

## Conflictos

- ventas y movimientos nunca se sobrescriben;
- catálogo usa versión para resolver cambios;
- caja cerrada, terminal revocado y stock insuficiente generan conflicto;
- el conflicto queda visible con recibo, payload y diferencia;
- resolución solo mediante operación compensatoria autorizada.

## Reconexión

1. Confirmar sesión y permisos.
2. Subir operaciones outbox en orden transaccional.
3. Guardar recibos.
4. Descargar cambios y avanzar cursores.
5. Ejecutar reconciliación de inventario y caja.
6. Exponer estados sin afirmar sincronización para ventas solo locales.

## Implementación inicial SQLite

`packages/data_local` implementa la persistencia local y el outbox básico:

- una venta confirmada crea su outbox en la misma transacción;
- el estado inicial es `PENDING`;
- `markSynced` crea un recibo y cambia la venta a `SYNCED`;
- errores conservan la operación y crean registros `sync_errors`;
- cursores se persisten por terminal y stream;
- llaves idempotentes impiden repetir una operación confirmada;
- ventas distintas conservan IDs y claves distintas aunque tengan igual total.

## Entregable D — Motor de sincronización

`packages/core_sync` implementa el contrato independiente de UI y transporte:

- `SyncEngine` orquesta outbox y recibos;
- `SyncTransport` abstrae HTTP/RPC/Realtime;
- `SyncInbox` conserva el primer recibo por llave idempotente;
- `RetryPolicy` aplica backoff exponencial y jitter acotado;
- `CursorStore` conserva cursores por stream;
- `SyncConflict` registra conflictos comerciales sin sobrescribir ventas;
- `SyncStatus.conflict` separa conflictos de errores temporales;
- operaciones distintas no se deduplican por payload equivalente.

Cada reintento persiste su número; el límite configurable impide loops infinitos.
Los errores permanentes tienen `retryable = false`. Realtime solo puede activar
descargas; la recuperación normal depende de outbox, transportes e inbox.
