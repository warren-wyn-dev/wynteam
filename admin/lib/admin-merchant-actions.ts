"use client";

import { createClient } from "@/lib/supabase/client";

export async function reviewMerchantApplication(params: {
  applicationId: string;
  decision: "approved" | "rejected";
  reason?: string;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_review_merchant_application", {
    p_application_id: params.applicationId,
    p_decision: params.decision,
    p_reason: params.reason?.trim() || null,
  });

  if (error) throw error;
}
