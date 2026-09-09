#!/usr/bin/env bash
# Migration-level regression test for WYN-147 Home Feed Repetition Control.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wyn147_feed_repetition_control.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path

m = Path(sys.argv[1]).read_text()
lower = m.lower()

required = [
    'feed_repetition_config',
    'hard_cooldown_minutes',
    'medium_cooldown_minutes',
    'soft_cooldown_minutes',
    'hard_factor',
    'medium_factor',
    'soft_factor',
    'feed_impressions_recent_user_idx',
    'internal.my_recent_feed_deliveries',
    'internal.repetition_adjust_source_scores',
    'get_wynos_ranked_feed_base_v1',
    "and (x->>'rankPosition')::int between 1 and 10",
    'i.created_at>=c.started_at',
    "'{feed_source_scores}'",
    'feed_repetition_factor',
    'hashtextextended',
    'security invoker',
]
for token in required:
    assert token in m, token

# Repetition control must remain a ranking/telemetry adjustment only. It must
# not delete user data, activate experiments, rewrite source weights, or alter
# the product version.
for forbidden in [
    'truncate ',
    'delete from public.',
    'update public.feed_ranking_config',
    'insert into public.feed_experiments',
    'status=\'active\'',
    'v1.0.0 beta5',
]:
    assert forbidden not in lower, forbidden

# The private impression read is isolated to a narrow SECURITY DEFINER helper;
# the public feed wrapper itself stays SECURITY INVOKER so existing Home/RLS
# visibility remains authoritative.
helper_start = lower.index('create or replace function internal.my_recent_feed_deliveries')
helper_end = lower.index('create or replace function internal.repetition_adjust_source_scores')
assert 'security definer' in lower[helper_start:helper_end]

wrapper_start = lower.index('create or replace function public.get_wynos_ranked_feed()')
wrapper = lower[wrapper_start:]
assert 'security invoker' in wrapper
assert 'security definer' not in wrapper.split('as $$', 1)[0]

# Ignore legacy WYN-146 telemetry recorded before this migration; otherwise the
# old all-200 behavior could incorrectly fatigue almost the whole candidate set.
assert 'started_at' in lower
assert 'i.created_at>=c.started_at' in lower

print('PASS: WYN-147 repetition control migration contracts')
PY
