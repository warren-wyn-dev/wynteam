#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations_wynos_merchant_shared_auth_v1.sql"

python3 - "$MIGRATION" <<'PY'
import sys
from pathlib import Path
sql = Path(sys.argv[1]).read_text().lower()
required = [
    "shared_wynos",
    "drop trigger if exists wynos_merchant_auth_user_created",
    "drop function if exists internal.bootstrap_merchant_auth_user",
    "insert into public.merchant_users",
    "values (v_user, 'shared_wynos', true)",
    "create or replace function public.merchant_submit_application",
    "(select auth.uid()) = user_id",
]
for token in required:
    assert token in sql, token
assert "merchant account required" not in sql
print("PASS: Merchant uses shared WYNOS auth with separate business tenancy")
PY
