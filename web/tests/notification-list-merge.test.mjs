import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/notification-list-merge.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports });
const { mergeNewestNotificationPage, NOTIFICATION_PAGE_SIZE } = mod.exports;

// Newest first, one minute apart.
const at = (minutesAgo) => new Date(Date.UTC(2026, 8, 26, 12, 0) - minutesAgo * 60_000).toISOString();
const rows = (from, count) => Array.from({ length: count }, (_, i) => ({ id: `n${from + i}`, created_at: at(from + i) }));

test("a Push/focus refresh keeps pages already loaded with ดูเพิ่มเติม", () => {
  const loaded = rows(0, 60); // pages 0 and 1
  const fresh = [{ id: "new", created_at: at(-1) }, ...rows(0, NOTIFICATION_PAGE_SIZE - 1)];
  const merged = mergeNewestNotificationPage(loaded, fresh);
  assert.equal(merged.length, 61);
  assert.equal(merged[0].id, "new");
  assert.deepEqual([...merged.slice(-31).map((row) => row.id)], rows(29, 31).map((row) => row.id));
  assert.equal(new Set(merged.map((row) => row.id)).size, merged.length, "no duplicates");
});

test("a short fresh page is the whole list; stale copies of deleted rows are dropped", () => {
  const loaded = rows(0, 60);
  const fresh = rows(0, 12);
  assert.equal(mergeNewestNotificationPage(loaded, fresh), fresh);
});

test("notification page merges background refreshes instead of truncating", () => {
  const route = readFileSync(new URL("../components/notifications-route.tsx", import.meta.url), "utf8");
  assert.match(route, /const merge = !append && !markExisting && nextPage === 0 && pageRef\.current > 0/);
  assert.match(route, /if \(merge\) return mergeNewestNotificationPage\(current, next\)/);
  // Background refreshes union the unread highlight captured on open.
  assert.match(route, /append \|\| !markExisting \? new Set\(\[\.\.\.current, \.\.\.nextUnread\]\)/);
});
