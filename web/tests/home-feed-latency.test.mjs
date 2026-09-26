import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function loadFeedModule() {
  const source = readFileSync(new URL("../lib/home-feed-sources.ts", import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: "home-feed-sources.ts",
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, {
    exports,
    require: (id) => {
      if (id === "@/lib/feed") {
        return { rankedDropRows: (items, limit) => items.map((item) => item.row_data).slice(0, limit) };
      }
      if (id === "@/lib/quote-feed-data") {
        return { fetchQuoteRepostRows: async () => [] };
      }
      throw new Error("Unexpected dependency: " + id);
    },
    Date,
    Math,
  }, { filename: "home-feed-sources.compiled.js" });
  return exports;
}

test("ranked Feed renders without waiting for impression telemetry", async () => {
  const { fetchRankedDropRows } = loadFeedModule();
  const row = {
    id: "11111111-1111-4111-8111-111111111111",
    content_type: "drop",
    created_at: "2026-09-25T00:00:00Z",
    image_url: "https://example.test/image.png",
  };
  const called = [];
  const client = {
    rpc: (name) => {
      called.push(name);
      if (name === "get_wynos_ranked_feed") {
        return Promise.resolve({ data: [{ row_data: row }], error: null });
      }
      if (name === "record_feed_impressions") {
        // A slow telemetry endpoint must not delay Feed rendering.
        return new Promise(() => {});
      }
      throw new Error("Unexpected RPC: " + name);
    },
    from: (table) => {
      assert.equal(table, "drops");
      return {
        select: (columns) => {
          assert.equal(columns, "id,image_aspect_ratio");
          return {
            in: async (_column, ids) => {
              assert.deepEqual(Array.from(ids), [row.id]);
              return { data: [{ id: row.id, image_aspect_ratio: "16:9" }], error: null };
            },
          };
        },
      };
    },
  };

  let timeout;
  try {
    const result = await Promise.race([
      fetchRankedDropRows(client),
      new Promise((_, reject) => {
        timeout = setTimeout(() => reject(new Error("Feed waited on impression telemetry")), 500);
      }),
    ]);
    assert.equal(result.length, 1);
    assert.equal(result[0].id, row.id);
    assert.equal(result[0].image_aspect_ratio, "16:9");
    assert.ok(called.includes("record_feed_impressions"), "telemetry must still be dispatched");
  } finally {
    clearTimeout(timeout);
  }
});
