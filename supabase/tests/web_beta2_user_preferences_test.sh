#!/usr/bin/env bash
# Web Beta2 WYN-188/189: public.user_preferences is owner-only and validated.
# Disposable PostgreSQL only. CI runs every maintained supabase/tests/*.sh file.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_user_prefs_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

cat >"$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create schema if not exists internal;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid
language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $$;
grant usage on schema public, auth to anon, authenticated, service_role;
insert into auth.users(id,email) values
 ('97000000-0000-0000-0000-000000000001','alice@example.invalid'),
 ('97000000-0000-0000-0000-000000000002','bob@example.invalid');
SQL

cat >"$WORK/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
-- Alice saves her own preferences.
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000001';
set role authenticated;
insert into public.user_preferences(user_id, theme_preference) values ('97000000-0000-0000-0000-000000000001','dark');
insert into public.user_preferences(user_id, language_preference) values ('97000000-0000-0000-0000-000000000001','en')
  on conflict (user_id) do update set language_preference = excluded.language_preference;
reset role;
do $$ begin
  if (select theme_preference || '/' || language_preference from public.user_preferences
      where user_id='97000000-0000-0000-0000-000000000001') <> 'dark/en' then
    raise exception 'Owner upsert did not persist both preferences';
  end if;
end $$;

-- Bob can neither read, write nor change Alice's row.
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000002';
set role authenticated;
do $$ begin
  if (select count(*) from public.user_preferences) <> 0 then
    raise exception 'Another user can read preferences';
  end if;
end $$;
update public.user_preferences set theme_preference='light' where user_id='97000000-0000-0000-0000-000000000001';
do $$ begin
  begin
    insert into public.user_preferences(user_id, theme_preference) values ('97000000-0000-0000-0000-000000000001','light');
    raise exception 'Cross-user insert was allowed';
  exception when insufficient_privilege or unique_violation then null;
  end;
end $$;
reset role;
do $$ begin
  if (select theme_preference from public.user_preferences where user_id='97000000-0000-0000-0000-000000000001') <> 'dark' then
    raise exception 'Another user changed the preference';
  end if;
end $$;

-- Anonymous callers get nothing.
set role anon;
do $$ begin
  begin
    perform 1 from public.user_preferences;
    raise exception 'anon can read user_preferences';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Only known values are accepted; NULL means "not chosen".
set request.jwt.claim.sub='97000000-0000-0000-0000-000000000002';
set role authenticated;
insert into public.user_preferences(user_id) values ('97000000-0000-0000-0000-000000000002');
do $$ begin
  begin
    update public.user_preferences set theme_preference='sepia' where user_id='97000000-0000-0000-0000-000000000002';
    raise exception 'Invalid theme accepted';
  exception when check_violation then null;
  end;
  begin
    update public.user_preferences set language_preference='fr' where user_id='97000000-0000-0000-0000-000000000002';
    raise exception 'Invalid language accepted';
  exception when check_violation then null;
  end;
end $$;
reset role;

-- updated_at moves on update; deleting the user removes the row.
update public.user_preferences set updated_at = now() - interval '1 day' where user_id='97000000-0000-0000-0000-000000000001';
update public.user_preferences set theme_preference='system' where user_id='97000000-0000-0000-0000-000000000001';
do $$ begin
  if (select updated_at from public.user_preferences where user_id='97000000-0000-0000-0000-000000000001') < now() - interval '1 hour' then
    raise exception 'updated_at was not touched';
  end if;
end $$;
delete from auth.users where id='97000000-0000-0000-0000-000000000001';
do $$ begin
  if exists(select 1 from public.user_preferences where user_id='97000000-0000-0000-0000-000000000001') then
    raise exception 'Preferences outlived the account';
  end if;
end $$;
SQL

createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/stub.sql" >/dev/null
# Apply twice to prove the migration is idempotent.
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations_web_beta2_user_preferences.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations_web_beta2_user_preferences.sql" >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$WORK/assert.sql" >/dev/null
echo "web_beta2_user_preferences_test: PASS"
