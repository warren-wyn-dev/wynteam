import assert from "node:assert/strict";
import test, { mock } from "node:test";

import { createClockSkewRetryFetch, sessionErrorCopy } from "../lib/supabase/clock-skew-fetch.ts";

const skew = () => new Response(JSON.stringify({ code: "PGRST303", message: "JWT issued at future" }), { status: 401 });
const ok = () => new Response("[]", { status: 200 });

test("retries 401 JWT issued at future until the database accepts the token", async () => {
  mock.timers.enable({ apis: ["setTimeout"] });
  try {
    const responses = [skew(), skew(), ok()];
    let calls = 0;
    const retryFetch = createClockSkewRetryFetch(async () => responses[calls++]);
    const pending = retryFetch("https://example.test/rest/v1/rpc/x", { method: "POST", body: "{}" });
    for (let i = 0; i < 2; i += 1) { await new Promise((r) => setImmediate(r)); mock.timers.tick(5000); }
    const response = await pending;
    assert.equal(response.status, 200);
    assert.equal(calls, 3);
  } finally {
    mock.timers.reset();
  }
});

test("does not retry other 401s", async () => {
  let calls = 0;
  const retryFetch = createClockSkewRetryFetch(async () => { calls += 1; return new Response('{"message":"JWT expired"}', { status: 401 }); });
  const response = await retryFetch("https://example.test/rest/v1/x");
  assert.equal(response.status, 401);
  assert.equal(calls, 1);
});

test("does not resend a streamed body", async () => {
  let calls = 0;
  const retryFetch = createClockSkewRetryFetch(async () => { calls += 1; return skew(); });
  const response = await retryFetch("https://example.test/storage/v1/x", { method: "POST", body: new ReadableStream() });
  assert.equal(response.status, 401);
  assert.equal(calls, 1);
});

test("returns the skew 401 once retries are exhausted, and the copy is Thai", async () => {
  mock.timers.enable({ apis: ["setTimeout"] });
  try {
    let calls = 0;
    const retryFetch = createClockSkewRetryFetch(async () => { calls += 1; return skew(); });
    const pending = retryFetch("https://example.test/rest/v1/rpc/x", { method: "POST", body: "{}" });
    for (let i = 0; i < 8; i += 1) { await new Promise((r) => setImmediate(r)); mock.timers.tick(13000); }
    const response = await pending;
    assert.equal(response.status, 401);
    assert.equal(calls, 8);
  } finally {
    mock.timers.reset();
  }
  assert.equal(sessionErrorCopy("JWT issued at future"), "กำลังยืนยันการเข้าสู่ระบบ กรุณาลองอีกครั้งในอีกสักครู่");
  assert.equal(sessionErrorCopy("JWT expired"), "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง");
  assert.equal(sessionErrorCopy("store is closed"), null);
});

test("a token still rejected after two tries is resent once with a freshly issued token", async () => {
  const seen = [];
  let refreshes = 0;
  const retryFetch = createClockSkewRetryFetch(
    async (_url, init) => { const auth = new Headers(init?.headers).get("Authorization"); seen.push(auth); return auth === "Bearer fresh" ? ok() : skew(); },
    async () => { refreshes += 1; return "fresh"; },
  );
  mock.timers.enable({ apis: ["setTimeout"] });
  try {
    const pending = retryFetch("https://example.test/rest/v1/x", { headers: { Authorization: "Bearer stale", apikey: "k" } });
    for (let i = 0; i < 3; i += 1) { await new Promise((r) => setImmediate(r)); mock.timers.tick(5000); }
    const response = await pending;
    assert.equal(response.status, 200);
  } finally {
    mock.timers.reset();
  }
  assert.equal(refreshes, 1);
  assert.deepEqual(seen, ["Bearer stale", "Bearer stale", "Bearer fresh"]);
});

test("a request without a bearer token keeps its headers when a refresh is offered", async () => {
  const seen = [];
  const retryFetch = createClockSkewRetryFetch(async (_url, init) => { seen.push(new Headers(init?.headers).get("Authorization")); return ok(); }, async () => "fresh");
  await retryFetch("https://example.test/rest/v1/x", { headers: { apikey: "k" } });
  assert.deepEqual(seen, [null]);
});

test("concurrent rejected requests share one refresh within the cooldown", async () => {
  const { createSharedTokenRefresher } = await import("../lib/supabase/clock-skew-fetch.ts");
  let calls = 0, clock = 0;
  const refresh = createSharedTokenRefresher(async () => { calls += 1; return "t" + calls; }, 30_000, () => clock);
  assert.deepEqual(await Promise.all([refresh(), refresh(), refresh()]), ["t1", "t1", "t1"]);
  clock = 10_000;
  assert.equal(await refresh(), "t1");
  clock = 40_000;
  assert.equal(await refresh(), "t2");
  assert.equal(calls, 2);
});
