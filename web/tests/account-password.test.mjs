import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";

const source = readFileSync(new URL("../lib/account-password.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

const USER_ID = "11111111-2222-3333-4444-555555555555";
const OTHER_ID = "22222222-3333-4444-5555-666666666666";
const account = { id: USER_ID, email: "owner@example.test" };

function fixture({
  authenticated = [account, account],
  verifierResult = { data: { user: account }, error: null },
  updatedResult = { data: { user: account }, error: null },
} = {}) {
  const attempts = [];
  const updates = [];
  const verifierOptions = [];
  let reads = 0;

  const mainClient = {
    auth: {
      getUser: async () => {
        const item = authenticated[Math.min(reads++, authenticated.length - 1)];
        if (item instanceof Error) return { data: { user: null }, error: item };
        return { data: { user: item }, error: null };
      },
      updateUser: async (data) => {
        updates.push(data);
        return updatedResult;
      },
    },
  };
  const module = { exports: {} };
  const dependency = (name) => {
    if (name === "@supabase/supabase-js") {
      return {
        createClient: (url, key, options) => {
          verifierOptions.push({ url, key, options });
          return {
            auth: {
              signInWithPassword: async (credentials) => {
                attempts.push(credentials);
                return verifierResult;
              },
            },
          };
        },
      };
    }
    if (name === "@/lib/signup-password-policy") return { MIN_SIGNUP_PASSWORD_LENGTH: 12 };
    throw new Error(`Unexpected dependency ${name}`);
  };
  new Function("require", "module", "exports", compiled)(dependency, module, module.exports);
  return { ...module.exports, mainClient, attempts, updates, verifierOptions, get reads() { return reads; } };
}

process.env.NEXT_PUBLIC_SUPABASE_URL = "https://mocked-auth.supabase.co";
process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_mocked_only";

test("new password validation rejects missing, short, mismatched and reused passwords", () => {
  const { validatePasswordChange: validate } = fixture();
  assert.match(validate("", "abcdefgh1234", "abcdefgh1234"), /ครบ/);
  assert.match(validate("old-pass", "abcdefgh123", "abcdefgh123"), /12/);
  assert.match(validate("old-pass", "abcdefgh1234", "differentpass"), /ไม่ตรง/);
  assert.match(validate("abcdefgh1234", "abcdefgh1234", "abcdefgh1234"), /แตกต่าง/);
  assert.equal(validate("old-pass", "abcdefgh1234", "abcdefgh1234"), null);
});

test("verifies current password in a separate, non-persistent client before updating", async () => {
  const f = fixture();
  await f.changeAccountPassword(f.mainClient, USER_ID, "my-old-password", "my-new-password-123");
  assert.deepEqual(f.attempts, [{ email: account.email, password: "my-old-password" }]);
  assert.deepEqual(f.updates, [{ password: "my-new-password-123" }]);
  assert.equal(f.verifierOptions.length, 1);
  assert.equal(f.verifierOptions[0].options.auth.persistSession, false);
  assert.equal(f.verifierOptions[0].options.auth.autoRefreshToken, false);
  assert.equal(f.verifierOptions[0].options.auth.detectSessionInUrl, false);
  assert.equal(f.reads, 2);
});

test("rejects incorrect current password without changing any session or credentials", async () => {
  const f = fixture({ verifierResult: { data: { user: null }, error: new Error("Invalid login credentials") } });
  await assert.rejects(
    f.changeAccountPassword(f.mainClient, USER_ID, "wrong", "my-new-password-123"),
    (error) => error.code === "WRONG_PASSWORD",
  );
  assert.deepEqual(f.updates, []);
});

test("does not allow changing a different account after an in-flight account switch", async () => {
  const f = fixture({ authenticated: [account, { id: OTHER_ID, email: "other@example.test" }] });
  await assert.rejects(
    f.changeAccountPassword(f.mainClient, USER_ID, "old-password", "my-new-password-123"),
    (error) => error.code === "ACCOUNT_CHANGED",
  );
  assert.equal(f.attempts.length, 1);
  assert.deepEqual(f.updates, []);
});

test("blocks wrong initial account and mismatched verifier user", async () => {
  const wrongInitial = fixture({ authenticated: [{ id: OTHER_ID, email: "other@example.test" }] });
  await assert.rejects(
    wrongInitial.changeAccountPassword(wrongInitial.mainClient, USER_ID, "old-password", "my-new-password-123"),
    (error) => error.code === "ACCOUNT_CHANGED",
  );
  assert.deepEqual(wrongInitial.attempts, []);
  const wrongVerifier = fixture({ verifierResult: { data: { user: { id: OTHER_ID } }, error: null } });
  await assert.rejects(
    wrongVerifier.changeAccountPassword(wrongVerifier.mainClient, USER_ID, "old-password", "my-new-password-123"),
    (error) => error.code === "WRONG_PASSWORD",
  );
  assert.deepEqual(wrongVerifier.updates, []);
});

test("requires an account email for old-password verification", async () => {
  const f = fixture({ authenticated: [{ id: USER_ID, email: null }] });
  await assert.rejects(
    f.changeAccountPassword(f.mainClient, USER_ID, "old-password", "my-new-password-123"),
    (error) => error.code === "NO_EMAIL",
  );
  assert.equal(f.verifierOptions.length, 0);
});

test("maps server-side reauthentication requirement without reporting success", async () => {
  const f = fixture({
    updatedResult: { data: { user: null }, error: { code: "reauthentication_needed" } },
  });
  await assert.rejects(
    f.changeAccountPassword(f.mainClient, USER_ID, "old-password", "my-new-password-123"),
    (error) => error.code === "REAUTHENTICATION_REQUIRED",
  );
  assert.equal(f.updates.length, 1);
});

test("invalid new credentials are rejected before any network request", async () => {
  const f = fixture();
  await assert.rejects(
    f.changeAccountPassword(f.mainClient, USER_ID, "my-old-password", "tiny"),
    (error) => error.code === "INVALID_FORM",
  );
  assert.equal(f.reads, 0);
  assert.deepEqual(f.attempts, []);
  assert.deepEqual(f.updates, []);
});
