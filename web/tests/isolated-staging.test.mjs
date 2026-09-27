import assert from "node:assert/strict";
import { test } from "node:test";
import { assertIsolatedStaging } from "../scripts/assert-isolated-staging.mjs";

const baseline = () => ({
  STAGING_SUPABASE_URL: "https://yydgdapzlrjmlrjgijkj.supabase.co",
  STAGING_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_staging",
  PRODUCTION_SUPABASE_URL: "https://kqokpocajhfbidcxpvhh.supabase.co",
  PRODUCTION_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_production",
  STAGING_VERCEL_PROJECT_ID: "prj_70GIbp0o056AOPsVUAie9CROED7r",
  PRODUCTION_VERCEL_PROJECT_ID: "prj_productionExample",
  VERCEL_ORG_ID: "team_example",
});

test("isolated staging accepts only its own approved project IDs", () => {
  assert.equal(assertIsolatedStaging(baseline()), true);
});

test("missing credentials and project identifiers fail closed", () => {
  for (const field of Object.keys(baseline())) {
    const env = baseline();
    env[field] = "";
    assert.throws(() => assertIsolatedStaging(env), new RegExp(field));
  }
});

test("staging cannot point to production, third-party Supabase, or plain HTTP", () => {
  for (const url of [
    baseline().PRODUCTION_SUPABASE_URL,
    "https://unapproved.supabase.co",
    "http://yydgdapzlrjmlrjgijkj.supabase.co",
    "https://yydgdapzlrjmlrjgijkj.supabase.co.evil.example",
    "https://yydgdapzlrjmlrjgijkj.supabase.co/path",
  ]) {
    assert.throws(() => assertIsolatedStaging({ ...baseline(), STAGING_SUPABASE_URL: url }));
  }
  assert.throws(() => assertIsolatedStaging({ ...baseline(), PRODUCTION_SUPABASE_URL: baseline().STAGING_SUPABASE_URL }));
});

test("staging rejects secret keys, shared production keys and shared Vercel projects", () => {
  assert.throws(() => assertIsolatedStaging({ ...baseline(), STAGING_SUPABASE_PUBLISHABLE_KEY: "sb_secret_wrong" }), /publishable key/);
  assert.throws(() => assertIsolatedStaging({ ...baseline(), STAGING_SUPABASE_PUBLISHABLE_KEY: baseline().PRODUCTION_SUPABASE_PUBLISHABLE_KEY }), /must differ/);
  assert.throws(() => assertIsolatedStaging({ ...baseline(), STAGING_VERCEL_PROJECT_ID: baseline().PRODUCTION_VERCEL_PROJECT_ID }), /Founder-approved isolated staging project/);
  assert.throws(() => assertIsolatedStaging({ ...baseline(), STAGING_VERCEL_PROJECT_ID: "prj_otherProtectedProject" }), /Founder-approved isolated staging project/);
});
