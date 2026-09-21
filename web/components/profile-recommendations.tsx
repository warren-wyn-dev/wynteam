"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import type { HomeFeedRow } from "@/lib/feed";
import { loadHomeViewerState, toggleAuthorFollow, type HomeViewerState } from "@/lib/home-actions";
import { haptic } from "@/lib/haptics";
import { fetchSuggestedProfiles, profileLabel, type ProfileRow } from "@/lib/phase3-data";

// See identical comment in components/search-route.tsx: a non-uuid
// placeholder id here breaks loadHomeViewerState()'s drop-table queries.
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

export function ProfileRecommendations({
  client,
  userId,
  viewedProfileId,
}: {
  client: SupabaseClient;
  userId: string;
  viewedProfileId: string;
}) {
  const router = useRouter();
  const [profiles, setProfiles] = useState<ProfileRow[] | null>(null);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [pending, setPending] = useState<Set<string>>(new Set());

  useEffect(() => {
    let live = true;
    void (async () => {
      try {
        const next = (await fetchSuggestedProfiles(client, 10)).filter((profile) => profile.id !== userId && profile.id !== viewedProfileId);
        const state = await loadHomeViewerState(client, userId, fakeRows(next));
        if (!live) return;
        setProfiles(next);
        setViewer(state);
      } catch {
        if (live) setProfiles([]);
      }
    })();
    return () => { live = false; };
  }, [client, userId, viewedProfileId]);

  const dismiss = useCallback(async (profile: ProfileRow) => {
    const current = profiles;
    if (!current) return;
    setProfiles(current.filter((item) => item.id !== profile.id));
    const result = await client.from("profile_recommendation_dismissals").insert({ user_id: userId, dismissed_profile_id: profile.id });
    if (result.error) setProfiles(current);
  }, [client, profiles, userId]);

  const follow = useCallback(async (profile: ProfileRow) => {
    if (!viewer || pending.has(profile.id)) return;
    const wasFollowing = viewer.followedAuthorIds.has(profile.id);
    const wasRequested = viewer.pendingFollowAuthorIds.has(profile.id);
    const isPrivate = viewer.privateAuthorIds.has(profile.id) || profile.is_private;
    if (wasRequested && isPrivate && !window.confirm(`ยกเลิกคำขอติดตาม @${profile.username}?`)) return;
    if (!wasFollowing) haptic();
    setPending((current) => new Set(current).add(profile.id));
    try {
      const state = await toggleAuthorFollow(client, userId, profile.id, { currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate });
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

  if (!profiles?.length || !viewer) return null;
  return (
    <section className="profile-recommendations">
      <h2>แนะนำสำหรับคุณ</h2>
      <div className="profile-recommendation-scroll">
        {profiles.map((profile) => {
          const following = viewer.followedAuthorIds.has(profile.id);
          const requested = viewer.pendingFollowAuthorIds.has(profile.id);
          return <article className="profile-recommendation-card" key={profile.id}>
            <button className="recommendation-dismiss" type="button" aria-label="ซ่อนคำแนะนำนี้" onClick={() => void dismiss(profile)}><WynosIcon name="close" size={16} strokeWidth={2} /></button>
            <button className="recommendation-person" type="button" onClick={() => router.push(`/profile/${profile.id}`)}>
              <Avatar src={profile.avatar_url} label={profile.username} size={56} />
              <strong>{profileLabel(profile)}</strong>
              <small>@{profile.username}</small>
            </button>
            <button className={`recommendation-follow ${following || requested ? "soft" : ""}`} type="button" disabled={pending.has(profile.id)} onClick={() => void follow(profile)}>{following ? "กำลังติดตาม" : requested ? "ขอติดตามแล้ว" : "ติดตาม"}</button>
          </article>;
        })}
      </div>
    </section>
  );
}
