import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import path from "node:path";
import { expect, test } from "@playwright/test";

const ID = "11111111-1111-4111-8111-111111111111";
const OTHER = "22222222-2222-4222-8222-222222222222";

function fakeWorker(openClients: Array<{ url: string; navigate?: (url: string) => Promise<unknown>; focus?: () => Promise<unknown> }> = []) {
  type PushClick = { notification: { close: () => void; data: unknown }; waitUntil: (promise: Promise<unknown>) => void; stopImmediatePropagation?: () => void };
  const listeners = new Map<string, (event: PushClick) => void>();
  const opened: string[] = [];
  let clickIntercepted = false;
  let notificationClosed = false;
  const clients = {
    matchAll: async () => openClients,
    openWindow: async (url: string) => { opened.push(url); return { url }; },
  };
  const self = {
    location: { origin: "https://wynos.online" },
    addEventListener: (name: string, callback: (event: PushClick) => void) => listeners.set(name, callback),
    skipWaiting: () => {},
    clients,
  };
  const workerSource = readFileSync(path.join(process.cwd(), "public/sw.js"), "utf8");
  runInNewContext(workerSource, { self, clients, URL, importScripts: () => {}, console });
  const click = async (data: unknown) => {
    let settled: Promise<unknown> | undefined;
    const listener = listeners.get("notificationclick");
    if (!listener) throw new Error("No notificationclick listener");
    listener({
      notification: { close: () => { notificationClosed = true; }, data },
      stopImmediatePropagation: () => { clickIntercepted = true; },
      waitUntil: (promise: Promise<unknown>) => { settled = promise; },
    });
    if (!settled) throw new Error("Notification click did not call waitUntil");
    await settled;
    return { clickIntercepted, notificationClosed };
  };
  return { click, opened };
}

test("a background DM push opens the conversation in an existing WYNOS window", async () => {
  const navigations: string[] = [];
  let focused = false;
  const client = {
    url: "https://wynos.online/",
    navigate: async (url: string) => { navigations.push(url); return client; },
    focus: async () => { focused = true; return client; },
  };
  const worker = fakeWorker([client]);
  const clickResult = await worker.click({ conversation_id: ID, actor_id: OTHER });
  expect(clickResult).toEqual({ clickIntercepted: true, notificationClosed: true });
  expect(navigations).toEqual([`https://wynos.online/chat/${ID}?user=${OTHER}`]);
  expect(focused).toBe(true);
  expect(worker.opened).toEqual([]);
});

test("an auto-displayed FCM push opens its post; unsafe payloads stay same-origin", async () => {
  const postWorker = fakeWorker();
  await postWorker.click({ FCM_MSG: { data: { drop_id: ID } } });
  expect(postWorker.opened).toEqual([`https://wynos.online/drop/${ID}`]);

  const unsafeWorker = fakeWorker([{ url: "https://external.example/", focus: async () => { throw Error("Should not focus external client"); } }]);
  await unsafeWorker.click({ conversation_id: "//external.example/bad", url: "https://external.example/" });
  expect(unsafeWorker.opened).toEqual(["https://wynos.online/notifications"]);
});

test("offline PWA worker still registers static caching when Firebase CDN is blocked", () => {
  const source = readFileSync(path.join(process.cwd(), "public/sw.js"), "utf8");
  const events: string[] = [];
  const fake = {
    location: { origin: "https://wynos.online" },
    addEventListener: (name: string) => { events.push(name); },
    skipWaiting: () => {},
  };
  expect(() => runInNewContext(source, {
    self: fake,
    clients: {},
    URL,
    importScripts: () => { throw new Error("Firebase CDN unavailable"); },
  })).not.toThrow();
  expect(events).toContain("fetch");
  expect(events).toContain("install");
  expect(events).toContain("activate");
});

test("foreground push uses the registered worker and server icon case matches public assets", () => {
  const source = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const client = source("lib/push-notifications.ts");
  const server = source("../supabase/functions/send-push-notification/index.ts");
  const worker = source("public/sw.js");
  // Push delivery must not depend on a CDN script or an async activate step.
  expect(worker).not.toContain("importScripts(");
  expect(worker).not.toContain("onBackgroundMessage");
  expect(worker).toContain("event.stopImmediatePropagation?.()");
  // The service worker is the single Push display path (no page onMessage).
  expect(client).not.toContain("onMessage(");
  expect(client).not.toContain("listenForForegroundPush");
  const subscription = client.slice(client.indexOf("export async function subscribeToPushNotifications"), client.indexOf("export async function unsubscribeFromPushNotifications"));
  expect(subscription).toContain("Notification.requestPermission()");
  expect(subscription.indexOf("Notification.requestPermission()")).toBeLessThan(subscription.indexOf("await getPushAvailability()"));
  expect(client).toContain("export async function isCurrentDevicePushEnabled");
  const settings = source("components/settings-route.tsx");
  expect(settings).toContain("isCurrentDevicePushEnabled(client, userId)");
  const profile = source("components/profile-route.tsx");
  expect(profile.indexOf("detachPushBeforeAccountChange()")).toBeLessThan(profile.indexOf("activateSavedAccount(account.userId)"));
  const accountAdd = source("components/account-add-route.tsx");
  expect(accountAdd.indexOf("unsubscribeFromPushNotifications(prior)")).toBeLessThan(accountAdd.indexOf("markAccountStorageActive(storageKey)"));
  expect(server).toContain('icon: "/icons/icon-192.png"');
  expect(server).not.toContain('"/icons/Icon-192.png"');
});

test("logging out unregisters the push device before auth is cleared", () => {
  const source = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const gate = source("components/developer-route-gate.tsx");
  const push = source("lib/push-notifications.ts");
  const settings = source("components/settings-route.tsx");
  expect(gate.indexOf("await unsubscribeFromPushNotifications(client)"))
    .toBeLessThan(gate.indexOf("await client.auth.signOut()"));
  expect(push).toContain("serviceWorkerRegistration: registration");
  // Both independent revocations now run in parallel. The UI may switch
  // only after BOTH have settled successfully; neither failure is ignored.
  expect(push).toContain("const [db, firebase] = await Promise.allSettled");
  expect(push).toContain('db.status === "fulfilled" && !db.value.error');
  expect(push).toContain('firebase.status === "fulfilled" && firebase.value === true');
  expect(settings).toContain("const removed = await unsubscribeFromPushNotifications(client)");
});


function pushWorker() {
  type PushEvent = { data: { json: () => unknown } | null; waitUntil: (promise: Promise<unknown>) => void };
  const workerSource = readFileSync(path.join(process.cwd(), "public/sw.js"), "utf8");
  const wakeMessages: unknown[] = [];
  const banners: Array<{ title: string; options: { body?: string; tag?: string; data?: unknown } }> = [];
  const listeners = new Map<string, (event: PushEvent) => void>();
  const self = {
    location: { origin: "https://wynos.online" },
    addEventListener: (name: string, callback: (event: PushEvent) => void) => listeners.set(name, callback),
    skipWaiting: () => undefined,
    clients: {
      claim: async () => undefined,
      matchAll: async () => [{ postMessage: (data: unknown) => { wakeMessages.push(data); } }],
    },
    registration: {
      showNotification: async (title: string, options: { body?: string; tag?: string; data?: unknown }) => {
        banners.push({ title, options });
      },
    },
  };
  // A fresh evaluation with NO activate event models the browser restarting
  // an idle worker to deliver a push — the common background case.
  runInNewContext(workerSource, {
    self,
    URL,
    clients: self.clients,
    importScripts: () => { throw new Error("worker must not load remote scripts"); },
  });
  const push = async (payload: unknown) => {
    const listener = listeners.get("push");
    if (!listener) throw new Error("push listener not registered at initial evaluation");
    let settled: Promise<unknown> | undefined;
    listener({
      data: payload === undefined ? null : { json: () => payload },
      waitUntil: (promise) => { settled = promise; },
    });
    if (!settled) throw new Error("push handler did not call waitUntil");
    await settled;
  };
  return { push, wakeMessages, banners };
}

test("a restarted worker shows the FCM banner and wakes tabs without exposing content", async () => {
  const worker = pushWorker();
  const data = { type: "like_drop", recipient_id: ID, notification_id: OTHER, drop_id: ID };
  await worker.push({
    notification: { title: "Alice", body: "PRIVATE CONTENT MUST NOT ENTER WAKE MESSAGES", tag: "collapse-1" },
    data,
    fcmMessageId: "m1",
  });
  expect(worker.wakeMessages).toEqual([{
    kind: "wynos:notification-push",
    recipientId: ID,
    notificationId: OTHER,
    notificationType: "like_drop",
  }]);
  expect(JSON.stringify(worker.wakeMessages)).not.toContain("PRIVATE CONTENT");
  expect(worker.banners).toHaveLength(1);
  expect(worker.banners[0].title).toBe("Alice");
  expect(worker.banners[0].options.body).toBe("PRIVATE CONTENT MUST NOT ENTER WAKE MESSAGES");
  expect(worker.banners[0].options.tag).toBe("collapse-1");
  // Click routing reads the same data object the banner stores.
  expect(worker.banners[0].options.data).toEqual(data);
});

test("data-only, empty and malformed pushes still show exactly one banner", async () => {
  const worker = pushWorker();
  await worker.push({ data: { push_title: "WYNOS", push_body: "hello", notification_id: OTHER } });
  await worker.push(undefined);
  await worker.push("not an object");
  expect(worker.banners.map((banner) => banner.title)).toEqual(["WYNOS", "WYNOS", "WYNOS"]);
  expect(worker.banners[0].options.body).toBe("hello");
  expect(worker.banners[0].options.tag).toBe(OTHER);
  expect(worker.wakeMessages).toHaveLength(3);
});
