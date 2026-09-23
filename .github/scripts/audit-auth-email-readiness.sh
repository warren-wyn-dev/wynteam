#!/usr/bin/env bash
# Read-only, secret-safe Supabase Auth email readiness audit.
# NEVER modifies Auth config, enables confirmations or sends email.
set -euo pipefail
umask 077

PROJECT_REF="kqokpocajhfbidcxpvhh"
API="https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth"
CALLBACK="https://wynos.online/auth/callback"
RECOVERY="https://wynos.online/reset-password"
tmp=""
cleanup() { if [ -n "$tmp" ]; then rm -f "$tmp"; fi; }
trap cleanup EXIT

if [ "$#" -eq 2 ] && [ "$1" = "--fixture" ]; then
  # Offline CI fixtures exercise the exact parser without any network call.
  config="$2"
elif [ "$#" -eq 0 ]; then
  if [[ ! -v SUPABASE_ACCESS_TOKEN ]] || [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
    echo "::error::SUPABASE_ACCESS_TOKEN is required for the read-only email audit"
    exit 1
  fi
  tmp=$(mktemp)
  config="$tmp"
  # Auth config can contain SMTP/OAuth secrets. NEVER print the response.
  curl --fail --silent --show-error --retry 2 --max-time 30 \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -o "$config" "$API"
else
  echo "Usage: audit-auth-email-readiness.sh [--fixture file.json]" >&2
  exit 2
fi

if ! jq -e 'type == "object"' "$config" >/dev/null; then
  echo "::error::Management API returned an invalid Auth config"
  exit 1
fi

# Only fixed booleans / non-sensitive state labels appear in logs and summaries.
# smtp_pass might be redacted by the Management API; never inspect or log it.
report=$(jq -r --arg confirmation_url "$CALLBACK" --arg reset_url "$RECOVERY" '
  def present: . != null and (. | tostring | length > 0);
  def allowlisted($url):
    (.uri_allow_list // "" | split(",")
      | map(gsub("^\\s+|\\s+$"; "")) | index($url)) != null;
  . as $cfg
  | ($cfg.smtp_host | present) as $host
  | ($cfg.smtp_port | present) as $port
  | ($cfg.smtp_user | present) as $user
  | ($cfg.smtp_admin_email | present) as $sender
  | (
      if $cfg.mailer_autoconfirm == false then "on"
      elif $cfg.mailer_autoconfirm == true then "off"
      else "unknown" end
    ) as $confirmation
  | [
      "SMTP_HOST_PRESENT=" + ($host | tostring),
      "SMTP_PORT_PRESENT=" + ($port | tostring),
      "SMTP_USER_PRESENT=" + ($user | tostring),
      "SMTP_SENDER_PRESENT=" + ($sender | tostring),
      "SMTP_METADATA_PRESENT=" + (($host and $port and $user and $sender) | tostring),
      "EMAIL_CONFIRMATION=" + $confirmation,
      "CONFIRMATION_REDIRECT_ALLOWED=" + (allowlisted($confirmation_url) | tostring),
      "RECOVERY_REDIRECT_ALLOWED=" + (allowlisted($reset_url) | tostring),
      "PASSWORD_MINIMUM_12=" + (((($cfg.password_min_length // 0) | tonumber) >= 12) | tostring)
    ] | .[]
' "$config")
printf '%s\n' "$report"

smtp_ready=$(printf '%s\n' "$report" | grep '^SMTP_METADATA_PRESENT=' | cut -d= -f2)
confirmation=$(printf '%s\n' "$report" | grep '^EMAIL_CONFIRMATION=' | cut -d= -f2)
if [[ -v GITHUB_STEP_SUMMARY ]] && [ -n "$GITHUB_STEP_SUMMARY" ]; then
  {
    echo "## WYNOS Web Beta1 — Supabase email readiness"
    echo
    echo "Read-only audit; no email sent and no settings changed."
    echo
    echo '~~~text'
    printf '%s\n' "$report"
    echo '~~~'
    echo
    echo "**SMTP metadata is not proof of email delivery.** Test a real non-team mailbox and recovery link before enabling email confirmation."
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$smtp_ready" != true ]; then
  echo "::warning::Custom SMTP metadata is incomplete; configure and verify a production SMTP provider before public signup"
elif [ "$confirmation" = "off" ]; then
  echo "::notice::SMTP metadata is present; email confirmation is still off. Test outbound delivery before enabling it."
elif [ "$confirmation" = "on" ]; then
  echo "::notice::Email confirmation is on; verify non-team mailbox delivery and the complete onboarding flow."
else
  echo "::warning::Email confirmation setting could not be established. Check Supabase Dashboard."
fi
