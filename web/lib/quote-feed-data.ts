import type { SupabaseClient } from "@supabase/supabase-js";
import { isQuotePost, type HomeFeedRow } from "@/lib/feed";

function fail(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "โหลดโพสต์อ้างอิงไม่สำเร็จ");
}

export async function fetchVisibleQuoteRows(
  client: SupabaseClient,
  quoteIds: string[],
): Promise<Map<string, HomeFeedRow>> {
  const ids = [...new Set(quoteIds.filter(Boolean))];
  if (!ids.length) return new Map();
  const batches = await Promise.all(
    Array.from({ length: Math.ceil(ids.length / 80) }, (_, i) => ids.slice(i * 80, (i + 1) * 80))
      .map(async (chunk) => {
        const result = await client.from("home_feed").select("*")
          .in("redrop_id", chunk).eq("content_type", "drop").not("quote_text", "is", null);
        fail(result.error);
        return (result.data ?? []) as HomeFeedRow[];
      }),
  );
  return new Map(batches.flat().filter(isQuotePost).map((row) => [row.redrop_id!, row]));
}

type QuoteRepost = { quote_id: string; user_id: string; created_at: string };

/** A Quote repost retains its Quote author and quoted Drop; the re-poster is
 * metadata on this extra timeline row, not a second "authored Quote". */
export async function fetchQuoteRepostRows(
  client: SupabaseClient,
  userIds: string[],
  limit = 21,
): Promise<HomeFeedRow[]> {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (!ids.length) return [];
  const result = await client.from("quote_reposts")
    .select("quote_id,user_id,created_at")
    .in("user_id", ids).order("created_at", { ascending: false })
    .range(0,limit - 1);
  fail(result.error);
  const reposts = (result.data ?? []) as QuoteRepost[];
  if (!reposts.length) return [];
  const [quotes, profilesResult] = await Promise.all([
    fetchVisibleQuoteRows(client, reposts.map((item) => item.quote_id)),
    client.from("profiles").select("id,username").in("id", [...new Set(reposts.map((item) => item.user_id))]),
  ]);
  fail(profilesResult.error);
  const usernames = new Map((profilesResult.data ?? []).map((row) => [String(row.id), String(row.username ?? "ผู้ใช้ WYNOS")]));
  return reposts.flatMap((share) => {
    const quote = quotes.get(share.quote_id);
    if (!quote) return [];
    return [{
      ...quote,
      quote_reposter_id: share.user_id,
      quote_reposter_username: usernames.get(share.user_id) || "ผู้ใช้ WYNOS",
      quote_reposted_at: share.created_at,
    }];
  });
}

export async function fetchSavedQuoteRows(
  client: SupabaseClient,
  userId: string,
  limit: number,
): Promise<(HomeFeedRow & { saved_at: string })[]> {
  const result = await client.from("quote_saves")
    .select("quote_id,created_at")
    .eq("user_id", userId).order("created_at", { ascending: false })
    .range(0,limit - 1);
  fail(result.error);
  const saves = (result.data ?? []) as { quote_id: string; created_at: string }[];
  const quotes = await fetchVisibleQuoteRows(client, saves.map((item) => item.quote_id));
  return saves.flatMap((item) => {
    const quote = quotes.get(item.quote_id);
    return quote ? [{ ...quote, saved_at: item.created_at }] : [];
  });
}

export async function fetchLikedQuoteRows(
  client: SupabaseClient,
  userId: string,
  limit: number,
): Promise<(HomeFeedRow & { liked_at: string })[]> {
  // The caller must check can_view_likes before discovering another user's
  // liked Quote IDs, the same gate used by fetch_liked_drop_ids.
  const result = await client.from("quote_likes")
    .select("quote_id,created_at").eq("user_id",userId)
    .order("created_at", { ascending: false }).range(0,limit - 1);
  fail(result.error);
  const likes = (result.data ?? []) as { quote_id: string; created_at: string }[];
  const quotes = await fetchVisibleQuoteRows(client, likes.map((item) => item.quote_id));
  return likes.flatMap((item) => {
    const quote = quotes.get(item.quote_id);
    return quote ? [{ ...quote, liked_at: item.created_at }] : [];
  });
}

export function feedIdentity(row: HomeFeedRow): string {
  return [row.id,row.redrop_id ?? "",row.quote_reposter_id ?? ""].join(":");
}
