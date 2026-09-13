import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import type { HomeFeedRow } from "@/lib/feed";

export type ProfileRow = {
  id: string;
  username: string;
  display_name?: string | null;
  bio?: string | null;
  avatar_url?: string | null;
  cover_url?: string | null;
  social_links?: Record<string, string> | null;
  platform_role?: string | null;
  is_private: boolean;
  is_verified: boolean;
  dm_permission: string;
  mention_permission: string;
  comment_permission: string;
  likes_visibility: string;
};

export type ProfileSummary = {
  profile: ProfileRow;
  followerCount: number;
  followingCount: number;
  following: boolean;
  requested: boolean;
  blocked: boolean;
  blockedBy: boolean;
  muted: boolean;
};

export type ClubRow = {
  id: string;
  name: string;
  description?: string | null;
  category?: string | null;
  privacy?: string | null;
  cover_url?: string | null;
  icon_url?: string | null;
  created_at: string;
  member_count: number;
};

export type RankedHashtag = {
  tag: string;
  score: number;
  postCount: number;
};

export type NotificationRow = {
  id: string;
  type: string;
  actor_id?: string | null;
  actor_username?: string | null;
  actor_display_name?: string | null;
  actor_avatar_url?: string | null;
  drop_id?: string | null;
  pop_id?: string | null;
  club_id?: string | null;
  club_name?: string | null;
  club_post_id?: string | null;
  reason?: string | null;
  moderation_action_id?: string | null;
  moderation_action_type?: string | null;
  conversation_id?: string | null;
  content_preview?: string | null;
  is_read: boolean;
  created_at: string;
};

export type ConversationRow = {
  conversation_id: string;
  status: string;
  requested_by?: string | null;
  conversation_created_at: string;
  other_user_id: string;
  other_username: string;
  other_display_name?: string | null;
  other_avatar_url?: string | null;
  last_message_text?: string | null;
  last_message_image_url?: string | null;
  last_message_deleted_at?: string | null;
  last_message_at?: string | null;
  last_message_sender_id?: string | null;
  my_last_read_at?: string | null;
};

export type MessageRequestRow = ConversationRow;

export type MessageRow = {
  id: string;
  conversation_id: string;
  sender_id: string;
  text?: string | null;
  image_url?: string | null;
  reply_to_message_id?: string | null;
  shared_content_type?: string | null;
  shared_content_id?: string | null;
  deleted_at?: string | null;
  created_at: string;
  view_once?: boolean | null;
  viewed_at?: string | null;
  edited_at?: string | null;
  reply_to?: {
    text?: string | null;
    image_url?: string | null;
    deleted_at?: string | null;
  } | null;
};

export type ConversationMeta = {
  status: string;
  requested_by?: string | null;
  other_user_last_read_at?: string | null;
};

export type NotificationSettings = {
  likes: boolean;
  comments: boolean;
  follows: boolean;
  messages: boolean;
  club: boolean;
  trending: boolean;
  system: boolean;
};

export type LegalDocument = {
  type: string;
  version: number;
  title: string;
  content: string;
  effective_at: string;
};

const dropCardSelect =
  "id,author_id,caption,image_url,image_width,image_height,created_at," +
  "author:profiles!drops_author_id_fkey(username,display_name,avatar_url,is_verified)," +
  "drop_likes(count),drop_comments(count),redrops(count),drop_images(count)";

const messageColumns =
  "id,conversation_id,sender_id,text,image_url,reply_to_message_id," +
  "shared_content_type,shared_content_id,deleted_at,created_at,view_once,viewed_at,edited_at," +
  "reply_to:messages!reply_to_message_id(text,image_url,deleted_at)";

const defaultNotificationSettings: NotificationSettings = {
  likes: true,
  comments: true,
  follows: true,
  messages: true,
  club: true,
  trending: true,
  system: true,
};

function fail(error: { message?: string } | null | undefined, fallback = "เกิดข้อผิดพลาด") {
  if (error) throw new Error(error.message || fallback);
}

function relation(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) {
    const first = value[0];
    return first && typeof first === "object" ? (first as Record<string, unknown>) : {};
  }
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function firstCount(value: unknown): number {
  if (!Array.isArray(value) || value.length === 0) return 0;
  const row = value[0];
  if (!row || typeof row !== "object") return 0;
  return Number((row as { count?: unknown }).count ?? 0) || 0;
}

function asProfile(row: Record<string, unknown>): ProfileRow {
  return {
    id: String(row.id ?? ""),
    username: String(row.username ?? ""),
    display_name: row.display_name == null ? null : String(row.display_name),
    bio: row.bio == null ? null : String(row.bio),
    avatar_url: row.avatar_url == null ? null : String(row.avatar_url),
    cover_url: row.cover_url == null ? null : String(row.cover_url),
    social_links:
      row.social_links && typeof row.social_links === "object"
        ? (row.social_links as Record<string, string>)
        : null,
    platform_role: row.platform_role == null ? null : String(row.platform_role),
    is_private: row.is_private === true,
    is_verified: row.is_verified === true,
    dm_permission: String(row.dm_permission ?? "everyone"),
    mention_permission: String(row.mention_permission ?? "everyone"),
    comment_permission: String(row.comment_permission ?? "everyone"),
    likes_visibility: String(row.likes_visibility ?? "everyone"),
  };
}

function asDrop(row: Record<string, unknown>): HomeFeedRow {
  const author = relation(row.author);
  return {
    id: String(row.id ?? ""),
    content_type: "drop",
    author_id: String(row.author_id ?? ""),
    author_username: String(author.username ?? ""),
    author_display_name: author.display_name == null ? null : String(author.display_name),
    author_avatar_url: author.avatar_url == null ? null : String(author.avatar_url),
    author_is_verified: author.is_verified === true,
    created_at: String(row.created_at ?? ""),
    caption: row.caption == null ? null : String(row.caption),
    image_url: row.image_url == null ? null : String(row.image_url),
    image_width: row.image_width == null ? null : Number(row.image_width),
    image_height: row.image_height == null ? null : Number(row.image_height),
    image_count: firstCount(row.drop_images),
    like_count: firstCount(row.drop_likes),
    comment_count: firstCount(row.drop_comments),
    redrop_count: firstCount(row.redrops),
  };
}

function safeOrPattern(query: string): string {
  const escaped = `%${query}%`.replace(/\\/g, "\\\\").replace(/\"/g, '\\"');
  return `\"${escaped}\"`;
}

export function profileLabel(profile: Pick<ProfileRow, "username" | "display_name">): string {
  return profile.display_name?.trim() || profile.username || "WYNOS";
}

export async function fetchProfile(client: SupabaseClient, userId: string): Promise<ProfileRow | null> {
  const result = await client
    .from("profiles")
    .select(
      "id,username,display_name,bio,avatar_url,cover_url,social_links,platform_role,is_private,is_verified,dm_permission,mention_permission,comment_permission,likes_visibility",
    )
    .eq("id", userId)
    .maybeSingle();
  fail(result.error, "โหลดโปรไฟล์ไม่สำเร็จ");
  return result.data ? asProfile(result.data as Record<string, unknown>) : null;
}

export async function fetchProfileByUsername(
  client: SupabaseClient,
  username: string,
): Promise<ProfileRow | null> {
  const result = await client
    .from("profiles")
    .select(
      "id,username,display_name,bio,avatar_url,cover_url,social_links,platform_role,is_private,is_verified,dm_permission,mention_permission,comment_permission,likes_visibility",
    )
    .eq("username", username)
    .maybeSingle();
  fail(result.error, "โหลดโปรไฟล์ไม่สำเร็จ");
  return result.data ? asProfile(result.data as Record<string, unknown>) : null;
}

export async function fetchProfileSummary(
  client: SupabaseClient,
  viewerId: string,
  userId: string,
): Promise<ProfileSummary | null> {
  const profile = await fetchProfile(client, userId);
  if (!profile) return null;

  const followerCountPromise = client.rpc("follower_count", { p_user_id: userId });
  const followingCountPromise = client.rpc("following_count", { p_user_id: userId });
  if (viewerId === userId) {
    const [followers, following] = await Promise.all([followerCountPromise, followingCountPromise]);
    fail(followers.error);
    fail(following.error);
    return {
      profile,
      followerCount: Number(followers.data ?? 0),
      followingCount: Number(following.data ?? 0),
      following: false,
      requested: false,
      blocked: false,
      blockedBy: false,
      muted: false,
    };
  }

  const [followers, following, followRow, requestRow, relationship, muteRow] = await Promise.all([
    followerCountPromise,
    followingCountPromise,
    client
      .from("follows")
      .select("following_id")
      .eq("follower_id", viewerId)
      .eq("following_id", userId)
      .maybeSingle(),
    client
      .from("follow_requests")
      .select("target_id")
      .eq("requester_id", viewerId)
      .eq("target_id", userId)
      .maybeSingle(),
    client.rpc("block_relationship", { p_other_user_id: userId }),
    client
      .from("mutes")
      .select("muted_id")
      .eq("muter_id", viewerId)
      .eq("muted_id", userId)
      .maybeSingle(),
  ]);
  for (const item of [followers, following, followRow, requestRow, relationship, muteRow]) fail(item.error);
  const wire = String(relationship.data ?? "none");
  return {
    profile,
    followerCount: Number(followers.data ?? 0),
    followingCount: Number(following.data ?? 0),
    following: Boolean(followRow.data),
    requested: Boolean(requestRow.data),
    blocked: wire === "blocked" || wire === "both",
    blockedBy: wire === "blocked_by" || wire === "both",
    muted: Boolean(muteRow.data),
  };
}

export async function searchProfiles(
  client: SupabaseClient,
  query: string,
  page = 0,
): Promise<ProfileRow[]> {
  const from = page * 30;
  const pattern = safeOrPattern(query.trim());
  const result = await client
    .from("profiles")
    .select(
      "id,username,display_name,bio,avatar_url,cover_url,platform_role,is_private,is_verified,dm_permission,mention_permission,comment_permission,likes_visibility",
    )
    .or(`username.ilike.${pattern},display_name.ilike.${pattern}`)
    .range(from, from + 29);
  fail(result.error, "ค้นหาผู้ใช้ไม่สำเร็จ");
  return (result.data ?? []).map((row) => asProfile(row as Record<string, unknown>));
}

export async function searchDrops(
  client: SupabaseClient,
  query: string,
  page = 0,
): Promise<HomeFeedRow[]> {
  const from = page * 21;
  const result = await client
    .from("drops")
    .select(dropCardSelect)
    .ilike("caption", `%${query.trim()}%`)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .range(from, from + 20);
  fail(result.error, "ค้นหาโพสต์ไม่สำเร็จ");
  return (result.data ?? []).map((row) => asDrop(row as Record<string, unknown>));
}

async function signClubMedia(client: SupabaseClient, path: unknown): Promise<string | null> {
  if (!path) return null;
  const result = await client.storage.from("club-media").createSignedUrl(String(path), 3600);
  return result.error ? null : result.data.signedUrl;
}

async function mapClub(client: SupabaseClient, row: Record<string, unknown>): Promise<ClubRow> {
  const [cover, icon, members] = await Promise.all([
    signClubMedia(client, row.cover_url),
    signClubMedia(client, row.icon_url),
    client
      .from("club_members")
      .select("club_id", { count: "exact", head: true })
      .eq("club_id", String(row.id ?? ""))
      .eq("status", "approved"),
  ]);
  return {
    id: String(row.id ?? ""),
    name: String(row.name ?? ""),
    description: row.description == null ? null : String(row.description),
    category: row.category == null ? null : String(row.category),
    privacy: row.privacy == null ? null : String(row.privacy),
    cover_url: cover,
    icon_url: icon,
    created_at: String(row.created_at ?? ""),
    member_count: members.count ?? 0,
  };
}

export async function searchClubs(client: SupabaseClient, query: string, page = 0): Promise<ClubRow[]> {
  const from = page * 20;
  const result = await client
    .from("clubs")
    .select("id,name,description,category,privacy,cover_url,icon_url,created_at")
    .ilike("name", `%${query.trim()}%`)
    .order("created_at", { ascending: false })
    .range(from, from + 19);
  fail(result.error, "ค้นหา Club ไม่สำเร็จ");
  return Promise.all((result.data ?? []).map((row) => mapClub(client, row as Record<string, unknown>)));
}

export async function fetchClub(client: SupabaseClient, clubId: string): Promise<ClubRow | null> {
  const result = await client
    .from("clubs")
    .select("id,name,description,category,privacy,cover_url,icon_url,created_at")
    .eq("id", clubId)
    .maybeSingle();
  fail(result.error, "โหลด Club ไม่สำเร็จ");
  return result.data ? mapClub(client, result.data as Record<string, unknown>) : null;
}

function extractHashtags(text: string): string[] {
  const matches = text.match(/#[\p{L}\p{N}_]+/gu) ?? [];
  return [...new Set(matches.map((tag) => tag.slice(1).toLowerCase()).filter(Boolean))];
}

export async function fetchTrendingHashtags(client: SupabaseClient, limit = 20): Promise<RankedHashtag[]> {
  const result = await client.rpc("trending_hashtag_candidates", { p_hours: 48, p_limit: 100 });
  fail(result.error, "โหลดกำลังนิยมไม่สำเร็จ");
  const now = Date.now();
  const scores = new Map<string, number>();
  const counts = new Map<string, number>();
  for (const raw of (result.data ?? []) as Record<string, unknown>[]) {
    const caption = raw.caption == null ? "" : String(raw.caption);
    const tags = extractHashtags(caption);
    if (!tags.length) continue;
    const ageHours = Math.max(0, (now - new Date(String(raw.created_at)).getTime()) / 3_600_000);
    const engagement =
      Number(raw.like_count ?? 0) +
      Number(raw.comment_count ?? 0) * 2 +
      Number(raw.redrop_count ?? 0) * 3 +
      Number(raw.view_count ?? 0) * 0.1;
    const score = engagement / Math.pow(ageHours + 2, 1.5);
    for (const tag of tags) {
      scores.set(tag, (scores.get(tag) ?? 0) + score);
      counts.set(tag, (counts.get(tag) ?? 0) + 1);
    }
  }
  return [...scores.keys()]
    .sort((a, b) => (scores.get(b)! - scores.get(a)!) || ((counts.get(b) ?? 0) - (counts.get(a) ?? 0)))
    .slice(0, limit)
    .map((tag) => ({ tag, score: scores.get(tag) ?? 0, postCount: counts.get(tag) ?? 0 }));
}

async function fetchRankedProfiles(client: SupabaseClient, rpcName: string, limit: number): Promise<ProfileRow[]> {
  const idsResult = await client.rpc(rpcName, { p_limit: limit });
  fail(idsResult.error, "โหลดคำแนะนำไม่สำเร็จ");
  const ids = ((idsResult.data ?? []) as Record<string, unknown>[]).map((row) => String(row.profile_id ?? ""));
  if (!ids.length) return [];
  const profiles = await client
    .from("profiles")
    .select(
      "id,username,display_name,bio,avatar_url,cover_url,platform_role,is_private,is_verified,dm_permission,mention_permission,comment_permission,likes_visibility",
    )
    .in("id", ids);
  fail(profiles.error, "โหลดคำแนะนำไม่สำเร็จ");
  const byId = new Map(
    (profiles.data ?? []).map((row) => [String(row.id), asProfile(row as Record<string, unknown>)] as const),
  );
  return ids.map((id) => byId.get(id)).filter((value): value is ProfileRow => Boolean(value));
}

export function fetchSuggestedProfiles(client: SupabaseClient, limit = 10) {
  return fetchRankedProfiles(client, "suggested_users", limit);
}

export function fetchRisingProfiles(client: SupabaseClient, limit = 10) {
  return fetchRankedProfiles(client, "rising_profiles", limit);
}

export async function fetchProfileDrops(
  client: SupabaseClient,
  userId: string,
  page = 0,
): Promise<HomeFeedRow[]> {
  const from = page * 21;
  const result = await client
    .from("drops")
    .select(dropCardSelect)
    .eq("author_id", userId)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .range(from, from + 20);
  fail(result.error, "โหลดโพสต์ไม่สำเร็จ");
  return (result.data ?? []).map((row) => asDrop(row as Record<string, unknown>));
}

export async function fetchProfileLikedDrops(
  client: SupabaseClient,
  userId: string,
  page = 0,
): Promise<HomeFeedRow[]> {
  const idsResult = await client.rpc("fetch_liked_drop_ids", {
    p_target_user_id: userId,
    p_page: page,
  });
  fail(idsResult.error, "โหลดรายการที่ถูกใจไม่สำเร็จ");
  const ids = ((idsResult.data ?? []) as Record<string, unknown>[]).map((row) => String(row.drop_id ?? ""));
  if (!ids.length) return [];
  const result = await client.from("drops").select(dropCardSelect).in("id", ids).is("deleted_at", null);
  fail(result.error, "โหลดรายการที่ถูกใจไม่สำเร็จ");
  const byId = new Map(
    (result.data ?? []).map((row) => [String(row.id), asDrop(row as Record<string, unknown>)] as const),
  );
  return ids.map((id) => byId.get(id)).filter((value): value is HomeFeedRow => Boolean(value));
}

export async function canViewProfileLikes(client: SupabaseClient, userId: string): Promise<boolean> {
  const result = await client.rpc("can_view_likes", { p_target: userId });
  fail(result.error);
  return result.data === true;
}

export async function updateProfileBasics(
  client: SupabaseClient,
  userId: string,
  input: { displayName: string; bio: string; socialLinks?: Record<string, string> },
): Promise<void> {
  const result = await client
    .from("profiles")
    .update({
      display_name: input.displayName.trim() || null,
      bio: input.bio,
      ...(input.socialLinks ? { social_links: input.socialLinks } : {}),
    })
    .eq("id", userId);
  fail(result.error, "บันทึกโปรไฟล์ไม่สำเร็จ");
}

export async function updateUsername(client: SupabaseClient, userId: string, username: string): Promise<void> {
  const normalized = username.trim().toLowerCase();
  const exists = await client.from("profiles").select("id").eq("username", normalized).maybeSingle();
  fail(exists.error);
  if (exists.data && String(exists.data.id) !== userId) throw new Error("username นี้ถูกใช้แล้ว");
  const result = await client.from("profiles").update({ username: normalized }).eq("id", userId);
  fail(result.error, "เปลี่ยน username ไม่สำเร็จ");
}

export async function uploadProfileImage(
  client: SupabaseClient,
  userId: string,
  kind: "avatar" | "cover",
  file: File,
): Promise<string> {
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
  const path = `${userId}/${kind}.${ext}`;
  const upload = await client.storage.from("avatars").upload(path, file, { upsert: true, contentType: file.type || undefined });
  fail(upload.error, "อัปโหลดรูปไม่สำเร็จ");
  const { data } = client.storage.from("avatars").getPublicUrl(path);
  const url = `${data.publicUrl}?v=${Date.now()}`;
  const update = await client.from("profiles").update({ [`${kind}_url`]: url }).eq("id", userId);
  fail(update.error, "บันทึกรูปโปรไฟล์ไม่สำเร็จ");
  return url;
}

export async function fetchNotifications(client: SupabaseClient, page = 0): Promise<NotificationRow[]> {
  const from = page * 30;
  const result = await client
    .from("notifications")
    .select(
      "id,type,drop_id,pop_id,club_id,club_post_id,reason,moderation_action_id,moderation_action_type,conversation_id,is_read,created_at," +
        "actor:profiles!notifications_actor_id_fkey(id,username,display_name,avatar_url)," +
        "club:clubs(name),drop:drops(caption),pop:pops(caption)",
    )
    .neq("type", "new_message")
    .order("created_at", { ascending: false })
    .range(from, from + 29);
  fail(result.error, "โหลดการแจ้งเตือนไม่สำเร็จ");
  return (result.data ?? []).map((raw) => {
    const row = raw as Record<string, unknown>;
    const actor = relation(row.actor);
    const club = relation(row.club);
    const drop = relation(row.drop);
    const pop = relation(row.pop);
    return {
      id: String(row.id ?? ""),
      type: String(row.type ?? ""),
      actor_id: actor.id == null ? null : String(actor.id),
      actor_username: actor.username == null ? null : String(actor.username),
      actor_display_name: actor.display_name == null ? null : String(actor.display_name),
      actor_avatar_url: actor.avatar_url == null ? null : String(actor.avatar_url),
      drop_id: row.drop_id == null ? null : String(row.drop_id),
      pop_id: row.pop_id == null ? null : String(row.pop_id),
      club_id: row.club_id == null ? null : String(row.club_id),
      club_name: club.name == null ? null : String(club.name),
      club_post_id: row.club_post_id == null ? null : String(row.club_post_id),
      reason: row.reason == null ? null : String(row.reason),
      moderation_action_id: row.moderation_action_id == null ? null : String(row.moderation_action_id),
      moderation_action_type: row.moderation_action_type == null ? null : String(row.moderation_action_type),
      conversation_id: row.conversation_id == null ? null : String(row.conversation_id),
      content_preview:
        drop.caption != null ? String(drop.caption) : pop.caption != null ? String(pop.caption) : null,
      is_read: row.is_read === true,
      created_at: String(row.created_at ?? ""),
    } satisfies NotificationRow;
  });
}

export async function markAllNotificationsRead(client: SupabaseClient, userId: string): Promise<void> {
  const result = await client
    .from("notifications")
    .update({ is_read: true })
    .eq("recipient_id", userId)
    .eq("is_read", false)
    .neq("type", "new_message");
  fail(result.error, "อัปเดตการแจ้งเตือนไม่สำเร็จ");
}

export async function fetchInbox(client: SupabaseClient, page = 0): Promise<ConversationRow[]> {
  const from = page * 30;
  const result = await client
    .from("chat_inbox")
    .select("*")
    .order("conversation_created_at", { ascending: false })
    .range(from, from + 29);
  fail(result.error, "โหลดแชทไม่สำเร็จ");
  return ((result.data ?? []) as ConversationRow[]).sort((a, b) => {
    const aKey = new Date(a.last_message_at || a.conversation_created_at).getTime();
    const bKey = new Date(b.last_message_at || b.conversation_created_at).getTime();
    return bKey - aKey;
  });
}

export async function fetchMessageRequests(client: SupabaseClient, page = 0): Promise<MessageRequestRow[]> {
  const from = page * 30;
  const result = await client
    .from("message_requests")
    .select("*")
    .order("conversation_created_at", { ascending: false })
    .range(from, from + 29);
  fail(result.error, "โหลดคำขอข้อความไม่สำเร็จ");
  return (result.data ?? []) as MessageRequestRow[];
}

export async function chatAllowed(client: SupabaseClient, otherUserId?: string): Promise<boolean> {
  const result = await client.rpc("chat_lockdown_status", { p_other_user_id: otherUserId ?? null });
  fail(result.error, "ตรวจสอบ Chat ไม่สำเร็จ");
  return result.data === true;
}

export async function getOrCreateConversation(client: SupabaseClient, otherUserId: string): Promise<string> {
  const result = await client.rpc("get_or_create_conversation", { p_other_user_id: otherUserId });
  fail(result.error, "เริ่มบทสนทนาไม่สำเร็จ");
  return String(result.data);
}

export async function acceptMessageRequest(client: SupabaseClient, conversationId: string): Promise<void> {
  const result = await client.rpc("accept_message_request", { p_conversation_id: conversationId });
  fail(result.error, "ยอมรับคำขอไม่สำเร็จ");
}

export async function deleteMessageRequest(client: SupabaseClient, conversationId: string): Promise<void> {
  const result = await client.rpc("delete_message_request", { p_conversation_id: conversationId });
  fail(result.error, "ลบคำขอไม่สำเร็จ");
}

export async function markConversationRead(client: SupabaseClient, conversationId: string): Promise<void> {
  const result = await client.rpc("mark_conversation_read", { p_conversation_id: conversationId });
  fail(result.error, "อัปเดตสถานะอ่านไม่สำเร็จ");
}

export async function fetchConversationMeta(
  client: SupabaseClient,
  userId: string,
  conversationId: string,
): Promise<ConversationMeta | null> {
  const result = await client
    .from("conversations")
    .select("status,requested_by,user_a_id,user_b_id,user_a_last_read_at,user_b_last_read_at")
    .eq("id", conversationId)
    .maybeSingle();
  fail(result.error, "โหลดบทสนทนาไม่สำเร็จ");
  if (!result.data) return null;
  const row = result.data as Record<string, unknown>;
  const amA = String(row.user_a_id) === userId;
  const otherRead = amA ? row.user_b_last_read_at : row.user_a_last_read_at;
  return {
    status: String(row.status ?? "active"),
    requested_by: row.requested_by == null ? null : String(row.requested_by),
    other_user_last_read_at: otherRead == null ? null : String(otherRead),
  };
}

export async function fetchMessages(
  client: SupabaseClient,
  conversationId: string,
  beforeCreatedAt?: string | null,
): Promise<MessageRow[]> {
  let query = client.from("messages").select(messageColumns).eq("conversation_id", conversationId);
  if (beforeCreatedAt) query = query.lt("created_at", beforeCreatedAt);
  const result = await query.order("created_at", { ascending: false }).limit(30);
  fail(result.error, "โหลดข้อความไม่สำเร็จ");
  return (result.data ?? []) as MessageRow[];
}

export async function sendMessage(
  client: SupabaseClient,
  userId: string,
  conversationId: string,
  input: { text?: string; file?: File | null; replyToMessageId?: string | null },
): Promise<MessageRow> {
  let imagePath: string | null = null;
  if (input.file) {
    const ext = (input.file.name.split(".").pop() || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
    imagePath = `${conversationId}/${userId}-${Date.now()}.${ext}`;
    const upload = await client.storage.from("chat-media").upload(imagePath, input.file, {
      upsert: false,
      contentType: input.file.type || undefined,
      cacheControl: "31536000",
    });
    fail(upload.error, "อัปโหลดรูปไม่สำเร็จ");
  }
  const text = input.text?.trim() || null;
  if (!text && !imagePath) throw new Error("ข้อความว่าง");
  const result = await client
    .from("messages")
    .insert({
      conversation_id: conversationId,
      sender_id: userId,
      text,
      image_url: imagePath,
      reply_to_message_id: input.replyToMessageId ?? null,
    })
    .select(messageColumns)
    .single();
  fail(result.error, "ส่งข้อความไม่สำเร็จ");
  return result.data as MessageRow;
}

export async function signedChatImage(client: SupabaseClient, path: string): Promise<string | null> {
  const result = await client.storage.from("chat-media").createSignedUrl(path, 3600);
  return result.error ? null : result.data.signedUrl;
}

export async function deleteMessage(client: SupabaseClient, message: MessageRow): Promise<void> {
  const result = await client.rpc("delete_message", { p_message_id: message.id });
  fail(result.error, "ลบข้อความไม่สำเร็จ");
  if (message.image_url) {
    await client.storage.from("chat-media").remove([message.image_url]);
  }
}

export function subscribeConversationMessages(
  client: SupabaseClient,
  conversationId: string,
  onChange: () => void,
): RealtimeChannel {
  return client
    .channel(`web-conversation-${conversationId}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "messages", filter: `conversation_id=eq.${conversationId}` },
      onChange,
    )
    .subscribe();
}

export async function fetchNotificationSettings(client: SupabaseClient): Promise<NotificationSettings> {
  const result = await client.from("notification_settings").select("*").maybeSingle();
  fail(result.error, "โหลดการตั้งค่าการแจ้งเตือนไม่สำเร็จ");
  return { ...defaultNotificationSettings, ...(result.data ?? {}) } as NotificationSettings;
}

export async function updateNotificationSetting(
  client: SupabaseClient,
  userId: string,
  category: keyof NotificationSettings,
  value: boolean,
): Promise<void> {
  const result = await client
    .from("notification_settings")
    .upsert({ user_id: userId, [category]: value }, { onConflict: "user_id" });
  fail(result.error, "บันทึกการแจ้งเตือนไม่สำเร็จ");
}

export async function updateProfilePrivacySetting(
  client: SupabaseClient,
  userId: string,
  field: "is_private" | "dm_permission" | "mention_permission" | "comment_permission" | "likes_visibility",
  value: boolean | string,
): Promise<void> {
  const result = await client.from("profiles").update({ [field]: value }).eq("id", userId);
  fail(result.error, "บันทึกการตั้งค่าไม่สำเร็จ");
}

export async function fetchShowOnlineStatus(client: SupabaseClient, userId: string): Promise<boolean> {
  const result = await client
    .from("user_presence")
    .select("show_online_status")
    .eq("user_id", userId)
    .maybeSingle();
  fail(result.error, "โหลดสถานะออนไลน์ไม่สำเร็จ");
  return result.data ? result.data.show_online_status !== false : true;
}

export async function setShowOnlineStatus(client: SupabaseClient, userId: string, value: boolean): Promise<void> {
  const result = await client.from("user_presence").upsert({
    user_id: userId,
    show_online_status: value,
    updated_at: new Date().toISOString(),
  });
  fail(result.error, "บันทึกสถานะออนไลน์ไม่สำเร็จ");
}

export async function fetchBlockedUsers(client: SupabaseClient, page = 0): Promise<ProfileRow[]> {
  const from = page * 30;
  const result = await client
    .from("blocks")
    .select("created_at,blocked:profiles!blocks_blocked_id_fkey(*)")
    .order("created_at", { ascending: false })
    .range(from, from + 29);
  fail(result.error, "โหลดรายการบล็อกไม่สำเร็จ");
  return (result.data ?? []).map((row) => asProfile(relation((row as Record<string, unknown>).blocked)));
}

export async function unblockUser(client: SupabaseClient, userId: string): Promise<void> {
  const result = await client.rpc("unblock_user", { p_target_user_id: userId });
  fail(result.error, "ปลดบล็อกไม่สำเร็จ");
}

export async function fetchMutedUsers(client: SupabaseClient, page = 0): Promise<ProfileRow[]> {
  const from = page * 30;
  const result = await client
    .from("mutes")
    .select("created_at,muted:profiles!mutes_muted_id_fkey(*)")
    .order("created_at", { ascending: false })
    .range(from, from + 29);
  fail(result.error, "โหลดรายการปิดเสียงไม่สำเร็จ");
  return (result.data ?? []).map((row) => asProfile(relation((row as Record<string, unknown>).muted)));
}

export async function unmuteUser(client: SupabaseClient, userId: string, mutedId: string): Promise<void> {
  const result = await client.from("mutes").delete().eq("muter_id", userId).eq("muted_id", mutedId);
  fail(result.error, "เปิดเสียงไม่สำเร็จ");
}

export async function exportMyData(client: SupabaseClient): Promise<string> {
  const result = await client.rpc("export_my_data");
  fail(result.error, "ส่งออกข้อมูลไม่สำเร็จ");
  return JSON.stringify(result.data, null, 2);
}

export async function deleteMyAccount(client: SupabaseClient): Promise<void> {
  const result = await client.rpc("delete_my_account");
  fail(result.error, "ลบบัญชีไม่สำเร็จ");
}

export async function fetchLegalDocument(client: SupabaseClient, type: string): Promise<LegalDocument | null> {
  const result = await client
    .from("platform_documents")
    .select("type,version,title,content,effective_at")
    .eq("type", type)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();
  fail(result.error, "โหลดเอกสารไม่สำเร็จ");
  return result.data as LegalDocument | null;
}

export async function fetchDropById(client: SupabaseClient, dropId: string): Promise<HomeFeedRow | null> {
  const result = await client
    .from("drops")
    .select(dropCardSelect)
    .eq("id", dropId)
    .is("deleted_at", null)
    .maybeSingle();
  fail(result.error, "โหลดโพสต์ไม่สำเร็จ");
  return result.data ? asDrop(result.data as Record<string, unknown>) : null;
}

export async function fetchClubPostById(client: SupabaseClient, postId: string): Promise<Record<string, unknown> | null> {
  const result = await client
    .from("club_posts")
    .select("*,author:profiles!club_posts_author_id_fkey(username,display_name,avatar_url),club:clubs(name)")
    .eq("id", postId)
    .maybeSingle();
  fail(result.error, "โหลดโพสต์ Club ไม่สำเร็จ");
  return result.data as Record<string, unknown> | null;
}

export async function fetchClubInvite(client: SupabaseClient, code: string): Promise<Record<string, unknown> | null> {
  const result = await client.rpc("preview_club_invite", { p_code: code });
  if (result.error) return null;
  if (Array.isArray(result.data)) return (result.data[0] as Record<string, unknown> | undefined) ?? null;
  return result.data && typeof result.data === "object" ? (result.data as Record<string, unknown>) : null;
}
