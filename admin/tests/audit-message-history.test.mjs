import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("message history maintains existing announcement and reminder histories", () => {
  const helper = read("../lib/admin-audit-history.ts");
  const announcements = read("../lib/admin-announcements.ts");
  const reminders = read("../lib/admin-inactive-reminders.ts");
  assert.match(announcements, /fetchAdminMessageHistory\("admin_announcement_sent"\)/);
  assert.match(reminders, /fetchAdminMessageHistory\("admin_inactive_reminder_sent"\)/);
  assert.match(helper, /await requireAdminRole\(\)/);
  assert.match(helper, /eventType !== "admin_announcement_sent" && eventType !== "admin_inactive_reminder_sent"/);
  assert.match(helper, /\.eq\("event_type", eventType\)/);
  assert.match(helper, /\.limit\(200\)/);
  assert.doesNotMatch(helper, /\.insert\(|\.update\(|\.delete\(|\.upsert\(/);
});

test("general Audit Log cannot request, render or serialize detail-bearing history", () => {
  const query = read("../lib/admin-audit-log.ts");
  const page = read("../app/(admin)/audit-log/page.tsx");
  const results = read("../app/(admin)/audit-log/results.tsx");
  const history = read("../lib/admin-audit-history.ts");
  assert.doesNotMatch(query, /\bdetail\b/);
  assert.doesNotMatch(results, /\bdetail\b/);
  assert.match(page, /await requireAdminRole\(\)/);
  assert.doesNotMatch(page, /fetchAdminMessageHistory|fetchAuditLog\(/);
  assert.match(history, /\.select\("id, actor_id, actor_username_snapshot, event_type, target_id, detail, created_at"\)/);
  assert.match(query, /\.select\("id, actor_id, actor_username_snapshot, event_type, target_id, created_at"\)/);
});
