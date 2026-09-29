#!/usr/bin/env bash
# WYNOS Web Beta1 — twice-daily follow-suggestion migration regression.
# Disposable PostgreSQL only. CI runs every maintained supabase/tests/*.sh file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_follow_suggestions_twice_daily_$$"
WORK="$(mktemp -d)"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

cat >"$WORK/stub.sql" <<'SQL'
do $$
begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then
    create role authenticated nologin;
  end if;
  if not exists(select 1 from pg_roles where rolname='anon') then
    create role anon nologin;
  end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then
    create role service_role nologin;
  end if;
end
$$;

create table public.daily_follow_suggestion_deliveries (
  id uuid primary key,
  user_id uuid not null,
  local_date date not null,
  profile_ids uuid[] not null,
  status text not null default 'claimed',
  lease_until timestamptz,
  sent_at timestamptz,
  opened_at timestamptz,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_follow_suggestion_profile_count
    check (cardinality(profile_ids) between 3 and 5),
  constraint daily_follow_suggestion_user_day_unique
    unique (user_id, local_date)
);
SQL

cat >"$WORK/assert.sql" <<'SQL'
do $$
declare
  v_definition text;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='daily_follow_suggestion_deliveries'
      and column_name='delivery_slot'
      and is_nullable='NO'
  ) then
    raise exception 'delivery_slot must exist and be NOT NULL';
  end if;

  if exists (
    select 1 from pg_constraint
    where conrelid='public.daily_follow_suggestion_deliveries'::regclass
      and conname='daily_follow_suggestion_user_day_unique'
  ) then
    raise exception 'old one-delivery-per-day unique constraint still exists';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.daily_follow_suggestion_deliveries'::regclass
      and conname='daily_follow_suggestion_user_day_slot_unique'
      and pg_get_constraintdef(oid) ilike '%UNIQUE (user_id, local_date, delivery_slot)%'
  ) then
    raise exception 'user/day/slot unique constraint missing';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.daily_follow_suggestion_deliveries'::regclass
      and conname='daily_follow_suggestion_delivery_slot_check'
      and pg_get_constraintdef(oid) ilike '%morning%'
      and pg_get_constraintdef(oid) ilike '%evening%'
  ) then
    raise exception 'delivery slot check constraint missing';
  end if;

  v_definition := pg_get_functiondef(
    'public.claim_daily_follow_suggestions(integer)'::regprocedure
  );

  if position('10:00' in v_definition) = 0
     or position('13:00' in v_definition) = 0
     or position('19:00' in v_definition) = 0
     or position('22:00' in v_definition) = 0 then
    raise exception 'morning/evening local-time windows missing from claim function';
  end if;

  if position('6 hours' in v_definition) = 0 then
    raise exception 'six-hour delivery spacing guard missing';
  end if;

  if position('d.delivery_slot = v_user.delivery_slot' in v_definition) = 0 then
    raise exception 'claim retry is not scoped to delivery slot';
  end if;

  if has_function_privilege('authenticated', 'public.claim_daily_follow_suggestions(integer)', 'EXECUTE')
     or has_function_privilege('anon', 'public.claim_daily_follow_suggestions(integer)', 'EXECUTE') then
    raise exception 'claim function became client-executable';
  end if;

  if not has_function_privilege('service_role', 'public.claim_daily_follow_suggestions(integer)', 'EXECUTE') then
    raise exception 'service_role lost claim permission';
  end if;
end
$$;

insert into public.daily_follow_suggestion_deliveries (
  id, user_id, local_date, delivery_slot, profile_ids, status
) values
  ('98000000-0000-0000-0000-000000000001',
   '98000000-0000-0000-0000-000000000010',
   date '2026-09-30',
   'morning',
   array[
     '98000000-0000-0000-0000-000000000101'::uuid,
     '98000000-0000-0000-0000-000000000102'::uuid,
     '98000000-0000-0000-0000-000000000103'::uuid
   ],
   'sent'),
  ('98000000-0000-0000-0000-000000000002',
   '98000000-0000-0000-0000-000000000010',
   date '2026-09-30',
   'evening',
   array[
     '98000000-0000-0000-0000-000000000104'::uuid,
     '98000000-0000-0000-0000-000000000105'::uuid,
     '98000000-0000-0000-0000-000000000106'::uuid
   ],
   'sent');

do $$
begin
  begin
    insert into public.daily_follow_suggestion_deliveries (
      id, user_id, local_date, delivery_slot, profile_ids
    ) values (
      '98000000-0000-0000-0000-000000000003',
      '98000000-0000-0000-0000-000000000010',
      date '2026-09-30',
      'morning',
      array[
        '98000000-0000-0000-0000-000000000107'::uuid,
        '98000000-0000-0000-0000-000000000108'::uuid,
        '98000000-0000-0000-0000-000000000109'::uuid
      ]
    );
    raise exception 'duplicate morning slot unexpectedly succeeded';
  exception when unique_violation then
    null;
  end;

  begin
    insert into public.daily_follow_suggestion_deliveries (
      id, user_id, local_date, delivery_slot, profile_ids
    ) values (
      '98000000-0000-0000-0000-000000000004',
      '98000000-0000-0000-0000-000000000010',
      date '2026-10-01',
      'night',
      array[
        '98000000-0000-0000-0000-000000000107'::uuid,
        '98000000-0000-0000-0000-000000000108'::uuid,
        '98000000-0000-0000-0000-000000000109'::uuid
      ]
    );
    raise exception 'invalid delivery slot unexpectedly succeeded';
  exception when check_violation then
    null;
  end;
end
$$;

\echo TWICE-DAILY FOLLOW SUGGESTION MIGRATION CHECKS PASSED
SQL

createdb "$DB"
psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/stub.sql" >/dev/null

# Apply twice to prove the migration is idempotent.
for _ in 1 2; do
  psql -X -d "$DB" -v ON_ERROR_STOP=1     -f "$ROOT/supabase/migrations/20260929201547_daily_follow_suggestions_twice_daily.sql" >/dev/null
done

psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$WORK/assert.sql"
