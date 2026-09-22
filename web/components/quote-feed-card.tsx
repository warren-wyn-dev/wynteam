"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useState } from "react";
import { createPortal } from "react-dom";

import { RichPostText } from "@/components/rich-post-text";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

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
    return <span className="wyn-quote-feed-avatar fallback" style={{ width: size, height: size }}>{label.trim().slice(0, 1).toUpperCase() || "W"}</span>;
  }
  return <Image className="wyn-quote-feed-avatar" src={src} alt="" width={size} height={size} sizes={small ? "30px" : "40px"} onError={() => setFailed(true)} />;
}

/**
 * An authored quote is its OWN feed card, with the original Drop embedded
 * beneath the author's commentary. The existing redrops schema does not yet
 * provide separate Like/Reply threads on a quote; don't show misleading
 * interaction counts or buttons bound to the original Drop as if they
 * belonged to this quote. The original remains directly accessible.
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
  const actorId = row.redropper_id || "";
  const quoteId = row.redrop_id || "";
  const own = Boolean(actorId && viewerId === actorId);
  const quoteName = row.redropper_display_name?.trim() || row.redropper_username || "WYNOS";
  const originalName = authorLabel(row);

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
    <article className="wyn-quote-feed-card" aria-label="โพสต์อ้างอิง">
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
          {quoteId && viewerId ? <button type="button" aria-label="ตัวเลือกอ้างอิง" onClick={() => { setError(""); setMenuOpen(true); }}><WynosIcon name="more" size={20} /></button> : null}
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
          {row.caption ? <span className="wyn-quote-feed-original-text">{row.caption}</span> : null}
          {row.image_url ? <span className="wyn-quote-feed-original-image"><Image src={row.image_url} alt="รูปจากโพสต์ต้นฉบับ" width={640} height={360} sizes="(max-width: 680px) calc(100vw - 98px), 510px" /></span> : null}
        </Link>
        {reported ? <p className="wyn-quote-feed-notice" role="status">ส่งรายงานแล้ว</p> : null}
      </div>
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
    </article>
  );
}
