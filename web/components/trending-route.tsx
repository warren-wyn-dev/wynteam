"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";
import { fetchTrendingHashtags, type RankedHashtag } from "@/lib/phase3-data";
import { getMountCache, setMountCache } from "@/lib/mount-cache";

const TOP_HASHTAG_LIMIT = 100;

function TrendingInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const cacheKey = `trending-top100:${userId}`;
  const cached = getMountCache<RankedHashtag[]>(cacheKey);
  const [hashtags, setHashtags] = useState<RankedHashtag[]>(cached ?? []);
  const [loading, setLoading] = useState(!cached);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const next = await fetchTrendingHashtags(client, TOP_HASHTAG_LIMIT);
      setHashtags(next);
      setMountCache(cacheKey, next);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "โหลดอันดับแฮชแท็กไม่สำเร็จ");
    } finally { setLoading(false); }
  }, [client, cacheKey]);

  useEffect(() => { void load(); }, [load]);

  return (
    <AppChrome title="อันดับแฮชแท็ก (Top 100)" userId={userId} backHref="/search" showBottomNav={false}>
      <div className="trending-top100-page">
        {error ? (
          <div className="route-empty">
            <p>{error}</p>
            <button className="route-secondary" type="button" disabled={loading} onClick={() => void load()}>ลองใหม่</button>
          </div>
        ) : loading && !hashtags.length ? (
          <LoadingState />
        ) : !hashtags.length ? (
          <EmptyState>ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้</EmptyState>
        ) : (
          <div className="hashtag-list trending-top100-list">
            {hashtags.map((item, index) => (
              <div className="hashtag-row flutter-rank-row" key={item.tag}>
                <b>{index + 1}</b>
                <span className="flutter-rank-copy">
                  <strong>#{item.tag}</strong>
                  <small>{item.postCount.toLocaleString("th-TH")} โพสต์ · กำลังนิยมใน ไทย</small>
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </AppChrome>
  );
}

export function TrendingRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <TrendingInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
