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

/** Why Push could not be turned on, in the words shown to people (Settings and the Push prompt). */
export function pushReasonDescription(reason: PushBlockReason): string {
  switch (reason) {
    case "install-required": return "บน iPhone/iPad ต้องเพิ่ม WYNOS ไปยังหน้าจอโฮม แล้วเปิดผ่านไอคอนแอปก่อน";
    case "not-configured": return "ระบบ Push ยังไม่ได้ตั้งค่า Firebase ครบ กรุณาแจ้งผู้ดูแล WYNOS";
    case "denied": return "อุปกรณ์ปิดสิทธิ์แจ้งเตือนอยู่ ต้องอนุญาต WYNOS จากการตั้งค่าโทรศัพท์หรือเบราว์เซอร์ก่อน";
    case "dismissed": return "ยังไม่ได้อนุญาตการแจ้งเตือน แตะเปิดอีกครั้งและเลือกอนุญาต";
    case "worker-failed": return "เริ่มระบบแจ้งเตือนของแอปไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่";
    case "no-token": return "ลงทะเบียนอุปกรณ์กับ Firebase ไม่สำเร็จ ลองเปิดใหม่อีกครั้ง";
    case "server-failed": return "บันทึกอุปกรณ์กับ WYNOS ไม่สำเร็จ กรุณาลองอีกครั้ง";
    case "unsupported": return "เบราว์เซอร์นี้ไม่รองรับ Push ลอง Chrome บน Android หรือ WYNOS ที่ติดตั้งบนหน้าจอโฮมของ iPhone";
    case "temporary": return "ตรวจสอบความพร้อมของ Push ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่";
  }
}

/**
 * Which installed WYNOS app this device token belongs to, so the server shows
 * Social, Food and Merchant notifications only in their own app (Founder,
 * 2026-10-05). The Food and Merchant subdomains are their own browser origin
 * and Push registration. On wynos.online a browser tab shares one token with
 * the main app; only an installed Food (/food) or Merchant (/merchant) Home
 * Screen app, which gets its own subscription, counts as that app. `path`
 * is where the app was launched, not the page open now.
 */
export type PushApp = "social" | "food" | "merchant";

export function pushAppFor(hostname: string, path: string, standalone: boolean): PushApp {
  const host = hostname.toLowerCase();
  if (host === "merchant.wynos.online") return "merchant";
  if (host === "food.wynos.online") return "food";
  if (standalone) {
    if (/^\/merchant(\/|$)/.test(path)) return "merchant";
    if (/^\/food(\/|$)/.test(path)) return "food";
  }
  return "social";
}

// The path this window was opened at. The main app can navigate into /food
// later; only an app that was launched at /food or /merchant is that app.
const LAUNCH_PATH_KEY = "wynos.push.launch-path.v1";

function launchPath(): string {
  const current = window.location?.pathname ?? "/";
  try {
    const saved = window.sessionStorage.getItem(LAUNCH_PATH_KEY);
    if (saved) return saved;
    window.sessionStorage.setItem(LAUNCH_PATH_KEY, current);
  } catch {
    // Private mode: fall back to the current page.
  }
  return current;
}

if (typeof window !== "undefined") launchPath();

function currentPushApp(): PushApp {
  const standalone = (typeof window.matchMedia === "function" &&
    window.matchMedia("(display-mode: standalone)").matches) ||
    (navigator as Navigator & { standalone?: boolean }).standalone === true;
  return pushAppFor(window.location?.hostname ?? "", launchPath(), standalone);
}

async function savePushToken(client: SupabaseClient, userId: string, token: string) {
  const row = { user_id: userId, token, platform: "web", updated_at: new Date().toISOString() };
  const saved = await client.from("push_tokens").upsert({ ...row, app: currentPushApp() }, { onConflict: "token" });
  // Until the push_tokens.app migration is applied, register as before.
  if (saved.error?.code === "PGRST204") {
    return client.from("push_tokens").upsert(row, { onConflict: "token" });
  }
  return saved;
}

export const PUSH_PROMPT_DISMISS_KEY = "wynos.push.prompt.dismissed-at.v1";
export const PUSH_PROMPT_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
// Main app screens only: never over sign-in/sign-up, Settings (it has the switch) or legal pages.
const PUSH_PROMPT_PATHS = /^\/(home|chat|notifications|clubs?|profile|search|trending|bookmarks|post|drop|food)(\/|$)/;
const PUSH_PERMISSION_RECOVERY_PATHS = /^\/(chat|notifications)(\/|$)/;

export function isPushPromptPath(path: string): boolean {
  return PUSH_PROMPT_PATHS.test(path);
}

/**
 * Founder decision (2026-09-27): everyone who has not answered the
 * notification question yet is asked once, in the app, after signing in.
 * The OS permission popup itself only ever opens from the card's button
 * (browsers and iOS require a tap). Pure so it can be unit tested.
 *
 * - "ask": the card with an Allow button.
 * - "install": iPhone/iPad in a Safari tab — Push needs the Home Screen app first.
 * - "settings": permission was denied before; show recovery guidance only on
 *   high-intent Chat/Notifications screens, where Push has an obvious benefit.
 * - null: nothing to ask (already enabled, unsupported, snoozed, wrong screen).
 */
export function pushPromptKind(state: {
  path: string;
  permission: NotificationPermission | "unsupported";
  availability: PushAvailability;
  dismissedAt: number | null;
  now: number;
}): "ask" | "install" | "settings" | null {
  if (!isPushPromptPath(state.path)) return null;
  if (state.dismissedAt !== null && state.now - state.dismissedAt < PUSH_PROMPT_COOLDOWN_MS) return null;
  if (!state.availability.available && state.availability.reason === "install-required") return "install";
  if (state.permission === "denied") {
    return PUSH_PERMISSION_RECOVERY_PATHS.test(state.path) ? "settings" : null;
  }
  // "granted" means they already said yes (and may have turned WYNOS Push off
  // in Settings on purpose). Unsupported browsers have no recovery path.
  if (state.permission !== "default") return null;
  return state.availability.available ? "ask" : null;
}

const PUSH_WANTED_KEY = "wynos.push.wanted.v1";

function readPushWanted(): string[] {
  try {
    const value = JSON.parse(window.localStorage.getItem(PUSH_WANTED_KEY) ?? "[]");
    return Array.isArray(value) ? value.filter((id): id is string => typeof id === "string") : [];
  } catch {
    return [];
  }
}

/**
 * Remember, on this device, which accounts turned Push on. Account switching
 * and sign-out detach the token (privacy) but keep this, so coming back to
 * the account turns Push back on by itself. Only the Settings switch clears it.
 */
export function setPushWanted(userId: string, wanted: boolean) {
  try {
    const next = readPushWanted().filter((id) => id !== userId);
    if (wanted) next.push(userId);
    window.localStorage.setItem(PUSH_WANTED_KEY, JSON.stringify(next));
  } catch {
    // Private mode: Push still works for this session.
  }
}

// Accounts whose owner turned Push off in Settings on this device. An
// account switch never turns Push back on for them.
const PUSH_OFF_KEY = "wynos.push.off.v1";

function readPushOff(): string[] {
  try {
    const value = JSON.parse(window.localStorage.getItem(PUSH_OFF_KEY) ?? "[]");
    return Array.isArray(value) ? value.filter((id): id is string => typeof id === "string") : [];
  } catch {
    return [];
  }
}

/** The Settings switch: on clears an earlier "off", off is remembered. */
export function setPushChosen(userId: string, on: boolean) {
  setPushWanted(userId, on);
  try {
    const next = readPushOff().filter((id) => id !== userId);
    if (!on) next.push(userId);
    window.localStorage.setItem(PUSH_OFF_KEY, JSON.stringify(next));
  } catch {
    // Private mode: nothing to remember.
  }
}

export function isPushWanted(userId: string): boolean {
  return readPushWanted().includes(userId);
}

export function isPushChosenOff(userId: string): boolean {
  return readPushOff().includes(userId);
}

/**
 * Before switching or adding an account: whether Push is on for the current
 * account on this device. The switch still detaches the old account's token
 * (privacy); when this is true the caller marks both accounts as wanted, so
 * Push comes back on by itself for the new account and on the way back.
 */
export async function isPushOnBeforeAccountChange(userId: string): Promise<boolean> {
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return false;
  return isPushWanted(userId) || (await hasActivePushSubscription()) === true;
}

/** After a switch or add: keep Push on for both accounts on this device. */
export function keepPushOnAcrossAccountChange(fromUserId: string | null | undefined, toUserId: string) {
  if (fromUserId) setPushWanted(fromUserId, true);
  if (!readPushOff().includes(toUserId)) setPushWanted(toUserId, true);
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
    const { error } = await savePushToken(client, userId, token);
    if (error) return { ok: false, reason: "server-failed" };

    // Keep local-time Push schedules accurate for this account/device.
    // This is deliberately detached and internally caught: a timezone write
    // must never turn an otherwise successful Push registration into failure.
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
    void (async () => {
      try {
        await client.from("notification_settings")
          .upsert(
            { user_id: userId, push_timezone: timezone, push_timezone_synced_at: new Date().toISOString(), updated_at: new Date().toISOString() },
            { onConflict: "user_id" },
          );
      } catch {
        // Best-effort metadata only. Push itself is already registered.
      }
    })();

    setPushChosen(userId, true);
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
 * null means it could not be checked (offline, Firebase or network error):
 * callers keep what they showed before instead of flipping the switch off.
 */
export async function isCurrentDevicePushEnabled(client: SupabaseClient, userId: string): Promise<boolean | null> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return false;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return false;
  try {
    const config = await fetchPushConfig();
    if (!config) return null;
    if (!config.configured) return false;
    const registration = await navigator.serviceWorker.getRegistration("/");
    if (!registration) return false;
    // An off switch must not create a new FCM subscription merely because
    // Settings checked the current device's state.
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) return false;
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    const token = await fb.getToken(messaging, { vapidKey: config.vapidKey, serviceWorkerRegistration: registration });
    if (!token) return null;
    const { data, error } = await client.from("push_tokens")
      .select("token,app")
      .eq("user_id", userId)
      .eq("token", token)
      .maybeSingle();
    if (error) return null;
    if (data) {
      // Tokens registered before per-app Push (or by another app on this
      // origin) are labelled with the app that is open now.
      if ((data as { app: string | null }).app !== currentPushApp()) {
        await savePushToken(client, userId, token);
      }
      return true;
    }
    // FCM rotated this device's token, or the server dropped it: if this
    // account turned Push on here, register the current token again.
    if (isPushWanted(userId)) {
      const saved = await savePushToken(client, userId, token);
      return saved.error ? null : true;
    }
    return false;
  } catch {
    return null;
  }
}

const resynced = new Set<string>();

/**
 * Once per page load for the signed-in account (like a native app's
 * onTokenRefresh): if this account turned Push on here and the browser still
 * allows notifications, make sure the device's current token is registered.
 * Heals token rotation, a token the server dropped, and switching back to an
 * account whose token was detached. Never prompts; failures are silent.
 */
export async function resyncPushRegistration(client: SupabaseClient, userId: string): Promise<void> {
  if (resynced.has(userId)) return;
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
  resynced.add(userId);
  if (!isPushWanted(userId)) {
    // Push turned on before the "wanted" flag existed: if this device is
    // registered for the account right now, remember it so a later account
    // switch or token rotation brings it back.
    if ((await isCurrentDevicePushEnabled(client, userId)) === true) setPushWanted(userId, true);
    return;
  }
  try {
    const config = await fetchPushConfig();
    if (!config?.configured || !config.vapidKey) return;
    const registration = await navigator.serviceWorker.getRegistration("/") ?? await navigator.serviceWorker.register("/sw.js", { scope: "/" });
    const fb = await loadFirebase();
    const messaging = fb.getMessaging(firebaseApp(fb, config));
    const token = await fb.getToken(messaging, { vapidKey: config.vapidKey, serviceWorkerRegistration: registration });
    if (!token) return;
    await savePushToken(client, userId, token);
  } catch {
    resynced.delete(userId);
  }
}
