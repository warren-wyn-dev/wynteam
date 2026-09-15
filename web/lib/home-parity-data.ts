import type { SupabaseClient } from "@supabase/supabase-js";

export type HomeIdentity = {
  id: string;
  username: string;
  display_name?: string | null;
  avatar_url?: string | null;
  follower_count: number;
  following_count: number;
};

export type ClubHomePost = {
  id: string;
  club_id: string;
  channel_id?: string | null;
  author_id: string;
  author_username: string;
  author_display_name?: string | null;
  author_avatar_url?: string | null;
  content?: string | null;
  image_urls: string[];
  link_url?: string | null;
  pinned: boolean;
  created_at: string;
  like_count: number;
  comment_count: number;
  liked_by_me: boolean;
  saved_by_me: boolean;
  my_role?: string | null;
  poll_id?: string | null;
  poll_options?: string[] | null;
  poll_expires_at?: string | null;
  poll_my_vote_index?: number | null;
  poll_total_votes?: number | null;
  poll_option_counts?: number[] | null;
};

function throwIfError(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "WYNOS request failed");
}

function firstCount(value: unknown): number {
  if (!Array.isArray(value) || value.length === 0) return 0;
  const first = value[0];
  if (!first || typeof first !== "object") return 0;
  return Number((first as { count?: unknown }).count ?? 0) || 0;
}

function relation(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) {
    const first = value[0];
    return first && typeof first === "object" ? first as Record<string, unknown> : {};
  }
  return value && typeof value === "object" ? value as Record<string, unknown> : {};
}

export async function fetchHomeIdentity(
  client: SupabaseClient,
  userId: string,
): Promise<HomeIdentity | null> {
  const [profile, followers, following] = await Promise.all([
    client.from("profiles").select("id,username,display_name,avatar_url").eq("id", userId).maybeSingle(),
    client.from("follows").select("follower_id", { count: "exact", head: true }).eq("following_id", userId),
    client.from("follows").select("following_id", { count: "exact", head: true }).eq("follower_id", userId),
  ]);
  throwIfError(profile.error);
  throwIfError(followers.error);
  throwIfError(following.error);
  if (!profile.data) return null;
  return {
    id: String(profile.data.id),
    username: String(profile.data.username ?? ""),
    display_name: profile.data.display_name ? String(profile.data.display_name) : null,
    avatar_url: profile.data.avatar_url ? String(profile.data.avatar_url) : null,
    follower_count: followers.count ?? 0,
    following_count: following.count ?? 0,
  };
}

// Same query AppChrome's own bottom-nav badge uses (components/phase3-ui.tsx) —
// kept as a small, separate helper here since Home's header badge and the
// root nav's badge are independent UI surfaces that happen to count the
// same thing.
export async function fetchHomeNotificationBadge(client: SupabaseClient, userId: string): Promise<number> {
  const result = await client
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("recipient_id", userId)
    .eq("is_read", false);
  throwIfError(result.error);
  return Math.max(0, result.count ?? 0);
}

async function fetchClubPostRows(
  client: SupabaseClient,
  userId: string,
  options: { clubId?: string; limit: number; pinnedFirst: boolean },
): Promise<ClubHomePost[]> {
  let query = client
    .from("club_posts")
    .select(
      "id,club_id,channel_id,author_id,content,image_urls,link_url,pinned,created_at," +
      "author:profiles!club_posts_author_id_fkey(username,display_name,avatar_url)," +
      "club_post_likes(count),club_post_comments(count),club_post_polls(id,options,expires_at)",
    );
  if (options.clubId) query = query.eq("club_id", options.clubId);
  if (options.pinnedFirst) query = query.order("pinned", { ascending: false });
  const result = await query.order("created_at", { ascending: false }).range(0, options.limit - 1);
  throwIfError(result.error);

  const raw = (result.data ?? []) as unknown as Record<string, unknown>[];
  const ids = raw.map((row) => String(row.id));
  const clubIds = [...new Set(raw.map((row) => String(row.club_id)).filter(Boolean))];
  const polls = raw.map((row) => relation(row.club_post_polls)).filter((poll) => Boolean(poll.id));
  const pollIds = polls.map((poll) => String(poll.id));

  const [likes, saves, memberships, votes, aggregate] = await Promise.all([
    ids.length
      ? client.from("club_post_likes").select("club_post_id").eq("user_id", userId).in("club_post_id", ids)
      : Promise.resolve({ data: [], error: null }),
    ids.length
      ? client.from("saves").select("content_id").eq("user_id", userId).eq("content_type", "club_post").in("content_id", ids)
      : Promise.resolve({ data: [], error: null }),
    clubIds.length
      ? client.from("club_members").select("club_id,role,status").eq("user_id", userId).eq("status", "approved").in("club_id", clubIds)
      : Promise.resolve({ data: [], error: null }),
    pollIds.length
      ? client.from("club_post_poll_votes").select("poll_id,option_index").eq("voter_id", userId).in("poll_id", pollIds)
      : Promise.resolve({ data: [], error: null }),
    pollIds.length
      ? client.rpc("get_club_poll_results", { p_poll_ids: pollIds })
      : Promise.resolve({ data: [], error: null }),
  ]);
  throwIfError(likes.error);
  throwIfError(saves.error);
  throwIfError(memberships.error);
  throwIfError(votes.error);
  throwIfError(aggregate.error);

  const likedIds = new Set((likes.data ?? []).map((row) => String(row.club_post_id)));
  const savedIds = new Set((saves.data ?? []).map((row) => String(row.content_id)));
  const roleByClub = new Map((memberships.data ?? []).map((row) => [String(row.club_id), String(row.role)]));
  const voteByPoll = new Map((votes.data ?? []).map((row) => [String(row.poll_id), Number(row.option_index)]));
  const aggregateByPoll = new Map(
    (((aggregate.data ?? []) as unknown as Record<string, unknown>[])).map((row) => [String(row.poll_id), row]),
  );

  return Promise.all(raw.map(async (row) => {
    const author = relation(row.author);
    const poll = relation(row.club_post_polls);
    const pollId = poll.id ? String(poll.id) : null;
    const aggregateRow = pollId ? aggregateByPoll.get(pollId) : undefined;
    const visible = aggregateRow?.visible === true;
    const paths = Array.isArray(row.image_urls) ? row.image_urls.map(String) : [];
    const signed = await Promise.all(paths.map(async (path) => {
      const value = await client.storage.from("club-media").createSignedUrl(path, 3600);
      return value.error ? null : value.data.signedUrl;
    }));
    const id = String(row.id);
    const clubId = String(row.club_id);
    return {
      id,
      club_id: clubId,
      channel_id: row.channel_id ? String(row.channel_id) : null,
      author_id: String(row.author_id),
      author_username: String(author.username ?? ""),
      author_display_name: author.display_name ? String(author.display_name) : null,
      author_avatar_url: author.avatar_url ? String(author.avatar_url) : null,
      content: row.content ? String(row.content) : null,
      image_urls: signed.filter((value): value is string => Boolean(value)),
      link_url: row.link_url ? String(row.link_url) : null,
      pinned: row.pinned === true,
      created_at: String(row.created_at ?? ""),
      like_count: firstCount(row.club_post_likes),
      comment_count: firstCount(row.club_post_comments),
      liked_by_me: likedIds.has(id),
      saved_by_me: savedIds.has(id),
      my_role: roleByClub.get(clubId) ?? null,
      poll_id: pollId,
      poll_options: Array.isArray(poll.options) ? poll.options.map(String) : null,
      poll_expires_at: poll.expires_at ? String(poll.expires_at) : null,
      poll_my_vote_index: pollId ? voteByPoll.get(pollId) ?? null : null,
      poll_total_votes: visible ? Number(aggregateRow?.total_votes ?? 0) : null,
      poll_option_counts: visible && Array.isArray(aggregateRow?.option_counts)
        ? (aggregateRow.option_counts as unknown[]).map((value) => Number(value) || 0)
        : null,
    } satisfies ClubHomePost;
  }));
}

export function fetchClubHomePosts(
  client: SupabaseClient,
  userId: string,
  limit = 100,
): Promise<ClubHomePost[]> {
  return fetchClubPostRows(client, userId, { limit, pinnedFirst: false });
}

export function fetchClubPostsForClub(
  client: SupabaseClient,
  userId: string,
  clubId: string,
  limit = 100,
): Promise<ClubHomePost[]> {
  return fetchClubPostRows(client, userId, { clubId, limit, pinnedFirst: true });
}

export async function toggleClubPostLike(
  client: SupabaseClient,
  userId: string,
  postId: string,
  currentlyLiked: boolean,
): Promise<void> {
  const result = currentlyLiked
    ? await client.from("club_post_likes").delete().eq("club_post_id", postId).eq("user_id", userId)
    : await client.from("club_post_likes").insert({ club_post_id: postId, user_id: userId });
  throwIfError(result.error);
}

export async function toggleClubPostSave(
  client: SupabaseClient,
  userId: string,
  postId: string,
  currentlySaved: boolean,
): Promise<void> {
  const result = currentlySaved
    ? await client.from("saves").delete().eq("user_id", userId).eq("content_type", "club_post").eq("content_id", postId)
    : await client.from("saves").insert({ user_id: userId, content_type: "club_post", content_id: postId });
  throwIfError(result.error);
}

export async function toggleClubPostPin(
  client: SupabaseClient,
  postId: string,
  currentlyPinned: boolean,
): Promise<void> {
  const result = await client.from("club_posts").update({ pinned: !currentlyPinned }).eq("id", postId);
  throwIfError(result.error);
}

export async function deleteClubPost(client: SupabaseClient, postId: string): Promise<void> {
  const result = await client.from("club_posts").delete().eq("id", postId);
  throwIfError(result.error);
}

export async function voteClubPostPoll(
  client: SupabaseClient,
  userId: string,
  pollId: string,
  optionIndex: number,
): Promise<void> {
  const result = await client.from("club_post_poll_votes").upsert(
    { poll_id: pollId, voter_id: userId, option_index: optionIndex },
    { onConflict: "poll_id,voter_id" },
  );
  throwIfError(result.error);
}
