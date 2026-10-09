import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";

import {
  ALLOWED_HEALTH_ENDPOINTS,
  classifyHttpStatus,
  probePublicReachability,
} from "../lib/system-health-probe.mjs";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Health classification never implies end-to-end availability from a response", () => {
  for (const code of [200, 204, 302, 307]) {
    assert.equal(classifyHttpStatus(code), "reachable");
  }
  for (const code of [500, 502, 503, 404]) {
    assert.equal(classifyHttpStatus(code), "degraded");
  }
  for (const code of [401, 403, 408, 429, 0, 600, undefined]) {
    assert.equal(classifyHttpStatus(code), "unknown");
  }
});

test("Health probe only accesses literal approved public WYNOS endpoints", async () => {
  const visited = [];
  const stub = async (url, options) => {
    visited.push([url, options]);
    return { status: 200 };
  };
  for (const id of ["social", "food", "merchant"]) {
    const result = await probePublicReachability(id, stub);
    assert.equal(result.status, "reachable");
    assert.equal(result.id, id);
    assert.match(result.checkedAt, /^\d{4}-\d\d-\d\dT/);
  }
  assert.deepEqual(visited.map((x) => x[0]), Object.values(ALLOWED_HEALTH_ENDPOINTS));
  for (const [, options] of visited) {
    assert.equal(options.method, "HEAD");
    assert.equal(options.redirect, "manual");
    assert.equal(options.credentials, "omit");
    assert.equal(options.next.revalidate, 120);
    assert.ok(options.signal instanceof AbortSignal);
  }
  assert.deepEqual(Object.keys(ALLOWED_HEALTH_ENDPOINTS).sort(), ["food", "merchant", "social"]);
  await assert.rejects(
    () => probePublicReachability("https://untrusted.invalid/", stub),
    /Untrusted health source/,
  );
});

test("Network errors, protection and rate limits become unknown, not false green", async () => {
  const fail = await probePublicReachability("social", async () => { throw new Error("private token in failure"); });
  assert.equal(fail.status, "unknown");
  assert.doesNotMatch(fail.detail, /private token/);

  const protectedResult = await probePublicReachability("food", async () => ({ status: 403 }));
  assert.equal(protectedResult.status, "unknown");
  const serverError = await probePublicReachability("merchant", async () => ({ status: 503 }));
  assert.equal(serverError.status, "degraded");
});

test("System Health requires authenticated staff and does not request privileged operations", () => {
  const source = read("../lib/admin-system-health.ts");
  const page = read("../app/(admin)/system-health/page.tsx");
  const probe = read("../lib/system-health-probe.mjs");
  const nav = read("../lib/admin-nav.ts");
  const ci = read("../../.github/workflows/ci.yml");
  assert.match(source, /await requireAdminRole\(\)/);
  assert.match(page, /await requireAdminRole\(\)/);
  assert.match(source, /\.from\("profiles"\)\.select\("id"\)\.limit\(1\)/);
  assert.match(page, /ไม่ได้ยืนยัน/);
  assert.match(page, /ยังไม่มีแหล่งข้อมูลเหตุขัดข้อง/);
  assert.match(page, /nextCursor|<article key=\{row\.id\}/);
  assert.doesNotMatch(source + probe, /service_role|\\.update\(|\\.insert\(|\\.delete\(|\\.upsert\(|\\.rpc\(/);
  assert.doesNotMatch(probe, /headers:\s*\{[^}]*Authorization/);
  assert.match(nav, /href: "\/system-health"/);
  assert.match(ci, /for route in \/ \/system-health \/social/);
});
