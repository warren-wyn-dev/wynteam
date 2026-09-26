"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { PostDetailSkeleton } from "@/components/ui/skeleton";
import { ViewportPortal } from "@/components/ui/viewport-portal";
import { RichPostText } from "@/components/rich-post-text";
import { AnimatedHeart } from "@/components/ui/animated-heart";
import { AnimatedBookmark } from "@/components/ui/animated-bookmark";
import { AnimatedCount } from "@/components/ui/animated-count";
import { followButtonLabel } from "@/components/ui/follow-button-label";
import { CommentIcon, RepostIcon } from "@/components/ui/post-action-icons";
import { Toast, useToast } from "@/components/ui/toast";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { WynosShareIcon } from "@/components/ui/wynos-share-icon";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { getRecentDropEngagement, listenDropEngagement, patchDropRow, patchDropViewer, publishDropEngagement } from "@/lib/drop-engagement-sync";
import {
  addDropComment,
  fetchDropComments,
  loadHomeViewerState,
  toggleAuthorFollow,
  toggleDropCommentLike,
  toggleDropLike,
  toggleDropRedrop,
  toggleDropSave,
  type DropCommentRow,
  type HomeViewerState,
} from "@/lib/home-actions";
import { haptic } from "@/lib/haptics";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { fetchDropById } from "@/lib/phase3-data";
import { shareOrCopyLink } from "@/lib/share";
import { useKeyboardInset } from "@/lib/use-keyboard-inset";

type ActivityTab = "likes" | "redrops";
type ActivityProfile = { id: string; username: string; display_name?: string | null; avatar_url?: string | null; is_verified?: boolean };
type PostDetailSnapshot = {
  row: HomeFeedRow;
  viewer: HomeViewerState;
  comments: DropCommentRow[];
  images: string[];
  commentPage: number;
  hasMoreComments: boolean;
  viewerProfile: { username: string; avatar_url?: string | null } | null;
};
type ActivityState = { likes: ActivityProfile[]; redrops: ActivityProfile[] };
const emptyActivity: ActivityState = { likes: [], redrops: [] };

function Caption({ value }: { value: string }) {
  return <RichPostText className="detail-caption" value={value} />;
}

async function fetchDropImages(client: SupabaseClient, dropId: string, fallback?: string | null): Promise<string[]> {
  const result = await client.from("drop_images").select("image_url,position").eq("drop_id", dropId).order("position", { ascending: true });
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
  const profilesResult = await client.from("profiles").select("id,username,display_name,avatar_url,is_verified").in("id", ids);
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
  const ordered = (idsToMap: string[]) => idsToMap.map((id) => profiles.get(id)).filter((value): value is ActivityProfile => Boolean(value));
  return { likes: ordered(likeIds), redrops: ordered(redropIds) };
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
          <Image
            className="detail-image"
            src={url}
            alt=""
            width={1200}
            height={1500}
            style={{ width: "100%", height: "auto" }}
            sizes="(max-width: 720px) 100vw, 720px"
            priority={imageIndex === 0}
            loading={imageIndex === 0 ? undefined : "lazy"}
            key={`${url}:${imageIndex}`}
          />
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
        <header className="detail-activity-header"><strong id="post-activity-title">กิจกรรมโพสต์</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={onClose}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header>
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

function ConfirmDialog({ title, body, dangerLabel, onCancel, onConfirm }: { title: string; body?: string; dangerLabel: string; onCancel: () => void; onConfirm: () => void }) {
  return <div className="route-modal-backdrop detail-dialog-backdrop" role="presentation" onClick={onCancel}><section className="route-modal detail-confirm-dialog" role="alertdialog" aria-modal="true" aria-label={title} onClick={(event) => event.stopPropagation()}><strong>{title}</strong>{body ? <p>{body}</p> : null}<footer><button type="button" onClick={onCancel}>ยกเลิก</button><button className="danger" type="button" onClick={onConfirm}>{dangerLabel}</button></footer></section></div>;
}

function TextDialog({ title, value, placeholder, confirmLabel, onChange, onCancel, onConfirm }: { title: string; value: string; placeholder?: string; confirmLabel: string; onChange: (value: string) => void; onCancel: () => void; onConfirm: () => void }) {
  return <div className="route-modal-backdrop detail-dialog-backdrop" role="presentation" onClick={onCancel}><section className="route-modal detail-dialog" role="dialog" aria-modal="true" aria-label={title} onClick={(event) => event.stopPropagation()}><header><strong>{title}</strong><button type="button" aria-label="ปิด" onClick={onCancel}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header><textarea autoFocus maxLength={500} value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} /><footer><button type="button" onClick={onCancel}>ยกเลิก</button><button className="primary" type="button" disabled={confirmLabel === "ส่งรายงาน" && !value.trim()} onClick={onConfirm}>{confirmLabel}</button></footer></section></div>;
}

function CommentRow({ comment, isReply, currentUserId, onLike, onReply, onDelete }: { comment: DropCommentRow; isReply: boolean; currentUserId: string; onLike: (comment: DropCommentRow) => void; onReply: (comment: DropCommentRow) => void; onDelete: (comment: DropCommentRow) => void }) {
  return (
    <div className={`detail-comment ${isReply ? "detail-comment-reply" : ""}`}>
      <Link className="detail-comment-avatar" href={`/profile/${comment.author_id}`}><Avatar src={comment.author_avatar_url} label={comment.author_username} size={isReply ? 32 : 36} /></Link>
      <div className="detail-comment-copy">
        <div className="detail-comment-author-line"><strong>{comment.author_display_name?.trim() || comment.author_username}</strong><small>{relativeTimeTh(comment.created_at)}</small></div>
        <p>{comment.text_content}</p>
        {!isReply ? <button className="detail-comment-reply-action" type="button" onClick={() => onReply(comment)}>ตอบกลับ</button> : null}
      </div>
      <div className="detail-comment-actions">
        {comment.author_id === currentUserId ? <button className="detail-comment-delete" type="button" aria-label="ลบคอมเมนต์" onClick={() => onDelete(comment)}><WynosIcon name="trash" size={16} strokeWidth={2} /></button> : null}
        <button className={`detail-comment-like ${comment.liked_by_me ? "active like" : ""}`} type="button" aria-label={comment.liked_by_me ? "เลิกถูกใจความคิดเห็น" : "ถูกใจความคิดเห็น"} onClick={() => onLike(comment)}><WynosIcon name="like" size={16} strokeWidth={2} fill={comment.liked_by_me ? "currentColor" : "none"} /><AnimatedCount value={comment.like_count} hideZero /></button>
      </div>
    </div>
  );
}

function PostDetailInner({ client, userId, dropId }: { client: SupabaseClient; userId: string; dropId: string }) {
  const router = useRouter();
  const source = useId();
  const cacheKey = `post-detail:${userId}:${dropId}`;
  const cached = getMountCache<PostDetailSnapshot>(cacheKey);
  const hadCache = useRef(cached !== undefined);
  const [row, setRow] = useState<HomeFeedRow | null>(cached?.row ?? null);
  const [viewer, setViewer] = useState<HomeViewerState | null>(cached?.viewer ?? null);
  const [comments, setComments] = useState<DropCommentRow[]>(cached?.comments ?? []);
  const [images, setImages] = useState<string[]>(cached?.images ?? []);
  const [commentPage, setCommentPage] = useState(cached?.commentPage ?? 0);
  const [hasMoreComments, setHasMoreComments] = useState(cached?.hasMoreComments ?? false);
  const [loading, setLoading] = useState(!cached);
  const [loadingMore, setLoadingMore] = useState(false);
  const [draft, setDraft] = useState("");
  const [replyTo, setReplyTo] = useState<DropCommentRow | null>(null);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [activityOpen, setActivityOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [followBusy, setFollowBusy] = useState(false);
  const [headerHidden, setHeaderHidden] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [editCaption, setEditCaption] = useState("");
  const [deleteDropOpen, setDeleteDropOpen] = useState(false);
  const [deleteCommentTarget, setDeleteCommentTarget] = useState<DropCommentRow | null>(null);
  const [reportOpen, setReportOpen] = useState(false);
  const [reportText, setReportText] = useState("");
  const [viewerProfile, setViewerProfile] = useState<{ username: string; avatar_url?: string | null } | null>(cached?.viewerProfile ?? null);
  const composerRef = useRef<HTMLInputElement | null>(null);
  const scrollYRef = useRef(0);
  const { toastMessage, toastAction, showToast, dismissToast } = useToast();

  useKeyboardInset();

  const load = useCallback(async (showLoading = true) => {
    if (showLoading) setLoading(true);
    setError("");
    try {
      const drop = await fetchDropById(client, dropId);
      if (!drop) { setRow(null); return; }
      const [state, firstComments, media, profileResult] = await Promise.all([
        loadHomeViewerState(client, userId, [drop]),
        fetchDropComments(client, userId, dropId, 0),
        fetchDropImages(client, dropId, drop.image_url),
        client.from("profiles").select("username,avatar_url").eq("id", userId).maybeSingle(),
      ]);
      const nextViewerProfile = !profileResult.error && profileResult.data
        ? { username: String(profileResult.data.username ?? "WYNOS"), avatar_url: profileResult.data.avatar_url ? String(profileResult.data.avatar_url) : null }
        : null;
      const recent = getRecentDropEngagement(userId, dropId);
      const latestRow = recent.reduce(patchDropRow, drop);
      const latestViewer = recent.reduce(patchDropViewer, state);
      setRow(latestRow); setViewer(latestViewer); setComments(firstComments); setImages(media);
      if (nextViewerProfile) setViewerProfile(nextViewerProfile);
      void client.rpc("record_drop_view", { p_drop_id: dropId }).then(() => undefined, () => undefined);
      setCommentPage(0); setHasMoreComments(firstComments.length === 50);
      setMountCache(cacheKey, { row: latestRow, viewer: latestViewer, comments: firstComments, images: media, commentPage: 0, hasMoreComments: firstComments.length === 50, viewerProfile: nextViewerProfile });
    } catch (reason) { setError(reason instanceof Error ? reason.message : "โหลดโพสต์ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, dropId, userId, cacheKey]);

  useEffect(() => { void load(!hadCache.current); }, [load]);
  useEffect(() => {
    const apply = (change: Parameters<typeof patchDropViewer>[1]) => {
      if (change.userId !== userId || change.dropId !== dropId || change.source === source) return;
      setViewer((current) => current ? patchDropViewer(current, change) : current);
      setRow((current) => current ? patchDropRow(current, change) : current);
    };
    for (const change of getRecentDropEngagement(userId, dropId)) apply(change);
    return listenDropEngagement(apply);
  }, [userId, dropId, source]);
  useEffect(() => {
    const onScroll = () => {
      const y = window.scrollY;
      const previous = scrollYRef.current;
      // iOS scrolls the document automatically when its keyboard opens.
      // That viewport pan is not an intentional user scroll and must not
      // hide the sticky Post header while someone is commenting.
      if (document.activeElement === composerRef.current || document.documentElement.hasAttribute("data-keyboard-open")) {
        setHeaderHidden(false);
        scrollYRef.current = y;
        return;
      }
      if (y <= 8 || y < previous - 2) setHeaderHidden(false);
      else if (y > 80 && y > previous + 2) setHeaderHidden(true);
      scrollYRef.current = y;
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const threaded = useMemo(() => {
    const top = comments.filter((comment) => !comment.parent_comment_id);
    const replies = new Map<string, DropCommentRow[]>();
    for (const comment of comments) {
      if (!comment.parent_comment_id) continue;
      const list = replies.get(comment.parent_comment_id) ?? [];
      list.push(comment); replies.set(comment.parent_comment_id, list);
    }
    return { top, replies };
  }, [comments]);

  if (loading && !row) return <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}><header className="detail-floating-header"><button type="button" aria-label="ย้อนกลับ" onClick={() => router.back()}><WynosIcon name="back" size={22} strokeWidth={2} /></button><strong>โพสต์</strong><span /></header><PostDetailSkeleton /></AppChrome>;
  if (!row || !viewer) return <AppChrome title="โพสต์" userId={userId} backHref="/" showBottomNav={false}><EmptyState>{error || "ไม่พบโพสต์นี้"}</EmptyState></AppChrome>;

  const liked = viewer.likedDropIds.has(row.id);
  const saved = viewer.savedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const ownDrop = row.author_id === userId;
  const publicAudience = (row.audience ?? "everyone") === "everyone";
  const followingAuthor = viewer.followedAuthorIds.has(row.author_id);
  const pendingAuthor = viewer.pendingFollowAuthorIds.has(row.author_id);
  const privateAuthor = viewer.privateAuthorIds.has(row.author_id);

  const patchSet = (key: "likedDropIds" | "savedDropIds" | "redroppedDropIds", enabled: boolean) => setViewer((current) => {
    if (!current) return current;
    const next = new Set(current[key]);
    if (enabled) next.add(row.id); else next.delete(row.id);
    return { ...current, [key]: next };
  });

  const undoSave = async () => {
    if (!getRecentDropEngagement(userId, row.id).some((change) => change.kind === "save" && change.active)) return;
    patchSet("savedDropIds", false);
    publishDropEngagement({ userId, dropId: row.id, kind: "save", active: false, source });
    try { await toggleDropSave(client, userId, row.id, true); }
    catch { publishDropEngagement({ userId, dropId: row.id, kind: "save", active: true, source }); showToast("เลิกทำไม่สำเร็จ"); void load(); }
  };

  const interact = async (kind: "like" | "save" | "redrop") => {
    const previouslyActive = kind === "like" ? liked : kind === "save" ? saved : redropped;
    const previousCount = kind === "like" ? (row.like_count ?? 0) : kind === "redrop" ? (row.redrop_count ?? 0) : undefined;
    const nextCount = previousCount === undefined ? undefined : Math.max(0, previousCount + (previouslyActive ? -1 : 1));
    if (!previouslyActive) haptic();
    const field = kind === "like" ? "likedDropIds" : kind === "save" ? "savedDropIds" : "redroppedDropIds";
    patchSet(field, !previouslyActive);
    if (kind === "like") setRow((current) => current ? { ...current, like_count: nextCount ?? 0 } : current);
    if (kind === "redrop") setRow((current) => current ? { ...current, redrop_count: nextCount ?? 0 } : current);
    publishDropEngagement({ userId, dropId: row.id, kind, active: !previouslyActive, count: nextCount, source });
    try {
      if (kind === "like") await toggleDropLike(client, userId, row.id, previouslyActive);
      if (kind === "save") await toggleDropSave(client, userId, row.id, previouslyActive);
      if (kind === "redrop") await toggleDropRedrop(client, userId, row.id, previouslyActive);
      if (kind === "save") {
        if (!previouslyActive) showToast("บันทึกโพสต์แล้ว", { label: "เลิกทำ", onClick: () => void undoSave() });
        else showToast("นำออกจากรายการที่บันทึกแล้ว");
      }
    } catch {
      publishDropEngagement({ userId, dropId: row.id, kind, active: previouslyActive, count: previousCount, source });
      showToast("อัปเดตกิจกรรมไม่สำเร็จ ลองใหม่อีกครั้ง");
      void load();
    }
  };

  const share = async () => {
    const url = `${window.location.origin}/drop/${row.id}`;
    await shareOrCopyLink({ title: `โพสต์โดย ${authorLabel(row)}`, text: row.caption ?? "WYNOS", url }, showToast);
  };

  const submit = async () => {
    if (!draft.trim() || sending) return;
    setSending(true); setError("");
    try {
      const created = await addDropComment(client, userId, row.id, draft, replyTo?.id ?? null);
      setComments((current) => [...current, created]);
      setDraft(""); setReplyTo(null);
      setRow((current) => current ? { ...current, comment_count: (current.comment_count ?? 0) + 1 } : current);
      publishDropEngagement({ userId, dropId: row.id, kind: "comment", active: true, count: (row.comment_count ?? 0) + 1, source });
    } catch { setError("ส่งความคิดเห็นไม่สำเร็จ"); }
    finally { setSending(false); }
  };

  const likeComment = async (comment: DropCommentRow) => {
    try {
      if (!comment.liked_by_me) haptic();
      await toggleDropCommentLike(client, userId, comment.id, comment.liked_by_me);
      setComments((current) => current.map((item) => item.id === comment.id ? { ...item, liked_by_me: !item.liked_by_me, like_count: Math.max(0, item.like_count + (item.liked_by_me ? -1 : 1)) } : item));
    } catch { setError("ถูกใจความคิดเห็นไม่สำเร็จ"); }
  };

  const deleteComment = async (comment: DropCommentRow) => {
    if (comment.author_id !== userId) return;
    setError("");
    try {
      const result = await client.from("drop_comments").delete().eq("id", comment.id).eq("author_id", userId);
      if (result.error) throw result.error;
      const removed = new Set([comment.id, ...comments.filter((item) => item.parent_comment_id === comment.id).map((item) => item.id)]);
      setComments((current) => current.filter((item) => !removed.has(item.id)));
      setRow((current) => current ? { ...current, comment_count: Math.max(0, (current.comment_count ?? 0) - removed.size) } : current);
      publishDropEngagement({ userId, dropId: row.id, kind: "comment", active: true, count: Math.max(0, (row.comment_count ?? 0) - removed.size), source });
      setDeleteCommentTarget(null);
    } catch { setError("ลบคอมเมนต์ไม่สำเร็จ"); }
  };

  const loadMore = async () => {
    if (loadingMore || !hasMoreComments) return;
    setLoadingMore(true); setError("");
    try {
      const nextPage = commentPage + 1;
      const next = await fetchDropComments(client, userId, row.id, nextPage);
      setComments((current) => [...current, ...next]); setCommentPage(nextPage); setHasMoreComments(next.length === 50);
    } catch { setError("โหลดคอมเมนต์เพิ่มไม่สำเร็จ"); }
    finally { setLoadingMore(false); }
  };

  const followAuthor = async () => {
    if (ownDrop || followBusy) return;
    setError(""); setFollowBusy(true);
    try {
      if (!followingAuthor) haptic();
      const state = await toggleAuthorFollow(client, userId, row.author_id, { currentlyFollowing: followingAuthor, pendingRequest: pendingAuthor, isPrivate: privateAuthor });
      setViewer((current) => {
        if (!current) return current;
        const followedAuthorIds = new Set(current.followedAuthorIds);
        const pendingFollowAuthorIds = new Set(current.pendingFollowAuthorIds);
        if (state === "following") followedAuthorIds.add(row.author_id); else followedAuthorIds.delete(row.author_id);
        if (state === "requested") pendingFollowAuthorIds.add(row.author_id); else pendingFollowAuthorIds.delete(row.author_id);
        return { ...current, followedAuthorIds, pendingFollowAuthorIds };
      });
    } catch { setError("ติดตามไม่สำเร็จ"); }
    finally { setFollowBusy(false); }
  };

  const editDrop = async () => {
    setError("");
    try {
      const result = await client.rpc("edit_drop", { p_drop_id: row.id, p_caption: editCaption.trim() || null });
      if (result.error) throw result.error;
      setRow((current) => current ? { ...current, caption: editCaption.trim() || null } : current);
      setEditOpen(false);
    } catch { setError("แก้ไขโพสต์ไม่สำเร็จ"); }
  };

  const deleteDrop = async () => {
    setError("");
    try {
      const result = await client.rpc("soft_delete_drop", { p_drop_id: row.id });
      if (result.error) throw result.error;
      setDeleteDropOpen(false); router.replace("/");
    } catch { setError("ลบโพสต์ไม่สำเร็จ"); }
  };

  const reportDrop = async () => {
    if (!reportText.trim()) return;
    setError("");
    try {
      const result = await client.rpc("submit_report", { p_target_type: "drop", p_target_id: row.id, p_category: "other", p_detail: reportText.trim() });
      if (result.error) throw result.error;
      setReportOpen(false); setReportText("");
    } catch { setError("ส่งรายงานไม่สำเร็จ"); }
  };

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}>
      <header className={`detail-floating-header ${headerHidden ? "hidden" : ""}`}><button type="button" aria-label="ย้อนกลับ" onClick={() => router.back()}><WynosIcon name="back" size={22} strokeWidth={2} /></button><strong>โพสต์</strong><span /></header>
      <article className="detail-post flutter-detail-post">
        <div className="detail-post-copy"><div className="detail-author-row"><Link className="route-drop-author detail-author-link" href={`/profile/${row.author_id}`}><Avatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} size={44} /><span className="detail-author-copy"><span className="detail-author-primary"><strong>{authorLabel(row)}{row.author_is_verified ? <b className="route-verified">✓</b> : null}</strong><small>{relativeTimeTh(row.created_at)}</small></span><small className="detail-author-username">@{row.author_username || "wynos"}</small></span></Link>{!ownDrop ? <button className="detail-follow-button" type="button" disabled={followBusy} onClick={() => void followAuthor()}>{followButtonLabel({ busy: followBusy, following: followingAuthor, requested: pendingAuthor })}</button> : null}<button className="detail-more-button" type="button" aria-label="เพิ่มเติม" onClick={() => setMoreOpen(true)}><WynosIcon name="moreVertical" size={18} strokeWidth={2} /></button></div>{row.caption ? <Caption value={row.caption} /> : null}</div>
        <MediaGallery urls={images} />
        <div className={`detail-actions flutter-detail-actions ${publicAudience ? "public" : "private"}`}><button className={liked ? "active like" : ""} type="button" aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"} aria-pressed={liked} onClick={() => void interact("like")}><AnimatedHeart size={24} strokeWidth={2} liked={liked} /><AnimatedCount value={row.like_count ?? 0} /></button><button type="button" aria-label="ความคิดเห็น" onClick={() => composerRef.current?.focus()}><CommentIcon size={24} strokeWidth={2} /><AnimatedCount value={row.comment_count ?? 0} /></button>{publicAudience ? <button className={redropped ? "active" : ""} type="button" aria-label={redropped ? "ยกเลิกรีโพสต์" : "รีโพสต์"} aria-pressed={redropped} onClick={() => void interact("redrop")}><RepostIcon size={24} strokeWidth={2} /><AnimatedCount value={row.redrop_count ?? 0} /></button> : null}<button type="button" aria-label="แชร์โพสต์" onClick={() => void share()}><WynosShareIcon size={24} /></button><button className={saved ? "active" : ""} type="button" aria-label={saved ? "นำออกจากที่บันทึก" : "บันทึกโพสต์"} aria-pressed={saved} onClick={() => void interact("save")}><AnimatedBookmark size={24} strokeWidth={2} saved={saved} /></button></div>
        <button className="detail-activity-row" type="button" onClick={() => setActivityOpen(true)}><span className="detail-activity-icon"><WynosIcon name="poll" size={22} strokeWidth={2} /></span><strong>ดูกิจกรรม</strong><WynosIcon name="chevronRight" size={27} strokeWidth={2} /></button>
      </article>

      {error ? <p className="route-error route-pad">{error}</p> : null}
      <section className="detail-comments flutter-detail-comments" aria-label="ความคิดเห็น">
        {!comments.length ? <EmptyState>ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!</EmptyState> : threaded.top.map((comment) => <div className="detail-thread" key={comment.id}><CommentRow comment={comment} isReply={false} currentUserId={userId} onLike={(value) => void likeComment(value)} onReply={(value) => { setReplyTo(value); composerRef.current?.focus(); }} onDelete={setDeleteCommentTarget} />{(threaded.replies.get(comment.id) ?? []).map((reply) => <CommentRow comment={reply} isReply currentUserId={userId} onLike={(value) => void likeComment(value)} onReply={() => undefined} onDelete={setDeleteCommentTarget} key={reply.id} />)}</div>)}
        {hasMoreComments ? <button className="route-more" type="button" disabled={loadingMore} onClick={() => void loadMore()}>{loadingMore ? "กำลังโหลด…" : "ดูคอมเมนต์เพิ่มเติม"}</button> : comments.length ? <p className="detail-comments-end">ไม่มีความคิดเห็นเพิ่มเติมแล้ว</p> : null}
      </section>

      <ViewportPortal><div className="detail-composer-shell">{replyTo ? <div className="detail-reply-banner"><span>ตอบกลับ {replyTo.author_display_name?.trim() || replyTo.author_username}</span><button type="button" aria-label="ยกเลิกการตอบกลับ" onClick={() => setReplyTo(null)}><WynosIcon name="close" size={16} strokeWidth={2} /></button></div> : null}<form className="detail-comment-form flutter-detail-composer" onSubmit={(event) => { event.preventDefault(); void submit(); }}><Avatar src={viewerProfile?.avatar_url} label={viewerProfile?.username || userId} size={36} /><div className="flutter-detail-composer-field"><input ref={composerRef} value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={500} placeholder="แสดงความคิดเห็น..." onFocus={() => setHeaderHidden(false)} /><button type="submit" aria-label="ส่งความคิดเห็น" disabled={sending || !draft.trim()}><WynosIcon name="send" size={25} strokeWidth={2} /></button></div></form></div></ViewportPortal>

      {activityOpen ? <ActivitySheet client={client} dropId={row.id} onClose={() => setActivityOpen(false)} /> : null}
      {editOpen ? <TextDialog title="แก้ไขโพสต์" value={editCaption} confirmLabel="บันทึก" onChange={setEditCaption} onCancel={() => setEditOpen(false)} onConfirm={() => void editDrop()} /> : null}
      {deleteDropOpen ? <ConfirmDialog title="ลบโพสต์นี้หรือไม่?" body="โพสต์จะถูกนำออกจาก WYNOS และยังคงใช้ระบบกู้คืนเดิม" dangerLabel="ลบ" onCancel={() => setDeleteDropOpen(false)} onConfirm={() => void deleteDrop()} /> : null}
      {deleteCommentTarget ? <ConfirmDialog title="ลบคอมเมนต์นี้หรือไม่?" dangerLabel="ลบ" onCancel={() => setDeleteCommentTarget(null)} onConfirm={() => void deleteComment(deleteCommentTarget)} /> : null}
      {reportOpen ? <TextDialog title="รายงานโพสต์" value={reportText} placeholder="รายละเอียดที่ต้องการรายงาน" confirmLabel="ส่งรายงาน" onChange={setReportText} onCancel={() => { setReportOpen(false); setReportText(""); }} onConfirm={() => void reportDrop()} /> : null}
      <Toast message={toastMessage} action={toastAction} onDismiss={dismissToast} />
      {moreOpen ? <div className="route-modal-backdrop detail-more-backdrop" role="presentation" onClick={() => setMoreOpen(false)}><section className="route-modal detail-more-sheet" role="dialog" aria-modal="true" aria-label="ตัวเลือกโพสต์" onClick={(event) => event.stopPropagation()}>{ownDrop ? <>{Date.now() - new Date(row.created_at).getTime() < 30 * 60 * 1000 ? <button type="button" onClick={() => { setEditCaption(row.caption ?? ""); setMoreOpen(false); setEditOpen(true); }}><WynosIcon name="pencil" size={19} strokeWidth={2} />แก้ไข</button> : null}<button className="danger" type="button" onClick={() => { setMoreOpen(false); setDeleteDropOpen(true); }}><WynosIcon name="trash" size={19} strokeWidth={2} />ลบ</button></> : <button type="button" onClick={() => { setMoreOpen(false); setReportOpen(true); }}><WynosIcon name="flag" size={19} strokeWidth={2} />รายงานโพสต์</button>}</section></div> : null}
    </AppChrome>
  );
}

export function PostDetailRoute({ dropId }: { dropId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <PostDetailInner client={client} userId={userId} dropId={dropId} />}</DeveloperRouteGate>;
}
