import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";
import { createClient } from "@supabase/supabase-js";

function loadMetrics(fetch, timeout = (ms) => AbortSignal.timeout(ms)) {
  const client = createClient("https://synthetic.supabase.invalid", "synthetic-publishable-key", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch },
  });
  const source = readFileSync(new URL("../lib/admin-metrics.ts", import.meta.url), "utf8");
  const output = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const exports = {};
  vm.runInNewContext(output, {
    exports,
    AbortSignal: { timeout },
    require(id) {
      assert.equal(id, "@/lib/supabase/server");
      return { createClient: async () => client };
    },
  });
  return exports;
}

test("dashboard reads retain RPC contracts and independently recover from failed sources", async () => {
  const requests = [];
  const metrics = { dau: 3, reports_pending: 1 };
  const signupCounts = { today: 1, this_week: 2, this_month: 4, this_year: 8 };
  const api = loadMetrics(async (url, options) => {
    const name = new URL(url).pathname.split("/").at(-1);
    requests.push({ name, body: JSON.parse(options.body), signal: options.signal });
    if (name === "admin_dashboard_trends") {
      return Response.json({ message: "Synthetic unavailable source", code: "TEST" }, { status: 503 });
    }
    const data = name === "admin_dashboard_metrics" ? metrics
      : name === "admin_signup_counts" ? signupCounts
      : [
          { day: "2026-10-13", active_users: "4" },
          { day: "2026-10-12", active_users: 2 },
          { day: "2026-10-11", active_users: "invalid" },
        ];
    return Response.json(data);
  });
  const result = await Promise.allSettled([
    api.fetchAdminDashboardMetrics(), api.fetchAdminDashboardTrends(),
    api.fetchSignupCounts(), api.fetchAdminActivityTrend(14),
  ]);
  assert.equal(result[0].status, "fulfilled");
  assert.deepEqual(result[0].value, metrics);
  assert.equal(result[1].status, "rejected");
  assert.deepEqual(result[2].value, signupCounts);
  assert.equal(JSON.stringify(result[3].value), JSON.stringify([
    { date: "2026-10-12", count: 2 }, { date: "2026-10-13", count: 4 },
  ]));
  assert.equal(requests.length, 4);
  assert.deepEqual(requests.find((r) => r.name === "admin_activity_trend").body, { p_days: 14 });
  assert.ok(requests.every((r) => r.signal instanceof AbortSignal));
});

test("all dashboard read requests terminate on their timeout instead of leaving loading stuck", async () => {
  const deadlines = [];
  const aborted = [];
  const api = loadMetrics((url, options) => new Promise((resolve, reject) => {
    const cancel = () => {
      aborted.push(new URL(url).pathname.split("/").at(-1));
      reject(new DOMException("Synthetic request aborted", "AbortError"));
    };
    if (options.signal.aborted) cancel();
    else options.signal.addEventListener("abort", cancel, { once: true });
  }), (ms) => {
    deadlines.push(ms);
    return AbortSignal.timeout(20);
  });
  // AbortSignal.timeout's timer is unref'ed; keep the test alive until it fires.
  const keepAlive = setTimeout(() => {}, 1000);
  try {
    const result = await Promise.allSettled([
      api.fetchAdminDashboardMetrics(), api.fetchAdminDashboardTrends(),
      api.fetchSignupCounts(), api.fetchAdminActivityTrend(), api.fetchFeedAlgorithmDashboard(),
    ]);
    assert.ok(result.every((r) => r.status === "rejected"));
    assert.deepEqual(deadlines, [10_000, 10_000, 10_000, 10_000, 10_000]);
    assert.equal(aborted.length, 5);
  } finally {
    clearTimeout(keepAlive);
  }
});

test("missing metric rows report failure rather than inventing zeroes", async () => {
  const api = loadMetrics(async () => Response.json(null));
  await assert.rejects(api.fetchAdminDashboardMetrics(), /returned no row/);
  await assert.rejects(api.fetchSignupCounts(), /returned no row/);
});
