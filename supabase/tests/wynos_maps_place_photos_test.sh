#!/usr/bin/env bash
# WYNOS Maps place photos behaviour test: upload limits, admin review and
# storage visibility (pending photos private, approved photos visible).
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_maps_place_photos_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_maps_place_photos_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

U=0000000a-0000-4000-8000-0000000000a1      # uploader
V=0000000b-0000-4000-8000-0000000000b1      # another user
ADMIN=0000000c-0000-4000-8000-0000000000c1  # platform admin
P1=00000001-0000-4000-8000-000000000001
P2=00000002-0000-4000-8000-000000000002

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth;
create schema internal;
create schema storage;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create function internal.current_platform_role() returns text language sql stable as
  \$\$ select case when auth.uid() = '$ADMIN'::uuid then 'admin' else null end \$\$;
create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql immutable as \$\$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] \$\$;
alter table storage.objects enable row level security;
create table public.profiles(id uuid primary key);
create table public.wynos_places(id text primary key, name_th text not null, is_active boolean not null default true);
grant usage on schema public, auth, internal, storage to authenticated, anon;
grant execute on function internal.current_platform_role() to authenticated;
grant select, insert, delete on storage.objects to authenticated;
insert into public.profiles values ('$U'), ('$V'), ('$ADMIN');
insert into public.wynos_places values ('wynos_place_live', 'ร้านกาแฟ', true), ('wynos_place_hidden', 'ซ่อน', false);
SQL

run -f "$ROOT/supabase/migrations_wynos_maps_place_photos_v1.sql" >/dev/null

as_user() { run -At <<SQL
set role authenticated;
select set_config('test.uid', '$1', false);
$2
SQL
}
last() { tail -n 1; }
expect_error() { local out
  if out=$(as_user "$2" "$3" 2>&1); then echo "FAIL $1: expected an error"; exit 1; fi
  echo "$out" | grep -q "$4" || { echo "FAIL $1: wrong error: $out"; exit 1; }
  echo "PASS $1"; }
expect_eq() { [ "$2" = "$3" ] || { echo "FAIL $1: got '$2', want '$3'"; exit 1; }; echo "PASS $1"; }

bucket=$(run -At -c "select public::text||':'||file_size_limit from storage.buckets where id='place-photos'")
expect_eq "bucket is private with a 5 MB cap" "$bucket" "false:5242880"

expect_error "cannot upload into someone else's folder" "$U" \
  "insert into storage.objects(bucket_id, name) values ('place-photos', '$V/$P1.jpg');" "row-level security"
as_user "$U" "insert into storage.objects(bucket_id, name) values ('place-photos', '$U/$P1.jpg'), ('place-photos', '$U/$P2.jpg');" >/dev/null
echo "PASS uploader can write into own folder"

expect_error "submit needs an existing upload" "$U" "select public.submit_wynos_place_photo('wynos_place_live', '$U/00000009-0000-4000-8000-000000000009.jpg', 1600, 1200);" "photo upload not found"
expect_error "submit rejects another user's path" "$V" "select public.submit_wynos_place_photo('wynos_place_live', '$U/$P1.jpg', 1600, 1200);" "invalid photo path"
expect_error "submit rejects hidden places" "$U" "select public.submit_wynos_place_photo('wynos_place_hidden', '$U/$P1.jpg', 1600, 1200);" "place not found"
expect_error "anon cannot submit" "" "select public.submit_wynos_place_photo('wynos_place_live', '$U/$P1.jpg', 1600, 1200);" "authentication required"

photo=$(as_user "$U" "select public.submit_wynos_place_photo('wynos_place_live', '$U/$P1.jpg', 1600, 1200);" | last)
[ -n "$photo" ] && echo "PASS uploader submits a photo"

v_sees=$(as_user "$V" "select count(*) from public.wynos_place_photos('wynos_place_live');" | last)
expect_eq "others do not see a pending photo" "$v_sees" "0"
u_sees=$(as_user "$U" "select status||':'||is_mine from public.wynos_place_photos('wynos_place_live');" | last)
expect_eq "uploader sees own pending photo" "$u_sees" "pending:true"
v_obj=$(as_user "$V" "select count(*) from storage.objects where name = '$U/$P1.jpg';" | last)
expect_eq "pending object is private to others" "$v_obj" "0"
direct=$(as_user "$V" "select count(*) from public.wynos_place_photos;" 2>&1 | grep -c "permission denied" || true)
expect_eq "photo table is not readable directly" "$direct" "1"

expect_error "non-admins cannot review" "$V" "select public.admin_review_wynos_place_photo('$photo', 'approve');" "Only admins"
queue=$(as_user "$ADMIN" "select count(*) from public.admin_wynos_place_photos('pending', 50);" | last)
expect_eq "admin sees the review queue" "$queue" "1"
reviewed=$(as_user "$ADMIN" "select public.admin_review_wynos_place_photo('$photo', 'approve');" | last)
expect_eq "admin approves" "$reviewed" "approved"

v_after=$(as_user "$V" "select count(*) from public.wynos_place_photos('wynos_place_live');" | last)
expect_eq "approved photo is listed for others" "$v_after" "1"
v_obj_after=$(as_user "$V" "select count(*) from storage.objects where name = '$U/$P1.jpg';" | last)
expect_eq "approved object is readable by others" "$v_obj_after" "1"

# RLS turns another user's delete into a no-op (0 rows), not an error.
as_user "$V" "delete from storage.objects where name = '$U/$P1.jpg';" >/dev/null
left=$(run -At -c "select count(*) from storage.objects where name = '$U/$P1.jpg'")
expect_eq "object survives another user's delete" "$left" "1"

for i in 3 4 5 6; do
  as_user "$U" "insert into storage.objects(bucket_id, name) values ('place-photos', '$U/0000000$i-0000-4000-8000-00000000000$i.jpg');
    select public.submit_wynos_place_photo('wynos_place_live', '$U/0000000$i-0000-4000-8000-00000000000$i.jpg', null, null);" >/dev/null
done
as_user "$U" "insert into storage.objects(bucket_id, name) values ('place-photos', '$U/00000007-0000-4000-8000-000000000007.jpg');" >/dev/null
expect_error "five photos per place per user" "$U" "select public.submit_wynos_place_photo('wynos_place_live', '$U/00000007-0000-4000-8000-000000000007.jpg', null, null);" "place photo limit reached"

withdrawn=$(as_user "$U" "select public.delete_my_wynos_place_photo('$photo');" | last)
expect_eq "uploader can withdraw and gets the path to remove" "$withdrawn" "$U/$P1.jpg"
v_withdrawn=$(as_user "$V" "select public.delete_my_wynos_place_photo('$photo');" | last)
expect_eq "nothing to withdraw for others" "$v_withdrawn" ""

echo "wynos_maps_place_photos_test: all checks passed"
