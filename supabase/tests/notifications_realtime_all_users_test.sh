#!/usr/bin/env bash
# WYNOS Web — public notification Realtime release migration regression.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wynos_notifications_realtime_release_$$"
cleanup() { dropdb --if-exists "$DB" >/dev/null 2>&1 || true; }
trap cleanup EXIT

for executable in psql createdb dropdb; do command -v "$executable" >/dev/null; done

createdb "$DB"

psql -X -d "$DB" -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
create extension if not exists pgcrypto;
create table public.notifications (
  id uuid primary key default gen_random_uuid()
);
create publication supabase_realtime;
SQL

for _ in 1 2; do
  psql -X -d "$DB" -v ON_ERROR_STOP=1     -f "$ROOT/supabase/migrations/20260930014500_notifications_realtime_all_users.sql" >/dev/null
done

count="$(
  psql -X -d "$DB" -At -v ON_ERROR_STOP=1 -c "
    select count(*)
    from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='notifications';
  "
)"

test "$count" = "1"
echo "NOTIFICATIONS REALTIME PUBLIC RELEASE CHECKS PASSED"
