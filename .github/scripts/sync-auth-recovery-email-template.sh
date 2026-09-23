#!/usr/bin/env bash
# WYNOS: update ONLY the recovery email template after the safe landing page
# has been successfully deployed. Never log Auth config, credentials or tokens.
set -euo pipefail
umask 077

PROJECT_REF="kqokpocajhfbidcxpvhh"
API="https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth"
TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/wynos-recovery-email.html"

validate_template() {
  test -f "$TEMPLATE"
  grep -Fq 'https://wynos.online/reset-password#type=recovery&amp;token_hash={{ .TokenHash }}' "$TEMPLATE"
  if grep -Fq '.ConfirmationURL' "$TEMPLATE"; then
    echo "::error::Recovery email must not link directly to the prefetchable Supabase /verify endpoint"
    exit 1
  fi
}
validate_template

if [[ "${1:-}" == "--check-only" && "$#" -eq 1 ]]; then
  echo "Recovery email template static checks passed"
  exit 0
fi
if [[ "$#" -ne 0 ]]; then
  echo "Usage: sync-auth-recovery-email-template.sh [--check-only]" >&2
  exit 2
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "::error::SUPABASE_ACCESS_TOKEN is missing"
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Auth configuration may contain secrets. Responses are saved to private
# temporary files and NEVER printed, even on errors.
curl --fail --silent --show-error --retry 2 --max-time 30 \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -o "$tmpdir/current.json" "$API"
jq -e 'type=="object"' "$tmpdir/current.json" >/dev/null

existing=$(jq -r '.mailer_templates_recovery_content // ""' "$tmpdir/current.json")
wanted=$(cat "$TEMPLATE")
if [[ "$existing" == "$wanted" ]]; then
  echo "RECOVERY_EMAIL_TEMPLATE=already_configured"
  exit 0
fi
if [[ -n "$existing" && "$existing" != *".ConfirmationURL"* ]]; then
  echo "::error::Unexpected existing recovery template. No change was made; review its existing configuration first."
  exit 1
fi

jq -n --arg html "$wanted" '{mailer_templates_recovery_content: $html}' > "$tmpdir/payload.json"
curl --fail --silent --show-error --retry 1 --max-time 30 \
  -X PATCH -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary "@$tmpdir/payload.json" \
  -o "$tmpdir/response.json" "$API"

# A second read is essential: HTTP 2xx alone does not prove the template is
# active. Show only a fixed state label; never print the Auth response.
curl --fail --silent --show-error --retry 2 --max-time 30 \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -o "$tmpdir/verify.json" "$API"
actual=$(jq -r '.mailer_templates_recovery_content // ""' "$tmpdir/verify.json")
if [[ "$actual" != "$wanted" ]]; then
  echo "::error::Recovery template could not be verified after update"
  exit 1
fi
echo "RECOVERY_EMAIL_TEMPLATE=updated_verified"
