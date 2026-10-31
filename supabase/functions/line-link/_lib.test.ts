import { assertEquals } from "jsr:@std/assert@1";

import {
  addFriendUrl,
  corsHeaders,
  extraOrigins,
  lineFriendStatus,
  parseLinkRequest,
  verifiedLineUserId,
} from "./_lib.ts";

const USER = `U${"0123456789abcdef".repeat(2)}`;
const TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.c2ln";
const CHANNEL = "1234567890";
const NOW = 1_800_000_000_000;

function fakeFetch(status: number, body: unknown = {}) {
  const calls: { url: string; init?: RequestInit }[] = [];
  const fn = ((url: string, init?: RequestInit) => {
    calls.push({ url, init });
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as unknown as typeof fetch;
  return { calls, fn };
}

const claims = (overrides: Record<string, unknown> = {}) => ({
  iss: "https://access.line.me",
  aud: CHANNEL,
  sub: USER,
  exp: NOW / 1000 + 600,
  ...overrides,
});

Deno.test("request parsing accepts only known actions and audiences", () => {
  assertEquals(parseLinkRequest({ action: "status", audience: "food" }), { action: "status", audience: "food" });
  assertEquals(parseLinkRequest({ action: "unlink", audience: "merchant" }), { action: "unlink", audience: "merchant" });
  assertEquals(parseLinkRequest({ action: "link", audience: "food", idToken: TOKEN }), {
    action: "link", audience: "food", idToken: TOKEN,
  });
  assertEquals(parseLinkRequest({ action: "status", audience: "social" }), null);
  assertEquals(parseLinkRequest({ action: "drop", audience: "food" }), null);
  assertEquals(parseLinkRequest(null), null);
  assertEquals(parseLinkRequest("link"), null);
});

Deno.test("link needs a JWT-shaped, bounded ID token", () => {
  assertEquals(parseLinkRequest({ action: "link", audience: "food" }), null);
  assertEquals(parseLinkRequest({ action: "link", audience: "food", idToken: "not a jwt" }), null);
  assertEquals(parseLinkRequest({ action: "link", audience: "food", idToken: `${"a".repeat(4100)}.b.c` }), null);
});

Deno.test("a client-supplied LINE userId is ignored", () => {
  const parsed = parseLinkRequest({ action: "link", audience: "food", idToken: TOKEN, lineUserId: USER });
  assertEquals(parsed && "lineUserId" in parsed, false);
});

Deno.test("verification asks LINE with our channel id and returns sub", async () => {
  const { calls, fn } = fakeFetch(200, claims());
  assertEquals(await verifiedLineUserId(fn, TOKEN, CHANNEL, NOW), USER);
  assertEquals(calls[0].url, "https://api.line.me/oauth2/v2.1/verify");
  const form = new URLSearchParams(calls[0].init?.body as string);
  assertEquals(form.get("client_id"), CHANNEL);
  assertEquals(form.get("id_token"), TOKEN);
});

Deno.test("tokens LINE rejects, or for another channel, issuer or user format, are refused", async () => {
  assertEquals(await verifiedLineUserId(fakeFetch(400, { error: "invalid_request" }).fn, TOKEN, CHANNEL, NOW), null);
  assertEquals(await verifiedLineUserId(fakeFetch(200, claims({ aud: "999" })).fn, TOKEN, CHANNEL, NOW), null);
  assertEquals(await verifiedLineUserId(fakeFetch(200, claims({ iss: "https://evil.test" })).fn, TOKEN, CHANNEL, NOW), null);
  assertEquals(await verifiedLineUserId(fakeFetch(200, claims({ sub: "../../x" })).fn, TOKEN, CHANNEL, NOW), null);
  assertEquals(await verifiedLineUserId(fakeFetch(200, claims({ sub: undefined })).fn, TOKEN, CHANNEL, NOW), null);
});

Deno.test("expired tokens are refused even if LINE answers 200", async () => {
  assertEquals(await verifiedLineUserId(fakeFetch(200, claims({ exp: NOW / 1000 - 1 })).fn, TOKEN, CHANNEL, NOW), null);
  assertEquals(await verifiedLineUserId(fakeFetch(200, claims({ exp: "never" })).fn, TOKEN, CHANNEL, NOW), null);
});

Deno.test("network failure during verification never links", async () => {
  const fn = (() => Promise.reject(new Error("down"))) as unknown as typeof fetch;
  assertEquals(await verifiedLineUserId(fn, TOKEN, CHANNEL, NOW), null);
});

Deno.test("friend status follows the OA profile lookup", async () => {
  assertEquals(await lineFriendStatus(fakeFetch(200).fn, "t", USER), "friend");
  assertEquals(await lineFriendStatus(fakeFetch(404).fn, "t", USER), "not_friend");
  assertEquals(await lineFriendStatus(fakeFetch(500).fn, "t", USER), "unknown");
  const { calls, fn } = fakeFetch(200);
  assertEquals(await lineFriendStatus(fn, "t", "U/../../oauth"), "unknown");
  assertEquals(calls.length, 0);
});

Deno.test("add-friend link only from a valid basic id", () => {
  assertEquals(addFriendUrl("@352lvyoi"), "https://line.me/R/ti/p/%40352lvyoi");
  assertEquals(addFriendUrl("javascript:alert(1)"), null);
  assertEquals(addFriendUrl(undefined), null);
});

Deno.test("CORS allows ZOKY origins and configured staging origins only", () => {
  assertEquals(corsHeaders("https://food.wynos.online")["Access-Control-Allow-Origin"], "https://food.wynos.online");
  assertEquals(corsHeaders("https://merchant.wynos.online")["Access-Control-Allow-Origin"], "https://merchant.wynos.online");
  assertEquals(corsHeaders("https://evil.test")["Access-Control-Allow-Origin"], undefined);
  assertEquals(corsHeaders("https://food.wynos.online.evil.test")["Access-Control-Allow-Origin"], undefined);
  const extra = extraOrigins("https://web-abc-warren14.vercel.app, http://insecure.test, javascript:x");
  assertEquals(extra, ["https://web-abc-warren14.vercel.app"]);
  assertEquals(corsHeaders("https://web-abc-warren14.vercel.app", extra)["Access-Control-Allow-Origin"], "https://web-abc-warren14.vercel.app");
});
