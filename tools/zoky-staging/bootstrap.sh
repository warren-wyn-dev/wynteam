#!/usr/bin/env bash
# Bootstrap the ZOKY STAGING database (separate Free Supabase project) to the
# production-like schema, following tools/zoky-staging/bootstrap-order.txt.
# Never point this at production: zoky-staging-e2e.yml refuses the production
# project ref and a token that can see it before calling this script.
#
# Usage: bootstrap.sh <backend checkout dir> <project ref>
# Needs the standard libpq env (PGHOST, PGPORT, PGUSER, PGPASSWORD,
# PGDATABASE, PGSSLMODE) for the staging session pooler.
#
# Fresh database: enables pg_cron/pg_net, stores the project URL in Vault,
# applies every `apply` line in its own transaction, then records a marker.
# Already bootstrapped (marker present): re-applies only the ZOKY Stripe jobs
# and cron migrations, which are idempotent, so a newer backend ref is picked up.
set -euo pipefail
REPO="$1"
REF="$2"
ORDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap-order.txt"
[[ "$REF" =~ ^[a-z0-9]{20}$ ]] || { echo "::error::bad project ref"; exit 1; }
psql_run() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

# Every migration in the repo must be listed (applied or skipped on purpose).
missing=0
while IFS= read -r f; do
  grep -Eq "^(apply|skip) ${f}( |$)" "$ORDER" || { echo "::error::$f is not in bootstrap-order.txt"; missing=1; }
done < <(cd "$REPO" && ls supabase/schema.sql supabase/migrations_*.sql supabase/pending_*.sql supabase/migrations/*.sql 2>/dev/null)
[ "$missing" = 0 ] || exit 1

if [ "$(psql_run -At -c "select to_regclass('staging_meta.bootstrap') is not null")" = "t" ]; then
  echo "Already bootstrapped; re-applying the ZOKY Stripe jobs + cron migrations (idempotent)."
  for f in supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql \
           supabase/migrations/20261023100100_food_stripe_jobs_enable_cron.sql; do
    psql_run --single-transaction -f "$REPO/$f"
    echo "OK   $f"
  done
  exit 0
fi

psql_run <<SQL
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
do \$\$
begin
  if exists (select 1 from vault.secrets where name = 'wynos_project_url') then
    perform vault.update_secret((select id from vault.secrets where name = 'wynos_project_url'),
                                'https://${REF}.supabase.co');
  else
    perform vault.create_secret('https://${REF}.supabase.co', 'wynos_project_url', 'ZOKY staging project URL');
  end if;
end
\$\$;
SQL

while IFS= read -r line; do
  case "$line" in
    apply\ *)
      f="${line#apply }"
      psql_run --single-transaction -f "$REPO/$f" >/dev/null
      echo "OK   $f" ;;
    sql\ *)
      psql_run --single-transaction -c "${line#sql }" >/dev/null
      echo "OK   (fixup) ${line#sql }" ;;
    skip\ *) echo "SKIP ${line#skip }" ;;
  esac
done < "$ORDER"

psql_run <<SQL
create schema if not exists staging_meta;
revoke all on schema staging_meta from public, anon, authenticated;
create table staging_meta.bootstrap(applied_at timestamptz not null default now(), backend_sha text not null);
insert into staging_meta.bootstrap(backend_sha) values ('$(git -C "$REPO" rev-parse HEAD)');
SQL
echo "Staging bootstrap complete."
