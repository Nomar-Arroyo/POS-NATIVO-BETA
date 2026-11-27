# Supabase / Backend

El backend está implementado como migraciones PostgreSQL y RPC `SECURITY
DEFINER`; no hay funciones Edge desplegadas ni secretos en este directorio.

```
migrations/
  20261126090000_0001_core_schema.sql
  20261126090100_0002_authz_rls.sql
  20261126090200_0003_commercial_rpc.sql
  20261126090300_0004_customer_sync.sql
seed/demo.sql                 # datos sintéticos idempotentes para desarrollo
tests/bootstrap.sql           # simula auth/esquemas para PostgreSQL local
tests/backend.test.mjs        # 19 pruebas de integración y seguridad
tests/package.json
functions/                    # reservado; el transporte usa RPC, no Edge Functions
```

## Verificación local

Requiere PostgreSQL 14+ y Node 20+.

```bash
psql "$DATABASE_URL" -f tests/bootstrap.sql
psql "$DATABASE_URL" -f migrations/20261126090000_0001_core_schema.sql
psql "$DATABASE_URL" -f migrations/20261126090100_0002_authz_rls.sql
psql "$DATABASE_URL" -f migrations/20261126090200_0003_commercial_rpc.sql
psql "$DATABASE_URL" -f migrations/20261126090300_0004_customer_sync.sql
psql "$DATABASE_URL" -f seed/demo.sql

cd tests && npm ci && DATABASE_URL="$DATABASE_URL" npm test
```

`bootstrap.sql` crea `auth.users` y `auth.uid()`; en Supabase ya existen y **no**
debe aplicarse allí. `seed/demo.sql` inserta usuarios de Auth directos y solo es
para desarrollo.

## Contratos

- [API_CONTRACTS.md](../docs/API_CONTRACTS.md)
- [AUTHORIZATION.md](../docs/AUTHORIZATION.md)
- [DATABASE_SCHEMA.md](../docs/DATABASE_SCHEMA.md)
- [CUSTOMER_TABLETS.md](../docs/CUSTOMER_TABLETS.md)
- [SYNC_PROTOCOL.md](../docs/SYNC_PROTOCOL.md)
- [BACKEND_DEPLOYMENT.md](../docs/BACKEND_DEPLOYMENT.md)

No agregar `service_role` keys, JWT secrets ni contraseñas a este repositorio.