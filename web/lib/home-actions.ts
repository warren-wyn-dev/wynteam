import type { SupabaseClient } from "@supabase/supabase-js";

import type { HomeFeedRow } from "@/lib/feed";
import { fetchQuoteEngagement, type QuoteEngagement } from "@/lib/quote-actions";
import { publishFollowChange, type FollowState } from "@/lib/follow-state";

export type HomeViewerState = {
  likedDropIds: Set<string>;
  savedDropIds: Set<string>;
  redroppedDropIds: Set<string>;
  followedAuthorIds: Set<string>;
  pendingFollowAuthorIds: Set<string>;
  privateAuthorIds: Set<string>;
  quoteEngagementById?: Map<string, QuoteEngagement>;
};

export type DropCommentRow = {
  id: string;
  drop_id: string;
  author_id: string;
  text_content: string;
  created_at: string;
  parent_comment_id?: string | null;
  author_username: string;
  author_display_name?: string | null;
  author_avatar_url?: string | null;
  like_count: number;
  liked_by_me: boolean;
};

function unique(values: string[]): string[] {
  return [...new Set(values.filter(Boolean))];
}

function throwIfError(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "Supabase request failed");
}

function firstCount(value: unknown): number {
  if (!Array.isArray(value) || !value.length) return 0;
  const row = value[0];
  if (!row || typeof row !== "object") return 0;
  const count = (row as { count?: unknown }).count;
  return typeof count === "number" ? count : Number(count ?? 0) || 0;
}

function profileFromRelation(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) {
    const first = value[0];
    return first && typeof first === "object" ? (first as Record<string, unknown>) : {};
  }
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

export async function loadHomeViewerState(
  client: SupabaseClient,
  userId: string,
  rows: HomeFeedRow[],
): Promise<HomeViewerState> {
  const dropIds = unique(rows.map((row) => row.id));
  const authorIds = unique(rows.map((row) => row.author_id));
  const quoteIds = unique(rows.map((row) => row.quote_text?.trim() ? row.redrop_id || "" : ""));

  const empty: HomeViewerState = {
    likedDropIds: new Set(),
    savedDropIds: new Set(),
    redroppedDropIds: new Set(),
    followedAuthorIds: new Set(),
    pendingFollowAuthorIds: new Set(),
    privateAuthorIds: new Set(),
    quoteEngagementById: new Map(),
  };
  if (!dropIds.length && !authorIds.length) return empty;

  const likesPromise = dropIds.length
    ? client.from("drop_likes").select("drop_id").eq("user_id", userId).in("drop_id", dropIds)
    : Promise.resolve({ data: [], error: null });
  const savesPromise = dropIds.length
    ? client
        .from("saves")
        .select("content_id")
        .eq("user_id", userId)
        .eq("content_type", "drop")
        .in("content_id", dropIds)
    : Promise.resolve({ data: [], error: null });
  const redropsPromise = dropIds.length
    ? client
        .from("redrops")
        .select("drop_id")
        .eq("redropper_id", userId)
        .is("quote_text", null)
        .in("drop_id", dropIds)
    : Promise.resolve({ data: [], error: null });
  const followsPromise = authorIds.length
    ? client
        .from("follows")
        .select("following_id")
        .eq("follower_id", userId)
        .in("following_id", authorIds)
    : Promise.resolve({ data: [], error: null });
  const requestsPromise = authorIds.length
    ? client
        .from("follow_requests")
        .select("target_id")
        .eq("requester_id", userId)
        .in("target_id", authorIds)
    : Promise.resolve({ data: [], error: null });
  const profilesPromise = authorIds.length
    ? client.from("profiles").select("id,is_private").in("id", authorIds)
    : Promise.resolve({ data: [], error: null });

  // Quote engagement is a separate domain; a temporarily unavailable new
  // migration must not break the existing Home feed or its Drop actions.
  const quotesPromise = fetchQuoteEngagement(client, quoteIds).catch(() => new Map<string, QuoteEngagement>());
  const [likes, saves, redrops, follows, requests, profiles, quotes] = await Promise.all([
    likesPromise,
    savesPromise,
    redropsPromise,
    followsPromise,
    requestsPromise,
    profilesPromise,
    quotesPromise,
  ]);

  for (const result of [likes, saves, redrops, follows, requests, profiles]) {
    throwIfError(result.error);
  }

  return {
    likedDropIds: new Set((likes.data ?? []).map((row) => String(row.drop_id))),
    savedDropIds: new Set((saves.data ?? []).map((row) => String(row.content_id))),
    redroppedDropIds: new Set((redrops.data ?? []).map((row) => String(row.drop_id))),
    followedAuthorIds: new Set((follows.data ?? []).map((row) => String(row.following_id))),
    pendingFollowAuthorIds: new Set((requests.data ?? []).map((row) => String(row.target_id))),
    quoteEngagementById: quotes,
    privateAuthorIds: new Set(
      (profiles.data ?? [])
        .filter((row) => row.is_private === true)
        .map((row) => String(row.id)),
    ),
  };
}

export async function toggleDropLike(
  client: SupabaseClient,
  userId: string,
  dropId: string,
  currentlyLiked: boolean,
): Promise<void> {
  if (currentlyLiked) {
    const { error } = await client
      .from("drop_likes")
      .delete()
      .eq("drop_id", dropId)
      .eq("user_id", userId);
    throwIfError(error);
    return;
  }
  const { error } = await client.from("drop_likes").upsert(
    { drop_id: dropId, user_id: userId },
    { onConflict: "drop_id,user_id", ignoreDuplicates: true },
  );
  throwIfError(error);
}

export async function toggleDropSave(
  client: SupabaseClient,
  userId: string,
  dropId: string,
  currentlySaved: boolean,
): Promise<void> {
  if (currentlySaved) {
    const { error } = await client
      .from("saves")
      .delete()
      .eq("user_id", userId)
      .eq("content_type", "drop")
      .eq("content_id", dropId);
    throwIfError(error);
    return;
  }
  const { error } = await client.from("saves").upsert(
    { user_id: userId, content_type: "drop", content_id: dropId },
    { onConflict: "user_id,content_type,content_id", ignoreDuplicates: true },
  );
  throwIfError(error);
}

export async function toggleDropRedrop(
  client: SupabaseClient,
  userId: string,
  dropId: string,
  currentlyRedropped: boolean,
): Promise<void> {
  if (currentlyRedropped) {
    const { error } = await client
      .from("redrops")
      .delete()
      .eq("drop_id", dropId)
      .eq("redropper_id", userId)
      .is("quote_text", null);
    throwIfError(error);
    return;
  }
  const { error } = await client.from("redrops").insert({ drop_id: dropId, redropper_id: userId });
  throwIfError(error);
}

/** Mirrors toggleAuthorFollow's own branching so callers can apply the
 * resulting state optimistically before the request resolves. */
export function predictFollowState(options: {
  currentlyFollowing: boolean;
  pendingRequest: boolean;
  isPrivate: boolean;
}): "following" | "requested" | "none" {
  if (options.currentlyFollowing) return "none";
  if (options.isPrivate) return options.pendingRequest ? "none" : "requested";
  return "following";
}

export async function toggleAuthorFollow(
  client: SupabaseClient,
  userId: string,
  authorId: string,
  options: { currentlyFollowing: boolean; pendingRequest: boolean; isPrivate: boolean },
): Promise<FollowState> {
  if (authorId === userId) return "none";

  // Profile, Search and the follow lists may show different cached snapshots.
  // Reconcile the real row BEFORE treating a tap as a toggle.
  const existing = await client.from("follows").select("following_id")
    .eq("follower_id", userId).eq("following_id", authorId).maybeSingle();
  throwIfError(existing.error);
  const actuallyFollowing = Boolean(existing.data);
  if (actuallyFollowing !== options.currentlyFollowing) {
    const state: FollowState = actuallyFollowing ? "following" : "none";
    publishFollowChange({ actorId: userId, targetId: authorId, state });
    return state;
  }

  if (actuallyFollowing) {
    const { error } = await client.from("follows").delete()
      .eq("follower_id", userId).eq("following_id", authorId);
    throwIfError(error);
    publishFollowChange({ actorId: userId, targetId: authorId, state: "none" });
    return "none";
  }

  if (options.isPrivate) {
    const pending = await client.from("follow_requests").select("target_id")
      .eq("requester_id", userId).eq("target_id", authorId).maybeSingle();
    throwIfError(pending.error);
    if (Boolean(pending.data) !== options.pendingRequest) {
      const state: FollowState = pending.data ? "requested" : "none";
      publishFollowChange({ actorId: userId, targetId: authorId, state });
      return state;
    }
    if (pending.data) {
      const { error } = await client.from("follow_requests").delete()
        .eq("requester_id", userId).eq("target_id", authorId);
      throwIfError(error);
      publishFollowChange({ actorId: userId, targetId: authorId, state: "none" });
      return "none";
    }
    const { error } = await client.from("follow_requests").upsert(
      { requester_id: userId, target_id: authorId },
      { onConflict: "requester_id,target_id", ignoreDuplicates: true },
    );
    throwIfError(error);
    publishFollowChange({ actorId: userId, targetId: authorId, state: "requested" });
    return "requested";
  }

  // A second tab can insert after the read. ON CONFLICT DO NOTHING keeps
  // the button idempotent and prevents follows_pkey leaking into the UI.
  const { error } = await client.from("follows").upsert(
    { follower_id: userId, following_id: authorId },
    { onConflict: "follower_id,following_id", ignoreDuplicates: true },
  );
  throwIfError(error);
  publishFollowChange({ actorId: userId, targetId: authorId, state: "following" });
  return "following";
}

const commentSelect =
  "id,drop_id,author_id,text_content,created_at,parent_comment_id," +
  "author:profiles!drop_comments_author_id_fkey(username,display_name,avatar_url)," +
  "drop_comment_likes(count)";

function parseComment(row: Record<string, unknown>, likedByMe: boolean): DropCommentRow {
  const author = profileFromRelation(row.author);
  return {
    id: String(row.id ?? ""),
    drop_id: String(row.drop_id ?? ""),
    author_id: String(row.author_id ?? ""),
    text_content: String(row.text_content ?? ""),
    created_at: String(row.created_at ?? ""),
    parent_comment_id: row.parent_comment_id ? String(row.parent_comment_id) : null,
    author_username: String(author.username ?? ""),
    author_display_name: author.display_name ? String(author.display_name) : null,
    author_avatar_url: author.avatar_url ? String(author.avatar_url) : null,
    like_count: firstCount(row.drop_comment_likes),
    liked_by_me: likedByMe,
  };
}

export async function fetchDropComments(
  client: SupabaseClient,
  userId: string,
  dropId: string,
  page = 0,
): Promise<DropCommentRow[]> {
  const from = page * 50;
  const to = from + 49;
  const { data, error } = await client
    .from("drop_comments")
    .select(commentSelect)
    .eq("drop_id", dropId)
    .order("created_at", { ascending: true })
    .range(from, to);
  throwIfError(error);

  const raw = (data ?? []) as unknown as Record<string, unknown>[];
  const ids = raw.map((row) => String(row.id));
  let likedIds = new Set<string>();
  if (ids.length) {
    const liked = await client
      .from("drop_comment_likes")
      .select("comment_id")
      .eq("user_id", userId)
      .in("comment_id", ids);
    throwIfError(liked.error);
    likedIds = new Set((liked.data ?? []).map((row) => String(row.comment_id)));
  }

  return raw.map((row) => parseComment(row, likedIds.has(String(row.id))));
}

export async function addDropComment(
  client: SupabaseClient,
  userId: string,
  dropId: string,
  text: string,
  parentCommentId?: string | null,
): Promise<DropCommentRow> {
  const trimmed = text.trim();
  if (!trimmed) throw new Error("กรุณาพิมพ์ความคิดเห็น");
  const { data, error } = await client
    .from("drop_comments")
    .insert({
      drop_id: dropId,
      author_id: userId,
      text_content: trimmed,
      parent_comment_id: parentCommentId ?? null,
    })
    .select(commentSelect)
    .single();
  throwIfError(error);
  return parseComment(data as unknown as Record<string, unknown>, false);
}

export async function toggleDropCommentLike(
  client: SupabaseClient,
  userId: string,
  commentId: string,
  currentlyLiked: boolean,
): Promise<void> {
  if (currentlyLiked) {
    const { error } = await client
      .from("drop_comment_likes")
      .delete()
      .eq("comment_id", commentId)
      .eq("user_id", userId);
    throwIfError(error);
    return;
  }
  const { error } = await client.from("drop_comment_likes").upsert(
    { comment_id: commentId, user_id: userId },
    { onConflict: "comment_id,user_id", ignoreDuplicates: true },
  );
  throwIfError(error);
}
