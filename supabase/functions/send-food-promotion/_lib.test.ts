import { assertEquals } from "jsr:@std/assert@1";
import { foodPromoPushPayload, foodPromoTokenQuery } from "./_lib.ts";

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
