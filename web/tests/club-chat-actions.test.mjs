// WYN-135: Web Beta2 Club chat actions, without contacting production.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/club-chat-actions.ts", import.meta.url), "utf8");
const output = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const exports = {};
runInNewContext(output, { exports, require: () => ({}) });
const calls = [];
const rpcClient = {
  rpc: async (name, args) => {
    calls.push([name, args]);
    return { data: name === "search_club_channel_messages"
      ? [{ id: "message1", content: "Hello world", author_id: "member1", created_at: "2026-09-27T00:00:00Z" }]
      : null, error: null };
  },
};

test("only approved staff can pin Club messages", () => {
  for (const role of ["owner", "admin", "moderator"])
    assert.equal(exports.isClubStaff(role, true), true);
  for (const role of ["member", "", null, "owner "])
    assert.equal(exports.isClubStaff(role, true), false);
  assert.equal(exports.isClubStaff("owner", false), false);
});

test("channel search is trimmed, bounded, and never runs for an empty term", async () => {
  calls.length = 0;
  assert.equal(exports.cleanClubChatSearch("  hello  world  "), "hello world");
  assert.equal(exports.cleanClubChatSearch("x".repeat(200)).length, 120);
  const empty = await exports.searchClubChat(rpcClient, "channel1", "  ");
  assert.equal(empty.length, 0);
  assert.equal(calls.length, 0);
  const hits = await exports.searchClubChat(rpcClient, "channel1", "  hello  world  ");
  assert.equal(hits[0].content, "Hello world");
  assert.equal(calls[0][0], "search_club_channel_messages");
  assert.equal(calls[0][1].p_channel_id, "channel1");
  assert.equal(calls[0][1].p_query, "hello world");
  assert.equal(calls[0][1].p_limit, 30);
});

test("client validation prevents blank edits; valid edits and pins use RPCs", async () => {
  calls.length = 0;
  await assert.rejects(() => exports.editClubChatMessage(rpcClient, "m1", "  "));
  await assert.rejects(() => exports.editClubChatMessage(rpcClient, "m1", "a".repeat(2001)));
  assert.equal(calls.length, 0);
  await exports.editClubChatMessage(rpcClient, "m1", "  Updated  ");
  await exports.setClubChatPin(rpcClient, "m1", true);
  await exports.setClubChatPin(rpcClient, "m1", false);
  assert.equal(calls[0][0], "edit_club_channel_message");
  assert.equal(calls[0][1].p_content, "Updated");
  assert.equal(calls[1][1].p_pin, true);
  assert.equal(calls[2][1].p_pin, false);
});

test("pinned messages query is scoped to the open channel and capped", async () => {
  const chainCalls = [];
  const chain = {
    select: (...args) => { chainCalls.push(["select", ...args]); return chain; },
    eq: (...args) => { chainCalls.push(["eq", ...args]); return chain; },
    not: (...args) => { chainCalls.push(["not", ...args]); return chain; },
    order: (...args) => { chainCalls.push(["order", ...args]); return chain; },
    limit: async (count) => { chainCalls.push(["limit", count]); return { data: [], error: null }; },
  };
  await exports.fetchPinnedClubChat({ from: () => chain }, "channel2");
  assert.equal(chainCalls.find(([method]) => method === "eq")[2], "channel2");
  assert.equal(chainCalls.find(([method]) => method === "limit")[1], 3);
});

test("Club chat actions are publicly released while preserving readiness and role guards", () => {
  const page = readFileSync(new URL("../components/club-detail-golden.tsx", import.meta.url), "utf8");
  const gate = readFileSync(new URL("../lib/beta2.ts", import.meta.url), "utf8");
  const sql = readFileSync(new URL("../../supabase/migrations_web_beta2_club_chat_actions.sql", import.meta.url), "utf8");
  assert.match(page, /useBeta2Feature\("clubChatActions", client, userId\)/);
  assert.match(page, /client\.rpc\("club_chat_actions_available"\)/);
  assert.match(page, /beta2Eligible && beta2Ready/);
  assert.match(sql, /public\.club_chat_actions_available\(\)/);
  assert.match(page, /beta2 \? setMenuMessage\(message\)/);
  assert.match(page, /beta2 \? ",edited_at,pinned_at" : ""/);
  assert.match(gate, /clubChatActions: true/);
  assert.equal((sql.match(/if not public\.is_developer_account\(\)/g) ?? []).length, 3, "historical staged migration remains auditable");
  assert.match(sql, /using gin\s*\(to_tsvector\('simple'::regconfig/);
  assert.match(sql, /public\.club_role\(v_club, v_me\)/);
  assert.match(sql, /for update;\s*if not found/);
});


test("mobile Club toolbar keeps pin errors separate from search and safely clears pending queries", () => {
  const toolbar = readFileSync(new URL("../components/club/club-chat-actions.tsx", import.meta.url), "utf8");
  const css = readFileSync(new URL("../app/club-detail-golden.css", import.meta.url), "utf8");
  assert.match(toolbar, /\[pinError, setPinError\] = useState/);
  assert.match(toolbar, /\[searchError, setSearchError\] = useState/);
  assert.match(toolbar, /setPinRetry\(\(value\) => value \+ 1\)/);
  assert.match(toolbar, /\.finally\(\(\) => \{ if \(active\) setPinLoading\(false\); \}\)/);
  assert.match(toolbar, /inputMode="search" enterKeyHint="search"/);
  assert.match(toolbar, /aria-label="ล้างคำค้นหา"/);
  assert.match(toolbar, /pending\.current \+= 1; setBusy\(false\); setSearchError\(""\); setQuery\(""\); setResults\(null\);/);
  assert.match(css, /\.golden-club-search form \.golden-club-search-clear.*min-width: 44px/);
  assert.match(css, /\.golden-club-pin-error button \{ min-height: 44px/);
});
