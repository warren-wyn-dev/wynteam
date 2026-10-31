import { assertEquals } from "jsr:@std/assert@1";

import { lineConfigFor, lineDestination, lineMessagesFor, sendLinePush } from "./_line.ts";

const env = (values: Record<string, string>) => (name: string) => values[name];
const enabled = {
  LINE_NOTIFICATIONS_ENABLED: "1",
  LINE_FOOD_CHANNEL_ACCESS_TOKEN: "food-token",
  LINE_FOOD_LIFF_ID: "1234567890-AbCdEfGh",
  LINE_MERCHANT_CHANNEL_ACCESS_TOKEN: "merchant-token",
};
const USER = `U${"a".repeat(32)}`;
const NOTIFICATION = "11111111-2222-4333-8444-555555555555";

Deno.test("LINE is never used for Social notifications", () => {
  assertEquals(lineConfigFor("social", env(enabled)), null);
});

Deno.test("LINE stays off until the feature flag and the OA token are set", () => {
  assertEquals(lineConfigFor("food", env({ ...enabled, LINE_NOTIFICATIONS_ENABLED: "" })), null);
  assertEquals(lineConfigFor("food", env({ LINE_NOTIFICATIONS_ENABLED: "1" })), null);
  assertEquals(lineConfigFor("merchant", env({ ...enabled, LINE_MERCHANT_CHANNEL_ACCESS_TOKEN: "  " })), null);
});

Deno.test("each audience uses its own OA token", () => {
  assertEquals(lineConfigFor("food", env(enabled))?.accessToken, "food-token");
  assertEquals(lineConfigFor("merchant", env(enabled))?.accessToken, "merchant-token");
});

Deno.test("a malformed LIFF id falls back to the web origin", () => {
  const config = lineConfigFor("food", env({ ...enabled, LINE_FOOD_LIFF_ID: "https://evil.test" }))!;
  assertEquals(config.liffId, null);
  assertEquals(lineDestination(config, "WF0015"), "https://food.wynos.online/food?order=WF0015");
});

Deno.test("the button opens the order through LIFF, same path as Web Push", () => {
  const food = lineConfigFor("food", env(enabled))!;
  assertEquals(
    lineDestination(food, "WF0015"),
    "https://liff.line.me/1234567890-AbCdEfGh?to=%2Ffood%3Forder%3DWF0015",
  );
  const merchant = lineConfigFor("merchant", env(enabled))!;
  assertEquals(lineDestination(merchant, "WF123456"), "https://merchant.wynos.online/merchant?order=WF123456");
});

Deno.test("only well-formed order numbers reach the URL", () => {
  const merchant = lineConfigFor("merchant", env(enabled))!;
  assertEquals(lineDestination(merchant, "WF1&x=https://evil"), "https://merchant.wynos.online/merchant");
  assertEquals(lineDestination(merchant, null), "https://merchant.wynos.online/merchant");
});

Deno.test("message text uses the event, not the generic app title, within LINE limits", () => {
  const [food] = lineMessagesFor("Wynos Food", "ออเดอร์ #WF0015 กำลังจัดส่ง", "https://x.test", "th") as {
    altText: string; template: { text: string; actions: { label: string }[] };
  }[];
  assertEquals(food.template.text, "ออเดอร์ #WF0015 กำลังจัดส่ง");
  assertEquals(food.template.actions[0].label, "เปิดดู");

  const [merchant] = lineMessagesFor("ออเดอร์ใหม่ #WF0016", "", "https://x.test", "en") as {
    template: { text: string; actions: { label: string }[] };
  }[];
  assertEquals(merchant.template.text, "ออเดอร์ใหม่ #WF0016");
  assertEquals(merchant.template.actions[0].label, "Open");

  const [long] = lineMessagesFor("", "ก".repeat(500), "https://x.test", "th") as {
    altText: string; template: { text: string };
  }[];
  assertEquals(Array.from(long.template.text).length, 160);
  assertEquals(Array.from(long.altText).length, 400);
});

function recordingFetch(status: number | Error) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fn = ((url: string, init: RequestInit) => {
    calls.push({ url, init });
    if (status instanceof Error) return Promise.reject(status);
    return Promise.resolve(new Response("{}", { status }));
  }) as unknown as typeof fetch;
  return { calls, fn };
}

Deno.test("push uses the OA token and the notification id as retry key", async () => {
  const config = lineConfigFor("merchant", env(enabled))!;
  const { calls, fn } = recordingFetch(200);
  assertEquals(await sendLinePush(fn, config, USER, [{ type: "text", text: "x" }], NOTIFICATION), "line_sent");
  assertEquals(calls[0].url, "https://api.line.me/v2/bot/message/push");
  const headers = calls[0].init.headers as Record<string, string>;
  assertEquals(headers.Authorization, "Bearer merchant-token");
  assertEquals(headers["X-Line-Retry-Key"], NOTIFICATION);
  assertEquals(JSON.parse(calls[0].init.body as string).to, USER);
});

Deno.test("a webhook redelivery (409 duplicate retry key) counts as sent", async () => {
  const config = lineConfigFor("food", env(enabled))!;
  assertEquals(await sendLinePush(recordingFetch(409).fn, config, USER, [], NOTIFICATION), "line_sent");
});

Deno.test("quota, rate limit and network errors are reported, never thrown", async () => {
  const config = lineConfigFor("food", env(enabled))!;
  assertEquals(await sendLinePush(recordingFetch(429).fn, config, USER, [], NOTIFICATION), "line_failed_429");
  assertEquals(await sendLinePush(recordingFetch(500).fn, config, USER, [], NOTIFICATION), "line_failed_500");
  assertEquals(await sendLinePush(recordingFetch(new Error("down")).fn, config, USER, [], NOTIFICATION), "line_error");
});

Deno.test("a non-UUID id is never sent as LINE retry key", async () => {
  const config = lineConfigFor("food", env(enabled))!;
  const { calls, fn } = recordingFetch(200);
  await sendLinePush(fn, config, USER, [], "not-a-uuid");
  assertEquals("X-Line-Retry-Key" in (calls[0].init.headers as Record<string, string>), false);
});
