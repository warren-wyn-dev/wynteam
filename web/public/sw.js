// Only immutable Next.js build assets use cache-first. Brand icons keep a
// cached offline fallback but revalidate on each request, so installing a new
// WYNOS icon doesn't leave subsequent icon requests pinned to old artwork.
// An OS-cached Home Screen icon may still require removing/re-adding the app.
// Navigation, user data and Supabase API calls are never intercepted.
const CACHE_NAME = "wynos-static-v2";
const IMMUTABLE_ASSET_PATTERNS = [/^\/_next\/static\//];
const MUTABLE_BRAND_ASSET_PATTERNS = [/^\/icons\//, /^\/wynos_logo_mark\.png$/];

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(names.filter((name) => name.startsWith("wynos-static-") && name !== CACHE_NAME).map((name) => caches.delete(name)));
      await self.clients.claim();
    })(),
  );
});

function matchesAsset(patterns, url) {
  return url.origin === self.location.origin && patterns.some((pattern) => pattern.test(url.pathname));
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  const immutable = matchesAsset(IMMUTABLE_ASSET_PATTERNS, url);
  const mutableBrandAsset = matchesAsset(MUTABLE_BRAND_ASSET_PATTERNS, url);
  if (!immutable && !mutableBrandAsset) return;

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      if (mutableBrandAsset) {
        // Unversioned filenames can change across releases. Try the network
        // first and use the last successful copy only when offline.
        try {
          const response = await fetch(request);
          if (response.ok) await cache.put(request, response.clone());
          return response;
        } catch (error) {
          const cached = await cache.match(request);
          if (cached) return cached;
          throw error;
        }
      }

      // Fingerprinted Next.js assets do not change at a given URL.
      const cached = await cache.match(request);
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok) await cache.put(request, response.clone());
      return response;
    })(),
  );
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
  // Run before the FCM SDK click handler, so only one navigation occurs.
  event.stopImmediatePropagation?.();
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

// ---------------------------------------------------------------------
// Web Push (Firebase Cloud Messaging transport)
// ---------------------------------------------------------------------
// The page obtains the FCM token (Firebase JS + VAPID key) against THIS
// worker's registration; delivery is a standard Web Push `push` event whose
// body is FCM's JSON envelope: { notification: {...}, data: {...}, ... }.
//
// The `push` listener MUST be registered during the script's initial
// evaluation. Browsers terminate idle workers and re-run this file for each
// incoming push WITHOUT firing `activate` again, so a listener installed
// later (e.g. Firebase messaging initialised from an async activate step)
// is missing for every push after the first restart: no banner is shown,
// and Safari revokes subscriptions that repeatedly receive silent pushes.
// Handling the event natively also removes the Google CDN importScripts
// dependency from the worker's startup path.
function readPushPayload(event) {
  if (!event.data) return {};
  try {
    const payload = event.data.json();
    return payload && typeof payload === "object" ? payload : {};
  } catch {
    return {};
  }
}

function pushString(value) {
  return typeof value === "string" ? value : undefined;
}

self.addEventListener("push", (event) => {
  const payload = readPushPayload(event);
  const data = payload.data && typeof payload.data === "object" ? payload.data : {};
  const notification = payload.notification && typeof payload.notification === "object"
    ? payload.notification
    : {};

  // Wake any open WYNOS tabs with a content-free invalidation hint.
  // A tab always reads its OWN user's rows via Auth/RLS. A late A push
  // after switching to B never includes A's text or profile here.
  const wakeTabs = self.clients.matchAll({ type: "window", includeUncontrolled: true })
    .then((windows) => {
      for (const client of windows) {
        if (typeof client.postMessage !== "function") continue;
        client.postMessage({
          kind: "wynos:notification-push",
          recipientId: pushString(data.recipient_id),
          notificationId: pushString(data.notification_id),
          notificationType: pushString(data.type),
        });
      }
    }).catch(() => undefined);

  // Every push shows exactly one banner (userVisibleOnly). The same tag as
  // the server's collapse key replaces a retried delivery instead of stacking.
  const banner = self.registration.showNotification(
    pushString(notification.title) || pushString(data.push_title) || "WYNOS",
    {
      body: pushString(notification.body) || pushString(data.push_body) || "",
      icon: "/icons/icon-192.png",
      badge: "/icons/icon-192.png",
      tag: pushString(notification.tag) || pushString(data.notification_id) || undefined,
      data,
    },
  ).catch(() => undefined);

  event.waitUntil(Promise.all([wakeTabs, banner]));
});
