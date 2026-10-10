import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import {
  AUDIT_EVENT_TYPES,
  parseAuditFilters,
  encodeAuditCursor,
  decodeAuditCursor,
  nextBangkokDay,
  toBangkokMidnightIso,
} from "../lib/audit-log-filters.mjs";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const uuid = "00000000-0000-4000-8000-000000000001";

test("Audit Log accepts a bounded set of supported search fields", () => {
  assert.equal(AUDIT_EVENT_TYPES.length, 11);
  const filters = parseAuditFilters({
    event_type: "moderation_action_applied",
    actor_id: uuid,
    from: "2026-10-01",
    to: "2026-10-09",
  });
  assert.equal(filters.actorId, uuid);
  assert.equal(filters.eventType, "moderation_action_applied");
  assert.equal(filters.from, "2026-10-01");
  assert.equal(filters.to, "2026-10-09");
  assert.equal(filters.cursor, null);
});

test("Malformed actor, event, date and duplicate query params fail closed", () => {
  for (const query of [
    { actor_id: "bob" },
    { actor_id: uuid + ",event_type.eq.account_deleted" },
    { event_type: "unknown_event" },
    { event_type: ["account_deleted", "data_exported"] },
    { from: "2026-02-30" },
    { from: "2026-10-10", to: "2026-10-01" },
    { from: "2026-10-01;drop table" },
    { cursor: "%%%invalid" },
    { actor_id: "x".repeat(300) },
  ]) {
    assert.throws(() => parseAuditFilters(query), undefined, JSON.stringify(query));
  }
});

test("Bangkok date range is start inclusive / next day exclusive", () => {
  assert.equal(toBangkokMidnightIso("2026-10-09"), "2026-10-08T17:00:00.000Z");
  assert.equal(nextBangkokDay("2026-12-31"), "2027-01-01");
  assert.equal(toBangkokMidnightIso(nextBangkokDay("2026-10-09")), "2026-10-09T17:00:00.000Z");
});

test("Cursor is strict, reversible and cannot inject PostgREST OR filters", () => {
  const source = { id: uuid, created_at: "2026-10-09T11:30:11.123456+00:00" };
  const cursor = encodeAuditCursor(source);
  assert.deepEqual(decodeAuditCursor(cursor), { id: uuid, createdAt: source.created_at });
  assert.deepEqual(parseAuditFilters({ cursor }).cursor, { id: uuid, createdAt: source.created_at });
  for (const value of [
    Buffer.from(JSON.stringify({ t: "2026-10-09T11:30:11Z", id: uuid + ",role.eq.admin" })).toString("base64url"),
    Buffer.from(JSON.stringify({ t: "2026-10-09T11:30:11Z),or(actor_id.neq.0", id: uuid })).toString("base64url"),
    Buffer.from("not-json").toString("base64url"),
    "x".repeat(501),
  ]) assert.throws(() => decodeAuditCursor(value));
});

test("Audit Log Plus remains read-only and omits raw detail payloads", () => {
  const query = read("../lib/admin-audit-log.ts");
  const page = read("../app/(admin)/audit-log/page.tsx");
  const results = read("../app/(admin)/audit-log/results.tsx");
  assert.match(page, /await requireAdminRole\(\)/);
  assert.match(query, /AUDIT_LOG_PAGE_SIZE = 50/);
  assert.match(query, /\.order\("created_at", \{ ascending: false \}\)/);
  assert.match(query, /\.order\("id", \{ ascending: false \}\)/);
  assert.match(query, /\.limit\(AUDIT_LOG_PAGE_SIZE \+ 1\)/);
  assert.match(query, /\.or\(/);
  assert.match(query, /\.select\("id, actor_id, actor_username_snapshot, event_type, target_id, created_at"\)/);
  assert.doesNotMatch(results, /JSON\.stringify\(row\.detail/);
  assert.doesNotMatch(query, /fetchAuditLog\(/, "obsolete full-detail API must stay removed");
  assert.doesNotMatch(query, /target_id, detail, created_at/, "raw detail must not be queried");
  assert.doesNotMatch(query.slice(query.indexOf("export async function fetchAuditLogPage")), /\.insert\(|\.update\(|\.delete\(|\.upsert\(/);
  assert.match(results, /nextCursor/);
  assert.match(page, /type="date"/);
});
