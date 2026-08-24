"use client";

import { createClient } from "@/lib/supabase/client";

/** apply_moderation_action() (WYN-029) -- the Report-driven action path,
 * called from the generic /reports/[id] detail page for every target
 * type WYN-051/052 don't already have a dedicated page for. */
export async function applyModerationAction(params: {
  reportId: string;
  actionType: "no_action" | "warning" | "remove_content" | "restrict" | "suspend" | "ban";
  reason: string;
  durationDays?: 1 | 3 | 7;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("apply_moderation_action", {
    p_report_id: params.reportId,
    p_action_type: params.actionType,
    p_reason: params.reason,
    p_duration_days: params.durationDays ?? null,
  });
  if (error) throw error;
}
