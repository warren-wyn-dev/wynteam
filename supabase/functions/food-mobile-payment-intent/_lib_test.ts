import { assertEquals } from "jsr:@std/assert@1";
import {
  payableStagingOrder,
  satangFromServerTotal,
  stagingStripeEnvironment,
} from "./_lib.ts";

Deno.test("mobile payment endpoint fails closed outside explicit isolated test Stripe", () => {
  const safe = {
    url: "https://pcatuxtenluqzjzzwsvl.supabase.co",
    secret: "sk_test_dummy",
    publish: "pk_test_dummy",
  };
  assertEquals(stagingStripeEnvironment(safe.url, safe.secret, safe.publish, "true"), { ok: true });
  assertEquals(stagingStripeEnvironment(safe.url, safe.secret, safe.publish, undefined).ok, false);
  assertEquals(stagingStripeEnvironment("https://kqokpocajhfbidcxpvhh.supabase.co", safe.secret, safe.publish, "true").ok, false);
  assertEquals(stagingStripeEnvironment(safe.url, "sk_live_dummy", safe.publish, "true").ok, false);
  assertEquals(stagingStripeEnvironment(safe.url, safe.secret, "pk_live_dummy", "true").ok, false);
  assertEquals(stagingStripeEnvironment("https://food.wynos.online", safe.secret, safe.publish, "true").ok, false);
  assertEquals(stagingStripeEnvironment("https://example.supabase.co", safe.secret, safe.publish, "true").ok, false);
});

Deno.test("amount comes only from server total, in satang", () => {
  assertEquals(satangFromServerTotal("120.50"), 12050);
  assertEquals(satangFromServerTotal(1), 100);
  assertEquals(satangFromServerTotal(0), null);
  assertEquals(satangFromServerTotal("-1"), null);
  assertEquals(satangFromServerTotal("NaN"), null);
  assertEquals(satangFromServerTotal("1.001"), null);
  assertEquals(satangFromServerTotal(1_000_001), null);
  assertEquals(satangFromServerTotal({ total: "100" }), null);
});

Deno.test("payable food staging order restricts late, accepted, refunded or slip transactions", () => {
  const now = Date.parse("2026-10-14T08:00:00Z");
  const good = {
    status: "pending_acceptance",
    payment_status: "pending",
    payment_due_at: "2026-10-14T08:10:00Z",
    payment_slip_path: null,
  };
  assertEquals(payableStagingOrder(good, now), null);
  assertEquals(payableStagingOrder({ ...good, status: "cancelled" }, now), "order_not_payable");
  assertEquals(payableStagingOrder({ ...good, payment_status: "paid" }, now), "order_not_payable");
  assertEquals(payableStagingOrder({ ...good, payment_due_at: "2026-10-14T07:59:59Z" }, now), "payment_deadline_expired");
  assertEquals(payableStagingOrder({ ...good, payment_slip_path: "private/file.png" }, now), "payment_method_conflict");
});
