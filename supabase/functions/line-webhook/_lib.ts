// ZOKY-LINE-001: pure logic for the LINE OA webhook (follow / unfollow).

export type LineAudience = "food" | "merchant";

export function audienceFromUrl(url: string): LineAudience | null {
  const oa = new URL(url).searchParams.get("oa");
  return oa === "food" || oa === "merchant" ? oa : null;
}

function base64(bytes: ArrayBuffer): string {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function constantTimeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  let diff = left.length ^ right.length;
  for (let i = 0; i < Math.max(left.length, right.length); i += 1) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

/** X-Line-Signature = base64(HMAC-SHA256(channel secret, raw request body)). */
export async function isValidLineSignature(
  channelSecret: string,
  rawBody: string,
  signature: string | null,
): Promise<boolean> {
  if (!channelSecret || !signature) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(channelSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  return constantTimeEqual(base64(mac), signature);
}

export type FriendUpdate = { lineUserId: string; friendStatus: "friend" | "not_friend" };

const LINE_USER_ID = /^U[0-9a-f]{32}$/;

/**
 * The latest follow/unfollow per user in this delivery. Other events
 * (messages, postbacks, group joins) are ignored: no chat bot in scope.
 */
export function friendUpdates(body: unknown): FriendUpdate[] {
  const events = (body as { events?: unknown } | null)?.events;
  if (!Array.isArray(events)) return [];
  const latest = new Map<string, FriendUpdate>();
  for (const event of events) {
    const { type, source } = (event ?? {}) as { type?: unknown; source?: { type?: unknown; userId?: unknown } };
    if (type !== "follow" && type !== "unfollow") continue;
    if (source?.type !== "user" || typeof source.userId !== "string" || !LINE_USER_ID.test(source.userId)) continue;
    latest.set(source.userId, {
      lineUserId: source.userId,
      friendStatus: type === "follow" ? "friend" : "not_friend",
    });
  }
  return [...latest.values()];
}
