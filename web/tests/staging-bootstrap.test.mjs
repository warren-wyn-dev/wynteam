import assert from "node:assert/strict";
import { test } from "node:test";
import { buildSyntheticPlan, validateBootstrapTarget } from "../scripts/bootstrap-beta2-staging.mjs";

test("staging bootstrap requires the approved project, explicit confirmation and server-only secret", () => {
  const env = {
    STAGING_SUPABASE_URL: "https://yydgdapzlrjmlrjgijkj.supabase.co",
    STAGING_SUPABASE_SERVICE_ROLE_KEY: "sb_secret_synthetic_test_only",
    CONFIRM_WYNOS_STAGING_BOOTSTRAP: "YES",
  };
  assert.equal(validateBootstrapTarget(env), true);
  assert.throws(() => validateBootstrapTarget({ ...env, STAGING_SUPABASE_URL: "https://kqokpocajhfbidcxpvhh.supabase.co" }), /never production/);
  assert.throws(() => validateBootstrapTarget({ ...env, STAGING_SUPABASE_SERVICE_ROLE_KEY: "sb_publishable_nope" }), /server secret/);
  assert.throws(() => validateBootstrapTarget({ ...env, CONFIRM_WYNOS_STAGING_BOOTSTRAP: "NO" }), /confirmation/);
  assert.throws(() => validateBootstrapTarget({ ...env, CI: "true" }), /cannot run in CI/);
});

test("synthetic plan includes each approved staff/member gate and outsiders", () => {
  const users = buildSyntheticPlan("aabbccdd");
  assert.equal(users.length, 7);
  assert.equal(users.filter((user) => user.developer).length, 5);
  assert.deepEqual(users.filter((user) => user.clubRole).map((user) => user.clubRole), ["owner", "admin", "moderator", "member", "member"]);
  assert.equal(users.find((user) => user.role === "nondeveloper_member").developer, false);
  assert.equal(users.find((user) => user.role === "developer_outsider").clubRole, null);
  assert.ok(users.every((user) => user.email.endsWith("@staging.example.invalid")));
  assert.equal(new Set(users.map((user) => user.username)).size, users.length);
});

test("nonhex or user-controlled run IDs cannot become account names", () => {
  assert.throws(() => buildSyntheticPlan("../production"), /hexadecimal/);
});
