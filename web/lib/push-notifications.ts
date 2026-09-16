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

/** Whether this browser/session can receive Web Push at all, independent of permission state. */
export async function pushSupported(): Promise<boolean> {
  if (typeof window === "undefined") return false;
  if (!("Notification" in window) || !("serviceWorker" in navigator)) return false;
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
  if (!(await pushSupported())) return { ok: false, reason: "unsupported" };

  const config = await fetchPushConfig();
  if (!config?.configured) return { ok: false, reason: "not-configured" };

  const permission = await Notification.requestPermission();
  if (permission !== "granted") return { ok: false, reason: "denied" };

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

    return { ok: true };
  } catch {
    return { ok: false, reason: "error" };
  }
}

/** Removes this device's token so it stops receiving push — does not revoke the browser's own notification permission, which only the user can do. */
export async function unsubscribeFromPushNotifications(client: SupabaseClient): Promise<void> {
  try {
    const config = await fetchPushConfig();
    if (!config?.configured) return;
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    const token = await fb.getToken(messaging, { vapidKey: config.vapidKey }).catch(() => null);
    if (token) {
      await client.from("push_tokens").delete().eq("token", token);
      await fb.deleteToken(messaging);
    }
  } catch {
    // Best-effort: if the token can't be re-derived, there is nothing more
    // to clean up client-side.
  }
}

/**
 * Foreground pushes (tab open and focused) are not shown automatically by
 * Firebase the way background ones are — this renders the same OS
 * notification manually so a push looks identical whether or not the app
 * happens to be focused. Safe to call unconditionally; it's a no-op when
 * push was never subscribed or isn't supported.
 */
export async function listenForForegroundPush(): Promise<void> {
  if (typeof window === "undefined" || typeof Notification === "undefined") return;
  if (Notification.permission !== "granted") return;
  if (!(await pushSupported())) return;
  const config = await fetchPushConfig();
  if (!config?.configured) return;
  try {
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    fb.onMessage(messaging, (payload) => {
      if (payload.notification) return;
      const data = payload.data ?? {};
      new Notification(data.push_title || "WYNOS", {
        body: data.push_body || "",
        icon: "/icons/icon-192.png",
        tag: data.notification_id,
      });
    });
  } catch {
    // Foreground display is best-effort polish, never worth surfacing.
  }
}
