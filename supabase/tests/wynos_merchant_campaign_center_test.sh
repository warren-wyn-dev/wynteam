#!/usr/bin/env bash
# Regression contracts for WYNOS Merchant Campaign Center.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wynos_merchant_campaign_center_v1.sql"
HARDENING="$ROOT/supabase/migrations_wynos_merchant_campaign_center_total_consistency_v1.sql"
MERCHANT_UI="$ROOT/web/components/merchant/merchant-campaign-center.tsx"
FOOD_DATA="$ROOT/web/lib/food-customer.ts"

python3 - "$MIGRATION" "$HARDENING" "$MERCHANT_UI" "$FOOD_DATA" <<'PY'
import sys
from pathlib import Path

migration = Path(sys.argv[1]).read_text()
hardening = Path(sys.argv[2]).read_text()
merchant_ui = Path(sys.argv[3]).read_text()
food_data = Path(sys.argv[4]).read_text()

for token in [
    "public.food_campaigns",
    "public.food_campaign_items",
    "public.food_order_campaigns",
    "internal.food_campaign_candidates",
    "public.food_quote_order",
    "create or replace function public.food_create_order",
    "order by saving desc",
    "for update",
    "usage_count=usage_count+1",
    "food_campaign_release_on_cancel",
    "usage_count=greatest(usage_count-1,0)",
    "campaign_applied",
    "food_campaigns_created_by_idx",
]:
    assert token in migration, token

for table in ["food_campaigns", "food_campaign_items", "food_order_campaigns"]:
    assert f"alter table public.{table} enable row level security" in migration
    assert f"revoke all on table public.{table} from public, anon, authenticated" in migration

# Merchant campaign mutations are business-role gated and the legacy manual-order
# endpoint must not be reintroduced by this migration.
assert "merchant_has_store_role(p_store_id,array['owner','admin','manager'])" in migration
assert "food_create_manual_order" not in migration
assert "total = subtotal - campaign_discount + delivery_fee - delivery_discount" in hardening

# Browser pricing is a preview; the final order still runs the same server-side
# candidate calculation and writes the campaign snapshot atomically.
assert 'client.rpc("food_quote_order"' in food_data
assert "WYNOS Food จะเลือกแคมเปญที่ลูกค้าประหยัดได้มากที่สุด" in merchant_ui
assert migration.count("internal.food_campaign_candidates(") >= 3

print("PASS: Merchant Campaign Center is server-priced, role-gated and non-stacking")
PY
