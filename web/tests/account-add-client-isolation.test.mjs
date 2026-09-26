import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/supabase/browser.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const A = "wynos.account.11111111-1111-4111-8111-111111111111";
const B = "wynos.account.22222222-2222-4222-8222-222222222222";

function fixture() {
  const calls = [];
  let pathname = "/profile/me";
  let search = "";
  let pending = null;
  let intent = null;
  const exports = {};
  const create = (kind) => (url, key, options) => {
    const result = { kind, options };
    calls.push(result);
    return result;
  };
  const browser = {
    location: {
      get pathname() { return pathname; },
      get search() { return search; },
    },
  };
  runInNewContext(compiled, {
    exports,
    URLSearchParams,
    window: browser,
    process: {
      env: {
        NEXT_PUBLIC_SUPABASE_URL: "https://mock.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "public-mock",
      },
    },
    require: (name) => {
      if (name === "@supabase/ssr") return { createBrowserClient: create("cookie") };
      if (name === "@supabase/supabase-js") return { createClient: create("slot") };
      if (name === "@/lib/account-registry") return { getActiveAccountStorageKey: () => A };
      if (name === "@/lib/pending-account-add") return { getPendingAddAccountSlot: () => pending, getAddAccountIntentSlot: () => intent };
      throw new Error("Unexpected dependency " + name);
    },
  });
  return {
    api: exports, calls,
    path: (p, q = "") => { pathname = p; search = q; },
    setPending: (slot) => { pending = slot; },
    setIntent: (slot) => { intent = slot; },
  };
}

test("signup explicitly selects B even if Next soft navigation still reports A's route", () => {
  const f = fixture();
  const original = f.api.getSupabaseBrowserClient();
  assert.equal(original.options.auth.storageKey, A);
  f.path("/account/add");
  f.setPending(B);
  f.setIntent(B);
  const newAccount = f.api.getSignupAuthClient();
  assert.equal(newAccount.options.auth.storageKey, B);
  assert.equal(newAccount.options.auth.detectSessionInUrl, false);
  assert.equal(f.api.getSupabaseBrowserClient(), original);
  assert.equal(f.calls.length, 2);
});

test("Google and email confirmation callbacks never exchange B's code in A's client", () => {
  const f = fixture();
  f.path("/profile/me");
  const original = f.api.getSupabaseBrowserClient();
  f.setPending(B);
  f.path("/account/add", "?slot=" + B + "&oauth=1&code=example");
  const googleClient = f.api.getSupabaseBrowserClient();
  assert.equal(googleClient.options.auth.storageKey, B);
  assert.equal(googleClient.options.auth.detectSessionInUrl, false);
  f.path("/auth/callback", "?slot=" + B + "&code=example");
  assert.equal(f.api.getSupabaseBrowserClient(), googleClient);
  f.path("/profile/me");
  assert.equal(f.api.getSupabaseBrowserClient(), original);
  assert.equal(f.calls.length, 2);
});

test("an expired B signup refuses to fall back to A's already signed-in credentials", () => {
  const f = fixture();
  const active = f.api.getSupabaseBrowserClient();
  f.setIntent(B);
  assert.equal(f.api.getSignupAuthClient(), null);
  assert.equal(f.api.getSupabaseBrowserClient(), active);
  f.setPending(B);
  assert.equal(f.api.getSignupAuthClient().options.auth.storageKey, B);
});

test("normal signup in another tab does not read a second account's global pending slot", () => {
  const f = fixture();
  const active = f.api.getSupabaseBrowserClient();
  f.setPending(B);
  assert.equal(f.api.getSignupAuthClient(), active);
  f.setIntent(A);
  assert.equal(f.api.getSignupAuthClient(), null);
  f.setIntent(B);
  assert.equal(f.api.getSignupAuthClient().options.auth.storageKey, B);
});
