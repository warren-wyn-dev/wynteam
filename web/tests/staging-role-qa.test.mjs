import assert from "node:assert/strict";
import { test } from "node:test";
import { buildSyntheticPlan } from "../scripts/bootstrap-beta2-staging.mjs";
import { validateRoleQaTarget } from "../scripts/verify-beta2-staging-roles.mjs";

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
