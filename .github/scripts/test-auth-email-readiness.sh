#!/usr/bin/env bash
# Offline regression suite; NEVER connects to the production project.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
audit="$root/.github/scripts/audit-auth-email-readiness.sh"
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

cat > "$dir/default.json" <<'JSON'
{
  "smtp_host": null, "smtp_port": null, "smtp_user": null,
  "smtp_pass": "SHOULD_NEVER_APPEAR",
  "smtp_admin_email": null, "mailer_autoconfirm": true,
  "password_min_length": 12,
  "uri_allow_list": "https://wynos.online/auth/callback,https://wynos.online/reset-password"
}
JSON
bash "$audit" --fixture "$dir/default.json" > "$dir/output"
grep -qx 'SMTP_METADATA_PRESENT=false' "$dir/output"
grep -qx 'EMAIL_CONFIRMATION=off' "$dir/output"
grep -qx 'CONFIRMATION_REDIRECT_ALLOWED=true' "$dir/output"
grep -qx 'RECOVERY_REDIRECT_ALLOWED=true' "$dir/output"
grep -qx 'PASSWORD_MINIMUM_12=true' "$dir/output"
if grep -q 'SHOULD_NEVER_APPEAR' "$dir/output"; then echo "Leaked SMTP password"; exit 1; fi

cat > "$dir/production.json" <<'JSON'
{
  "smtp_host": "EXAMPLE_PRIVATE_SMTP_HOST",
  "smtp_port": 587,
  "smtp_user": "EXAMPLE_PRIVATE_USERNAME",
  "smtp_pass": "EXAMPLE_PRIVATE_PASSWORD",
  "smtp_admin_email": "EXAMPLE_PRIVATE_SENDER",
  "mailer_autoconfirm": false,
  "password_min_length": 14,
  "uri_allow_list": "https://wynos.online/login, https://wynos.online/auth/callback, https://wynos.online/reset-password"
}
JSON
bash "$audit" --fixture "$dir/production.json" > "$dir/output"
grep -qx 'SMTP_METADATA_PRESENT=true' "$dir/output"
grep -qx 'EMAIL_CONFIRMATION=on' "$dir/output"
grep -qx 'PASSWORD_MINIMUM_12=true' "$dir/output"
grep -qx 'RECOVERY_REDIRECT_ALLOWED=true' "$dir/output"
for secret in EXAMPLE_PRIVATE_SMTP_HOST EXAMPLE_PRIVATE_USERNAME EXAMPLE_PRIVATE_PASSWORD EXAMPLE_PRIVATE_SENDER; do
  if grep -q "$secret" "$dir/output"; then echo "Leaked a config secret"; exit 1; fi
done

cat > "$dir/partial.json" <<'JSON'
{
  "smtp_host": "example", "smtp_port": 587, "smtp_user": "private",
  "mailer_autoconfirm": true, "password_min_length": 6,
  "uri_allow_list": ""
}
JSON
bash "$audit" --fixture "$dir/partial.json" > "$dir/output"
grep -qx 'SMTP_METADATA_PRESENT=false' "$dir/output"
grep -qx 'EMAIL_CONFIRMATION=off' "$dir/output"
grep -qx 'PASSWORD_MINIMUM_12=false' "$dir/output"
grep -qx 'CONFIRMATION_REDIRECT_ALLOWED=false' "$dir/output"
grep -qx 'RECOVERY_REDIRECT_ALLOWED=false' "$dir/output"

if bash "$audit" --fixture "$dir/nonexistent.json" >/dev/null 2>&1; then
  echo "Audit unexpectedly accepted a missing config"; exit 1
fi
echo "PASS: email readiness parser, secret redaction, missing metadata, and redirect checks"
