// WYN-016: unit tests for the pure logic in _lib.ts -- no network, no
// Deno.serve, no real Firebase project needed. Run with `deno test`.
import { assertEquals, assertMatch } from "jsr:@std/assert@1";

import {
  base64Url,
  buildDataPayload,
  buildSignedJwtAssertion,
  displayNameOrUsername,
  type FcmServiceAccount,
  importPrivateKey,
  messageFor,
  type NotificationRow,
} from "./_lib.ts";

Deno.test("displayNameOrUsername falls back to @username when displayName is null", () => {
  assertEquals(displayNameOrUsername(null, "namfah"), "@namfah");
});

Deno.test("displayNameOrUsername falls back to @username when displayName is empty", () => {
  assertEquals(displayNameOrUsername("", "namfah"), "@namfah");
});

Deno.test("displayNameOrUsername uses displayName when set", () => {
  assertEquals(displayNameOrUsername("น้ำฝน", "namfah"), "น้ำฝน");
});

// Mirrors app/test/notification_list_screen_test.dart's "shows type-
// specific Thai messages" assertions word for word -- these two message
// sets (Dart client vs this Deno function) must never drift apart, so
// this test is the guard for that.
Deno.test("messageFor produces the exact same Thai strings as the Dart client, WYN-012/015 types", () => {
  assertEquals(messageFor("like_drop", "น้ำฝน", null, null), "น้ำฝน ถูกใจโพสต์ของคุณ");
  assertEquals(messageFor("like_pop", "@ploy", null, null), "@ploy ถูกใจ Pop ของคุณ");
  assertEquals(
    messageFor("comment_drop", "น้ำฝน", null, null),
    "น้ำฝน แสดงความคิดเห็นในโพสต์ของคุณ",
  );
  assertEquals(
    messageFor("comment_pop", "@ploy", null, null),
    "@ploy แสดงความคิดเห็นใน Pop ของคุณ",
  );
  assertEquals(messageFor("follow", "@benz", null, null), "@benz เริ่มติดตามคุณ");
  assertEquals(
    messageFor("club_join_request", "@gam", "ชมรมถ่ายภาพ", null),
    "@gam ขอเข้าร่วม ชมรมถ่ายภาพ ของคุณ",
  );
  assertEquals(
    messageFor("club_join_approved", "@owner_user", "ชมรมถ่ายภาพ", null),
    "@owner_user อนุมัติคำขอเข้าร่วม ชมรมถ่ายภาพ ของคุณแล้ว",
  );
  assertEquals(
    messageFor("club_post_like", "@gam", "ชมรมถ่ายภาพ", null),
    "@gam ถูกใจโพสต์ของคุณใน ชมรมถ่ายภาพ",
  );
  assertEquals(
    messageFor("club_post_comment", "@gam", "ชมรมถ่ายภาพ", null),
    "@gam แสดงความคิดเห็นในโพสต์ของคุณใน ชมรมถ่ายภาพ",
  );
});

// Mirrors app/test/notification_list_screen_test.dart's "Order
// notification types (ZOKY-005 R1)" test and seller_app/test/
// seller_notification_list_screen_test.dart's equivalent, word for
// word.
Deno.test("messageFor produces the exact same Thai strings as the Dart clients, ZOKY-005 order types", () => {
  assertEquals(
    messageFor("new_order", "@buyer_user", null, "ร้านทดสอบ"),
    "@buyer_user สั่งซื้อสินค้าจาก ร้านทดสอบ",
  );
  assertEquals(
    messageFor("new_order", "@buyer_user", null, null),
    "@buyer_user สั่งซื้อสินค้าจาก ร้านของคุณ",
  );
  assertEquals(
    messageFor("order_shipped", "", null, "ร้านทดสอบ"),
    "คำสั่งซื้อของคุณจาก ร้านทดสอบ ถูกจัดส่งแล้ว",
  );
  // Buyer cancelled -> seller is the recipient -- seller_app's wording.
  assertEquals(
    messageFor("order_cancelled_seller", "ผู้ซื้อทดสอบ", null, null),
    "ผู้ซื้อทดสอบ ยกเลิกคำสั่งซื้อที่ร้านของคุณ",
  );
  // Seller cancelled -> buyer is the recipient -- app/'s wording.
  assertEquals(
    messageFor("order_cancelled_buyer", "", null, "ร้านทดสอบ"),
    "คำสั่งซื้อจากร้าน ร้านทดสอบ ถูกยกเลิก",
  );
  assertEquals(
    messageFor("order_refunded", "", null, "ร้านทดสอบ"),
    "คำสั่งซื้อของคุณจาก ร้านทดสอบ ถูกคืนเงินแล้ว",
  );
});

Deno.test("messageFor falls back to a generic message for an unrecognized type", () => {
  assertEquals(messageFor("something_new", "x", null, null), "คุณมีการแจ้งเตือนใหม่");
});

// Mirrors app/test/notification_list_screen_test.dart's WYN-021 mention
// assertions word for word (seller_app has no mention concept).
Deno.test("messageFor produces the exact same Thai strings as the Dart client, WYN-021 mention types", () => {
  assertEquals(messageFor("mention_drop", "@ploy", null, null), "@ploy กล่าวถึงคุณในโพสต์");
  assertEquals(
    messageFor("mention_club_post", "@ploy", "ชมรมถ่ายภาพ", null),
    "@ploy กล่าวถึงคุณในโพสต์ที่ ชมรมถ่ายภาพ",
  );
});

// Every field a real webhook payload row always carries (even when
// null) -- individual tests below only override what they need.
const baseRow: NotificationRow = {
  id: "n0",
  recipient_id: "r1",
  actor_id: "a1",
  type: "like_drop",
  drop_id: null,
  pop_id: null,
  club_id: null,
  club_post_id: null,
  order_id: null,
  reason: null,
  moderation_action_id: null,
  moderation_action_type: null,
  conversation_id: null,
};

// Mirrors app/test/notification_list_screen_test.dart's WYN-034/043
// redrop assertion word for word.
Deno.test("messageFor produces the exact same Thai string as the Dart client, WYN-034 redrop", () => {
  assertEquals(messageFor("redrop", "@ploy", null, null), "@ploy รีโพสต์โพสต์ของคุณ");
});

// Mirrors notification_list_screen.dart's WYN-029/030 moderation/appeal
// wording exactly -- see that file's own _messageFor for the source of
// truth these must never drift from.
Deno.test("messageFor produces the exact same Thai strings as the Dart client, WYN-029/030 moderation/appeal types", () => {
  assertEquals(
    messageFor("moderation_warning", "มีคน", null, null, "สแปม"),
    "คุณได้รับคำเตือนจากทีมงาน WYN: สแปม",
  );
  assertEquals(
    messageFor("moderation_content_removed", "มีคน", null, null, "เนื้อหาไม่เหมาะสม"),
    "เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- เหตุผล: เนื้อหาไม่เหมาะสม",
  );
  assertEquals(
    messageFor("appeal_approved", "มีคน", null, null, null, "warning"),
    "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว คำเตือนนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว",
  );
  assertEquals(
    messageFor("appeal_approved", "มีคน", null, null, null, "restrict"),
    "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว สิทธิ์การโพสต์ของคุณกลับมาใช้งานได้ตามปกติแล้ว",
  );
  assertEquals(
    messageFor("appeal_approved", "มีคน", null, null, null, "suspend"),
    "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว",
  );
  assertEquals(
    messageFor("appeal_approved", "มีคน", null, null, null, "ban"),
    "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว " +
      "คุณสามารถเข้าสู่ระบบได้ทันที",
  );
  assertEquals(
    messageFor("appeal_approved", "มีคน", null, null, null, "remove_content"),
    "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว",
  );
  assertEquals(
    messageFor("appeal_approved", "มีคน", null, null, null, null),
    "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว",
  );
  assertEquals(
    messageFor("appeal_rejected", "มีคน", null, null, "ไม่มีหลักฐานเพียงพอ"),
    "อุทธรณ์ของคุณถูกปฏิเสธ -- เหตุผล: ไม่มีหลักฐานเพียงพอ",
  );
});

// Mirrors notification_list_screen.dart's WYN-032/039 wording exactly.
Deno.test("messageFor produces the exact same Thai strings as the Dart client, WYN-032/039 message/follow-request types", () => {
  assertEquals(
    messageFor("message_request", "@ploy", null, null),
    "@ploy ส่งคำขอข้อความถึงคุณ",
  );
  assertEquals(messageFor("follow_request", "@gam", null, null), "@gam ขอติดตามคุณ");
  assertEquals(
    messageFor("follow_request_accepted", "@gam", null, null),
    "@gam ยอมรับคำขอติดตามของคุณแล้ว",
  );
});

// Mirrors notification_list_screen.dart's WYN-043 system-announcement
// wording exactly -- the admin's own message text, shown as-is.
Deno.test("messageFor produces the exact same Thai strings as the Dart client, WYN-043 system type", () => {
  assertEquals(
    messageFor("system", "มีคน", null, null, "แอปจะปิดปรับปรุงคืนนี้"),
    "แอปจะปิดปรับปรุงคืนนี้",
  );
  assertEquals(messageFor("system", "มีคน", null, null, null), "มีประกาศจากระบบ WYN");
});

Deno.test("buildDataPayload includes only the id columns that are actually set, plus type/actor_id always", () => {
  const row: NotificationRow = { ...baseRow, id: "n1", type: "like_drop", drop_id: "d1" };
  assertEquals(buildDataPayload(row), { type: "like_drop", actor_id: "a1", drop_id: "d1" });
});

Deno.test("buildDataPayload includes order_id when set, omits every drop/pop/club field", () => {
  const row: NotificationRow = { ...baseRow, id: "n2", type: "new_order", order_id: "o1" };
  assertEquals(buildDataPayload(row), { type: "new_order", actor_id: "a1", order_id: "o1" });
});

// WYN-029 fix: actor_id is null for these types -- must be omitted
// entirely, not sent as the literal string "null".
Deno.test("buildDataPayload omits actor_id when null", () => {
  const row: NotificationRow = {
    ...baseRow,
    id: "n3",
    actor_id: null,
    type: "moderation_warning",
    moderation_action_id: "ma1",
    reason: "สแปม",
  };
  assertEquals(buildDataPayload(row), {
    type: "moderation_warning",
    moderation_action_id: "ma1",
  });
});

Deno.test("buildDataPayload includes conversation_id when set (message_request)", () => {
  const row: NotificationRow = {
    ...baseRow,
    id: "n4",
    type: "message_request",
    conversation_id: "c1",
  };
  assertEquals(buildDataPayload(row), {
    type: "message_request",
    actor_id: "a1",
    conversation_id: "c1",
  });
});

Deno.test("base64Url produces URL-safe output with no padding", () => {
  // "hi" -> base64 "aGk=" -- standard base64 already has no +/ here, so
  // this mainly proves the padding strip.
  const encoded = base64Url(new TextEncoder().encode("hi"));
  assertEquals(encoded, "aGk");
});

// End-to-end signing correctness check: generate a throwaway RSA
// keypair (Web Crypto, same API the real function uses), export the
// private key as the PKCS8 PEM format a real Firebase service account
// JSON ships, run it through buildSignedJwtAssertion, then verify the
// signature with the matching public key. This is the strongest
// verification possible in this sandbox without a real Google service
// account -- it proves the RS256 signing implementation itself is
// correct, just not that a *real* Firebase project accepts it.
Deno.test("buildSignedJwtAssertion produces a JWT whose signature verifies against the matching public key", async () => {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );

  // importPrivateKey's PEM parser only strips whitespace/headers and
  // feeds the result to atob(), which requires *standard* base64 (+/
  // with padding) -- build the PEM with standard base64, not
  // base64Url (which is intentionally URL-safe/unpadded and would fail
  // atob()), so this test round-trips through the exact same parsing
  // path production PEM files go through.
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  const standardBase64 = btoa(String.fromCharCode(...new Uint8Array(pkcs8)));
  const standardPem = `-----BEGIN PRIVATE KEY-----\n${standardBase64}\n-----END PRIVATE KEY-----`;

  const serviceAccount: FcmServiceAccount = {
    client_email: "test@example-project.iam.gserviceaccount.com",
    private_key: standardPem,
    project_id: "example-project",
  };

  const nowSeconds = 1_700_000_000;
  const assertion = await buildSignedJwtAssertion(serviceAccount, nowSeconds);

  const parts = assertion.split(".");
  assertEquals(parts.length, 3);
  assertMatch(assertion, /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);

  const [headerB64, claimsB64, signatureB64] = parts;
  const decodeB64Url = (s: string) => {
    const padded = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
    return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
  };

  const header = JSON.parse(new TextDecoder().decode(decodeB64Url(headerB64)));
  assertEquals(header, { alg: "RS256", typ: "JWT" });

  const claims = JSON.parse(new TextDecoder().decode(decodeB64Url(claimsB64)));
  assertEquals(claims.iss, serviceAccount.client_email);
  assertEquals(claims.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assertEquals(claims.aud, "https://oauth2.googleapis.com/token");
  assertEquals(claims.iat, nowSeconds);
  assertEquals(claims.exp, nowSeconds + 3600);

  const signingInput = new TextEncoder().encode(`${headerB64}.${claimsB64}`);
  const verified = await crypto.subtle.verify(
    { name: "RSASSA-PKCS1-v1_5" },
    keyPair.publicKey,
    decodeB64Url(signatureB64),
    signingInput,
  );
  assertEquals(verified, true);

  // Also exercise importPrivateKey directly against the exact same PEM
  // string production code parses, independent of the JWT flow above.
  const importedKey = await importPrivateKey(standardPem);
  assertEquals(importedKey.type, "private");
  assertEquals(importedKey.usages, ["sign"]);
});
