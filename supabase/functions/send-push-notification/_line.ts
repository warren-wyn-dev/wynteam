// ZOKY-LINE-001: LINE OA as an additional delivery channel for Food
// (customer) and Merchant (store) notifications. Web Push is unchanged; a
// LINE failure never affects it. Pure helpers live here so they can be
// tested without network access or secrets.
import type { PushApp } from "./_lib.ts";

export type LineAudience = Exclude<PushApp, "social">;

export type LineConfig = {
  audience: LineAudience;
  accessToken: string;
  liffId: string | null;
};

type Env = (name: string) => string | undefined;

const LIFF_ID = /^\d{10}-[A-Za-z0-9]{8}$/;
const ORDER = /^WF\d{4,9}$/;
const UUID = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;

/** LINE delivery for this app, or null when it is off or not configured. */
export function lineConfigFor(app: PushApp, env: Env): LineConfig | null {
  if (app === "social") return null;
  if (env("LINE_NOTIFICATIONS_ENABLED") !== "1") return null;
  const prefix = app === "food" ? "LINE_FOOD" : "LINE_MERCHANT";
  const accessToken = env(`${prefix}_CHANNEL_ACCESS_TOKEN`)?.trim();
  if (!accessToken) return null;
  const liffId = env(`${prefix}_LIFF_ID`)?.trim() ?? "";
  return { audience: app, accessToken, liffId: LIFF_ID.test(liffId) ? liffId : null };
}

const ORIGIN: Record<LineAudience, string> = {
  food: "https://food.wynos.online",
  merchant: "https://merchant.wynos.online",
};

/**
 * Where the button opens: the same in-app destination Web Push uses
 * (public/sw.js pushTarget), through LIFF when configured so it stays in LINE.
 */
export function lineDestination(config: LineConfig, orderNumber: string | null): string {
  const order = orderNumber && ORDER.test(orderNumber) ? `?order=${orderNumber}` : "";
  const path = `/${config.audience}${order}`;
  return config.liffId
    ? `https://liff.line.me/${config.liffId}?to=${encodeURIComponent(path)}`
    : `${ORIGIN[config.audience]}${path}`;
}

export type LineSendOutcome = "line_sent" | "line_skipped" | "line_filtered" | `line_failed_${number}` | "line_error";

/**
 * Push one notification. The notification id is the retry key, so a webhook
 * redelivery never sends the same LINE message twice (LINE answers 409).
 */
export async function sendLinePush(
  fetchFn: typeof fetch,
  config: LineConfig,
  lineUserId: string,
  messages: unknown[],
  notificationId: string,
): Promise<LineSendOutcome> {
  try {
    const response = await fetchFn("https://api.line.me/v2/bot/message/push", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.accessToken}`,
        "Content-Type": "application/json",
        ...(UUID.test(notificationId) ? { "X-Line-Retry-Key": notificationId } : {}),
      },
      body: JSON.stringify({ to: lineUserId, messages }),
    });
    await response.body?.cancel();
    if (response.ok || response.status === 409) return "line_sent";
    return `line_failed_${response.status}`;
  } catch {
    return "line_error";
  }
}
