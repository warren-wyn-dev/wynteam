"use client";

import { createClient } from "@/lib/supabase/client";

/** Super admin only; the RPC re-checks. Same key = same change (safe to retry). */
export async function setGpRate(params: {
  storeId: string | null;
  rateBp: number;
  effectiveFrom: string | null;
  effectiveTo: string | null;
  reason: string;
  idempotencyKey: string;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_gp_rate", {
    p_store_id: params.storeId,
    p_rate_bp: params.rateBp,
    p_effective_from: params.effectiveFrom,
    p_effective_to: params.effectiveTo,
    p_reason: params.reason.trim(),
    p_idempotency_key: params.idempotencyKey,
  });
  if (error) throw error;
}

export async function cancelGpRate(params: { rateId: string; reason: string }): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_cancel_gp_rate", { p_rate_id: params.rateId, p_reason: params.reason.trim() });
  if (error) throw error;
}
