"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { Bookmark, ChevronRight, Flag, Quote, Repeat2, Share2, X } from "lucide-react";
import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState, type TouchEvent } from "react";
import { useInView } from "react-intersection-observer";

import { ClubFeedPost } from "@/components/home/club-feed-post";
import { HomeHeader } from "@/components/home/home-header";
import { HomePostCard } from "@/components/home/home-post-card";
import { HOME_FEED_MODES, HomeTabs, type HomeFeedMode } from "@/components/home/home-tabs";
import { AppChrome } from "@/components/phase3-ui";
import { FeedSkeleton } from "@/components/ui/skeleton";
import { Toast, useToast } from "@/components/ui/toast";
import { authorLabel, type HomeFeedRow } from "@/lib/feed";
import {
  loadHomeViewerState,
  predictFollowState,
  toggleAuthorFollow,
  toggleDropLike,
  toggleDropRedrop,
  toggleDropSave,
  type HomeViewerState,
} from "@/lib/home-actions";
import { fetchHomeSurfaceRows } from "@/lib/home-feed-sources";
import {
  fetchClubHomePosts,
  fetchHomeIdentity,
  fetchHomeNotificationBadge,
  toggleClubPostLike,
  type ClubHomePost,
  type HomeIdentity,
} from "@/lib/home-parity-data";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

// These are heavy, interaction-only overlays (composer with image/poll
// upload, quote-redrop composer, side drawer) — none of them are needed for
// the first paint of the feed, so they're split out of the initial bundle
// and only fetched once the user actually opens one.
const Beta4Composer = dynamic(() => import("@/components/beta4-composer").then((mod) => mod.Beta4Composer));
const QuoteRedropComposer = dynamic(() => import("@/components/quote-redrop-composer").then((mod) => mod.QuoteRedropComposer));
const HomeDrawer = dynamic(() => import("@/components/home/home-drawer").then((mod) => mod.HomeDrawer));

type ReportCategory =
  | "spam"
  | "scam"
  | "harassment"
  | "hate"
  | "sexual_content"
  | "violence"
  | "privacy"
  | "illegal_content"
  | "copyright"
  | "other";
type HiddenDrop = { row: HomeFeedRow; index: number };
type HomeDropFeedSnapshot = {
  kind: "drops";
  rows: HomeFeedRow[];
  viewer: HomeViewerState;
  images: Map<string, string[]>;
};
type HomeClubFeedSnapshot = {
  kind: "clubs";
  clubRows: ClubHomePost[];
};
type HomeFeedSnapshot = HomeDropFeedSnapshot | HomeClubFeedSnapshot;

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

function modeIndex(mode: HomeFeedMode) {
  return HOME_FEED_MODES.findIndex((item) => item.key === mode);
}

// Infinite scroll renders the feed in windows of this size instead of
// mounting every fetched row at once, so an initial paint only pays for the
// posts actually on screen; the sentinel below grows the window as the user
// scrolls near the bottom.
const FEED_PAGE_SIZE = 15;

async function fetchDropImages(
  client: SupabaseClient,
  rows: HomeFeedRow[],
): Promise<Map<string, string[]>> {
  const map = new Map<string, string[]>();
  for (const row of rows) {
    if (row.image_url) map.set(row.id, [row.image_url]);
  }
  const ids = rows.filter((row) => (row.image_count ?? 0) > 1).map((row) => row.id);
  if (!ids.length) return map;

  const result = await client
    .from("drop_images")
    .select("drop_id,image_url,position")
    .in("drop_id", ids)
    .order("position", { ascending: true });
  if (result.error) return map;

  for (const raw of result.data ?? []) {
    const id = String(raw.drop_id);
    const url = String(raw.image_url ?? "");
    if (!url) continue;
    const list = map.get(id) ?? [];
    if (!list.includes(url)) list.push(url);
    map.set(id, list);
  }
  return map;
}

function ActionSheet({
  children,
  onClose,
  label,
}: {
  children: React.ReactNode;
  onClose: () => void;
  label: string;
}) {
  return (
    <div className="route-modal-backdrop audit-sheet-backdrop" role="presentation" onClick={onClose}>
      <section
        className="audit-action-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={label}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="audit-sheet-grip" />
        {children}
      </section>
    </div>
  );
}

export function HomeScreen({ session }: { session: Session }) {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const router = useRouter();
  const searchParams = useSearchParams();
  const userId = session.user.id;
  const { toastMessage, showToast } = useToast();

  const [mode, setMode] = useState<HomeFeedMode>("for-you");
  const [visibleMode, setVisibleMode] = useState<HomeFeedMode>("for-you");
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [visibleCount, setVisibleCount] = useState(FEED_PAGE_SIZE);
  const [clubRows, setClubRows] = useState<ClubHomePost[]>([]);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [images, setImages] = useState<Map<string, string[]>>(new Map());
  const [identity, setIdentity] = useState<HomeIdentity | null>(null);
  const [notificationBadge, setNotificationBadge] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [selected, setSelected] = useState<HomeFeedRow | null>(null);
  const [sheet, setSheet] = useState<"more" | "redrop" | "quote" | "report" | null>(null);
  const [quote, setQuote] = useState("");
  const [reportCategory, setReportCategory] = useState<ReportCategory>("spam");
  const [reportDetail, setReportDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [hidden, setHidden] = useState<HiddenDrop | null>(null);
  const [composerOpen, setComposerOpen] = useState(() => searchParams.get("compose") === "1");
  const [pullDistance, setPullDistance] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const touchGesture = useRef<{ x: number; y: number; canPull: boolean } | null>(null);
  const activeModeRef = useRef<HomeFeedMode>("for-you");
  const visibleModeRef = useRef<HomeFeedMode>("for-you");
  const feedCache = useRef<Partial<Record<HomeFeedMode, HomeFeedSnapshot>>>({});
  const inFlightLoads = useRef<Partial<Record<HomeFeedMode, Promise<HomeFeedSnapshot>>>>({});
  const scrollPositions = useRef<Record<HomeFeedMode, number>>({
    "for-you": 0,
    following: 0,
    clubs: 0,
  });
  const visibleCounts = useRef<Record<HomeFeedMode, number>>({
    "for-you": FEED_PAGE_SIZE,
    following: FEED_PAGE_SIZE,
    clubs: FEED_PAGE_SIZE,
  });

  useEffect(() => {
    return () => {
      scrollPositions.current[visibleModeRef.current] = window.scrollY;
    };
  }, []);

  useEffect(() => {
    if (!client) return;
    void Promise.all([fetchHomeIdentity(client, userId), fetchHomeNotificationBadge(client, userId)])
      .then(([nextIdentity, badge]) => {
        setIdentity(nextIdentity);
        setNotificationBadge(badge);
      })
      .catch(() => undefined);
  }, [client, userId]);

  const restoreScroll = useCallback((targetMode: HomeFeedMode) => {
    const top = scrollPositions.current[targetMode] ?? 0;
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        const maxTop = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
        window.scrollTo({ top: Math.min(top, maxTop), behavior: "auto" });
      });
    });
  }, []);

  const applySnapshot = useCallback((snapshot: HomeFeedSnapshot, targetMode: HomeFeedMode, restore = false) => {
    visibleModeRef.current = targetMode;
    setVisibleMode(targetMode);
    if (snapshot.kind === "clubs") {
      setClubRows(snapshot.clubRows);
      setRows([]);
      setViewer(null);
      setImages(new Map());
    } else {
      setRows(snapshot.rows);
      setViewer(snapshot.viewer);
      setImages(snapshot.images);
      setClubRows([]);
    }
    // Restoring a cached tab keeps whatever window the user had already
    // scrolled to open; a fresh load or pull-to-refresh starts over at one page.
    if (!restore) visibleCounts.current[targetMode] = FEED_PAGE_SIZE;
    setVisibleCount(visibleCounts.current[targetMode]);
    if (restore) restoreScroll(targetMode);
  }, [restoreScroll]);

  const fetchModeSnapshot = useCallback(async (targetMode: HomeFeedMode): Promise<HomeFeedSnapshot> => {
    if (!client) throw new Error("Supabase client unavailable");
    const running = inFlightLoads.current[targetMode];
    if (running) return running;

    const promise = (async () => {
      if (targetMode === "clubs") {
        return {
          kind: "clubs" as const,
          clubRows: await fetchClubHomePosts(client, userId),
        };
      }

      const nextRows = await fetchHomeSurfaceRows(client, userId, {
        kind: targetMode === "following" ? "following" : "ranked",
      });
      const [state, media] = await Promise.all([
        loadHomeViewerState(client, userId, nextRows),
        fetchDropImages(client, nextRows),
      ]);
      return {
        kind: "drops" as const,
        rows: nextRows,
        viewer: state,
        images: media,
      };
    })();

    inFlightLoads.current[targetMode] = promise;
    try {
      return await promise;
    } finally {
      if (inFlightLoads.current[targetMode] === promise) delete inFlightLoads.current[targetMode];
    }
  }, [client, userId]);

  const loadMode = useCallback(async (
    targetMode: HomeFeedMode,
    options: { showLoading?: boolean; apply?: boolean } = {},
  ) => {
    const cached = feedCache.current[targetMode];
    const shouldApply = options.apply !== false;
    if (shouldApply && activeModeRef.current === targetMode && options.showLoading && !cached) {
      setLoading(true);
    }
    if (shouldApply && activeModeRef.current === targetMode) setError("");

    try {
      const snapshot = await fetchModeSnapshot(targetMode);
      feedCache.current[targetMode] = snapshot;
      if (shouldApply && activeModeRef.current === targetMode) {
        const shouldRestore = visibleModeRef.current !== targetMode;
        applySnapshot(snapshot, targetMode, shouldRestore);
        setLoading(false);
      }
    } catch (e) {
      if (shouldApply && activeModeRef.current === targetMode) {
        if (!cached && visibleModeRef.current !== targetMode) {
          activeModeRef.current = visibleModeRef.current;
          setMode(visibleModeRef.current);
          restoreScroll(visibleModeRef.current);
        }
        setError(e instanceof Error ? e.message : "โหลดฟีดไม่สำเร็จ");
        setLoading(false);
      }
    }
  }, [applySnapshot, fetchModeSnapshot, restoreScroll]);

  const load = useCallback(async () => {
    await loadMode(visibleModeRef.current, { showLoading: false });
  }, [loadMode]);

  const refreshVisibleMode = useCallback(async () => {
    if (refreshing) return;
    const targetMode = visibleModeRef.current;
    setRefreshing(true);
    setPullDistance(0);
    setError("");
    try {
      const snapshot = await fetchModeSnapshot(targetMode);
      feedCache.current[targetMode] = snapshot;
      if (visibleModeRef.current === targetMode && activeModeRef.current === targetMode) {
        applySnapshot(snapshot, targetMode, false);
        scrollPositions.current[targetMode] = 0;
      }
    } catch (e) {
      if (visibleModeRef.current === targetMode) {
        setError(e instanceof Error ? e.message : "รีเฟรชฟีดไม่สำเร็จ");
      }
    } finally {
      setRefreshing(false);
    }
  }, [applySnapshot, fetchModeSnapshot, refreshing]);

  useEffect(() => {
    const cached = feedCache.current[mode];
    if (cached && visibleModeRef.current !== mode) {
      applySnapshot(cached, mode, true);
      setLoading(false);
    }
    const timer = window.setTimeout(() => {
      void loadMode(mode, { showLoading: !cached });
    }, 0);
    return () => window.clearTimeout(timer);
  }, [applySnapshot, loadMode, mode]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      for (const item of HOME_FEED_MODES) {
        if (item.key === "for-you" || feedCache.current[item.key]) continue;
        void loadMode(item.key, { showLoading: false, apply: false });
      }
    }, 250);
    return () => window.clearTimeout(timer);
  }, [loadMode]);

  useEffect(() => {
    if (visibleMode === "clubs") {
      feedCache.current.clubs = { kind: "clubs", clubRows };
      return;
    }
    if (viewer) {
      feedCache.current[visibleMode] = { kind: "drops", rows, viewer, images };
    }
  }, [clubRows, images, rows, viewer, visibleMode]);

  const patchSet = (
    key: "likedDropIds" | "savedDropIds" | "redroppedDropIds",
    id: string,
    enabled: boolean,
  ) => setViewer((current) => {
    if (!current) return current;
    const next = new Set(current[key]);
    if (enabled) next.add(id);
    else next.delete(id);
    return { ...current, [key]: next };
  });

  const like = async (row: HomeFeedRow) => {
    if (!client || !viewer) return;
    const liked = viewer.likedDropIds.has(row.id);
    patchSet("likedDropIds", row.id, !liked);
    setRows((current) => current.map((item) =>
      item.id === row.id
        ? { ...item, like_count: Math.max(0, (item.like_count ?? 0) + (liked ? -1 : 1)) }
        : item,
    ));
    try {
      await toggleDropLike(client, userId, row.id, liked);
    } catch {
      void load();
      showToast("ถูกใจไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  };

  const likeClub = async (post: ClubHomePost) => {
    if (!client) return;
    setClubRows((current) => current.map((item) =>
      item.id === post.id
        ? {
            ...item,
            liked_by_me: !post.liked_by_me,
            like_count: Math.max(0, item.like_count + (post.liked_by_me ? -1 : 1)),
          }
        : item,
    ));
    try {
      await toggleClubPostLike(client, userId, post.id, post.liked_by_me);
    } catch {
      void load();
      showToast("ถูกใจไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  };

  const save = async (row: HomeFeedRow) => {
    if (!client || !viewer) return;
    const saved = viewer.savedDropIds.has(row.id);
    patchSet("savedDropIds", row.id, !saved);
    try {
      await toggleDropSave(client, userId, row.id, saved);
    } catch {
      void load();
      showToast("บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  };

  const applyFollowState = (authorId: string, state: "following" | "requested" | "none") => setViewer((current) => {
    if (!current) return current;
    const followedAuthorIds = new Set(current.followedAuthorIds);
    const pendingFollowAuthorIds = new Set(current.pendingFollowAuthorIds);
    followedAuthorIds.delete(authorId);
    pendingFollowAuthorIds.delete(authorId);
    if (state === "following") followedAuthorIds.add(authorId);
    if (state === "requested") pendingFollowAuthorIds.add(authorId);
    return { ...current, followedAuthorIds, pendingFollowAuthorIds };
  });

  const followAuthor = async (row: HomeFeedRow) => {
    if (!client || !viewer || row.author_id === userId) return;
    const currentlyFollowing = viewer.followedAuthorIds.has(row.author_id);
    const pendingRequest = viewer.pendingFollowAuthorIds.has(row.author_id);
    const isPrivate = viewer.privateAuthorIds.has(row.author_id);
    const optimisticNext = predictFollowState({ currentlyFollowing, pendingRequest, isPrivate });
    applyFollowState(row.author_id, optimisticNext);
    try {
      await toggleAuthorFollow(client, userId, row.author_id, {
        currentlyFollowing,
        pendingRequest,
        isPrivate,
      });
    } catch {
      applyFollowState(row.author_id, currentlyFollowing ? "following" : pendingRequest ? "requested" : "none");
      showToast("ติดตามไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  };

  const redrop = async (row: HomeFeedRow) => {
    if (!client || !viewer) return;
    const active = viewer.redroppedDropIds.has(row.id);
    patchSet("redroppedDropIds", row.id, !active);
    setRows((current) => current.map((item) =>
      item.id === row.id
        ? { ...item, redrop_count: Math.max(0, (item.redrop_count ?? 0) + (active ? -1 : 1)) }
        : item,
    ));
    try {
      await toggleDropRedrop(client, userId, row.id, active);
      setSheet(null);
      setSelected(null);
    } catch {
      void load();
      showToast("รีโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  };

  // Legacy product contract name: Quote ReDrop.
  const quoteRedrop = async () => {
    if (!client || !selected || !quote.trim() || busy) return;
    setBusy(true);
    setError("");
    try {
      const result = await client.from("redrops").insert({
        drop_id: selected.id,
        redropper_id: userId,
        quote_text: quote.trim(),
      });
      if (result.error) throw result.error;
      setQuote("");
      setSheet(null);
      setSelected(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "รีโพสต์พร้อมความคิดเห็นไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  const share = async (row: HomeFeedRow) => {
    const url = `${window.location.origin}/drop/${row.id}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: authorLabel(row), text: row.caption || "WYNOS", url });
      } else {
        await navigator.clipboard.writeText(url);
      }
    } catch {
      // Native share cancellation is not an application error.
    }
  };

  const hide = async (row: HomeFeedRow) => {
    if (!client) return;
    const index = rows.findIndex((item) => item.id === row.id && item.redrop_id === row.redrop_id);
    setRows((current) => current.filter((item) => !(item.id === row.id && item.redrop_id === row.redrop_id)));
    setHidden({ row, index: Math.max(0, index) });
    setSheet(null);
    setSelected(null);
    const result = await client.from("feed_signals").insert({
      user_id: userId,
      signal_type: "hide",
      target_type: "drop",
      target_id: row.id,
    });
    if (result.error) {
      setHidden(null);
      void load();
    }
  };

  const undoHide = async () => {
    if (!client || !hidden) return;
    const value = hidden;
    setHidden(null);
    setRows((current) => {
      const next = [...current];
      next.splice(Math.min(value.index, next.length), 0, value.row);
      return next;
    });
    const result = await client
      .from("feed_signals")
      .delete()
      .eq("user_id", userId)
      .eq("signal_type", "hide")
      .eq("target_type", "drop")
      .eq("target_id", value.row.id);
    if (result.error) void load();
  };

  const report = async () => {
    if (!client || !selected || busy) return;
    if (reportCategory === "other" && !reportDetail.trim()) {
      setError("กรุณาระบุรายละเอียด");
      return;
    }
    setBusy(true);
    setError("");
    const result = await client.rpc("submit_report", {
      p_target_type: "drop",
      p_target_id: selected.id,
      p_category: reportCategory,
      p_detail: reportCategory === "other" ? reportDetail.trim() : null,
    });
    if (result.error) {
      setError(result.error.message || "ส่งรายงานไม่สำเร็จ");
    } else {
      setSheet(null);
      setSelected(null);
      setReportDetail("");
    }
    setBusy(false);
  };

  const switchMode = (next: HomeFeedMode) => {
    if (next === mode) return;
    scrollPositions.current[visibleModeRef.current] = window.scrollY;
    activeModeRef.current = next;
    setMode(next);

    const cached = feedCache.current[next];
    if (cached) {
      applySnapshot(cached, next, true);
      setLoading(false);
    } else {
      // Keep the previous feed painted while the new tab is fetched. This avoids
      // the full white loading flash seen on mobile when switching tabs.
      setLoading(true);
    }
  };
  const onTouchStart = (event: TouchEvent<HTMLDivElement>) => {
    const touch = event.changedTouches[0];
    if (!touch) return;
    touchGesture.current = {
      x: touch.clientX,
      y: touch.clientY,
      canPull: window.scrollY <= 2 && !refreshing && mode === visibleModeRef.current,
    };
  };
  const onTouchMove = (event: TouchEvent<HTMLDivElement>) => {
    const start = touchGesture.current;
    const touch = event.changedTouches[0];
    if (!start || !touch || !start.canPull || refreshing) return;
    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    if (deltaY <= 0 || Math.abs(deltaY) <= Math.abs(deltaX) * 1.1) {
      if (pullDistance) setPullDistance(0);
      return;
    }
    // Dampen the gesture so the refresh affordance feels native rather than
    // moving one-for-one with the finger. The feed itself stays stable.
    setPullDistance(Math.min(88, deltaY * 0.48));
  };
  const onTouchEnd = (event: TouchEvent<HTMLDivElement>) => {
    const start = touchGesture.current;
    const touch = event.changedTouches[0];
    touchGesture.current = null;
    if (!start || !touch) {
      setPullDistance(0);
      return;
    }

    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    const releasedPullDistance = Math.min(88, Math.max(0, deltaY) * 0.48);
    const shouldRefresh = start.canPull && releasedPullDistance >= 54 && deltaY > Math.abs(deltaX);
    if (shouldRefresh) {
      void refreshVisibleMode();
      return;
    }
    setPullDistance(0);

    if (Math.abs(deltaY) >= Math.abs(deltaX) || Math.abs(deltaX) < 55) return;
    const index = modeIndex(mode);
    const next = deltaX < 0
      ? Math.min(HOME_FEED_MODES.length - 1, index + 1)
      : Math.max(0, index - 1);
    switchMode(HOME_FEED_MODES[next].key);
  };
  const onTouchCancel = () => {
    touchGesture.current = null;
    setPullDistance(0);
  };

  const visibleRows = rows.slice(0, visibleCount);
  const hasMoreRows = visibleCount < rows.length;
  const { ref: loadMoreRef } = useInView({
    skip: !hasMoreRows,
    rootMargin: "600px 0px",
    onChange: (inView) => {
      if (!inView) return;
      setVisibleCount((current) => {
        const next = Math.min(rows.length, current + FEED_PAGE_SIZE);
        visibleCounts.current[visibleModeRef.current] = next;
        return next;
      });
    },
  });

  if (!client) {
    return <main className="wyn-home-state"><p>ยังไม่ได้ตั้งค่า Supabase สำหรับเว็บ</p></main>;
  }

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav>
      <div className="wyn-home">
        <HomeHeader
          notificationBadgeCount={notificationBadge}
          onOpenMenu={() => setDrawerOpen(true)}
          onOpenSearch={() => router.push("/search")}
          onOpenNotifications={() => router.push("/notifications")}
        />
        <HomeTabs mode={mode} onSelect={switchMode} />
      </div>

      {pullDistance > 0 || refreshing ? (
        <div
          aria-label={refreshing ? "กำลังรีเฟรชฟีด" : "ลากลงเพื่อรีเฟรช"}
          aria-live="polite"
          style={{ height: 0, position: "relative", zIndex: 6, pointerEvents: "none" }}
        >
          <div
            className="route-system-spinner tiny"
            style={{
              position: "absolute",
              top: refreshing ? 10 : Math.max(4, Math.min(18, pullDistance * 0.2)),
              left: "50%",
              opacity: refreshing ? 1 : Math.max(0.22, Math.min(1, pullDistance / 54)),
              transform: `translateX(-50%) scale(${refreshing ? 1 : Math.max(0.78, Math.min(1, pullDistance / 54))})`,
              transition: refreshing ? "top 140ms ease, opacity 140ms ease, transform 140ms ease" : "none",
            }}
          />
        </div>
      ) : loading && mode !== visibleMode ? (
        <div
          aria-label="กำลังโหลดฟีด"
          aria-live="polite"
          style={{ height: 0, position: "relative", zIndex: 5 }}
        >
          <div
            className="route-system-spinner tiny"
            style={{ position: "absolute", top: 8, left: "50%", transform: "translateX(-50%)" }}
          />
        </div>
      ) : null}

      <div
        className="wyn-home-feed"
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onTouchCancel={onTouchCancel}
      >
        {loading && !rows.length && !clubRows.length ? (
          <FeedSkeleton />
        ) : error && !rows.length && !clubRows.length ? (
          <div className="wyn-home-state">
            <p>{error}</p>
            <button className="route-secondary" type="button" onClick={() => void load()}>ลองใหม่</button>
          </div>
        ) : visibleMode === "clubs" ? (
          clubRows.length ? (
            clubRows.map((post) => (
              <ClubFeedPost post={post} onLike={() => void likeClub(post)} key={post.id} />
            ))
          ) : (
            <div className="wyn-home-state">
              <p>ยังไม่มีโพสต์จาก Club ของคุณ</p>
              <Link className="route-primary" href="/clubs">สำรวจ Club</Link>
            </div>
          )
        ) : rows.length && viewer ? (
          <>
            {visibleRows.map((row, index) => (
              <HomePostCard
                row={row}
                viewer={viewer}
                images={images.get(row.id) ?? (row.image_url ? [row.image_url] : [])}
                userId={userId}
                onLike={() => void like(row)}
                onMore={() => {
                  setSelected(row);
                  setSheet("more");
                }}
                onRedrop={() => {
                  setSelected(row);
                  setSheet("redrop");
                }}
                onFollow={() => void followAuthor(row)}
                onShare={() => void share(row)}
                priority={index < 2}
                key={`${row.id}:${row.redrop_id ?? "plain"}`}
              />
            ))}
            {hasMoreRows ? <div ref={loadMoreRef} style={{ height: 1 }} aria-hidden="true" /> : null}
          </>
        ) : (
          <div className="wyn-home-state">
            <p>{visibleMode === "following" ? "ยังไม่มีโพสต์จากคนที่คุณกำลังติดตาม" : "ยังไม่มีอะไรให้ดูตรงนี้"}</p>
            <Link className="route-primary" href="/search">ค้นหาคนและเนื้อหา</Link>
          </div>
        )}
      </div>

      {drawerOpen ? <HomeDrawer identity={identity} onClose={() => setDrawerOpen(false)} /> : null}

      {selected && sheet === "more" ? (
        <ActionSheet label="ตัวเลือกโพสต์" onClose={() => { setSheet(null); setSelected(null); }}>
          <button className="audit-sheet-row" type="button" onClick={() => { void share(selected); setSheet(null); }}>
            <Share2 size={20} />แชร์
          </button>
          <button className="audit-sheet-row" type="button" onClick={() => { void save(selected); setSheet(null); }}>
            <Bookmark size={20} fill={viewer?.savedDropIds.has(selected.id) ? "currentColor" : "none"} />
            {viewer?.savedDropIds.has(selected.id) ? "เอาออกจากบันทึก" : "บันทึก"}
          </button>
          {selected.author_id !== userId ? (
            <button className="audit-sheet-row" type="button" onClick={() => void hide(selected)}>
              <X size={20} />ไม่สนใจโพสต์นี้
            </button>
          ) : null}
          {selected.author_id !== userId ? (
            <button className="audit-sheet-row" type="button" onClick={() => setSheet("report")}>
              <Flag size={20} />รายงานโพสต์
            </button>
          ) : null}
          {selected.redrop_id && selected.redropper_username === identity?.username ? (
            <button
              className="audit-sheet-row"
              type="button"
              onClick={async () => {
                const result = await client
                  .from("redrops")
                  .delete()
                  .eq("id", selected.redrop_id)
                  .eq("redropper_id", userId);
                if (!result.error) {
                  setSheet(null);
                  setSelected(null);
                  void load();
                }
              }}
            >
              <Repeat2 size={20} />ลบรีโพสต์
            </button>
          ) : null}
        </ActionSheet>
      ) : null}

      {selected && sheet === "redrop" ? (
        <ActionSheet label="รีโพสต์" onClose={() => { setSheet(null); setSelected(null); }}>
          <div className="wyn-redrop-sheet-options">
            <button className="wyn-redrop-sheet-option is-primary" type="button" onClick={() => void redrop(selected)}>
              <span className="wyn-redrop-sheet-icon" aria-hidden="true"><Repeat2 size={28} /></span>
              <span className="wyn-redrop-sheet-copy">
                <strong>{viewer?.redroppedDropIds.has(selected.id) ? "ยกเลิกรีโพสต์" : "รีโพสต์"}</strong>
                <small>
                  {viewer?.redroppedDropIds.has(selected.id)
                    ? "นำโพสต์นี้ออกจากโปรไฟล์ของคุณ"
                    : "แชร์โพสต์นี้ไปยังโปรไฟล์ของคุณ"}
                </small>
              </span>
              <ChevronRight className="wyn-redrop-sheet-chevron" size={22} aria-hidden="true" />
            </button>
            <button className="wyn-redrop-sheet-option is-quote" type="button" onClick={() => setSheet("quote")}>
              <span className="wyn-redrop-sheet-icon" aria-hidden="true"><Quote size={28} /></span>
              <span className="wyn-redrop-sheet-copy">
                <strong>รีโพสต์พร้อมความคิดเห็น</strong>
                <small>แชร์โพสต์นี้พร้อมเพิ่มความคิดเห็นของคุณ</small>
              </span>
              <ChevronRight className="wyn-redrop-sheet-chevron" size={22} aria-hidden="true" />
            </button>
            <button
              className="wyn-redrop-sheet-cancel"
              type="button"
              onClick={() => { setSheet(null); setSelected(null); }}
            >
              ยกเลิก
            </button>
          </div>
        </ActionSheet>
      ) : null}

      {selected && sheet === "quote" ? (
        <QuoteRedropComposer
          row={selected}
          value={quote}
          busy={busy}
          error={error}
          onChange={setQuote}
          onClose={() => { setSheet(null); setSelected(null); setQuote(""); setError(""); }}
          onSubmit={() => void quoteRedrop()}
        />
      ) : null}

      {selected && sheet === "report" ? (
        <ActionSheet label="รายงานโพสต์" onClose={() => { setSheet(null); setSelected(null); setReportDetail(""); }}>
          <div className="audit-sheet-form">
            <strong>รายงานโพสต์</strong>
            <div className="audit-report-list">
              {reportCategories.map((item) => (
                <label key={item.value}>
                  <input
                    type="radio"
                    name="report-category"
                    checked={reportCategory === item.value}
                    onChange={() => setReportCategory(item.value)}
                  />
                  {item.label}
                </label>
              ))}
            </div>
            {reportCategory === "other" ? (
              <textarea
                maxLength={1000}
                value={reportDetail}
                onChange={(event) => setReportDetail(event.target.value)}
                placeholder="รายละเอียดเพิ่มเติม"
              />
            ) : null}
            {error ? <p className="route-error">{error}</p> : null}
            <button className="route-primary" type="button" disabled={busy} onClick={() => void report()}>
              ส่งรายงาน
            </button>
          </div>
        </ActionSheet>
      ) : null}

      {hidden ? (
        <div className="audit-undo-toast">
          <span>ไม่สนใจโพสต์นี้แล้ว</span>
          <button type="button" onClick={() => void undoHide()}>เลิกทำ</button>
        </div>
      ) : null}
      <Toast message={toastMessage} />

      {composerOpen ? (
        <Beta4Composer
          client={client}
          userId={userId}
          onClose={() => {
            setComposerOpen(false);
            if (searchParams.get("compose") === "1") router.replace("/");
          }}
          onPublished={() => void load()}
        />
      ) : null}
    </AppChrome>
  );
}
