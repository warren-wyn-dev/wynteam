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

/** WYN-189: the recipient's chosen app language (user_preferences). */
export type PushLanguage = "th" | "en";

export function pushLanguageFrom(value: unknown): PushLanguage {
  return value === "en" ? "en" : "th";
}

export function dmMessagePreview(
  text: string | null,
  imageUrl: string | null,
  sharedContentType: string | null,
  viewOnce = false,
  lang: PushLanguage = "th",
): string {
  const trimmed = text?.trim();
  if (trimmed) return trimmed;

  if (lang === "en") {
    if (imageUrl) return viewOnce ? "sent you a view-once photo" : "sent you a photo";
    switch (sharedContentType) {
      case "drop":
        return "shared a post with you";
      case "profile":
        return "shared a profile with you";
      case "club":
        return "shared a Club with you";
      default:
        return "sent you a message";
    }
  }

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
  lang: PushLanguage = "th",
): string {
  if (lang === "en") return messageForEn(type, actorName, clubName, reason, moderationActionType, dmPreview);
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
    case "club_announcement":
      return `${actorName} ประกาศใน ${club}`;
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

function messageForEn(
  type: string,
  actorName: string,
  clubName: string | null,
  reason: string | null,
  moderationActionType: string | null,
  dmPreview: string | null,
): string {
  const club = clubName ?? "Club";
  switch (type) {
    case "like_drop":
      return `${actorName} liked your post`;
    case "like_pop":
      return `${actorName} liked your Pop`;
    case "comment_drop":
      return `${actorName} commented on your post`;
    case "comment_pop":
      return `${actorName} commented on your Pop`;
    case "follow":
      return `${actorName} started following you`;
    case "club_join_request":
      return `${actorName} asked to join your ${club}`;
    case "club_join_approved":
      return `${actorName} approved your request to join ${club}`;
    case "club_post_like":
      return `${actorName} liked your post in ${club}`;
    case "club_post_comment":
      return `${actorName} commented on your post in ${club}`;
    case "club_post_new":
      return `${actorName} posted in ${club}`;
    case "club_post_pinned":
      return `${actorName} pinned a new post in ${club}`;
    case "club_announcement":
      return `${actorName} posted an announcement in ${club}`;
    case "club_invite":
      return `${actorName} invited you to join ${club}`;
    case "mention_drop":
      return `${actorName} mentioned you in a post`;
    case "mention_club_post":
      return `${actorName} mentioned you in a post in ${club}`;
    case "redrop":
      return `${actorName} reposted your post`;
    case "moderation_warning":
      return `You've received a warning from the WYN team: ${reason ?? ""}`;
    case "moderation_content_removed":
      return `Your content was removed for breaking the WYN rules -- reason: ${reason ?? ""}`;
    case "appeal_approved":
      switch (moderationActionType) {
        case "warning":
          return "Your appeal was approved. The warning has been removed from your account history";
        case "restrict":
          return "Your appeal was approved. You can post normally again";
        case "suspend":
          return "Your appeal was approved. Your account is back to normal";
        case "ban":
          return "Your appeal was approved. Your account is back to normal and you can sign in right away";
        case "remove_content":
          return "Your appeal was approved. The violation has been removed from your account history";
        default:
          return "Your appeal was approved";
      }
    case "appeal_rejected":
      return `Your appeal was rejected -- reason: ${reason ?? ""}`;
    case "message_request":
      return `${actorName} sent you a message request`;
    case "new_message":
      return `${actorName} ${dmPreview ?? "sent you a message"}`;
    case "follow_request":
      return `${actorName} requested to follow you`;
    case "follow_request_accepted":
      return `${actorName} accepted your follow request`;
    case "system":
      return reason ?? "A notice from the WYN system";
    default:
      return "You have a new notification";
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

export async function fetchFcmAccessToken(serviceAccount: FcmServiceAccount): Promise<string> {
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
    throw new Error(`FCM OAuth2 token request failed: ${response.status} ${await response.text()}`);
  }
  const json = await response.json();
  return json.access_token as string;
}

export const MERCHANT_NOTIFICATION_TEST_REASON = "WYNOS Merchant · ทดสอบการแจ้งเตือน";

export function isMerchantNotificationTest(row: NotificationRow): boolean {
  return row.type === "system" && row.reason === MERCHANT_NOTIFICATION_TEST_REASON;
}

export type PushPreferenceCategory = "likes" | "comments" | "follows" | "messages" | "club" | "trending" | "system";

export function pushPreferenceCategory(type: string): PushPreferenceCategory {
  if (type === "like_drop" || type === "like_pop" || type === "redrop") return "likes";
  if (type === "follow" || type === "follow_request" || type === "follow_request_accepted") return "follows";
  if (type === "message_request" || type === "new_message") return "messages";
  if (type.startsWith("club_") || type === "mention_club_post") return "club";
  if (type === "trending") return "trending";
  if (type === "comment_drop" || type === "comment_pop" || type === "mention_drop") return "comments";
  return "system";
}

function clockMinutes(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})/.exec(value);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

export function isQuietHourAt(
  now: Date,
  timezone: string,
  start: string,
  end: string,
): boolean {
  const startMinutes = clockMinutes(start);
  const endMinutes = clockMinutes(end);
  if (startMinutes == null || endMinutes == null || startMinutes === endMinutes) return false;
  try {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone: timezone || "UTC",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(now);
    const hour = Number(parts.find((part) => part.type === "hour")?.value ?? "-1");
    const minute = Number(parts.find((part) => part.type === "minute")?.value ?? "-1");
    if (hour < 0 || minute < 0) return false;
    const current = hour * 60 + minute;
    return startMinutes < endMinutes
      ? current >= startMinutes && current < endMinutes
      : current >= startMinutes || current < endMinutes;
  } catch {
    // An invalid timezone should never suppress a notification.
    return false;
  }
}

export function isRetryableFcmStatus(httpStatus: number): boolean {
  return httpStatus === 429 || httpStatus === 500 || httpStatus === 502 || httpStatus === 503 || httpStatus === 504;
}

export function collapseKeyFor(row: NotificationRow): string {
  return row.id;
}

export function webPushTopic(collapseKey: string): string {
  return collapseKey.replace(/-/g, "").replace(/[^A-Za-z0-9_]/g, "").slice(0, 32);
}

/**
 * Whether an FCM send error proves this device token is dead, so it should
 * be removed. INVALID_ARGUMENT alone does not: FCM returns it for a bad
 * message too, and deleting on it silently turned Push off for every
 * device the moment one message was rejected. Only a token-specific
 * INVALID_ARGUMENT ("registration token is not valid") counts.
 */
export function isDeadTokenError(status: string | undefined, message: string | undefined): boolean {
  if (status === "UNREGISTERED" || status === "NOT_FOUND") return true;
  if (status === "INVALID_ARGUMENT") return /registration token/i.test(message ?? "");
  return false;
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

/**
 * Which installed WYNOS app a notification belongs to (Founder, 2026-10-05).
 * Food and Merchant notifications are all `system` rows told apart by the
 * text their database triggers write, so these prefixes must follow those
 * triggers. Anything unrecognised stays with the Social app, as before.
 */
export type PushApp = "social" | "food" | "merchant";

const MERCHANT_REASON_PREFIX = "WYNOS Merchant · ";
const MERCHANT_REASONS = [
  /^WYNOS Merchant · /,
  /^คำขอ WYNOS Merchant/,
  /^WYNOS (เติมเครดิตโฆษณาร้าน|ไม่อนุมัติการเติมเครดิตโฆษณาร้าน|หยุดโฆษณาร้าน|เปิดให้ร้าน|โอนส่วนลดแคมเปญคืนร้าน) /,
  /^ร้าน .+ (ถูกระงับชั่วคราวโดยทีม WYNOS|ยกเลิกการระงับแล้ว)/,
];
const FOOD_REASONS = [/^(ชำระเงินออเดอร์|สลิปออเดอร์|คืนเงินออเดอร์|ออเดอร์) #WF\d+/];

export function pushAppForNotification(row: Pick<NotificationRow, "type" | "reason">): PushApp {
  if (row.type !== "system") return "social";
  const reason = (row.reason ?? "").trim();
  if (MERCHANT_REASONS.some((pattern) => pattern.test(reason))) return "merchant";
  if (FOOD_REASONS.some((pattern) => pattern.test(reason))) return "food";
  return "social";
}

export const PUSH_APP_TITLES: Record<PushApp, string> = {
  social: "Wynos",
  food: "Wynos Food",
  merchant: "WYNOS Merchant",
};

/** The title and body shown on the phone for a notification of this app. */
export function pushMessageForApp(
  app: PushApp,
  message: string,
  actorName: string,
): { title: string; body: string } {
  if (app === "social") {
    const split = splitPushMessage(message, actorName);
    return split.title === "WYN" ? { title: PUSH_APP_TITLES.social, body: split.body } : split;
  }
  // The title already names the app; drop the "WYNOS Merchant · " prefix.
  const body = message.startsWith(MERCHANT_REASON_PREFIX)
    ? message.slice(MERCHANT_REASON_PREFIX.length)
    : message;
  return { title: PUSH_APP_TITLES[app], body };
}

type AppToken = { app?: string | null };

/**
 * The devices that should show a notification of `app`. Tokens registered
 * before per-app routing (app = null) count as the Social app. Food and
 * Merchant notifications fall back to the Social app when their own app has
 * no registered device, so nobody silently loses an order notification.
 */
export function tokensForApp<T extends AppToken>(tokens: T[], app: PushApp): T[] {
  const ofApp = (target: PushApp) =>
    tokens.filter((token) => (token.app ?? "social") === target);
  if (app === "social") return ofApp("social");
  const own = ofApp(app);
  return own.length > 0 ? own : ofApp("social");
}

export function safeErrorMessage(err: unknown): string {
  const name = err instanceof Error ? err.name : "Error";
  const raw = err instanceof Error ? err.message : String(err);
  const scrubbed = raw
    .replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, "[pem]")
    .replace(/[A-Za-z0-9+/_-]{40,}={0,2}/g, "[redacted]");
  return `${name}: ${scrubbed}`.slice(0, 300);
}

/** The Food order number (WF0015) a Food or Merchant notification is about. */
export function orderNumberInReason(reason: string | null): string | null {
  const match = /#(WF\d{4,9})\b/.exec(reason ?? "");
  return match ? match[1] : null;
}

export function buildDataPayload(row: NotificationRow): Record<string, string> {
  const data: Record<string, string> = { type: row.type };
  data.notification_id = row.id;
  // The web badge only applies an optimistic +1 when the Push names the
  // signed-in account; without it every Push is a slower refresh hint.
  data.recipient_id = row.recipient_id;
  if (isMerchantNotificationTest(row)) data.merchant_test = "1";
  const app = pushAppForNotification(row);
  if (app !== "social") {
    data.app = app;
    // Tapping a Food or Merchant notification opens that order.
    const order = orderNumberInReason(row.reason);
    if (order) data.order_number = order;
  }
  if (row.actor_id) data.actor_id = row.actor_id;
  if (row.drop_id) data.drop_id = row.drop_id;
  if (row.pop_id) data.pop_id = row.pop_id;
  if (row.club_id) data.club_id = row.club_id;
  if (row.club_post_id) data.club_post_id = row.club_post_id;
  if (row.conversation_id) data.conversation_id = row.conversation_id;
  if (row.moderation_action_id) data.moderation_action_id = row.moderation_action_id;
  return data;
}
