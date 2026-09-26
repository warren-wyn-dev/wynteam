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

export type PushBlockReason = "unsupported" | "install-required" | "not-configured" | "denied" | "dismissed" | "no-token" | "worker-failed" | "server-failed" | "temporary";
export type PushAvailability = { available: true } | { available: false; reason: PushBlockReason };
export type PushSubscribeResult = { ok: true } | { ok: false; reason: PushBlockReason };

/** iOS/iPadOS Web Push requires a Home Screen PWA, not a Safari tab.
 * All checks are read-only; only the explicit toggle click prompts OS permission.
 */
export function isIosWebPushInstallRequired(
  userAgent: string,
  touchPoints: number,
  standalone: boolean,
): boolean {
  const ios = /iPhone|iPad|iPod/i.test(userAgent) ||
    (/Macintosh/i.test(userAgent) && touchPoints > 1);
  return ios && !standalone;
}

function iosNeedsInstallation(): boolean {
  if (typeof window === "undefined" || typeof navigator === "undefined") return false;
  const mode = typeof window.matchMedia === "function" &&
    window.matchMedia("(display-mode: standalone)").matches;
  return isIosWebPushInstallRequired(
    navigator.userAgent,
    navigator.maxTouchPoints ?? 0,
    mode || (navigator as Navigator & { standalone?: boolean }).standalone === true,
  );
}

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

// Reuse only a successful PUBLIC Firebase configuration briefly. Account
// switching must still await the real server token deletion and FCM revoke;
// caching config never treats an uncertain detach as successful.
let cachedPushConfig: { until: number; promise: Promise<PushConfig | null> } | null = null;
function fetchPushConfig(): Promise<PushConfig | null> {
  if (cachedPushConfig && Date.now() < cachedPushConfig.until) {
    return cachedPushConfig.promise;
  }
  const promise = (async (): Promise<PushConfig | null> => {
    try {
      const response = await fetch("/api/push-config");
      if (!response.ok) return null;
      return (await response.json()) as PushConfig;
    } catch {
      return null;
    }
  })();
  cachedPushConfig = { until: Date.now() + 60_000, promise };
  void promise.then((config) => {
    if (!config?.configured && cachedPushConfig?.promise === promise) {
      cachedPushConfig = null; // Failure must never be cached past reconnect.
    }
  });
  return promise;
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
export async function getPushAvailability(): Promise<PushAvailability> {
  if (typeof window === "undefined" || typeof navigator === "undefined") {
    return { available: false, reason: "unsupported" };
  }
  // Safari tabs on iOS may not expose the Push API at all. Detect the
  // install requirement BEFORE feature detection so the UI can show the
  // correct action instead of falsely reporting the phone is unsupported.
  if (iosNeedsInstallation()) return { available: false, reason: "install-required" };
  if (!("Notification" in window) || !("serviceWorker" in navigator) ||
      !("PushManager" in window)) {
    return { available: false, reason: "unsupported" };
  }
  if (Notification.permission === "denied") return { available: false, reason: "denied" };
  const config = await fetchPushConfig();
  if (!config?.configured || !config.vapidKey) {
    return { available: false, reason: "not-configured" };
  }
  try {
    const fb = await loadFirebase();
    return (await fb.isSupported())
      ? { available: true }
      : { available: false, reason: "unsupported" };
  } catch {
    return { available: false, reason: "temporary" };
  }
}

export async function pushSupported(): Promise<boolean> {
  return (await getPushAvailability()).available;
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
  if (typeof window === "undefined" || typeof navigator === "undefined") {
    return { ok: false, reason: "unsupported" };
  }
  if (iosNeedsInstallation()) return { ok: false, reason: "install-required" };
  if (!("Notification" in window) || !("serviceWorker" in navigator) ||
      !("PushManager" in window)) {
    return { ok: false, reason: "unsupported" };
  }
  if (Notification.permission === "denied") return { ok: false, reason: "denied" };

  // IMPORTANT: requestPermission must be the first awaited browser API
  // after the Settings switch's real click/tap. iOS installed PWAs require
  // a live user gesture; never await config/Firebase before this point.
  let permission: NotificationPermission;
  try {
    permission = Notification.permission === "granted" ? "granted" : await Notification.requestPermission();
  } catch {
    return { ok: false, reason: "temporary" };
  }
  if (permission !== "granted") {
    return { ok: false, reason: permission === "denied" ? "denied" : "dismissed" };
  }

  const availability = await getPushAvailability();
  if (!availability.available) return { ok: false, reason: availability.reason };
  const config = await fetchPushConfig();
  if (!config?.configured || !config.vapidKey) return { ok: false, reason: "not-configured" };

  let registration: ServiceWorkerRegistration;
  try {
    registration = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
    // Do not silently spin forever when a stale/broken worker never becomes
    // active; users should see a retryable error instead of a stuck switch.
    await Promise.race([
      navigator.serviceWorker.ready,
      new Promise<never>((_, reject) => {
        window.setTimeout(() => reject(new Error("worker-not-ready")), 10_000);
      }),
    ]);
  } catch {
    return { ok: false, reason: "worker-failed" };
  }

  let token: string;
  try {
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    token = await fb.getToken(messaging, {
      vapidKey: config.vapidKey,
      serviceWorkerRegistration: registration,
    });
  } catch {
    return { ok: false, reason: "no-token" };
  }
  if (!token) return { ok: false, reason: "no-token" };

  try {
    const { error } = await client.from("push_tokens")
      .upsert(
        { user_id: userId, token, platform: "web", updated_at: new Date().toISOString() },
        { onConflict: "token" },
      );
    if (error) return { ok: false, reason: "server-failed" };
    // On this exact device/account, confirmation is a successful server write,
    // not merely a granted OS notification permission. Display and in-app
    // wake-ups for every Push (foreground or not) happen in public/sw.js.
    return { ok: true };
  } catch {
    return { ok: false, reason: "server-failed" };
  }
}

/** Remove the current device token while the owning user is still signed in.
 * Returns false on failure so Settings never claims push is disabled when
 * the server may still have this token. Sign-out remains best-effort.
 */
export async function unsubscribeFromPushNotifications(client: SupabaseClient): Promise<boolean> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return true;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return true;
  try {
    // Notification permission can remain granted after the user disables
    // WYNOS Push. No worker/subscription means nothing on this device can
    // receive the old account's notifications; do not block account switching.
    const registration = await navigator.serviceWorker.getRegistration("/");
    if (!registration || !("pushManager" in registration)) return true;
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) return true;

    // An ACTIVE subscription is different: never bypass the detach gate
    // because a config request, Firebase lookup or server delete has failed.
    const config = await fetchPushConfig();
    if (!config?.configured) return false;
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    const token = await fb.getToken(messaging, {
      vapidKey: config.vapidKey,
      serviceWorkerRegistration: registration,
    }).catch(() => null);
    if (!token) return false;

    // These revocations are independent once the token is known. Run them
    // together instead of paying two serial network round trips, but wait
    // for BOTH before allowing any account change (fail closed).
    const [db, firebase] = await Promise.allSettled([
      client.from("push_tokens").delete().eq("token", token),
      fb.deleteToken(messaging),
    ]);
    return db.status === "fulfilled" && !db.value.error &&
      firebase.status === "fulfilled" && firebase.value === true;
  } catch {
    return false;
  }
}

/**
 * Distinguish a granted browser permission from an ACTIVE Push subscription.
 * null means the worker state could not be checked, so callers must not
 * assume the previous account's notifications have stopped.
 */
export async function hasActivePushSubscription(): Promise<boolean | null> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return false;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return false;
  try {
    const registration = await navigator.serviceWorker.getRegistration("/");
    if (!registration || !("pushManager" in registration)) return false;
    return Boolean(await registration.pushManager.getSubscription());
  } catch {
    return null;
  }
}

/**
 * Warm the read-only Push configuration and Firebase JS while the switcher
 * is visible. Never get/create a token, unsubscribe, or delete a DB record
 * until the user selects a successfully verified destination.
 */
export function prewarmAccountSwitchPush(): void {
  if (typeof navigator === "undefined" || typeof Notification === "undefined" ||
      Notification.permission !== "granted") return;
  void hasActivePushSubscription().then((active) => {
    if (active !== true) return;
    void fetchPushConfig();
    void loadFirebase().catch(() => undefined);
  }).catch(() => undefined);
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
    // An off switch must not create a new FCM subscription merely because
    // Settings checked the current device's state.
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) return false;
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
