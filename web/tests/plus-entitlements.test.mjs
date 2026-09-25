import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { test } from "node:test";
import ts from "typescript";

function load() {
  const source = readFileSync(new URL("../lib/plus-membership.ts", import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: "plus-membership.ts",
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, { exports, Date, Number });
  return exports;
}
const now = Date.parse("2026-09-26T10:00:00Z");
const active = {
  tier: "plus", status: "active", current_period_end: "2026-10-01T00:00:00Z",
  cancel_at_period_end: false,
};

test("only active or trialing unexpired periods are eligible", () => {
  const { hasCurrentPlusMembership } = load();
  assert.equal(hasCurrentPlusMembership(active, now), true);
  assert.equal(hasCurrentPlusMembership({ ...active, status: "trialing" }, now), true);
  for (const status of ["past_due","canceled","incomplete","unpaid"]) {
    assert.equal(hasCurrentPlusMembership({ ...active, status }, now), false, status);
  }
  assert.equal(hasCurrentPlusMembership({ ...active, current_period_end: null }, now), false);
  assert.equal(hasCurrentPlusMembership({ ...active, current_period_end: "2026-09-25T00:00:00Z" }, now), false);
  assert.equal(hasCurrentPlusMembership({ ...active, tier: "unexpected" }, now), false);
  assert.equal(hasCurrentPlusMembership(null, now), false);
});

test("missing DB table fails closed and never invents membership", async () => {
  const { fetchPlusMembership } = load();
  const fake = {
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: async () => ({ data: null, error: { code: "42P01" } }),
        }),
      }),
    }),
  };
  const result = await fetchPlusMembership(fake, "A");
  assert.equal(result.available, false);
  assert.equal(result.membership, null);
});

test("reader filters by account and selects no billing identifiers", async () => {
  const { fetchPlusMembership } = load();
  const calls = [];
  const fake = {
    from: (table) => {
      calls.push(["table",table]);
      return {
        select: (columns) => {
          calls.push(["columns",columns]);
          return {
            eq: (key,value) => {
              calls.push(["filter",key,value]);
              return { maybeSingle: async () => ({ data: active, error: null }) };
            },
          };
        },
      };
    },
  };
  const result = await fetchPlusMembership(fake, "A");
  assert.equal(result.available, true);
  assert.equal(result.membership.status, "active");
  assert.deepEqual(calls, [
    ["table","wynos_plus_memberships"],
    ["columns","tier,status,current_period_end,cancel_at_period_end"],
    ["filter","user_id","A"],
  ]);
});

test("schema denies client writes and UI never silently starts checkout", () => {
  const sql = readFileSync(new URL("../../supabase/migrations_wyn191_plus_memberships.sql", import.meta.url), "utf8").toLowerCase();
  assert.match(sql, /enable row level security/);
  assert.match(sql, /grant select on table public\.wynos_plus_memberships to authenticated/);
  assert.match(sql, /auth\.uid\(\)\)\s*=\s*user_id/);
  assert.match(sql, /revoke all on table internal\.wynos_plus_billing_refs from public,anon,authenticated/);
  assert.doesNotMatch(sql, /grant (insert|update|delete|all) on table public\.wynos_plus_memberships to authenticated/);
  const ui = readFileSync(new URL("../components/plus-route.tsx", import.meta.url), "utf8");
  assert.match(ui, /disabled aria-disabled="true"/);
  assert.doesNotMatch(ui, /checkout|confirmPayment|createSubscription/);
});
