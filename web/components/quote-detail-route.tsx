"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { QuoteFeedCard } from "@/components/quote-feed-card";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { addQuoteComment, fetchQuoteComments, removeQuoteComment, type QuoteComment } from "@/lib/quote-actions";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { SupabaseClient } from "@supabase/supabase-js";

function QuoteComments({
  client,
  quoteId,
  viewerId,
  onCountChange,
}: {
  client: SupabaseClient;
  quoteId: string;
  viewerId: string;
  onCountChange: (delta: number) => void;
}) {
  const [rows, setRows] = useState<QuoteComment[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [text, setText] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    let live = true;
    void fetchQuoteComments(client, quoteId).then((first) => {
      if (!live) return;
      setRows(first);
      setHasMore(first.length === 30);
      setLoading(false);
    }).catch(() => {
      if (live) { setError("โหลดความคิดเห็นไม่สำเร็จ"); setLoading(false); }
    });
    return () => { live = false; };
  }, [client, quoteId]);

  const loadMore = async () => {
    if (loading) return;
    setLoading(true);
    try {
      const next = await fetchQuoteComments(client, quoteId, page + 1);
      setRows((current) => [...current, ...next.filter((item) => !current.some((row) => row.id === item.id))]);
      setPage((value) => value + 1);
      setHasMore(next.length === 30);
    } catch { setError("โหลดความคิดเห็นเพิ่มเติมไม่สำเร็จ"); }
    finally { setLoading(false); }
  };
  const send = async () => {
    if (!viewerId || !text.trim() || sending) return;
    setSending(true);
    setError("");
    try {
      await addQuoteComment(client, viewerId, quoteId, text);
      setText("");
      const fresh = await fetchQuoteComments(client, quoteId);
      setRows(fresh);
      setPage(0);
      setHasMore(fresh.length === 30);
      onCountChange(1);
    } catch { setError("ส่งความคิดเห็นไม่สำเร็จ"); }
    finally { setSending(false); }
  };
  const remove = async (comment: QuoteComment) => {
    if (comment.authorId !== viewerId || sending) return;
    setSending(true);
    setError("");
    try {
      await removeQuoteComment(client, viewerId, comment.id);
      setRows((current) => current.filter((item) => item.id !== comment.id));
      onCountChange(-1);
    } catch { setError("ลบความคิดเห็นไม่สำเร็จ"); }
    finally { setSending(false); }
  };

  return (
    <section className="detail-comments wyn-quote-comments" id="comments">
      <h2>ความคิดเห็นของโพสต์อ้างอิง</h2>
      {error ? <p className="route-error" role="alert">{error}</p> : null}
      {loading && !rows.length ? <LoadingState /> : !rows.length ? (
        <EmptyState>ยังไม่มีความคิดเห็นของโพสต์อ้างอิงนี้</EmptyState>
      ) : rows.map((comment) => (
        <div className="detail-comment" key={comment.id}>
          <Link href={\`/profile/\${comment.authorId}\`} className="detail-comment-avatar">
            <Avatar src={comment.authorAvatarUrl} label={comment.authorUsername} size={36} />
          </Link>
          <div className="detail-comment-copy">
            <div className="detail-comment-author-line">
              <strong>{comment.authorDisplayName || comment.authorUsername}
                {comment.authorVerified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
              </strong>
              <small>{relativeTimeTh(comment.createdAt)}</small>
            </div>
            <p>{comment.text}</p>
          </div>
          {comment.authorId === viewerId ? (
            <button className="detail-comment-delete" type="button" aria-label="ลบความคิดเห็น" disabled={sending} onClick={() => void remove(comment)}>
              <WynosIcon name="trash" size={17} />
            </button>
          ) : null}
        </div>
      ))}
      {hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void loadMore()}>ดูความคิดเห็นเพิ่มเติม</button> : null}
      {viewerId ? (
        <form className="detail-comment-form" onSubmit={(event) => { event.preventDefault(); void send(); }}>
          <input value={text} onChange={(event) => setText(event.target.value)} maxLength={500} placeholder="แสดงความคิดเห็นต่อโพสต์อ้างอิง…" aria-label="ความคิดเห็นต่อโพสต์อ้างอิง" />
          <button type="submit" aria-label="ส่งความคิดเห็น" disabled={sending || !text.trim()}><WynosIcon name="send" size={19} /></button>
        </form>
      ) : <p className="route-notice">เข้าสู่ระบบเพื่อแสดงความคิดเห็น</p>}
    </section>
  );
}

/** Quote links and their comment feed never route to the original Drop. */
export function QuoteDetailRoute({ quoteId }: { quoteId: string }) {
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [viewerId, setViewerId] = useState("");
  const [row, setRow] = useState<HomeFeedRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [commentCountDelta, setCommentCountDelta] = useState(0);

  useEffect(() => {
    if (!client || !quoteId) return;
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
        else router.push(row?.redropper_id ? \`/profile/\${row.redropper_id}\` : "/");
      }}
    >
      {!client || !quoteId ? <EmptyState>ไม่สามารถเปิดโพสต์นี้ได้</EmptyState> : loading ? <LoadingState /> : row ? (
        <>
          <QuoteFeedCard row={row} viewerId={viewerId} commentCountDelta={commentCountDelta} onDeleted={(actorId) => router.replace(\`/profile/\${actorId}\`)} />
          <QuoteComments client={client} quoteId={quoteId} viewerId={viewerId} onCountChange={(delta) => setCommentCountDelta((current) => current + delta)} />
        </>
      ) : <EmptyState>{error || "ไม่พบโพสต์นี้"}</EmptyState>}
    </AppChrome>
  );
}
