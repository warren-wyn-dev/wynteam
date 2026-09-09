#!/usr/bin/env bash
# Migration-level regression test for WYN-145 Experimentation & A/B Testing.
# This intentionally validates the additive migration itself instead of assuming
# schema.sql has already been regenerated from every pending migration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wyn145_experimentation.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path

m = Path(sys.argv[1]).read_text()
required = [
    'create table if not exists public.feed_experiments',
    'create table if not exists public.feed_experiment_variants',
    'create table if not exists public.feed_experiment_exposures',
    'create table if not exists public.feed_experiment_outcomes',
    'internal.experiment_bucket',
    'internal.feed_experiment_is_valid',
    'internal.validate_feed_experiment_activation',
    'internal.prevent_active_variant_mutation',
    'public.resolve_home_feed_experiments',
    'public.record_home_feed_experiment_exposures',
    'internal.attribute_feed_experiment_outcome',
    'internal.feed_experiment_variant_metrics',
    "check(status in ('draft','active','paused','completed'))",
    "check(surface in ('home'))",
    "unique(experiment_key,experiment_version,user_id,surface,exposure_date)",
]
for token in required:
    assert token in m, token

lower = m.lower()
for forbidden in [
    'truncate ',
    'drop table public.feed_experiments',
    'update public.feed_ranking_config',
    "values('home_mix'",
]:
    assert forbidden not in lower, forbidden

# The migration must not activate or seed an experiment. Definitions remain
# inert until an administrator explicitly inserts/configures one later.
assert 'insert into public.feed_experiments' not in lower
assert "default 'draft'" in lower

# Ordinary clients can resolve/record their own assignment path, but cannot
# directly inspect or mutate experiment definitions/telemetry tables.
assert 'revoke all on public.feed_experiments' in lower
assert 'grant execute on function public.resolve_home_feed_experiments(text) to authenticated' in lower
assert 'grant execute on function public.record_home_feed_experiment_exposures(text[],text)' in lower

print('PASS: WYN-145 additive experimentation migration contracts')
PY
