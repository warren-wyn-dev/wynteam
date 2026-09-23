"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";
import { QuoteFeedCard } from "@/components/quote-feed-card";
import type { HomeFeedRow } from "@/lib/feed";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

/** A stable direct link for sharing an authored Quote, not its source Drop. */
export function QuoteDetailRoute({ quoteId }: { quoteId: string }) {
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [viewerId, setViewerId] = useState("");
  const [row, setRow] = useState<HomeFeedRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!client || !quoteId) {
      setError("ไม่สามารถเปิดโพสต์นี้ได้");
      setLoading(false);
      return;
    }
    let live = true;
    void Promise.all([
      client.auth.getUser(),
      client.from("home_feed").select("*").eq("redrop_id", quoteId)
        .eq("content_type", "drop").maybeSingle(),
    ]).then(([auth, result]) => {
      if (!live) return;
      setViewerId(auth.data.user?.id ?? "");
      if (result.error) setError("โหลดโพสต์ไม่สำเร็จ");
      else if (!result.data) setError("ไม่พบโพสต์นี้");
      else setRow(result.data as HomeFeedRow);
    }).catch(() => { if (live) setError("โหลดโพสต์ไม่สำเร็จ"); })
      .finally(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [client, quoteId]);

  return (
    <AppChrome
      title="โพสต์"
      userId={viewerId}
      showBottomNav={false}
      onBack={() => {
        if (window.history.length > 1) router.back();
        else router.push(row?.redropper_id ? `/profile/${row.redropper_id}` : "/");
      }}
    >
      {loading ? <LoadingState /> : row ? (
        <QuoteFeedCard row={row} viewerId={viewerId} onDeleted={(actorId) => router.replace(`/profile/${actorId}`)} />
      ) : <EmptyState>{error || "ไม่พบโพสต์นี้"}</EmptyState>}
    </AppChrome>
  );
}
