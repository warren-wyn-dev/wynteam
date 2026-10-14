/** Native Stripe PaymentSheet test-mode guard. No live transactions. */
export function stagingStripeEnvironment(
  supabaseUrl: string | undefined,
  secretKey: string | undefined,
  publishableKey: string | undefined,
  enabled: string | undefined,
): { ok: true } | { ok: false; error: string } {
  if (enabled !== "true") return { ok: false, error: "mobile_payment_disabled" };
  if (!supabaseUrl || !/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(supabaseUrl) ||
      supabaseUrl === "https://kqokpocajhfbidcxpvhh.supabase.co") {
    return { ok: false, error: "isolated_staging_required" };
  }
  if (!secretKey || !/^(sk|rk)_test_/.test(secretKey) ||
      !publishableKey || !/^pk_test_/.test(publishableKey)) {
    return { ok: false, error: "stripe_test_keys_required" };
  }
  return { ok: true };
}

export function satangFromServerTotal(raw: unknown): number | null {
  const value = typeof raw === "number" || typeof raw === "string" ? Number(raw) : NaN;
  // Prevent fractional-satang pricing and unbounded charge requests.
  if (!Number.isFinite(value) || value <= 0 || value > 1000000) return null;
  const result = Math.round(value * 100);
  if (!Number.isSafeInteger(result) || Math.abs(result / 100 - value) > 0.000001) return null;
  return result;
}

export function payableStagingOrder(order: {
  status?: string | null;
  payment_status?: string | null;
  payment_due_at?: string | null;
  payment_slip_path?: string | null;
}, nowMs = Date.now()): string | null {
  if (order.status !== "pending_acceptance" ||
      !["pending", "issue"].includes(order.payment_status ?? "")) return "order_not_payable";
  if (order.payment_slip_path) return "payment_method_conflict";
  if (order.payment_due_at && (!Number.isFinite(Date.parse(order.payment_due_at)) ||
      Date.parse(order.payment_due_at) <= nowMs)) return "payment_deadline_expired";
  return null;
}
