// ZOKY-LINE-001: pure logic for linking a signed-in ZOKY account to LINE.
// The LINE userId is taken only from an ID token that LINE itself verifies
// for our LINE Login channel -- never from a client-supplied field.

export type LineAudience = "food" | "merchant";
export type LinkAction = "status" | "link" | "unlink";
export type FriendStatus = "unknown" | "friend" | "not_friend";

export type LinkRequest =
  | { action: "status" | "unlink"; audience: LineAudience }
  | { action: "link"; audience: LineAudience; idToken: string };

const LINE_USER_ID = /^U[0-9a-f]{32}$/;
// A JWT: three base64url parts. Bounded so a huge body is rejected early.
const ID_TOKEN = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;

export function parseLinkRequest(body: unknown): LinkRequest | null {
  if (!body || typeof body !== "object") return null;
  const { action, audience, idToken } = body as Record<string, unknown>;
  if (audience !== "food" && audience !== "merchant") return null;
  if (action === "status" || action === "unlink") return { action, audience };
  if (action !== "link") return null;
  if (typeof idToken !== "string" || idToken.length > 4096 || !ID_TOKEN.test(idToken)) return null;
  return { action, audience, idToken };
}

/**
 * Verify a LIFF/LINE Login ID token with LINE and return its LINE userId.
 * LINE checks the signature, issuer and expiry and rejects a token for any
 * other channel (client_id); aud/exp/sub are rechecked here as well.
 */
export async function verifiedLineUserId(
  fetchFn: typeof fetch,
  idToken: string,
  channelId: string,
  nowMs: number,
): Promise<string | null> {
  try {
    const response = await fetchFn("https://api.line.me/oauth2/v2.1/verify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ id_token: idToken, client_id: channelId }).toString(),
    });
    if (!response.ok) {
      await response.body?.cancel();
      return null;
    }
    const claims = await response.json() as { sub?: unknown; aud?: unknown; exp?: unknown; iss?: unknown };
    if (claims.iss !== "https://access.line.me") return null;
    if (claims.aud !== channelId) return null;
    if (typeof claims.exp !== "number" || claims.exp * 1000 <= nowMs) return null;
    return typeof claims.sub === "string" && LINE_USER_ID.test(claims.sub) ? claims.sub : null;
  } catch {
    return null;
  }
}

/** Whether this LINE user currently has the OA as a friend (can receive push). */
export async function lineFriendStatus(
  fetchFn: typeof fetch,
  accessToken: string,
  lineUserId: string,
): Promise<FriendStatus> {
  if (!LINE_USER_ID.test(lineUserId)) return "unknown";
  try {
    const response = await fetchFn(`https://api.line.me/v2/bot/profile/${lineUserId}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    await response.body?.cancel();
    if (response.ok) return "friend";
    // 404: never added, or blocked. LINE does not say which.
    if (response.status === 404) return "not_friend";
    return "unknown";
  } catch {
    return "unknown";
  }
}

const BASIC_ID = /^@[0-9a-z._-]{3,30}$/i;

/** "Add friend" link for the audience's OA, from its basic id (e.g. @123abcd). */
export function addFriendUrl(basicId: string | undefined): string | null {
  const id = basicId?.trim() ?? "";
  return BASIC_ID.test(id) ? `https://line.me/R/ti/p/${encodeURIComponent(id)}` : null;
}

const ALLOWED_ORIGINS = new Set([
  "https://food.wynos.online",
  "https://merchant.wynos.online",
  "https://zoky.wynos.online",
  "https://wynos.online",
  "https://www.wynos.online",
]);

/** Extra exact https origins for staging (LINE_LINK_EXTRA_ORIGINS, comma separated). */
export function extraOrigins(raw: string | undefined): string[] {
  return (raw ?? "").split(",").map((value) => value.trim())
    .filter((value) => /^https:\/\/[a-z0-9.-]+(?::\d+)?$/i.test(value));
}

export function corsHeaders(origin: string | null, extra: string[] = []): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
  if (origin && (ALLOWED_ORIGINS.has(origin) || extra.includes(origin))) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}
