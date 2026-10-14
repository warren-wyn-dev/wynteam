#!/usr/bin/env bash
# Only synthetic fixtures in an isolated local PostgreSQL database.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/stripe_application_fee_refund_receipts_test.py"
