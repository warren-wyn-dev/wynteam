"use client";

// Non-routed TEST FIXTURE. CI copies this to a disposable app route in its
// ephemeral runner workspace. Never deploy or use with live accounts.
import { MerchantFinanceQaPreview } from "@/components/merchant/merchant-finance-qa-preview";
import type { SupabaseClient } from "@supabase/supabase-js";

const STORE = "10000000-0000-4000-8000-000000000001";
const ORDER = "10000000-0000-4000-8000-000000000002";

declare global {
  interface Window { __qaFinanceRequests?: { method: string; args: Record<string, unknown> }[]; }
}
const fakeClient = {
  rpc: async (method: string, args: Record<string, unknown>) => {
    const requests = window.__qaFinanceRequests ?? (window.__qaFinanceRequests = []);
    requests.push({ method, args });
    if (new URLSearchParams(window.location.search).get("scenario") === "forbidden") {
      return { data: null, error: { message: "QA mock denied owner authorization" } };
    }
    if (method === "merchant_food_finance_buckets_v2_qa") {
      return {
        data: {
          mode: "simulation_only",
          currency: "thb",
          timezone: "Asia/Bangkok",
          granularity: args.p_granularity,
          selected_store_id: STORE,
          stripe_processing_fee_satang: null,
          stripe_fee_status: "unknown",
          merchant_net_payout_satang: null,
          merchant_payout_status: "not_reconciled",
          buckets: [{
            local_period_start: "2026-10-08",
            projection_count: 1,
            refund_event_count: 2,
            projected_customer_paid_satang: 5000,
            estimated_platform_gp_satang: 375,
            simulated_customer_refund_satang: 5000,
            simulated_gp_reversal_satang: 375,
            period_merchant_food_projection_less_reversals_satang: 0,
          }],
        },
        error: null,
      };
    }
    if (method === "merchant_food_finance_order_details_v2_qa") {
      return {
        data: args.p_order_id === ORDER ? {
          status: "projected",
          mode: "simulation_only",
          order_number: "QA-ORDER-0002",
          frozen_gp_rate_bps: 750,
          simulated_customer_refunded_satang: 5000,
          simulated_gp_reversal_satang: 375,
          refund_event_count: 2,
        } : { status: "not_projected", mode: "simulation_only" },
        error: null,
      };
    }
    return { data: null, error: { message: "Unknown mock method" } };
  },
} as unknown as SupabaseClient;

export default function FinanceQaCiFixture() {
  if (process.env.NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW !== "true") return null;
  return (
    <main style={{ maxWidth: 920, width: "100%", margin: "0 auto", padding: 16 }}>
      <MerchantFinanceQaPreview client={fakeClient} storeId={STORE} />
    </main>
  );
}
