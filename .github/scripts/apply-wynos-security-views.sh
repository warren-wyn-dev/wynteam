#!/usr/bin/env bash
# Founder-operated, manual-only deployment gate for WYN-188/189/190.
# Never set these actions to run on push/PR or reveal management credentials.
set -euo pipefail

fail() { echo "::error::$1" >&2; exit 1; }
clean() { printf '%s' "$1" | tr -d '\n\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

test "$GITHUB_REF" = "refs/heads/main" || fail "Security migrations only deploy from main."
case "$STAGE" in
  WYN188) FILE=supabase/migrations_wyn188_moderation_history_invoker.sql; EXPECTED=1 ;;
  WYN189) FILE=supabase/migrations_wyn189_staff_audit_projection.sql; EXPECTED=2 ;;
  WYN190) FILE=supabase/migrations_wyn190_private_views.sql; EXPECTED=4 ;;
  *) fail "Unrecognized stage" ;;
esac
test -f "$FILE" || fail "Selected migration file was not checked out."
TOKEN="$(clean "$SUPABASE_ACCESS_TOKEN")"
URL="$(clean "$SUPABASE_URL")"
test -n "$TOKEN" && test -n "$URL" || fail "Required Supabase secret missing."
REF="$(printf '%s' "$URL" | sed -nE 's#^https://([a-z0-9]{20})[.]supabase[.]co/?$#\1#p')"
test -n "$REF" || fail "Secret SUPABASE_URL has an unexpected host format."
test "$PROJECT_REF_CONFIRM" = "$REF" || fail "Entered project ref does not match the configured Supabase project."
test "$DRY_RUN" = "true" || test "$DRY_RUN" = "false" || fail "Invalid dry_run value."
if test "$DRY_RUN" = "false"; then
  test "$CONFIRMATION" = "APPLY-$STAGE" || fail "Exact stage confirmation phrase missing."
fi

API="https://api.supabase.com/v1/projects/$REF/database/query"
RESPONSE="$(mktemp)"
BODY="$(mktemp)"
trap 'rm -f "$RESPONSE" "$BODY"' EXIT

sql_request() {
  jq -n --arg query "$1" '{query: $query}' > "$BODY"
  local status
  status="$(curl --silent --show-error --connect-timeout 10 --max-time 120 \
    --request POST "$API" --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/json" --data-binary "@$BODY" \
    --output "$RESPONSE" --write-out '%{http_code}')" ||
    fail "Supabase Management API network request failed."
  test "$status" = "200" || test "$status" = "201" ||
    fail "Supabase Management API returned HTTP $status (details intentionally omitted)."
}
check_boolean() {
  jq -e 'if type=="array" then .[0].ok==true
         elif type=="object" and (.result|type)=="array"
           then .result[0].ok==true else false end' "$RESPONSE" >/dev/null ||
    fail "$1 (database reported false or unexpected response)."
}

case "$STAGE" in
  WYN188)
    PREFLIGHT="select (
      exists(select 1 from pg_class where oid='public.moderation_actions'::regclass and relrowsecurity)
      and exists(select 1 from pg_policies where schemaname='public'
        and tablename='moderation_actions' and cmd='SELECT'
        and 'authenticated'=any(roles) and position('internal.current_platform_role()' in qual)>0)
    ) as ok;"
    ;;
  WYN189)
    PREFLIGHT="select (
      exists(select 1 from pg_class where oid='public.admin_user_moderation_history'::regclass
        and 'security_invoker=true'=any(reloptions))
      and exists(select 1 from pg_class where oid='public.audit_log'::regclass and relrowsecurity)
      and not exists(select 1 from pg_policies where schemaname='public'
        and tablename='audit_log' and cmd in('SELECT','ALL'))
    ) as ok;"
    ;;
  WYN190)
    PREFLIGHT="select (
      (select count(*)=2 from pg_class where relnamespace='public'::regnamespace
        and relname in('admin_user_moderation_history','admin_audit_log')
        and 'security_invoker=true'=any(reloptions))
      and exists(select 1 from pg_policies where schemaname='public'
        and tablename='reports' and cmd='SELECT' and position('reporter_id' in qual)>0)
      and not has_table_privilege('authenticated','public.user_affinities','SELECT')
    ) as ok;"
    ;;
esac

echo "Running read-only $STAGE preflight against confirmed project ref $REF."
sql_request "$PREFLIGHT"
check_boolean "Preflight denied stage $STAGE"
echo "Preflight PASS."
if test "$DRY_RUN" = "true"; then
  echo "DRY RUN ONLY — no migration SQL submitted."
  echo "WYNOS Security $STAGE: dry-run preflight passed, no DDL applied." >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

echo "Applying reviewed $STAGE migration from $(git rev-parse --short HEAD)."
jq -n --rawfile query "$FILE" '{query: $query}' > "$BODY"
code="$(curl --silent --show-error --connect-timeout 10 --max-time 120 \
  --request POST "$API" --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/json" --data-binary "@$BODY" \
  --output "$RESPONSE" --write-out '%{http_code}')" ||
  fail "Migration request failed; independently inspect production state before retrying."
test "$code" = "200" || test "$code" = "201" ||
  fail "Migration HTTP $code; independently inspect production state before retrying."

POSTCHECK="select (
  (select count(*)=$EXPECTED from pg_class
   where relnamespace='public'::regnamespace
     and relname in('admin_user_moderation_history','admin_audit_log',
                    'moderation_queue','my_effective_affinities')
     and 'security_invoker=true'=any(reloptions))
  and (case when '$STAGE'='WYN190'
     then exists(select 1 from pg_class
       where oid='public.my_effective_affinities'::regclass
         and 'security_barrier=true'=any(reloptions))
     else true end)
) as ok;"
sql_request "$POSTCHECK"
check_boolean "Post-migration security-invoker verification failed"
echo "WYNOS Security $STAGE: reviewed migration applied; catalog postcheck passed." >> "$GITHUB_STEP_SUMMARY"
echo "Postcheck PASS. Follow the runbook's staff/user behavior and Security Advisor verification."
