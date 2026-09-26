"use client";

import Image from "next/image";
import Link from "next/link";
import dynamic from "next/dynamic";
import { useEffect, useMemo, useState } from "react";

import { PostActions } from "@/components/home/post-actions";
import { haptic } from "@/lib/haptics";
import { beginSocialMutation, definitelyOffline, OFFLINE_ACTION_MESSAGE } from "@/lib/social-mutation-guard";
import { RepostSheetChoices } from "@/components/ui/repost-sheet-choices";
import { Toast, useToast } from "@/components/ui/toast";
import { postMediaAspectRatio } from "@/lib/feed";
import { fetchQuoteEngagement, toggleQuoteLike, toggleQuoteRepost, toggleQuoteSave, type QuoteEngagement } from "@/lib/quote-actions";
import { deleteMountCache } from "@/lib/mount-cache";
import { shareOrCopyLink } from "@/lib/share";
import { createPortal } from "react-dom";

import { RichPostText } from "@/components/rich-post-text";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { DefaultProfileAvatar } from "@/components/ui/default-profile-avatar";
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
  const [failedSrc, setFailedSrc] = useState<string | null>(null);
  if (!src || failedSrc === src) {
    return <DefaultProfileAvatar className="wyn-quote-feed-avatar fallback" size={size} label={`รูปโปรไฟล์ของ ${label}`} />;
  }
  return <Image className="wyn-quote-feed-avatar" src={src} alt="" width={size} height={size} sizes={small ? "30px" : "40px"} onError={() => setFailedSrc(src)} />;
}

/** All actions below target redrops.id (this Quote), not the embedded original Drop. */
export function QuoteFeedCard({
  row,
  viewerId,
  initialQuoteState,
  commentCountDelta = 0,
  onQuoteRepostChanged,
  onDeleted,
}: {
  row: HomeFeedRow;
  viewerId: string;
  initialQuoteState?: QuoteEngagement | null;
  commentCountDelta?: number;
  onQuoteRepostChanged?: (actorId: string, quoteId: string, removed: boolean) => void;
  onDeleted?: (actorId: string, quoteId: string) => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [reason, setReason] = useState<(typeof reportReasons)[number]["value"]>("spam");
  const [detail, setDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [reported, setReported] = useState(false);
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  // Never copy row.like_count: home_feed's row is the ORIGINAL Drop.
  const [engagement, setEngagement] = useState<QuoteEngagement | null>(initialQuoteState ?? null);
  const [engagementError, setEngagementError] = useState("");
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
  const liked = engagement?.liked ?? false;
  const redropped = engagement?.redropped ?? false;
  const saved = engagement?.saved ?? false;
  const canRedropOriginal = row.audience == null || row.audience === "everyone";
  const availableMedia = media.filter((url) => !failedMedia.has(url));
  const firstImage = availableMedia[0];
  const mediaRatio = postMediaAspectRatio(row, availableMedia.length > 1);

  useEffect(() => {
    if (!client || !quoteId || initialQuoteState) return;
    let live = true;
    void fetchQuoteEngagement(client, [quoteId]).then((states) => {
      if (!live) return;
      const next = states.get(quoteId);
      if (next) { setEngagement(next); setEngagementError(""); }
      else setEngagementError("ไม่สามารถโหลดกิจกรรมโพสต์อ้างอิงได้");
    }).catch(() => { if (live) setEngagementError("โหลดกิจกรรมโพสต์อ้างอิงไม่สำเร็จ"); });
    return () => { live = false; };
  }, [client, quoteId, initialQuoteState]);

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

  const reloadEngagement = async () => {
    if (!client || !quoteId) return;
    try {
      const latest = await fetchQuoteEngagement(client, [quoteId]);
      const state = latest.get(quoteId);
      if (!state) { setEngagementError("ไม่พบกิจกรรมของโพสต์อ้างอิงนี้"); return; }
      setEngagement(state);
      setEngagementError("");
    } catch {
      setEngagementError("โหลดกิจกรรมโพสต์อ้างอิงไม่สำเร็จ");
      showToast("อัปเดตสถานะโพสต์อ้างอิงไม่สำเร็จ");
    }
  };
  const likeQuote = async () => {
    if (!client || !viewerId || !quoteId || !engagement || busy) return;
    if (definitelyOffline()) { showToast(OFFLINE_ACTION_MESSAGE); return; }
    const releaseMutation = beginSocialMutation("quote", viewerId, quoteId, "like");
    if (!releaseMutation) return;
    const before = engagement;
    if (!liked) haptic();
    setBusy(true);
    setEngagement({ ...before, liked: !liked, likeCount: Math.max(0, before.likeCount + (liked ? -1 : 1)) });
    try {
      await toggleQuoteLike(client, viewerId, quoteId, liked);
    }
    catch {
      setEngagement(before);
      await reloadEngagement();
      showToast("กดถูกใจโพสต์อ้างอิงไม่สำเร็จ");
    } finally { setBusy(false); releaseMutation(); }
  };
  const saveQuote = async () => {
    if (!client || !viewerId || !quoteId || !engagement || busy) return;
    if (definitelyOffline()) { showToast(OFFLINE_ACTION_MESSAGE); return; }
    const releaseMutation = beginSocialMutation("quote", viewerId, quoteId, "save");
    if (!releaseMutation) return;
    const before = engagement;
    if (!saved) haptic();
    setBusy(true);
    setEngagement({ ...before, saved: !saved });
    try {
      await toggleQuoteSave(client, viewerId, quoteId, saved);
      deleteMountCache(`bookmarks:${viewerId}`);
      showToast(saved ? "นำออกจากรายการที่บันทึกแล้ว" : "บันทึกโพสต์แล้ว");
    } catch {
      setEngagement(before);
      await reloadEngagement();
      showToast("บันทึกโพสต์อ้างอิงไม่สำเร็จ");
    } finally { setBusy(false); releaseMutation(); }
  };
  const repostQuote = async () => {
    if (!client || !viewerId || !quoteId || !engagement || busy) return;
    if (definitelyOffline()) { showToast(OFFLINE_ACTION_MESSAGE); return; }
    const releaseMutation = beginSocialMutation("quote", viewerId, quoteId, "redrop");
    if (!releaseMutation) return;
    const before = engagement;
    setBusy(true);
    setError("");
    setEngagement({ ...before, redropped: !redropped, redropCount: Math.max(0, before.redropCount + (redropped ? -1 : 1)) });
    try {
      await toggleQuoteRepost(client, viewerId, quoteId, redropped);
      deleteMountCache(`profile-feed:${viewerId}:redrops`);
      onQuoteRepostChanged?.(viewerId, quoteId, redropped);
      setActionSheet(null);
    } catch {
      setEngagement(before);
      await reloadEngagement();
      setError("รีโพสต์อ้างอิงไม่สำเร็จ");
    } finally { setBusy(false); releaseMutation(); }
  };
  const quoteOriginal = async () => {
    if (!client || !viewerId || !quote.trim() || busy || !canRedropOriginal) return;
    if (definitelyOffline()) { showToast(OFFLINE_ACTION_MESSAGE); return; }
    const releaseMutation = beginSocialMutation("drop", viewerId, row.id, "quote");
    if (!releaseMutation) return;
    setBusy(true); setError("");
    try {
      const result = await client.from("redrops").insert({ drop_id: row.id, redropper_id: viewerId, quote_text: quote.trim() });
      if (result.error) throw result.error;
      setQuote(""); setActionSheet(null);
      showToast("โพสต์อ้างอิงแล้ว");
    } catch { setError("อ้างอิงโพสต์ต้นฉบับไม่สำเร็จ"); }
    finally { setBusy(false); releaseMutation(); }
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
    const client = getSupabaseBrowserClient();
    if (!client) { setError("กรุณาเข้าสู่ระบบ"); return; }
    setBusy(true);
    setError("");
    try {
      const result = await client.from("redrops").delete().eq("id", quoteId).eq("redropper_id", viewerId).not("quote_text", "is", null);
      if (result.error) throw result.error;
      setMenuOpen(false);
      setDeleteConfirm(false);
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
        {row.quote_reposter_id ? <div className="wyn-post-redrop-line"><WynosIcon name="repost" size={16} strokeWidth={2} /> รีโพสต์โดย {row.quote_reposter_username || "ผู้ใช้ WYNOS"} · {row.quote_reposted_at ? relativeTimeTh(row.quote_reposted_at) : ""}</div> : null}
        <header className="wyn-quote-feed-head">
          <Link href={`/profile/${actorId}`} className="wyn-quote-feed-byline">
            <strong>{quoteName}</strong>
            {row.redropper_is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
            <small>· {relativeTimeTh(row.created_at)}</small>
          </Link>
          {quoteId ? <button type="button" aria-label="ตัวเลือกอ้างอิง" onClick={() => { setError(""); setDeleteConfirm(false); setMenuOpen(true); }}><WynosIcon name="more" size={20} /></button> : null}
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
        <div className="wyn-quote-feed-actions" aria-label="กิจกรรมโพสต์อ้างอิง">
          {engagement ? <PostActions
            liked={liked}
            likeCount={engagement.likeCount}
            commentCount={Math.max(0, engagement.commentCount + commentCountDelta)}
            canRedrop
            redropped={redropped}
            redropCount={engagement.redropCount}
            saved={saved}
            onLike={() => void likeQuote()}
            commentHref={`/quote/${quoteId}#comments`}
            onRedrop={() => { if (!viewerId) { showToast("กรุณาเข้าสู่ระบบ"); return; } setActionSheet("redrop"); }}
            onShare={() => void shareQuote()}
            onSave={() => void saveQuote()}
            modernFeed
          /> : <div className="wyn-quote-feed-state" role="status">
            {engagementError ? <button type="button" onClick={() => { setEngagementError(""); void reloadEngagement(); }}>โหลดกิจกรรมไม่สำเร็จ · ลองใหม่</button> : "กำลังโหลดกิจกรรมโพสต์อ้างอิง…"}
          </div>}
        </div>
        {reported ? <p className="wyn-quote-feed-notice" role="status">ส่งรายงานแล้ว</p> : null}
      </div>
      {actionSheet === "redrop" && typeof document !== "undefined" ? createPortal(
        <div className="route-modal-backdrop wyn-quote-feed-sheet-backdrop" role="presentation" onClick={() => setActionSheet(null)} onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()} onTouchEnd={(event) => event.stopPropagation()}>
          <section className="wyn-quote-feed-sheet" role="dialog" aria-modal="true" aria-label="รีโพสต์อ้างอิง" onClick={(event) => event.stopPropagation()}>
            <div className="wyn-quote-feed-sheet-grip" aria-hidden="true" />
            <RepostSheetChoices reposted={redropped} busy={busy} error={error} onRepost={() => void repostQuote()} onQuote={() => { setError(""); setActionSheet("quote"); }} quoteLabel="อ้างอิงโพสต์ต้นฉบับ" />
            <button type="button" className="wyn-quote-feed-sheet-cancel" onClick={() => setActionSheet(null)}>ยกเลิก</button>
          </section>
        </div>, document.body,
      ) : null}
      {actionSheet === "quote" ? <QuoteRedropComposer row={row} viewerId={viewerId} value={quote} busy={busy} error={error} onChange={setQuote} onClose={() => { setActionSheet(null); setQuote(""); setError(""); }} onSubmit={() => void quoteOriginal()} /> : null}
      {menuOpen && typeof document !== "undefined" ? createPortal(
        <div className="route-modal-backdrop wyn-quote-feed-sheet-backdrop" role="presentation" onClick={() => { if (!busy) { setMenuOpen(false); setDeleteConfirm(false); } }} onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()} onTouchEnd={(event) => event.stopPropagation()}>
          <section className="wyn-quote-feed-sheet wyn-quote-feed-menu-sheet" role="dialog" aria-modal="true" aria-label={own ? "จัดการอ้างอิง" : "รายงานอ้างอิง"} onClick={(event) => event.stopPropagation()}>
            <div className="wyn-quote-feed-sheet-grip" aria-hidden="true" />
            {own ? (deleteConfirm ? (
              <div className="wyn-quote-feed-delete-confirm">
                <strong>ลบโพสต์อ้างอิงนี้?</strong>
                <p>ลบเฉพาะโพสต์อ้างอิงของคุณ โพสต์ต้นฉบับยังอยู่</p>
                <div className="wyn-quote-feed-delete-actions">
                  <button type="button" disabled={busy} onClick={() => setDeleteConfirm(false)}>กลับ</button>
                  <button type="button" className="danger" disabled={busy} onClick={() => void remove()}>ยืนยันการลบ</button>
                </div>
              </div>
            ) : (
              <>
                <button type="button" className="danger" disabled={busy} onClick={() => setDeleteConfirm(true)}><WynosIcon name="trash" size={21} />ลบอ้างอิง</button>
                <p className="wyn-quote-feed-sheet-hint">ลบเฉพาะโพสต์อ้างอิงของคุณ ไม่กระทบโพสต์ต้นฉบับ</p>
              </>
            )) : reportOpen ? (
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
            <button type="button" className="wyn-quote-feed-sheet-cancel" disabled={busy} onClick={() => { setMenuOpen(false); setDeleteConfirm(false); }}>ยกเลิก</button>
          </section>
        </div>, document.body,
      ) : null}
      <Toast message={toastMessage} />
    </article>
  );
}
