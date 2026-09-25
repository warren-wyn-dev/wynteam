import type { SupabaseClient } from "@supabase/supabase-js";

type PushConfig = {
  configured: boolean;
  apiKey?: string;
  appId?: string;
  messagingSenderId?: string;
  projectId?: string;
  authDomain?: string;
  storageBucket?: string;
  vapidKey?: string;
};

export type PushSubscribeResult = { ok: true } | { ok: false; reason: "unsupported" | "not-configured" | "denied" | "no-token" | "error" };

// `firebase/app` + `firebase/messaging` are only ever needed by the handful
// of visitors who actually use push (or already granted it in a past
// session) — loading them via a static import would put Firebase in the
// shared bundle every page pays for. Dynamic imports keep it out of the
// critical path entirely for everyone else.
async function loadFirebase() {
  const [{ getApps, initializeApp }, messaging] = await Promise.all([
    import("firebase/app"),
    import("firebase/messaging"),
  ]);
  return { getApps, initializeApp, ...messaging };
}

async function fetchPushConfig(): Promise<PushConfig | null> {
  try {
    const response = await fetch("/api/push-config");
    if (!response.ok) return null;
    return (await response.json()) as PushConfig;
  } catch {
    return null;
  }
}

function firebaseApp(fb: Awaited<ReturnType<typeof loadFirebase>>, config: PushConfig) {
  const existing = fb.getApps()[0];
  if (existing) return existing;
  return fb.initializeApp({
    apiKey: config.apiKey,
    appId: config.appId,
    messagingSenderId: config.messagingSenderId,
    projectId: config.projectId,
    authDomain: config.authDomain,
    storageBucket: config.storageBucket,
  });
}

/**
 * Whether this browser/session can receive Web Push at all, independent of
 * permission state — and whether the server actually has Firebase
 * configured (production is missing these env vars until WYN-016 ships, so
 * without this check the toggle would show as available and then always
 * fail with a confusing error on tap).
 */
export async function pushSupported(): Promise<boolean> {
  if (typeof window === "undefined") return false;
  if (!("Notification" in window) || !("serviceWorker" in navigator)) return false;
  const config = await fetchPushConfig();
  if (!config?.configured) return false;
  try {
    const fb = await loadFirebase();
    return await fb.isSupported();
  } catch {
    return false;
  }
}

/**
 * Requests notification permission (a real permission prompt — only call
 * this from an explicit user action, e.g. a Settings toggle, never on
 * page load) and, once granted, registers this device's FCM token in
 * `push_tokens` with platform "web" — the same table and shape the existing
 * `send-push-notification` Edge Function already reads for Android/iOS.
 */
export async function subscribeToPushNotifications(
  client: SupabaseClient,
  userId: string,
): Promise<PushSubscribeResult> {
  if (typeof window === "undefined" || !("Notification" in window) || !("serviceWorker" in navigator)) {
    return { ok: false, reason: "unsupported" };
  }

  // iOS installed web apps and other browsers require this call to begin
  // inside the Settings toggle's user gesture. Do not await Firebase config
  // or feature detection before requesting the permission.
  let permission: NotificationPermission;
  try {
    permission = Notification.permission === "granted" ? "granted" : await Notification.requestPermission();
  } catch {
    return { ok: false, reason: "error" };
  }
  if (permission !== "granted") return { ok: false, reason: "denied" };

  if (!(await pushSupported())) return { ok: false, reason: "unsupported" };
  const config = await fetchPushConfig();
  if (!config?.configured) return { ok: false, reason: "not-configured" };

  try {
    const fb = await loadFirebase();
    const registration = await navigator.serviceWorker.register("/sw.js");
    await navigator.serviceWorker.ready;
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    const token = await fb.getToken(messaging, { vapidKey: config.vapidKey, serviceWorkerRegistration: registration });
    if (!token) return { ok: false, reason: "no-token" };

    const { error } = await client
      .from("push_tokens")
      .upsert({ user_id: userId, token, platform: "web", updated_at: new Date().toISOString() }, { onConflict: "token" });
    if (error) return { ok: false, reason: "error" };

    // The root listener may have mounted before permission was granted.
    // Start foreground delivery now without requiring an app reload.
    void listenForForegroundPush();
    return { ok: true };
  } catch {
    return { ok: false, reason: "error" };
  }
}

/** Remove the current device token while the owning user is still signed in.
 * Returns false on failure so Settings never claims push is disabled when
 * the server may still have this token. Sign-out remains best-effort.
 */
export async function unsubscribeFromPushNotifications(client: SupabaseClient): Promise<boolean> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return false;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return true;
  try {
    const config = await fetchPushConfig();
    if (!config?.configured) return false;
    const registration = await navigator.serviceWorker.getRegistration("/");
    if (!registration) return false;
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    // getToken() without the same service worker registration tries the
    // Firebase default worker, which this PWA intentionally does not ship.
    const token = await fb.getToken(messaging, {
      vapidKey: config.vapidKey,
      serviceWorkerRegistration: registration,
    }).catch(() => null);
    if (!token) return false;

    const { error } = await client.from("push_tokens").delete().eq("token", token);
    // Even if the DB delete failed (e.g. a stale account-owned row), try to
    // invalidate this browser's FCM token to stop further delivery.
    const revoked = await fb.deleteToken(messaging);
    return !error && revoked;
  } catch {
    return false;
  }
}

/**
 * Best-effort local last resort before sign-out. A network failure may prevent
 * deleting the old owner's DB token; retiring the browser PushSubscription
 * reduces the chance of receiving that owner's messages after reconnect.
 * Never treat this as proof of backend deletion or use it to bypass the
 * strict account-switch Push-detach gate.
 */
export async function revokeLocalPushSubscription(): Promise<boolean> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return false;
  try {
    const registration = await navigator.serviceWorker.getRegistration("/");
    if (!registration || !("pushManager" in registration)) return false;
    const subscription = await registration.pushManager.getSubscription();
    return subscription ? await subscription.unsubscribe() : true;
  } catch {
    return false;
  }
}

/** Whether THIS device's Firebase token is registered for THIS user.
 * Browser permission alone is not enough: the user may have switched
 * accounts or explicitly unsubscribed without revoking OS permission.
 */
export async function isCurrentDevicePushEnabled(client: SupabaseClient, userId: string): Promise<boolean> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return false;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return false;
  try {
    const config = await fetchPushConfig();
    if (!config?.configured) return false;
    const registration = await navigator.serviceWorker.getRegistration("/");
    if (!registration) return false;
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    const token = await fb.getToken(messaging, { vapidKey: config.vapidKey, serviceWorkerRegistration: registration });
    if (!token) return false;
    const { data, error } = await client.from("push_tokens")
      .select("token")
      .eq("user_id", userId)
      .eq("token", token)
      .maybeSingle();
    return !error && Boolean(data);
  } catch {
    return false;
  }
}

// Deduplicate the root-mount and Settings-toggle setup attempts.
let foregroundListenerPromise: Promise<void> | null = null;

/**
 * Foreground pushes (tab open and focused) are not shown automatically by
 * Firebase the way background ones are — this renders the same OS
 * notification manually so a push looks identical whether or not the app
 * happens to be focused. Safe to call unconditionally; it's a no-op when
 * push was never subscribed or isn't supported.
 */
export async function listenForForegroundPush(): Promise<void> {
  if (typeof window === "undefined" || typeof Notification === "undefined") return;
  if (Notification.permission !== "granted" || !("serviceWorker" in navigator)) return;
  if (foregroundListenerPromise) return foregroundListenerPromise;

  foregroundListenerPromise = (async () => {
    if (!(await pushSupported())) throw new Error("Push support is unavailable");
    const config = await fetchPushConfig();
    if (!config?.configured) throw new Error("Push is not configured");
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    fb.onMessage(messaging, (payload) => {
      // FCM's onMessage runs while the app is in the foreground; it does
      // NOT render the notification payload automatically in this case.
      // A registered worker displays it consistently on installed iOS
      // PWAs and Android, where the window Notification constructor differs.
      const data = payload.data ?? {};
      if (!payload.notification && !data.push_title && !data.push_body) return;
      const title = payload.notification?.title || data.push_title || "WYNOS";
      const body = payload.notification?.body || data.push_body || "";
      void navigator.serviceWorker.ready.then((registration) =>
        registration.showNotification(title, {
          body,
          icon: "/icons/icon-192.png",
          badge: "/icons/icon-192.png",
          tag: data.notification_id,
          data,
        }),
      ).catch(() => undefined);
    });
  })().catch(() => {
    // Configuration, browser support and intermittent connectivity may
    // change; allow a later explicit opt-in to retry initialization.
    foregroundListenerPromise = null;
  });

  return foregroundListenerPromise;
}
