import assert from "node:assert/strict";
import test, { mock } from "node:test";

import { createClockSkewRetryFetch } from "../lib/supabase/clock-skew-fetch.ts";

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
