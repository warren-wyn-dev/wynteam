import type { SupabaseClient } from "@supabase/supabase-js";

import { rankedDropRows, type HomeFeedRow } from "@/lib/feed";
import { fetchQuoteRepostRows } from "@/lib/quote-feed-data";

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
const impressionLimit = 10;
const feedSources = [
  "following",
  "recommended",
  "trending",
  "latest",
  "club",
  "new_creator",
  "exploration",
] as const;

function throwIfError(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "โหลดฟีดไม่สำเร็จ");
}

function recordValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? value as Record<string, unknown> : {};
}

function impressionSource(row: Record<string, unknown>): typeof feedSources[number] {
  const scores = recordValue(row.feed_source_scores);
  let selected: typeof feedSources[number] = "recommended";
  let selectedScore = Number.NEGATIVE_INFINITY;
  for (const source of feedSources) {
    const score = Number(scores[source]);
    if (Number.isFinite(score) && score > selectedScore) {
      selected = source;
      selectedScore = score;
    }
  }
  return selected;
}

/**
 * The ranked backend deliberately down-ranks content delivered recently, but
 * that only works after the client records the first visible ranked window.
 * Flutter already calls record_feed_impressions; web must do the same or a
 * pull-to-refresh will legitimately receive the same deterministic ranking.
 */
async function recordRankedImpressions(
  client: SupabaseClient,
  raw: unknown,
  latencyMs: number,
): Promise<void> {
  if (!Array.isArray(raw)) return;

  const items: Record<string, unknown>[] = [];
  for (const candidateValue of raw) {
    const candidate = recordValue(candidateValue);
    const row = recordValue(candidate.row_data ?? candidateValue);
    if (row.content_type !== "drop" || typeof row.id !== "string") continue;

    items.push({
      contentId: row.id,
      renderKey: `${row.id}:${typeof row.redrop_id === "string" ? row.redrop_id : ""}`,
      feedSource: impressionSource(row),
      rankPosition: items.length + 1,
      contentType: "drop",
      topic: typeof row.feed_topic === "string" ? row.feed_topic : null,
      candidateOrigin: typeof row.feed_candidate_origin === "string" ? row.feed_candidate_origin : "direct",
      experiments: [],
    });
    if (items.length >= impressionLimit) break;
  }

  if (!items.length) return;
  try {
    await client.rpc("record_feed_impressions", {
      p_session_key: `web-home-v1-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`,
      p_latency_ms: Math.max(0, Math.round(latencyMs)),
      p_items: items,
    });
  } catch {
    // Repetition telemetry is best-effort and must never block a valid feed.
  }
}

/**
 * Flutter cannot read image_aspect_ratio from home_feed either; it batch-reads
 * drops in parallel and falls back to 4:5. Mirror that production-safe rule.
 */
async function hydrateImageAspectRatios(
  client: SupabaseClient,
  rows: HomeFeedRow[],
): Promise<HomeFeedRow[]> {
  const ids = [...new Set(rows.filter((row) => row.image_url).map((row) => row.id))];
  if (!ids.length) return rows;
  const result = await client
    .from("drops")
    .select("id,image_aspect_ratio")
    .in("id", ids);
  if (result.error) return rows;
  const ratios = new Map(
    (result.data ?? []).map((row) => [String(row.id), row.image_aspect_ratio == null ? null : String(row.image_aspect_ratio)]),
  );
  return rows.map((row) => ratios.has(row.id) ? { ...row, image_aspect_ratio: ratios.get(row.id) } : row);
}

export async function fetchRankedDropRows(
  client: SupabaseClient,
): Promise<HomeFeedRow[]> {
  const startedAt = Date.now();
  const result = await client.rpc("get_wynos_ranked_feed");
  throwIfError(result.error);
  const rows = rankedDropRows(result.data, rankedLimit);
  await recordRankedImpressions(client, result.data, Date.now() - startedAt);
  return hydrateImageAspectRatios(client, rows);
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

  // Like X's Following surface: original Drops belong to followed authors,
  // while standard reposts and authored Quotes belong to the REPOSTER, not
  // the quoted Drop's original author. Without the redrop_id null guard,
  // following Alice would also surface every stranger quoting Alice's Drop.
  const list = followingIds.join(",");
  const [result, quoteShares] = await Promise.all([
    client.from("home_feed").select("*")
      .or(`and(author_id.in.(${list}),redrop_id.is.null),redropper_id.in.(${list})`)
      .neq("content_type", "pop")
      .order("created_at", { ascending: false })
      .range(0, followingLimit - 1),
    fetchQuoteRepostRows(client, followingIds, followingLimit),
  ]);
  throwIfError(result.error);
  const combined = [...rankedDropRows(result.data, followingLimit), ...quoteShares]
    .sort((a,b) => Date.parse(b.quote_reposted_at ?? b.created_at) - Date.parse(a.quote_reposted_at ?? a.created_at))
    .slice(0,followingLimit);
  return hydrateImageAspectRatios(client, combined);
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
  return hydrateImageAspectRatios(client, rankedDropRows(result.data, trendingLimit));
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
