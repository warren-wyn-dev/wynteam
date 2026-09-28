import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
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


test("staging-only privilege migration requires empty database and preserves the 15 anonymous functions in both schemas", () => {
  const sql = readFileSync(new URL("../../docs/engineering/staging-only/WEB_BETA2_ANON_GRANTS.sql", import.meta.url), "utf8");
  assert.match(sql, /STAGING ONLY\. DO NOT APPLY TO PRODUCTION/);
  assert.match(sql, /count\(\*\) FROM auth\.users\) <> 0/);
  assert.match(sql, /count\(\*\) FROM public\.profiles\) <> 0/);
  assert.match(sql, /REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon/);
  assert.equal((sql.match(/GRANT EXECUTE ON FUNCTION public\./g) ?? []).length, 15);
  for (const restricted of ["is_developer_account", "edit_club_channel_message", "set_club_channel_message_pin", "search_club_channel_messages", "create_club_announcement", "update_club_announcement", "delete_club_announcement"]) {
    assert.doesNotMatch(sql, new RegExp("GRANT EXECUTE ON FUNCTION public\\." + restricted + "\\([^\\n]* TO anon"));
  }
});
