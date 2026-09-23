#!/usr/bin/env bash
# Apply only the non-disruptive Web Beta1 Auth policy after the web deploy.
# Email confirmation is deliberately NOT enabled by automation: first test
# outbound email and the PKCE callback against a real signup.
set -euo pipefail

if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "::error::SUPABASE_ACCESS_TOKEN is not configured"
  exit 1
fi

PROJECT_REF="kqokpocajhfbidcxpvhh"
CALLBACK="https://wynos.online/auth/callback"
RESET_CALLBACK="https://wynos.online/reset-password"
API="https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth"

before=$(mktemp)
payload=$(mktemp)
after=$(mktemp)
trap 'rm -f "$before" "$payload" "$after"' EXIT

# Never print the Auth config: it can include SMTP and OAuth secrets.
curl --fail --silent --show-error --retry 2 --max-time 30 \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -o "$before" "$API"

old_min=$(jq -r '.password_min_length // 0' "$before")
if ! [[ "$old_min" =~ ^[0-9]+$ ]]; then
  echo "::error::Unexpected Supabase password_min_length"
  exit 1
fi
target_min=12
if (( old_min > target_min )); then target_min=$old_min; fi

# uri_allow_list is a comma-separated string. Keep every existing callback,
# especially those used for Google OAuth and password recovery.
existing=$(jq -r '.uri_allow_list // ""' "$before")
updated="$existing"
for required in "$CALLBACK" "$RESET_CALLBACK"; do
  if ! printf '%s' "$updated" | tr ',' '\n' | grep -Fxq "$required"; then
    if [ -n "$updated" ]; then updated="$updated,$required"; else updated="$required"; fi
  fi
done

if (( old_min >= 12 )) && [ "$updated" = "$existing" ]; then
  echo "Auth minimum and redirect allowlist already satisfy Web Beta1 policy"
  exit 0
fi

jq -n --arg list "$updated" --argjson min "$target_min" \
  '{password_min_length: $min, uri_allow_list: $list}' > "$payload"

status=$(curl --silent --show-error --retry 2 --max-time 30 \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --request PATCH --data-binary "@$payload" \
  -o "$after" -w '%{http_code}' "$API")
if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
  echo "::error::Supabase Auth update failed (HTTP $status)"
  exit 1
fi

# GET again rather than trusting a write response.
curl --fail --silent --show-error --retry 2 --max-time 30 \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -o "$after" "$API"

jq -e --arg cb "$CALLBACK" --arg reset "$RESET_CALLBACK" \
  '(.password_min_length >= 12) and
   ((.uri_allow_list // "" | split(",") | map(gsub("^\\s+|\\s+$"; "")) | index($cb)) != null) and
   ((.uri_allow_list // "" | split(",") | map(gsub("^\\s+|\\s+$"; "")) | index($reset)) != null)' \
  "$after" >/dev/null || {
    echo "::error::Supabase Auth config failed post-update verification"
    exit 1
  }

echo "Supabase Auth password minimum, confirmation and recovery redirects verified"
echo "Email confirmation remains unchanged pending email-delivery QA"
