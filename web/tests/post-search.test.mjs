import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
const route = readFileSync(new URL("../components/search-route.tsx", import.meta.url), "utf8");
const english = readFileSync(new URL("../lib/i18n/en.ts", import.meta.url), "utf8");
const migration = readFileSync(
  new URL("../../supabase/migrations/20260929140657_web_post_search_ranked_i18n.sql", import.meta.url),
  "utf8",
);

test("Post Search uses ranked IDs with stable 21-row pagination", () => {
  assert.match(data, /client\.rpc\("search_drop_ids_ranked"/);
  assert.match(data, /p_limit:\s*21/);
  assert.match(data, /p_offset:\s*page \* 21/);
  assert.doesNotMatch(data, /\.ilike\("caption"/);
});

test("Post Search preserves database relevance order after loading full cards", () => {
  assert.match(data, /const byId = new Map/);
  assert.match(data, /return ids\.flatMap\(\(id\) => \{/);
  assert.match(data, /const row = byId\.get\(id\)/);
});

test("Thai and English Post Search UI remain bilingual", () => {
  assert.match(route, /id: "posts" as const, label: "โพสต์"/);
  assert.match(route, /ไม่พบโพสต์สำหรับ/);
  assert.match(english, /"โพสต์": "Posts"/);
  assert.match(english, /"ไม่พบโพสต์สำหรับ “": "No posts found for “"/);
  assert.match(english, /"ค้นหาโพสต์ไม่สำเร็จ": "Couldn't search posts"/);
});

test("Post Search supports Thai substring, English token search and typo tolerance", () => {
  assert.match(migration, /lower\(d\.caption\) like '%' \|\| i\.term \|\| '%'/);
  assert.match(migration, /plainto_tsquery\('simple', i\.term\)/);
  assert.match(migration, /extensions\.similarity/);
  assert.match(migration, />= 0\.18/);
});

test("Post Search keeps Drops privacy through SECURITY INVOKER and hides deleted posts", () => {
  assert.match(migration, /security invoker/i);
  assert.match(migration, /d\.deleted_at is null/);
  assert.match(migration, /revoke all on function public\.search_drop_ids_ranked\(text, integer, integer\) from public, anon/i);
  assert.match(migration, /grant execute on function public\.search_drop_ids_ranked\(text, integer, integer\) to authenticated/i);
});

test("Post Search has active-caption trigram and full-text indexes", () => {
  assert.match(migration, /drops_caption_trgm_active_idx/);
  assert.match(migration, /drops_caption_fts_active_idx/);
  assert.match(migration, /where deleted_at is null/);
});
