"use client";

import Image from "next/image";
import Link from "next/link";
import dynamic from "next/dynamic";
import { useEffect, useMemo, useState } from "react";

import { PostActions } from "@/components/home/post-actions";
import { RepostSheetChoices } from "@/components/ui/repost-sheet-choices";
import { Toast, useToast } from "@/components/ui/toast";
import { postMediaAspectRatio } from "@/lib/feed";
import { loadHomeViewerState, toggleDropLike, toggleDropRedrop, toggleDropSave, type HomeViewerState } from "@/lib/home-actions";
import { shareOrCopyLink } from "@/lib/share";
import { createPortal } from "react-dom";

import { RichPostText } from "@/components/rich-post-text";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const QuoteRedropComposer = dynamic(() => import("@/components/quote-redrop-composer").then((mod) => mod.QuoteRedropComposer));

const reportReasons = [
  { value: "spam", label: "สแปม" },
  { value: "scam", label: "หลอกลวง" },
  { value: "harassment", label: "คุกคาม" },
  { value: "other", label: "อื่น ๆ" },
] as const;

function QuoteAvatar({ src, label, small = false }: { src?: string | null; label: string; small?: boolean }) {
  const size = small ? 30 : 40;
  const [failed, setFailed] = useState(false);
  if (!src || failed) {
    return <span className="wyn-quote-feed-avatar fallback" style={small ? { width: size, height: size } : undefined}>{label.trim().slice(0, 1).toUpperCase() || "W"}</span>;
  }
  return <Image className="wyn-quote-feed-avatar" src={src} alt="" width={size} height={size} sizes={small ? "30px" : "40px"} onError={() => setFailed(true)} />;
}

/**
 * Quotes are separate authored posts. Until quote-specific reactions exist in
 * the backend, label the action strip explicitly as actions on the ORIGINAL
 * Drop; never present original engagement counts as counts for the quote.
 */
export function QuoteFeedCard({
  row,
  viewerId,
  onDeleted,
}: {
  row: HomeFeedRow;
  viewerId: string;
  onDeleted?: (actorId: string, quoteId: string) => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [reason, setReason] = useState<(typeof reportReasons)[number]["value"]>("spam");
  const [detail, setDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [reported, setReported] = useState(false);
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [likeCount, setLikeCount] = useState(row.like_count ?? 0);
  const [redropCount, setRedropCount] = useState(row.redrop_count ?? 0);
  const [actionSheet, setActionSheet] = useState<"redrop" | "quote" | null>(null);
  const [quote, setQuote] = useState("");
  const [media, setMedia] = useState<string[]>(row.image_url ? [row.image_url] : []);
  const [failedMedia, setFailedMedia] = useState<Set<string>>(() => new Set());
  const { toastMessage, showToast } = useToast();
  const actorId = row.redropper_id || "";
  const quoteId = row.redrop_id || "";
  const own = Boolean(actorId && viewerId === actorId);
  const quoteName = row.redropper_display_name?.trim() || row.redropper_username || "WYNOS";
  const originalName = authorLabel(row);
  const liked = viewer?.likedDropIds.has(row.id) ?? false;
  const redropped = viewer?.redroppedDropIds.has(row.id) ?? false;
  const saved = viewer?.savedDropIds.has(row.id) ?? false;
  const canRedrop = row.audience == null || row.audience === "everyone";
  const availableMedia = media.filter((url) => !failedMedia.has(url));
  const firstImage = availableMedia[0];
  const mediaRatio = postMediaAspectRatio(row, availableMedia.length > 1);

  useEffect(() => {
    if (!client || !viewerId) return;
    let live = true;
    void loadHomeViewerState(client, viewerId, [row]).then((state) => {
      if (live) setViewer(state);
    }).catch(() => { if (live) showToast("โหลดสถานะโพสต์ไม่สำเร็จ"); });
    return () => { live = false; };
  }, [client, viewerId, row, showToast]);

  // home_feed may have an incomplete/old image_url. Read the source image
  // rows (also supports multi-image posts) instead of displaying a blank box.
  useEffect(() => {
    if (!client || !(row.image_url || (row.image_count ?? 0) > 0)) return;
    let live = true;
    void client.from("drop_images").select("image_url,position").eq("drop_id", row.id)
      .order("position", { ascending: true }).then(({ data, error: imageError }) => {
        if (!live || imageError) return;
        const urls = (data ?? []).map((item) => String(item.image_url ?? "")).filter(Boolean);
        const fallback = row.image_url ? [row.image_url] : [];
        setMedia([...new Set([...urls, ...fallback])]);
      });
    return () => { live = false; };
  }, [client, row.id, row.image_url, row.image_count]);

  const reloadViewer = async () => {
    if (!client || !viewerId) return;
    try { setViewer(await loadHomeViewerState(client, viewerId, [row])); }
    catch { showToast("อัปเดตสถานะไม่สำเร็จ"); }
  };
  const patchViewer = (key: "likedDropIds" | "redroppedDropIds" | "savedDropIds", value: boolean) => {
    setViewer((current) => {
      if (!current) return current;
      const next = new Set(current[key]);
      if (value) next.add(row.id); else next.delete(row.id);
      return { ...current, [key]: next };
    });
  };
  const likeOriginal = async () => {
    if (!client || !viewerId || !viewer || busy) { showToast("กรุณาเข้าสู่ระบบ"); return; }
    patchViewer("likedDropIds", !liked);
    setLikeCount((count) => Math.max(0, count + (liked ? -1 : 1)));
    try { await toggleDropLike(client, viewerId, row.id, liked); }
    catch { setLikeCount(row.like_count ?? 0); await reloadViewer(); showToast("กดถูกใจไม่สำเร็จ"); }
  };
  const saveOriginal = async () => {
    if (!client || !viewerId || !viewer || busy) { showToast("กรุณาเข้าสู่ระบบ"); return; }
    patchViewer("savedDropIds", !saved);
    try { await toggleDropSave(client, viewerId, row.id, saved); }
    catch { await reloadViewer(); showToast("บันทึกโพสต์ไม่สำเร็จ"); }
  };
  const redropOriginal = async () => {
    if (!client || !viewerId || !viewer || busy || !canRedrop) return;
    setBusy(true);
    setError("");
    patchViewer("redroppedDropIds", !redropped);
    setRedropCount((count) => Math.max(0, count + (redropped ? -1 : 1)));
    try {
      await toggleDropRedrop(client, viewerId, row.id, redropped);
      setActionSheet(null);
    } catch {
      setRedropCount(row.redrop_count ?? 0);
      await reloadViewer();
      setError("รีโพสต์ต้นฉบับไม่สำเร็จ");
    } finally { setBusy(false); }
  };
  const quoteOriginal = async () => {
    if (!client || !viewerId || !quote.trim() || busy || !canRedrop) return;
    setBusy(true); setError("");
    try {
      const result = await client.from("redrops").insert({ drop_id: row.id, redropper_id: viewerId, quote_text: quote.trim() });
      if (result.error) throw result.error;
      setRedropCount((count) => count + 1);
      setQuote(""); setActionSheet(null);
      showToast("โพสต์อ้างอิงแล้ว");
    } catch { setError("อ้างอิงโพสต์ต้นฉบับไม่สำเร็จ"); }
    finally { setBusy(false); }
  };
  const shareQuote = async () => {
    const url = quoteId
      ? `${window.location.origin}/quote/${quoteId}`
      : `${window.location.origin}/drop/${row.id}`;
    await shareOrCopyLink({ title: quoteName, text: row.quote_text || "WYNOS", url }, showToast);
  };

  useEffect(() => {
    if (!menuOpen) return;
    const old = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const key = (event: KeyboardEvent) => { if (event.key === "Escape" && !busy) setMenuOpen(false); };
    document.addEventListener("keydown", key);
    return () => {
      document.body.style.overflow = old;
      document.removeEventListener("keydown", key);
    };
  }, [menuOpen, busy]);

  const remove = async () => {
    if (!own || !quoteId || busy) return;
    if (!window.confirm("ลบโพสต์อ้างอิงนี้?")) return;
    const client = getSupabaseBrowserClient();
    if (!client) { setError("กรุณาเข้าสู่ระบบ"); return; }
    setBusy(true);
    setError("");
    try {
      const result = await client.from("redrops").delete().eq("id", quoteId).eq("redropper_id", viewerId).not("quote_text", "is", null);
      if (result.error) throw result.error;
      setMenuOpen(false);
      onDeleted?.(viewerId, quoteId);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "ลบอ้างอิงไม่สำเร็จ");
    } finally { setBusy(false); }
  };

  const report = async () => {
    if (own || !quoteId || busy) return;
    if (reason === "other" && !detail.trim()) { setError("กรุณาระบุรายละเอียด"); return; }
    const client = getSupabaseBrowserClient();
    if (!client) { setError("กรุณาเข้าสู่ระบบ"); return; }
    setBusy(true);
    setError("");
    try {
      const result = await client.rpc("submit_report", {
        p_target_type: "redrop",
        p_target_id: quoteId,
        p_category: reason,
        p_detail: reason === "other" ? detail.trim() : null,
      });
      if (result.error) throw result.error;
      setReported(true);
      setMenuOpen(false);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "ส่งรายงานไม่สำเร็จ");
    } finally { setBusy(false); }
  };

  return (
    <article id={quoteId ? `quote-${quoteId}` : undefined} className="wyn-quote-feed-card" aria-label="โพสต์อ้างอิง">
      <Link className="wyn-quote-feed-author-avatar" href={`/profile/${actorId}`}>
        <QuoteAvatar src={row.redropper_avatar_url} label={quoteName} />
      </Link>
      <div className="wyn-quote-feed-body">
        <header className="wyn-quote-feed-head">
          <Link href={`/profile/${actorId}`} className="wyn-quote-feed-byline">
            <strong>{quoteName}</strong>
            {row.redropper_is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
            <small>· {relativeTimeTh(row.created_at)}</small>
          </Link>
          {quoteId ? <button type="button" aria-label="ตัวเลือกอ้างอิง" onClick={() => { setError(""); setMenuOpen(true); }}><WynosIcon name="more" size={20} /></button> : null}
        </header>
        <RichPostText className="wyn-quote-feed-comment" value={row.quote_text || ""} />
        <Link className="wyn-quote-feed-original" href={`/drop/${row.id}`} aria-label={`ดูโพสต์ต้นฉบับของ ${originalName}`}>
          <span className="wyn-quote-feed-original-head">
            <QuoteAvatar small src={row.author_avatar_url} label={originalName} />
            <span className="wyn-quote-feed-original-byline">
              <strong>{originalName}</strong>
              {row.author_is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
              {row.author_username ? <small>@{row.author_username}</small> : null}
            </span>
          </span>
          {row.caption ? <span className="wyn-quote-feed-original-text">{row.caption.split(/(#[\p{L}\p{N}_]+)/gu).map((part, index) => part.startsWith("#") ? <span className="wyn-quote-feed-tag" key={index}>{part}</span> : part)}</span> : null}
          {firstImage ? <span className="wyn-quote-feed-original-image" style={{ aspectRatio: String(mediaRatio) }}><Image src={firstImage} alt="รูปจากโพสต์ต้นฉบับ" width={800} height={Math.round(800 / (mediaRatio || 1))} sizes="(max-width: 680px) calc(100vw - 98px), 510px" onError={() => setFailedMedia((current) => new Set([...current, firstImage]))} />{availableMedia.length > 1 ? <span className="wyn-quote-feed-image-count">1/{availableMedia.length}</span> : null}</span> : null}
        </Link>
        <div className="wyn-quote-feed-engagement-label">โต้ตอบกับโพสต์ต้นฉบับ</div>
        <div className="wyn-quote-feed-actions">
          <PostActions
            liked={liked}
            likeCount={likeCount}
            commentCount={row.comment_count ?? 0}
            canRedrop={canRedrop}
            redropped={redropped}
            redropCount={redropCount}
            saved={saved}
            onLike={() => void likeOriginal()}
            commentHref={`/drop/${row.id}#comments`}
            onRedrop={() => { if (!viewerId) { showToast("กรุณาเข้าสู่ระบบ"); return; } setActionSheet("redrop"); }}
            onShare={() => void shareQuote()}
            onSave={() => void saveOriginal()}
            modernFeed
          />
        </div>
        {reported ? <p className="wyn-quote-feed-notice" role="status">ส่งรายงานแล้ว</p> : null}
      </div>
      {actionSheet === "redrop" && typeof document !== "undefined" ? createPortal(
        <div className="route-modal-backdrop wyn-quote-feed-sheet-backdrop" role="presentation" onClick={() => setActionSheet(null)} onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()} onTouchEnd={(event) => event.stopPropagation()}>
          <section className="wyn-quote-feed-sheet" role="dialog" aria-modal="true" aria-label="โต้ตอบกับโพสต์ต้นฉบับ" onClick={(event) => event.stopPropagation()}>
            <div className="wyn-quote-feed-sheet-grip" aria-hidden="true" />
            <RepostSheetChoices reposted={redropped} busy={busy} error={error} onRepost={() => void redropOriginal()} onQuote={() => { setError(""); setActionSheet("quote"); }} />
            <button type="button" className="wyn-quote-feed-sheet-cancel" onClick={() => setActionSheet(null)}>ยกเลิก</button>
          </section>
        </div>, document.body,
      ) : null}
      {actionSheet === "quote" ? <QuoteRedropComposer row={row} viewerId={viewerId} value={quote} busy={busy} error={error} onChange={setQuote} onClose={() => { setActionSheet(null); setQuote(""); setError(""); }} onSubmit={() => void quoteOriginal()} /> : null}
      {menuOpen && typeof document !== "undefined" ? createPortal(
        <div className="route-modal-backdrop wyn-quote-feed-sheet-backdrop" role="presentation" onClick={() => !busy && setMenuOpen(false)} onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()} onTouchEnd={(event) => event.stopPropagation()}>
          <section className="wyn-quote-feed-sheet" role="dialog" aria-modal="true" aria-label={own ? "จัดการอ้างอิง" : "รายงานอ้างอิง"} onClick={(event) => event.stopPropagation()}>
            <div className="wyn-quote-feed-sheet-grip" aria-hidden="true" />
            {own ? (
              <button type="button" className="danger" disabled={busy} onClick={() => void remove()}><WynosIcon name="trash" size={21} />ลบอ้างอิง</button>
            ) : reportOpen ? (
              <form className="wyn-quote-feed-report" onSubmit={(event) => { event.preventDefault(); void report(); }}>
                <strong>รายงานอ้างอิง</strong>
                {reportReasons.map((item) => <label key={item.value}><input type="radio" name={`quote-report-${quoteId}`} value={item.value} checked={reason === item.value} onChange={() => setReason(item.value)} />{item.label}</label>)}
                {reason === "other" ? <textarea value={detail} onChange={(event) => setDetail(event.target.value)} maxLength={1000} placeholder="รายละเอียดเพิ่มเติม" /> : null}
                <button type="submit" className="wyn-quote-feed-report-submit" disabled={busy}>ส่งรายงาน</button>
              </form>
            ) : (
              <button type="button" onClick={() => setReportOpen(true)}><WynosIcon name="flag" size={21} />รายงานอ้างอิง</button>
            )}
            {error ? <p className="route-error" role="alert">{error}</p> : null}
            <button type="button" className="wyn-quote-feed-sheet-cancel" disabled={busy} onClick={() => setMenuOpen(false)}>ยกเลิก</button>
          </section>
        </div>, document.body,
      ) : null}
      <Toast message={toastMessage} />
    </article>
  );
}
