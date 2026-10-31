#!/usr/bin/env bash
# Behaviour test for 20261031120000_zoky_line_links.sql (ZOKY-LINE-001) on a
# throwaway local PostgreSQL database with a minimal auth stub. Proves:
#   * signed-in users read/delete only their own links;
#   * clients can never insert or retarget a link (no insert/update grant);
#   * anon has no access; line_user_id is never exposed to clients;
#   * one LINE account per OA, format/audience checks;
#   * the migration is re-runnable.
#
# Usage: PSQL="sudo -u postgres psql" supabase/tests/zoky_line_links_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="zoky_line_links_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run >/dev/null <<'SQL'
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth, public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b');
SQL

run -f "$ROOT/supabase/migrations/20261031120000_zoky_line_links.sql" >/dev/null
run -f "$ROOT/supabase/migrations/20261031120000_zoky_line_links.sql" >/dev/null

UA="U$(printf 'a%.0s' {1..32})"
UB="U$(printf 'b%.0s' {1..32})"
run >/dev/null <<SQL
insert into public.line_links(user_id, audience, line_user_id) values
  ('00000000-0000-0000-0000-00000000000a', 'food', '$UA'),
  ('00000000-0000-0000-0000-00000000000a', 'merchant', '$UA'),
  ('00000000-0000-0000-0000-00000000000b', 'food', '$UB');
SQL

fail=0
check() {
  local name="$1" sql="$2" expected="$3" actual
  actual=$(run -tA -c "$sql" 2>&1 || true)
  if [ "$actual" = "$expected" ]; then echo "PASS $name"; else echo "FAIL $name: expected [$expected] got [$actual]"; fail=1; fi
}
as_user() { echo "set role authenticated; set request.jwt.claim.sub = '$1'; $2"; }
A=00000000-0000-0000-0000-00000000000a
B=00000000-0000-0000-0000-00000000000b

check "user sees only own links" "$(as_user $A "select count(*) from public.line_links")" "2"
check "other user's link invisible" "$(as_user $B "select string_agg(audience, ',') from public.line_links")" "food"
check "line_user_id not readable by clients" \
  "$(as_user $A "do \$\$ begin perform line_user_id from public.line_links; raise exception 'readable'; exception when insufficient_privilege then null; end \$\$; select 'denied'")" "denied"
check "client insert denied" \
  "$(as_user $B "do \$\$ begin insert into public.line_links(user_id,audience,line_user_id) values ('$B','merchant','$UB'); raise exception 'inserted'; exception when insufficient_privilege then null; end \$\$; select 'denied'")" "denied"
check "client update denied" \
  "$(as_user $B "do \$\$ begin update public.line_links set friend_status='friend'; raise exception 'updated'; exception when insufficient_privilege then null; end \$\$; select 'denied'")" "denied"
check "cannot delete another user's link" \
  "$(as_user $B "delete from public.line_links where audience='merchant'; select count(*) from public.line_links where audience='merchant'")" "0"
check "A's merchant link survives B's delete" "select count(*) from public.line_links where user_id='$A' and audience='merchant'" "1"
check "own delete works" "$(as_user $A "delete from public.line_links where audience='food'; select count(*) from public.line_links")" "1"
check "anon denied" \
  "set role anon; do \$\$ begin perform 1 from public.line_links; raise exception 'readable'; exception when insufficient_privilege then null; end \$\$; select 'denied'" "denied"
check "one LINE account per OA" \
  "do \$\$ begin insert into public.line_links(user_id,audience,line_user_id) values ('$A','food','$UB'); raise exception 'accepted'; exception when unique_violation then null; end \$\$; select 'rejected'" "rejected"
check "malformed LINE userId rejected" \
  "do \$\$ begin insert into public.line_links(user_id,audience,line_user_id) values ('$B','merchant','not-a-line-id'); raise exception 'accepted'; exception when check_violation then null; end \$\$; select 'rejected'" "rejected"
check "unknown audience rejected" \
  "do \$\$ begin insert into public.line_links(user_id,audience,line_user_id) values ('$B','social','$UB'); raise exception 'accepted'; exception when check_violation then null; end \$\$; select 'rejected'" "rejected"
check "deleting the account removes its links" \
  "delete from auth.users where id='$B'; select count(*) from public.line_links where user_id='$B'" "0"

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || { echo "SOME CHECKS FAILED"; exit 1; }
