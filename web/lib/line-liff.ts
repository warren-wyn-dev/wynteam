// ZOKY-LINE-001: helpers for the /line LIFF entry and the
// "รับแจ้งเตือนทาง LINE" cards. No secrets: LIFF IDs are public identifiers.
import type { Liff } from "@line/liff";

export type LineAudience = "food" | "merchant";

export type LineLinkStatus = {
  linked: boolean;
  friendStatus: "unknown" | "friend" | "not_friend" | null;
  addFriendUrl: string | null;
};

/** The Merchant origin uses the Merchant OA; everything else the customer OA. */
export function lineAudienceFor(hostname: string, requested: string | null): LineAudience {
  if (requested === "food" || requested === "merchant") return requested;
  return hostname.toLowerCase() === "merchant.wynos.online" ? "merchant" : "food";
}

const LIFF_ID = /^\d{10}-[A-Za-z0-9]{8}$/;

export function liffIdFor(audience: LineAudience, ids: { food?: string; merchant?: string }): string | null {
  const id = (audience === "food" ? ids.food : ids.merchant)?.trim() ?? "";
  return LIFF_ID.test(id) ? id : null;
}

/** LIFF IDs from the build environment (inlined by Next.js). */
export function configuredLiffIds(): { food?: string; merchant?: string } {
  return {
    food: process.env.NEXT_PUBLIC_LIFF_ID_FOOD,
    merchant: process.env.NEXT_PUBLIC_LIFF_ID_MERCHANT,
  };
}

const ORDER_QUERY = /^\?order=(?:WF\d{4,9}|ZF-\d{4,9})$/;
// Founder 2026-11-04: a store QR opens that store in LINE (share code or id).
const FOOD_STORE_PATH = /^(?:\/s\/[a-hjkmnp-z2-9]{6}|\/food\?store=[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/;

/**
 * Where a LINE message button may send the user: only that audience's app
 * home, one of its orders, or (customer) a store share link. Anything else (other paths, origins, schemes)
 * falls back to the app home, so /line can never be an open redirect.
 */
export function safeLineDestination(audience: LineAudience, to: string | null): string {
  const home = `/${audience}`;
  if (!to || to.length > 64) return home;
  if (to === home) return home;
  if (to.startsWith(home) && ORDER_QUERY.test(to.slice(home.length))) return to;
  if (audience === "food" && FOOD_STORE_PATH.test(to)) return to;
  return home;
}

/** Ask scanners to add/unblock the linked OA before opening their store. */
export async function requestStoreLineFriendship(
  destination: string,
  liff: Pick<Liff, "isApiAvailable" | "getFriendship" | "requestFriendship">,
): Promise<void> {
  if (!FOOD_STORE_PATH.test(destination)) return;
  try {
    if (!liff.isApiAvailable("requestFriendship")) return;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const friendship = await Promise.race([
      liff.getFriendship(),
      new Promise<null>((resolve) => { timeout = setTimeout(() => resolve(null), 4000); }),
    ]).finally(() => clearTimeout(timeout));
    // Only the lookup is bounded; let the user finish the visible prompt.
    if (friendship?.friendFlag === false) await liff.requestFriendship();
  } catch {
    // An unsupported client or missing linked OA must not prevent ordering.
    // LINE Developers needs the linked customer OA, profile scope and Full size.
  }
}

/** The same-browser link flow, started from the settings cards. */
export function lineLinkPath(audience: LineAudience): string {
  return `/line?mode=link&oa=${audience}`;
}

export function lineLinkStatusFrom(data: unknown): LineLinkStatus | null {
  if (!data || typeof data !== "object") return null;
  const { linked, friendStatus, addFriendUrl } = data as Record<string, unknown>;
  if (typeof linked !== "boolean") return null;
  const status = friendStatus === "friend" || friendStatus === "not_friend" || friendStatus === "unknown"
    ? friendStatus
    : null;
  const url = typeof addFriendUrl === "string" && addFriendUrl.startsWith("https://line.me/R/ti/p/")
    ? addFriendUrl
    : null;
  return { linked, friendStatus: linked ? status : null, addFriendUrl: url };
}

export function lineStatusText(status: LineLinkStatus | null): string {
  if (!status) return "ยังไม่ได้เชื่อม LINE";
  if (!status.linked) return "ยังไม่ได้เชื่อม LINE";
  if (status.friendStatus === "not_friend") return "เชื่อมแล้ว แต่ยังไม่ได้เพิ่มเพื่อน LINE OA — ยังไม่ได้รับข้อความ";
  return "เชื่อม LINE แล้ว รับแจ้งเตือนทาง LINE";
}

// Founder 2026-11-04 ("ทำแจ้งเตือนอัตโนมัติ"): a customer who opens ZOKY from
// LINE gets LINE notifications without tapping "เชื่อม LINE". If they still
// have to sign in, this remembers where they were going so the signed-in
// app returns to /line once to finish the link.
const AUTO_LINK_KEY = "zoky.line-autolink.v1";
const AUTO_LINK_MAX_AGE_MS = 30 * 60 * 1000;

/** LINE's in-app browser (also the LIFF browser). */
export function isLineInAppBrowser(userAgent: string): boolean {
  return /\bLine\/\d/i.test(userAgent);
}

export function rememberLineAutoLink(destination: string): void {
  try {
    window.localStorage.setItem(AUTO_LINK_KEY, JSON.stringify({ at: Date.now(), to: safeLineDestination("food", destination) }));
  } catch { /* storage unavailable */ }
}

/** The pending destination, once; null when none or older than 30 minutes. */
export function takeLineAutoLink(now = Date.now()): string | null {
  try {
    const raw = window.localStorage.getItem(AUTO_LINK_KEY);
    window.localStorage.removeItem(AUTO_LINK_KEY);
    if (!raw) return null;
    const value = JSON.parse(raw) as { at?: unknown; to?: unknown };
    if (typeof value.at !== "number" || now - value.at > AUTO_LINK_MAX_AGE_MS || typeof value.to !== "string") return null;
    return safeLineDestination("food", value.to);
  } catch {
    return null;
  }
}
