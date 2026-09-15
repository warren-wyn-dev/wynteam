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
