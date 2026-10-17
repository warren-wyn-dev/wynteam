import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";
import { createClient } from "@supabase/supabase-js";

function load(fetch = async () => Response.json(null), timeout = ms => AbortSignal.timeout(ms)) {
  const client = createClient("https://synthetic.supabase.invalid", "synthetic-publishable-key", {
    auth: { persistSession: false, autoRefreshToken: false }, global: { fetch },
  });
  const output = ts.transpileModule(readFileSync(new URL("../lib/admin-food-payments.ts", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const exports = {};
  vm.runInNewContext(output, { exports, AbortSignal: { timeout }, require(name) {
    assert.equal(name, "@/lib/supabase/server"); return { createClient: async () => client };
  } });
  return exports;
}

const params = { query: "ร้านทดสอบ", filter: "review", provider: "stripe", from: "2026-10-01", to: "2026-10-14", page: 2 };

test("payment query keeps date, filter and pagination contracts with a bounded request", async () => {
  const requests = [];
  const api = load(async (url, options) => {
    requests.push({ url, body: JSON.parse(options.body), signal: options.signal });
    return Response.json({ rows: [], total_count: 0, page_size: 25, offset: 25, as_of: "2026-10-14T00:00:00Z" });
  });
  assert.equal((await api.fetchFoodPaymentMonitor(params)).total_count, 0);
  assert.deepEqual(requests[0].body, { p_query: params.query, p_filter: "review", p_provider: "stripe", p_from: params.from, p_to: params.to, p_limit: 25, p_offset: 25 });
  assert.ok(requests[0].signal instanceof AbortSignal);
});

test("malformed responses and outages cannot become empty customer or payment histories", async () => {
  await assert.rejects(load().fetchFoodPaymentMonitor(params), /invalid_observation/);
  const missing = load(async () => Response.json({ total_count: 0, as_of: "now" }));
  await assert.rejects(missing.fetchFoodCustomerHistory({ buyerId: null, query: "", page: 1 }), /invalid_observation/);
  const failed = load(async () => Response.json({ message: "fixture unavailable" }, { status: 503 }));
  await assert.rejects(failed.fetchFoodPaymentMonitor(params), error => error.message === "fixture unavailable");
});

test("calendar bounds reject invalid dates, reversed windows and excessive range", () => {
  const api = load();
  assert.equal(JSON.stringify(api.foodMonitorDates("2024-02-29", "2024-03-01")), JSON.stringify({ from: "2024-02-29", to: "2024-03-01" }));
  for (const [from, to] of [["2026-02-30", "2026-03-01"], ["2026-10-15", "2026-10-14"], ["2025-01-01", "2026-10-14"]]) {
    assert.throws(() => api.foodMonitorDates(from, to), /invalid_dates/);
  }
  assert.equal(api.observationPage("999999999999999999"), 4001);
  assert.equal(api.observationPage("-1"), 1);
  assert.equal(api.foodHistoryBuyer("not-a-uuid"), null);
});
