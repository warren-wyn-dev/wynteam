import type { SupabaseClient } from "@supabase/supabase-js";

import { isQuotePost, type HomeFeedRow } from "@/lib/feed";
import { fetchProfileDrops } from "@/lib/phase3-data";

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
  const from = page * PROFILE_REPOST_PAGE_SIZE;
  const result = await client.from("home_feed")
    .select("*")
    .eq("redropper_id", userId)
    .is("quote_text", null)
    .eq("content_type", "drop")
    .order("created_at", { ascending: false })
    .range(from, from + PROFILE_REPOST_PAGE_SIZE - 1);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as HomeFeedRow[];
}
