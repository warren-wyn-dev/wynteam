#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wynos_merchant_accounts_v2.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path
sql = Path(sys.argv[1]).read_text()
required = [
    "create table if not exists public.merchant_users",
    "create table if not exists public.merchant_accounts",
    "create table if not exists public.merchant_memberships",
    "merchant_account_id uuid",
    "wynos_merchant_auth_user_created",
    "merchant_submit_application",
    "identity_mode in ('merchant', 'legacy_social')",
    "role in ('owner', 'admin', 'manager', 'orders', 'support', 'delivery')",
    "public.merchant_notifications",
    "insert into public.profiles(id)",
    "join public.merchant_memberships",
]
for token in required:
    assert token.lower() in sql.lower(), token

assert "grant execute on function public.merchant_submit_application" in sql.lower()
assert "to authenticated" in sql.lower().split(
    "grant execute on function public.merchant_submit_application", 1
)[1].split(";", 1)[0]
print("PASS: Merchant business account tenancy and separate identity contracts present")
PY
