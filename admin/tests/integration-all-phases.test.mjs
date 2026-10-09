import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { parseAdminSearchQuery } from "../lib/admin-search-query.mjs";
import { parseAuditFilters } from "../lib/audit-log-filters.mjs";
import { safeMetric, safeDaySeries } from "../lib/analytics-series.mjs";
import { probePublicReachability } from "../lib/system-health-probe.mjs";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const nav = read("../lib/admin-nav.ts");
const overview = read("../app/(admin)/page.tsx");
const ci = read("../../.github/workflows/ci.yml");
const root = join(dirname(fileURLToPath(import.meta.url)), "../app/(admin)");

test("Integrated workspace has all seven unique feature destinations and guest smoke covers every one", () => {
  const routes = ["/action-center", "/audit-log", "/search", "/system-health", "/security-center", "/admin-notifications", "/analytics"];
  for (const route of routes) {
    assert.equal((nav.match(new RegExp('href: "' + route + '"', "g")) ?? []).length, 1, route);
    assert.ok(statSync(join(root, route.slice(1), "page.tsx")).isFile(), route);
    assert.ok(ci.includes(" " + route + " "), "route absent from guest smoke: " + route);
  }
  assert.equal((nav.match(/href: "\/"/g) ?? []).length, 1);
  assert.match(overview, /href: "\/action-center"/);
  assert.match(overview, /href: "\/system-health"/);
});

test("Phase 3 and 4 sensitive features remain OFF unless explicitly approved", () => {
  for (const [route, flag] of [
    ["security-center", "NEXT_PUBLIC_ADMIN_SECURITY_CENTER_ENABLED"],
    ["admin-notifications", "NEXT_PUBLIC_ADMIN_NOTIFICATIONS_ENABLED"],
    ["analytics", "NEXT_PUBLIC_ADMIN_ANALYTICS_ENABLED"],
  ]) {
    assert.ok(nav.includes(flag), route + " nav flag");
    assert.ok(read("../app/(admin)/" + route + "/page.tsx").includes("process.env." + flag + ' !== "true"'), route + " direct route flag");
  }
  assert.match(overview, /NEXT_PUBLIC_ADMIN_ANALYTICS_ENABLED === "true"/);
});

test("Top header remains only workspace selector, contextual Sidebar unchanged", () => {
  const header = read("../components/admin/header.tsx");
  const sidebar = read("../components/admin/sidebar.tsx");
  assert.equal((header.match(/<select\b/g) ?? []).length, 1);
  assert.match(header, /href="\/search"/);
  assert.match(sidebar, /getAdminVisibleItems\(workspace, role\)/);
  assert.doesNotMatch(sidebar, /ADMIN_WORKSPACES\.map|<select\b/);
});

test("Independent source fetches enforce least privilege and no new writes", () => {
  const analytics = read("../lib/admin-analytics.ts");
  const action = read("../lib/admin-action-center.ts");
  const search = read("../lib/admin-global-search.ts");
  const signals = read("../lib/admin-notification-feed.ts");
  const security = read("../lib/admin-security-snapshot.ts");
  assert.match(analytics, /role !== "admin"/);
  assert.match(action, /role === "admin"/);
  assert.match(search, /role === "moderator"/);
  assert.match(signals, /role === "admin"/);
  assert.match(security, /await requireAdminRole\(\)/);
  assert.doesNotMatch(analytics + action + search + signals + security, /\.insert\(|\.update\(|\.delete\(|\.upsert\(|service_role/);
});

test("Cross-feature malicious inputs and failures have bounded deterministic behavior", async () => {
  assert.throws(() => parseAdminSearchQuery("x@y.com"));
  assert.throws(() => parseAuditFilters({ event_type: "x,actor_id.neq.uuid" }));
  assert.equal(safeMetric(null), null);
  assert.equal(safeDaySeries([{ date: "2026-10-09", count: null }], { dateKey: "date", countKey: "count" }), null);
  const failed = await probePublicReachability("social", async () => { throw new Error("internal token"); });
  assert.equal(failed.status, "unknown");
  assert.doesNotMatch(failed.detail, /internal token/);
});
