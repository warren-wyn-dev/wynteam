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
const recent = read("../components/admin/recent-workspace-link.tsx");
const deployAdmin = read("../../.github/workflows/deploy-admin.yml");

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
  // The top header is the only workspace selector; no duplicated list in the sidebar.
  assert.doesNotMatch(sidebar, /ADMIN_WORKSPACES\.map/);
  assert.doesNotMatch(sidebar, /aria-label="เลือกพื้นที่ทำงาน"/);
  assert.match(sidebar, /const items = getAdminVisibleItems\(workspace, role\)/);
  assert.match(sidebar, /items\.map/g);
  assert.match(sidebar, /เมนูจัดการ/);
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
  assert.match(header, /sticky top-0/);
  assert.match(header, /ADMIN_WORKSPACES\.map/);
  assert.equal((header.match(/<select\b/g) ?? []).length, 1);
  assert.doesNotMatch(header, /document\.cookie|supabase\.from/);
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

test("Last-workspace UI preference is local only and overview remains reachable", () => {
  assert.match(header, /window\.localStorage\.setItem\(LAST_ADMIN_WORKSPACE_KEY, workspace\.id\)/);
  assert.match(header, /workspace\.id === "overview"/);
  assert.match(recent, /window\.localStorage\.getItem\(LAST_ADMIN_WORKSPACE_KEY\)/);
  assert.match(recent, /item\.id !== "overview"/);
  assert.match(landing, /<RecentWorkspaceLink \/>/);
  assert.doesNotMatch(recent, /supabase|fetch\(|sessionStorage|document\.cookie/);
});

test("Workspace choice appears only in the top header and sidebar stays service-specific", () => {
  assert.match(header, /id="admin-workspace"/);
  assert.match(header, /router\.push\(next\.href\)/);
  assert.doesNotMatch(sidebar, /ADMIN_WORKSPACES/);
  assert.doesNotMatch(sidebar, /section\.href/);
  assert.match(sidebar, /workspace\.icon/);
  assert.match(sidebar, /workspace\.domain/);
  assert.match(sidebar, /items\.map/g);
  assert.doesNotMatch(sidebar, /<select\b/);
});

test("Admin deployment stays scoped to the existing project, Preview by default", () => {
  assert.match(deployAdmin, /default: preview/);
  assert.match(deployAdmin, /CONFIRM_PRODUCTION.*DEPLOY_ADMIN_PRODUCTION/);
  assert.match(deployAdmin, /working-directory: \. # Vercel project rootDirectory/);
  assert.match(deployAdmin, /VERCEL_PROJECT_ID: prj_Ca3SJBvzn0K4w8t0bwQn13EDbVh5/);
  assert.match(deployAdmin, /vercel@63\.1\.0 deploy/);
  assert.doesNotMatch(deployAdmin, /--token=/);
  assert.match(deployAdmin, /args\+\=\(--prod\)/);
  assert.doesNotMatch(deployAdmin, /deploy-web\.yml|food-apply-.*\.yml|merchant\/|web\//);
});
