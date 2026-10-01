#!/usr/bin/env bash
# Regression contracts for WYNOS Merchant PromptPay/slip payment core.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wynos_merchant_payment_core_v1.sql"
VERIFY="$ROOT/supabase/functions/food-verify-slip/index.ts"
QR="$ROOT/supabase/functions/food-payment-qr/index.ts"

python3 - "$MIGRATION" "$VERIFY" "$QR" <<'PY'
import sys
from pathlib import Path

migration = Path(sys.argv[1]).read_text()
verify = Path(sys.argv[2]).read_text()
qr = Path(sys.argv[3]).read_text()

required_migration = [
    "payment_verification_status",
    "food_payment_verifications",
    "food_record_payment_verification",
    "unsafe automatic payment verification",
    "p_receiver_match is distinct from true",
    "p_amount_match is distinct from true",
    "food_payment_verifications_provider_transaction_uq",
    "grant execute on function public.food_record_payment_verification",
    "to service_role",
    "revoke all on function public.food_record_payment_verification",
    "source in ('app','manual','social')",
    "food_orders_notify_merchant_payment",
    "revoke all on table public.food_payment_verifications from public, anon, authenticated",
]
for token in required_migration:
    assert token in migration, token

lower = migration.lower()
assert "grant execute on function public.food_record_payment_verification" in lower
assert "to authenticated" not in lower.split(
    "grant execute on function public.food_record_payment_verification", 1
)[1].split(";", 1)[0]

required_verify = [
    'SLIPOK_API_KEY',
    'SLIPOK_BRANCH_ID',
    'SLIPOK_RECEIVER_STORE_ID',
    'receiverBound',
    'receiverBound && amountMatch === true && transactionRef ? "auto_verified" : "manual_review"',
    'form.append("log", receiverBound ? "true" : "false")',
    'provider_not_configured',
    'duplicate_transaction',
]
# duplicate_transaction is enforced in SQL rather than the Edge Function.
for token in required_verify[:-1]:
    assert token in verify, token
assert required_verify[-1] in migration

assert 'SUPABASE_SERVICE_ROLE_KEY' in verify
assert 'SLIPOK_API_KEY' not in qr
assert 'buildPromptPayPayload' in qr

print("PASS: Merchant payment core keeps auto-Paid receiver-safe and service-role-only")
PY
