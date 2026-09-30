import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const beta2 = readFileSync(new URL("../lib/beta2.ts", import.meta.url), "utf8");
const settings = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
const notificationCount = readFileSync(new URL("../lib/notification-count.ts", import.meta.url), "utf8");
const edge = readFileSync(
  new URL("../../supabase/functions/send-push-notification/index.ts", import.meta.url),
  "utf8",
);
const migration = readFileSync(
  new URL("../../supabase/migrations/20260930014500_notifications_realtime_all_users.sql", import.meta.url),
  "utf8",
);
const approvals = readFileSync(
  new URL("../../.wyn/company/APPROVALS.md", import.meta.url),
  "utf8",
);

test("current Web Beta2 feature switches are released to every account", () => {
  for (const feature of ["chatThreads", "clubChatActions", "clubAnnouncements"]) {
    assert.match(beta2, new RegExp(`\\b${feature}: true,`));
    assert.match(approvals, new RegExp(`Beta2 release: ${feature}\\b`));
  }
});

test("advanced notification settings are public and no preview banner remains", () => {
  assert.doesNotMatch(settings, /useIsDeveloperAccount/);
  assert.doesNotMatch(settings, /Notifications Developer Preview/);
  assert.doesNotMatch(settings, /เฉพาะบัญชีนักพัฒนา/);
  assert.match(settings, /<h2>Push ตามประเภท<\/h2>/);
  assert.match(settings, /<h2>Quiet Hours<\/h2>/);
  assert.match(settings, /กำลังโหลดการตั้งค่า Push…/);
});

test("notification Realtime attaches without a developer-account RPC", () => {
  assert.match(notificationCount, /async function attachRealtime/);
  assert.match(notificationCount, /void attachRealtime\(runtime\)/);
  assert.doesNotMatch(notificationCount, /rpc\("is_developer_account"\)/);
});

test("advanced Web Push preferences and retry policy apply to every web account", () => {
  assert.match(edge, /async function webPushPolicy/);
  assert.match(edge, /const webPolicyApplies = platform === "web"/);
  assert.doesNotMatch(edge, /developer_accounts\?/);
  assert.doesNotMatch(edge, /developerPreviewPolicy/);
});

test("release migration publishes notifications to Supabase Realtime idempotently", () => {
  assert.match(migration, /pg_publication_tables/);
  assert.match(migration, /tablename = 'notifications'/);
  assert.match(migration, /alter publication supabase_realtime add table public\.notifications/);
});
