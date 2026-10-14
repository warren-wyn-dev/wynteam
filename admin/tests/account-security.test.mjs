import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

function fixture({ allowed = true, assurance, factors, failure } = {}) {
  const output = ts.transpileModule(readFileSync(new URL("../lib/admin-account-security.ts", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const calls = [];
  const exports = {};
  vm.runInNewContext(output, { exports, require(name) {
    if (name === "@/lib/admin-systems") return { ADMIN_SYSTEMS: ["account", "social", "food", "merchant", "maps"] };
    if (name === "@/lib/auth") return {
      requireAdminRole: async () => ({ access: { available: true, superAdmin: false } }),
      adminCan: (_ctx, system, level) => allowed && system === "account" && level !== "edit",
    };
    assert.equal(name, "@/lib/supabase/server");
    return { createClient: async () => ({ auth: { mfa: {
      getAuthenticatorAssuranceLevel: async () => { calls.push("assurance"); if (failure === "assurance") throw new Error("offline"); return { data: assurance, error: null }; },
      listFactors: async () => { calls.push("factors"); return { data: factors, error: failure === "factors" ? { message: "offline" } : null }; },
    } } }) };
  } });
  return { load: exports.fetchAccountSecurityOverview, calls };
}

test("self security reads return only assurance, counts and effective permissions", async () => {
  const f = fixture({ assurance: { currentLevel: "aal1", nextLevel: "aal2", secret: "private-session-field" },
    factors: { all: [
      { factor_type: "totp", status: "verified", id: "private-factor-id", friendly_name: "private-factor-name" },
      { factor_type: "phone", status: "unverified", phone: "private-phone" },
    ] } });
  const data = JSON.parse(JSON.stringify(await f.load()));
  assert.deepEqual(data.assurance, { currentLevel: "aal1", nextLevel: "aal2" });
  assert.deepEqual(data.factors, { verified: 1, unverified: 1, totp: 1, phone: 0, webauthn: 0 });
  assert.equal(data.permissions.filter(row => row.view).length, 1);
  assert.equal(data.permissions.some(row => row.edit), false);
  assert.doesNotMatch(JSON.stringify(data), /private-/);
});

test("missing account permission rejects before any factor reads", async () => {
  const f = fixture({ allowed: false });
  await assert.rejects(f.load(), /Account access/);
  assert.deepEqual(f.calls, []);
});

test("a failed or unknown security response stays unknown rather than claiming no MFA", async () => {
  const f = fixture({ failure: "assurance", factors: { all: [{ factor_type: "future-factor", status: "verified" }] } });
  const data = await f.load();
  assert.equal(data.assurance, null);
  assert.equal(data.factors, null);
  const other = await fixture({ assurance: { currentLevel: "aal2", nextLevel: "aal2" }, failure: "factors" }).load();
  assert.equal(other.assurance.currentLevel, "aal2");
  assert.equal(other.factors, null);
});
