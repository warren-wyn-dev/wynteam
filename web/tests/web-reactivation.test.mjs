import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const tracker = readFileSync(new URL("../components/web-reactivation-activation.tsx", import.meta.url), "utf8");
const migration = readFileSync(
  new URL("../../supabase/migrations/20260929153000_web_beta1_reactivation_push.sql", import.meta.url),
  "utf8",
);
const edge = readFileSync(
  new URL("../../supabase/functions/send-web-reactivation/index.ts", import.meta.url),
  "utf8",
);

test("reactivation activation is server-backed and stops after a return or five minutes", () => {
  assert.match(tracker, /mark_web_reactivation_seen/);
  assert.match(tracker, /visibilitychange/);
  assert.match(tracker, /5 \* 60 \* 1000/);
  assert.match(migration, /interval '5 minutes'/);
  assert.match(migration, /activated_at = now\(\)/);
  assert.match(migration, /next_due_at = null/);
});

test("reactivation schedule is 24h, 3d, 7d, then every 7d", () => {
  assert.match(migration, /interval '24 hours'/);
  assert.match(migration, /enrolled_at \+ interval '3 days'/);
  assert.match(migration, /enrolled_at \+ interval '7 days'/);
  assert.match(migration, /now\(\) \+ interval '7 days'/);
  assert.match(migration, /'17 \* \* \* \*'/);
});

test("rollout does not back-send to historical accounts", () => {
  assert.match(migration, /Baseline everyone who already exists at rollout time as activated/);
  assert.match(migration, /select p\.id, p\.created_at, p\.created_at, now\(\), now\(\), null/);
});

test("reactivation delivery is web-only and never creates a shared notification row", () => {
  assert.match(edge, /platform=eq\.web/);
  assert.doesNotMatch(edge, /from\("notifications"\)/);
  assert.doesNotMatch(edge, /rest\/v1\/notifications/);
  assert.match(edge, /type: "web_reactivation"/);
});

test("cron uses Vault names rather than committed credential values", () => {
  assert.match(migration, /wynos_project_url/);
  assert.match(migration, /wynos_cron_anon_key/);
  assert.doesNotMatch(migration, /sb_publishable_/);
  assert.doesNotMatch(migration, /eyJhbGciOi/);
});
