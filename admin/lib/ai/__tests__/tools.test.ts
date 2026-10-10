import assert from "node:assert/strict";
import { test } from "node:test";

import { resolveTier, estimateCostUsd } from "../models.ts";
import { SECRETARY_TOOLS, findTool } from "../tools.ts";

const ctx = (rpcData: Record<string, unknown>) => ({
  rpc: async (name: string) => {
    if (!(name in rpcData)) throw new Error(`unexpected rpc ${name}`);
    return rpcData[name];
  },
  listMemory: async () => [
    { kind: "decision", content: "Founder อนุมัติ WYN-219 Phase 1", created_at: "2026-10-10" },
    { kind: "note", content: "ร้านเปิดใหม่สัปดาห์หน้า", created_at: "2026-10-09" },
  ],
  signal: new AbortController().signal,
});

test("Phase 1 registers read-only tools only, with unique valid names", () => {
  const names = new Set<string>();
  for (const tool of SECRETARY_TOOLS) {
    assert.equal(tool.level, 1, `${tool.name} must be level 1`);
    assert.match(tool.name, /^[a-z][a-z0-9_]{0,63}$/);
    assert.ok(!names.has(tool.name));
    names.add(tool.name);
    assert.ok(tool.timeoutMs > 0 && tool.timeoutMs <= 30_000);
  }
});

test("no-input tools reject unexpected input", () => {
  const tool = findTool("get_food_overview")!;
  assert.equal(tool.validate({}).ok, true);
  assert.equal(tool.validate(undefined).ok, true);
  assert.equal(tool.validate({ store_id: "x" }).ok, false);
  assert.equal(tool.validate("x").ok, false);
});

test("compare_today_vs_yesterday computes deltas and handles zero", async () => {
  const tool = findTool("compare_today_vs_yesterday")!;
  const result = await tool.run(
    ctx({
      admin_dashboard_metrics: [{ new_users_today: 30, drops_today: 0, views_today: 10, likes_today: 5, comments_today: 0, redrops_today: 0, messages_today: 0 }],
      admin_dashboard_trends: [{ new_users_yesterday: 20, drops_yesterday: 0, views_yesterday: 20, likes_yesterday: 5, comments_yesterday: 0, redrops_yesterday: 0, messages_yesterday: 0, dau_last_14d: [] }],
    }),
    {},
  );
  const rows = (result.data as { comparison: Array<{ metric: string; change_pct: number | null }> }).comparison;
  assert.equal(rows.find((r) => r.metric === "new_users")?.change_pct, 50);
  assert.equal(rows.find((r) => r.metric === "views")?.change_pct, -50);
  assert.equal(rows.find((r) => r.metric === "drops")?.change_pct, null);
  assert.match(result.source.window, /24/);
});

test("search_memory validates input and matches every word", async () => {
  const tool = findTool("search_memory")!;
  assert.equal(tool.validate({ query: 1 }).ok, false);
  assert.equal(tool.validate({ query: "a", extra: 1 }).ok, false);
  const parsed = tool.validate({ query: "  founder WYN-219 " });
  assert.ok(parsed.ok);
  const result = await tool.run(ctx({}), parsed.ok ? parsed.value : {});
  assert.equal((result.data as { notes: unknown[] }).notes.length, 1);
});

test("model tiers resolve with safe overrides", () => {
  assert.equal(resolveTier("fast", {}).model, "claude-haiku-5-5");
  assert.equal(resolveTier("standard", {}).model, "claude-opus-5-5");
  assert.equal(resolveTier("deep", {}).effort, "high");
  assert.equal(resolveTier("standard", { AI_MODEL_STANDARD: "claude-sonnet-5-5" }).model, "claude-sonnet-5-5");
  assert.equal(resolveTier("standard", { AI_MODEL_STANDARD: "bad model; rm -rf" }).model, "claude-opus-5-5");
  assert.equal(resolveTier("standard", { AI_MODEL_STANDARD: "claude-haiku-5-5" }).refusalFallback, false);
});

test("cost estimate uses known prices only", () => {
  assert.equal(estimateCostUsd("claude-opus-5-5", 1_000_000, 100_000), 6);
  assert.equal(estimateCostUsd("unknown", 1, 1), null);
});
