#!/usr/bin/env bash
# Offline regression for production Auth policy sync. Never contacts Supabase.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat > "$work/bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail
output=""
payload=""
write_status=false
method=GET
while (( $# > 0 )); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -w) write_status=true; shift 2 ;;
    --request) method="$2"; shift 2 ;;
    --data-binary) payload="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [ "$method" = PATCH ]; then
  if [ "$FAKE_PATCH_STATUS" != 200 ]; then
    printf '{"message":"denied"}' > "$output"
    if [ "$write_status" = true ]; then printf '%s' "$FAKE_PATCH_STATUS"; fi
    exit 0
  fi
  next=$(mktemp)
  jq -s '.[0] * .[1]' "$FAKE_AUTH_STATE" "${payload#@}" > "$next"
  mv "$next" "$FAKE_AUTH_STATE"
  printf 200 > "$output"
  printf 'patched\n' >> "$FAKE_PATCH_LOG"
  if [ "$write_status" = true ]; then printf 200; fi
else
  cp "$FAKE_AUTH_STATE" "$output"
  if [ "$write_status" = true ]; then printf 200; fi
fi
FAKE_CURL
chmod +x "$work/bin/curl"
export PATH="$work/bin:$PATH"
export FAKE_AUTH_STATE="$work/current.json"
export FAKE_PATCH_LOG="$work/patches.log"
export FAKE_PATCH_STATUS=200
export SUPABASE_ACCESS_TOKEN=offline-test-only
: > "$FAKE_PATCH_LOG"

# Raise minimum while preserving existing redirect and unrelated Auth settings.
cat > "$FAKE_AUTH_STATE" <<'JSON'
{"password_min_length":6,"uri_allow_list":"https://wynos.online/welcome,https://wynos.online/login","mailer_autoconfirm":true}
JSON
bash "$root/.github/scripts/sync-auth-password-policy.sh"
jq -e '(.password_min_length == 12) and (.mailer_autoconfirm == true) and
       (.uri_allow_list == "https://wynos.online/welcome,https://wynos.online/login,https://wynos.online/auth/callback,https://wynos.online/reset-password")' "$FAKE_AUTH_STATE" >/dev/null
test "$(wc -l < "$FAKE_PATCH_LOG")" -eq 1

# Repeated production workflow must not repeatedly change Auth config.
bash "$root/.github/scripts/sync-auth-password-policy.sh"
test "$(wc -l < "$FAKE_PATCH_LOG")" -eq 1

# Respect a pre-existing stronger password minimum.
cat > "$FAKE_AUTH_STATE" <<'JSON'
{"password_min_length":14,"uri_allow_list":"https://wynos.online/welcome"}
JSON
bash "$root/.github/scripts/sync-auth-password-policy.sh"
jq -e '.password_min_length == 14 and
       (.uri_allow_list | contains("https://wynos.online/auth/callback")) and
       (.uri_allow_list | contains("https://wynos.online/reset-password"))' "$FAKE_AUTH_STATE" >/dev/null
test "$(wc -l < "$FAKE_PATCH_LOG")" -eq 2

# Expired/underprivileged management token must cause an explicit failure.
cat > "$FAKE_AUTH_STATE" <<'JSON'
{"password_min_length":6,"uri_allow_list":""}
JSON
export FAKE_PATCH_STATUS=403
if bash "$root/.github/scripts/sync-auth-password-policy.sh" >/dev/null 2>&1; then
  echo "Unexpected success on HTTP 403" >&2
  exit 1
fi
test "$(wc -l < "$FAKE_PATCH_LOG")" -eq 2
echo "All Web Beta1 Auth policy rollout regressions passed"
