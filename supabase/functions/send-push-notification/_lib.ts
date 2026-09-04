// WYN-016: pure/testable logic for send-push-notification, split out of
// index.ts so it can be unit tested without importing index.ts itself
// (which calls Deno.serve() at module load time -- importing it would
// start a server as a side effect of running `deno test`).

export interface NotificationRow {
  id: string;
  recipient_id: string;
  // Nullable (WYN-029 fix, mirrors WynNotification.actorId in the Dart
  // client exactly): null only for moderation_warning/
  // moderation_content_removed and system -- see notification.dart's
  // own doc comment for why.
  actor_id: string | null;
  type: string;
  drop_id: string | null;
  pop_id: string | null;
  club_id: string | null;
  club_post_id: string | null;
  order_id: string | null;
  // WYN-029/030/032 -- added for the moderation/appeal/message-request
  // types below. Same columns notification.dart's WynNotification
  // already reads (reason/moderationActionId/moderationActionType/
  // conversationId).
  reason: string | null;
  moderation_action_id: string | null;
  moderation_action_type: string | null;
  conversation_id: string | null;
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

// ---------------------------------------------------------------------
// Thai message templates -- mirror `_messageFor` in
// app/lib/features/notification/presentation/notification_list_screen.dart
// and seller_app/lib/features/notification/presentation/
// seller_notification_list_screen.dart *exactly*, word for word. If
// either of those ever changes wording, this must change too -- there
// is no shared source of truth across Dart and this Deno function (no
// package-sharing infra in this project, same reasoning as every other
// cross-app/cross-language duplication here).
// ---------------------------------------------------------------------
export function displayNameOrUsername(displayName: string | null, username: string): string {
  return displayName && displayName.length > 0 ? displayName : `@${username}`;
}

export function messageFor(
  type: string,
  actorName: string,
  clubName: string | null,
  storeName: string | null,
  // Optional/trailing so every existing call site (and every existing
  // test) keeps compiling unchanged -- only the WYN-029/030/032/034/039/
  // 043 types below read either of these.
  reason: string | null = null,
  moderationActionType: string | null = null,
): string {
  const club = clubName ?? "Club";
  // Fallback text differs by type in the Dart source this mirrors --
  // `new_order` (app/'s NotificationListScreen._messageFor) falls back
  // to "ร้านของคุณ" specifically; order_shipped/order_cancelled_buyer/
  // order_refunded fall back to "ร้านค้า". Not a typo -- read both
  // exactly before touching either.
  const store = storeName ?? "ร้านค้า";
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
    // The 2 order_cancelled_* pseudo-types below don't exist as a DB
    // `type` value -- the caller (index.ts) resolves the real
    // bidirectional `order_cancelled` type (see notify_order_cancelled
    // in supabase/schema.sql) to one of these two based on who the
    // *recipient* of this specific row actually is, before calling
    // this function. See index.ts for that resolution.
    case "new_order": {
      // Uses the real store name when known -- exactly app/'s wording
      // (`'$name สั่งซื้อสินค้าจาก $store'`, store falling back to
      // "ร้านของคุณ"), not seller_app's fixed "...จากร้านของคุณ" wording
      // for the same type (the two apps render this notification type
      // slightly differently in-app too -- see notification.dart's
      // `_messageFor` vs seller_notification.dart's -- this picks the
      // more informative one since a push body is a single fixed
      // string, unlike in-app which re-renders per viewing app).
      const newOrderStore = storeName ?? "ร้านของคุณ";
      return `${actorName} สั่งซื้อสินค้าจาก ${newOrderStore}`;
    }
    case "order_shipped":
      return `คำสั่งซื้อของคุณจาก ${store} ถูกจัดส่งแล้ว`;
    case "order_cancelled_seller":
      // Recipient is the seller (buyer cancelled) -- mirrors seller_
      // notification_list_screen.dart's orderCancelled wording exactly.
      return `${actorName} ยกเลิกคำสั่งซื้อที่ร้านของคุณ`;
    case "order_cancelled_buyer":
      // Recipient is the buyer (seller cancelled) -- mirrors app/'s
      // NotificationType.orderCancelled wording exactly.
      return `คำสั่งซื้อจากร้าน ${store} ถูกยกเลิก`;
    case "order_refunded":
      return `คำสั่งซื้อของคุณจาก ${store} ถูกคืนเงินแล้ว`;
    // WYN-021: mirrors app/'s notification_list_screen.dart's
    // `_messageFor` word for word (seller_app has no mention concept).
    case "mention_drop":
      return `${actorName} กล่าวถึงคุณในโพสต์`;
    case "mention_club_post":
      return `${actorName} กล่าวถึงคุณในโพสต์ที่ ${club}`;
    // WYN-034/043: same destination/data field as like_drop/mentionDrop
    // (drop_id) -- see buildDataPayload, no new field needed.
    case "redrop":
      return `${actorName} รีโพสต์โพสต์ของคุณ`;
    // WYN-029: mirrors notification_list_screen.dart's `_messageFor`
    // word for word. actor_id is null for both of these (WYN-029 fix --
    // see NotificationRow's own doc comment), which is fine here since
    // neither template references actorName.
    case "moderation_warning":
      return `คุณได้รับคำเตือนจากทีมงาน WYN: ${reason ?? ""}`;
    case "moderation_content_removed":
      return `เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- ` +
        `เหตุผล: ${reason ?? ""}`;
    // WYN-030: mirrors the Dart client's per-action-type wording
    // exactly -- see notification_list_screen.dart's own comment on why
    // Remove Content's wording may never imply the content itself came
    // back.
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
    // WYN-032/039: actor_id is always real for these 3 -- see
    // notification.dart's own doc comment.
    case "message_request":
      return `${actorName} ส่งคำขอข้อความถึงคุณ`;
    case "follow_request":
      return `${actorName} ขอติดตามคุณ`;
    case "follow_request_accepted":
      return `${actorName} ยอมรับคำขอติดตามของคุณแล้ว`;
    // WYN-043: the admin's own message text, shown as-is -- same `reason`
    // column moderation_warning/moderation_content_removed use above,
    // just with no fixed prefix (send_system_notification() already
    // writes the full message).
    case "system":
      return reason ?? "มีประกาศจากระบบ WYN";
    default:
      return "คุณมีการแจ้งเตือนใหม่";
  }
}

// ---------------------------------------------------------------------
// Google OAuth2 JWT-bearer flow -- mints an FCM v1-scoped access token
// from the service account's private key. Deno's Web Crypto
// (crypto.subtle) supports RS256 signing directly with a PKCS8 key,
// which is exactly the format a Firebase service account JSON's
// `private_key` field already is (PEM-encoded PKCS8) -- no external
// JWT/OAuth library needed.
// ---------------------------------------------------------------------
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

/// Builds the signed JWT assertion (header.claims.signature) for the
/// OAuth2 JWT-bearer grant -- split out from the token-exchange HTTP
/// call itself so the signing logic alone (the part with real
/// cryptographic correctness risk) can be unit tested without a live
/// network call to Google.
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

/// The de-duplication key for one notification, used by all three
/// delivery layers (Beta4 §11.6).
///
/// The problem this solves is not hypothetical: `send-push-notification`
/// is driven by a Supabase Database Webhook, and a webhook that does not
/// receive a timely 200 is retried. Before Beta4 a retry produced a
/// second, identical notification on the device -- the row insert had
/// already happened, so the in-app list was correct, but the phone
/// showed the same thing twice.
///
/// A collapse key does not prevent the second *send*; it makes the
/// second send land on top of the first instead of beside it, which is
/// the behaviour every platform offers and the only one available
/// without giving this function its own delivery ledger. FCM's own
/// per-platform names for the same idea:
/// * Web -- `webpush.headers.Topic`, plus the `tag` the service worker
///   sets on `showNotification`.
/// * Android -- `android.collapse_key`.
/// * iOS -- `apns.headers.apns-collapse-id`.
///
/// Keyed on the notification row id rather than, say, type+target: two
/// different people liking the same post are two notifications a person
/// should see separately, and the in-app list already groups those (see
/// `_groupWithinDay` in notification_list_screen.dart). This collapses
/// only a literal redelivery of one row.
///
/// APNs caps `apns-collapse-id` at 64 bytes; a uuid is 36, so no
/// truncation is needed for any id this table produces.
export function collapseKeyFor(row: NotificationRow): string {
  return row.id;
}

/// A short, safe description of a thrown value, for the one place a
/// failure here is visible from: the response body, which pg_net stores
/// in `net._http_response`.
///
/// Without this, every failure in the function is an opaque 500. That
/// cost a real debugging round: a service-account key that would not
/// parse looked exactly like a key that would not sign, and neither
/// could be told apart from the outside. The push path is
/// fire-and-forget by design -- nobody is watching a screen when it
/// fails -- so the stored reply is the only record there will be.
///
/// It is scrubbed rather than passed through, because the values in
/// scope when things go wrong here include a Firebase private key and
/// an FCM access token, and `net._http_response` is readable by anyone
/// with database access. PEM blocks and long base64 runs come out; the
/// error's name and a truncated message stay, which is what actually
/// distinguishes the cases.
/// Condenses the per-token results of one notification's fan-out into a
/// single line for the response body.
///
/// "OK" alone was ambiguous in the way that matters: the function
/// returns it after FCM has rejected every device just as readily as
/// after it accepted them all, and net._http_response is the only place
/// anyone ever sees this. `sent=0 failed=2 (404 UNREGISTERED)` says in
/// one line both that nothing arrived and why.
///
/// Reasons are deduplicated because a fan-out to many devices usually
/// fails the same way on all of them, and a row of identical strings
/// would push the useful part out of a truncated log.
export function summariseOutcomes(outcomes: string[]): string {
  const sent = outcomes.filter((o) => o === "sent").length;
  const failures = outcomes.filter((o) => o !== "sent");
  if (failures.length === 0) return `OK sent=${sent}`;
  const reasons = [...new Set(failures)].join(", ");
  return `OK sent=${sent} failed=${failures.length} (${reasons})`;
}

export function safeErrorMessage(err: unknown): string {
  const name = err instanceof Error ? err.name : "Error";
  const raw = err instanceof Error ? err.message : String(err);
  const scrubbed = raw
    .replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, "[pem]")
    .replace(/[A-Za-z0-9+/_-]{40,}={0,2}/g, "[redacted]");
  return `${name}: ${scrubbed}`.slice(0, 300);
}

/// Which of the `notifications`-row id columns are non-null becomes the
/// FCM `data` payload -- split out so the "only include set fields, as
/// strings" logic can be tested without any network/crypto involved.
/// `actor_id` is included only when set (WYN-029 fix: null for
/// moderation_warning/moderation_content_removed/system) -- omitting it
/// rather than sending the literal string "null" mirrors every other
/// optional field here.
export function buildDataPayload(row: NotificationRow): Record<string, string> {
  const data: Record<string, string> = { type: row.type };
  // Beta4 §11.6 (Duplicate Protection): the notification's own row id,
  // carried so every delivery layer can collapse a repeat of the *same*
  // notification onto the one already showing -- see
  // [collapseKeyFor]/the `webpush`/`android`/`apns` blocks in index.ts,
  // and the `tag` the web service worker sets from this field.
  //
  // This is the id of the row that triggered the webhook, so it is
  // stable across a webhook retry and distinct between two genuinely
  // different notifications (even two of the same type about the same
  // post). It is not read by the client's deep-link switch -- that
  // keys off `type` plus the target id, exactly as before.
  data.notification_id = row.id;
  if (row.actor_id) data.actor_id = row.actor_id;
  if (row.drop_id) data.drop_id = row.drop_id;
  if (row.pop_id) data.pop_id = row.pop_id;
  if (row.club_id) data.club_id = row.club_id;
  if (row.club_post_id) data.club_post_id = row.club_post_id;
  if (row.order_id) data.order_id = row.order_id;
  // WYN-032: lets the client open ConversationScreen directly on tap.
  if (row.conversation_id) data.conversation_id = row.conversation_id;
  // WYN-030: lets the client open MyModerationActionScreen directly on
  // tap, for all 4 moderation-related types.
  if (row.moderation_action_id) data.moderation_action_id = row.moderation_action_id;
  return data;
}
