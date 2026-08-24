"use client";

import { createClient } from "@/lib/supabase/client";

/** Called from the Client Component ActionDialog (mirrors WYN-051's
 * admin-user-actions.ts) -- no cookies/redirect involved, so a plain
 * browser-client RPC call is enough. */
export async function removeDrop(params: { dropId: string; reason: string }): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_remove_drop", {
    p_drop_id: params.dropId,
    p_reason: params.reason,
  });
  if (error) throw error;
}

export async function restoreDrop(params: { dropId: string; reason: string }): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_restore_drop", {
    p_drop_id: params.dropId,
    p_reason: params.reason,
  });
  if (error) throw error;
}
