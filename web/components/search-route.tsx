"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, DropPreviewCard, EmptyState, ProfileRowView } from "@/components/phase3-ui";
import { FeedSkeleton, SearchClubSkeleton, SearchDiscoverySkeleton, SearchUserSkeleton } from "@/components/ui/skeleton";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { loadHomeViewerState, toggleAuthorFollow, type HomeViewerState } from "@/lib/home-actions";
import { haptic } from "@/lib/haptics";
import type { HomeFeedRow } from "@/lib/feed";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import {
  fetchSuggestedProfiles,
  fetchTrendingHashtags,
  searchClubs,
  searchDrops,
  searchProfiles,
  type ClubRow,
  type ProfileRow,
  type RankedHashtag,
} from "@/lib/phase3-data";

// loadHomeViewerState() also queries drop_likes/saves/redrops (all uuid
// drop_id/content_id columns) for whatever `id` these rows carry — a
// non-uuid placeholder like "profile:<uuid>" makes those queries fail
// server-side (invalid input syntax for type uuid), which throws and
// leaves the caller's viewer state stuck at null forever. An empty id is
// filtered out of dropIds before any drop-table query runs, so only the
// author-scoped follow/request/privacy queries we actually need fire.
function fakeRows(profiles: ProfileRow[]): HomeFeedRow[] {
  return profiles.map((profile) => ({
    id: "",
    content_type: "drop",
    author_id: profile.id,
    author_username: profile.username,
    author_display_name: profile.display_name,
    author_avatar_url: profile.avatar_url,
    created_at: new Date(0).toISOString(),
  }));
}

type UserResultsSnapshot = { rows: ProfileRow[]; viewer: HomeViewerState | null; page: number; hasMore: boolean };

function UserResults({ client, userId, query }: { client: SupabaseClient; userId: string; query: string }) {
  const cacheKey = `search-users:${userId}:${query}`;
  const cached = getMountCache<UserResultsSnapshot>(cacheKey);
  const [rows, setRows] = useState<ProfileRow[]>(cached?.rows ?? []);
  const [viewer, setViewer] = useState<HomeViewerState | null>(cached?.viewer ?? null);
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(!cached);
  const [error, setError] = useState("");
  const [pending, setPending] = useState<Set<string>>(new Set());

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true); setError("");
    try {
      const next = await searchProfiles(client, query, nextPage);
      const combined = append ? [...rows, ...next] : next;
      const nextViewer = await loadHomeViewerState(client, userId, fakeRows(combined));
      const nextHasMore = next.length === 30;
      setRows(combined);
      setPage(nextPage);
      setHasMore(nextHasMore);
      setViewer(nextViewer);
      setMountCache(cacheKey, { rows: combined, viewer: nextViewer, page: nextPage, hasMore: nextHasMore });
    } catch (e) {
      setError(e instanceof Error ? e.message : "ค้นหาผู้ใช้ไม่สำเร็จ");
    } finally {
      setLoading(false);
    }
  }, [client, query, rows, userId, cacheKey]);

  useEffect(() => { void load(0, false); }, [query]); // eslint-disable-line react-hooks/exhaustive-deps

  const follow = useCallback(async (profile: ProfileRow) => {
    if (!viewer || profile.id === userId || pending.has(profile.id)) return;
    const wasFollowing = viewer.followedAuthorIds.has(profile.id);
    const wasRequested = viewer.pendingFollowAuthorIds.has(profile.id);
    const isPrivate = viewer.privateAuthorIds.has(profile.id) || profile.is_private;
    if (wasRequested && isPrivate && !window.confirm(`ยกเลิกคำขอติดตาม @${profile.username}?`)) return;
    if (!wasFollowing) haptic();
    setPending((current) => new Set(current).add(profile.id));
    try {
      const state = await toggleAuthorFollow(client, userId, profile.id, {
        currentlyFollowing: wasFollowing,
        pendingRequest: wasRequested,
        isPrivate,
      });
      setViewer((current) => {
        if (!current) return current;
        const followed = new Set(current.followedAuthorIds);
        const requested = new Set(current.pendingFollowAuthorIds);
        if (state === "following") followed.add(profile.id); else followed.delete(profile.id);
        if (state === "requested") requested.add(profile.id); else requested.delete(profile.id);
        return { ...current, followedAuthorIds: followed, pendingFollowAuthorIds: requested };
      });
    } finally {
      setPending((current) => { const next = new Set(current); next.delete(profile.id); return next; });
    }
  }, [client, pending, userId, viewer]);

  if (loading && !rows.length) return <SearchUserSkeleton />;
  if (error && !rows.length) return <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load(0, false)}>ลองใหม่</button></div>;
  if (!rows.length) return <EmptyState>ไม่พบผู้ใช้สำหรับ “{query}”</EmptyState>;
  return (
    <div className="route-list">
      {rows.map((profile) => {
        const followed = viewer?.followedAuthorIds.has(profile.id) ?? false;
        const requested = viewer?.pendingFollowAuthorIds.has(profile.id) ?? false;
        return (
          <ProfileRowView
            profile={profile}
            key={profile.id}
            trailing={profile.id === userId ? null : (
              <button className={`route-pill ${followed || requested ? "soft" : ""}`} disabled={pending.has(profile.id)} type="button" onClick={() => void follow(profile)}>
                {followed ? "กำลังติดตาม" : requested ? "ขอติดตามแล้ว" : "ติดตาม"}
              </button>
            )}
          />
        );
      })}
      {hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}
    </div>
  );
}

type PagedRowsSnapshot<T> = { rows: T[]; page: number; hasMore: boolean };

function DropResults({ client, query }: { client: SupabaseClient; query: string }) {
  const cacheKey = `search-drops:${query}`;
  const cached = getMountCache<PagedRowsSnapshot<HomeFeedRow>>(cacheKey);
  const [rows, setRows] = useState<HomeFeedRow[]>(cached?.rows ?? []);
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(!cached);
  const [error, setError] = useState("");
  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true); setError("");
    try {
      const next = await searchDrops(client, query, nextPage);
      const nextHasMore = next.length === 21;
      setRows((current) => {
        const combined = append ? [...current, ...next] : next;
        setMountCache(cacheKey, { rows: combined, page: nextPage, hasMore: nextHasMore });
        return combined;
      });
      setPage(nextPage);
      setHasMore(nextHasMore);
    } catch (e) {
      setError(e instanceof Error ? e.message : "ค้นหาโพสต์ไม่สำเร็จ");
    } finally { setLoading(false); }
  }, [client, query, cacheKey]);
  useEffect(() => { void load(0, false); }, [load]);
  if (loading && !rows.length) return <FeedSkeleton items={3} />;
  if (error && !rows.length) return <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load(0, false)}>ลองใหม่</button></div>;
  if (!rows.length) return <EmptyState>ไม่พบโพสต์สำหรับ “{query}”</EmptyState>;
  return <div>{rows.map((row) => <DropPreviewCard row={row} key={row.id} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

function ClubResults({ client, query }: { client: SupabaseClient; query: string }) {
  const cacheKey = `search-clubs:${query}`;
  const cached = getMountCache<PagedRowsSnapshot<ClubRow>>(cacheKey);
  const [rows, setRows] = useState<ClubRow[]>(cached?.rows ?? []);
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(!cached);
  const [error, setError] = useState("");
  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true); setError("");
    try {
      const next = await searchClubs(client, query, nextPage);
      const nextHasMore = next.length === 20;
      setRows((current) => {
        const combined = append ? [...current, ...next] : next;
        setMountCache(cacheKey, { rows: combined, page: nextPage, hasMore: nextHasMore });
        return combined;
      });
      setPage(nextPage);
      setHasMore(nextHasMore);
    } catch (e) {
      setError(e instanceof Error ? e.message : "ค้นหา Club ไม่สำเร็จ");
    } finally { setLoading(false); }
  }, [client, query, cacheKey]);
  useEffect(() => { void load(0, false); }, [load]);
  if (loading && !rows.length) return <SearchClubSkeleton />;
  if (error && !rows.length) return <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load(0, false)}>ลองใหม่</button></div>;
  if (!rows.length) return <EmptyState>ไม่พบ Club สำหรับ “{query}”</EmptyState>;
  return <div className="route-list">{rows.map((club) => <Link href={`/club/${club.id}`} className="route-club-row" key={club.id}><span className="route-club-image">{club.icon_url ? <Image src={club.icon_url} alt="" width={46} height={46} sizes="46px" /> : club.name.slice(0, 1)}</span><span><strong>{club.name}</strong><small>{club.member_count.toLocaleString("th-TH")} สมาชิก{club.category ? ` · ${club.category}` : ""}</small></span></Link>)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

type DiscoverySnapshot = { hashtags: RankedHashtag[]; suggested: ProfileRow[] };

function Discovery({ client, userId }: { client: SupabaseClient; userId: string }) {
  const cacheKey = `search-discovery:${userId}`;
  const cached = getMountCache<DiscoverySnapshot>(cacheKey);
  const [hashtags, setHashtags] = useState<RankedHashtag[]>(cached?.hashtags ?? []);
  const [suggested, setSuggested] = useState<ProfileRow[]>(cached?.suggested ?? []);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [loading, setLoading] = useState(!cached);
  const [pending, setPending] = useState<Set<string>>(new Set());

  useEffect(() => {
    let live = true;
    void Promise.all([
      fetchTrendingHashtags(client, 6),
      fetchSuggestedProfiles(client, 10),
    ]).then(async ([tags, suggest]) => {
      if (!live) return;
      setHashtags(tags);
      setSuggested(suggest);
      setMountCache(cacheKey, { hashtags: tags, suggested: suggest });
      try {
        const nextViewer = await loadHomeViewerState(client, userId, fakeRows(suggest));
        if (live) setViewer(nextViewer);
      } finally {
        if (live) setLoading(false);
      }
    }).catch(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [client, userId, cacheKey]);

  const follow = useCallback(async (profile: ProfileRow) => {
    if (!viewer || profile.id === userId || pending.has(profile.id)) return;
    const wasFollowing = viewer.followedAuthorIds.has(profile.id);
    const wasRequested = viewer.pendingFollowAuthorIds.has(profile.id);
    const isPrivate = viewer.privateAuthorIds.has(profile.id) || profile.is_private;
    if (wasRequested && isPrivate && !window.confirm(`ยกเลิกคำขอติดตาม @${profile.username}?`)) return;
    if (!wasFollowing) haptic();
    setPending((current) => new Set(current).add(profile.id));
    try {
      const state = await toggleAuthorFollow(client, userId, profile.id, {
        currentlyFollowing: wasFollowing,
        pendingRequest: wasRequested,
        isPrivate,
      });
      setViewer((current) => {
        if (!current) return current;
        const followed = new Set(current.followedAuthorIds);
        const requested = new Set(current.pendingFollowAuthorIds);
        if (state === "following") followed.add(profile.id); else followed.delete(profile.id);
        if (state === "requested") requested.add(profile.id); else requested.delete(profile.id);
        return { ...current, followedAuthorIds: followed, pendingFollowAuthorIds: requested };
      });
    } finally {
      setPending((current) => { const next = new Set(current); next.delete(profile.id); return next; });
    }
  }, [client, pending, userId, viewer]);

  if (loading && !hashtags.length && !suggested.length) return <SearchDiscoverySkeleton />;
  return (
    <div className="discovery-page flutter-search-discovery">
      <section className="route-section">
        <div className="route-section-title"><h2>แฮชแท็กกำลังนิยม</h2></div>
        <div className="hashtag-list">
          {hashtags.length ? hashtags.map((item, index) => (
            <div className="hashtag-row flutter-rank-row" key={item.tag}>
              <b>{index + 1}</b>
              <span className="flutter-rank-copy"><strong>#{item.tag}</strong><small>{item.postCount.toLocaleString("th-TH")} โพสต์ · กำลังนิยมใน ไทย</small></span>
              <WynosIcon name="more" size={16} strokeWidth={2} aria-hidden="true" />
            </div>
          )) : <EmptyState>ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้</EmptyState>}
        </div>
        <Link className="top100-link" href="/trending">ดูอันดับทั้งหมด (Top 100) <WynosIcon name="chevronRight" size={14} strokeWidth={2} /></Link>
      </section>
      <section className="route-section flutter-suggested-section">
        <div className="route-section-title"><h2>แนะนำให้ติดตาม</h2></div>
        {suggested.length ? (
          <div className="route-list">
            {suggested.map((profile) => {
              const followed = viewer?.followedAuthorIds.has(profile.id) ?? false;
              const requested = viewer?.pendingFollowAuthorIds.has(profile.id) ?? false;
              return (
                <ProfileRowView
                  profile={profile}
                  key={profile.id}
                  trailing={profile.id === userId ? null : (
                    <button
                      className={`route-pill search-follow-button ${followed || requested ? "soft" : ""}`}
                      disabled={!viewer || pending.has(profile.id)}
                      type="button"
                      onClick={() => void follow(profile)}
                    >
                      {followed ? "กำลังติดตาม" : requested ? "ขอติดตามแล้ว" : "ติดตาม"}
                    </button>
                  )}
                />
              );
            })}
          </div>
        ) : <EmptyState>ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้</EmptyState>}
      </section>
    </div>
  );
}

type SearchTab = "all" | "users" | "posts" | "clubs";
type AllResultsSnapshot = { users: ProfileRow[]; drops: HomeFeedRow[]; clubs: ClubRow[] };

// WYN-185 item 7: the "ทั้งหมด" (All) default tab, so a query that only
// matches posts (e.g. a caption keyword with no matching username) doesn't
// land on an empty User tab first — every tab used to default to "user"
// regardless of what the query actually matched.
function AllResults({
  client,
  userId,
  query,
  onSelectTab,
}: {
  client: SupabaseClient;
  userId: string;
  query: string;
  onSelectTab: (tab: SearchTab) => void;
}) {
  const cacheKey = `search-all:${userId}:${query}`;
  const cached = getMountCache<AllResultsSnapshot>(cacheKey);
  const [users, setUsers] = useState<ProfileRow[]>(cached?.users ?? []);
  const [drops, setDrops] = useState<HomeFeedRow[]>(cached?.drops ?? []);
  const [clubs, setClubs] = useState<ClubRow[]>(cached?.clubs ?? []);
  const [loading, setLoading] = useState(!cached);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const [nextUsers, nextDrops, nextClubs] = await Promise.all([
        searchProfiles(client, query, 0),
        searchDrops(client, query, 0),
        searchClubs(client, query, 0),
      ]);
      setUsers(nextUsers); setDrops(nextDrops); setClubs(nextClubs);
      setMountCache(cacheKey, { users: nextUsers, drops: nextDrops, clubs: nextClubs });
    } catch (e) {
      setError(e instanceof Error ? e.message : "ค้นหาไม่สำเร็จ");
    } finally { setLoading(false); }
  }, [client, query, cacheKey]);

  useEffect(() => { void load(); }, [load]);

  const empty = !users.length && !drops.length && !clubs.length;
  if (loading && empty) {
    return <div className="search-all-results"><SearchUserSkeleton items={3} /><FeedSkeleton items={2} /><SearchClubSkeleton items={2} /></div>;
  }
  if (error && empty) return <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load()}>ลองใหม่</button></div>;
  if (empty) return <EmptyState>ไม่พบผลลัพธ์สำหรับ “{query}”</EmptyState>;

  return (
    <div className="search-all-results flutter-search-discovery">
      {users.length ? (
        <section className="route-section">
          <div className="route-section-title"><h2>ผู้ใช้</h2>{users.length > 3 ? <button className="search-all-see-more" type="button" onClick={() => onSelectTab("users")}>ดูทั้งหมด</button> : null}</div>
          <div className="route-list">{users.slice(0, 3).map((profile) => <ProfileRowView profile={profile} key={profile.id} />)}</div>
        </section>
      ) : null}
      {drops.length ? (
        <section className="route-section">
          <div className="route-section-title"><h2>โพสต์</h2>{drops.length > 2 ? <button className="search-all-see-more" type="button" onClick={() => onSelectTab("posts")}>ดูทั้งหมด</button> : null}</div>
          {drops.slice(0, 2).map((row) => <DropPreviewCard row={row} key={row.id} />)}
        </section>
      ) : null}
      {clubs.length ? (
        <section className="route-section">
          <div className="route-section-title"><h2>Club</h2>{clubs.length > 2 ? <button className="search-all-see-more" type="button" onClick={() => onSelectTab("clubs")}>ดูทั้งหมด</button> : null}</div>
          <div className="route-list">{clubs.slice(0, 2).map((club) => <Link href={`/club/${club.id}`} className="route-club-row" key={club.id}><span className="route-club-image">{club.icon_url ? <Image src={club.icon_url} alt="" width={46} height={46} sizes="46px" /> : club.name.slice(0, 1)}</span><span><strong>{club.name}</strong><small>{club.member_count.toLocaleString("th-TH")} สมาชิก{club.category ? ` · ${club.category}` : ""}</small></span></Link>)}</div>
        </section>
      ) : null}
    </div>
  );
}

const SEARCH_TABS: readonly SearchTab[] = ["all", "users", "posts", "clubs"];
const SEARCH_DEBOUNCE_MS = 400;

// WYN-185 item 7: query + result tab now live in the URL (?q=...&type=...)
// instead of only in local state, so a refresh, back/forward navigation, or
// a shared link all reproduce the same search instead of landing back on
// empty Discovery. `type` is omitted from the URL for the "all" default to
// keep the common-case URL short (/search?q=wynos instead of
// /search?q=wynos&type=all).
function SearchInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const params = useSearchParams();
  const urlQuery = params.get("q")?.trim() ?? "";
  const urlTabParam = params.get("type");
  const tab: SearchTab = SEARCH_TABS.includes(urlTabParam as SearchTab) ? (urlTabParam as SearchTab) : "all";
  const [draft, setDraft] = useState(urlQuery);

  // The URL is the source of truth; keep the input in sync when it changes
  // from outside typing (back/forward, a shared link, the clear button).
  useEffect(() => { setDraft(urlQuery); }, [urlQuery]);

  const updateUrl = useCallback((nextQuery: string, nextTab: SearchTab) => {
    const qs = new URLSearchParams();
    if (nextQuery) qs.set("q", nextQuery);
    if (nextTab !== "all") qs.set("type", nextTab);
    const suffix = qs.toString();
    router.replace(suffix ? `/search?${suffix}` : "/search");
  }, [router]);

  // Debounced as-you-type search (WYN-185 item 7: "ใช้ debounce สำหรับช่องค้นหา").
  // Submitting via Enter/the search icon (submitNow below) bypasses this
  // for an immediate result instead of waiting out the debounce.
  useEffect(() => {
    const trimmed = draft.trim();
    if (trimmed === urlQuery) return;
    if (trimmed.length > 0 && trimmed.length < 2) return; // too short to search yet
    const timer = window.setTimeout(() => updateUrl(trimmed, tab), SEARCH_DEBOUNCE_MS);
    return () => window.clearTimeout(timer);
  }, [draft, urlQuery, tab, updateUrl]);

  const submitNow = () => {
    const trimmed = draft.trim();
    if (trimmed.length > 0 && trimmed.length < 2) return;
    updateUrl(trimmed, tab);
  };
  const selectTab = (next: SearchTab) => updateUrl(urlQuery, next);
  const clear = () => { setDraft(""); updateUrl("", tab); };

  const closeSearch = () => {
    if (window.history.length > 1) {
      router.back();
      return;
    }
    router.push("/");
  };
  const submitted = urlQuery.length >= 2;
  const tabs = useMemo(() => [
    { id: "all" as const, label: "ทั้งหมด" },
    { id: "users" as const, label: "User" },
    { id: "posts" as const, label: "โพสต์" },
    { id: "clubs" as const, label: "Club" },
  ], []);
  return (
    <AppChrome title="" userId={userId} headerMode="hidden">
      <div className="flutter-search-header">
        <button className="search-back-button" type="button" aria-label="ออกจากหน้าค้นหา" onClick={closeSearch}><WynosIcon name="back" size={28} strokeWidth={2} /></button>
        <form className="search-route-form" onSubmit={(event) => { event.preventDefault(); submitNow(); }}>
          <button type="submit" aria-label="ค้นหา"><WynosIcon name="search" size={20} strokeWidth={2} /></button>
          <input value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="ค้นหา username, โพสต์, Club" inputMode="search" />
          {draft ? <button type="button" aria-label="ล้างคำค้นหา" onClick={clear}><WynosIcon name="close" size={18} strokeWidth={2} /></button> : null}
        </form>
      </div>
      {!submitted ? <Discovery client={client} userId={userId} /> : (
        <>
          <div className="route-tabs flutter-search-tabs" role="tablist" aria-label="ประเภทผลการค้นหา">{tabs.map((item) => <button type="button" role="tab" aria-selected={tab === item.id} className={tab === item.id ? "active" : ""} onClick={() => selectTab(item.id)} key={item.id}>{item.label}</button>)}</div>
          {tab === "all" ? <AllResults client={client} userId={userId} query={urlQuery} onSelectTab={selectTab} /> : null}
          {tab === "users" ? <UserResults client={client} userId={userId} query={urlQuery} /> : null}
          {tab === "posts" ? <DropResults client={client} query={urlQuery} /> : null}
          {tab === "clubs" ? <ClubResults client={client} query={urlQuery} /> : null}
        </>
      )}
    </AppChrome>
  );
}

export function SearchRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <SearchInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
