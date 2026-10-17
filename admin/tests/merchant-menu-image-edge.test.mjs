import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import { createClient } from "@supabase/supabase-js";
import ts from "typescript";

const SUPABASE_URL = "https://synthetic.supabase.invalid";
const STORE = "abcdefab-1234-4abc-8def-001122aabbcc";
const USER_TOKEN = "synthetic-user-jwt";
const PUBLIC_KEY = "synthetic-public-key";
const SERVICE_KEY = "synthetic-service-role-key";
const PRIVATE_DIAGNOSTIC = "synthetic private provider diagnostic";
const RAW = new Uint8Array([1, 2, 3]);
const NORMALIZED = new Uint8Array([82, 73, 70, 70, 4, 5, 6]);

function compile(file) {
  return ts.transpileModule(readFileSync(new URL(file, import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
}
const compiledLibrary = compile("../../supabase/functions/admin-merchant-menu-image/_lib.ts");
const compiledEntrypoint = compile("../../supabase/functions/admin-merchant-menu-image/index.ts");
const legacyEnvironment = {
  SUPABASE_URL,
  SUPABASE_ANON_KEY: PUBLIC_KEY,
  SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
};

function fixture({ environment = legacyEnvironment, authStatus = 200,
  authBody = { id: "12345678-1234-4123-8123-123456789abc" }, authMalformedJson = false, authThrows = false,
  rpcResult = true, rpcError, rpcMalformedJson = false, storageStatus = 200, storageThrows = false } = {}) {
  const requests = [], normalizations = [], environmentReads = [];
  let handler;
  const globals = {
    Response, Request, Headers, URL, Uint8Array, AbortSignal, setTimeout, clearTimeout,
    crypto: webcrypto,
  };
  const library = {};
  runInNewContext(compiledLibrary, { exports: library, ...globals });
  const syntheticFetch = async (input, init = {}) => {
    const url = new URL(typeof input === "string" ? input : input.url);
    assert.equal(url.origin, SUPABASE_URL, "all HTTP requests must stay inside the synthetic fetch fixture");
    const request = {
      path: url.pathname, method: init.method ?? "GET",
      headers: new Headers(init.headers), body: init.body, signal: init.signal,
    };
    requests.push(request);
    if (url.pathname === "/auth/v1/user") {
      if (authThrows) throw new Error(PRIVATE_DIAGNOSTIC);
      if (authMalformedJson) return new Response("malformed JSON", { status: authStatus });
      return Response.json(authStatus === 200 ? authBody
        : { code: "bad_jwt", message: PRIVATE_DIAGNOSTIC }, { status: authStatus });
    }
    if (url.pathname === "/rest/v1/rpc/admin_authorize_merchant_menu_upload") {
      if (rpcMalformedJson) return new Response("malformed JSON");
      return Response.json(rpcError ? { code: "P0001", message: rpcError, details: PRIVATE_DIAGNOSTIC }
        : rpcResult, { status: rpcError ? 400 : 200 });
    }
    assert.match(url.pathname, new RegExp(`^/storage/v1/object/food-public/admin-menu/${STORE}/[0-9a-f-]{36}\\.webp$`));
    if (storageThrows) throw new Error(PRIVATE_DIAGNOSTIC);
    return Response.json(storageStatus === 200 ? { Key: url.pathname.slice("/storage/v1/object/".length) }
      : { error: PRIVATE_DIAGNOSTIC, message: PRIVATE_DIAGNOSTIC, statusCode: String(storageStatus) }, { status: storageStatus });
  };
  runInNewContext(compiledEntrypoint, {
    exports: {}, ...globals, fetch: syntheticFetch,
    Deno: {
      env: { get(name) { environmentReads.push(name); return environment[name]; } },
      serve(value) { assert.equal(handler, undefined); handler = value; },
    },
    require(name) {
      if (name === "./_lib.ts") return library;
      if (name === "./_image.ts") return {
        async normalizeMenuImage(bytes, contentType) {
          normalizations.push({ bytes: Array.from(bytes), contentType });
          return NORMALIZED;
        },
      };
      assert.fail(`Unexpected module in the native HTTP entrypoint: ${name}`);
    },
  });
  assert.equal(typeof handler, "function");
  return { requests, normalizations, environmentReads,
    run() {
      return handler(new Request(`${SUPABASE_URL}/functions/v1/admin-merchant-menu-image?store_id=${STORE.toUpperCase()}`, {
        method: "POST", headers: { Authorization: `Bearer ${USER_TOKEN}`, "Content-Type": "image/jpeg" }, body: RAW,
      }));
    },
  };
}

function assertUserRequest(request, publicKey = PUBLIC_KEY) {
  assert.equal(request.headers.get("authorization"), `Bearer ${USER_TOKEN}`);
  assert.equal(request.headers.get("apikey"), publicKey);
  assert.ok(request.signal instanceof AbortSignal);
  assert.equal(request.signal.aborted, false);
}

test("actual Edge HTTP entrypoint separates caller authorization from the immutable normalized-image publisher", async () => {
  const f = fixture();
  const response = await f.run();
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.match(result.path, new RegExp(`^admin-menu/${STORE}/[0-9a-f-]{36}\\.webp$`));
  assert.equal(f.requests.length, 3);
  const [auth, permission, storage] = f.requests;
  assert.equal(auth.path, "/auth/v1/user");
  assert.equal(auth.method, "GET");
  assertUserRequest(auth);
  assert.equal(permission.path, "/rest/v1/rpc/admin_authorize_merchant_menu_upload");
  assert.equal(permission.method, "POST");
  assertUserRequest(permission);
  assert.deepEqual(JSON.parse(permission.body), { p_store_id: STORE });
  assert.equal(storage.path, `/storage/v1/object/food-public/${result.path}`);
  assert.equal(storage.method, "POST");
  assert.equal(storage.headers.get("authorization"), `Bearer ${SERVICE_KEY}`);
  assert.equal(storage.headers.get("apikey"), SERVICE_KEY);
  assert.equal(storage.headers.get("content-type"), "image/webp");
  assert.equal(storage.headers.get("x-upsert"), "false");
  assert.equal(storage.headers.get("cache-control"), "max-age=31536000");
  assert.deepEqual(Array.from(storage.body), Array.from(NORMALIZED));
  assert.deepEqual(f.normalizations, [{ bytes: Array.from(RAW), contentType: "image/jpeg" }]);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.deepEqual(Object.keys(result), ["path"]);
});

for (const [name, environment, publicKey, serviceKey] of [
  ["new named-key JSON prefers default over another key", {
    SUPABASE_URL, SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ rotated: "unused-public", default: "sb_publishable_synthetic" }),
    SUPABASE_SECRET_KEYS: JSON.stringify({ rotated: "unused-service", default: "sb_secret_synthetic" }),
  }, "sb_publishable_synthetic", "sb_secret_synthetic"],
  ["new named-key JSON supports a single nondefault key", {
    SUPABASE_URL, SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ current: PUBLIC_KEY }),
    SUPABASE_SECRET_KEYS: JSON.stringify({ current: SERVICE_KEY }),
  }, PUBLIC_KEY, SERVICE_KEY],
  ["configured legacy keys retain precedence over named-key JSON", {
    ...legacyEnvironment, SUPABASE_PUBLISHABLE_KEYS: "malformed unused JSON", SUPABASE_SECRET_KEYS: "malformed unused JSON",
  }, PUBLIC_KEY, SERVICE_KEY],
]) {
  test(`runtime configuration: ${name}`, async () => {
    const f = fixture({ environment });
    assert.equal((await f.run()).status, 200);
    assertUserRequest(f.requests[0], publicKey);
    assertUserRequest(f.requests[1], publicKey);
    assert.equal(f.requests[2].headers.get("apikey"), serviceKey);
    assert.equal(f.requests[2].headers.get("authorization"), `Bearer ${serviceKey}`);
  });
}

for (const [message, status, code] of [
  ["Not authorized", 403, "not_authorized"],
  ["Menu image upload limit reached", 429, "upload_limit_reached"],
  ["Store not found", 404, "store_not_found"],
  [PRIVATE_DIAGNOSTIC, 503, "upload_unavailable"],
]) {
  test(`RPC permission failure ${status} cannot decode or use privileged Storage`, async () => {
    const f = fixture({ rpcError: message });
    const response = await f.run();
    assert.equal(response.status, status);
    assert.deepEqual(await response.json(), { error: code });
    assert.equal(f.requests.length, 2);
    f.requests.forEach(request => assertUserRequest(request));
    assert.deepEqual(f.normalizations, []);
  });
}

test("only literal true from the live permission RPC admits an upload", async () => {
  for (const rpcResult of [false, null, "true", 1, {}, [], { allowed: true }]) {
    const f = fixture({ rpcResult });
    const response = await f.run();
    assert.equal(response.status, 403);
    assert.deepEqual(await response.json(), { error: "not_authorized" });
    assert.equal(f.requests.length, 2);
    assert.deepEqual(f.normalizations, []);
  }
});

test("expired or rejected Auth fails closed before permission checks without exposing diagnostics", async () => {
  for (const authStatus of [401, 403]) {
    const f = fixture({ authStatus });
    const response = await f.run();
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: "unauthorized" });
    assert.equal(f.requests.length, 1);
    assertUserRequest(f.requests[0]);
    assert.deepEqual(f.normalizations, []);
  }
});

test("Auth provider and transport failures stay retryable instead of falsely reporting an expired session", async () => {
  for (const options of [{ authStatus: 503 }, { authStatus: 429 }, { authThrows: true }]) {
    const f = fixture(options);
    const response = await f.run();
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: "upload_unavailable" });
    assert.equal(f.requests.length, 1);
    assertUserRequest(f.requests[0]);
    assert.deepEqual(f.normalizations, []);
  }
});

test("malformed Auth identities and JSON never authorize a request", async () => {
  for (const options of [
    ...[{}, null, [], "untrusted", { id: null }, { id: "" }, { id: 17 }, { id: "not-a-uuid" }]
      .map(authBody => ({ authBody })),
    { authMalformedJson: true },
  ]) {
    const f = fixture(options);
    const response = await f.run();
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: "upload_unavailable" });
    assert.equal(f.requests.length, 1);
    assert.deepEqual(f.normalizations, []);
  }
});

test("malformed permission JSON fails closed without decoding or using privileged Storage", async () => {
  const f = fixture({ rpcMalformedJson: true });
  const response = await f.run();
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "upload_unavailable" });
  assert.equal(f.requests.length, 2);
  f.requests.forEach(request => assertUserRequest(request));
  assert.deepEqual(f.normalizations, []);
});

test("Storage provider and transport failures never delete, replace or attach an image", async () => {
  for (const options of [{ storageStatus: 503 }, { storageThrows: true }]) {
    const f = fixture(options);
    const response = await f.run();
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: "upload_unavailable" });
    assert.equal(f.requests.length, 3, "failure must not issue cleanup, retry writes or menu mutations");
    assert.deepEqual(f.requests.map(request => request.method), ["GET", "POST", "POST"]);
    assert.equal(f.requests[2].headers.get("x-upsert"), "false");
    assert.equal(f.normalizations.length, 1);
  }
});

test("missing or malformed runtime configuration returns redacted 503 before any HTTP request", async () => {
  const environments = [
    {}, { SUPABASE_URL, SUPABASE_ANON_KEY: PUBLIC_KEY }, { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY },
    { SUPABASE_ANON_KEY: PUBLIC_KEY, SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY },
    { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEYS: "malformed JSON", SUPABASE_SECRET_KEYS: "{}" },
    ...["null", '"synthetic-string-key"', '["synthetic-array-key"]'].flatMap(value => [
      { ...legacyEnvironment, SUPABASE_ANON_KEY: undefined, SUPABASE_PUBLISHABLE_KEYS: value },
      { ...legacyEnvironment, SUPABASE_SERVICE_ROLE_KEY: undefined, SUPABASE_SECRET_KEYS: value },
    ]),
    { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEYS: '{"default":42}', SUPABASE_SECRET_KEYS: '{"default":false}' },
  ];
  for (const environment of environments) {
    const f = fixture({ environment });
    const response = await f.run();
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: "upload_unavailable" });
    assert.deepEqual(f.requests, []);
    assert.deepEqual(f.normalizations, []);
  }
});

test("actual SDK public URLs normalize dot segments, so direct table references need the retained path guard", () => {
  const client = createClient(SUPABASE_URL, PUBLIC_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: async () => assert.fail("formatting a public URL must not make a request") },
  });
  const foreign = "admin-menu/12345678-1234-4123-8123-123456789abc/12345678-1234-4123-8123-123456789abc.webp";
  const { data } = client.storage.from("food-public").getPublicUrl(`stores/${STORE}/menu/../../../${foreign}`);
  assert.equal(new URL(data.publicUrl).pathname, `/storage/v1/object/public/food-public/${foreign}`);
});
