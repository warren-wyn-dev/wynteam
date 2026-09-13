"use client";

import type { Session } from "@supabase/supabase-js";
import {
  Bell,
  Bookmark,
  ChevronRight,
  Compass,
  Heart,
  ImagePlus,
  Menu,
  MessageCircle,
  MessagesSquare,
  MoreHorizontal,
  Plus,
  Repeat2,
  Search,
  UserRound,
  UsersRound,
  X,
} from "lucide-react";
import { useRouter } from "next/navigation";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type TouchEvent,
} from "react";

import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import {
  DropPublicationStateUnknownError,
  publishDropSafely,
} from "@/lib/drop-publication";
import { fetchHomeSurfaceRows, type HomeSurface } from "@/lib/home-feed-sources";
import {
  loadHomeViewerState,
  toggleAuthorFollow,
  toggleDropLike,
  toggleDropRedrop,
  toggleDropSave,
  type HomeViewerState,
} from "@/lib/home-actions";
import {
  fetchClubHomePosts,
  fetchHomeChatBadge,
  fetchHomeIdentity,
  toggleClubPostLike,
  toggleClubPostSave,
  type ClubHomePost,
  type HomeIdentity,
} from "@/lib/home-parity-data";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

type FeedMode = "for-you" | "following" | "clubs";
type ViewerSetKey = keyof HomeViewerState;

const feedModes: Array<{ id: FeedMode; label: string }> = [
  { id: "for-you", label: "สำหรับคุณ" },
  { id: "following", label: "กำลังติดตาม" },
  { id: "clubs", label: "คลับของฉัน" },
];

const emptyViewerState = (): HomeViewerState => ({
  likedDropIds: new Set(),
  savedDropIds: new Set(),
  redroppedDropIds: new Set(),
  followedAuthorIds: new Set(),
  pendingFollowAuthorIds: new Set(),
  privateAuthorIds: new Set(),
});

function withViewerSet(
  state: HomeViewerState,
  key: ViewerSetKey,
  value: string,
  enabled: boolean,
): HomeViewerState {
  const next = new Set(state[key]);
  if (enabled) next.add(value);
  else next.delete(value);
  return { ...state, [key]: next };
}

function Avatar({ src, label, size = 42 }: { src?: string | null; label: string; size?: number }) {
  const [failed, setFailed] = useState(false);
  if (!src || failed) {
    return <span className="avatar avatar-fallback" style={{ width: size, height: size }}>{label.trim().slice(0, 1).toUpperCase() || "W"}</span>;
  }
  // eslint-disable-next-line @next/next/no-img-element
  return <img className="avatar" src={src} alt="" width={size} height={size} loading="lazy" decoding="async" onError={() => setFailed(true)} />;
}

function Caption({ value }: { value: string }) {
  const parts = value.split(/((?:https?:\/\/[^\s]+)|(?:#[\p{L}\p{N}_]+))/gu);
  return (
    <p className="caption">
      {parts.map((part, index) => {
        if (/^https?:\/\//i.test(part)) return <a className="linkish" href={part} target="_blank" rel="noreferrer" key={`${part}-${index}`}>{part}</a>;
        if (part.startsWith("#")) return <span className="hashtag" key={`${part}-${index}`}>{part}</span>;
        return part;
      })}
    </p>
  );
}

function FeedPost({
  row,
  userId,
  viewer,
  pending,
  onLike,
  onSave,
  onRedrop,
  onFollow,
  onOpen,
}: {
  row: HomeFeedRow;
  userId: string;
  viewer: HomeViewerState;
  pending: Set<string>;
  onLike: (row: HomeFeedRow) => void;
  onSave: (row: HomeFeedRow) => void;
  onRedrop: (row: HomeFeedRow) => void;
  onFollow: (row: HomeFeedRow) => void;
  onOpen: (row: HomeFeedRow) => void;
}) {
  const liked = viewer.likedDropIds.has(row.id);
  const saved = viewer.savedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const following = viewer.followedAuthorIds.has(row.author_id);
  const requested = viewer.pendingFollowAuthorIds.has(row.author_id);
  const privateAuthor = viewer.privateAuthorIds.has(row.author_id);
  const showFollow = row.author_id !== userId && !following;
  return (
    <article className="post parity-feed-post">
      <button className="avatar-button" type="button" aria-label={`เปิดโปรไฟล์ ${authorLabel(row)}`} onClick={() => location.assign(`/profile/${row.author_id}`)}>
        <Avatar src={row.author_avatar_url} label={row.author_username || authorLabel(row)} />
      </button>
      <div className="post-main">
        {row.redrop_id && row.redropper_username ? <p className="redrop-label">รีโพสต์โดย @{row.redropper_username}</p> : null}
        <div className="post-header">
          <button className="author-link" type="button" onClick={() => location.assign(`/profile/${row.author_id}`)}>
            <span className="author">{authorLabel(row)}</span>
          </button>
          {row.author_is_verified ? <span className="verified" aria-label="บัญชีที่ยืนยันแล้ว">●</span> : null}
          {showFollow ? (
            <button className={`follow-pill ${requested ? "requested" : ""}`} type="button" disabled={pending.has(`follow:${row.author_id}`)} onClick={() => onFollow(row)}>
              {privateAuthor && requested ? "ขอติดตามแล้ว" : "ติดตาม"}
            </button>
          ) : null}
          <span className="timestamp">{relativeTimeTh(row.created_at)}</span>
          <button className="icon-button more-button" type="button" aria-label="ตัวเลือกเพิ่มเติม"><MoreHorizontal size={20} strokeWidth={1.8} /></button>
        </div>
        <button className="post-open-button" type="button" onClick={() => onOpen(row)}>
          {row.quote_text ? <Caption value={row.quote_text} /> : null}
          {row.caption ? <Caption value={row.caption} /> : null}
          {row.image_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img className="post-media" src={row.image_url} alt="" loading="lazy" decoding="async" />
          ) : null}
        </button>
        <div className="action-row" aria-label="กิจกรรมโพสต์">
          <button className={`metric metric-button ${liked ? "liked" : ""}`} type="button" aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"} disabled={pending.has(`like:${row.id}`)} onClick={() => onLike(row)}>
            <Heart aria-hidden="true" strokeWidth={1.75} fill={liked ? "currentColor" : "none"} />
            {(row.like_count ?? 0) > 0 ? <span>{row.like_count}</span> : null}
          </button>
          <button className="metric metric-button" type="button" aria-label="ความคิดเห็น" onClick={() => onOpen(row)}>
            <MessageCircle aria-hidden="true" strokeWidth={1.75} />
            {(row.comment_count ?? 0) > 0 ? <span>{row.comment_count}</span> : null}
          </button>
          <button className={`metric metric-button ${redropped ? "active" : ""}`} type="button" aria-label={redropped ? "ยกเลิกรีโพสต์" : "รีโพสต์"} disabled={pending.has(`redrop:${row.id}`)} onClick={() => onRedrop(row)}>
            <Repeat2 aria-hidden="true" strokeWidth={1.75} />
            {(row.redrop_count ?? 0) > 0 ? <span>{row.redrop_count}</span> : null}
          </button>
          <button className={`metric metric-button metric-save ${saved ? "active" : ""}`} type="button" aria-label={saved ? "นำออกจากที่บันทึก" : "บันทึก"} disabled={pending.has(`save:${row.id}`)} onClick={() => onSave(row)}>
            <Bookmark aria-hidden="true" strokeWidth={1.75} fill={saved ? "currentColor" : "none"} />
          </button>
        </div>
      </div>
    </article>
  );
}

function ClubPostCard({
  post,
  pending,
  onLike,
  onSave,
  onOpen,
}: {
  post: ClubHomePost;
  pending: Set<string>;
  onLike: (post: ClubHomePost) => void;
  onSave: (post: ClubHomePost) => void;
  onOpen: (post: ClubHomePost) => void;
}) {
  const name = post.author_display_name?.trim() || post.author_username || "WYNOS";
  return (
    <article className="post parity-feed-post club-home-card">
      <Avatar src={post.author_avatar_url} label={post.author_username || name} />
      <div className="post-main">
        <div className="post-header"><span className="author">{name}</span><span className="timestamp">{relativeTimeTh(post.created_at)}</span><button className="icon-button more-button" type="button" aria-label="ตัวเลือกเพิ่มเติม"><MoreHorizontal size={20} /></button></div>
        <button className="post-open-button" type="button" onClick={() => onOpen(post)}>
          {post.content ? <Caption value={post.content} /> : null}
          {post.image_urls[0] ? <img className="post-media" src={post.image_urls[0]} alt="" loading="lazy" decoding="async" /> : null}
          {post.link_url ? <span className="club-link-preview">{post.link_url}</span> : null}
        </button>
        <div className="action-row" aria-label="กิจกรรมโพสต์">
          <button className={`metric metric-button ${post.liked_by_me ? "liked" : ""}`} type="button" aria-label={post.liked_by_me ? "เลิกถูกใจ" : "ถูกใจ"} disabled={pending.has(`club-like:${post.id}`)} onClick={() => onLike(post)}><Heart fill={post.liked_by_me ? "currentColor" : "none"} />{post.like_count > 0 ? <span>{post.like_count}</span> : null}</button>
          <button className="metric metric-button" type="button" aria-label="ความคิดเห็น" onClick={() => onOpen(post)}><MessageCircle />{post.comment_count > 0 ? <span>{post.comment_count}</span> : null}</button>
          <button className={`metric metric-button metric-save ${post.saved_by_me ? "active" : ""}`} type="button" aria-label={post.saved_by_me ? "นำออกจากที่บันทึก" : "บันทึก"} disabled={pending.has(`club-save:${post.id}`)} onClick={() => onSave(post)}><Bookmark fill={post.saved_by_me ? "currentColor" : "none"} /></button>
        </div>
      </div>
    </article>
  );
}

function SideDrawer({ identity, userId, onClose }: { identity: HomeIdentity | null; userId: string; onClose: () => void }) {
  const router = useRouter();
  const name = identity?.display_name?.trim() || identity?.username || "WYNOS";
  const go = (href: string) => { onClose(); router.push(href); };
  const rows = [
    { label: "สำรวจ Club", icon: Compass, href: "/search" },
    { label: "สร้าง Club", icon: Plus, href: "/search" },
    { label: "Club ของฉัน", icon: UsersRound, href: "/search" },
    { label: "บันทึกไว้", icon: Bookmark, href: `/profile/${userId}` },
  ];
  return (
    <div className="home-drawer-backdrop" role="presentation" onClick={onClose}>
      <aside className="home-drawer" role="dialog" aria-modal="true" aria-label="เมนู" onClick={(event) => event.stopPropagation()}>
        <div className="home-drawer-close"><button className="icon-button" type="button" aria-label="ปิด" onClick={onClose}><X size={22} /></button></div>
        <button className="drawer-identity" type="button" onClick={() => go(`/profile/${userId}`)}>
          <Avatar src={identity?.avatar_url} label={identity?.username || name} size={56} />
          <span className="drawer-identity-copy"><strong>{name}</strong>{identity?.username ? <small>@{identity.username}</small> : null}<span><b>{identity?.follower_count ?? 0}</b> ผู้ติดตาม <b>{identity?.following_count ?? 0}</b> กำลังติดตาม</span></span>
          <ChevronRight size={20} />
        </button>
        <div className="drawer-divider" />
        <div className="drawer-menu-list">
          {rows.map(({ label, icon: Icon, href }) => <button className="drawer-menu-row" type="button" onClick={() => go(href)} key={label}><span className="drawer-menu-icon"><Icon size={19} /></span><span>{label}</span><ChevronRight size={19} /></button>)}
        </div>
      </aside>
    </div>
  );
}

export function ParityHome({ session }: { session: Session }) {
  const router = useRouter();
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const userId = session.user.id;
  const [mode, setMode] = useState<FeedMode>("for-you");
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [clubPosts, setClubPosts] = useState<ClubHomePost[]>([]);
  const [viewer, setViewer] = useState<HomeViewerState>(emptyViewerState);
  const [pending, setPending] = useState<Set<string>>(new Set());
  const pendingRef = useRef<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [identity, setIdentity] = useState<HomeIdentity | null>(null);
  const [chatBadge, setChatBadge] = useState(0);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [toast, setToast] = useState("");
  const toastTimer = useRef<number | null>(null);
  const [composerOpen, setComposerOpen] = useState(false);
  const [composerCaption, setComposerCaption] = useState("");
  const [composerFiles, setComposerFiles] = useState<File[]>([]);
  const [publicationOperationId, setPublicationOperationId] = useState<string | null>(null);
  const [publishing, setPublishing] = useState(false);
  const touchStart = useRef<number | null>(null);

  const showToast = useCallback((value: string) => {
    setToast(value);
    if (toastTimer.current != null) window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(""), 2600);
  }, []);

  useEffect(() => () => { if (toastTimer.current != null) window.clearTimeout(toastTimer.current); }, []);

  const loadIdentity = useCallback(async () => {
    if (!supabase) return;
    try {
      const [nextIdentity, badge] = await Promise.all([
        fetchHomeIdentity(supabase, userId),
        fetchHomeChatBadge(supabase).catch(() => 0),
      ]);
      setIdentity(nextIdentity);
      setChatBadge(badge);
    } catch { /* secondary chrome never blocks Home */ }
  }, [supabase, userId]);

  const loadFeed = useCallback(async (nextMode: FeedMode) => {
    if (!supabase) return;
    setLoading(true);
    try {
      if (nextMode === "clubs") {
        setRows([]);
        setViewer(emptyViewerState());
        setClubPosts(await fetchClubHomePosts(supabase, userId));
      } else {
        setClubPosts([]);
        const surface: HomeSurface = { kind: nextMode === "following" ? "following" : "ranked" };
        const nextRows = await fetchHomeSurfaceRows(supabase, userId, surface);
        const nextViewer = await loadHomeViewerState(supabase, userId, nextRows);
        setRows(nextRows);
        setViewer(nextViewer);
      }
    } catch {
      showToast("โหลดฟีดไม่สำเร็จ กรุณาลองใหม่");
    } finally {
      setLoading(false);
    }
  }, [showToast, supabase, userId]);

  useEffect(() => { void loadIdentity(); void loadFeed(mode); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (new URLSearchParams(window.location.search).get("compose") === "1") {
      setComposerOpen(true);
      router.replace("/");
    }
  }, [router]);

  const beginPending = (key: string) => {
    if (pendingRef.current.has(key)) return false;
    pendingRef.current.add(key); setPending(new Set(pendingRef.current)); return true;
  };
  const endPending = (key: string) => { pendingRef.current.delete(key); setPending(new Set(pendingRef.current)); };
  const patchCount = (id: string, field: "like_count" | "redrop_count", delta: number) => setRows((current) => current.map((row) => row.id === id ? { ...row, [field]: Math.max(0, (row[field] ?? 0) + delta) } : row));

  const onLike = async (row: HomeFeedRow) => {
    if (!supabase) return; const key = `like:${row.id}`; if (!beginPending(key)) return;
    const wasLiked = viewer.likedDropIds.has(row.id); setViewer((current) => withViewerSet(current, "likedDropIds", row.id, !wasLiked)); patchCount(row.id, "like_count", wasLiked ? -1 : 1);
    try { await toggleDropLike(supabase, userId, row.id, wasLiked); } catch { setViewer((current) => withViewerSet(current, "likedDropIds", row.id, wasLiked)); patchCount(row.id, "like_count", wasLiked ? 1 : -1); showToast("อัปเดตการถูกใจไม่สำเร็จ"); } finally { endPending(key); }
  };
  const onSave = async (row: HomeFeedRow) => {
    if (!supabase) return; const key = `save:${row.id}`; if (!beginPending(key)) return;
    const wasSaved = viewer.savedDropIds.has(row.id); setViewer((current) => withViewerSet(current, "savedDropIds", row.id, !wasSaved));
    try { await toggleDropSave(supabase, userId, row.id, wasSaved); } catch { setViewer((current) => withViewerSet(current, "savedDropIds", row.id, wasSaved)); showToast("อัปเดตที่บันทึกไม่สำเร็จ"); } finally { endPending(key); }
  };
  const onRedrop = async (row: HomeFeedRow) => {
    if (!supabase) return; const key = `redrop:${row.id}`; if (!beginPending(key)) return;
    const was = viewer.redroppedDropIds.has(row.id); setViewer((current) => withViewerSet(current, "redroppedDropIds", row.id, !was)); patchCount(row.id, "redrop_count", was ? -1 : 1);
    try { await toggleDropRedrop(supabase, userId, row.id, was); } catch { setViewer((current) => withViewerSet(current, "redroppedDropIds", row.id, was)); patchCount(row.id, "redrop_count", was ? 1 : -1); showToast("รีโพสต์ไม่สำเร็จ"); } finally { endPending(key); }
  };
  const onFollow = async (row: HomeFeedRow) => {
    if (!supabase || row.author_id === userId) return; const key = `follow:${row.author_id}`; if (!beginPending(key)) return;
    const wasFollowing = viewer.followedAuthorIds.has(row.author_id); const wasRequested = viewer.pendingFollowAuthorIds.has(row.author_id); const isPrivate = viewer.privateAuthorIds.has(row.author_id);
    if (isPrivate && wasRequested && !window.confirm(`ยกเลิกคำขอติดตาม ${authorLabel(row)}?`)) { endPending(key); return; }
    try {
      const state = await toggleAuthorFollow(supabase, userId, row.author_id, { currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate });
      setViewer((current) => { let next = withViewerSet(current, "followedAuthorIds", row.author_id, state === "following"); next = withViewerSet(next, "pendingFollowAuthorIds", row.author_id, state === "requested"); return next; });
    } catch { showToast("อัปเดตการติดตามไม่สำเร็จ"); } finally { endPending(key); }
  };
  const onClubLike = async (post: ClubHomePost) => {
    if (!supabase) return; const key = `club-like:${post.id}`; if (!beginPending(key)) return;
    setClubPosts((current) => current.map((item) => item.id === post.id ? { ...item, liked_by_me: !post.liked_by_me, like_count: Math.max(0, post.like_count + (post.liked_by_me ? -1 : 1)) } : item));
    try { await toggleClubPostLike(supabase, userId, post.id, post.liked_by_me); } catch { setClubPosts((current) => current.map((item) => item.id === post.id ? post : item)); showToast("อัปเดตการถูกใจไม่สำเร็จ"); } finally { endPending(key); }
  };
  const onClubSave = async (post: ClubHomePost) => {
    if (!supabase) return; const key = `club-save:${post.id}`; if (!beginPending(key)) return;
    setClubPosts((current) => current.map((item) => item.id === post.id ? { ...item, saved_by_me: !post.saved_by_me } : item));
    try { await toggleClubPostSave(supabase, userId, post.id, post.saved_by_me); } catch { setClubPosts((current) => current.map((item) => item.id === post.id ? post : item)); showToast("อัปเดตที่บันทึกไม่สำเร็จ"); } finally { endPending(key); }
  };

  const selectMode = (next: FeedMode) => { if (next === mode) { window.scrollTo({ top: 0, behavior: "smooth" }); void loadFeed(next); return; } setMode(next); void loadFeed(next); };
  const onTouchStart = (event: TouchEvent) => { touchStart.current = event.changedTouches[0]?.clientX ?? null; };
  const onTouchEnd = (event: TouchEvent) => {
    if (touchStart.current == null) return; const delta = (event.changedTouches[0]?.clientX ?? touchStart.current) - touchStart.current; touchStart.current = null; if (Math.abs(delta) < 70) return;
    const index = feedModes.findIndex((item) => item.id === mode); const next = delta < 0 ? Math.min(feedModes.length - 1, index + 1) : Math.max(0, index - 1); if (next !== index) selectMode(feedModes[next].id);
  };

  const submitDrop = async () => {
    if (!supabase || publishing) return; setPublishing(true);
    try {
      await publishDropSafely(supabase, userId, { caption: composerCaption, files: composerFiles, operationId: publicationOperationId });
      setPublicationOperationId(null); setComposerCaption(""); setComposerFiles([]); setComposerOpen(false); showToast("เผยแพร่ Drop แล้ว"); setMode("for-you"); await loadFeed("for-you");
    } catch (error) {
      if (error instanceof DropPublicationStateUnknownError) setPublicationOperationId(error.operationId);
      showToast(error instanceof Error ? error.message : "เผยแพร่ Drop ไม่สำเร็จ");
    } finally { setPublishing(false); }
  };

  return (
    <div className="wynos-app parity-home-app">
      <main className="wynos-main parity-home-main" onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
        <header className="parity-home-shell">
          <div className="parity-home-header">
            <button className="home-header-action" type="button" aria-label="เมนู" onClick={() => setDrawerOpen(true)}><Menu size={22} /></button>
            <div className="home-wordmark" aria-label="WYNOS"><span className="home-logo-mark" aria-hidden="true">W</span><strong>WYNOS</strong></div>
            <button className="home-header-action home-chat-action" type="button" aria-label={chatBadge > 0 ? `ข้อความ, ${chatBadge} บทสนทนายังไม่อ่าน` : "ข้อความ"} onClick={() => router.push("/chat")}><MessagesSquare size={23} />{chatBadge > 0 ? <span className="home-chat-badge">{chatBadge > 9 ? "9+" : chatBadge}</span> : null}</button>
          </div>
          <div className="parity-home-tabs" role="tablist" aria-label="ฟีด">
            {feedModes.map((item) => <button className={mode === item.id ? "active" : ""} type="button" role="tab" aria-selected={mode === item.id} onClick={() => selectMode(item.id)} key={item.id}>{item.label}</button>)}
          </div>
        </header>
        <section className="home-feed-surface" aria-live="polite">
          {loading ? <div className="home-loading"><div className="route-system-spinner" /></div> : mode === "clubs" ? (
            clubPosts.length ? clubPosts.map((post) => <ClubPostCard post={post} pending={pending} onLike={(value) => void onClubLike(value)} onSave={(value) => void onClubSave(value)} onOpen={(value) => router.push(`/club-post/${value.id}`)} key={post.id} />) : <div className="home-empty"><p>เข้าร่วม Club เพื่อดูโพสต์ที่นี่</p><button className="route-secondary" type="button" onClick={() => router.push("/search")}>สำรวจ Club</button></div>
          ) : rows.length ? rows.map((row) => <FeedPost row={row} userId={userId} viewer={viewer} pending={pending} onLike={(value) => void onLike(value)} onSave={(value) => void onSave(value)} onRedrop={(value) => void onRedrop(value)} onFollow={(value) => void onFollow(value)} onOpen={(value) => router.push(`/drop/${value.id}`)} key={`${row.id}:${row.redrop_id ?? "plain"}`} />) : <div className="home-empty">ยังไม่มีโพสต์ที่แสดงได้ในฟีดนี้</div>}
        </section>
      </main>

      <nav className="bottom-nav" aria-label="เมนูหลัก">
        <button className="nav-button active" type="button" aria-label="หน้าหลัก" onClick={() => selectMode(mode)}><HomeIcon /></button>
        <button className="nav-button" type="button" aria-label="ค้นหา" onClick={() => router.push("/search")}><Search /></button>
        <button className="nav-button" type="button" aria-label="สร้างโพสต์" onClick={() => setComposerOpen(true)}><span className="create-button"><Plus /></span></button>
        <button className="nav-button" type="button" aria-label="การแจ้งเตือน" onClick={() => router.push("/notifications")}><Bell /></button>
        <button className="nav-button" type="button" aria-label="โปรไฟล์" onClick={() => router.push(`/profile/${userId}`)}><UserRound /></button>
      </nav>

      {drawerOpen ? <SideDrawer identity={identity} userId={userId} onClose={() => setDrawerOpen(false)} /> : null}

      {composerOpen ? (
        <div className="sheet-backdrop" role="presentation" onClick={() => !publishing && setComposerOpen(false)}>
          <section className="sheet composer-sheet parity-composer" role="dialog" aria-modal="true" aria-label="สร้าง Drop" onClick={(event) => event.stopPropagation()}>
            <header className="sheet-header"><button className="icon-button" type="button" aria-label="ปิด" disabled={publishing} onClick={() => setComposerOpen(false)}><X /></button><strong>สร้าง Drop</strong><button className="share-button" type="button" disabled={publishing || (!composerCaption.trim() && !composerFiles.length)} onClick={() => void submitDrop()}>{publishing ? "กำลังแชร์…" : "แชร์"}</button></header>
            <div className="composer-body"><textarea autoFocus value={composerCaption} maxLength={500} placeholder="มีอะไรอยาก Drop ไหม?" onChange={(event) => { setComposerCaption(event.target.value); setPublicationOperationId(null); }} /><div className="composer-tools"><label className="image-picker"><ImagePlus size={22} /><span>เพิ่มรูป</span><input type="file" accept="image/*" multiple disabled={publishing} onChange={(event) => { setComposerFiles(Array.from(event.target.files ?? []).slice(0, 9)); setPublicationOperationId(null); }} /></label><span>{composerCaption.length}/500</span></div>{composerFiles.length ? <div className="selected-files"><strong>รูปที่เลือก {composerFiles.length}/9</strong>{composerFiles.map((file) => <span key={`${file.name}:${file.size}`}>{file.name}</span>)}</div> : null}{publicationOperationId ? <p className="publication-retry-note">ระบบจะลองเผยแพร่รายการเดิมอีกครั้งอย่างปลอดภัย โดยไม่สร้าง Drop ซ้ำ</p> : null}</div>
          </section>
        </div>
      ) : null}
      {toast ? <div className="toast" role="status">{toast}</div> : null}
    </div>
  );
}

function HomeIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 10.8 12 3l9 7.8v9.7a.5.5 0 0 1-.5.5H15v-6H9v6H3.5a.5.5 0 0 1-.5-.5z" fill="currentColor" /></svg>;
}
