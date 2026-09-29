import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../../supabase/migrations/20260929164203_web_daily_follow_suggestions.sql", import.meta.url),
  "utf8",
);

const permanentGuard = readFileSync(
  new URL("../../supabase/migrations/20260929164437_daily_follow_suggestions_permanent_account_guard.sql", import.meta.url),
  "utf8",
);

const timezoneGuard = readFileSync(
  new URL("../../supabase/migrations/20260929164931_daily_follow_suggestions_timezone_guard.sql", import.meta.url),
  "utf8",
);

const edge = readFileSync(
  new URL("../../supabase/functions/send-daily-follow-suggestions/index.ts", import.meta.url),
  "utf8",
);
const route = readFileSync(new URL("../components/suggested-route.tsx", import.meta.url), "utf8");
const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
const worker = readFileSync(new URL("../public/sw.js", import.meta.url), "utf8");
const settings = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
const push = readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8");
const pushResync = readFileSync(new URL("../components/push-resync.tsx", import.meta.url), "utf8");

test("daily follow suggestions are one delivery per local day with a 3-5 profile payload", () => {
  assert.match(migration, /unique \(user_id, local_date\)/i);
  assert.match(migration, /cardinality\(profile_ids\) between 3 and 5/i);
  assert.match(migration, /local_now::time >= time '19:00'/i);
  assert.match(migration, /local_now::time < time '22:00'/i);
  assert.match(migration, /'27 \* \* \* \*'/);
});

test("candidate selection excludes unsafe or already-actioned accounts", () => {
  assert.match(migration, /daily_follow_candidate_allowed/);
  assert.match(migration, /is_blocked_either_way\(p_user_id, p\.id\)/);
  assert.match(migration, /f\.follower_id = p_user_id[\s\S]*f\.following_id = p\.id/);
  assert.match(migration, /fr\.requester_id = p_user_id[\s\S]*fr\.target_id = p\.id/);
  assert.match(migration, /m\.muter_id = p_user_id[\s\S]*m\.muted_id = p\.id/);
  assert.match(migration, /rd\.user_id = p_user_id[\s\S]*rd\.dismissed_profile_id = p\.id/);
  assert.match(migration, /onboarding_completed = true/);
  assert.match(migration, /is_posting_blocked\(p\.id\)/);
});

test("rotation hard-blocks the last 7 days and prefers fresh accounts within 30 days", () => {
  assert.match(migration, /sent_at >= now\(\) - interval '7 days'/);
  assert.match(migration, /sent_at >= now\(\) - interval '30 days'/);
  assert.match(migration, /then 1 else 0 end/);
});

test("retry revalidates the same-day set before sending it again", () => {
  assert.match(migration, /daily_follow_candidate_allowed/);
  assert.match(migration, /bool_and\(internal\.daily_follow_candidate_allowed\(v_user\.uid, candidate_id\)\)/);
  assert.match(migration, /then v_existing\.profile_ids[\s\S]*else null/);
});

test("daily suggestions respect Web Push eligibility, quiet hours and recent-notification anti-spam", () => {
  assert.match(migration, /pt\.platform = 'web'/);
  assert.match(migration, /push_suggestions/);
  assert.match(migration, /suggestions/);
  assert.match(migration, /daily_follow_quiet_now/);
  assert.match(migration, /interval '90 minutes'/);
});

test("cron is release-gated and authenticated by a dedicated Vault key", () => {
  assert.match(migration, /wynos_daily_follow_cron_key/);
  assert.match(migration, /verify_daily_follow_suggestion_cron_key/);
  assert.match(migration, /cron\.alter_job[\s\S]*active := false/);
  assert.doesNotMatch(migration, /eyJhbGciOi/);
  assert.doesNotMatch(migration, /sb_secret_/);
});

test("sender is Web-only, data-only, and carries the delivery id for attribution", () => {
  assert.match(edge, /platform=eq\.web/);
  assert.match(edge, /type: "daily_follow_suggestion"/);
  assert.match(edge, /delivery_id: claim\.delivery_id/);
  assert.match(edge, /push_title: title/);
  assert.match(edge, /push_body: body/);
  assert.doesNotMatch(edge, /notification:\s*\{/);
  assert.match(edge, /verify_daily_follow_suggestion_cron_key/);
});

test("Web Push click opens Suggested and does not wake the notification badge", () => {
  assert.match(worker, /data\?\.type === "daily_follow_suggestion"/);
  assert.match(worker, /\/suggested\?source=daily_follow_suggestion/);
  assert.match(worker, /data\.type === "daily_follow_suggestion"[\s\S]*Promise\.resolve\(\)/);
});

test("Suggested route loads the delivered set and records opens", () => {
  assert.match(route, /fetchDailySuggestedProfiles/);
  assert.match(route, /markDailyFollowSuggestionOpened/);
  assert.match(route, /fetchDailySuggestedProfiles\(client, pushedDeliveryId\)/);
  assert.match(route, /if \(pushedDeliveryId && daily\.deliveryId === pushedDeliveryId\)/);
  assert.match(route, /daily_follow_suggestion/);
  assert.match(route, /followButtonLabel/);
  assert.match(route, /profile_recommendation_dismissals/);
  assert.match(data, /daily_follow_suggestion_deliveries/);
  assert.match(data, /mark_daily_follow_suggestion_opened/);
});

test("notification settings expose suggestions and Push registration persists timezone", () => {
  assert.match(settings, /\["suggestions", "คำแนะนำคนที่น่าสนใจ"\]/);
  assert.match(settings, /\["push_suggestions", "คำแนะนำคนที่น่าสนใจ"\]/);
  assert.match(data, /suggestions: boolean/);
  assert.match(data, /push_suggestions: boolean/);
  assert.match(push, /resolvedOptions\(\)\.timeZone/);
  assert.match(push, /push_timezone: timezone/);
  assert.match(pushResync, /syncPushTimezone/);
  assert.match(pushResync, /push_timezone: timezone/);
});

test("suggestion history rejects anonymous authenticated sessions", () => {
  assert.match(permanentGuard, /auth\.jwt\(\).*is_anonymous/s);
  assert.match(permanentGuard, /Permanent account required/);
  assert.match(permanentGuard, /\(select auth\.uid\(\)\) = user_id/);
});

test("daily suggestions require an explicitly synced valid browser timezone", () => {
  assert.match(timezoneGuard, /push_timezone_synced_at timestamptz/);
  assert.match(timezoneGuard, /ns\.push_timezone_synced_at is not null/);
  assert.match(timezoneGuard, /join pg_timezone_names tz[\s\S]*tz\.name = ns\.push_timezone/);
  assert.doesNotMatch(timezoneGuard, /coalesce\(tz\.name, 'UTC'\)/);
  assert.match(push, /push_timezone_synced_at: new Date\(\)\.toISOString\(\)/);
  assert.match(pushResync, /push_timezone_synced_at: new Date\(\)\.toISOString\(\)/);
});
