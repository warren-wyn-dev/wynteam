import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const settings = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
const count = readFileSync(new URL("../lib/notification-count.ts", import.meta.url), "utf8");
const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
const migration = readFileSync(
  new URL("../../supabase/migrations/20260929193000_notifications_developer_preview.sql", import.meta.url),
  "utf8",
);
const edge = readFileSync(
  new URL("../../supabase/functions/send-push-notification/index.ts", import.meta.url),
  "utf8",
);

test("advanced notification settings are developer-gated and fail closed", () => {
  assert.match(settings, /const isDeveloper = useIsDeveloperAccount\(client, userId\)/);
  assert.match(settings, /if \(!isDeveloper\) \{\s*setDeveloperNotifications\(null\);\s*return;/s);
  assert.match(settings, /\{isDeveloper \? \(\s*<>[\s\S]*Notifications Developer Preview/);
  assert.match(count, /client\.rpc\("is_developer_account"\)/);
  assert.match(
    count,
    /if \(!current\(runtime\) \|\| access\.error \|\| access\.data !== true \|\| runtime\.channel\) return;/,
  );
});

test("quiet hours pause Push only and save the browser timezone", () => {
  assert.match(settings, /In-App และ badge ยังทำงานตามปกติ เฉพาะ Push จะถูกพัก/);
  assert.match(settings, /Intl\.DateTimeFormat\(\)\.resolvedOptions\(\)\.timeZone \|\| "UTC"/);
  assert.match(data, /push_quiet_enabled: false/);
  assert.match(data, /push_quiet_start: "22:00"/);
  assert.match(data, /push_quiet_end: "08:00"/);
});

test("developer Push policy is scoped to web tokens and bounded retries", () => {
  assert.match(edge, /const previewApplies = previewPolicy\.enabled && platform === "web"/);
  assert.match(edge, /const maxAttempts = previewApplies \? 3 : 1/);
  assert.match(edge, /if \(previewApplies && !previewPolicy\.allowed\)/);
});

test("delivery telemetry is internal and never stores raw FCM tokens", () => {
  assert.match(migration, /alter table public\.notification_push_deliveries enable row level security/);
  assert.match(migration, /revoke all on table public\.notification_push_deliveries from anon, authenticated/);
  assert.match(migration, /token_id uuid references public\.push_tokens\(id\) on delete set null/);
  assert.doesNotMatch(migration, /\btoken\s+text\b/i);
  assert.doesNotMatch(migration, /grant\s+select[^;]*notification_push_deliveries[^;]*(anon|authenticated)/i);
});

test("Notifications Developer Preview has no Email notification channel", () => {
  const developerType = data.match(/export type NotificationDeveloperSettings = \{([\s\S]*?)\n\};/)?.[1] ?? "";
  assert.ok(developerType.length > 0);
  assert.doesNotMatch(developerType, /email/i);

  const previewSchema =
    migration.match(/-- Notifications Developer Preview[\s\S]*/)?.[0] ?? migration;
  assert.doesNotMatch(previewSchema, /email_notification|notification_email|push_email/i);
  assert.doesNotMatch(edge, /notification_email|push_email|email_notification/i);
});
