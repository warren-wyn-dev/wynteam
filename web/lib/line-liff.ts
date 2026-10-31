// ZOKY-LINE-001: pure helpers for the /line LIFF entry and the
// "รับแจ้งเตือนทาง LINE" cards. No secrets: LIFF IDs are public identifiers.

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

const ORDER_QUERY = /^\?order=WF\d{4,9}$/;

/**
 * Where a LINE message button may send the user: only that audience's app
 * home or one of its orders. Anything else (other paths, origins, schemes)
 * falls back to the app home, so /line can never be an open redirect.
 */
export function safeLineDestination(audience: LineAudience, to: string | null): string {
  const home = `/${audience}`;
  if (!to || to.length > 64) return home;
  if (to === home) return home;
  if (to.startsWith(home) && ORDER_QUERY.test(to.slice(home.length))) return to;
  return home;
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
