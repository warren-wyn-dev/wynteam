"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, DropPreviewCard, EmptyState, LoadingState } from "@/components/phase3-ui";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import type { HomeFeedRow } from "@/lib/feed";
import { fetchSavedQuoteRows, feedIdentity } from "@/lib/quote-feed-data";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";
import {
  addToBookmarkCollection, bookmarkContent, collectionMembershipsForContent,
  createBookmarkCollection, deleteBookmarkCollection, fetchBookmarkCollectionPage,
  listBookmarkCollections, removeFromBookmarkCollection, renameBookmarkCollection,
  type BookmarkCollection,
} from "@/lib/bookmark-collections";
import styles from "./bookmark-collections.module.css";

const COLLECTIONS_ENABLED = process.env.NEXT_PUBLIC_WYNOS_BOOKMARK_COLLECTIONS === "1";
type BookmarksSnapshot = { rows: HomeFeedRow[]; page: number; hasMore: boolean };

function BookmarksInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const cacheKey = "bookmarks:" + userId;
  const cached = getMountCache<BookmarksSnapshot>(cacheKey);
  const [rows, setRows] = useState<HomeFeedRow[]>(cached?.rows ?? []);
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [collections, setCollections] = useState<BookmarkCollection[]>([]);
  const [collectionsError, setCollectionsError] = useState("");
  const [activeCollection, setActiveCollection] = useState<string | null>(null);
  const [editor, setEditor] = useState<"create" | "rename" | null>(null);
  const [collectionName, setCollectionName] = useState("");
  const [busy, setBusy] = useState(false);
  const [assignRow, setAssignRow] = useState<HomeFeedRow | null>(null);
  const [assigned, setAssigned] = useState<Set<string>>(new Set());
  const [assignmentLoading, setAssignmentLoading] = useState(false);
  const [assignmentBusy, setAssignmentBusy] = useState<string | null>(null);

  useEffect(() => {
    if (!activeCollection) setMountCache(cacheKey, { rows, page, hasMore });
  }, [cacheKey, rows, page, hasMore, activeCollection]);

  useEffect(() => {
    if (!COLLECTIONS_ENABLED) return;
    let active = true;
    void listBookmarkCollections(client, userId)
      .then((next) => { if (active) setCollections(next); })
      .catch((cause) => {
        if (active) setCollectionsError(cause instanceof Error ? cause.message : "โหลดคอลเลกชันไม่สำเร็จ");
      });
    return () => { active = false; };
  }, [client, userId]);

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true); setError("");
    try {
      if (COLLECTIONS_ENABLED && activeCollection) {
        const result = await fetchBookmarkCollectionPage(client, userId, activeCollection, nextPage);
        setRows((current) => append ? [...current, ...result.rows] : result.rows);
        setPage(nextPage);
        setHasMore(result.hasMore);
        return;
      }
      const limit = (nextPage + 1) * 21;
      const [result, savedQuotes] = await Promise.all([
        client.from("saved_feed").select("*").neq("content_type","pop")
          .order("saved_at",{ascending:false}).range(0,limit-1),
        fetchSavedQuoteRows(client,userId,limit),
      ]);
      if (result.error) throw result.error;
      const originals = (result.data ?? []) as (HomeFeedRow & { saved_at?: string })[];
      const next = [...originals,...savedQuotes]
        .sort((a,b) => Date.parse(b.saved_at ?? b.created_at)-Date.parse(a.saved_at ?? a.created_at))
        .slice(nextPage*21,(nextPage+1)*21);
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 21);
    } catch (e) {
      setError(e instanceof Error ? e.message : "โหลดรายการที่บันทึกไว้ไม่สำเร็จ");
    } finally { setLoading(false); }
  }, [client,userId,activeCollection]);

  useEffect(() => { void load(0, false); }, [load]);
  const pull = usePullToRefresh({ enabled: true, onRefresh: () => load(0, false) });

  const selectCollection = (id: string | null) => {
    if (id === activeCollection) return;
    setActiveCollection(id); setRows([]); setPage(0); setHasMore(false);
  };

  const saveEditor = async () => {
    if (!editor || busy) return;
    setBusy(true); setCollectionsError("");
    try {
      if (editor === "create") {
        const created = await createBookmarkCollection(client, userId, collectionName);
        setCollections((current) => [created, ...current]);
        setActiveCollection(created.id); setRows([]); setPage(0); setHasMore(false);
      } else if (activeCollection) {
        await renameBookmarkCollection(client, userId, activeCollection, collectionName);
        setCollections((current) => current.map((entry) =>
          entry.id === activeCollection ? { ...entry, name: collectionName.trim() } : entry));
      }
      setEditor(null); setCollectionName("");
    } catch (cause) {
      setCollectionsError(cause instanceof Error ? cause.message : "บันทึกคอลเลกชันไม่สำเร็จ");
    } finally { setBusy(false); }
  };

  const deleteActiveCollection = async () => {
    if (!activeCollection || busy ||
        !window.confirm("ลบคอลเลกชันนี้? โพสต์ที่บันทึกไว้จะไม่ถูกลบ")) return;
    setBusy(true); setCollectionsError("");
    try {
      await deleteBookmarkCollection(client, userId, activeCollection);
      setCollections((current) => current.filter((entry) => entry.id !== activeCollection));
      selectCollection(null); setEditor(null);
    } catch (cause) {
      setCollectionsError(cause instanceof Error ? cause.message : "ลบคอลเลกชันไม่สำเร็จ");
    } finally { setBusy(false); }
  };

  const openAssignment = async (row: HomeFeedRow) => {
    const content = bookmarkContent(row);
    if (!content) return;
    setAssignRow(row); setAssigned(new Set()); setAssignmentLoading(true); setCollectionsError("");
    try {
      const ids = await collectionMembershipsForContent(client, userId, content);
      setAssigned(new Set(ids));
    } catch (cause) {
      setCollectionsError(cause instanceof Error ? cause.message : "โหลดคอลเลกชันไม่สำเร็จ");
      setAssignRow(null);
    } finally { setAssignmentLoading(false); }
  };

  const toggleAssignment = async (id: string) => {
    const content = assignRow ? bookmarkContent(assignRow) : null;
    if (!content || assignmentBusy || assignmentLoading) return;
    setAssignmentBusy(id); setCollectionsError("");
    const had = assigned.has(id);
    try {
      if (had) await removeFromBookmarkCollection(client,userId,id,content);
      else await addToBookmarkCollection(client,userId,id,content);
      setAssigned((current) => {
        const next = new Set(current);
        if (had) next.delete(id); else next.add(id);
        return next;
      });
      if (had && activeCollection === id) {
        setRows((current) => current.filter((item) => {
          const key = bookmarkContent(item);
          return key?.content_type !== content.content_type || key.content_id !== content.content_id;
        }));
      }
    } catch (cause) {
      setCollectionsError(cause instanceof Error ? cause.message : "จัดเข้าคอลเลกชันไม่สำเร็จ");
    } finally { setAssignmentBusy(null); }
  };

  return <AppChrome title="บันทึกไว้" userId={userId} backHref="/" showBottomNav={false}>
    <PullToRefreshIndicator pull={pull} topOffset="60px" refreshingLabel="กำลังรีเฟรชรายการที่บันทึกไว้" />
    {COLLECTIONS_ENABLED ? <section className={styles.toolbar} aria-label="คอลเลกชันส่วนตัว">
      <div className={styles.tabs}>
        <button type="button" className={styles.tab} aria-pressed={activeCollection===null}
          onClick={() => selectCollection(null)}>ทั้งหมด</button>
        {collections.map((item) =>
          <button type="button" key={item.id} className={styles.tab}
            aria-pressed={activeCollection===item.id}
            onClick={() => selectCollection(item.id)}>{item.name}</button>)}
      </div>
      <div className={styles.actions}>
        <button type="button" className={styles.secondary} disabled={busy}
          onClick={() => {setEditor("create");setCollectionName("");}}>สร้างคอลเลกชัน</button>
        {activeCollection ? <>
          <button type="button" className={styles.secondary} disabled={busy}
            onClick={() => {
              setEditor("rename");
              setCollectionName(collections.find((item) => item.id===activeCollection)?.name ?? "");
            }}>เปลี่ยนชื่อ</button>
          <button type="button" className={styles.secondary} disabled={busy}
            onClick={() => void deleteActiveCollection()}>ลบคอลเลกชัน</button>
        </> : null}
      </div>
      {editor ? <form className={styles.editor} onSubmit={(event) => {event.preventDefault();void saveEditor();}}>
        <label htmlFor="bookmark-collection-name">{editor==="create"?"ตั้งชื่อคอลเลกชัน":"เปลี่ยนชื่อคอลเลกชัน"}</label>
        <input id="bookmark-collection-name" autoFocus maxLength={48} value={collectionName}
          onChange={(event) => setCollectionName(event.target.value)} placeholder="ชื่อคอลเลกชัน" />
        <button type="submit" disabled={busy || !collectionName.trim()}>{busy?"กำลังบันทึก":"บันทึก"}</button>
        <button type="button" onClick={() => setEditor(null)}>ยกเลิก</button>
      </form> : null}
      {collectionsError ? <p className={styles.error} role="alert">{collectionsError}</p> : null}
    </section> : null}
    <div onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
      {error ? <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load(0, false)}>ลองใหม่</button></div>
        : loading && !rows.length ? <LoadingState />
        : !rows.length ? <EmptyState>{activeCollection?"ยังไม่มีโพสต์ในคอลเลกชันนี้":"ยังไม่มีโพสต์ที่บันทึกไว้"}</EmptyState>
        : <div className="bookmarks-list">{rows.map((row) =>
          <div className={styles.card} key={feedIdentity(row)}>
            <DropPreviewCard row={row} viewerId={userId} />
            {COLLECTIONS_ENABLED && bookmarkContent(row) ?
              <div className={styles.cardAction}>
                <button type="button" aria-label="จัดโพสต์เข้าคอลเลกชัน" onClick={() => void openAssignment(row)}>จัดเข้าคอลเลกชัน</button>
              </div> : null}
          </div>)}
          {hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}
        </div>}
    </div>
    {COLLECTIONS_ENABLED && assignRow ? <div className={styles.backdrop} role="presentation"
      onClick={() => !assignmentBusy && setAssignRow(null)}>
      <section className={styles.dialog} role="dialog" aria-modal="true" aria-label="จัดเข้าคอลเลกชัน"
        onClick={(event) => event.stopPropagation()}>
        <h2>จัดเข้าคอลเลกชัน</h2>
        {assignmentLoading ? <p>กำลังโหลด...</p> : !collections.length
          ? <p>ยังไม่มีคอลเลกชัน สร้างคอลเลกชันจากด้านบนก่อน</p>
          : collections.map((entry) =>
            <label className={styles.choice} key={entry.id}>
              <span>{entry.name}</span>
              <input type="checkbox" checked={assigned.has(entry.id)} disabled={Boolean(assignmentBusy)}
                onChange={() => void toggleAssignment(entry.id)} />
            </label>)}
        <button type="button" className={styles.close} disabled={Boolean(assignmentBusy)}
          onClick={() => setAssignRow(null)}>เสร็จสิ้น</button>
      </section>
    </div> : null}
  </AppChrome>;
}
export function BookmarksRoute() {
  return <DeveloperRouteGate>{({ client, userId }) =>
    <BookmarksInner key={userId} client={client} userId={userId} />}</DeveloperRouteGate>;
}
