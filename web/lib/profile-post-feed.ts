import type { SupabaseClient } from "@supabase/supabase-js";

import { isQuotePost, type HomeFeedRow } from "@/lib/feed";
import { fetchProfileDrops, fetchProfileLikedDrops } from "@/lib/phase3-data";
import { fetchLikedQuoteRows, fetchQuoteRepostRows } from "@/lib/quote-feed-data";

/**
 * Profile timeline contract: authored Drops + authored Quote Reposts are
 * POSTS. Only unannotated, standard reposts belong to the Reposts tab.
 *
 * Fetch the first (page+1)*PAGE_SIZE rows from both independently sorted
 * sources before merging. Offset-paginating each source independently loses
 * entries when one source dominates a page (e.g. 18 posts + 3 quotes).
 * Visibility/block checks on quoted originals are enforced by home_feed's
 * existing security_invoker view. Never query redrops without that policy.
 */
export const PROFILE_POST_PAGE_SIZE = 21;
export const PROFILE_REPOST_PAGE_SIZE = 10;

export function mergeProfilePostsAndQuotes(
  posts: HomeFeedRow[],
  quotes: HomeFeedRow[],
  page: number,
  pageSize = PROFILE_POST_PAGE_SIZE,
): HomeFeedRow[] {
  const start = Math.max(0, page) * pageSize;
  const end = start + pageSize;
  return [...posts, ...quotes.filter(isQuotePost)]
    .sort((a, b) => {
      const byTime = Date.parse(b.created_at) - Date.parse(a.created_at);
      if (byTime) return byTime;
      return (b.redrop_id ?? b.id).localeCompare(a.redrop_id ?? a.id);
    })
    .slice(start, end);
}

export async function fetchProfilePostTimeline(
  client: SupabaseClient,
  userId: string,
  page: number,
): Promise<HomeFeedRow[]> {
  const limit = (Math.max(0, page) + 1) * PROFILE_POST_PAGE_SIZE;
  const [posts, quotesResult] = await Promise.all([
    fetchProfileDrops(client, userId, 0, limit),
    client.from("home_feed")
      .select("*")
      .eq("redropper_id", userId)
      .not("quote_text", "is", null)
      .eq("content_type", "drop")
      .order("created_at", { ascending: false })
      .range(0, limit - 1),
  ]);
  if (quotesResult.error) throw new Error(quotesResult.error.message);
  return mergeProfilePostsAndQuotes(posts, (quotesResult.data ?? []) as HomeFeedRow[], page);
}

export async function fetchProfileStandardReposts(
  client: SupabaseClient,
  userId: string,
  page: number,
): Promise<HomeFeedRow[]> {
  const limit = (Math.max(0, page) + 1) * PROFILE_REPOST_PAGE_SIZE;
  const [originals, quotes] = await Promise.all([
    client.from("home_feed")
      .select("*")
      .eq("redropper_id", userId).is("quote_text", null)
      .eq("content_type", "drop")
      .order("created_at", { ascending: false })
      .range(0, limit - 1),
    fetchQuoteRepostRows(client, [userId], limit),
  ]);
  if (originals.error) throw new Error(originals.error.message);
  return [...(originals.data ?? []) as HomeFeedRow[], ...quotes]
    .sort((a,b) => Date.parse(b.quote_reposted_at ?? b.created_at) - Date.parse(a.quote_reposted_at ?? a.created_at))
    .slice(page * PROFILE_REPOST_PAGE_SIZE, (page + 1) * PROFILE_REPOST_PAGE_SIZE);
}

/** The Likes tab includes both original Drops and independent Quote likes. */
export async function fetchProfileLikedContent(
  client: SupabaseClient,
  userId: string,
  page: number,
): Promise<HomeFeedRow[]> {
  const permission = await client.rpc("can_view_likes", { p_target: userId });
  if (permission.error) throw new Error(permission.error.message);
  if (permission.data !== true) return [];

  const limit = (Math.max(0,page)+1) * PROFILE_POST_PAGE_SIZE;
  const [dropPages, quotes] = await Promise.all([
    Promise.all(Array.from({ length: Math.max(0,page)+1 }, (_, p) => fetchProfileLikedDrops(client,userId,p))),
    fetchLikedQuoteRows(client,userId,limit),
  ]);
  const drops = dropPages.flat();
  const ids = [...new Set(drops.map((drop) => drop.id))];
  const timestamps = new Map<string,string>();
  if (ids.length) {
    const result = await client.from("drop_likes").select("drop_id,created_at")
      .eq("user_id",userId).in("drop_id",ids);
    if (result.error) throw new Error(result.error.message);
    for (const item of result.data ?? []) timestamps.set(String(item.drop_id),String(item.created_at));
  }
  return [
    ...drops.map((drop) => ({ ...drop, liked_at: timestamps.get(drop.id) ?? drop.created_at })),
    ...quotes,
  ].sort((a,b) => Date.parse(b.liked_at) - Date.parse(a.liked_at))
    .slice(page*PROFILE_POST_PAGE_SIZE,(page+1)*PROFILE_POST_PAGE_SIZE);
}
