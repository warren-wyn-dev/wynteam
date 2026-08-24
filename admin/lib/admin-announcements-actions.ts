"use client";

import { createClient } from "@/lib/supabase/client";
import type { AnnouncementAudience, AnnouncementCategory } from "@/lib/admin-announcements";

/** admin_send_announcement() (WYN-055) -- returns the actual recipient
 * count so the compose form can confirm what really happened, not just
 * that the call succeeded. */
export async function sendAnnouncement(params: {
  category: AnnouncementCategory;
  message: string;
  audience: AnnouncementAudience;
}): Promise<number> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_send_announcement", {
    p_category: params.category,
    p_message: params.message,
    p_audience: params.audience,
  });
  if (error) throw error;
  return data as number;
}
