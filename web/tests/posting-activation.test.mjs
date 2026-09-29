import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../../supabase/migrations/20260930013000_web_posting_activation_loop.sql", import.meta.url),
  "utf8",
);
const edge = readFileSync(
  new URL("../../supabase/functions/send-posting-activity/index.ts", import.meta.url),
  "utf8",
);
const home = readFileSync(new URL("../components/home/home-screen.tsx", import.meta.url), "utf8");
const quick = readFileSync(new URL("../components/home/home-quick-compose.tsx", import.meta.url), "utf8");
const composer = readFileSync(new URL("../components/beta4-composer.tsx", import.meta.url), "utf8");
const prompts = readFileSync(new URL("../lib/posting-prompts.ts", import.meta.url), "utf8");
const settings = readFileSync(new URL("../components/settings-route.tsx", import.meta.url), "utf8");
const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
const worker = readFileSync(new URL("../public/sw.js", import.meta.url), "utf8");

test("first-post and daily-prompt surfaces reuse the existing composer", () => {
  assert.match(quick, /เริ่มโพสต์แรกของคุณ/);
  assert.match(quick, /FIRST_POST_PROMPTS/);
  assert.match(quick, /dailyPostingPrompt/);
  assert.match(home, /hasPublishedPost=\{\(identity\?\.post_count \?\? 0\) > 0\}/);
  assert.match(home, /promptText=\{postingPromptByKey\(searchParams\.get\("prompt"\)\)\?\.text \?\? null\}/);
  assert.match(composer, /promptText\?: string \| null/);
  assert.match(composer, /หัวข้อชวนคุย/);
  assert.match(prompts, /FIRST_POST_PROMPTS/);
  assert.match(prompts, /dailyPostingPrompt/);
});

test("posting nudges target active users and use conservative cooldowns", () => {
  assert.match(migration, /wr\.activated_at is not null/);
  assert.match(migration, /wr\.last_seen_at >= now\(\) - interval '3 days'/);
  assert.match(migration, /account_created_at <= now\(\) - interval '12 hours'/);
  assert.match(migration, /last_sent_at <= now\(\) - interval '3 days'/);
  assert.match(migration, /last_post_at <= now\(\) - interval '7 days'/);
  assert.match(migration, /last_sent_at <= now\(\) - interval '7 days'/);
  assert.match(migration, /local_now::time >= time '18:30'/);
  assert.match(migration, /local_now::time < time '19:20'/);
});

test("posting nudges and followed-post digests honor push eligibility and anti-spam", () => {
  assert.match(migration, /push_posting_prompts = true/);
  assert.match(migration, /push_post_updates = true/);
  assert.match(migration, /push_timezone_synced_at is not null/);
  assert.match(migration, /pt\.platform = 'web'/);
  assert.match(migration, /daily_follow_quiet_now/);
  assert.match(migration, /interval '90 minutes'/);
  assert.match(migration, /daily_follow_suggestion_deliveries/);
});

test("followed-post digest batches only new public followed-account posts", () => {
  assert.match(migration, /join public\.follows f/);
  assert.match(migration, /d\.author_id = f\.following_id/);
  assert.match(migration, /d\.audience = 'everyone'/);
  assert.match(migration, /d\.created_at > v\.cursor_at/);
  assert.match(migration, /count\(distinct d\.author_id\)/);
  assert.match(migration, /last_sent_at <= now\(\) - interval '3 hours'/);
  assert.match(migration, /is_blocked_either_way\(v\.user_id, d\.author_id\)/);
});

test("scheduled posting activity is release-gated and protected by Vault auth", () => {
  assert.match(migration, /wynos_posting_activity_cron_key/);
  assert.match(migration, /verify_posting_activity_cron_key/);
  assert.match(migration, /'7,37 \* \* \* \*'/);
  assert.match(migration, /cron\.alter_job\(job_id := v_job, active := false\)/);
  assert.doesNotMatch(migration, /eyJhbGciOi/);
  assert.doesNotMatch(migration, /sb_secret_/);
});

test("sender is Web-only and sends data-only posting activity pushes", () => {
  assert.match(edge, /platform=eq\.web/);
  assert.match(edge, /type: "posting_prompt"/);
  assert.match(edge, /type: "followed_post_digest"/);
  assert.match(edge, /prompt_key: claim\.prompt_key/);
  assert.match(edge, /drop_id: claim\.latest_drop_id/);
  assert.match(edge, /verify_posting_activity_cron_key/);
  assert.doesNotMatch(edge, /notification:\s*\{/);
});

test("service worker routes posting activity without changing the normal notification badge", () => {
  assert.match(worker, /data\?\.type === "posting_prompt"/);
  assert.match(worker, /compose=1&prompt=/);
  assert.match(worker, /data\?\.type === "followed_post_digest"/);
  assert.match(worker, /\/drop\/\$\{id\("drop_id"\)\}/);
  assert.match(worker, /data\.type === "daily_follow_suggestion" \|\| data\.type === "posting_prompt" \|\| data\.type === "followed_post_digest"/);
});

test("notification settings expose posting loop controls", () => {
  assert.match(settings, /\["post_updates", "โพสต์จากคนที่คุณติดตาม"\]/);
  assert.match(settings, /\["posting_prompts", "คำแนะนำให้เริ่มโพสต์"\]/);
  assert.match(settings, /\["push_post_updates", "โพสต์จากคนที่คุณติดตาม"\]/);
  assert.match(settings, /\["push_posting_prompts", "คำแนะนำให้เริ่มโพสต์"\]/);
  assert.match(data, /post_updates: boolean/);
  assert.match(data, /posting_prompts: boolean/);
  assert.match(data, /push_post_updates: boolean/);
  assert.match(data, /push_posting_prompts: boolean/);
});
