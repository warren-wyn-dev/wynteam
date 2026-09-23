import type { SupabaseClient } from "@supabase/supabase-js";

export type QuoteEngagement = {
  quoteId: string;
  likeCount: number;
  commentCount: number;
  redropCount: number;
  liked: boolean;
  saved: boolean;
  redropped: boolean;
};

export type QuoteComment = {
  id: string;
  quoteId: string;
  authorId: string;
  authorUsername: string;
  authorDisplayName: string | null;
  authorAvatarUrl: string | null;
  authorVerified: boolean;
  text: string;
  createdAt: string;
};

function fail(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "อัปเดตโพสต์อ้างอิงไม่สำเร็จ");
}

/** Counts and viewer flags are keyed by the Quote's redrops.id, never by drop_id. */
export async function fetchQuoteEngagement(
  client: SupabaseClient,
  quoteIds: string[],
): Promise<Map<string, QuoteEngagement>> {
  const ids = [...new Set(quoteIds.filter(Boolean))];
  if (!ids.length) return new Map();
  // Postgres enforces the 100-ID bound too; chunk larger cached feeds.
  const pages = await Promise.all(
    Array.from({ length: Math.ceil(ids.length / 100) }, (_, i) => ids.slice(i * 100, (i + 1) * 100))
      .map(async (chunk) => {
        const result = await client.rpc("get_quote_engagement", { p_quote_ids: chunk });
        fail(result.error);
        return (result.data ?? []) as Record<string, unknown>[];
      }),
  );
  const items = new Map<string, QuoteEngagement>();
  for (const raw of pages.flat()) {
    const quoteId = String(raw.quote_id ?? "");
    if (!quoteId) continue;
    items.set(quoteId, {
      quoteId,
      likeCount: Number(raw.like_count ?? 0),
      commentCount: Number(raw.comment_count ?? 0),
      redropCount: Number(raw.redrop_count ?? 0),
      liked: raw.liked_by_me === true,
      saved: raw.saved_by_me === true,
      redropped: raw.redropped_by_me === true,
    });
  }
  return items;
}

export async function toggleQuoteLike(
  client: SupabaseClient,
  userId: string,
  quoteId: string,
  liked: boolean,
): Promise<void> {
  const result = liked
    ? await client.from("quote_likes").delete().eq("quote_id", quoteId).eq("user_id", userId)
    : await client.from("quote_likes").insert({ quote_id: quoteId, user_id: userId });
  fail(result.error);
}

export async function toggleQuoteSave(
  client: SupabaseClient,
  userId: string,
  quoteId: string,
  saved: boolean,
): Promise<void> {
  const result = saved
    ? await client.from("quote_saves").delete().eq("quote_id", quoteId).eq("user_id", userId)
    : await client.from("quote_saves").insert({ quote_id: quoteId, user_id: userId });
  fail(result.error);
}

export async function toggleQuoteRepost(
  client: SupabaseClient,
  userId: string,
  quoteId: string,
  redropped: boolean,
): Promise<void> {
  const result = redropped
    ? await client.from("quote_reposts").delete().eq("quote_id", quoteId).eq("user_id", userId)
    : await client.from("quote_reposts").insert({ quote_id: quoteId, user_id: userId });
  fail(result.error);
}

function relation(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) return relation(value[0]);
  return value && typeof value === "object" ? value as Record<string, unknown> : {};
}

export async function fetchQuoteComments(
  client: SupabaseClient,
  quoteId: string,
  page = 0,
  pageSize = 30,
): Promise<QuoteComment[]> {
  const result = await client.from("quote_comments")
    .select("id,quote_id,author_id,text_content,created_at,author:profiles!quote_comments_author_id_fkey(username,display_name,avatar_url,is_verified)")
    .eq("quote_id", quoteId)
    .order("created_at", { ascending: true })
    .range(page * pageSize, (page + 1) * pageSize - 1);
  fail(result.error);
  return (result.data ?? []).map((row) => {
    const author = relation(row.author);
    return {
      id: String(row.id),
      quoteId: String(row.quote_id),
      authorId: String(row.author_id),
      authorUsername: String(author.username ?? "WYNOS"),
      authorDisplayName: author.display_name ? String(author.display_name) : null,
      authorAvatarUrl: author.avatar_url ? String(author.avatar_url) : null,
      authorVerified: author.is_verified === true,
      text: String(row.text_content),
      createdAt: String(row.created_at),
    };
  });
}

export async function addQuoteComment(
  client: SupabaseClient,
  userId: string,
  quoteId: string,
  text: string,
): Promise<void> {
  const body = text.trim();
  if (!body || body.length > 500) throw new Error("ความคิดเห็นต้องมีความยาว 1–500 ตัวอักษร");
  const result = await client.from("quote_comments").insert({
    quote_id: quoteId,
    author_id: userId,
    text_content: body,
  });
  fail(result.error);
}

export async function removeQuoteComment(
  client: SupabaseClient,
  userId: string,
  commentId: string,
): Promise<void> {
  const result = await client.from("quote_comments").delete().eq("id", commentId).eq("author_id", userId);
  fail(result.error);
}
