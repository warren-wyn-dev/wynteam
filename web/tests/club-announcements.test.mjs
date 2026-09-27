// WYN-137: announcement paging must not skip rows that share a timestamp.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/club-announcements.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const exports = {};
runInNewContext(compiled, { exports, require: () => ({}) });

function client(calls) {
  const chain = {
    select: () => chain,
    eq: (...args) => { calls.push(["eq", ...args]); return chain; },
    or: (filter) => { calls.push(["or", filter]); return chain; },
    order: (...args) => { calls.push(["order", ...args]); return chain; },
    limit: async (n) => { calls.push(["limit", n]); return { data: [], error: null }; },
  };
  return { from: () => chain };
}

test("the first page orders by (created_at, id) with no cursor filter", async () => {
  const calls = [];
  await exports.fetchClubAnnouncements(client(calls), "club-1");
  assert.deepEqual(calls.filter(([k]) => k === "order").map(([, col]) => col), ["created_at", "id"]);
  assert.equal(calls.some(([k]) => k === "or"), false);
});

test("the next page keeps rows that share the last timestamp", async () => {
  const calls = [];
  await exports.fetchClubAnnouncements(client(calls), "club-1", { created_at: "2026-09-27T08:00:00+00:00", id: "b0000000-0000-4000-8000-000000000001" });
  const [, filter] = calls.find(([k]) => k === "or");
  assert.equal(filter, 'created_at.lt."2026-09-27T08:00:00+00:00",and(created_at.eq."2026-09-27T08:00:00+00:00",id.lt.b0000000-0000-4000-8000-000000000001)');
});
