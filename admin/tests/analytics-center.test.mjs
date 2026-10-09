import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { safeMetric, safeDaySeries, safeMerchantSample, validIsoDay } from "../lib/analytics-series.mjs";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Analytics metric validation accepts genuine zero without inventing absent values", () => {
  assert.equal(safeMetric(0), 0);
  assert.equal(safeMetric("42"), 42);
  assert.equal(safeMetric(124.75, { integer: false }), 124.75);
  for (const value of [null, undefined, "", "not-ready", NaN, Infinity, -5, "1e8", {}, 2.5]) {
    assert.equal(safeMetric(value), null, String(value));
  }
  assert.equal(safeMetric(-0.5, { integer: false }), null);
});

test("Social and Food trends retain only trustworthy source days; no fake zero fill", () => {
  assert.ok(validIsoDay("2026-10-09"));
  assert.equal(validIsoDay("2026-02-30"), false);
  assert.equal(validIsoDay("2026-13-01"), false);
  const unordered = [
    { date: "2026-10-09", count: 8 },
    { date: "2026-10-07", count: 0 },
  ];
  assert.deepEqual(safeDaySeries(unordered, { dateKey: "date", countKey: "count", limit: 14 }), [
    { day: "2026-10-07", count: 0 },
    { day: "2026-10-09", count: 8 },
  ]);
  const seven = Array.from({ length: 8 }, (_, index) => ({
    day: "2026-10-" + String(index + 1).padStart(2, "0"), orders: index,
  }));
  assert.equal(safeDaySeries(seven, { dateKey: "day", countKey: "orders", limit: 7 }).length, 7);
  assert.deepEqual(safeDaySeries([], { dateKey: "date", countKey: "count", limit: 14 }), []);
  for (const bad of [
    [{ date: "2026-02-30", count: 7 }],
    [{ date: "2026-10-09", count: null }],
    [{ date: "2026-10-09", count: -1 }],
    [{ date: "2026-10-09", count: Infinity }],
    [{ date: "2026-10-09", count: 7 }, { date: "2026-10-09", count: 2 }],
  ]) assert.equal(safeDaySeries(bad, { dateKey: "date", countKey: "count" }), null);
  assert.equal(safeDaySeries(Array(41).fill(null), { dateKey: "date", countKey: "count" }), null);
});

test("Merchant sample does not present capped or invalid rows as full population", () => {
  const rows = [
    { id: "a", status: "pending", contact_name: "SECRET" },
    { id: "b", status: "approved", contact_name: "SECRET2" },
    { id: "c", status: "rejected" },
  ];
  assert.deepEqual(safeMerchantSample(rows, 200), {
    pending: 1, approved: 1, rejected: 1, sampled: 3, capped: false,
  });
  assert.equal(safeMerchantSample(rows.slice(0, 2), 2).capped, true);
  assert.equal(safeMerchantSample(rows, 2), null);
  assert.equal(safeMerchantSample([{ id: "a", status: "pending" }, { id: "a", status: "pending" }]), null);
  assert.equal(safeMerchantSample([{ id: "b", status: "unknown" }]), null);
  assert.equal(Object.keys(safeMerchantSample(rows)).includes("contact_name"), false);
});

test("Analytics route is Admin-only at both server boundaries; Moderator never gets Food/finance", () => {
  const page = read("../app/(admin)/analytics/page.tsx");
  const loader = read("../lib/admin-analytics.ts");
  const nav = read("../lib/admin-nav.ts");
  const overview = read("../app/(admin)/page.tsx");
  const ci = read("../../.github/workflows/ci.yml");
  assert.match(page, /await requireAdminRole\(\)/);
  assert.match(loader, /await requireAdminRole\(\)/);
  assert.match(page, /role !== "admin"\) notFound\(\)/);
  assert.match(loader, /role !== "admin"\) notFound\(\)/);
  assert.match(nav, /href: "\/analytics"[^\n]+roles: \["admin"\]/);
  assert.match(overview, /href: "\/analytics"[^\n]+roles: \["admin"\]/);
  assert.match(ci, /for route in \/ \/analytics \/social/);
});

test("Analytics reuses audited existing RPC adapters, never invents totals or records", () => {
  const loader = read("../lib/admin-analytics.ts");
  const page = read("../app/(admin)/analytics/page.tsx");
  assert.match(loader, /fetchAdminDashboardMetrics\(\)/);
  assert.match(loader, /fetchAdminDashboardTrends\(\)/);
  assert.match(loader, /fetchSignupCounts\(\)/);
  assert.match(loader, /fetchAdminFoodOverview\(\)/);
  assert.match(loader, /fetchMerchantApplications\(\)/);
  assert.match(loader, /safeMerchantSample\(rows, MERCHANT_APPLICATION_LIMIT\)/);
  assert.match(loader, /Promise\.all\(\[/);
  assert.match(loader, /status: "unavailable"/);
  assert.match(loader, /ไม่ใช่ยอด Merchant ทั้งระบบ/);
  assert.match(page, /panel\.status === "unavailable"/);
  assert.match(page, /role="status"/);
  assert.match(page, /TrendRows/);
  assert.match(page, /time dateTime=\{point\.day\}/);
  assert.match(page, /lg:grid-cols-2/);
  assert.doesNotMatch(loader + page, /service_role|\.insert\(|\.update\(|\.delete\(|\.upsert\(|payment_slip|recipient_phone|shipping_address|customer_note/);
});
