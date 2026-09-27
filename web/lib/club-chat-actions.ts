import type { SupabaseClient } from "@supabase/supabase-js";

/** WYN-135: UI is developer-only until the Founder releases clubChatActions. */
export const CLUB_CHAT_SEARCH_LIMIT = 30;
export const CLUB_CHAT_PIN_LIMIT = 3;

export type ClubChatSearchHit = {
  id: string;
  content: string;
  author_id: string;
  created_at: string;
};

export type ClubChatPin = {
  id: string;
  content: string | null;
  pinned_at: string;
};

export function isClubStaff(role: string | null | undefined, approved: boolean): boolean {
  return approved && ["owner", "admin", "moderator"].includes(role ?? "");
}

export function cleanClubChatSearch(raw: string): string {
  return raw.trim().replace(/\s+/g, " ").slice(0, 120);
}

export async function searchClubChat(
  client: SupabaseClient,
  channelId: string,
  rawQuery: string,
): Promise<ClubChatSearchHit[]> {
  const query = cleanClubChatSearch(rawQuery);
  if (!channelId || !query) return [];
  const { data, error } = await client.rpc("search_club_channel_messages", {
    p_channel_id: channelId, p_query: query, p_limit: CLUB_CHAT_SEARCH_LIMIT,
  });
  if (error) throw error;
  return (Array.isArray(data) ? data : []).map((row: Record<string, unknown>) => ({
    id: String(row.id),
    content: String(row.content ?? ""),
    author_id: String(row.author_id),
    created_at: String(row.created_at),
  }));
}

export async function fetchPinnedClubChat(
  client: SupabaseClient,
  channelId: string,
): Promise<ClubChatPin[]> {
  if (!channelId) return [];
  const { data, error } = await client.from("club_channel_messages")
    .select("id,content,pinned_at")
    .eq("channel_id", channelId)
    .not("pinned_at", "is", null)
    .order("pinned_at", { ascending: false })
    .limit(CLUB_CHAT_PIN_LIMIT);
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: String(row.id),
    content: row.content ? String(row.content) : null,
    pinned_at: String(row.pinned_at),
  }));
}

export async function editClubChatMessage(
  client: SupabaseClient, messageId: string, text: string,
): Promise<void> {
  const body = text.trim();
  if (!body || body.length > 2000) throw new Error("Message must be 1–2000 characters");
  const { error } = await client.rpc("edit_club_channel_message", {
    p_message_id: messageId, p_content: body,
  });
  if (error) throw error;
}

export async function setClubChatPin(
  client: SupabaseClient, messageId: string, pin: boolean,
): Promise<void> {
  const { error } = await client.rpc("set_club_channel_message_pin", {
    p_message_id: messageId, p_pin: pin,
  });
  if (error) throw error;
}
