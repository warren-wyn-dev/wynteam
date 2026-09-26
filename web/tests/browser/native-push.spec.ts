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
  // Firebase documents that custom click handlers must be registered
  // before its scripts; otherwise the SDK may claim the event first.
  expect(worker.indexOf('self.addEventListener("notificationclick"')).toBeLessThan(worker.indexOf("importScripts("));
  expect(worker).toContain("event.stopImmediatePropagation?.()");
  expect(client).toContain("registration.showNotification(title");
  const subscription = client.slice(client.indexOf("export async function subscribeToPushNotifications"), client.indexOf("export async function unsubscribeFromPushNotifications"));
  expect(subscription).toContain("Notification.requestPermission()");
  expect(subscription.indexOf("Notification.requestPermission()")).toBeLessThan(subscription.indexOf("await pushSupported()"));
  expect(client).toContain("export async function isCurrentDevicePushEnabled");
  const settings = source("components/settings-route.tsx");
  expect(settings).toContain("isCurrentDevicePushEnabled(client, userId)");
  const profile = source("components/profile-route.tsx");
  expect(profile.indexOf("detachPushBeforeAccountChange()")).toBeLessThan(profile.indexOf("activateSavedAccount(account.userId)"));
  const accountAdd = source("components/account-add-route.tsx");
  expect(accountAdd.indexOf("unsubscribeFromPushNotifications(prior)")).toBeLessThan(accountAdd.indexOf("markAccountStorageActive(storageKey)"));
  expect(client).toContain("void listenForForegroundPush()");
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


test("background Push wakes open WYNOS tabs without exposing content or duplicating FCM banners", async () => {
  type PushPayload = { notification?: { title: string }; data?: Record<string, string> };
  const workerSource = readFileSync(path.join(process.cwd(), "public/sw.js"), "utf8");
  const handlers = new Map<string, Array<(event: { waitUntil: (promise: Promise<unknown>) => void }) => void>>();
  const wakeMessages: unknown[] = [];
  const banners: Array<{ title: string; data: unknown }> = [];
  const receiverRef: { current?: (payload: PushPayload) => Promise<unknown> | void } = {};
  const self = {
    location: { origin: "https://wynos.online" },
    addEventListener: (name: string, callback: (event: { waitUntil: (promise: Promise<unknown>) => void }) => void) => {
      const callbacks = handlers.get(name) ?? [];
      callbacks.push(callback);
      handlers.set(name, callbacks);
    },
    skipWaiting: () => undefined,
    clients: {
      claim: async () => undefined,
      matchAll: async () => [{ postMessage: (data: unknown) => { wakeMessages.push(data); } }],
    },
    registration: {
      showNotification: async (title: string, options: { data?: unknown }) => {
        banners.push({ title, data: options.data });
      },
    },
  };
  runInNewContext(workerSource, {
    self,
    URL,
    clients: self.clients,
    caches: { keys: async () => [], delete: async () => true },
    fetch: async () => ({ ok: true, json: async () => ({ configured: true }) }),
    importScripts: () => undefined,
    firebase: {
      initializeApp: () => undefined,
      messaging: () => ({
        onBackgroundMessage: (callback: (payload: PushPayload) => Promise<unknown> | void) => {
          receiverRef.current = callback;
        },
      }),
    },
  });
  const activation: Promise<unknown>[] = [];
  for (const callback of handlers.get("activate") ?? []) {
    callback({ waitUntil: (promise) => { activation.push(promise); } });
  }
  await Promise.all(activation);
  if (!receiverRef.current) throw new Error("Firebase background receiver not installed");

  const data = {
    type: "like_drop",
    recipient_id: ID,
    notification_id: OTHER,
    push_body: "PRIVATE CONTENT MUST NOT ENTER WAKE MESSAGES",
  };
  await receiverRef.current({
    notification: { title: "FCM displays this automatically" },
    data,
  });
  expect(wakeMessages).toEqual([{
    kind: "wynos:notification-push",
    recipientId: ID,
    notificationId: OTHER,
    notificationType: "like_drop",
  }]);
  expect(JSON.stringify(wakeMessages)).not.toContain(data.push_body);
  expect(banners).toHaveLength(0);

  await receiverRef.current({ data });
  expect(wakeMessages).toHaveLength(2);
  expect(banners).toHaveLength(1);
  expect(banners[0].data).toEqual(data);
});
