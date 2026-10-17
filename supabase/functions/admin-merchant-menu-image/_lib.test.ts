import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import { MAX_MENU_IMAGE_BYTES, menuImageHandler, type MenuImageDependencies, type UploadPermission } from "./_lib.ts";

const STORE = "10000000-0000-4000-8000-000000000001";
const IMAGE = "20000000-0000-4000-8000-000000000001";
const RAW = new Uint8Array([1, 2, 3]);
const ENCODED = new Uint8Array([4, 5, 6]);

function request(options: { store?: string; headers?: Record<string, string>; body?: BodyInit | null; method?: string } = {}) {
  return new Request(`https://synthetic.invalid/functions/v1/admin-merchant-menu-image?store_id=${options.store ?? STORE}`, {
    method: options.method ?? "POST",
    headers: { Authorization: "Bearer synthetic-user-token", "Content-Type": "image/jpeg", ...options.headers },
    body: options.method === "OPTIONS" || options.method === "GET" ? null : options.body === undefined ? RAW : options.body,
  });
}
function fixture(overrides: Partial<MenuImageDependencies> = {}) {
  const calls: string[] = [];
  const published: Array<{ path: string; bytes: Uint8Array }> = [];
  const handler = menuImageHandler({
    authenticate: async (authorization) => { calls.push("authenticate"); assertEquals(authorization, "Bearer synthetic-user-token"); return true; },
    authorize: async (_authorization, store) => { calls.push("authorize"); assertEquals(store, STORE); return "allowed"; },
    normalize: async (bytes, type) => { calls.push("normalize"); assertEquals(bytes, RAW); assertEquals(type, "image/jpeg"); return ENCODED; },
    publish: async (path, bytes) => { calls.push("publish"); published.push({ path, bytes }); },
    randomId: () => IMAGE,
    ...overrides,
  });
  return { handler, calls, published };
}

Deno.test("menu image upload authenticates and authorizes before decoding; publishes only normalized bytes", async () => {
  const { handler, calls, published } = fixture();
  const response = await handler(request({ store: STORE.toUpperCase() }));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { path: `admin-menu/${STORE}/${IMAGE}.webp` });
  assertEquals(calls, ["authenticate", "authorize", "normalize", "publish"]);
  assertEquals(published, [{ path: `admin-menu/${STORE}/${IMAGE}.webp`, bytes: ENCODED }]);
  assertEquals(response.headers.get("Cache-Control"), "no-store");
});

Deno.test("menu image preflight and invalid envelope never read identities or publish", async () => {
  const cases: Array<[Request, number]> = [
    [request({ method: "OPTIONS" }), 204],
    [request({ method: "GET" }), 405],
    [request({ headers: { Authorization: "" } }), 401],
    [request({ headers: { Authorization: "Basic untrusted" } }), 401],
    [request({ store: "../foreign" }), 400],
    [request({ headers: { "Content-Type": "image/svg+xml" } }), 415],
    [request({ headers: { "Content-Length": "-1" } }), 400],
    [request({ headers: { "Content-Length": "0" } }), 400],
    [request({ headers: { "Content-Length": String(MAX_MENU_IMAGE_BYTES + 1) } }), 413],
  ];
  for (const [input, expected] of cases) {
    const { handler, calls, published } = fixture();
    assertEquals((await handler(input)).status, expected);
    assertEquals(calls, []);
    assertEquals(published, []);
  }
});

Deno.test("expired JWT and denied or limited permission never decode or write", async () => {
  const denied = fixture({ authenticate: async () => false });
  assertEquals((await denied.handler(request())).status, 401);
  assertEquals(denied.calls, []);
  const cases: Array<[UploadPermission, number]> = [["denied", 403], ["missing", 404], ["limited", 429], ["unavailable", 503]];
  for (const [permission, status] of cases) {
    const { handler, calls, published } = fixture({ authorize: async () => permission });
    assertEquals((await handler(request())).status, status);
    assertEquals(calls, ["authenticate"]);
    assertEquals(published, []);
  }
});

Deno.test("streamed body is bounded independently of client length claims", async () => {
  let cancelled = false;
  const body = new ReadableStream({
    start(controller) {
      controller.enqueue(new Uint8Array(MAX_MENU_IMAGE_BYTES));
      controller.enqueue(new Uint8Array([1]));
    },
    cancel() { cancelled = true; },
  });
  const { handler, calls, published } = fixture();
  assertEquals((await handler(request({ body, headers: { "Content-Length": "3" } }))).status, 413);
  assertEquals(cancelled, true);
  assertEquals(calls, ["authenticate", "authorize"]);
  assertEquals(published, []);
});

Deno.test("empty and inconsistent bodies never reach the decoder", async () => {
  for (const input of [request({ body: null }), request({ body: new Uint8Array() }), request({ headers: { "Content-Length": "2" } })]) {
    const { handler, calls } = fixture();
    assertEquals([400, 413].includes((await handler(input)).status), true);
    assertEquals(calls, ["authenticate", "authorize"]);
  }
});

Deno.test("corrupt content and oversized normalized results never reach Storage", async () => {
  for (const normalize of [
    async () => { throw new Error("corrupt decoder detail"); },
    async () => new Uint8Array(),
    async () => new Uint8Array(MAX_MENU_IMAGE_BYTES + 1),
  ]) {
    const { handler, published } = fixture({ normalize });
    const response = await handler(request());
    assertEquals(response.status, 422);
    assertEquals(published, []);
    assertEquals((await response.text()).includes("corrupt decoder detail"), false);
  }
});

Deno.test("Auth, permission and Storage failures return only redacted retryable errors", async () => {
  const fail = async () => { throw new Error("private provider diagnostic must never be returned"); };
  for (const overrides of [{ authenticate: fail }, { authorize: fail }, { publish: fail }]) {
    const { handler } = fixture(overrides);
    const response = await handler(request());
    assertEquals(response.status, 503);
    assertEquals(await response.json(), { error: "upload_unavailable" });
  }
});

Deno.test("publisher generates its own immutable canonical name and rejects bad generator output", async () => {
  const { handler } = fixture({ randomId: undefined });
  const response = await handler(request());
  assertEquals(response.status, 200);
  assertMatch((await response.json()).path, new RegExp(`^admin-menu/${STORE}/[0-9a-f-]{36}\\.webp$`));
  const invalid = fixture({ randomId: () => "../../foreign.webp" });
  assertEquals((await invalid.handler(request())).status, 503);
  assertEquals(invalid.published, []);
});

Deno.test("an observed request cancellation before publication preserves all existing objects", async () => {
  const controller = new AbortController();
  const { handler, published } = fixture({ normalize: async () => { controller.abort(); return ENCODED; } });
  const input = new Request(request(), { signal: controller.signal });
  const response = await handler(input);
  assertEquals(response.status, 400);
  assertEquals(await response.json(), { error: "upload_cancelled" });
  assertEquals(published, []);
});

Deno.test("overlapping uploads do not allocate or decode another body while the isolate is busy", async () => {
  let release!: (bytes: Uint8Array) => void;
  let entered!: () => void;
  const ready = new Promise<void>(resolve => { entered = resolve; });
  let decodeCount = 0;
  const { handler, published } = fixture({ normalize: async () => {
    decodeCount++;
    if (decodeCount > 1) return ENCODED;
    entered();
    return await new Promise<Uint8Array>(resolve => { release = resolve; });
  } });
  const first = handler(request());
  await ready;
  const concurrent = await handler(request());
  assertEquals(concurrent.status, 503);
  assertEquals(await concurrent.json(), { error: "upload_busy" });
  assertEquals(decodeCount, 1);
  assertEquals(published, []);
  release(ENCODED);
  assertEquals((await first).status, 200);
  assertEquals((await handler(request())).status, 200);
  assertEquals(decodeCount, 2);
});

Deno.test("a failed decoder releases isolate admission for a later retry", async () => {
  let calls = 0;
  const { handler, published } = fixture({ normalize: async () => {
    if (++calls === 1) throw new Error("invalid first input");
    return ENCODED;
  } });
  assertEquals((await handler(request())).status, 422);
  assertEquals((await handler(request())).status, 200);
  assertEquals(published.length, 1);
});
