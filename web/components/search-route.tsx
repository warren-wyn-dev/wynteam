"use client";

import { ChevronRight, MoreHorizontal, Search, X } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, DropPreviewCard, EmptyState, LoadingState, ProfileRowView } from "@/components/phase3-ui";
import { loadHomeViewerState, toggleAuthorFollow, type HomeViewerState } from "@/lib/home-actions";
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

function fakeRows(profiles: ProfileRow[]): HomeFeedRow[] {
  return profiles.map((profile) => ({
    id: `profile:${profile.id}`,
    content_type: "drop",
    author_id: profile.id,
    author_username: profile.username,
    author_display_name: profile.display_name,
    author_avatar_url: profile.avatar_url,
    created_at: new Date(0).toISOString(),
  }));
}

function UserResults({ client, userId, query }: { client: SupabaseClient; userId: string; query: string }) {
  const [rows, setRows] = useState<ProfileRow[]>([]);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState<Set<string>>(new Set());

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      const next = await searchProfiles(client, query, nextPage);
      const combined = append ? [...rows, ...next] : next;
      setRows(combined);
      setPage(nextPage);
      setHasMore(next.length === 30);
      setViewer(await loadHomeViewerState(client, userId, fakeRows(combined)));
    } finally {
      setLoading(false);
    }
  }, [client, query, rows, userId]);

  useEffect(() => { void load(0, false); }, [query]); // eslint-disable-line react-hooks/exhaustive-deps

  const follow = useCallback(async (profile: ProfileRow) => {
    if (!viewer || profile.id === userId || pending.has(profile.id)) return;
    const wasFollowing = viewer.followedAuthorIds.has(profile.id);
    const wasRequested = viewer.pendingFollowAuthorIds.has(profile.id);
    const isPrivate = viewer.privateAuthorIds.has(profile.id) || profile.is_private;
    if (wasRequested && isPrivate && !window.confirm(`ยกเลิกคำขอติดตาม @${profile.username}?`)) return;
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

  if (loading && !rows.length) return <LoadingState />;
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

function DropResults({ client, query }: { client: SupabaseClient; query: string }) {
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      const next = await searchDrops(client, query, nextPage);
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 21);
    } finally { setLoading(false); }
  }, [client, query]);
  useEffect(() => { void load(0, false); }, [load]);
  if (loading && !rows.length) return <LoadingState />;
  if (!rows.length) return <EmptyState>ไม่พบโพสต์สำหรับ “{query}”</EmptyState>;
  return <div>{rows.map((row) => <DropPreviewCard row={row} key={row.id} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

function ClubResults({ client, query }: { client: SupabaseClient; query: string }) {
  const [rows, setRows] = useState<ClubRow[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      const next = await searchClubs(client, query, nextPage);
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 20);
    } finally { setLoading(false); }
  }, [client, query]);
  useEffect(() => { void load(0, false); }, [load]);
  if (loading && !rows.length) return <LoadingState />;
  if (!rows.length) return <EmptyState>ไม่พบ Club สำหรับ “{query}”</EmptyState>;
  return <div className="route-list">{rows.map((club) => <Link href={`/club/${club.id}`} className="route-club-row" key={club.id}><span className="route-club-image">{club.icon_url ? <Image src={club.icon_url} alt="" width={46} height={46} sizes="46px" /> : club.name.slice(0, 1)}</span><span><strong>{club.name}</strong><small>{club.member_count.toLocaleString("th-TH")} สมาชิก{club.category ? ` · ${club.category}` : ""}</small></span></Link>)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

type DiscoverySnapshot = { hashtags: RankedHashtag[]; suggested: ProfileRow[] };

function Discovery({ client, userId }: { client: SupabaseClient; userId: string }) {
  const cacheKey = `search-discovery:${userId}`;
  const cached = getMountCache<DiscoverySnapshot>(cacheKey);
  const [hashtags, setHashtags] = useState<RankedHashtag[]>(cached?.hashtags ?? []);
  const [suggested, setSuggested] = useState<ProfileRow[]>(cached?.suggested ?? []);
  const [loading, setLoading] = useState(!cached);
  useEffect(() => {
    let live = true;
    void Promise.all([
      fetchTrendingHashtags(client, 6),
      fetchSuggestedProfiles(client, 10),
    ]).then(([tags, suggest]) => {
      if (!live) return;
      setHashtags(tags);
      setSuggested(suggest);
      setLoading(false);
      setMountCache(cacheKey, { hashtags: tags, suggested: suggest });
    }).catch(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [client, cacheKey]);
  if (loading && !hashtags.length && !suggested.length) return <LoadingState />;
  return (
    <div className="discovery-page flutter-search-discovery">
      <section className="route-section">
        <div className="route-section-title"><h2>แฮชแท็กกำลังนิยม</h2></div>
        <div className="hashtag-list">
          {hashtags.length ? hashtags.map((item, index) => (
            <div className="hashtag-row flutter-rank-row" key={item.tag}>
              <b>{index + 1}</b>
              <span className="flutter-rank-copy"><strong>#{item.tag}</strong><small>{item.postCount.toLocaleString("th-TH")} โพสต์ · กำลังนิยมใน ไทย</small></span>
              <MoreHorizontal size={16} aria-hidden="true" />
            </div>
          )) : <EmptyState>ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้</EmptyState>}
        </div>
        <button className="top100-link" type="button">ดูอันดับทั้งหมด (Top 100) <ChevronRight size={14} /></button>
      </section>
      <section className="route-section flutter-suggested-section">
        <div className="route-section-title"><h2>แนะนำให้ติดตาม</h2></div>
        {suggested.length ? <div className="route-list">{suggested.map((profile) => <ProfileRowView profile={profile} key={profile.id} />)}</div> : <EmptyState>ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้</EmptyState>}
      </section>
    </div>
  );
}

function SearchInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const params = useSearchParams();
  const urlQuery = params.get("q")?.trim() ?? "";
  const [draft, setDraft] = useState(urlQuery);
  const [query, setQuery] = useState(urlQuery.length >= 2 ? urlQuery : "");
  const [tab, setTab] = useState<"user" | "drop" | "club">(urlQuery.startsWith("#") ? "drop" : "user");
  useEffect(() => {
    if (urlQuery.length < 2) return;
    setDraft(urlQuery);
    setQuery(urlQuery);
    if (urlQuery.startsWith("#")) setTab("drop");
  }, [urlQuery]);
  const submitted = query.trim().length >= 2 && draft.trim() === query;
  const submit = () => setQuery(draft.trim());
  const tabs = useMemo(() => [{ id: "user" as const, label: "User" }, { id: "drop" as const, label: "โพสต์" }, { id: "club" as const, label: "Club" }], []);
  return (
    <AppChrome title="" userId={userId} headerMode="hidden">
      <div className="flutter-search-header">
        <form className="search-route-form" onSubmit={(event) => { event.preventDefault(); submit(); }}>
          <button type="submit" aria-label="ค้นหา"><Search size={20} /></button>
          <input value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="ค้นหา username, โพสต์, Club" inputMode="search" />
          {draft ? <button type="button" aria-label="ล้างคำค้นหา" onClick={() => { setDraft(""); setQuery(""); }}><X size={18} /></button> : null}
        </form>
      </div>
      {!submitted ? <Discovery client={client} userId={userId} /> : (
        <>
          <div className="route-tabs flutter-search-tabs">{tabs.map((item) => <button type="button" className={tab === item.id ? "active" : ""} onClick={() => setTab(item.id)} key={item.id}>{item.label}</button>)}</div>
          {tab === "user" ? <UserResults client={client} userId={userId} query={query} /> : null}
          {tab === "drop" ? <DropResults client={client} query={query} /> : null}
          {tab === "club" ? <ClubResults client={client} query={query} /> : null}
        </>
      )}
    </AppChrome>
  );
}

export function SearchRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <SearchInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
