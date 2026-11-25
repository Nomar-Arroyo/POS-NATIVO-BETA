# core_sync

Motor independiente de sincronización Outbox/Inbox para Caffè Amalfi POS.

## Responsabilidades

- estados de sincronización;
- backoff exponencial con jitter;
- límites de reintento;
- inbox idempotente;
- recibos remotos;
- cursores de cambios;
- conflictos comerciales revisables;
- separación de errores temporales y permanentes;
- operaciones distintas no se confunden por payload equivalente.

Realtime no forma parte del contrato base y solo puede activar una descarga.
