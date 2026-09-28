import assert from "node:assert/strict";
import { test } from "node:test";
import { buildSyntheticPlan } from "../scripts/bootstrap-beta2-staging.mjs";
import { validateRoleQaTarget, assertExpectedDenial } from "../scripts/verify-beta2-staging-roles.mjs";
import { readFileSync } from "node:fs";

const suffix = "aabbccdd";
const uuid = (n) => "00000000-0000-4000-8000-" + String(n).padStart(12, "0");
const env = {
  STAGING_SUPABASE_URL: "https://yydgdapzlrjmlrjgijkj.supabase.co",
  STAGING_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_only",
  CONFIRM_WYNOS_STAGING_ROLE_QA: "YES",
};
const manifest = () => ({
  stagingRef: "yydgdapzlrjmlrjgijkj",
  status: "complete",
  suffix,
  accounts: buildSyntheticPlan(suffix).map((person, index) => ({
    ...person, id: uuid(index + 1), password: "SyntheticNeverUsedInTests_" + "x".repeat(32),
  })),
  clubs: [{ id: uuid(20), label: 1 }, { id: uuid(21), label: 2 }],
});

test("authenticated role QA accepts only an explicit staging-only synthetic manifest", () => {
  assert.equal(validateRoleQaTarget(env, manifest()), true);
  assert.equal(validateRoleQaTarget({ ...env, STAGING_SUPABASE_URL: env.STAGING_SUPABASE_URL + "/" }, manifest()), true);
  assert.throws(() => validateRoleQaTarget({ ...env, CI: "true" }, manifest()), /never CI/);
  assert.throws(() => validateRoleQaTarget({ ...env, CONFIRM_WYNOS_STAGING_ROLE_QA: "NO" }, manifest()), /confirmation/);
  assert.throws(() => validateRoleQaTarget({ ...env, STAGING_SUPABASE_URL: "https://kqokpocajhfbidcxpvhh.supabase.co" }, manifest()), /never production/);
  assert.throws(() => validateRoleQaTarget({ ...env, STAGING_SUPABASE_PUBLISHABLE_KEY: "sb_secret_not_allowed" }, manifest()), /no privileged key/);
});

test("role QA refuses incomplete, cross-project, duplicate, renamed and non-synthetic identities", () => {
  const scenarios = [
    (m) => { m.status = "partial-failure-needs-manual-cleanup"; },
    (m) => { m.stagingRef = "kqokpocajhfbidcxpvhh"; },
    (m) => { m.accounts.pop(); },
    (m) => { m.accounts[0].role = "developer_member"; },
    (m) => { m.accounts[0].developer = false; },
    (m) => { m.accounts[0].clubRole = "member"; },
    (m) => { m.accounts[0].email = "real-person@example.com"; },
    (m) => { m.accounts[0].username = "someone_real"; },
    (m) => { m.accounts[0].id = "invalid"; },
    (m) => { m.accounts[0].password = ""; },
    (m) => { m.clubs[1].id = m.clubs[0].id; },
    (m) => { m.clubs = []; },
    (m) => { m.suffix = "../../live"; },
  ];
  for (const mutate of scenarios) {
    const m = manifest();
    mutate(m);
    assert.throws(() => validateRoleQaTarget(env, m));
  }
});


test("role QA accepts ONLY the expected database denial code and exact reason", () => {
  const error = (code, message) => ({ error: { code, message } });
  assert.equal(assertExpectedDenial(
    error("P0001", "Only Club staff can pin messages"), "member pin",
    "P0001", /Only Club staff can pin messages/,
  ), true);
  assert.equal(assertExpectedDenial(
    error("42501", "permission denied for function club_chat_actions_available"),
    "anonymous RPC", "42501", /permission denied/i,
  ), true);
  for (const result of [
    { error: null },
    error("PGRST202", "Could not find function in the schema cache"),
    error("P0001", "Unrelated constraint violation"),
    error("42501", "permission denied"),
    error("ECONNRESET", "Socket disconnected"),
  ]) {
    assert.throws(() => assertExpectedDenial(
      result, "ordinary member pin", "P0001", /Only Club staff can pin messages/,
    ));
  }
});

test("manual staging workflow separates reviewed-source checks and token-bearing deploy runners", () => {
  const workflow = readFileSync(
    new URL("../../.github/workflows/web-beta2-isolated-staging.yml", import.meta.url), "utf8",
  );
  const checks = workflow.split("\n  checks:")[1]?.split("\n  staging:")[0] ?? "";
  const staging = workflow.split("\n  staging:")[1] ?? "";
  assert.match(workflow, /\$\{\{ github\.ref \}\}/);
  assert.match(workflow, /refs\/heads\/main/);
  assert.match(checks, /npm ci --no-audit --no-fund/);
  assert.match(checks, /^\s+run: npm run check$/m, "The unprivileged runner must actually execute the Web check");
  assert.match(checks, /npm run qa:browser/);
  assert.doesNotMatch(checks, /VERCEL_TOKEN|PRODUCTION_VERCEL_PROJECT_ID/);
  assert.match(staging, /needs: \[guard, checks\]/);
  assert.match(staging, /ref: \$\{\{ needs\.guard\.outputs\.reviewed_sha \}\}/);
  assert.match(staging, /VERCEL_TOKEN/);
  assert.match(staging, /vercel@60\.1\.3/);
  assert.match(staging, /id: deploy\n\s+(?:#[^\n]*\n\s+)*working-directory: \./,
    "Staging Vercel Root Directory is web, so CLI must run at repository root");
  assert.match(staging, /Approved isolated project identities verified/);
  assert.match(staging, /profiles\\?select=id&limit=0/,
    "The staging publishable key must be tested through an actual zero-row Data API call");
  assert.match(staging, /if \[ "\$status" != '200' \]; then/,
    "A mismatched project key must fail closed");
  assert.match(staging, /All protected staging routes returned app HTML/);
  assert.match(staging, /grep -q '\/_next\/'/);
  assert.match(staging, /Unexpected\/SSO redirect during protected route/);
  assert.doesNotMatch(staging, /^\s+curl[^\n]*--location\b/m,
    "Protected curl must not send the temporary bypass to another origin");
  assert.doesNotMatch(staging, /node scripts\/assert-isolated-staging\.mjs/);
  assert.doesNotMatch(staging, /^\s+run: npm ci\b/m);
  assert.doesNotMatch(staging, /^\s+run: npm run check\b/m);
  assert.doesNotMatch(staging, /^\s+npm run qa:browser\b/m);
});

test("staging role QA restores only its own pins and proves message content changed", () => {
  const roleQa = readFileSync(new URL("../scripts/verify-beta2-staging-roles.mjs", import.meta.url), "utf8");
  assert.match(roleQa, /const qaPinned = new Set\(\)/);
  assert.match(roleQa, /qaPinned\.add\(row\.id\)/);
  assert.match(roleQa, /for \(const id of qaPinned\)/);
  assert.doesNotMatch(roleQa, /for \(const row of remaining\.data/);
  assert.match(roleQa, /assert\.equal\(edited\.content, expectedEditContent/);
});
