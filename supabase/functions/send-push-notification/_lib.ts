// WYN-016: pure/testable logic for send-push-notification, split out of
// index.ts so it can be unit tested without importing index.ts itself
// (which calls Deno.serve() at module load time -- importing it would
// start a server as a side effect of running `deno test`).

export interface NotificationRow {
  id: string;
  recipient_id: string;
  actor_id: string | null;
  type: string;
  drop_id: string | null;
  pop_id: string | null;
  club_id: string | null;
  club_post_id: string | null;
  reason: string | null;
  moderation_action_id: string | null;
  moderation_action_type: string | null;
  conversation_id: string | null;
  // Present on authoritative DB rows. Optional here so historical unit-test
  // fixtures and webhook-shaped helpers remain source-compatible.
  created_at?: string;
}

export interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: NotificationRow;
  schema: string;
}

export interface FcmServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

export function displayNameOrUsername(displayName: string | null, username: string): string {
  return displayName && displayName.length > 0 ? displayName : `@${username}`;
}

export function dmMessagePreview(
  text: string | null,
  imageUrl: string | null,
  sharedContentType: string | null,
  viewOnce = false,
): string {
  const trimmed = text?.trim();
  if (trimmed) return trimmed;

  if (imageUrl) {
    return viewOnce ? "ส่งรูปภาพแบบดูครั้งเดียว" : "ส่งรูปภาพ";
  }

  switch (sharedContentType) {
    case "drop":
      return "แชร์โพสต์กับคุณ";
    case "profile":
      return "แชร์โปรไฟล์กับคุณ";
    case "club":
      return "แชร์ Club กับคุณ";
    default:
      return "ส่งข้อความถึงคุณ";
  }
}

export function messageFor(
  type: string,
  actorName: string,
  clubName: string | null,
  reason: string | null = null,
  moderationActionType: string | null = null,
  dmPreview: string | null = null,
): string {
  const club = clubName ?? "Club";
  switch (type) {
    case "like_drop":
      return `${actorName} ถูกใจโพสต์ของคุณ`;
    case "like_pop":
      return `${actorName} ถูกใจ Pop ของคุณ`;
    case "comment_drop":
      return `${actorName} แสดงความคิดเห็นในโพสต์ของคุณ`;
    case "comment_pop":
      return `${actorName} แสดงความคิดเห็นใน Pop ของคุณ`;
    case "follow":
      return `${actorName} เริ่มติดตามคุณ`;
    case "club_join_request":
      return `${actorName} ขอเข้าร่วม ${club} ของคุณ`;
    case "club_join_approved":
      return `${actorName} อนุมัติคำขอเข้าร่วม ${club} ของคุณแล้ว`;
    case "club_post_like":
      return `${actorName} ถูกใจโพสต์ของคุณใน ${club}`;
    case "club_post_comment":
      return `${actorName} แสดงความคิดเห็นในโพสต์ของคุณใน ${club}`;
    case "club_post_new":
      return `${actorName} โพสต์ใหม่ใน ${club}`;
    case "club_post_pinned":
      return `${actorName} ปักหมุดโพสต์ใหม่ใน ${club}`;
    case "club_invite":
      return `${actorName} ชวนคุณเข้าร่วม ${club}`;
    case "mention_drop":
      return `${actorName} กล่าวถึงคุณในโพสต์`;
    case "mention_club_post":
      return `${actorName} กล่าวถึงคุณในโพสต์ที่ ${club}`;
    case "redrop":
      return `${actorName} รีโพสต์โพสต์ของคุณ`;
    case "moderation_warning":
      return `คุณได้รับคำเตือนจากทีมงาน WYN: ${reason ?? ""}`;
    case "moderation_content_removed":
      return `เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- ` +
        `เหตุผล: ${reason ?? ""}`;
    case "appeal_approved":
      switch (moderationActionType) {
        case "warning":
          return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว คำเตือนนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว";
        case "restrict":
          return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว สิทธิ์การโพสต์ของคุณกลับมาใช้งานได้ตามปกติแล้ว";
        case "suspend":
          return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว";
        case "ban":
          return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว " +
            "คุณสามารถเข้าสู่ระบบได้ทันที";
        case "remove_content":
          return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว";
        default:
          return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว";
      }
    case "appeal_rejected":
      return `อุทธรณ์ของคุณถูกปฏิเสธ -- เหตุผล: ${reason ?? ""}`;
    case "message_request":
      return `${actorName} ส่งคำขอข้อความถึงคุณ`;
    case "new_message":
      return `${actorName} ${dmPreview ?? "ส่งข้อความถึงคุณ"}`;
    case "follow_request":
      return `${actorName} ขอติดตามคุณ`;
    case "follow_request_accepted":
      return `${actorName} ยอมรับคำขอติดตามของคุณแล้ว`;
    case "system":
      return reason ?? "มีประกาศจากระบบ WYN";
    default:
      return "คุณมีการแจ้งเตือนใหม่";
  }
}

export function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function buildSignedJwtAssertion(
  serviceAccount: FcmServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };
  const headerB64 = base64Url(encoder.encode(JSON.stringify(header)));
  const claimsB64 = base64Url(encoder.encode(JSON.stringify(claims)));
  const signingInput = `${headerB64}.${claimsB64}`;

  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    encoder.encode(signingInput),
  );
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

type OAuthToken = { token: string; expiresInSeconds: number };

async function requestFcmAccessToken(serviceAccount: FcmServiceAccount): Promise<OAuthToken> {
  const assertion = await buildSignedJwtAssertion(serviceAccount, Math.floor(Date.now() / 1000));
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    // Never log the assertion or OAuth response body: they may contain
    // credentials, private keys, or bearer tokens.
    throw new Error(`FCM OAuth2 token request failed: ${response.status}`);
  }
  const json = await response.json() as { access_token?: unknown; expires_in?: unknown };
  if (typeof json.access_token !== "string" || !json.access_token) {
    throw new Error("FCM OAuth2 response did not contain an access token");
  }
  const seconds = Number(json.expires_in);
  return {
    token: json.access_token,
    expiresInSeconds: Number.isFinite(seconds) && seconds > 0 ? Math.min(seconds, 3600) : 300,
  };
}

// Retain the original one-shot API for tests and other callers.
export async function fetchFcmAccessToken(serviceAccount: FcmServiceAccount): Promise<string> {
  return (await requestFcmAccessToken(serviceAccount)).token;
}

/**
 * Edge isolates can receive many database webhooks, but previously fetched
 * Google OAuth for EVERY notification. Reuse a short-lived access token in
 * this one isolate; allow 90 seconds of expiry slack. Parallel webhooks
 * share one in-flight OAuth request, and 401 responses can invalidate just
 * the rejected token rather than repeatedly refreshing a newer one.
 */
export function createFcmAccessTokenCache(
  request: () => Promise<OAuthToken>,
  now: () => number = () => Date.now(),
) {
  let token: string | null = null;
  let validUntil = 0;
  let pending: Promise<string> | null = null;
  return {
    get(): Promise<string> {
      if (token && now() < validUntil) return Promise.resolve(token);
      if (pending) return pending;
      const task = request()
        .then((fresh) => {
          if (!fresh.token) throw new Error("FCM returned an empty access token");
          token = fresh.token;
          validUntil = now() + Math.max(0, fresh.expiresInSeconds - 90) * 1000;
          return fresh.token;
        })
        .catch((error) => {
          token = null;
          validUntil = 0;
          throw error;
        })
        .finally(() => { if (pending === task) pending = null; });
      pending = task;
      return task;
    },
    invalidate(rejected: string): void {
      if (token === rejected) {
        token = null;
        validUntil = 0;
      }
    },
  };
}

const oauthCaches = new Map<string, ReturnType<typeof createFcmAccessTokenCache>>();
function cacheFor(serviceAccount: FcmServiceAccount) {
  const key = `${serviceAccount.project_id}:${serviceAccount.client_email}`;
  let cache = oauthCaches.get(key);
  if (!cache) {
    cache = createFcmAccessTokenCache(() => requestFcmAccessToken(serviceAccount));
    oauthCaches.set(key, cache);
  }
  return cache;
}

export function getCachedFcmAccessToken(serviceAccount: FcmServiceAccount): Promise<string> {
  return cacheFor(serviceAccount).get();
}

export function invalidateCachedFcmAccessToken(serviceAccount: FcmServiceAccount, rejectedToken: string): void {
  cacheFor(serviceAccount).invalidate(rejectedToken);
}

export function collapseKeyFor(row: NotificationRow): string {
  return row.id;
}

export function webPushTopic(collapseKey: string): string {
  return collapseKey.replace(/-/g, "").replace(/[^A-Za-z0-9_]/g, "").slice(0, 32);
}

export function summariseOutcomes(outcomes: string[]): string {
  const sent = outcomes.filter((o) => o === "sent").length;
  const failures = outcomes.filter((o) => o !== "sent");
  if (failures.length === 0) return `OK sent=${sent}`;
  const reasons = [...new Set(failures)].join(", ");
  return `OK sent=${sent} failed=${failures.length} (${reasons})`;
}

export function splitPushMessage(
  message: string,
  actorName: string,
): { title: string; body: string } {
  const prefix = `${actorName} `;
  if (!message.startsWith(prefix)) {
    return { title: "WYN", body: message };
  }
  return { title: actorName, body: message.slice(prefix.length) };
}

export function safeErrorMessage(err: unknown): string {
  const name = err instanceof Error ? err.name : "Error";
  const raw = err instanceof Error ? err.message : String(err);
  const scrubbed = raw
    .replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, "[pem]")
    .replace(/[A-Za-z0-9+/_-]{40,}={0,2}/g, "[redacted]");
  return `${name}: ${scrubbed}`.slice(0, 300);
}

export function buildDataPayload(row: NotificationRow): Record<string, string> {
  const data: Record<string, string> = { type: row.type };
  data.notification_id = row.id;
  // The receiving device may have switched accounts while this webhook was
  // in flight. The browser can ignore an old recipient's hint before fetching.
  data.recipient_id = row.recipient_id;
  if (row.actor_id) data.actor_id = row.actor_id;
  if (row.drop_id) data.drop_id = row.drop_id;
  if (row.pop_id) data.pop_id = row.pop_id;
  if (row.club_id) data.club_id = row.club_id;
  if (row.club_post_id) data.club_post_id = row.club_post_id;
  if (row.conversation_id) data.conversation_id = row.conversation_id;
  if (row.moderation_action_id) data.moderation_action_id = row.moderation_action_id;
  return data;
}
