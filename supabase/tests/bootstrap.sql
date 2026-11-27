-- Bootstrap SOLO para pruebas locales/CI sobre PostgreSQL puro.
-- En Supabase, los esquemas auth/extensions y los roles ya existen.
-- Este archivo NO es una migración: se ejecuta antes de aplicar
-- supabase/migrations/*.sql.

create schema if not exists auth;
create schema if not exists extensions;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end;
$$;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function auth.uid() returns uuid
language plpgsql stable
as $$
declare
  v_sub text;
begin
  begin
    v_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
    if v_sub is not null then
      return v_sub::uuid;
    end if;
  exception when others then
    null;
  end;

  begin
    v_sub := nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub';
    if v_sub is not null then
      return v_sub::uuid;
    end if;
  exception when others then
    null;
  end;

  return null;
end;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;