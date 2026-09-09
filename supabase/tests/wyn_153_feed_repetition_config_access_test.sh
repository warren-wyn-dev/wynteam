#!/usr/bin/env bash
# Migration-level contract test for WYN-153 repetition-config access hardening.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wyn153_feed_repetition_config_access.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path

m = Path(sys.argv[1]).read_text()
lower = m.lower()

required = [
    'internal.current_feed_repetition_config',
    'security definer',
    'set search_path = public',
    'from public.feed_repetition_config c',
    'grant execute on function internal.current_feed_repetition_config()',
    'to authenticated',
    'create or replace function public.get_wynos_ranked_feed()',
    'security invoker',
    'select * from internal.current_feed_repetition_config()',
    'internal.my_recent_feed_deliveries()',
    'internal.get_wynos_ranked_feed_base_v1()',
    "a.dimension_type = 'creator'",
]
for token in required:
    assert token in lower, token

helper_start = lower.index('create or replace function internal.current_feed_repetition_config')
wrapper_start = lower.index('create or replace function public.get_wynos_ranked_feed()')
helper = lower[helper_start:wrapper_start]
wrapper = lower[wrapper_start:]

assert 'security definer' in helper
assert 'security invoker' in wrapper.split('as $$', 1)[0]
assert 'security definer' not in wrapper.split('as $$', 1)[0]
assert 'from public.feed_repetition_config' not in wrapper
assert 'grant select on public.feed_repetition_config' not in lower
assert 'grant all on public.feed_repetition_config' not in lower

for forbidden in [
    'truncate ',
    'delete from public.',
    'v1.0.0 beta5',
]:
    assert forbidden not in lower, forbidden

print('PASS: WYN-153 private repetition config access contract')
PY
