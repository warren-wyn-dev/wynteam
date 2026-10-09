import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

const nav = read("../lib/admin-nav.ts");
const sidebar = read("../components/admin/sidebar.tsx");
const header = read("../components/admin/header.tsx");
const landing = read("../app/(admin)/page.tsx");
const social = read("../app/(admin)/social/page.tsx");
const layout = read("../app/(admin)/layout.tsx");

test("All WYNOS services have their own clearly named workspace and live route", () => {
  for (const id of ["overview", "social", "food", "merchant", "central"]) {
    assert.match(nav, new RegExp('id: "' + id + '"'));
  }
  for (const destination of ['href: "/"', 'href: "/social"', 'href: "/food"', 'href: "/merchants"', 'href: "/audit-log"']) {
    assert.ok(nav.includes(destination), destination);
  }
  for (const domain of ["wynos.online", "food.wynos.online", "merchant.wynos.online"]) {
    assert.ok(nav.includes(domain), domain);
  }
});

test("Existing deep link routes are preserved and not relocated into other apps", () => {
  for (const route of ["/users", "/moderation", "/reports", "/announcements", "/food/orders", "/food/campaigns", "/food/coupons", "/food/notifications", "/food/ads", "/food/places", "/merchants", "/audit-log"]) {
    assert.ok(nav.includes('href: "' + route + '"'), route);
  }
  assert.match(nav, /pathname\.startsWith\(href \+ "\/"\)/);
  assert.match(nav, /right\.href\.length - left\.href\.length/);
});

test("Desktop and mobile use the same workspace-scoped navigation source", () => {
  assert.match(sidebar, /getAdminWorkspace\(pathname\)/);
  assert.match(sidebar, /getAdminVisibleItems\(workspace, role\)/);
  assert.match(sidebar, /ADMIN_WORKSPACES\.map/);
  assert.match(sidebar, /aria-label="เลือกพื้นที่ทำงาน"/);
  assert.match(sidebar, /md:hidden/);
  assert.match(sidebar, /safe-area-inset-bottom/);
  assert.match(layout, /<AdminSidebar role=\{role\} \/>/);
  assert.match(layout, /<AdminHeader email=\{email\} role=\{role\}/);
});

test("Mobile and desktop header switch workspace without changing stored app data", () => {
  assert.match(header, /getAdminWorkspace\(pathname\)/);
  assert.match(header, /value=\{workspace\.id\}/);
  assert.match(header, /router\.push\(next\.href\)/);
  assert.match(header, /htmlFor="admin-workspace"/);
  assert.doesNotMatch(header, /localStorage|document\.cookie|supabase\.from/);
});

test("Social dashboard is preserved while global overview does not pretend its numbers are global", () => {
  assert.match(social, /DashboardMetrics/);
  assert.match(social, /DashboardSkeleton/);
  assert.match(social, /RefreshButton/);
  assert.match(landing, /ADMIN_WORKSPACES\.filter/);
  assert.match(landing, /role \} = await requireAdminRole\(\)/);
  assert.doesNotMatch(landing, /DashboardMetrics/);
});

test("Menu respects legacy Admin and Moderator permission boundaries", () => {
  assert.match(nav, /"\/food\/orders"[^\n]+roles: \["admin"\]/);
  assert.match(nav, /"\/food\/ads"[^\n]+roles: \["admin"\]/);
  assert.match(nav, /item\.roles\.includes\(role\)/);
  assert.match(landing, /link\.roles\.includes\(role\)/);
  assert.match(layout, /requireAdminRole\(\)/);
});
