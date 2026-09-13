"use client";

import {
  Bell,
  Bookmark,
  Heart,
  Home,
  ImagePlus,
  Menu,
  MessageCircle,
  MoreHorizontal,
  Plus,
  Repeat2,
  Search,
  Send,
  UserRound,
  X,
} from "lucide-react";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import type { Session } from "@supabase/supabase-js";

import { authorLabel, rankedDropRows, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import {
  addDropComment,
  fetchDropComments,
  loadHomeViewerState,
  publishDrop,
  toggleAuthorFollow,
  toggleDropCommentLike,
  toggleDropLike,
  toggleDropRedrop,
  toggleDropSave,
  type DropCommentRow,
  type HomeViewerState,
} from "@/lib/home-actions";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

type GateState = "loading" | "missing-config" | "signed-out" | "regular" | "developer" | "error";
type ViewerSetKey = keyof HomeViewerState;

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

function Caption({ value, onOpen }: { value: string; onOpen?: () => void }) {
  const parts = value.split(/(#[\p{L}\p{N}_]+)/gu);
  return (
    <p className="caption" onClick={onOpen}>
      {parts.map((part, index) =>
        part.startsWith("#") ? (
          <span className="hashtag" key={`${part}-${index}`}>
            {part}
          </span>
        ) : (
          part
        ),
      )}
    </p>
  );
}

function Avatar({ row }: { row: HomeFeedRow }) {
  const [failed, setFailed] = useState(false);
  const label = authorLabel(row);
  if (!row.author_avatar_url || failed) {
    return <div className="avatar avatar-fallback">{label.slice(0, 1).toUpperCase()}</div>;
  }
  return (
    // Browser-native <img> is intentional: no Flutter CanvasKit decode/texture path.
    // eslint-disable-next-line @next/next/no-img-element
    <img
      className="avatar"
      src={row.author_avatar_url}
      alt=""
      width={42}
      height={42}
      loading="lazy"
      decoding="async"
      onError={() => setFailed(true)}
    />
  );
}

type FeedPostProps = {
  row: HomeFeedRow;
  userId: string;
  viewer: HomeViewerState;
  pending: Set<string>;
  onLike: (row: HomeFeedRow) => void;
  onComment: (row: HomeFeedRow) => void;
  onRedrop: (row: HomeFeedRow) => void;
  onSave: (row: HomeFeedRow) => void;
  onFollow: (row: HomeFeedRow) => void;
  compact?: boolean;
};

function FeedPost({
  row,
  userId,
  viewer,
  pending,
  onLike,
  onComment,
  onRedrop,
  onSave,
  onFollow,
  compact = false,
}: FeedPostProps) {
  const liked = viewer.likedDropIds.has(row.id);
  const saved = viewer.savedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const following = viewer.followedAuthorIds.has(row.author_id);
  const requested = viewer.pendingFollowAuthorIds.has(row.author_id);
  const privateAuthor = viewer.privateAuthorIds.has(row.author_id);
  const showFollow = row.author_id !== userId && !following;

  return (
    <article className={`post ${compact ? "post-compact" : ""}`}>
      <Avatar row={row} />
      <div className="post-main">
        {row.redrop_id && row.redropper_username ? (
          <p className="redrop-label">รีโพสต์โดย @{row.redropper_username}</p>
        ) : null}
        <div className="post-header">
          <span className="author">{authorLabel(row)}</span>
          {row.author_is_verified ? <span className="verified" aria-label="บัญชีที่ยืนยันแล้ว">●</span> : null}
          {showFollow ? (
            <button
              className={`follow-pill ${requested ? "requested" : ""}`}
              type="button"
              disabled={pending.has(`follow:${row.author_id}`)}
              onClick={() => onFollow(row)}
            >
              {privateAuthor && requested ? "ขอติดตามแล้ว" : "ติดตาม"}
            </button>
          ) : null}
          <span className="timestamp">{relativeTimeTh(row.created_at)}</span>
          <button className="icon-button more-button" type="button" aria-label="ตัวเลือกเพิ่มเติม">
            <MoreHorizontal size={20} strokeWidth={1.8} />
          </button>
        </div>
        {row.quote_text ? <Caption value={row.quote_text} onOpen={() => onComment(row)} /> : null}
        {row.caption ? <Caption value={row.caption} onOpen={() => onComment(row)} /> : null}
        {row.image_url ? (
          // Native browser image rendering is part of the migration goal.
          // eslint-disable-next-line @next/next/no-img-element
          <img
            className="post-media"
            src={row.image_url}
            alt=""
            loading="lazy"
            decoding="async"
            onClick={() => onComment(row)}
          />
        ) : null}
        <div className="action-row" aria-label="กิจกรรมโพสต์">
          <button
            className={`metric metric-button ${liked ? "liked" : ""}`}
            type="button"
            aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"}
            disabled={pending.has(`like:${row.id}`)}
            onClick={() => onLike(row)}
          >
            <Heart aria-hidden="true" strokeWidth={1.75} fill={liked ? "currentColor" : "none"} />
            {(row.like_count ?? 0) > 0 ? <span>{row.like_count}</span> : null}
          </button>
          <button className="metric metric-button" type="button" aria-label="ความคิดเห็น" onClick={() => onComment(row)}>
            <MessageCircle aria-hidden="true" strokeWidth={1.75} />
            {(row.comment_count ?? 0) > 0 ? <span>{row.comment_count}</span> : null}
          </button>
          <button
            className={`metric metric-button ${redropped ? "active" : ""}`}
            type="button"
            aria-label={redropped ? "ยกเลิกรีโพสต์" : "รีโพสต์"}
            disabled={pending.has(`redrop:${row.id}`)}
            onClick={() => onRedrop(row)}
          >
            <Repeat2 aria-hidden="true" strokeWidth={1.75} />
            {(row.redrop_count ?? 0) > 0 ? <span>{row.redrop_count}</span> : null}
          </button>
          <button
            className={`metric metric-button metric-save ${saved ? "active" : ""}`}
            type="button"
            aria-label={saved ? "นำออกจากที่บันทึก" : "บันทึก"}
            disabled={pending.has(`save:${row.id}`)}
            onClick={() => onSave(row)}
          >
            <Bookmark aria-hidden="true" strokeWidth={1.75} fill={saved ? "currentColor" : "none"} />
          </button>
        </div>
      </div>
    </article>
  );
}

function SignedOut({ onGoogle }: { onGoogle: () => Promise<void> }) {
  return (
    <main className="center-state">
      <h1>WYNOS</h1>
      <p>Next.js Web รุ่นทดสอบภายใน ใช้ Supabase เดิมและฟอนต์ระบบของอุปกรณ์ผ่าน browser โดยตรง</p>
      <button className="primary-button" type="button" onClick={() => void onGoogle()}>
        เข้าสู่ระบบด้วย Google
      </button>
    </main>
  );
}

function CommentAvatar({ comment }: { comment: DropCommentRow }) {
  const [failed, setFailed] = useState(false);
  const label = comment.author_display_name?.trim() || comment.author_username || "W";
  if (!comment.author_avatar_url || failed) {
    return <span className="comment-avatar avatar-fallback">{label.slice(0, 1).toUpperCase()}</span>;
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img className="comment-avatar" src={comment.author_avatar_url} alt="" onError={() => setFailed(true)} />
  );
}

export function HomeMigrationPreview() {
  const [gate, setGate] = useState<GateState>(() =>
    hasSupabaseBrowserConfig() ? "loading" : "missing-config",
  );
  const [session, setSession] = useState<Session | null>(null);
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [viewer, setViewer] = useState<HomeViewerState>(emptyViewerState);
  const [pending, setPending] = useState<Set<string>>(new Set());
  const [message, setMessage] = useState("");
  const [toast, setToast] = useState("");
  const [activeTab, setActiveTab] = useState("สำหรับคุณ");
  const [activeMode, setActiveMode] = useState("ทั้งหมด");
  const [visibleCount, setVisibleCount] = useState(10);
  const [detailPost, setDetailPost] = useState<HomeFeedRow | null>(null);
  const [comments, setComments] = useState<DropCommentRow[]>([]);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [commentDraft, setCommentDraft] = useState("");
  const [commentSending, setCommentSending] = useState(false);
  const [composerOpen, setComposerOpen] = useState(false);
  const [composerCaption, setComposerCaption] = useState("");
  const [composerFiles, setComposerFiles] = useState<File[]>([]);
  const [publishing, setPublishing] = useState(false);
  const loadMoreRef = useRef<HTMLDivElement | null>(null);

  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const userId = session?.user.id ?? "";

  const showToast = useCallback((value: string) => {
    setToast(value);
    window.setTimeout(() => setToast(""), 2600);
  }, []);

  const loadDeveloperPreview = useCallback(async (nextSession: Session | null) => {
    setSession(nextSession);
    setMessage("");

    if (!hasSupabaseBrowserConfig() || !supabase) {
      setGate("missing-config");
      return;
    }
    if (!nextSession) {
      setRows([]);
      setViewer(emptyViewerState());
      setGate("signed-out");
      return;
    }

    setGate("loading");
    const developerResult = await supabase.rpc("is_developer_account");
    if (developerResult.error || developerResult.data !== true) {
      setRows([]);
      setViewer(emptyViewerState());
      setGate("regular");
      return;
    }

    const feedResult = await supabase.rpc("get_wynos_ranked_feed");
    if (feedResult.error) {
      setMessage("โหลดฟีดไม่สำเร็จ กรุณาลองใหม่");
      setGate("error");
      return;
    }

    const nextRows = rankedDropRows(feedResult.data, 200);
    try {
      const nextViewer = await loadHomeViewerState(supabase, nextSession.user.id, nextRows);
      setRows(nextRows);
      setViewer(nextViewer);
      setVisibleCount(10);
      setGate("developer");
    } catch {
      setMessage("โหลดสถานะกิจกรรมไม่สำเร็จ กรุณาลองใหม่");
      setGate("error");
    }
  }, [supabase]);

  useEffect(() => {
    if (!supabase) return;
    let mounted = true;
    void supabase.auth.getSession().then(({ data }) => {
      if (mounted) void loadDeveloperPreview(data.session);
    });
    const { data: authSubscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (mounted) void loadDeveloperPreview(nextSession);
    });
    return () => {
      mounted = false;
      authSubscription.subscription.unsubscribe();
    };
  }, [loadDeveloperPreview, supabase]);

  useEffect(() => {
    const node = loadMoreRef.current;
    if (!node || visibleCount >= rows.length) return;
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        setVisibleCount((current) => Math.min(current + 10, rows.length));
      }
    }, { rootMargin: "500px 0px" });
    observer.observe(node);
    return () => observer.disconnect();
  }, [rows.length, visibleCount]);

  const signInWithGoogle = useCallback(async () => {
    if (!supabase) return;
    const redirectTo = `${window.location.origin}/`;
    const { error } = await supabase.auth.signInWithOAuth({ provider: "google", options: { redirectTo } });
    if (error) {
      setMessage("เริ่มเข้าสู่ระบบไม่สำเร็จ");
      setGate("error");
    }
  }, [supabase]);

  const signOut = useCallback(async () => {
    if (!supabase) return;
    await supabase.auth.signOut();
  }, [supabase]);

  const beginPending = useCallback((key: string) => {
    let allowed = false;
    setPending((current) => {
      if (current.has(key)) return current;
      allowed = true;
      const next = new Set(current);
      next.add(key);
      return next;
    });
    return allowed;
  }, []);

  const endPending = useCallback((key: string) => {
    setPending((current) => {
      const next = new Set(current);
      next.delete(key);
      return next;
    });
  }, []);

  const patchCounts = useCallback((dropId: string, field: "like_count" | "redrop_count" | "comment_count", delta: number) => {
    setRows((current) => current.map((row) => row.id === dropId
      ? { ...row, [field]: Math.max(0, (row[field] ?? 0) + delta) }
      : row));
    setDetailPost((current) => current?.id === dropId
      ? { ...current, [field]: Math.max(0, (current[field] ?? 0) + delta) }
      : current);
  }, []);

  const onLike = useCallback(async (row: HomeFeedRow) => {
    if (!supabase || !userId) return;
    const key = `like:${row.id}`;
    if (!beginPending(key)) return;
    const wasLiked = viewer.likedDropIds.has(row.id);
    setViewer((current) => withViewerSet(current, "likedDropIds", row.id, !wasLiked));
    patchCounts(row.id, "like_count", wasLiked ? -1 : 1);
    try {
      await toggleDropLike(supabase, userId, row.id, wasLiked);
    } catch {
      setViewer((current) => withViewerSet(current, "likedDropIds", row.id, wasLiked));
      patchCounts(row.id, "like_count", wasLiked ? 1 : -1);
      showToast("อัปเดตการถูกใจไม่สำเร็จ");
    } finally {
      endPending(key);
    }
  }, [beginPending, endPending, patchCounts, showToast, supabase, userId, viewer.likedDropIds]);

  const onSave = useCallback(async (row: HomeFeedRow) => {
    if (!supabase || !userId) return;
    const key = `save:${row.id}`;
    if (!beginPending(key)) return;
    const wasSaved = viewer.savedDropIds.has(row.id);
    setViewer((current) => withViewerSet(current, "savedDropIds", row.id, !wasSaved));
    try {
      await toggleDropSave(supabase, userId, row.id, wasSaved);
    } catch {
      setViewer((current) => withViewerSet(current, "savedDropIds", row.id, wasSaved));
      showToast("อัปเดตที่บันทึกไม่สำเร็จ");
    } finally {
      endPending(key);
    }
  }, [beginPending, endPending, showToast, supabase, userId, viewer.savedDropIds]);

  const onRedrop = useCallback(async (row: HomeFeedRow) => {
    if (!supabase || !userId) return;
    const key = `redrop:${row.id}`;
    if (!beginPending(key)) return;
    const wasRedropped = viewer.redroppedDropIds.has(row.id);
    setViewer((current) => withViewerSet(current, "redroppedDropIds", row.id, !wasRedropped));
    patchCounts(row.id, "redrop_count", wasRedropped ? -1 : 1);
    try {
      await toggleDropRedrop(supabase, userId, row.id, wasRedropped);
    } catch {
      setViewer((current) => withViewerSet(current, "redroppedDropIds", row.id, wasRedropped));
      patchCounts(row.id, "redrop_count", wasRedropped ? 1 : -1);
      showToast("รีโพสต์ไม่สำเร็จ");
    } finally {
      endPending(key);
    }
  }, [beginPending, endPending, patchCounts, showToast, supabase, userId, viewer.redroppedDropIds]);

  const onFollow = useCallback(async (row: HomeFeedRow) => {
    if (!supabase || !userId || row.author_id === userId) return;
    const key = `follow:${row.author_id}`;
    if (!beginPending(key)) return;
    const wasFollowing = viewer.followedAuthorIds.has(row.author_id);
    const wasRequested = viewer.pendingFollowAuthorIds.has(row.author_id);
    const isPrivate = viewer.privateAuthorIds.has(row.author_id);
    const optimisticState = wasFollowing ? "none" : isPrivate ? (wasRequested ? "none" : "requested") : "following";
    setViewer((current) => {
      let next = withViewerSet(current, "followedAuthorIds", row.author_id, optimisticState === "following");
      next = withViewerSet(next, "pendingFollowAuthorIds", row.author_id, optimisticState === "requested");
      return next;
    });
    try {
      await toggleAuthorFollow(supabase, userId, row.author_id, {
        currentlyFollowing: wasFollowing,
        pendingRequest: wasRequested,
        isPrivate,
      });
    } catch {
      setViewer((current) => {
        let next = withViewerSet(current, "followedAuthorIds", row.author_id, wasFollowing);
        next = withViewerSet(next, "pendingFollowAuthorIds", row.author_id, wasRequested);
        return next;
      });
      showToast("อัปเดตการติดตามไม่สำเร็จ");
    } finally {
      endPending(key);
    }
  }, [beginPending, endPending, showToast, supabase, userId, viewer]);

  const openComments = useCallback(async (row: HomeFeedRow) => {
    if (!supabase || !userId) return;
    setDetailPost(row);
    setComments([]);
    setCommentDraft("");
    setCommentsLoading(true);
    try {
      setComments(await fetchDropComments(supabase, userId, row.id));
    } catch {
      showToast("โหลดความคิดเห็นไม่สำเร็จ");
    } finally {
      setCommentsLoading(false);
    }
  }, [showToast, supabase, userId]);

  const submitComment = useCallback(async () => {
    if (!supabase || !userId || !detailPost || commentSending || !commentDraft.trim()) return;
    setCommentSending(true);
    try {
      const created = await addDropComment(supabase, userId, detailPost.id, commentDraft);
      setComments((current) => [...current, created]);
      patchCounts(detailPost.id, "comment_count", 1);
      setCommentDraft("");
    } catch {
      showToast("ส่งความคิดเห็นไม่สำเร็จ");
    } finally {
      setCommentSending(false);
    }
  }, [commentDraft, commentSending, detailPost, patchCounts, showToast, supabase, userId]);

  const onCommentLike = useCallback(async (comment: DropCommentRow) => {
    if (!supabase || !userId) return;
    const key = `comment-like:${comment.id}`;
    if (!beginPending(key)) return;
    const wasLiked = comment.liked_by_me;
    setComments((current) => current.map((item) => item.id === comment.id ? {
      ...item,
      liked_by_me: !wasLiked,
      like_count: Math.max(0, item.like_count + (wasLiked ? -1 : 1)),
    } : item));
    try {
      await toggleDropCommentLike(supabase, userId, comment.id, wasLiked);
    } catch {
      setComments((current) => current.map((item) => item.id === comment.id ? comment : item));
      showToast("อัปเดตการถูกใจความคิดเห็นไม่สำเร็จ");
    } finally {
      endPending(key);
    }
  }, [beginPending, endPending, showToast, supabase, userId]);

  const submitDrop = useCallback(async () => {
    if (!supabase || !userId || publishing) return;
    setPublishing(true);
    try {
      await publishDrop(supabase, userId, { caption: composerCaption, files: composerFiles });
      setComposerCaption("");
      setComposerFiles([]);
      setComposerOpen(false);
      showToast("เผยแพร่ Drop แล้ว");
      await loadDeveloperPreview(session);
    } catch (error) {
      showToast(error instanceof Error ? error.message : "เผยแพร่ Drop ไม่สำเร็จ");
    } finally {
      setPublishing(false);
    }
  }, [composerCaption, composerFiles, loadDeveloperPreview, publishing, session, showToast, supabase, userId]);

  if (gate === "loading") {
    return <main className="center-state"><h1>WYNOS</h1><p>กำลังเปิด Web รุ่นใหม่…</p></main>;
  }
  if (gate === "missing-config") {
    return <main className="center-state"><h1>WYNOS</h1><p>Preview นี้ยังไม่ได้ตั้งค่า Supabase environment variables</p></main>;
  }
  if (gate === "signed-out") return <SignedOut onGoogle={signInWithGoogle} />;
  if (gate === "regular") {
    return (
      <main className="center-state">
        <h1>WYNOS</h1>
        <p>Web รุ่นใหม่นี้ยังเปิดเฉพาะบัญชีนักพัฒนาตาม staged rollout ผู้ใช้ทั่วไปยังใช้ WYNOS เวอร์ชันปัจจุบันเหมือนเดิม</p>
        <button className="secondary-button" type="button" onClick={() => void signOut()}>ออกจากระบบ</button>
      </main>
    );
  }
  if (gate === "error") {
    return (
      <main className="center-state">
        <h1>WYNOS</h1>
        <p>{message || "เกิดข้อผิดพลาด"}</p>
        <button className="primary-button" type="button" onClick={() => void loadDeveloperPreview(session)}>ลองใหม่</button>
      </main>
    );
  }

  const visibleRows = rows.slice(0, visibleCount);
  const phaseTwoPrimaryFeed = activeTab === "สำหรับคุณ" && (activeMode === "ทั้งหมด" || activeMode === "Drop");

  return (
    <div className="wynos-app">
      <main className="wynos-main">
        <header className="top-shell">
          <div className="wordmark-row">
            <h1 className="wordmark">WYNOS</h1>
            <div className="icon-row">
              <button className="icon-button" type="button" aria-label="ค้นหา"><Search size={25} strokeWidth={1.8} /></button>
              <button className="icon-button" type="button" aria-label="เมนู"><Menu size={27} strokeWidth={1.8} /></button>
            </div>
          </div>
          <div className="primary-tabs" role="tablist" aria-label="ฟีด">
            {["สำหรับคุณ", "กำลังติดตาม"].map((tab) => (
              <button
                className={`primary-tab ${activeTab === tab ? "active" : ""}`}
                type="button"
                role="tab"
                aria-selected={activeTab === tab}
                onClick={() => setActiveTab(tab)}
                key={tab}
              >{tab}</button>
            ))}
          </div>
          <div className="mode-strip" aria-label="ประเภทฟีด">
            {["ทั้งหมด", "Drop", "กำลังนิยม"].map((mode) => (
              <button
                className={`mode-pill ${activeMode === mode ? "active" : ""}`}
                type="button"
                aria-pressed={activeMode === mode}
                onClick={() => setActiveMode(mode)}
                key={mode}
              >{mode}</button>
            ))}
          </div>
        </header>

        {!phaseTwoPrimaryFeed ? (
          <p className="status-note">Phase 2 กำลังย้ายแหล่งฟีด “กำลังติดตาม / กำลังนิยม” ต่อจาก interaction หลัก โดย Production เดิมยังไม่เปลี่ยน</p>
        ) : visibleRows.length ? (
          <>
            {visibleRows.map((row) => (
              <FeedPost
                row={row}
                userId={userId}
                viewer={viewer}
                pending={pending}
                onLike={(value) => void onLike(value)}
                onComment={(value) => void openComments(value)}
                onRedrop={(value) => void onRedrop(value)}
                onSave={(value) => void onSave(value)}
                onFollow={(value) => void onFollow(value)}
                key={`${row.id}:${row.redrop_id ?? "plain"}`}
              />
            ))}
            {visibleCount < rows.length ? <div className="feed-sentinel" ref={loadMoreRef}>กำลังโหลดเพิ่ม…</div> : null}
          </>
        ) : (
          <p className="status-note">ยังไม่มีโพสต์ที่แสดงได้ในฟีดนี้</p>
        )}
      </main>

      <nav className="bottom-nav" aria-label="เมนูหลัก">
        <button className="nav-button active" type="button" aria-label="หน้าหลัก"><Home size={25} strokeWidth={1.9} /></button>
        <button className="nav-button" type="button" aria-label="ค้นหา"><Search size={25} strokeWidth={1.8} /></button>
        <button className="nav-button" type="button" aria-label="สร้างโพสต์" onClick={() => setComposerOpen(true)}><span className="create-button"><Plus size={24} strokeWidth={2} /></span></button>
        <button className="nav-button" type="button" aria-label="การแจ้งเตือน"><Bell size={25} strokeWidth={1.8} /></button>
        <button className="nav-button" type="button" aria-label="โปรไฟล์"><UserRound size={25} strokeWidth={1.8} /></button>
      </nav>

      {detailPost ? (
        <div className="sheet-backdrop" role="presentation" onClick={() => setDetailPost(null)}>
          <section className="sheet detail-sheet" role="dialog" aria-modal="true" aria-label="รายละเอียดโพสต์" onClick={(event) => event.stopPropagation()}>
            <header className="sheet-header">
              <button className="icon-button" type="button" aria-label="ปิด" onClick={() => setDetailPost(null)}><X /></button>
              <strong>โพสต์</strong>
              <span className="sheet-header-spacer" />
            </header>
            <div className="sheet-scroll">
              <FeedPost
                row={detailPost}
                userId={userId}
                viewer={viewer}
                pending={pending}
                onLike={(value) => void onLike(value)}
                onComment={() => undefined}
                onRedrop={(value) => void onRedrop(value)}
                onSave={(value) => void onSave(value)}
                onFollow={(value) => void onFollow(value)}
                compact
              />
              <div className="comments-section">
                <h2>ความคิดเห็น</h2>
                {commentsLoading ? <p className="comment-empty">กำลังโหลด…</p> : null}
                {!commentsLoading && !comments.length ? <p className="comment-empty">ยังไม่มีความคิดเห็น</p> : null}
                {comments.map((comment) => (
                  <article className={`comment-row ${comment.parent_comment_id ? "reply" : ""}`} key={comment.id}>
                    <CommentAvatar comment={comment} />
                    <div className="comment-body">
                      <div className="comment-meta">
                        <strong>{comment.author_display_name?.trim() || comment.author_username || "WYNOS"}</strong>
                        <span>{relativeTimeTh(comment.created_at)}</span>
                      </div>
                      <p>{comment.text_content}</p>
                    </div>
                    <button
                      className={`comment-like ${comment.liked_by_me ? "liked" : ""}`}
                      type="button"
                      disabled={pending.has(`comment-like:${comment.id}`)}
                      aria-label={comment.liked_by_me ? "เลิกถูกใจความคิดเห็น" : "ถูกใจความคิดเห็น"}
                      onClick={() => void onCommentLike(comment)}
                    >
                      <Heart size={16} fill={comment.liked_by_me ? "currentColor" : "none"} />
                      {comment.like_count > 0 ? <span>{comment.like_count}</span> : null}
                    </button>
                  </article>
                ))}
              </div>
            </div>
            <form className="comment-composer" onSubmit={(event) => { event.preventDefault(); void submitComment(); }}>
              <input
                value={commentDraft}
                maxLength={500}
                placeholder="เพิ่มความคิดเห็น…"
                aria-label="ความคิดเห็น"
                onChange={(event) => setCommentDraft(event.target.value)}
              />
              <button type="submit" aria-label="ส่งความคิดเห็น" disabled={commentSending || !commentDraft.trim()}><Send size={20} /></button>
            </form>
          </section>
        </div>
      ) : null}

      {composerOpen ? (
        <div className="sheet-backdrop" role="presentation" onClick={() => !publishing && setComposerOpen(false)}>
          <section className="sheet composer-sheet" role="dialog" aria-modal="true" aria-label="สร้าง Drop" onClick={(event) => event.stopPropagation()}>
            <header className="sheet-header">
              <button className="icon-button" type="button" aria-label="ปิด" disabled={publishing} onClick={() => setComposerOpen(false)}><X /></button>
              <strong>สร้าง Drop</strong>
              <button className="share-button" type="button" disabled={publishing || (!composerCaption.trim() && !composerFiles.length)} onClick={() => void submitDrop()}>
                {publishing ? "กำลังแชร์…" : "แชร์"}
              </button>
            </header>
            <div className="composer-body">
              <textarea
                autoFocus
                value={composerCaption}
                maxLength={500}
                placeholder="มีอะไรอยาก Drop ไหม?"
                onChange={(event) => setComposerCaption(event.target.value)}
              />
              <div className="composer-tools">
                <label className="image-picker">
                  <ImagePlus size={22} />
                  <span>เพิ่มรูป</span>
                  <input
                    type="file"
                    accept="image/*"
                    multiple
                    disabled={publishing}
                    onChange={(event) => setComposerFiles(Array.from(event.target.files ?? []).slice(0, 9))}
                  />
                </label>
                <span>{composerCaption.length}/500</span>
              </div>
              {composerFiles.length ? (
                <div className="selected-files">
                  <strong>รูปที่เลือก {composerFiles.length}/9</strong>
                  {composerFiles.map((file) => <span key={`${file.name}:${file.size}`}>{file.name}</span>)}
                </div>
              ) : null}
            </div>
          </section>
        </div>
      ) : null}

      {toast ? <div className="toast" role="status">{toast}</div> : null}
    </div>
  );
}
