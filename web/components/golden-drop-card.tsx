"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import Image from "next/image";
import Link from "next/link";

import { AnimatedHeart } from "@/components/ui/animated-heart";
import { CommentIcon, RepostIcon, SaveIcon } from "@/components/ui/post-action-icons";
import { Toast, useToast } from "@/components/ui/toast";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { WynosShareIcon } from "@/components/ui/wynos-share-icon";
import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type PointerEvent } from "react";

import { PostActions } from "@/components/home/post-actions";
import { RichPostText } from "@/components/rich-post-text";
import { authorLabel, postMediaAspectRatio, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { loadHomeViewerState, toggleDropLike, toggleDropRedrop, toggleDropSave, type HomeViewerState } from "@/lib/home-actions";
import { haptic } from "@/lib/haptics";
import { shareOrCopyLink } from "@/lib/share";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

type Sheet = "more" | "redrop" | "quote" | "report" | null;
type ReportCategory = "spam" | "scam" | "harassment" | "hate" | "sexual_content" | "violence" | "privacy" | "illegal_content" | "copyright" | "other";

const reportCategories: { value: ReportCategory; label: string }[] = [
  { value: "spam", label: "สแปม (Spam)" },
  { value: "scam", label: "หลอกลวง (Scam)" },
  { value: "harassment", label: "คุกคาม/กลั่นแกล้ง (Harassment)" },
  { value: "hate", label: "ความเกลียดชัง (Hate)" },
  { value: "sexual_content", label: "เนื้อหาทางเพศ (Sexual Content)" },
  { value: "violence", label: "ความรุนแรง (Violence)" },
  { value: "privacy", label: "ละเมิดความเป็นส่วนตัว (Privacy)" },
  { value: "illegal_content", label: "ผิดกฎหมาย (Illegal Content)" },
  { value: "copyright", label: "ละเมิดลิขสิทธิ์ (Copyright)" },
  { value: "other", label: "อื่น ๆ (Other)" },
];

function Avatar({ src, label }: { src?: string | null; label: string }) {
  const [failed, setFailed] = useState(false);
  const letter = label.trim().replace(/^@/, "").slice(0, 1).toUpperCase() || "W";
  if (!src || failed) return <span className="golden-drop-avatar fallback">{letter}</span>;
  return <Image className="golden-drop-avatar" src={src} alt="" width={44} height={44} sizes="44px" onError={() => setFailed(true)} />;
}

function SheetFrame({ label, onClose, children }: { label: string; onClose: () => void; children: React.ReactNode }) {
  return <div className="route-modal-backdrop golden-drop-sheet-backdrop" role="presentation" onClick={onClose}><section className="golden-drop-sheet" role="dialog" aria-modal="true" aria-label={label} onClick={(event) => event.stopPropagation()}><div className="golden-drop-sheet-grip" />{children}</section></div>;
}

async function fetchImages(client: SupabaseClient, row: HomeFeedRow): Promise<string[]> {
  const fallback = row.image_url ? [row.image_url] : [];
  if ((row.image_count ?? 0) <= 1) return fallback;
  const result = await client.from("drop_images").select("image_url,position").eq("drop_id", row.id).order("position", { ascending: true });
  if (result.error) return fallback;
  const urls = (result.data ?? []).map((item) => String(item.image_url ?? "")).filter(Boolean);
  return urls.length ? [...new Set(urls)] : fallback;
}

export function GoldenDropCard({ row, homeParity = false }: { row: HomeFeedRow; homeParity?: boolean }) {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [userId, setUserId] = useState("");
  const [images, setImages] = useState<string[]>(row.image_url ? [row.image_url] : []);
  const [likeCount, setLikeCount] = useState(row.like_count ?? 0);
  const [redropCount, setRedropCount] = useState(row.redrop_count ?? 0);
  const [viewCount, setViewCount] = useState<number | null>(null);
  const [sheet, setSheet] = useState<Sheet>(null);
  const [quote, setQuote] = useState("");
  const [reportCategory, setReportCategory] = useState<ReportCategory>("spam");
  const [reportDetail, setReportDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [burst, setBurst] = useState(false);
  const lastTap = useRef(0);
  const mediaRatio = postMediaAspectRatio(row, images.length > 1);
  const [mediaIndex, setMediaIndex] = useState(0);
  const mediaTrack = useRef<HTMLAnchorElement>(null);
  const updateMediaIndex = () => {
    const track = mediaTrack.current;
    const first = track?.querySelector<HTMLImageElement>("img");
    if (!track || !first || images.length <= 1) return;
    const stride = first.getBoundingClientRect().width + 8;
    if (stride <= 0) return;
    const next = Math.max(0, Math.min(images.length - 1, Math.round(track.scrollLeft / stride)));
    setMediaIndex((current) => current === next ? current : next);
  };

  const reloadViewer = useCallback(async (uid: string) => {
    if (!client) return;
    setViewer(await loadHomeViewerState(client, uid, [row]));
  }, [client, row]);

  useEffect(() => {
    if (!client) return;
    let live = true;
    void (async () => {
      const auth = await client.auth.getUser();
      const uid = auth.data.user?.id ?? "";
      if (!uid || !live) return;
      const [state, media, views] = await Promise.all([
        loadHomeViewerState(client, uid, [row]),
        fetchImages(client, row),
        client.rpc("drop_view_count", { p_drop_id: row.id }),
      ]);
      if (!live) return;
      setUserId(uid);
      setViewer(state);
      setImages(media);
      if (!views.error) setViewCount(Number(views.data ?? 0) || 0);
    })().catch(() => undefined);
    return () => { live = false; };
  }, [client, row]);

  const liked = viewer?.likedDropIds.has(row.id) ?? false;
  const saved = viewer?.savedDropIds.has(row.id) ?? false;
  const redropped = viewer?.redroppedDropIds.has(row.id) ?? false;
  const canRedrop = row.audience == null || row.audience === "everyone";
  const own = Boolean(userId && row.author_id === userId);

  const patchViewer = (key: "likedDropIds" | "savedDropIds" | "redroppedDropIds", enabled: boolean) => {
    setViewer((current) => {
      if (!current) return current;
      const next = new Set(current[key]);
      if (enabled) next.add(row.id); else next.delete(row.id);
      return { ...current, [key]: next };
    });
  };

  const like = async () => {
    if (!client || !viewer || !userId || busy) return;
    if (!liked) haptic();
    patchViewer("likedDropIds", !liked);
    setLikeCount((count) => Math.max(0, count + (liked ? -1 : 1)));
    try { await toggleDropLike(client, userId, row.id, liked); }
    catch { setLikeCount(row.like_count ?? 0); void reloadViewer(userId); }
  };

  const doubleLike = () => {
    if (!liked) void like();
    setBurst(false);
    requestAnimationFrame(() => setBurst(true));
    window.setTimeout(() => setBurst(false), 650);
  };
  const pointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (event.pointerType === "mouse") return;
    const now = event.timeStamp;
    if (now - lastTap.current <= 300) { lastTap.current = 0; doubleLike(); }
    else lastTap.current = now;
  };

  const save = async () => {
    if (!client || !viewer || !userId || busy) return;
    if (!saved) haptic();
    patchViewer("savedDropIds", !saved);
    try { await toggleDropSave(client, userId, row.id, saved); setSheet(null); }
    catch { void reloadViewer(userId); }
  };

  const redrop = async () => {
    if (!client || !viewer || !userId || busy || !canRedrop) return;
    patchViewer("redroppedDropIds", !redropped);
    setRedropCount((count) => Math.max(0, count + (redropped ? -1 : 1)));
    try { await toggleDropRedrop(client, userId, row.id, redropped); setSheet(null); }
    catch { setRedropCount(row.redrop_count ?? 0); void reloadViewer(userId); }
  };

  const quoteRedrop = async () => {
    if (!client || !userId || !quote.trim() || busy || !canRedrop) return;
    setBusy(true); setError("");
    const result = await client.from("redrops").insert({ drop_id: row.id, redropper_id: userId, quote_text: quote.trim() });
    if (result.error) setError(result.error.message || "Quote ReDrop ไม่สำเร็จ");
    else { setQuote(""); setRedropCount((count) => count + 1); setSheet(null); }
    setBusy(false);
  };

  const { toastMessage, showToast } = useToast();
  const share = async () => {
    const url = `${window.location.origin}/drop/${row.id}`;
    await shareOrCopyLink({ title: authorLabel(row), text: row.caption || "WYNOS", url }, showToast);
  };

  const report = async () => {
    if (!client || busy || own) return;
    if (reportCategory === "other" && !reportDetail.trim()) { setError("กรุณาระบุรายละเอียด"); return; }
    setBusy(true); setError("");
    const result = await client.rpc("submit_report", { p_target_type: "drop", p_target_id: row.id, p_category: reportCategory, p_detail: reportCategory === "other" ? reportDetail.trim() : null });
    if (result.error) setError(result.error.message || "ส่งรายงานไม่สำเร็จ");
    else { setSheet(null); setReportDetail(""); }
    setBusy(false);
  };

  return <article className="golden-drop-card">
    {row.redrop_id ? <div className="golden-drop-redrop"><WynosIcon name="repost" size={homeParity ? 16 : 13} strokeWidth={2} />รีโพสต์โดย {homeParity ? "" : "@"}{row.redropper_username || "wynos"} · {relativeTimeTh(row.created_at)}</div> : null}
    {row.quote_text ? <RichPostText className="golden-drop-quote" value={row.quote_text} /> : null}
    <Link className="golden-drop-author-avatar" href={`/profile/${row.author_id}`}><Avatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} /></Link>
    <div className="golden-drop-body">
      <header className="golden-drop-head"><Link href={`/profile/${row.author_id}`}><strong>{authorLabel(row)}{row.author_is_verified ? <span className="route-verified">✓</span> : null}</strong><small>{homeParity ? "· " : ""}{relativeTimeTh(row.created_at)}{row.location ? ` · 📍 ${row.location}` : ""}</small></Link><button type="button" aria-label="เพิ่มเติม" onClick={() => setSheet("more")}><WynosIcon name="more" size={homeParity ? 16 : 22} strokeWidth={2} /></button></header>
      {row.caption ? <RichPostText className="golden-drop-open" value={row.caption} postHref={`/drop/${row.id}`} /> : null}
      {images.length ? <div className="golden-drop-media-wrap" onDoubleClick={doubleLike} onPointerUp={pointerUp}><Link ref={mediaTrack} onScroll={updateMediaIndex} className={`golden-drop-media ${images.length > 1 ? "multi" : "single"}`} style={{ "--post-media-ratio": String(mediaRatio) } as CSSProperties} href={`/drop/${row.id}`}>{images.map((url, index) => <Image className={images.length > 1 ? `golden-media-card ${index === mediaIndex ? "front" : index < mediaIndex ? "before" : "after"}` : "golden-media-card"} src={url} alt="" width={1200} height={Math.round(1200 / (mediaRatio || 1))} style={{ width: "100%", height: "auto" }} sizes="(max-width: 640px) 100vw, 640px" loading="lazy" key={`${row.id}:${index}`} />)}</Link>{burst ? <WynosIcon name="like" className="golden-drop-burst" size={72} fill="currentColor" strokeWidth={0} /> : null}</div> : null}
      {homeParity ? (
        <PostActions
          liked={liked}
          likeCount={likeCount}
          commentCount={row.comment_count ?? 0}
          canRedrop={canRedrop}
          redropped={redropped}
          redropCount={redropCount}
          saved={saved}
          onLike={() => void like()}
          commentHref={`/drop/${row.id}#comments`}
          onRedrop={() => setSheet("redrop")}
          onShare={() => void share()}
          onSave={() => void save()}
          modernFeed
        />
      ) : (
        <div className="golden-drop-actions"><button className={liked ? "liked" : ""} type="button" aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"} aria-pressed={liked} onClick={() => void like()}><AnimatedHeart size={22} strokeWidth={2} liked={liked} />{likeCount > 0 ? <span>{likeCount}</span> : null}</button><Link href={`/drop/${row.id}#comments`} aria-label="ความคิดเห็น"><CommentIcon size={22} strokeWidth={2} />{(row.comment_count ?? 0) > 0 ? <span>{row.comment_count}</span> : null}</Link>{canRedrop ? <button className={redropped ? "active" : ""} type="button" aria-label="รีโพสต์" aria-pressed={redropped} onClick={() => setSheet("redrop")}><RepostIcon size={22} strokeWidth={2} />{redropCount > 0 ? <span>{redropCount}</span> : null}</button> : null}<button className="golden-drop-share" type="button" aria-label="แชร์" onClick={() => void share()}><WynosShareIcon size={22} /></button><button className={`golden-drop-save-inline ${saved ? "active" : ""}`} type="button" aria-label={saved ? "ยกเลิกบันทึก" : "บันทึก"} aria-pressed={saved} onClick={() => void save()}><SaveIcon size={22} strokeWidth={2} saved={saved} /></button>{viewCount != null ? <span className="golden-drop-view"><WynosIcon name="eye" size={22} strokeWidth={2} />{viewCount > 0 ? <span>{viewCount}</span> : null}</span> : null}</div>
      )}
    </div>

    {sheet === "more" ? <SheetFrame label="ตัวเลือกโพสต์" onClose={() => setSheet(null)}><button className="golden-drop-sheet-row" type="button" onClick={() => { setSheet(null); void share(); }}><WynosIcon name="share" size={20} strokeWidth={2} />แชร์</button><button className="golden-drop-sheet-row" type="button" onClick={() => void save()}><WynosIcon name="bookmark" size={20} strokeWidth={2} fill={saved ? "currentColor" : "none"} />{saved ? "เอาออกจากบันทึก" : "บันทึก"}</button>{!own ? <button className="golden-drop-sheet-row" type="button" onClick={() => setSheet("report")}><WynosIcon name="flag" size={20} strokeWidth={2} />รายงานโพสต์</button> : null}</SheetFrame> : null}
    {sheet === "redrop" ? <SheetFrame label="รีโพสต์" onClose={() => setSheet(null)}><button className="golden-drop-sheet-row" type="button" onClick={() => void redrop()}><WynosIcon name="repost" size={20} strokeWidth={2} />{redropped ? "ยกเลิก ReDrop" : "ReDrop"}</button><button className="golden-drop-sheet-row" type="button" onClick={() => setSheet("quote")}><WynosIcon name="quote" size={20} strokeWidth={2} />Quote ReDrop</button></SheetFrame> : null}
    {sheet === "quote" ? <SheetFrame label="Quote ReDrop" onClose={() => { setSheet(null); setQuote(""); }}><div className="golden-drop-sheet-form"><strong>Quote ReDrop</strong><textarea autoFocus maxLength={500} value={quote} onChange={(event) => setQuote(event.target.value)} placeholder="เขียนความคิดเห็นของคุณ…" />{error ? <p className="route-error">{error}</p> : null}<button className="route-primary" type="button" disabled={busy || !quote.trim()} onClick={() => void quoteRedrop()}>รีโพสต์พร้อมความคิดเห็น</button></div></SheetFrame> : null}
    {sheet === "report" ? <SheetFrame label="รายงานโพสต์" onClose={() => { setSheet(null); setReportDetail(""); }}><div className="golden-drop-sheet-form"><strong>รายงานโพสต์</strong><div className="golden-drop-report-list">{reportCategories.map((item) => <label key={item.value}><input type="radio" name={`drop-report-${row.id}`} checked={reportCategory === item.value} onChange={() => setReportCategory(item.value)} />{item.label}</label>)}</div>{reportCategory === "other" ? <textarea maxLength={1000} value={reportDetail} onChange={(event) => setReportDetail(event.target.value)} placeholder="รายละเอียดเพิ่มเติม" /> : null}{error ? <p className="route-error">{error}</p> : null}<button className="route-primary" type="button" disabled={busy} onClick={() => void report()}>ส่งรายงาน</button></div></SheetFrame> : null}
    <Toast message={toastMessage} />
  </article>;
}
