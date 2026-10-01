import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const route = readFileSync(new URL("../components/search-route.tsx", import.meta.url), "utf8");
const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
const migration = readFileSync(
  new URL("../../supabase/migrations/20260929132826_web_people_search_ranked.sql", import.meta.url),
  "utf8",
);

test("People Search uses the ranked RPC with stable 30-row pagination", () => {
  assert.match(data, /client\.rpc\("search_profiles_ranked"/);
  assert.match(data, /p_limit:\s*30/);
  assert.match(data, /p_offset:\s*page \* 30/);
  assert.doesNotMatch(data, /username\.ilike/);
});

test("Thai search chrome uses People wording and keeps English translation-compatible source text", () => {
  assert.match(route, /id: "users" as const, label: "ผู้ใช้"/);
  assert.match(route, /placeholder="ค้นหาผู้ใช้ โพสต์ และคลับ"/);
  assert.match(route, /aria-label="ค้นหาผู้ใช้ โพสต์ และคลับ"/);
  assert.doesNotMatch(route, /id: "users" as const, label: "User"/);
  assert.match(route, />ดูทั้งหมด \(Top 100\)/);
  assert.match(route, />ดูเพิ่มเติม/);
});

test("ranked search supports @username and prioritizes exact/prefix matches", () => {
  assert.match(migration, /regexp_replace\(trim\(coalesce\(p_query, ''\)\), '\^@\+', ''\)/);
  assert.match(migration, /when lower\(coalesce\(p\.username, ''\)\) = i\.term then 0/);
  assert.match(migration, /when lower\(coalesce\(p\.username, ''\)\) like i\.term \|\| '%' then 1/);
  assert.match(migration, /extensions\.similarity/);
});

test("People Search excludes blocked relationships and stays authenticated-only", () => {
  assert.match(migration, /not internal\.is_blocked_either_way\(auth\.uid\(\), p\.id\)/);
  assert.match(migration, /security invoker/i);
  assert.match(migration, /revoke all on function public\.search_profiles_ranked\(text, integer, integer\) from public, anon/i);
  assert.match(migration, /grant execute on function public\.search_profiles_ranked\(text, integer, integer\) to authenticated/i);
});

test("People Search has trigram indexes for username and display name", () => {
  assert.match(migration, /profiles_username_trgm_idx/);
  assert.match(migration, /profiles_display_name_trgm_idx/);
  assert.match(migration, /extensions\.gin_trgm_ops/);
});
