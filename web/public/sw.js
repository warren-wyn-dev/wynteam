// Minimal PWA service worker: caches the app's static build assets and icons
// so repeat visits (and the standalone/home-screen app) load instantly from
// cache, while every navigation and data request always goes to the network.
// Nothing that can go stale in a way that hides real content (HTML pages,
// Supabase API calls) is ever cached — only immutable, hashed `/_next/static`
// assets and the small set of local icon/manifest files.
const CACHE_NAME = "wynos-static-v1";
const STATIC_CACHE_PATTERNS = [/^\/_next\/static\//, /^\/icons\//, /^\/wynos_logo_mark\.png$/];

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(names.filter((name) => name !== CACHE_NAME).map((name) => caches.delete(name)));
      await self.clients.claim();
    })(),
  );
});

function isCacheableStaticAsset(url) {
  if (url.origin !== self.location.origin) return false;
  return STATIC_CACHE_PATTERNS.some((pattern) => pattern.test(url.pathname));
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (!isCacheableStaticAsset(url)) return;

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(request);
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok) cache.put(request, response.clone());
      return response;
    })(),
  );
});

// ---------------------------------------------------------------------
// Web Push (Firebase Cloud Messaging)
// ---------------------------------------------------------------------
// This worker doubles as WYNOS Web's push receiver instead of registering a
// second service worker at /firebase-messaging-sw.js: two workers both
// claiming scope "/" would fight over which one actually controls the page.
// A plain static file can't read `process.env`, so the Firebase Web config
// (public-by-design values, same as the ones already shipped in the Flutter
// web build — see app/web/firebase-messaging-sw.js) is fetched once here at
// activate time from /api/push-config instead of being baked in.
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

async function initFirebaseMessaging() {
  try {
    const response = await fetch("/api/push-config");
    const config = await response.json();
    if (!config.configured) return;
    firebase.initializeApp(config);
    const messaging = firebase.messaging();

    // Background delivery only (tab closed, or another tab focused): a
    // "notification" payload is already rendered automatically by the SDK,
    // so re-showing it here for a data-only payload avoids a duplicate banner.
    messaging.onBackgroundMessage((payload) => {
      if (payload.notification) return;
      const data = payload.data || {};
      self.registration.showNotification(data.push_title || "WYNOS", {
        body: data.push_body || "",
        icon: "/icons/icon-192.png",
        badge: "/icons/icon-192.png",
        tag: data.notification_id || undefined,
        data,
      });
    });
  } catch {
    // No config, offline, or the fetch failed — push simply stays unavailable
    // for this session rather than breaking the worker's caching duties above.
  }
}

self.addEventListener("activate", (event) => {
  event.waitUntil(initFirebaseMessaging());
});

// The server sends UUID target columns (not arbitrary URLs). Build the same
// in-app destinations the notification center uses, ignoring untrusted
// external links or malformed IDs from the notification's data field.
const PUSH_UUID = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;
function pushTarget(data) {
  const id = (key) => typeof data?.[key] === "string" && PUSH_UUID.test(data[key]) ? data[key] : null;
  const conversation = id("conversation_id");
  const actor = id("actor_id");
  if (conversation) return `/chat/${conversation}${actor ? `?user=${actor}` : ""}`;
  if (id("drop_id")) return `/drop/${id("drop_id")}`;
  if (id("pop_id")) return `/pop/${id("pop_id")}`;
  if (id("club_post_id")) return `/club-post/${id("club_post_id")}`;
  if (id("club_id")) return `/club/${id("club_id")}`;
  if (actor) return `/profile/${actor}`;
  return "/notifications";
}

// FCM auto-displayed notifications wrap data in FCM_MSG; data-only messages
// displayed by this worker store data directly. Handle both shapes.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const raw = event.notification.data || {};
  const data = raw.FCM_MSG?.data || raw.data || raw;
  const targetUrl = new URL(pushTarget(data), self.location.origin).href;

  event.waitUntil((async () => {
    const windows = await clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const client of windows) {
      if (new URL(client.url).origin !== self.location.origin || !("focus" in client)) continue;
      try {
        const destination = client.url !== targetUrl && "navigate" in client
          ? await client.navigate(targetUrl)
          : client;
        return await (destination || client).focus();
      } catch {
        // A stale window might have closed between matchAll and navigate.
      }
    }
    return clients.openWindow ? clients.openWindow(targetUrl) : undefined;
  })());
});
