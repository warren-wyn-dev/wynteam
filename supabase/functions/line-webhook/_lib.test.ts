import { assertEquals } from "jsr:@std/assert@1";

import { audienceFromUrl, friendUpdates, isValidLineSignature } from "./_lib.ts";

const SECRET = "synthetic-channel-secret";
const A = `U${"a".repeat(32)}`;
const B = `U${"b".repeat(32)}`;

async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  return btoa(String.fromCharCode(...mac));
}

Deno.test("OA is chosen only from a known ?oa value", () => {
  assertEquals(audienceFromUrl("https://x.supabase.co/functions/v1/line-webhook?oa=food"), "food");
  assertEquals(audienceFromUrl("https://x.supabase.co/functions/v1/line-webhook?oa=merchant"), "merchant");
  assertEquals(audienceFromUrl("https://x.supabase.co/functions/v1/line-webhook?oa=social"), null);
  assertEquals(audienceFromUrl("https://x.supabase.co/functions/v1/line-webhook"), null);
});

Deno.test("a correctly signed body is accepted", async () => {
  const body = JSON.stringify({ events: [] });
  assertEquals(await isValidLineSignature(SECRET, body, await sign(SECRET, body)), true);
});

Deno.test("wrong secret, tampered body, missing header or missing secret are rejected", async () => {
  const body = JSON.stringify({ events: [{ type: "unfollow", source: { type: "user", userId: A } }] });
  const signature = await sign(SECRET, body);
  assertEquals(await isValidLineSignature("other-secret", body, signature), false);
  assertEquals(await isValidLineSignature(SECRET, body.replace("unfollow", "follow"), signature), false);
  assertEquals(await isValidLineSignature(SECRET, body, null), false);
  assertEquals(await isValidLineSignature("", body, signature), false);
  assertEquals(await isValidLineSignature(SECRET, body, signature.slice(0, -2)), false);
});

Deno.test("follow/unfollow become friend states; the latest event per user wins", () => {
  assertEquals(friendUpdates({
    events: [
      { type: "follow", source: { type: "user", userId: A } },
      { type: "unfollow", source: { type: "user", userId: B } },
      { type: "unfollow", source: { type: "user", userId: A } },
    ],
  }), [
    { lineUserId: A, friendStatus: "not_friend" },
    { lineUserId: B, friendStatus: "not_friend" },
  ]);
});

Deno.test("other events, groups and malformed users are ignored", () => {
  assertEquals(friendUpdates({
    events: [
      { type: "message", source: { type: "user", userId: A } },
      { type: "follow", source: { type: "group", userId: A } },
      { type: "follow", source: { type: "user", userId: "U'; drop table" } },
      null,
    ],
  }), []);
  assertEquals(friendUpdates({}), []);
  assertEquals(friendUpdates(null), []);
});
