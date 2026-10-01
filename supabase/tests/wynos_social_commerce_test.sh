#!/usr/bin/env bash
# Regression contracts for WYNOS Social Commerce v1.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wynos_social_commerce_v1.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path

migration = Path(sys.argv[1]).read_text()
required = [
    "create table if not exists public.food_social_offers",
    "food_social_offers_for_drops",
    "food_merchant_social_offers",
    "food_set_social_offer",
    "post must be your public WYNOS post",
    "food_create_social_order",
    "'social'",
    "source_drop_id",
    "merchant payment is not configured",
    "food_social_payment_path_allowed",
    "Food private upload by rollout gate",
    "public.food_is_permanent_account()",
    "revoke all on table public.food_social_offers from public, anon, authenticated",
]
for token in required:
    assert token in migration, token

lower = migration.lower()
for signature in [
    "food_social_offers_for_drops(uuid[])",
    "food_merchant_social_offers(uuid)",
    "food_set_social_offer(uuid,uuid)",
    "food_create_social_order(uuid,text,text,text,text,integer)",
]:
    idx = lower.index("grant execute on function public." + signature)
    stmt = lower[idx:lower.index(";", idx)]
    assert "to authenticated" in stmt, signature

assert "grant select on table public.food_social_offers" not in lower
assert "author_id = auth.uid()" in migration
assert "d.audience = 'everyone'" in migration
assert "o.source = 'social'" in migration
print("PASS: Social Commerce stays owner-linked, authenticated and payment-safe")
PY
