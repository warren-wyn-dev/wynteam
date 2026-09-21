"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { AnimatePresence, motion } from "framer-motion";
import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type TouchEvent } from "react";
import { useInView } from "react-intersection-observer";

import { ClubFeedPost } from "@/components/home/club-feed-post";
import { HomeHeader } from "@/components/home/home-header";
import { HomePostCard } from "@/components/home/home-post-card";
import { HOME_FEED_MODES, HomeTabs, type HomeFeedMode } from "@/components/home/home-tabs";
import { AppChrome } from "@/components/phase3-ui";
import { useRouteRefreshListener } from "@/components/route-refresh-runtime";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { FeedSkeleton } from "@/components/ui/skeleton";
import { Toast, useToast } from "@/components/ui/toast";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { authorLabel, type HomeFeedRow } from "@/lib/feed";
import { haptic } from "@/lib/haptics";
import { shareOrCopyLink } from "@/lib/share";
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
  toggleClubPostLike,
  type ClubHomePost,
  type HomeIdentity,
} from "@/lib/home-parity-data";
import { useUnreadNotificationCount } from "@/lib/notification-count";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";

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

type HomeScreenStore = {
  feedCache: Partial<Record<HomeFeedMode, HomeFeedSnapshot>>;
  scrollPositions: Record<HomeFeedMode, number>;
  visibleCounts: Record<HomeFeedMode, number>;
  mode: HomeFeedMode;
  visibleMode: HomeFeedMode;
  identity: HomeIdentity | null;
};

// Kept at module scope (outside the component) so it survives HomeScreen
// unmounting — the root PageTransition fully unmounts/remounts every page on
// route change, so a plain useRef would lose the feed the instant the user
// tapped away to another tab. Without this, navigating Home -> anything ->
// back to Home re-showed FeedSkeleton and refetched from scratch every time,
// which read as the whole app "reloading" on every navigation.
const homeScreenStores = new Map<string, HomeScreenStore>();

function getHomeScreenStore(userId: string): HomeScreenStore {
  let store = homeScreenStores.get(userId);
  if (!store) {
    store = {
      feedCache: {},
      scrollPositions: { "for-you": 0, following: 0, clubs: 0 },
      visibleCounts: { "for-you": FEED_PAGE_SIZE, following: FEED_PAGE_SIZE, clubs: FEED_PAGE_SIZE },
      mode: "for-you",
      visibleMode: "for-you",
      identity: null,
    };
    homeScreenStores.set(userId, store);
  }
  return store;
}

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
    <motion.div
      className="route-modal-backdrop audit-sheet-backdrop"
      role="presentation"
      onClick={onClose}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.18 }}
    >
      <motion.section
        className="audit-action-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={label}
        onClick={(event) => event.stopPropagation()}
        initial={{ y: "100%" }}
        animate={{ y: 0 }}
        exit={{ y: "100%" }}
        transition={{ duration: 0.22, ease: "easeOut" }}
      >
        <div className="audit-sheet-grip" />
        {children}
      </motion.section>
    </motion.div>
  );
}

export function HomeScreen({ session }: { session: Session }) {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const router = useRouter();
  const searchParams = useSearchParams();
  const userId = session.user.id;
  const { toastMessage, showToast } = useToast();

  // Deliberately not wrapped in useMemo/useRef: `store`'s fields (mode,
  // visibleMode) are mutated directly outside of render, which the stricter
  // React Compiler lint forbids for a useMemo result, and reading a ref's
  // `.current` during render (needed below, for the useState initializers)
  // is equally forbidden. A plain module-level lookup keyed by userId sits
  // outside both rules while still returning the same object reference on
  // every render.
  const store = getHomeScreenStore(userId);
  const initialSnapshot = store.feedCache[store.visibleMode];

  const [mode, setMode] = useState<HomeFeedMode>(store.mode);
  const [visibleMode, setVisibleMode] = useState<HomeFeedMode>(store.visibleMode);
  const [rows, setRows] = useState<HomeFeedRow[]>(() => (initialSnapshot?.kind === "drops" ? initialSnapshot.rows : []));
  const [visibleCount, setVisibleCount] = useState(store.visibleCounts[store.visibleMode]);
  const [clubRows, setClubRows] = useState<ClubHomePost[]>(() => (initialSnapshot?.kind === "clubs" ? initialSnapshot.clubRows : []));
  const [viewer, setViewer] = useState<HomeViewerState | null>(() => (initialSnapshot?.kind === "drops" ? initialSnapshot.viewer : null));
  const [images, setImages] = useState<Map<string, string[]>>(() => (initialSnapshot?.kind === "drops" ? initialSnapshot.images : new Map()));
  const [identity, setIdentity] = useState<HomeIdentity | null>(store.identity);
  const [loading, setLoading] = useState(!initialSnapshot);
  const [error, setError] = useState("");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [selected, setSelected] = useState<HomeFeedRow | null>(null);
  const [sheet, setSheet] = useState<"more" | "redrop" | "quote" | "report" | null>(null);
  const [quote, setQuote] = useState("");
  const [reportCategory, setReportCategory] = useState<ReportCategory>("spam");
  const [reportDetail, setReportDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [hidden, setHidden] = useState<HiddenDrop | null>(null);
  // Derived directly from the URL rather than mirrored into its own
  // useState: tapping the bottom nav's "โพสต์" button while already on "/"
  // is a same-route navigation (only the ?compose=1 param changes), so this
  // component stays mounted rather than remounting. A useState initializer
  // only runs once at the original mount, so it silently never opened on
  // that path — only mattered from a live account already on Home, so it
  // went unreported until now. Navigating here fresh from another route
  // happened to work, since that mount read the param directly.
  const composerOpen = searchParams.get("compose") === "1";
  // Horizontal tab-swipe's own gesture tracking — separate, unrelated concern
  // from the pull-to-refresh gesture below (see usePullToRefresh, WYN-182).
  const swipeStart = useRef<{ x: number; y: number } | null>(null);
  const slideDirectionRef = useRef<1 | -1>(1);
  const skipSlideAnimationRef = useRef(true);
  const [slideStyle, setSlideStyle] = useState<{ transform: string; opacity: number; transition: string }>({
    transform: "translateX(0)",
    opacity: 1,
    transition: "none",
  });
  const activeModeRef = useRef<HomeFeedMode>(store.mode);
  const visibleModeRef = useRef<HomeFeedMode>(store.visibleMode);
  const feedCache = useRef(store.feedCache);
  const inFlightLoads = useRef<Partial<Record<HomeFeedMode, Promise<HomeFeedSnapshot>>>>({});
  const scrollPositions = useRef(store.scrollPositions);
  const visibleCounts = useRef(store.visibleCounts);

  useEffect(() => {
    return () => {
      scrollPositions.current[visibleModeRef.current] = window.scrollY;
    };
  }, []);

  useEffect(() => {
    if (!client) return;
    void fetchHomeIdentity(client, userId)
      .then((nextIdentity) => {
        setIdentity(nextIdentity);
        getHomeScreenStore(userId).identity = nextIdentity;
      })
      .catch(() => undefined);
  }, [client, userId]);

  // Shares its cache with AppChrome's own root-nav badge (lib/notification-count.ts)
  // so opening /notifications clears both instantly instead of each polling separately.
  const notificationBadge = useUnreadNotificationCount(client, userId, true);

  // Plays a directional slide the moment the visible tab's content actually
  // lands (tap or swipe both funnel through switchMode, which records the
  // direction) — a plain content swap read as an abrupt cut, not the
  // sliding-tab feel every large social app uses. Runs as a layout effect so
  // the "shifted, faded" start frame paints before the browser's next
  // repaint, instead of flashing the settled position first.
  useLayoutEffect(() => {
    if (skipSlideAnimationRef.current) {
      skipSlideAnimationRef.current = false;
      return;
    }
    const direction = slideDirectionRef.current;
    setSlideStyle({ transform: `translateX(${direction * 28}px)`, opacity: 0.4, transition: "none" });
    const raf = window.requestAnimationFrame(() => {
      setSlideStyle({
        transform: "translateX(0px)",
        opacity: 1,
        transition: "transform 220ms cubic-bezier(0.22, 1, 0.36, 1), opacity 220ms ease-out",
      });
    });
    return () => window.cancelAnimationFrame(raf);
  }, [visibleMode]);

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
    getHomeScreenStore(userId).visibleMode = targetMode;
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
  }, [restoreScroll, userId]);

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
          getHomeScreenStore(userId).mode = visibleModeRef.current;
          setMode(visibleModeRef.current);
          restoreScroll(visibleModeRef.current);
          // Reverting keeps the previously-loaded tab's rows on screen, so
          // this failure never reaches the empty-state error branch below —
          // without a toast, a tap or swipe to a tab whose fetch throws just
          // silently snaps back with zero feedback, reading as "switching
          // doesn't work" rather than "that tab failed to load".
          showToast("สลับแท็บไม่สำเร็จ ลองใหม่อีกครั้ง");
        }
        setError(e instanceof Error ? e.message : "โหลดฟีดไม่สำเร็จ");
        setLoading(false);
      }
    }
  }, [applySnapshot, fetchModeSnapshot, restoreScroll, showToast, userId]);

  const load = useCallback(async () => {
    await loadMode(visibleModeRef.current, { showLoading: false });
  }, [loadMode]);

  // The de-duplication (only one refresh in flight) and refreshing/
  // pullDistance state this used to own directly now live in
  // usePullToRefresh below — both this function's callers (the pull
  // gesture and the bottom-nav "tap active tab" refresh) go through the
  // hook's `refresh()`/touch handlers, so this only needs to describe what
  // a refresh actually does.
  const refreshVisibleMode = useCallback(async () => {
    const targetMode = visibleModeRef.current;
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
    }
  }, [applySnapshot, fetchModeSnapshot]);

  // Home's own pull-to-refresh — already shipped/GA, not staged-rollout
  // gated. `enabled` mirrors the original inline canPull check exactly:
  // only pull while looking at the tab whose data this would refresh. A
  // getter (not a plain boolean) because visibleModeRef is a ref — reading
  // it during render is disallowed, so resolution happens lazily inside
  // the hook's onTouchStart instead, same as the original inline check did.
  const pull = usePullToRefresh({ enabled: () => mode === visibleModeRef.current, onRefresh: refreshVisibleMode });

  useRouteRefreshListener(pull.refresh);

  useEffect(() => {
    const cached = feedCache.current[mode];
    if (cached) {
      // Already have this tab's data (a prior visit this session) — show it
      // as-is. Fetching again here would still land, but applySnapshot's
      // non-restore path replaces rows wholesale and resets the windowed
      // visibleCount back to one page, which reads as the feed refreshing
      // itself on every tab switch instead of the instant, no-refetch swap
      // switching back to an already-visited tab should feel like.
      if (visibleModeRef.current !== mode) {
        applySnapshot(cached, mode, true);
        setLoading(false);
      }
      if (mode !== "clubs") return;
      // Clubs is its own, much lower-traffic tab (a handful of posts across
      // however many clubs someone's in, not an endless feed) — entering it
      // always revalidates in the background, the same freshness a manual
      // pull-to-refresh gives elsewhere, just automatic. showLoading stays
      // false so this never flashes a spinner over the cached posts already
      // on screen.
      const revalidateTimer = window.setTimeout(() => {
        void loadMode(mode, { showLoading: false });
      }, 0);
      return () => window.clearTimeout(revalidateTimer);
    }
    const timer = window.setTimeout(() => {
      void loadMode(mode, { showLoading: true });
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
    if (!liked) haptic();
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
    if (!post.liked_by_me) haptic();
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
    if (!saved) haptic();
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
    if (!currentlyFollowing) haptic();
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
    if (!active) haptic();
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
    await shareOrCopyLink({ title: authorLabel(row), text: row.caption || "WYNOS", url }, showToast);
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
    slideDirectionRef.current = modeIndex(next) > modeIndex(mode) ? 1 : -1;
    scrollPositions.current[visibleModeRef.current] = window.scrollY;
    activeModeRef.current = next;
    getHomeScreenStore(userId).mode = next;
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
  // Composes usePullToRefresh's pull-gesture handlers with Home's own
  // horizontal tab-swipe gesture — two independent concerns layered on the
  // same touch events (see swipeStart above and usePullToRefresh's own
  // internal gesture tracking; each keeps its own start-position ref).
  // pull.onTouchMove/onTouchEnd are called unconditionally on every event:
  // their own start.canPull/delta checks already no-op (or reset
  // pullDistance to 0) whenever the drag turns out to be horizontal-
  // dominant or a refresh isn't eligible, so this never has to coordinate
  // with the swipe branch below to avoid double-handling a gesture.
  const onTouchStart = (event: TouchEvent<HTMLDivElement>) => {
    const touch = event.changedTouches[0];
    if (touch) swipeStart.current = { x: touch.clientX, y: touch.clientY };
    pull.onTouchStart(event);
  };
  const onTouchMove = (event: TouchEvent<HTMLDivElement>) => {
    pull.onTouchMove(event);

    const start = swipeStart.current;
    const touch = event.changedTouches[0];
    if (!start || !touch) return;
    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;

    // Horizontal-dominant drag: follow the finger live, the same tab-switch
    // gesture big-platform feeds use. This runs regardless of scroll
    // position (unlike the pull-to-refresh gesture above) since switching
    // tabs by swipe shouldn't require being scrolled to the top. Without
    // this, a swipe that falls short of onTouchEnd's switch threshold — or
    // one aimed past the first/last tab — produced no visible response at
    // all, reading as the gesture not being registered rather than as an
    // incomplete or out-of-bounds swipe.
    if (Math.abs(deltaX) > 8 && Math.abs(deltaX) > Math.abs(deltaY)) {
      const index = modeIndex(mode);
      const atStart = index === 0 && deltaX > 0;
      const atEnd = index === HOME_FEED_MODES.length - 1 && deltaX < 0;
      const dragX = atStart || atEnd ? deltaX * 0.35 : deltaX;
      setSlideStyle({ transform: `translateX(${dragX}px)`, opacity: 1, transition: "none" });
    }
  };
  const onTouchEnd = (event: TouchEvent<HTMLDivElement>) => {
    pull.onTouchEnd(event);

    const start = swipeStart.current;
    const touch = event.changedTouches[0];
    swipeStart.current = null;
    if (!start || !touch) return;

    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    if (Math.abs(deltaY) >= Math.abs(deltaX) || Math.abs(deltaX) < 55) {
      // Didn't clear the switch threshold (too short, too diagonal, or
      // aimed past the first/last tab) — spring the live drag back to rest
      // instead of leaving it wherever the finger let go, so an incomplete
      // swipe still visibly did something rather than looking unresponsive.
      // (Also covers a just-triggered pull-to-refresh release: that always
      // has deltaY > |deltaX|, so it lands here and simply springs back —
      // matching the original's explicit early-return for that case.)
      setSlideStyle({ transform: "translateX(0px)", opacity: 1, transition: "transform 200ms ease-out" });
      return;
    }
    const index = modeIndex(mode);
    const next = deltaX < 0
      ? Math.min(HOME_FEED_MODES.length - 1, index + 1)
      : Math.max(0, index - 1);
    switchMode(HOME_FEED_MODES[next].key);
  };
  const onTouchCancel = () => {
    pull.onTouchCancel();
    swipeStart.current = null;
    setSlideStyle({ transform: "translateX(0px)", opacity: 1, transition: "transform 200ms ease-out" });
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

      {pull.pullDistance > 0 || pull.refreshing ? (
        <PullToRefreshIndicator pull={pull} topOffset="68px" refreshingLabel="กำลังรีเฟรชฟีด" />
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
        style={slideStyle}
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
                onSave={() => void save(row)}
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

      <AnimatePresence>
        {drawerOpen ? <HomeDrawer identity={identity} onClose={() => setDrawerOpen(false)} /> : null}
      </AnimatePresence>

      <AnimatePresence>
      {selected && sheet === "more" ? (
        <ActionSheet key="more" label="ตัวเลือกโพสต์" onClose={() => { setSheet(null); setSelected(null); }}>
          <button className="audit-sheet-row" type="button" onClick={() => { void share(selected); setSheet(null); }}>
            <WynosIcon name="share" size={20} strokeWidth={2} />แชร์
          </button>
          <button className="audit-sheet-row" type="button" onClick={() => { void save(selected); setSheet(null); }}>
            <WynosIcon name="bookmark" size={20} strokeWidth={2} fill={viewer?.savedDropIds.has(selected.id) ? "currentColor" : "none"} />
            {viewer?.savedDropIds.has(selected.id) ? "เอาออกจากบันทึก" : "บันทึก"}
          </button>
          {selected.author_id !== userId ? (
            <button className="audit-sheet-row" type="button" onClick={() => void hide(selected)}>
              <WynosIcon name="close" size={20} strokeWidth={2} />ไม่สนใจโพสต์นี้
            </button>
          ) : null}
          {selected.author_id !== userId ? (
            <button className="audit-sheet-row" type="button" onClick={() => setSheet("report")}>
              <WynosIcon name="flag" size={20} strokeWidth={2} />รายงานโพสต์
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
              <WynosIcon name="repost" size={20} strokeWidth={2} />ลบรีโพสต์
            </button>
          ) : null}
        </ActionSheet>
      ) : null}

      {selected && sheet === "redrop" ? (
        <ActionSheet key="redrop" label="รีโพสต์" onClose={() => { setSheet(null); setSelected(null); }}>
          <div className="wyn-redrop-sheet-options">
            <button className="wyn-redrop-sheet-option is-primary" type="button" onClick={() => void redrop(selected)}>
              <span className="wyn-redrop-sheet-icon" aria-hidden="true"><WynosIcon name="repost" size={28} strokeWidth={2} /></span>
              <span className="wyn-redrop-sheet-copy">
                <strong>{viewer?.redroppedDropIds.has(selected.id) ? "ยกเลิกรีโพสต์" : "รีโพสต์"}</strong>
                <small>
                  {viewer?.redroppedDropIds.has(selected.id)
                    ? "นำโพสต์นี้ออกจากโปรไฟล์ของคุณ"
                    : "แชร์โพสต์นี้ไปยังโปรไฟล์ของคุณ"}
                </small>
              </span>
              <WynosIcon name="chevronRight" className="wyn-redrop-sheet-chevron" size={22} strokeWidth={2} aria-hidden="true" />
            </button>
            <button className="wyn-redrop-sheet-option is-quote" type="button" onClick={() => setSheet("quote")}>
              <span className="wyn-redrop-sheet-icon" aria-hidden="true"><WynosIcon name="quote" size={28} strokeWidth={2} /></span>
              <span className="wyn-redrop-sheet-copy">
                <strong>รีโพสต์พร้อมความคิดเห็น</strong>
                <small>แชร์โพสต์นี้พร้อมเพิ่มความคิดเห็นของคุณ</small>
              </span>
              <WynosIcon name="chevronRight" className="wyn-redrop-sheet-chevron" size={22} strokeWidth={2} aria-hidden="true" />
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
        <ActionSheet key="report" label="รายงานโพสต์" onClose={() => { setSheet(null); setSelected(null); setReportDetail(""); }}>
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
      </AnimatePresence>

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
          draftId={searchParams.get("draft")}
          onClose={() => router.replace("/")}
          onPublished={() => void load()}
        />
      ) : null}
    </AppChrome>
  );
}
