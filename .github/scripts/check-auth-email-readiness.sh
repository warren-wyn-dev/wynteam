#!/usr/bin/env bash
# Read-only production email readiness audit. Never prints SMTP credentials or hostnames.
set -euo pipefail
: "${SUPABASE_ACCESS_TOKEN:?SUPABASE_ACCESS_TOKEN is not configured}"
PROJECT_REF="kqokpocajhfbidcxpvhh"
API="https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth"
config=$(mktemp)
trap 'rm -f "$config"' EXIT
curl --fail --silent --show-error --retry 2 --max-time 30 \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -o "$config" "$API"

smtp_configured=$(jq -r 'if ((.smtp_host // "")|length)>0 and ((.smtp_user // "")|length)>0 then "yes" else "no" end' "$config")
confirm_required=$(jq -r 'if (.mailer_autoconfirm // false) == false then "yes" else "no" end' "$config")
callback_allowed=$(jq -r 'if ((.uri_allow_list // "" | split(",") | map(gsub("^\\s+|\\s+$"; "")) | index("https://wynos.online/auth/callback")) != null) then "yes" else "no" end' "$config")

echo "custom_smtp_configured=$smtp_configured"
echo "email_confirmation_required=$confirm_required"
echo "confirmation_callback_allowed=$callback_allowed"
if [ "$smtp_configured" != yes ]; then
  echo "::warning::Public Auth email is not production-ready: configure custom SMTP before enabling email confirmation."
fi
if [ "$callback_allowed" != yes ]; then
  echo "::error::Production confirmation callback is not allowlisted."
  exit 1
fi
# This audit deliberately does not change mailer_autoconfirm or SMTP settings.
