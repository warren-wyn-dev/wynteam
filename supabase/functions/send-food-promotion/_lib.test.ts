import { assertEquals } from "jsr:@std/assert@1";
import { foodPromoPushPayload, foodPromoTokenQuery, isFoodPromoQuietTime } from "./_lib.ts";

Deno.test("Food promotions select only explicit Food web tokens", () => {
  const q = new URL(foodPromoTokenQuery("id&app=eq.social"), "https://example.invalid/");
  assertEquals(q.searchParams.get("user_id"), "eq.id&app=eq.social");
  assertEquals(q.searchParams.getAll("app"), ["eq.food"]);
  assertEquals(q.searchParams.get("platform"), "eq.web");
  assertEquals(q.searchParams.get("select"), "token");
});
Deno.test("Food promo carries isolated app identity and coupon click metadata", () => {
  const data = foodPromoPushPayload("campaign","delivery","Title","Body","FOOD50");
  assertEquals(data.app,"food");
  assertEquals(data.type,"food_promotion");
  assertEquals(data.coupon_code,"FOOD50");
});

Deno.test("Food marketing quiet hours suppress night messages in Thailand", () => {
  assertEquals(isFoodPromoQuietTime(new Date("2026-10-08T14:59:00Z")), false); // 21:59
  assertEquals(isFoodPromoQuietTime(new Date("2026-10-08T15:00:00Z")), true); // 22:00
  assertEquals(isFoodPromoQuietTime(new Date("2026-10-08T23:59:00Z")), true); // 06:59
  assertEquals(isFoodPromoQuietTime(new Date("2026-10-09T01:00:00Z")), false); // 08:00
});
