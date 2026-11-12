// ZOKY-136: cleanup service worker for the retired food.wynos.online origin.
//
// web/proxy.ts serves this file as /sw.js on food.wynos.online only (every
// other URL there redirects to zoky.wynos.online). Browsers refuse a
// redirected worker update, so without this the old WYNOS Food worker and
// its push subscription would stay installed and keep showing that
// account's Food notifications after the user signed out on ZOKY.
//
// When the browser's update check installs this worker it removes the old
// origin's push subscription (the FCM token becomes invalid and the push
// senders prune it as a dead token), drops the old static caches and
// unregisters itself. It never shows notification content and never talks
// to Supabase.
const ZOKY_ORIGIN = "https://zoky.wynos.online";

async function retireLegacyFoodWorker() {
  try {
    const subscription = await self.registration.pushManager.getSubscription();
    if (subscription) await subscription.unsubscribe();
  } catch {
    // Unregistering below also deactivates the subscription.
  }
  try {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith("wynos-static-")).map((name) => caches.delete(name)));
  } catch {
    // Cache cleanup is best effort.
  }
  try {
    await self.registration.unregister();
  } catch {
    // The next update check retries.
  }
}

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(retireLegacyFoodWorker());
});

// A push that reaches this worker before it retires gets a generic,
// content-free banner (browsers require one) and the subscription is removed.
self.addEventListener("push", (event) => {
  event.waitUntil(Promise.all([
    self.registration.showNotification("ZOKY", {
      body: "WYNOS Food ย้ายมาเป็น ZOKY แล้ว แตะเพื่อเปิด ZOKY และเปิดการแจ้งเตือนอีกครั้ง",
      icon: "/icons/zoky/icon-192-v1.png",
      tag: "zoky-legacy-food-moved",
    }).catch(() => undefined),
    self.registration.pushManager.getSubscription()
      .then((subscription) => (subscription ? subscription.unsubscribe() : true))
      .catch(() => undefined),
  ]));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(self.clients.openWindow ? self.clients.openWindow(`${ZOKY_ORIGIN}/`) : Promise.resolve());
});
