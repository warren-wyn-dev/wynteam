"use client";

import {
  Bookmark,
  ChevronRight,
  Heart,
  MessageCircle,
  Repeat2,
  Send,
  Share2,
  X,
} from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import {
  addDropComment,
  fetchDropComments,
  loadHomeViewerState,
  toggleDropCommentLike,
  toggleDropLike,
  toggleDropRedrop,
  toggleDropSave,
  type DropCommentRow,
  type HomeViewerState,
} from "@/lib/home-actions";
import { fetchDropById } from "@/lib/phase3-data";

type ActivityTab = "likes" | "redrops";

type ActivityProfile = {
  id: string;
  username: string;
  display_name?: string | null;
  avatar_url?: string | null;
  is_verified?: boolean;
};

type ActivityState = {
  likes: ActivityProfile[];
  redrops: ActivityProfile[];
};

const emptyActivity: ActivityState = { likes: [], redrops: [] };

function Caption({ value }: { value: string }) {
  const parts = value.split(/((?:https?:\/\/[^\s]+)|(?:#[\p{L}\p{N}_]+))/gu);
  return (
    <p className="detail-caption">
      {parts.map((part, index) => {
        if (/^https?:\/\//i.test(part)) {
          return <a className="linkish" href={part} target="_blank" rel="noreferrer" key={`${part}-${index}`}>{part}</a>;
        }
        if (part.startsWith("#")) return <span className="hashtag" key={`${part}-${index}`}>{part}</span>;
        return part;
      })}
    </p>
  );
}

async function fetchDropImages(client: SupabaseClient, dropId: string, fallback?: string | null): Promise<string[]> {
  const result = await client
    .from("drop_images")
    .select("image_url,position")
    .eq("drop_id", dropId)
    .order("position", { ascending: true });
  if (result.error) return fallback ? [fallback] : [];
  const urls = (result.data ?? []).map((row) => String(row.image_url ?? "")).filter(Boolean);
  if (fallback && !urls.includes(fallback)) urls.unshift(fallback);
  return [...new Set(urls)];
}

async function fetchActivity(client: SupabaseClient, dropId: string): Promise<ActivityState> {
  const [likesResult, redropsResult] = await Promise.all([
    client.from("drop_likes").select("user_id,created_at").eq("drop_id", dropId).order("created_at", { ascending: false }).limit(100),
    client.from("redrops").select("redropper_id,created_at").eq("drop_id", dropId).order("created_at", { ascending: false }).limit(100),
  ]);
  if (likesResult.error) throw new Error(likesResult.error.message);
  if (redropsResult.error) throw new Error(redropsResult.error.message);

  const likeIds = (likesResult.data ?? []).map((row) => String(row.user_id));
  const redropIds = (redropsResult.data ?? []).map((row) => String(row.redropper_id));
  const ids = [...new Set([...likeIds, ...redropIds])];
  if (!ids.length) return emptyActivity;

  const profilesResult = await client
    .from("profiles")
    .select("id,username,display_name,avatar_url,is_verified")
    .in("id", ids);
  if (profilesResult.error) throw new Error(profilesResult.error.message);

  const profiles = new Map<string, ActivityProfile>();
  for (const raw of profilesResult.data ?? []) {
    profiles.set(String(raw.id), {
      id: String(raw.id),
      username: String(raw.username ?? ""),
      display_name: raw.display_name ? String(raw.display_name) : null,
      avatar_url: raw.avatar_url ? String(raw.avatar_url) : null,
      is_verified: raw.is_verified === true,
    });
  }
  const mapOrdered = (ordered: string[]) => ordered.map((id) => profiles.get(id)).filter((value): value is ActivityProfile => Boolean(value));
  return { likes: mapOrdered(likeIds), redrops: mapOrdered(redropIds) };
}

function MediaGallery({ urls }: { urls: string[] }) {
  const [index, setIndex] = useState(0);
  if (!urls.length) return null;
  return (
    <div className="detail-gallery">
      <div className="detail-gallery-track" onScroll={(event) => {
        const element = event.currentTarget;
        const width = element.clientWidth || 1;
        setIndex(Math.max(0, Math.min(urls.length - 1, Math.round(element.scrollLeft / width))));
      }}>
        {urls.map((url, imageIndex) => (
          // Browser-native <img> is intentional for signed Supabase media and WebKit stability.
          // eslint-disable-next-line @next/next/no-img-element
          <img className="detail-image" src={url} alt="" loading={imageIndex === 0 ? "eager" : "lazy"} decoding="async" key={`${url}:${imageIndex}`} />
        ))}
      </div>
      {urls.length > 1 ? <div className="detail-gallery-dots" aria-label={`รูป ${index + 1} จาก ${urls.length}`}>{urls.map((_, dot) => <i className={dot === index ? "active" : ""} key={dot} />)}</div> : null}
    </div>
  );
}

function ActivitySheet({ client, dropId, onClose }: { client: SupabaseClient; dropId: string; onClose: () => void }) {
  const [tab, setTab] = useState<ActivityTab>("likes");
  const [state, setState] = useState<ActivityState>(emptyActivity);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let live = true;
    void fetchActivity(client, dropId)
      .then((next) => { if (live) setState(next); })
      .catch(() => { if (live) setError("โหลดกิจกรรมโพสต์ไม่สำเร็จ"); })
      .finally(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [client, dropId]);

  const rows = tab === "likes" ? state.likes : state.redrops;
  return (
    <div className="route-modal-backdrop detail-activity-backdrop" role="presentation" onClick={onClose}>
      <section className="route-modal detail-activity-sheet" role="dialog" aria-modal="true" aria-labelledby="post-activity-title" onClick={(event) => event.stopPropagation()}>
        <header className="detail-activity-header"><strong id="post-activity-title">กิจกรรมโพสต์</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={onClose}><X size={20} /></button></header>
        <div className="detail-activity-tabs" role="tablist" aria-label="กิจกรรมโพสต์">
          <button type="button" role="tab" aria-selected={tab === "likes"} className={tab === "likes" ? "active" : ""} onClick={() => setTab("likes")}>ถูกใจ</button>
          <button type="button" role="tab" aria-selected={tab === "redrops"} className={tab === "redrops" ? "active" : ""} onClick={() => setTab("redrops")}>รีโพสต์</button>
        </div>
        <div className="detail-activity-content">
          {loading ? <LoadingState /> : error ? <EmptyState>{error}</EmptyState> : !rows.length ? <EmptyState>{tab === "likes" ? "ยังไม่มีคนถูกใจโพสต์นี้" : "ยังไม่มีคนรีโพสต์โพสต์นี้"}</EmptyState> : rows.map((profile) => (
            <Link className="detail-activity-person" href={`/profile/${profile.id}`} onClick={onClose} key={`${tab}:${profile.id}`}>
              <Avatar src={profile.avatar_url} label={profile.username} />
              <span><strong>{profile.display_name?.trim() || profile.username}{profile.is_verified ? <b className="route-verified">✓</b> : null}</strong><small>@{profile.username}</small></span>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}

function CommentRow({
  comment,
  isReply,
  onLike,
  onReply,
}: {
  comment: DropCommentRow;
  isReply: boolean;
  onLike: (comment: DropCommentRow) => void;
  onReply: (comment: DropCommentRow) => void;
}) {
  return (
    <div className={`detail-comment ${isReply ? "detail-comment-reply" : ""}`}>
      <Link href={`/profile/${comment.author_id}`}><Avatar src={comment.author_avatar_url} label={comment.author_username} size={34} /></Link>
      <div className="detail-comment-copy">
        <div><strong>{comment.author_display_name?.trim() || comment.author_username}</strong><small> @{comment.author_username}</small></div>
        <p>{comment.text_content}</p>
        <div className="detail-comment-meta"><small>{relativeTimeTh(comment.created_at)}</small><button type="button" onClick={() => onReply(comment)}>ตอบกลับ</button></div>
      </div>
      <button className={`detail-comment-like ${comment.liked_by_me ? "active like" : ""}`} type="button" aria-label={comment.liked_by_me ? "เลิกถูกใจความคิดเห็น" : "ถูกใจความคิดเห็น"} onClick={() => onLike(comment)}><Heart size={15} fill={comment.liked_by_me ? "currentColor" : "none"} />{comment.like_count > 0 ? <span>{comment.like_count}</span> : null}</button>
    </div>
  );
}

function PostDetailInner({ client, userId, dropId }: { client: SupabaseClient; userId: string; dropId: string }) {
  const [row, setRow] = useState<HomeFeedRow | null>(null);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [comments, setComments] = useState<DropCommentRow[]>([]);
  const [images, setImages] = useState<string[]>([]);
  const [commentPage, setCommentPage] = useState(0);
  const [hasMoreComments, setHasMoreComments] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [draft, setDraft] = useState("");
  const [replyTo, setReplyTo] = useState<DropCommentRow | null>(null);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [activityOpen, setActivityOpen] = useState(false);
  const composerRef = useRef<HTMLInputElement | null>(null);

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const drop = await fetchDropById(client, dropId);
      if (!drop) { setRow(null); return; }
      const [state, firstComments, media] = await Promise.all([
        loadHomeViewerState(client, userId, [drop]),
        fetchDropComments(client, userId, dropId, 0),
        fetchDropImages(client, dropId, drop.image_url),
      ]);
      setRow(drop);
      setViewer(state);
      setComments(firstComments);
      setImages(media);
      setCommentPage(0);
      setHasMoreComments(firstComments.length === 50);
    } catch (e) { setError(e instanceof Error ? e.message : "โหลดโพสต์ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, dropId, userId]);
  useEffect(() => { void load(); }, [load]);

  const threaded = useMemo(() => {
    const top = comments.filter((comment) => !comment.parent_comment_id);
    const replies = new Map<string, DropCommentRow[]>();
    for (const comment of comments) {
      if (!comment.parent_comment_id) continue;
      const list = replies.get(comment.parent_comment_id) ?? [];
      list.push(comment);
      replies.set(comment.parent_comment_id, list);
    }
    return { top, replies };
  }, [comments]);

  if (loading) return <AppChrome title="โพสต์" userId={userId} backHref="/" showBottomNav={false}><LoadingState /></AppChrome>;
  if (!row || !viewer) return <AppChrome title="โพสต์" userId={userId} backHref="/" showBottomNav={false}><EmptyState>{error || "ไม่พบโพสต์นี้"}</EmptyState></AppChrome>;

  const liked = viewer.likedDropIds.has(row.id);
  const saved = viewer.savedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const patchSet = (key: "likedDropIds" | "savedDropIds" | "redroppedDropIds", enabled: boolean) => setViewer((current) => {
    if (!current) return current;
    const next = new Set(current[key]);
    if (enabled) next.add(row.id); else next.delete(row.id);
    return { ...current, [key]: next };
  });

  const interact = async (kind: "like" | "save" | "redrop") => {
    try {
      if (kind === "like") {
        patchSet("likedDropIds", !liked);
        setRow((current) => current ? { ...current, like_count: Math.max(0, (current.like_count ?? 0) + (liked ? -1 : 1)) } : current);
        await toggleDropLike(client, userId, row.id, liked);
      }
      if (kind === "save") { patchSet("savedDropIds", !saved); await toggleDropSave(client, userId, row.id, saved); }
      if (kind === "redrop") {
        patchSet("redroppedDropIds", !redropped);
        setRow((current) => current ? { ...current, redrop_count: Math.max(0, (current.redrop_count ?? 0) + (redropped ? -1 : 1)) } : current);
        await toggleDropRedrop(client, userId, row.id, redropped);
      }
    } catch { setError("อัปเดตกิจกรรมไม่สำเร็จ"); void load(); }
  };

  const share = async () => {
    const url = `${window.location.origin}/drop/${row.id}`;
    try {
      if (navigator.share) await navigator.share({ title: `โพสต์โดย ${authorLabel(row)}`, text: row.caption ?? "WYNOS", url });
      else await navigator.clipboard.writeText(url);
    } catch { /* user cancelled */ }
  };

  const submit = async () => {
    if (!draft.trim() || sending) return;
    setSending(true); setError("");
    try {
      const created = await addDropComment(client, userId, row.id, draft, replyTo?.id ?? null);
      setComments((current) => [...current, created]);
      setDraft(""); setReplyTo(null);
      setRow((current) => current ? { ...current, comment_count: (current.comment_count ?? 0) + 1 } : current);
    } catch { setError("ส่งความคิดเห็นไม่สำเร็จ"); }
    finally { setSending(false); }
  };

  const likeComment = async (comment: DropCommentRow) => {
    try {
      await toggleDropCommentLike(client, userId, comment.id, comment.liked_by_me);
      setComments((current) => current.map((item) => item.id === comment.id ? { ...item, liked_by_me: !item.liked_by_me, like_count: Math.max(0, item.like_count + (item.liked_by_me ? -1 : 1)) } : item));
    } catch { setError("ถูกใจความคิดเห็นไม่สำเร็จ"); }
  };

  const startReply = (comment: DropCommentRow) => {
    setReplyTo(comment);
    composerRef.current?.focus();
  };

  const loadMore = async () => {
    if (loadingMore || !hasMoreComments) return;
    setLoadingMore(true); setError("");
    try {
      const nextPage = commentPage + 1;
      const next = await fetchDropComments(client, userId, row.id, nextPage);
      setComments((current) => [...current, ...next]);
      setCommentPage(nextPage);
      setHasMoreComments(next.length === 50);
    } catch { setError("โหลดคอมเมนต์เพิ่มไม่สำเร็จ"); }
    finally { setLoadingMore(false); }
  };

  return (
    <AppChrome title="โพสต์" userId={userId} backHref="/" showBottomNav={false}>
      <article className="detail-post flutter-detail-post">
        <div className="detail-author-row">
          <Link className="route-drop-author" href={`/profile/${row.author_id}`}><Avatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} /><span><strong>{authorLabel(row)}{row.author_is_verified ? <b className="route-verified">✓</b> : null}</strong><small>@{row.author_username || "wynos"} · {relativeTimeTh(row.created_at)}</small></span></Link>
        </div>
        {row.caption ? <Caption value={row.caption} /> : null}
        <MediaGallery urls={images} />
        <div className="detail-actions flutter-detail-actions">
          <button className={liked ? "active like" : ""} type="button" aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"} onClick={() => void interact("like")}><Heart fill={liked ? "currentColor" : "none"} />{row.like_count ?? 0}</button>
          <button type="button" aria-label="ความคิดเห็น" onClick={() => composerRef.current?.focus()}><MessageCircle />{row.comment_count ?? 0}</button>
          <button className={redropped ? "active" : ""} type="button" aria-label={redropped ? "ยกเลิกรีโพสต์" : "รีโพสต์"} onClick={() => void interact("redrop")}><Repeat2 />{row.redrop_count ?? 0}</button>
          <button type="button" aria-label="แชร์โพสต์" onClick={() => void share()}><Share2 /></button>
          <button className={saved ? "active" : ""} type="button" aria-label={saved ? "นำออกจากที่บันทึก" : "บันทึกโพสต์"} onClick={() => void interact("save")}><Bookmark fill={saved ? "currentColor" : "none"} /></button>
        </div>
        <button className="detail-activity-row" type="button" onClick={() => setActivityOpen(true)}><span className="detail-activity-icon">⌁</span><strong>ดูกิจกรรม</strong><ChevronRight size={27} /></button>
      </article>

      {error ? <p className="route-error route-pad">{error}</p> : null}
      <section className="detail-comments flutter-detail-comments" aria-label="ความคิดเห็น">
        {!comments.length ? <EmptyState>ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!</EmptyState> : threaded.top.map((comment) => (
          <div className="detail-thread" key={comment.id}>
            <CommentRow comment={comment} isReply={false} onLike={(value) => void likeComment(value)} onReply={startReply} />
            {(threaded.replies.get(comment.id) ?? []).map((reply) => <CommentRow comment={reply} isReply onLike={(value) => void likeComment(value)} onReply={startReply} key={reply.id} />)}
          </div>
        ))}
        {hasMoreComments ? <button className="route-more" type="button" disabled={loadingMore} onClick={() => void loadMore()}>{loadingMore ? "กำลังโหลด…" : "ดูคอมเมนต์เพิ่มเติม"}</button> : comments.length ? <p className="detail-comments-end">ไม่มีความคิดเห็นเพิ่มเติมแล้ว</p> : null}
      </section>

      <div className="detail-composer-shell">
        {replyTo ? <div className="detail-reply-banner"><span>ตอบกลับ @{replyTo.author_username}</span><button type="button" aria-label="ยกเลิกการตอบกลับ" onClick={() => setReplyTo(null)}><X size={16} /></button></div> : null}
        <form className="detail-comment-form flutter-detail-composer" onSubmit={(event) => { event.preventDefault(); void submit(); }}><input ref={composerRef} value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={500} placeholder={replyTo ? `ตอบกลับ @${replyTo.author_username}…` : "เพิ่มความคิดเห็น…"} /><button type="submit" aria-label="ส่งความคิดเห็น" disabled={sending || !draft.trim()}><Send size={19} /></button></form>
      </div>
      {activityOpen ? <ActivitySheet client={client} dropId={row.id} onClose={() => setActivityOpen(false)} /> : null}
    </AppChrome>
  );
}

export function PostDetailRoute({ dropId }: { dropId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <PostDetailInner client={client} userId={userId} dropId={dropId} />}</DeveloperRouteGate>;
}
