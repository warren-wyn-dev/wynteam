import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";

import { parseAdminSearchQuery, toSafeIlikePattern } from "../lib/admin-search-query.mjs";
const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Search safely normalizes names and order numbers and bounds the work", () => {
  assert.deepEqual(parseAdminSearchQuery(), { query: "", hasQuery: false });
  assert.deepEqual(parseAdminSearchQuery("  ร้าน  อาหาร  "), { query: "ร้าน อาหาร", hasQuery: true });
  assert.deepEqual(parseAdminSearchQuery("  user_name "), { query: "user_name", hasQuery: true });
  assert.deepEqual(parseAdminSearchQuery("OD-2026-123"), { query: "OD-2026-123", hasQuery: true });
  assert.equal(toSafeIlikePattern("hello_world"), "%hello\\_world%");
  assert.equal(toSafeIlikePattern("hello"), "%hello%");
});

test("Search rejects sensitive identifiers, operators and malformed query arrays", () => {
  for (const value of [
    "a", "z".repeat(49), "somebody@example.com", "0812345678", "id%foo",
    "hello,or(username.neq.x)", "\nhello", ["valid", "invalid"],
    "hello\\world", "123456789", "foo;select", "foo()",
  ]) {
    assert.throws(() => parseAdminSearchQuery(value), undefined, String(value));
  }
});

test("Search enforces server-side auth, least privilege and source isolation", () => {
  const source = read("../lib/admin-global-search.ts");
  const page = read("../app/(admin)/search/page.tsx");
  const header = read("../components/admin/header.tsx");
  assert.match(source, /await requireAdminRole\(\)/);
  assert.match(page, /await requireAdminRole\(\)/);
  assert.match(source, /if \(role === "moderator"\)/);
  assert.match(source, /return \[await users\];/);
  assert.match(source, /safeSection\("orders"/);
  assert.match(source, /safeSection\("stores"/);
  assert.match(source, /status: "unavailable"/);
  assert.match(source, /\\.select\("id, username, display_name"\)/);
  assert.match(source, /\\.ilike\("username", pattern\)/);
  assert.match(source, /\\.ilike\("display_name", pattern\)/);
  assert.doesNotMatch(source, /\.or\(|service_role|\\.insert\(|\\.update\(|\\.delete\(|\\.upsert\(/);
  assert.doesNotMatch(page, /recipient_phone|contact_name|address|payment_status|\\.email/);
  assert.match(header, /href="\/search" aria-label="ค้นหาทั้งระบบ"/);
  assert.match(page, /type="search"/);
  assert.match(page, /min-h-11/);
});

test("Order results use order references only, never search recipients", () => {
  const source = read("../lib/admin-global-search.ts");
  assert.match(source, /if \(!\/\^\[A-Za-z0-9-\]\{4,48\}\$\/\.test\(term\)\) return \[\]/);
  assert.match(source, /row\.order_number\.toLowerCase\(\)\.includes\(term\.toLowerCase\(\)\)/);
  assert.doesNotMatch(source, /row\\.recipient_name|row\\.recipient_phone|row\\.total|row\\.payment_status/);
  assert.match(source, /\\.limit\(PER_CATEGORY_LIMIT\)/);
  assert.match(source, /limit: PER_CATEGORY_LIMIT/);
});
