import { readFileSync } from "node:fs";
import path from "node:path";
import { runInNewContext } from "node:vm";
import { expect, test } from "@playwright/test";

type MockResponse = { ok: boolean; version: string; clone: () => MockResponse };
type MockRequest = { url: string; method: string };

function makeResponse(version: string): MockResponse {
  return { ok: true, version, clone: () => makeResponse(version) };
}

function makeWorker() {
  const handlers = new Map<string, Array<(event: unknown) => void>>();
  const stores = new Map<string, Map<string, MockResponse>>([
    ["wynos-static-v1", new Map()],
    ["unrelated-app-cache", new Map()],
  ]);
  const online = { value: true };
  const version = { value: "old-icon" };
  const networkRequests: string[] = [];
  const cacheApi = {
    keys: async () => [...stores.keys()],
    delete: async (name: string) => stores.delete(name),
    open: async (name: string) => {
      if (!stores.has(name)) stores.set(name, new Map());
      const store = stores.get(name)!;
      return {
        match: async (request: MockRequest) => store.get(request.url),
        put: async (request: MockRequest, response: MockResponse) => {
          store.set(request.url, response.clone());
        },
      };
    },
  };
  const self = {
    location: { origin: "https://wynos.online" },
    skipWaiting: () => undefined,
    clients: { claim: async () => undefined },
    addEventListener: (name: string, callback: (event: unknown) => void) => {
      handlers.set(name, [...(handlers.get(name) ?? []), callback]);
    },
  };
  const source = readFileSync(path.join(process.cwd(), "public/sw.js"), "utf8");
  runInNewContext(source, {
    self,
    caches: cacheApi,
    URL,
    fetch: async (request: MockRequest) => {
      networkRequests.push(request.url);
      if (!online.value) throw new Error("offline");
      return makeResponse(version.value);
    },
    // Firebase is optional; the PWA cache must work even if its CDN fails.
    importScripts: () => { throw new Error("Firebase CDN unavailable"); },
  });

  const request = async (url: string): Promise<MockResponse | undefined> => {
    let response: Promise<MockResponse> | undefined;
    for (const handler of handlers.get("fetch") ?? []) {
      handler({
        request: { url, method: "GET" },
        respondWith: (value: Promise<MockResponse>) => { response = value; },
      });
    }
    return response;
  };
  const activate = async () => {
    const pending: Promise<unknown>[] = [];
    for (const handler of handlers.get("activate") ?? []) {
      handler({ waitUntil: (promise: Promise<unknown>) => { pending.push(promise); } });
    }
    await Promise.all(pending);
  };

  return { activate, networkRequests, online, request, stores, version };
}

test("updated unversioned app icons replace the old cache and remain available offline", async () => {
  const worker = makeWorker();
  const icon = "https://wynos.online/icons/icon-192.png";
  expect((await worker.request(icon))?.version).toBe("old-icon");
  worker.version.value = "new-icon";
  expect((await worker.request(icon))?.version).toBe("new-icon");
  worker.online.value = false;
  expect((await worker.request(icon))?.version).toBe("new-icon");
  expect(worker.networkRequests).toEqual([icon, icon, icon]);
});

test("fingerprinted Next.js assets stay cache-first across repeated visits", async () => {
  const worker = makeWorker();
  const asset = "https://wynos.online/_next/static/chunks/hashed.js";
  expect((await worker.request(asset))?.version).toBe("old-icon");
  worker.version.value = "new-icon";
  expect((await worker.request(asset))?.version).toBe("old-icon");
  expect(worker.networkRequests).toEqual([asset]);
});

test("worker upgrades remove only old WYNOS caches, never another app's cache", async () => {
  const worker = makeWorker();
  await worker.request("https://wynos.online/icons/icon-512.png");
  await worker.activate();
  expect([...worker.stores.keys()].sort()).toEqual(["unrelated-app-cache", "wynos-static-v2"]);
});

test("private pages, API calls and cross-origin assets are never intercepted", async () => {
  const worker = makeWorker();
  expect(await worker.request("https://wynos.online/home")).toBeUndefined();
  expect(await worker.request("https://wynos.online/api/push-config")).toBeUndefined();
  expect(await worker.request("https://external.example/icons/icon-192.png")).toBeUndefined();
  expect(worker.networkRequests).toHaveLength(0);
});
