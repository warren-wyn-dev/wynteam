"use client";

import { createClient } from "@/lib/supabase/client";
import type { InactiveDays } from "@/lib/admin-inactive-reminder-options";

/** admin_count_inactive_users(): how many people a reminder would reach now. */
export async function countInactiveUsers(days: InactiveDays): Promise<number> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_count_inactive_users", { p_inactive_days: days });
  if (error) throw error;
  return data as number;
}

/** admin_send_inactive_reminder(): in-app + Push; returns how many it reached. */
export async function sendInactiveReminder(params: { days: InactiveDays; message: string }): Promise<number> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_send_inactive_reminder", {
    p_inactive_days: params.days,
    p_message: params.message,
  });
  if (error) throw error;
  return data as number;
}
