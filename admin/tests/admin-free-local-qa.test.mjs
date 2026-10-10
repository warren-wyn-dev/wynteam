import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { validateLocalQaTarget } from "../scripts/check-admin-local-qa.mjs";

const valid = {
  url: "http://127.0.0.1:54321",
  publishableKey: "synthetic_local_only_test_key",
};

test("free-only Admin QA accepts local Supabase API only", () => {
  assert.deepEqual(validateLocalQaTarget(valid), { scope: "local-only" });
  assert.deepEqual(validateLocalQaTarget({ ...valid, url: "http://localhost:54321/" }), { scope: "local-only" });
  assert.deepEqual(validateLocalQaTarget({ ...valid, url: "http://[::1]:54321/" }), { scope: "local-only" });
});

test("free-only Admin QA rejects Production, Stripe Sandbox, staging and arbitrary hosts", () => {
  for (const url of [
    "https://kqokpocajhfbidcxpvhh.supabase.co",
    "https://pcatuxtenluqzjzzwsvl.supabase.co",
    "https://yydgdapzlrjmlrjgijkj.supabase.co",
    "http://192.168.1.100:54321/",
    "http://localhost.evil.example.com:54321/",
    "http://localhost/",
    "https://localhost:54321/",
    "http://user:password@localhost:54321/",
    "http://localhost:54321/private",
    "http://localhost:54321/?token=secrets",
    "",
  ]) {
    assert.throws(() => validateLocalQaTarget({ ...valid, url }), /local|Supabase|localhost-only/i, url);
  }
});

test("free-only QA rejects remote deploy context and missing test keys", () => {
  assert.throws(() => validateLocalQaTarget({ ...valid, vercelEnv: "production" }), /Vercel/);
  assert.throws(() => validateLocalQaTarget({ ...valid, vercelEnv: "preview" }), /Vercel/);
  for (const publishableKey of ["", "  ", "qa_dummy_key", "placeholder", "replace_me_later"]) {
    assert.throws(() => validateLocalQaTarget({ ...valid, publishableKey }), /local Supabase CLI/);
  }
});

test("local-only CLI never prints a key on invalid target", () => {
  const script = fileURLToPath(new URL("../scripts/check-admin-local-qa.mjs", import.meta.url));
  const key = "synthetic_local_only_secret_not_to_log";
  const result = spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: {
      ...process.env,
      VERCEL_ENV: "",
      VERCEL: "",
      NEXT_PUBLIC_SUPABASE_URL: "https://kqokpocajhfbidcxpvhh.supabase.co",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key,
    },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /BLOCKED:/);
  assert.doesNotMatch(result.stdout + result.stderr, new RegExp(key));
});
