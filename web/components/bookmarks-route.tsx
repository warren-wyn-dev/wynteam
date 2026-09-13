"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, DropPreviewCard, EmptyState, LoadingState } from "@/components/phase3-ui";
import type { HomeFeedRow } from "@/lib/feed";

function BookmarksInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

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

  return <AppChrome title="บันทึกไว้" userId={userId} backHref="/" showBottomNav={false}>{error ? <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load(0, false)}>ลองใหม่</button></div> : loading && !rows.length ? <LoadingState /> : !rows.length ? <EmptyState>ยังไม่มีโพสต์ที่บันทึกไว้</EmptyState> : <div className="bookmarks-list">{rows.map((row) => <DropPreviewCard row={row} key={row.id} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>}</AppChrome>;
}

export function BookmarksRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <BookmarksInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
