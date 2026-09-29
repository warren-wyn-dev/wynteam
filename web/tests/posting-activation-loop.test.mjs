import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../../supabase/migrations/20260929190537_web_posting_activation_loop.sql", import.meta.url),
  "utf8",
);
const edge = readFileSync(
  new URL("../../supabase/functions/send-posting-activity/index.ts", import.meta.url),
  "utf8",
);
const worker = readFileSync(new URL("../public/sw.js", import.meta.url), "utf8");
const home = readFileSync(new URL("../components/home/home-quick-compose.tsx", import.meta.url), "utf8");
const homeScreen = readFileSync(new URL("../components/home/home-screen.tsx", import.meta.url), "utf8");
const composer = readFileSync(new URL("../components/beta4-composer.tsx", import.meta.url), "utf8");
const settings = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
const prompts = readFileSync(new URL("../lib/posting-prompts.ts", import.meta.url), "utf8");

test("first-post and daily prompt surfaces reuse the existing composer", () => {
  assert.match(home, /เริ่มโพสต์แรกของคุณ/);
  assert.match(home, /FIRST_POST_PROMPTS/);
  assert.match(home, /dailyPostingPrompt/);
  assert.match(home, /\?compose=1&prompt=/);
  assert.match(homeScreen, /postingPromptByKey\(searchParams\.get\("prompt"\)\)/);
  assert.match(homeScreen, /hasPublishedPost=\{\(identity\?\.post_count \?\? 0\) > 0\}/);
  assert.match(composer, /promptText\?: string \| null/);
  assert.match(composer, /หัวข้อชวนคุย/);
  assert.match(prompts, /FIRST_POST_PROMPTS/);
  assert.match(prompts, /DAILY_PROMPTS/);
});

test("posting notification preferences are user controllable", () => {
  assert.match(migration, /post_updates boolean not null default true/);
  assert.match(migration, /posting_prompts boolean not null default true/);
  assert.match(migration, /push_post_updates boolean not null default true/);
  assert.match(migration, /push_posting_prompts boolean not null default true/);
  assert.match(settings, /โพสต์จากคนที่คุณติดตาม/);
  assert.match(settings, /คำแนะนำให้เริ่มโพสต์/);
  assert.match(data, /post_updates: boolean/);
  assert.match(data, /posting_prompts: boolean/);
  assert.match(data, /push_post_updates: boolean/);
  assert.match(data, /push_posting_prompts: boolean/);
});

test("posting nudges target recently active non-posters without daily spam", () => {
  assert.match(migration, /wr\.activated_at is not null/);
  assert.match(migration, /wr\.last_seen_at >= now\(\) - interval '3 days'/);
  assert.match(migration, /c\.account_created_at <= now\(\) - interval '12 hours'/);
  assert.match(migration, /c\.last_post_at <= now\(\) - interval '7 days'/);
  assert.match(migration, /c\.last_sent_at <= now\(\) - interval '3 days'/);
  assert.match(migration, /c\.last_sent_at <= now\(\) - interval '7 days'/);
  assert.match(migration, /local_now::time >= time '17:00'/);
  assert.match(migration, /local_now::time < time '18:00'/);
  assert.match(migration, /daily_follow_suggestion_deliveries/);
  assert.match(migration, /interval '90 minutes'/);
  assert.match(migration, /daily_follow_quiet_now/);
  assert.match(migration, /not internal\.is_posting_blocked\(p\.id\)/);
});

test("followed-post digests are batched, public-only, cursor-based and low frequency", () => {
  assert.match(migration, /followed_post_digest_state/);
  assert.match(migration, /cursor_at timestamptz not null default now\(\)/);
  assert.match(migration, /d\.audience = 'everyone'/);
  assert.match(migration, /d\.deleted_at is null/);
  assert.match(migration, /d\.created_at > v\.cursor_at/);
  assert.match(migration, /is_blocked_either_way\(v\.user_id, d\.author_id\)/);
  assert.match(migration, /is_posting_blocked\(d\.author_id\)/);
  assert.match(migration, /m\.muter_id = v\.user_id[\s\S]*m\.muted_id = d\.author_id/);
  assert.match(migration, /last_sent_at <= now\(\) - interval '3 hours'/);
  assert.match(migration, /time '09:00'/);
  assert.match(migration, /time '17:00'/);
  assert.match(migration, /count\(distinct d\.author_id\)/);
  assert.match(migration, /pending_cursor_at/);
});

test("posting activity cron is Vault-authenticated and release gated", () => {
  assert.match(migration, /wynos_posting_activity_cron_key/);
  assert.match(migration, /verify_posting_activity_cron_key/);
  assert.match(migration, /revoke all on function internal\.enroll_posting_activity_state\(\)/);
  assert.match(migration, /wynos-posting-activity/);
  assert.match(migration, /'7,37 \* \* \* \*'/);
  assert.match(migration, /active := false/);
  assert.doesNotMatch(migration, /eyJhbGciOi/);
  assert.doesNotMatch(migration, /sb_secret_/);
});

test("sender uses Web-only data pushes and finishes every claim", () => {
  assert.match(edge, /platform=eq\.web/);
  assert.match(edge, /type: "posting_prompt"/);
  assert.match(edge, /type: "followed_post_digest"/);
  assert.match(edge, /finish_posting_nudge/);
  assert.match(edge, /finish_followed_post_digest/);
  assert.match(edge, /verify_posting_activity_cron_key/);
  assert.match(edge, /push_title/);
  assert.match(edge, /push_body/);
  assert.doesNotMatch(edge, /notification:\s*\{/);
  assert.doesNotMatch(edge.toLowerCase(), /email/);
});

test("service worker deep-links activation pushes without notification badge wakes", () => {
  assert.match(worker, /data\?\.type === "posting_prompt"/);
  assert.match(worker, /allowedPrompts/);
  assert.match(worker, /compose=1&prompt=/);
  assert.match(worker, /data\?\.type === "followed_post_digest"/);
  assert.match(worker, /count === 1 && id\("drop_id"\)/);
  assert.match(worker, /data\.type === "posting_prompt"/);
  assert.match(worker, /data\.type === "followed_post_digest"/);
  assert.match(worker, /Promise\.resolve\(\)/);
});

test("no Email notification path is introduced", () => {
  const combined = [migration, edge, worker, home, composer, settings, data].join("\n").toLowerCase();
  assert.doesNotMatch(combined, /email notification/);
  assert.doesNotMatch(combined, /send[_-]?email/);
});
