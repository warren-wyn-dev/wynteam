import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const load = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = load("../../supabase/migrations/20261009140000_admin_qa_guardrails.sql");
const page = load("../app/(admin)/food/notifications/page.tsx");
const manager = load("../components/admin/food-promotion-broadcast-manager.tsx");
const campaigns = load("../components/admin/platform-campaign-actions.tsx");
const deployWorkflow = load("../../.github/workflows/deploy-admin.yml");

test("Scheduler health is role gated and does not mutate delivery state", () => {
  assert.match(migration, /function public\.admin_food_promo_scheduler_status\(\)/);
  assert.match(migration, /current_platform_role\(\).*not in \('admin', 'moderator'\)/);
  assert.match(migration, /where jobname = 'wynos-food-promotions-5min' and active/);
  assert.match(migration, /revoke all on function public\.admin_food_promo_scheduler_status\(\) from public, anon/);
});

test("Existing Admin schedule RPC checks cron before any insertion", () => {
  const start = migration.indexOf("create or replace function public.admin_food_promo_schedule(");
  const end = migration.indexOf("create or replace view", start);
  const sql = migration.slice(start, end);
  assert.ok(start !== -1 && end > start);
  assert.match(sql, /'food_promo_scheduler_disabled'/);
  assert.ok(sql.indexOf("'food_promo_scheduler_disabled'") < sql.indexOf("insert into public.food_promo_broadcasts"));
  assert.match(sql, /'Only admins can send Food promotions'/);
  assert.match(sql, /'coupon_not_active'/);
  assert.match(sql, /'invalid_audience'/);
  assert.match(sql, /'invalid_promotion_copy'/);
});

test("Privileged views are limited explicitly to Admin and Moderator", () => {
  for (const view of ["moderation_queue", "admin_user_moderation_history", "admin_audit_log"]) {
    const fragment = migration.split("create or replace view public." + view + " as")[1];
    assert.ok(fragment, view + " must be hardened");
    assert.match(fragment.split(";")[0], /current_platform_role\(\).*in \('admin', 'moderator'\)/);
    assert.doesNotMatch(fragment.split(";")[0], /<> 'user'/);
  }
});

test("Admin UI fails closed if Scheduler cannot be verified", () => {
  assert.match(page, /scheduler\.error \? "unknown"/);
  assert.match(page, /schedulerState=\{schedulerState\}/);
  assert.match(manager, /schedulerState === "active"/);
  assert.match(manager, /disabled=\{!schedulerActive \|\| pending/);
  assert.match(manager, /food_promo_scheduler_disabled/);
});

test("First-order campaign requires typed confirmation only for activation", () => {
  assert.match(campaigns, /activationPhrase = "เปิดโปรลูกค้าใหม่"/);
  assert.match(campaigns, /active \|\| confirmation\.trim\(\) === activationPhrase/);
  assert.match(campaigns, /if \(pending \|\| !canConfirm\) return/);
  assert.match(campaigns, /disabled=\{pending \|\| !canConfirm\}/);
  assert.match(campaigns, /await setFirstOrderFoodCampaignActive\(!active\)/);
});

test("Admin deploy workflow targets only existing Admin project with preview default", () => {
  assert.match(deployWorkflow, /working-directory: \. # Vercel project rootDirectory/);
  assert.match(deployWorkflow, /default: preview/);
  assert.match(deployWorkflow, /CONFIRM_PRODUCTION.*DEPLOY_ADMIN_PRODUCTION/);
  assert.match(deployWorkflow, /VERCEL_PROJECT_ID: prj_Ca3SJBvzn0K4w8t0bwQn13EDbVh5/);
  assert.match(deployWorkflow, /vercel@63\.1\.0 deploy/);
  assert.doesNotMatch(deployWorkflow, /--token=/);
  assert.match(deployWorkflow, /args\+\=\(--prod\)/);
});
