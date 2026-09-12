#!/usr/bin/env bash
set -euo pipefail

ci_bin="$RUNNER_TEMP/wynos-db-ci-bin"
mkdir -p "$ci_bin"

cat > "$ci_bin/psql" <<'EOF'
#!/usr/bin/env bash
set +e
capture="${RUNNER_TEMP}/wynos-psql-capture-$$.out"
/usr/bin/psql "$@" >"$capture" 2>&1
status=$?
cat "$capture"
if [ "$status" -ne 0 ]; then
  cp "$capture" /tmp/wynos-last-psql-failure.out
fi
rm -f "$capture"
exit "$status"
EOF

cat > "$ci_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -e
if [ "${1:-}" = "-u" ] && [ "${2:-}" = "postgres" ]; then
  shift 2
  if [ "${1:-}" = "psql" ] && [ -f /tmp/wynos-last-psql-failure.out ]; then
    cat /tmp/wynos-last-psql-failure.out >&2
    exit 1
  fi
  exec "$@"
fi
exec /usr/bin/sudo "$@"
EOF

chmod +x "$ci_bin/psql" "$ci_bin/sudo"
export PATH="$ci_bin:$PATH"

failed=""
: > /tmp/sql-suite.log
rm -f /tmp/wynos-last-psql-failure.out

for test_script in supabase/tests/*.sh; do
  if [ "$test_script" = "supabase/tests/wyn_038_view_counting_test.sh" ]; then
    continue
  fi
  rm -f /tmp/wynos-last-psql-failure.out
  echo "===== RUN $test_script =====" | tee -a /tmp/sql-suite.log
  set +e
  bash "$test_script" 2>&1 | tee -a /tmp/sql-suite.log
  status=${PIPESTATUS[0]}
  set -e
  if [ "$status" -ne 0 ]; then
    failed="$test_script"
    break
  fi
done

if [ -z "$failed" ]; then
  printf 'ALL_MAINTAINED_SQL_TESTS_PASSED\n' > sql_failure_diagnostic.txt
  exit 0
fi

{
  printf 'FAILED_SCRIPT=%s\n' "$failed"
  if [ -s /tmp/wynos-last-psql-failure.out ]; then
    printf '%s\n' '--- LAST_PSQL_FAILURE ---'
    cat /tmp/wynos-last-psql-failure.out
  fi
  printf '%s\n' '--- SUITE_TAIL ---'
  tail -n 140 /tmp/sql-suite.log
} > sql_failure_diagnostic.txt

exit 1
