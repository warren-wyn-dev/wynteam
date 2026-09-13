import type { SupabaseClient } from "@supabase/supabase-js";

import { rankedDropRows, type HomeFeedRow } from "@/lib/feed";

export type HomeSurface =
  | { kind: "ranked" }
  | { kind: "following" }
  | { kind: "trending" };

const rankedLimit = 200;
const followingLimit = 200;
// Flutter HomeRepository.fetchTrending() returns 10 items by default for the
// Home surface. Keep that UX contract here; Discovery is the surface that may
// deliberately request a larger trend window later.
const trendingLimit = 10;

function throwIfError(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "โหลดฟีดไม่สำเร็จ");
}

export async function fetchRankedDropRows(
  client: SupabaseClient,
): Promise<HomeFeedRow[]> {
  const result = await client.rpc("get_wynos_ranked_feed");
  throwIfError(result.error);
  return rankedDropRows(result.data, rankedLimit);
}

export async function fetchFollowingDropRows(
  client: SupabaseClient,
  userId: string,
): Promise<HomeFeedRow[]> {
  const follows = await client
    .from("follows")
    .select("following_id")
    .eq("follower_id", userId);
  throwIfError(follows.error);

  const followingIds = (follows.data ?? []).map((row) => String(row.following_id));
  if (!followingIds.length) return [];

  // Mirrors HomeRepository.fetchFollowingFeed(): a followed user's Standard/
  // Quote Repost belongs in Following even when the original Drop author is
  // not followed, so both author_id and redropper_id are matched.
  const list = followingIds.join(",");
  const result = await client
    .from("home_feed")
    .select("*")
    .or(`author_id.in.(${list}),redropper_id.in.(${list})`)
    .neq("content_type", "pop")
    .order("created_at", { ascending: false })
    .range(0, followingLimit - 1);
  throwIfError(result.error);
  return rankedDropRows(result.data, followingLimit);
}

export async function fetchTrendingDropRows(
  client: SupabaseClient,
): Promise<HomeFeedRow[]> {
  // Mirrors HomeRepository.fetchTrending(): preserve the backend's
  // authoritative trend order; no client-side cumulative re-ranking.
  const result = await client.rpc("get_trending_candidates", {
    p_limit: trendingLimit,
  });
  throwIfError(result.error);
  return rankedDropRows(result.data, trendingLimit);
}

export async function fetchHomeSurfaceRows(
  client: SupabaseClient,
  userId: string,
  surface: HomeSurface,
): Promise<HomeFeedRow[]> {
  switch (surface.kind) {
    case "following":
      return fetchFollowingDropRows(client, userId);
    case "trending":
      return fetchTrendingDropRows(client);
    case "ranked":
    default:
      return fetchRankedDropRows(client);
  }
}
