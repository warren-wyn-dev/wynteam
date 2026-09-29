import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../../supabase/migrations/20260929160000_web_daily_follow_suggestions.sql", import.meta.url),
  "utf8",
);
const edge = readFileSync(
  new URL("../../supabase/functions/send-daily-follow-suggestions/index.ts", import.meta.url),
  "utf8",
);
const worker = readFileSync(new URL("../public/sw.js", import.meta.url), "utf8");
const search = readFileSync(new URL("../components/search-route.tsx", import.meta.url), "utf8");
const pushClient = readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8");

test("daily follow suggestions are at most once per local day and release-gated", () => {
  assert.match(migration, /unique \(user_id, local_date\)/);
  assert.match(migration, /'37 \* \* \* \*'/);
  assert.match(migration, /cron\.alter_job[\s\S]*active := false/);
  assert.match(migration, /time '10:00'/);
  assert.doesNotMatch(migration, /\nas \$\n/);
  assert.doesNotMatch(migration, /\ndo \$\n/);
});

test("candidate ranking excludes unsafe and repetitive recommendations", () => {
  assert.match(migration, /not internal\.is_blocked_either_way/);
  assert.match(migration, /public\.mutes/);
  assert.match(migration, /profile_recommendation_dismissals/);
  assert.match(migration, /public\.follows f/);
  assert.match(migration, /interval '7 days'/);
  assert.match(migration, /onboarding_completed = true/);
  assert.match(migration, /limit greatest\(1, least\(coalesce\(p_limit, 5\), 5\)\)/);
});

test("inactive new users do not receive daily follow push on top of reactivation", () => {
  assert.match(migration, /web_reactivation_state wr/);
  assert.match(migration, /wr\.activated_at is null/);
});

test("delivery is Web-only, bilingual, and does not create notification-center rows", () => {
  assert.match(edge, /platform=eq\.web/);
  assert.match(edge, /คนใหม่ ๆ ที่คุณอาจสนใจ 👋/);
  assert.match(edge, /People you may want to follow 👋/);
  assert.doesNotMatch(edge, /rest\/v1\/notifications/);
  assert.doesNotMatch(edge, /from\("notifications"\)/);
});

test("push click opens the dedicated suggested people view without badge invalidation", () => {
  assert.match(worker, /daily_follow_suggestion/);
  assert.match(worker, /\/search\?suggested=1/);
  assert.match(worker, /web_reactivation" \|\| data\.type === "daily_follow_suggestion/);
  assert.match(search, /params\.get\("suggested"\) === "1"/);
  assert.match(search, /<h1>แนะนำสำหรับคุณ<\/h1>/);
  assert.match(search, /suggestedOnly \? fetchDailySuggestedProfiles\(client\) : fetchSuggestedProfiles\(client, 10\)/);
  assert.match(migration, /daily_follow_suggestions_for_me/);
});


test("Push registration syncs the browser timezone for local daily scheduling", () => {
  assert.match(pushClient, /Intl\.DateTimeFormat\(\)\.resolvedOptions\(\)\.timeZone/);
  assert.match(pushClient, /notification_settings/);
  assert.match(pushClient, /push_timezone: timezone/);
});
