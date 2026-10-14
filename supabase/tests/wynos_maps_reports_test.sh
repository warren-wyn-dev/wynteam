#!/usr/bin/env bash
# Real disposable PG17 fixture; synthetic identities only, no network/credentials.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="maps_reports_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run(){ $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
grant usage on schema auth,internal to authenticated,anon;
create table public.profiles(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create table public.test_permissions(user_id uuid primary key,system text,level text,developer boolean);
create function public.is_developer_account() returns boolean language sql stable security definer set search_path='' as $$
select coalesce((select developer from public.test_permissions where user_id=auth.uid()),false)$$;
create function internal.has_admin_permission(p_system text,p_level text) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.test_permissions where user_id=auth.uid() and system=p_system and (level='edit' or p_level='view'))$$;
create table public.wynos_places(id text primary key,name_th text,is_active boolean);
alter table public.wynos_places enable row level security;
create policy public_places on public.wynos_places for select to authenticated using(is_active);
grant select on public.wynos_places to authenticated;
create table public.audit_log(id uuid primary key default gen_random_uuid(),actor_id uuid references public.profiles(id) on delete set null,event_type text not null, target_id uuid,detail jsonb,
 constraint audit_log_event_type_check check(event_type in ('existing_event_a','existing_event_b')));
create function internal.log_audit_event(p_actor_id uuid,p_event_type text,p_target_id uuid,p_detail jsonb) returns void language sql as $$
 insert into public.audit_log(actor_id,event_type,target_id,detail) values(p_actor_id,p_event_type,p_target_id,p_detail)$$;
revoke all on function internal.log_audit_event(uuid,text,uuid,jsonb) from public,anon,authenticated;
insert into public.profiles select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,8) n;
insert into public.test_permissions values
 ('00000000-0000-0000-0000-000000000001',null,null,true),
 ('00000000-0000-0000-0000-000000000002',null,null,true),
 ('00000000-0000-0000-0000-000000000003','maps','view',false),
 ('00000000-0000-0000-0000-000000000004','maps','edit',false),
 ('00000000-0000-0000-0000-000000000005','food','edit',true),
 ('00000000-0000-0000-0000-000000000006',null,null,false),
 ('00000000-0000-0000-0000-000000000007',null,null,true),
 ('00000000-0000-0000-0000-000000000008','maps','edit',true);
insert into public.wynos_places select 'wynos_place_'||lpad(n::text,32,'0'),'Synthetic place '||n,n<>9 from generate_series(1,12) n;
SQL
MIGRATION="$ROOT/supabase/migrations/20261014074023_wynos_maps_reports_v1.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"
A=00000000-0000-0000-0000-000000000001
B=00000000-0000-0000-0000-000000000002
VIEW=00000000-0000-0000-0000-000000000003
EDIT=00000000-0000-0000-0000-000000000004
OTHER=00000000-0000-0000-0000-000000000005
NONDEV=00000000-0000-0000-0000-000000000006
RACE=00000000-0000-0000-0000-000000000007
EDITOR2=00000000-0000-0000-0000-000000000008
PLACE=wynos_place_00000000000000000000000000000001
CHECKS=0
eq(){
 local got
 got="$(run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4: got $got expected $3";exit 1; }
 CHECKS=$((CHECKS+1))
}
fail(){
 local got
 if got="$(run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" 2>&1)";then echo "FAIL $3: expected error";exit 1;fi
 [[ "$got" == *"$4"* ]] || { echo "FAIL $3: unexpected $got";exit 1; }
 CHECKS=$((CHECKS+1))
}
fail '' "select public.submit_wynos_map_report('$PLACE','wrong_info','Entrance is on another street')" 'signed out' 'Not authorized'
fail "$NONDEV" "select public.submit_wynos_map_report('$PLACE','wrong_info','Entrance is on another street')" 'nondeveloper intake gate' 'Not authorized'
fail "$NONDEV" 'select public.wynos_my_map_reports()' 'nondeveloper status gate' 'Not authorized'
fail "$A" "select public.submit_wynos_map_report('wynos_place_00000000000000000000000000000009','closed','Place closed last month')" 'inactive preview rejected' 'Public place not available'
fail "$A" "select public.submit_wynos_map_report('osm_1','closed','Place closed last month')" 'external provider rejected' 'Invalid report input'
fail "$A" "select public.submit_wynos_map_report('$PLACE',null,'Entrance is on another street')" 'null kind rejected' 'Invalid report input'
fail "$A" "select public.submit_wynos_map_report('$PLACE','wrong_info',repeat('x',501))" 'oversize rejected' 'Invalid report input'
fail "$A" "select public.submit_wynos_map_report('$PLACE','wrong_info','short')" 'short note rejected' 'Invalid report input'
eq "$A" "select public.submit_wynos_map_report('$PLACE','wrong_info','Entrance information 0812345678 email@example.com https://example.com <b>review</b>') is not null" t 'intake'
REPORT="$(run -At -c 'select id from public.wynos_map_reports limit 1' | tail -n1)"
eq "$A" 'select count(*) from public.wynos_my_map_reports()' 1 'owner status'
eq "$B" 'select count(*) from public.wynos_my_map_reports()' 0 'cross owner hidden'
eq "$A" "select row_to_json(r)::text ~ 'reporter|note|reason|actor|latitude|longitude' from public.wynos_my_map_reports() r" f 'owner projection minimized'
fail "$A" "select public.submit_wynos_map_report('$PLACE','unsafe','Another concern about entrance')" 'dedupe all active kinds' 'Active report already exists'
fail "$A" 'select public.admin_wynos_map_reports()' 'customer cannot read queue' 'Not authorized'
fail "$OTHER" 'select public.admin_wynos_map_reports()' 'other system cannot read queue' 'Not authorized'
eq "$VIEW" 'select count(*) from public.admin_wynos_map_reports()' 1 'maps view queue'
eq "$VIEW" "select row_to_json(r)::text ~ 'reporter|email@example|0812345678|https://|<b>|actor_id|latitude|longitude' from public.admin_wynos_map_reports() r" f 'queue identity/contact redaction'
fail "$VIEW" "select public.admin_update_wynos_map_report('$REPORT',1,'reviewing','Human review started')" 'view cannot edit' 'Not authorized'
fail "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',1,'resolved','Human review completed')" 'cannot skip human review' 'Invalid report transition'
fail "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',1,'reviewing','')" 'reason required' 'Review reason required'
fail "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',null,'reviewing','Human review started')" 'null version rejected' 'Report changed'
eq "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',1,'reviewing','Human review started 0812345678')" 2 'start human review'
fail "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',1,'resolved','Human review completed')" 'stale edit rejected' 'Report changed'
eq "$A" "select status from public.wynos_my_map_reports() where id='$REPORT'" reviewing 'owner sees status update'
eq "$VIEW" "select count(*) from public.admin_wynos_map_report_history('$REPORT')" 2 'view history'
eq "$VIEW" "select bool_and(reason not like '%0812345678%') from public.admin_wynos_map_report_history('$REPORT')" t 'audit reason contact masking'
fail "$A" "select public.admin_wynos_map_report_history('$REPORT')" 'owner cannot read internal history' 'Not authorized'
eq "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',2,'resolved','Checked public entrance information')" 3 'human resolution'
fail "$EDIT" "select public.admin_update_wynos_map_report('$REPORT',3,'reviewing','Reopen without a new report')" 'terminal state protected' 'Invalid report transition'
eq "$A" "select has_table_privilege('authenticated','public.wynos_map_reports','SELECT')" f 'reports table denied'
eq "$A" "select has_table_privilege('authenticated','public.wynos_map_report_events','UPDATE')" f 'events immutable'
fail "$A" 'select * from public.wynos_map_reports' 'direct table bypass' 'permission denied'
fail "$EDIT" "update public.wynos_map_report_events set reason='Tampering attempt'" 'direct audit update denied' 'permission denied'
eq "$A" "select has_function_privilege('anon','public.submit_wynos_map_report(text,text,text)','EXECUTE')" f 'anon RPC denied'
eq "$A" "select has_function_privilege('authenticated','internal.wynos_map_report_safe_text(text)','EXECUTE')" f 'internal helper denied'
eq "$A" "select relrowsecurity from pg_class where oid='public.wynos_map_reports'::regclass" t 'reports RLS'
eq "$A" "select relrowsecurity from pg_class where oid='public.wynos_map_report_events'::regclass" t 'events RLS'
[[ "$(run -At -c "select count(*) from public.audit_log where event_type='admin_wynos_map_report_updated' and target_id='$REPORT'")" == 2 ]]
[[ "$(run -At -c "select bool_and(detail::text not like '%0812345678%' and not detail ? 'reason') from public.audit_log")" == t ]]
[[ "$(run -At -c "select bool_and(is_active) from public.wynos_places where id='$PLACE'")" == t ]]
CHECKS=$((CHECKS+3))
# Concurrent duplicate submissions serialize per reporter; only one succeeds.
TMP="$(mktemp -d)"; trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null; rm -rf "$TMP"' EXIT
race_submit(){ run -At -c "set role authenticated; select set_config('test.uid','$RACE',false);" -c "select public.submit_wynos_map_report('$PLACE','unsafe','Please review the public entrance')"; }
race_submit >"$TMP/submit1" 2>&1 & PID1=$!
race_submit >"$TMP/submit2" 2>&1 & PID2=$!
S1=0;S2=0;wait "$PID1" || S1=$?;wait "$PID2" || S2=$?
[[ $((S1+S2)) -ne 0 && ( "$S1" == 0 || "$S2" == 0 ) ]]
[[ "$(run -At -c "select count(*) from public.wynos_map_reports where reporter_id='$RACE'")" == 1 ]]
CHECKS=$((CHECKS+2))
RACE_REPORT="$(run -At -c "select id from public.wynos_map_reports where reporter_id='$RACE'")"
race_edit(){ run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "select public.admin_update_wynos_map_report('$RACE_REPORT',1,'reviewing','Human reviewing concurrent report')"; }
race_edit "$EDIT" >"$TMP/edit1" 2>&1 & PID1=$!
race_edit "$EDITOR2" >"$TMP/edit2" 2>&1 & PID2=$!
S1=0;S2=0;wait "$PID1" || S1=$?;wait "$PID2" || S2=$?
[[ $((S1+S2)) -ne 0 && ( "$S1" == 0 || "$S2" == 0 ) ]]
[[ "$(run -At -c "select count(*) from public.wynos_map_report_events where report_id='$RACE_REPORT'")" == 2 ]]
CHECKS=$((CHECKS+2))
for N in 2 3 4 5;do eq "$A" "select public.submit_wynos_map_report('wynos_place_'||lpad('$N',32,'0'),'other','Please review this public place') is not null" t 'daily allowed';done
fail "$A" "select public.submit_wynos_map_report('wynos_place_'||lpad('6',32,'0'),'other','Please review this public place')" 'daily rate limit' 'Report rate limit'
run >/dev/null < "$ROOT/supabase/rollbacks/20261014074023_wynos_maps_reports_v1_rollback.sql"
eq "$A" "select has_function_privilege('authenticated','public.wynos_my_map_reports(integer)','EXECUTE')" f 'rollback disables API'
[[ "$(run -At -c "select count(*) from public.wynos_map_report_events where report_id='$REPORT'")" == 3 ]]
CHECKS=$((CHECKS+1))
run >/dev/null < "$MIGRATION"
eq "$A" "select status from public.wynos_my_map_reports() where id='$REPORT'" resolved 'reapply preserves status'
run -c "delete from public.profiles where id in ('$A','$EDIT','$EDITOR2');delete from public.wynos_places where id='$PLACE'" >/dev/null
[[ "$(run -At -c "select reporter_id is null and place_id is null from public.wynos_map_reports where id='$REPORT'")" == t ]]
[[ "$(run -At -c "select count(*) from public.wynos_map_report_events where report_id='$REPORT' and actor_id is not null")" == 0 ]]
CHECKS=$((CHECKS+2))
eq "$B" 'select count(*) from public.wynos_my_map_reports()' 0 'deleted owner report inaccessible'
echo "PASS Maps reports: $CHECKS integration assertions incl. actual roles, concurrency, rollback, deletion"
