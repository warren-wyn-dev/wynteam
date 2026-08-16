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
  assertEquals(messageFor("like_drop", "น้ำฝน", null, null), "น้ำฝน ถูกใจ Drop ของคุณ");
  assertEquals(messageFor("like_pop", "@ploy", null, null), "@ploy ถูกใจ Pop ของคุณ");
  assertEquals(
    messageFor("comment_drop", "น้ำฝน", null, null),
    "น้ำฝน แสดงความคิดเห็นใน Drop ของคุณ",
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

Deno.test("buildDataPayload includes only the id columns that are actually set, plus type/actor_id always", () => {
  const row: NotificationRow = {
    id: "n1",
    recipient_id: "r1",
    actor_id: "a1",
    type: "like_drop",
    drop_id: "d1",
    pop_id: null,
    club_id: null,
    club_post_id: null,
    order_id: null,
  };
  assertEquals(buildDataPayload(row), { type: "like_drop", actor_id: "a1", drop_id: "d1" });
});

Deno.test("buildDataPayload includes order_id when set, omits every drop/pop/club field", () => {
  const row: NotificationRow = {
    id: "n2",
    recipient_id: "r1",
    actor_id: "a1",
    type: "new_order",
    drop_id: null,
    pop_id: null,
    club_id: null,
    club_post_id: null,
    order_id: "o1",
  };
  assertEquals(buildDataPayload(row), { type: "new_order", actor_id: "a1", order_id: "o1" });
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
