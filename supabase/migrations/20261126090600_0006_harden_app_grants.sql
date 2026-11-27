-- 0006: los helpers de app.* son internos.
-- Los usan las RPC SECURITY DEFINER y las políticas RLS, nunca un cliente.
-- Con EXECUTE por defecto a PUBLIC y USAGE de anon, un cliente anónimo podía
-- invocar app.record_receipt/app.write_audit y forjar sync_operations y
-- auditoría saltándose RLS.

revoke all on all functions in schema app from public;
revoke usage on schema app from anon;

-- Las políticas RLS se evalúan con el rol consultante y necesitan estos
-- helpers; sus grants explícitos de 0002/0005 se conservan.
grant usage on schema app to authenticated;

-- Aplica a funciones futuras creadas por el rol que ejecuta las migraciones.
alter default privileges in schema app revoke execute on functions from public;
