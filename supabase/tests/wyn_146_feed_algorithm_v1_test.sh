#!/usr/bin/env bash
# Migration-level regression test for WYN-146 Feed Algorithm v1 hardening.
# Validate the additive migration directly; schema.sql may legitimately lag
# pending migrations until the normal schema-regeneration step.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wyn146_feed_algorithm_v1.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path

m = Path(sys.argv[1]).read_text()
required = [
    'algorithm_version integer',
    'feed_impressions',
    'admin_feed_algorithm_dashboard',
    'topic_similarities',
    'creator_similarities',
    'content_similarities',
    'refresh_feed_similarities',
    'my_similarity_candidates',
    'candidate_origin',
    'similarity_score * 100',
    "signal_type in ('hide', 'not_interested')",
]
for token in required:
    assert token in m, token

lower = m.lower()
for forbidden in [
    'truncate ',
    'update public.feed_ranking_config',
    'insert into public.feed_experiments',
]:
    assert forbidden not in lower, forbidden

# Distribution/impression telemetry must not feed back into authoritative
# Trending, Top100, or similarity scoring functions.
def between(start, end):
    a = lower.index(start.lower())
    b = lower.index(end.lower(), a)
    return lower[a:b]

assert 'feed_impressions' not in between(
    'create or replace function public.refresh_trending_scores',
    'create or replace function public.get_trending_candidates',
)
assert 'feed_impressions' not in between(
    'create or replace function public.refresh_top100_scores',
    'create or replace function public.get_top100_candidates',
)
assert 'feed_impressions' not in between(
    'create or replace function public.refresh_feed_similarities',
    'create or replace function internal.my_similarity_candidates',
)

print('PASS: WYN-146 observability/similarity/feedback-loop migration contracts')
PY
