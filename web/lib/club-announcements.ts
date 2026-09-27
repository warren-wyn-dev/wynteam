import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * WYN-137 (Beta2, developer-only until released): Club announcements.
 * Reads go through RLS (approved members only); every write is an RPC
 * that checks Club staff role and the Beta2 developer gate on the server
 * (supabase/migrations_web_beta2_club_announcements.sql).
 */
export const ANNOUNCEMENT_MAX_LENGTH = 2000;

export type ClubAnnouncement = {
  id: string;
  club_id: string;
  author_id: string;
  body: string;
  created_at: string;
  edited_at: string | null;
  author_username: string;
  author_display_name: string | null;
  author_avatar_url: string | null;
};

type AnnouncementRow = Omit<ClubAnnouncement, "author_username" | "author_display_name" | "author_avatar_url">;
type ProfileRow = { id: string; username: string; display_name: string | null; avatar_url: string | null };

/** Newest first. Throws on a read error so the tab can show a retry. */
export async function fetchClubAnnouncements(client: SupabaseClient, clubId: string): Promise<ClubAnnouncement[]> {
  const { data, error } = await client
    .from("club_announcements")
    .select("id, club_id, author_id, body, created_at, edited_at")
    .eq("club_id", clubId)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  const rows = (data ?? []) as AnnouncementRow[];
  const authorIds = [...new Set(rows.map((row) => row.author_id))];
  const profiles = new Map<string, ProfileRow>();
  if (authorIds.length) {
    const { data: people } = await client.from("profiles").select("id, username, display_name, avatar_url").in("id", authorIds);
    for (const person of (people ?? []) as ProfileRow[]) profiles.set(person.id, person);
  }
  return rows.map((row) => {
    const author = profiles.get(row.author_id);
    return {
      ...row,
      author_username: author?.username ?? "",
      author_display_name: author?.display_name ?? null,
      author_avatar_url: author?.avatar_url ?? null,
    };
  });
}

export async function createClubAnnouncement(client: SupabaseClient, clubId: string, body: string): Promise<string> {
  const { data, error } = await client.rpc("create_club_announcement", { p_club_id: clubId, p_body: body });
  if (error) throw error;
  return data as string;
}

export async function updateClubAnnouncement(client: SupabaseClient, announcementId: string, body: string): Promise<void> {
  const { error } = await client.rpc("update_club_announcement", { p_announcement_id: announcementId, p_body: body });
  if (error) throw error;
}

export async function deleteClubAnnouncement(client: SupabaseClient, announcementId: string): Promise<void> {
  const { error } = await client.rpc("delete_club_announcement", { p_announcement_id: announcementId });
  if (error) throw error;
}

/** Mirrors the server rules, only to decide which buttons to show. */
export function announcementPermissions(role: string | null | undefined, userId: string, authorId: string) {
  const staff = role === "owner" || role === "admin" || role === "moderator";
  const own = userId === authorId;
  return {
    canEdit: own && staff,
    canDelete: own || role === "owner" || role === "admin",
  };
}

export function canPostAnnouncement(role: string | null | undefined): boolean {
  return role === "owner" || role === "admin" || role === "moderator";
}
