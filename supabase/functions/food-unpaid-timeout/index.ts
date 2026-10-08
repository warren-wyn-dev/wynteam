import { createClient } from "npm:@supabase/supabase-js@2.112.3";

// Invoked once per minute by pg_cron through pg_net, never by a browser.
// The vault-backed request key is verified against a service-role-only RPC.
// Stripe Checkout is expired BEFORE the order is marked cancelled.
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json" },
  });
}
function serviceKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;
  try {
    const keys = JSON.parse(raw) as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch { return null; }
}
function stripeLivemode(secret: string) {
  if (/^(?:sk|rk)_live_/.test(secret)) return true;
  if (/^(?:sk|rk)_test_/.test(secret)) return false;
  return null;
}
async function stripeSession(
  secret: string, accountId: string, sessionId: string, expire = false,
) {
  const response = await fetch(
    `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}${expire ? "/expire" : ""}`,
    {
      method: expire ? "POST" : "GET",
      headers: {
        Authorization: `Basic ${btoa(secret + ":")}`,
        "Stripe-Account": accountId,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      signal: AbortSignal.timeout(7500),
    },
  );
  if (!response.ok) throw new Error(`Stripe session request failed (${response.status})`);
  return await response.json() as { id?: string; status?: string; payment_status?: string };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const dbUrl = Deno.env.get("SUPABASE_URL");
  const dbKey = serviceKey();
  const token = req.headers.get("x-wynos-cron-key");
  if (!dbUrl || !dbKey || !token) return json({ error: "unauthorized" }, 401);

  const admin = createClient(dbUrl, dbKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const check = await admin.rpc("food_timeout_cron_authorized", { p_token: token });
  if (check.error || check.data !== true) return json({ error: "unauthorized" }, 401);

  const now = new Date().toISOString();
  const { data: orders, error } = await admin.from("food_orders")
    .select("id,store_id,stripe_checkout_session_id,payment_due_at")
    .eq("source", "app")
    .eq("status", "pending_acceptance")
    .in("payment_status", ["pending", "issue"])
    .not("payment_due_at", "is", null)
    .lte("payment_due_at", now)
    .order("payment_due_at", { ascending: true })
    .limit(60);
  if (error) return json({ error: "orders_query_failed" }, 500);

  const secret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  const secretMode = stripeLivemode(secret);
  let cancelled = 0;
  let deferred = 0;
  for (const order of orders ?? []) {
    const sessionId = order.stripe_checkout_session_id as string | null;
    if (sessionId) {
      // Fail closed if the Stripe configuration is missing: never cancel a
      // pending order while its payment link may still be payable.
      if (!secret || secretMode == null) { deferred++; continue; }
      const { data: payment } = await admin.from("food_stripe_payments")
        .select("stripe_account_id,livemode,status")
        .eq("order_id", order.id).eq("checkout_session_id", sessionId)
        .maybeSingle();
      if (!payment || !payment.stripe_account_id ||
          payment.livemode !== secretMode || payment.status === "paid") {
        deferred++;
        continue;
      }

      try {
        let session = await stripeSession(secret, payment.stripe_account_id, sessionId);
        if (session.payment_status === "paid" || session.status === "complete") {
          // Stripe may have processed payment before its webhook reaches us.
          deferred++;
          continue;
        }
        if (session.status === "open") {
          try {
            session = await stripeSession(secret, payment.stripe_account_id, sessionId, true);
          } catch {
            // It may have completed while we were expiring it. Retry next tick.
            deferred++;
            continue;
          }
        }
        if (session.status !== "expired" || session.payment_status === "paid") {
          deferred++;
          continue;
        }
      } catch {
        deferred++;
        continue;
      }
    }

    // Locks the order and rechecks all payment, deadline, and session fields.
    const { data: didCancel, error: cancelError } = await admin.rpc("food_timeout_cancel", {
      p_order_id: order.id, p_expected_session_id: sessionId,
    });
    if (cancelError) { deferred++; continue; }
    if (didCancel === true) {
      cancelled++;
      if (sessionId) {
        await admin.from("food_stripe_payments").update({
          status: "failed",
          last_error: "10-minute payment deadline elapsed; Checkout expired",
          updated_at: new Date().toISOString(),
        }).eq("order_id", order.id).eq("checkout_session_id", sessionId)
          .eq("status", "pending");
      }
    }
  }
  return json({ scanned: (orders ?? []).length, cancelled, deferred });
});
