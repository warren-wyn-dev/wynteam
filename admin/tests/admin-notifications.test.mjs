import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Admin Notifications are OFF until approved, and protected even on direct guest URLs", () => {
  const page = read("../app/(admin)/admin-notifications/page.tsx");
  const nav = read("../lib/admin-nav.ts");
  const ci = read("../../.github/workflows/ci.yml");
  assert.ok(page.includes("await requireAdminRole()"));
  assert.ok(page.includes('process.env.NEXT_PUBLIC_ADMIN_NOTIFICATIONS_ENABLED !== "true"'));
  assert.ok(page.includes("notFound()"));
  assert.ok(nav.includes('process.env.NEXT_PUBLIC_ADMIN_NOTIFICATIONS_ENABLED === "true"'));
  assert.ok(nav.includes('href: "/admin-notifications"'));
  assert.ok(ci.includes(" /admin-notifications "));
});

test("Feed is a read-only source snapshot, not a fabricated notification delivery", () => {
  const source = read("../lib/admin-notification-feed.ts");
  const page = read("../app/(admin)/admin-notifications/page.tsx");
  assert.ok(source.includes("await requireAdminRole()"));
  assert.ok(source.includes('mode: "pending_work_snapshot"'));
  assert.ok(source.includes('.from("moderation_queue")'));
  assert.ok(source.includes('.select("id, target_type, created_at")'));
  assert.ok(source.includes(".limit(FEED_LIMIT)"));
  assert.ok(source.includes('p_status: "pending"'));
  assert.ok(source.includes("p_limit: FEED_LIMIT"));
  assert.ok(source.includes("new Set<string>()"));
  assert.ok(source.includes("seen.has(item.key)"));
  assert.ok(page.includes("จำนวนรายการไม่ใช่จำนวนยังไม่อ่าน"));
  assert.ok(page.includes("ไม่มี Email Notifications"));
  assert.doesNotMatch(source + page, /\.insert\(|\.update\(|\.delete\(|\.upsert\(|service_role|markAsRead|markRead|sendEmail|sendPush/);
});

test("Moderator never queries merchant applicant data and backend errors do not leak", () => {
  const source = read("../lib/admin-notification-feed.ts");
  const page = read("../app/(admin)/admin-notifications/page.tsx");
  assert.ok(source.includes('role === "admin"'));
  assert.ok(source.includes('getSource("merchants", "คำขอ Merchant", recentMerchantSignals)'));
  assert.ok(source.includes(": [await reports]"));
  assert.ok(source.includes('status: "unavailable"'));
  assert.ok(page.includes('source.status === "unavailable"'));
  assert.ok(page.includes("ไม่ได้หมายความว่าไม่มีงานค้าง"));
  assert.doesNotMatch(source + page, /row\.phone|row\.address|row\.contact_name|row\.recipient_phone|row\.detail|error\.message|console\.log/);
});

test("Staff signal UI is mobile responsive, with stable source ID and deep links", () => {
  const source = read("../lib/admin-notification-feed.ts");
  const page = read("../app/(admin)/admin-notifications/page.tsx");
  assert.ok(source.includes('"report:" + String(row.id)'));
  assert.ok(source.includes('"merchant:" + row.id'));
  assert.ok(source.includes('"/reports/" + encodeURIComponent(String(row.id))'));
  assert.ok(source.includes('href: "/merchants"'));
  assert.ok(page.includes("lg:grid-cols-2"));
  assert.ok(page.includes("min-h-14"));
  assert.ok(page.includes("key={item.key}"));
});
