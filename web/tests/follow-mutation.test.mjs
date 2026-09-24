import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

// Execute the actual TypeScript module with only its external imports mocked.
// No production credentials and no fabricated SQL fixtures are required.
const source = readFileSync(new URL("../lib/home-actions.ts", import.meta.url), "utf8");
const output = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;
const events = [];
const exports = {};
vm.runInNewContext(output, {
  exports,
  module: { exports },
  require(id) {
    if (id === "@/lib/follow-state") return { publishFollowChange: (event) => events.push(event) };
    if (id === "@/lib/quote-actions") return { fetchQuoteEngagement() { throw new Error("unneeded"); } };
    throw new Error("Unexpected module: " + id);
  },
});
const { toggleAuthorFollow } = exports;
assert.equal(typeof toggleAuthorFollow, "function");

function mockClient({ follows = [], requests = [], race = false, failRead = false } = {}) {
  const stored = { follows: new Set(follows), follow_requests: new Set(requests) };
  const writes = [];
  const key = (table, row) => table === "follows"
    ? row.follower_id + "|" + row.following_id
    : row.requester_id + "|" + row.target_id;
  const filteredKey = (table, where) => table === "follows"
    ? where.follower_id + "|" + where.following_id
    : where.requester_id + "|" + where.target_id;
  return {
    stored,
    writes,
    from(table) {
      assert.ok(table === "follows" || table === "follow_requests");
      const where = {};
      let mode = "read";
      const builder = {
        select() { return builder; },
        eq(field, value) { where[field] = value; return builder; },
        async maybeSingle() {
          if (failRead) return { data: null, error: { message: "network unavailable" } };
          const present = stored[table].has(filteredKey(table, where));
          return { data: present ? (table === "follows" ? { following_id: where.following_id } : { target_id: where.target_id }) : null, error: null };
        },
        delete() { mode = "delete"; return builder; },
        async upsert(row, options) {
          writes.push({ table, kind: "upsert", options });
          const id = key(table, row);
          // Simulate an independent tab inserting after our read.
          if (race) stored[table].add(id);
          if (stored[table].has(id) && !options?.ignoreDuplicates) {
            return { error: { message: "duplicate key value violates unique constraint" } };
          }
          stored[table].add(id);
          return { error: null };
        },
        then(resolve) {
          assert.equal(mode, "delete");
          writes.push({ table, kind: "delete" });
          stored[table].delete(filteredKey(table, where));
          resolve({ error: null });
        },
      };
      return builder;
    },
  };
}

const actor = "new-user";
const official = "official-user";
const pair = actor + "|" + official;
const publicOptions = (currentlyFollowing) => ({ currentlyFollowing, pendingRequest: false, isPrivate: false });

test("auto-follow already exists: stale Search button synchronizes without duplicate insert", async () => {
  events.length = 0;
  const client = mockClient({ follows: [pair] });
  const result = await toggleAuthorFollow(client, actor, official, publicOptions(false));
  assert.equal(result, "following");
  assert.equal(client.stored.follows.size, 1);
  assert.equal(client.writes.length, 0);
  assert.equal(events.at(-1).state, "following");
});

test("unfollow, stale list, then follow from Search works again and never auto-refollows", async () => {
  events.length = 0;
  const client = mockClient({ follows: [pair] });
  assert.equal(await toggleAuthorFollow(client, actor, official, publicOptions(true)), "none");
  assert.equal(client.stored.follows.size, 0);
  // Another screen still shows the earlier "Following" button.
  assert.equal(await toggleAuthorFollow(client, actor, official, publicOptions(true)), "none");
  assert.equal(client.writes.length, 1);
  // A fresh Search button can re-follow by explicit user action.
  assert.equal(await toggleAuthorFollow(client, actor, official, publicOptions(false)), "following");
  assert.equal(client.stored.follows.size, 1);
  assert.equal(client.writes.at(-1).options.onConflict, "follower_id,following_id");
  assert.equal(client.writes.at(-1).options.ignoreDuplicates, true);
  assert.deepEqual(events.map((e) => e.state), ["none", "none", "following"]);
});

test("concurrent second insert cannot produce follows_pkey error", async () => {
  events.length = 0;
  const client = mockClient({ race: true });
  assert.equal(await toggleAuthorFollow(client, actor, official, publicOptions(false)), "following");
  assert.equal(client.stored.follows.size, 1);
  assert.equal(client.writes.at(-1).options.ignoreDuplicates, true);
});

test("private follow requests are idempotent and can be cancelled", async () => {
  events.length = 0;
  const client = mockClient();
  const options = (pendingRequest) => ({ currentlyFollowing: false, pendingRequest, isPrivate: true });
  assert.equal(await toggleAuthorFollow(client, actor, official, options(false)), "requested");
  assert.equal(client.stored.follow_requests.size, 1);
  assert.equal(client.writes.at(-1).options.onConflict, "requester_id,target_id");
  assert.equal(await toggleAuthorFollow(client, actor, official, options(true)), "none");
  assert.equal(client.stored.follow_requests.size, 0);
});

test("failed authoritative read neither mutates nor publishes a success event", async () => {
  events.length = 0;
  const client = mockClient({ failRead: true });
  await assert.rejects(toggleAuthorFollow(client, actor, official, publicOptions(false)), /network unavailable/);
  assert.equal(client.writes.length, 0);
  assert.equal(events.length, 0);
});
