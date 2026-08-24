"use client";

import { createClient } from "@/lib/supabase/client";

/** Called from Client Component Dialogs (WYN-051's action dialogs) --
 * no cookies/redirect involved, so a plain browser-client RPC call is
 * enough (unlike sign-in/sign-out, WYN-049, which need Server Actions
 * for the cookie mutations). */
export async function applyUserAction(params: {
  targetUserId: string;
  actionType: "warning" | "restrict" | "suspend" | "ban";
  reason: string;
  durationDays?: 1 | 3 | 7;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_apply_user_action", {
    p_target_user_id: params.targetUserId,
    p_action_type: params.actionType,
    p_reason: params.reason,
    p_duration_days: params.durationDays ?? null,
  });
  if (error) throw error;
}

export async function unbanUser(params: {
  targetUserId: string;
  reason: string;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_unban_user", {
    p_target_user_id: params.targetUserId,
    p_reason: params.reason,
  });
  if (error) throw error;
}
