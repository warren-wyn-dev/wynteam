#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA="$ROOT/supabase/schema.sql"
MIGRATION="$ROOT/supabase/migrations_wyn146_feed_algorithm_v1.sql"
python3 - "$SCHEMA" "$MIGRATION" <<'PY'
import sys
from pathlib import Path
s,m=map(lambda p:Path(p).read_text(),sys.argv[1:])
required=['algorithm_version integer','feed_impressions','admin_feed_algorithm_dashboard',
 'topic_similarities','creator_similarities','content_similarities',
 'refresh_feed_similarities','my_similarity_candidates','candidate_origin',
 "similarity_score * 100","signal_type in ('hide', 'not_interested')"]
for token in required:
 assert token in s and token in m, token
for forbidden in ['truncate ','update public.feed_ranking_config','insert into public.feed_experiments']:
 assert forbidden not in m.lower(), forbidden
assert 'feed_impressions' not in s[s.index('create or replace function public.refresh_trending_scores'):s.index('create or replace function public.get_trending_candidates')]
assert 'feed_impressions' not in s[s.index('create or replace function public.refresh_top100_scores'):s.index('create or replace function public.get_top100_candidates')]
assert 'feed_impressions' not in s[s.index('create or replace function public.refresh_feed_similarities'):s.index('create or replace function internal.my_similarity_candidates')]
print('PASS: Algorithm v1 observability/similarity/feedback-loop contracts')
PY
