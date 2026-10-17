#!/usr/bin/env bash
# Run the independent real-role, concurrent-write and account-deletion regression.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/supabase/tests/food_support_cases_security_test.py"
