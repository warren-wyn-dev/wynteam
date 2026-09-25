import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function loaded() {
  const source = readFileSync(new URL("../lib/bookmark-collections.ts", import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, {
    exports,
    require: (name) => {
      if (name === "@/lib/feed") {
        return { isQuotePost: (row) => Boolean(row.redrop_id && row.quote_text) };
      }
      if (name === "@/lib/quote-feed-data") {
        return { fetchVisibleQuoteRows: async () => new Map() };
      }
      throw new Error("Unexpected dependency: " + name);
    },
    Date, Map,
  });
  return exports;
}
const collections = loaded();

test("collection name normalization is bounded and strips whitespace", () => {
  assert.equal(collections.normalizeCollectionName("  งานที่ชอบ  "), "งานที่ชอบ");
  assert.throws(() => collections.normalizeCollectionName("  "));
  assert.throws(() => collections.normalizeCollectionName("a".repeat(49)));
  assert.throws(() => collections.normalizeCollectionName("bad\nname"));
});

test("quote membership uses the Quote ID, not the quoted original Drop", () => {
  assert.equal(JSON.stringify(collections.bookmarkContent({
    id: "original", content_type: "drop", redrop_id: "quote-1", quote_text: "Commentary",
  })), JSON.stringify({ content_type: "quote", content_id: "quote-1" }));
  assert.equal(JSON.stringify(collections.bookmarkContent({
    id: "drop-1", content_type: "drop",
  })), JSON.stringify({ content_type: "drop", content_id: "drop-1" }));
  assert.equal(collections.bookmarkContent({ id: "pop-1", content_type: "pop" }), null);
});

test("create invalid collection name fails before any backend mutation", async () => {
  let touched = false;
  const client = { from: () => { touched = true; throw new Error("must not hit server"); } };
  await assert.rejects(() => collections.createBookmarkCollection(client, "A", "\n"));
  assert.equal(touched, false);
});

test("collection page never renders stale IDs not verified by saved_feed", async () => {
  const memberships = [
    { collection_id: "C", content_type: "drop", content_id: "saved-1", created_at: "2026-09-25T10:00:00Z" },
    { collection_id: "C", content_type: "drop", content_id: "unsaved-1", created_at: "2026-09-25T09:00:00Z" },
  ];
  const calls = [];
  const query = (table) => ({
    select: () => query(table),
    eq: (_key,_value) => query(table),
    in: (_key,_ids) => { calls.push([table, _ids]); return Promise.resolve({
      data: table === "saved_feed" ? [{ id: "saved-1", content_type: "drop" }] : [], error: null,
    }); },
    order: () => query(table),
    range: async () => ({ data: memberships, error: null }),
  });
  const out = await collections.fetchBookmarkCollectionPage({ from: query }, "A", "C", 0);
  assert.deepEqual(Array.from(out.rows, (row) => row.id), ["saved-1"]);
  assert.equal(out.hasMore, false);
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], "saved_feed");
});
