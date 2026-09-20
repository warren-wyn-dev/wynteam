"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, DropPreviewCard, EmptyState, LoadingState } from "@/components/phase3-ui";
import type { HomeFeedRow } from "@/lib/feed";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";

type BookmarksSnapshot = { rows: HomeFeedRow[]; page: number; hasMore: boolean };

function BookmarksInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const cacheKey = `bookmarks:${userId}`;
  const cached = getMountCache<BookmarksSnapshot>(cacheKey);
  const [rows, setRows] = useState<HomeFeedRow[]>(cached?.rows ?? []);
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    setMountCache(cacheKey, { rows, page, hasMore });
  }, [cacheKey, rows, page, hasMore]);

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true); setError("");
    try {
      const from = nextPage * 21;
      const result = await client.from("saved_feed").select("*").neq("content_type", "pop").order("saved_at", { ascending: false }).range(from, from + 20);
      if (result.error) throw result.error;
      const next = (result.data ?? []) as HomeFeedRow[];
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 21);
    } catch (e) {
      setError(e instanceof Error ? e.message : "โหลดรายการที่บันทึกไว้ไม่สำเร็จ");
    } finally { setLoading(false); }
  }, [client]);

  useEffect(() => { void load(0, false); }, [load]);

  // GA (2026-09-20, Founder decision): was staged-rollout-gated to
  // developer accounts (WYN-125/WYN-182) — Founder asked to widen it to
  // everyone.
  const pull = usePullToRefresh({ enabled: true, onRefresh: () => load(0, false) });

  return <AppChrome title="บันทึกไว้" userId={userId} backHref="/" showBottomNav={false}>
    {pull.pullDistance > 0 || pull.refreshing ? (
      <div
        aria-label={pull.refreshing ? "กำลังรีเฟรชรายการที่บันทึกไว้" : "ลากลงเพื่อรีเฟรช"}
        aria-live="polite"
        style={{ height: 0, position: "relative", zIndex: 6, pointerEvents: "none" }}
      >
        <div
          className="route-system-spinner tiny"
          style={{
            position: "absolute",
            top: pull.refreshing ? 10 : Math.max(4, Math.min(18, pull.pullDistance * 0.2)),
            left: "50%",
            opacity: pull.refreshing ? 1 : Math.max(0.22, Math.min(1, pull.pullDistance / 54)),
            transform: `translateX(-50%) scale(${pull.refreshing ? 1 : Math.max(0.78, Math.min(1, pull.pullDistance / 54))})`,
            transition: pull.refreshing ? "top 140ms ease, opacity 140ms ease, transform 140ms ease" : "none",
          }}
        />
      </div>
    ) : null}
    <div onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
      {error ? <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load(0, false)}>ลองใหม่</button></div> : loading && !rows.length ? <LoadingState /> : !rows.length ? <EmptyState>ยังไม่มีโพสต์ที่บันทึกไว้</EmptyState> : <div className="bookmarks-list">{rows.map((row) => <DropPreviewCard row={row} key={row.id} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>}
    </div>
  </AppChrome>;
}

export function BookmarksRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <BookmarksInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
