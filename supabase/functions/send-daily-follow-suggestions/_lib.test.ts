// Regression: Social account suggestions must never be delivered to
// WYNOS Food or WYNOS Merchant installations (WYN-215 per-app routing).
import { assertEquals } from "jsr:@std/assert@1";
import { dailyFollowSocialTokenQuery } from "./_lib.ts";

Deno.test("daily suggestions select only Social web tokens and legacy NULL labels", () => {
  const query = dailyFollowSocialTokenQuery("account-123");
  const url = new URL(query, "https://example.invalid/rest/v1/");
  assertEquals(url.pathname, "/rest/v1/push_tokens");
  assertEquals(url.searchParams.get("user_id"), "eq.account-123");
  assertEquals(url.searchParams.get("platform"), "eq.web");
  assertEquals(url.searchParams.get("or"), "(app.eq.social,app.is.null)");
  assertEquals(url.searchParams.get("select"), "token");
});

Deno.test("daily suggestions escape user identifiers in PostgREST query", () => {
  const url = new URL(dailyFollowSocialTokenQuery("id&platform=eq.ios"), "https://example.invalid/rest/v1/");
  assertEquals(url.searchParams.get("user_id"), "eq.id&platform=eq.ios");
  assertEquals(url.searchParams.getAll("platform"), ["eq.web"]);
  assertEquals(url.searchParams.get("or"), "(app.eq.social,app.is.null)");
});
