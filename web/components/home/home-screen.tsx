"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { Bookmark, Flag, Quote, Repeat, Share2, X } from "lucide-react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState, type TouchEvent } from "react";

import { Beta4Composer } from "@/components/beta4-composer";
import { WynosAppShell } from "@/components/design-system/WynosAppShell";
import { ClubFeedPost } from "@/components/home/club-feed-post";
import homeShell from "@/components/home/home-shell.module.css";
import { HomeDrawer } from "@/components/home/home-drawer";
import { HomeHeader } from "@/components/home/home-header";
import { HomePostCard } from "@/components/home/home-post-card";
import { HOME_FEED_MODES, HomeTabs, type HomeFeedMode } from "@/components/home/home-tabs";
import { AppChrome, useUnreadNotificationBadge } from "@/components/phase3-ui";
import { authorLabel, type HomeFeedRow } from "@/lib/feed";
import {
  loadHomeViewerState,
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
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

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

  const [mode, setMode] = useState<HomeFeedMode>("for-you");
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [clubRows, setClubRows] = useState<ClubHomePost[]>([]);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [images, setImages] = useState<Map<string, string[]>>(new Map());
  const [identity, setIdentity] = useState<HomeIdentity | null>(null);
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
  const touchStart = useRef<number | null>(null);

  useEffect(() => {
    if (!client) return;
    void fetchHomeIdentity(client, userId)
      .then((nextIdentity) => setIdentity(nextIdentity))
      .catch(() => undefined);
  }, [client, userId]);

  const { notificationBadge, notificationLabel } = useUnreadNotificationBadge(userId, true);

  const load = useCallback(async () => {
    if (!client) return;
    setLoading(true);
    setError("");
    try {
      if (mode === "clubs") {
        setClubRows(await fetchClubHomePosts(client, userId));
        setRows([]);
        setViewer(null);
        setImages(new Map());
      } else {
        const nextRows = await fetchHomeSurfaceRows(client, userId, {
          kind: mode === "following" ? "following" : "ranked",
        });
        const [state, media] = await Promise.all([
          loadHomeViewerState(client, userId, nextRows),
          fetchDropImages(client, nextRows),
        ]);
        setRows(nextRows);
        setViewer(state);
        setImages(media);
        setClubRows([]);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "โหลดฟีดไม่สำเร็จ");
    } finally {
      setLoading(false);
    }
  }, [client, mode, userId]);

  useEffect(() => {
    const timer = window.setTimeout(() => { void load(); }, 0);
    return () => window.clearTimeout(timer);
  }, [load]);

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
    }
  };

  const followAuthor = async (row: HomeFeedRow) => {
    if (!client || !viewer || row.author_id === userId) return;
    const currentlyFollowing = viewer.followedAuthorIds.has(row.author_id);
    const pendingRequest = viewer.pendingFollowAuthorIds.has(row.author_id);
    const isPrivate = viewer.privateAuthorIds.has(row.author_id);
    try {
      const next = await toggleAuthorFollow(client, userId, row.author_id, {
        currentlyFollowing,
        pendingRequest,
        isPrivate,
      });
      setViewer((current) => {
        if (!current) return current;
        const followedAuthorIds = new Set(current.followedAuthorIds);
        const pendingFollowAuthorIds = new Set(current.pendingFollowAuthorIds);
        followedAuthorIds.delete(row.author_id);
        pendingFollowAuthorIds.delete(row.author_id);
        if (next === "following") followedAuthorIds.add(row.author_id);
        if (next === "requested") pendingFollowAuthorIds.add(row.author_id);
        return { ...current, followedAuthorIds, pendingFollowAuthorIds };
      });
    } catch {
      void load();
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
    }
  };

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
      setError(e instanceof Error ? e.message : "Quote ReDrop ไม่สำเร็จ");
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
    if (next !== mode) setMode(next);
  };
  const onTouchStart = (event: TouchEvent<HTMLDivElement>) => {
    touchStart.current = event.changedTouches[0]?.clientX ?? null;
  };
  const onTouchEnd = (event: TouchEvent<HTMLDivElement>) => {
    const start = touchStart.current;
    touchStart.current = null;
    if (start == null) return;
    const end = event.changedTouches[0]?.clientX ?? start;
    const delta = end - start;
    if (Math.abs(delta) < 55) return;
    const index = modeIndex(mode);
    const next = delta < 0
      ? Math.min(HOME_FEED_MODES.length - 1, index + 1)
      : Math.max(0, index - 1);
    switchMode(HOME_FEED_MODES[next].key);
  };

  if (!client) {
    return <main className={homeShell.state}><p>ยังไม่ได้ตั้งค่า Supabase สำหรับเว็บ</p></main>;
  }

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav>
      <WynosAppShell>
        <div className={homeShell.stickyWrap}>
          <div className={homeShell.headerGroup}>
            <HomeHeader
              notificationBadge={notificationBadge}
              notificationLabel={notificationLabel}
              onOpenMenu={() => setDrawerOpen(true)}
              onOpenSearch={() => router.push("/search")}
              onOpenNotifications={() => router.push("/notifications")}
            />
            <HomeTabs mode={mode} onSelect={switchMode} />
          </div>
        </div>

        <div className={homeShell.feed} onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
          {loading ? (
            <div className={homeShell.state}><div className="route-system-spinner" /></div>
          ) : error && !rows.length && !clubRows.length ? (
            <div className={homeShell.state}>
              <p>{error}</p>
              <button className="route-secondary" type="button" onClick={() => void load()}>ลองใหม่</button>
            </div>
          ) : mode === "clubs" ? (
            clubRows.length ? (
              clubRows.map((post) => (
                <ClubFeedPost post={post} onLike={() => void likeClub(post)} key={post.id} />
              ))
            ) : (
              <div className={homeShell.state}>
                <p>ยังไม่มีโพสต์จาก Club ของคุณ</p>
                <Link className="route-primary" href="/clubs">สำรวจ Club</Link>
              </div>
            )
          ) : rows.length && viewer ? (
            rows.map((row) => (
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
                key={`${row.id}:${row.redrop_id ?? "plain"}`}
              />
            ))
          ) : (
            <div className={homeShell.state}>
              <p>{mode === "following" ? "ยังไม่มีโพสต์จากคนที่คุณกำลังติดตาม" : "ยังไม่มีอะไรให้ดูตรงนี้"}</p>
              <Link className="route-primary" href="/search">ค้นหาคนและเนื้อหา</Link>
            </div>
          )}
        </div>
      </WynosAppShell>

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
              <Repeat size={20} />ลบรีโพสต์
            </button>
          ) : null}
        </ActionSheet>
      ) : null}

      {selected && sheet === "redrop" ? (
        <ActionSheet label="รีโพสต์" onClose={() => { setSheet(null); setSelected(null); }}>
          <button className="audit-sheet-row" type="button" onClick={() => void redrop(selected)}>
            <Repeat size={20} />{viewer?.redroppedDropIds.has(selected.id) ? "ยกเลิก ReDrop" : "ReDrop"}
          </button>
          <button className="audit-sheet-row" type="button" onClick={() => setSheet("quote")}>
            <Quote size={20} />Quote ReDrop
          </button>
        </ActionSheet>
      ) : null}

      {selected && sheet === "quote" ? (
        <ActionSheet label="Quote ReDrop" onClose={() => { setSheet(null); setSelected(null); setQuote(""); }}>
          <div className="audit-sheet-form">
            <strong>Quote ReDrop</strong>
            <textarea
              maxLength={500}
              autoFocus
              value={quote}
              onChange={(event) => setQuote(event.target.value)}
              placeholder="เขียนความคิดเห็นของคุณ…"
            />
            {error ? <p className="route-error">{error}</p> : null}
            <button className="route-primary" type="button" disabled={busy || !quote.trim()} onClick={() => void quoteRedrop()}>
              รีโพสต์พร้อมความคิดเห็น
            </button>
          </div>
        </ActionSheet>
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
