"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { WynosAvatar } from "@/components/design-system/WynosAvatar";
import { WynosPillButton } from "@/components/design-system/WynosPillButton";
import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";
import { toggleAuthorFollow } from "@/lib/home-actions";

type Kind = "followers" | "following";
type Person = { id: string; username: string; display_name?: string | null; avatar_url?: string | null; is_verified: boolean; is_private: boolean; following: boolean; requested: boolean };

async function fetchPeople(client: SupabaseClient, viewerId: string, profileId: string, kind: Kind): Promise<Person[]> {
  const relation = kind === "followers"
    ? await client.from("follows").select("follower_id").eq("following_id", profileId).order("created_at", { ascending: false }).limit(200)
    : await client.from("follows").select("following_id").eq("follower_id", profileId).order("created_at", { ascending: false }).limit(200);
  if (relation.error) throw relation.error;
  const ids = kind === "followers"
    ? ((relation.data ?? []) as { follower_id: string }[]).map((row) => String(row.follower_id))
    : ((relation.data ?? []) as { following_id: string }[]).map((row) => String(row.following_id));
  if (!ids.length) return [];
  const [profiles, follows, requests] = await Promise.all([
    client.from("profiles").select("id,username,display_name,avatar_url,is_verified,is_private").in("id", ids),
    client.from("follows").select("following_id").eq("follower_id", viewerId).in("following_id", ids),
    client.from("follow_requests").select("target_id").eq("requester_id", viewerId).in("target_id", ids),
  ]);
  if (profiles.error) throw profiles.error;
  if (follows.error) throw follows.error;
  if (requests.error) throw requests.error;
  const followed = new Set((follows.data ?? []).map((row) => String(row.following_id)));
  const pending = new Set((requests.data ?? []).map((row) => String(row.target_id)));
  const byId = new Map((profiles.data ?? []).map((profile) => [String(profile.id), profile]));
  return ids.map((id) => byId.get(id)).filter(Boolean).map((raw) => ({
    id: String(raw!.id), username: String(raw!.username ?? ""), display_name: raw!.display_name ? String(raw!.display_name) : null,
    avatar_url: raw!.avatar_url ? String(raw!.avatar_url) : null, is_verified: raw!.is_verified === true, is_private: raw!.is_private === true,
    following: followed.has(String(raw!.id)), requested: pending.has(String(raw!.id)),
  }));
}

function FollowListInner({ client, viewerId, profileId, kind }: { client: SupabaseClient; viewerId: string; profileId: string; kind: Kind }) {
  const [people, setPeople] = useState<Person[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState("");
  const load = useCallback(async () => { setLoading(true); setError(""); try { setPeople(await fetchPeople(client, viewerId, profileId, kind)); } catch { setError("โหลดรายชื่อไม่สำเร็จ"); } finally { setLoading(false); } }, [client, kind, profileId, viewerId]);
  useEffect(() => { void load(); }, [load]);
  const follow = async (person: Person) => {
    if (person.id === viewerId || busy) return;
    setBusy(person.id); setError("");
    try {
      const next = await toggleAuthorFollow(client, viewerId, person.id, { currentlyFollowing: person.following, pendingRequest: person.requested, isPrivate: person.is_private });
      setPeople((current) => current.map((item) => item.id === person.id ? { ...item, following: next === "following", requested: next === "requested" } : item));
    } catch { setError("อัปเดตการติดตามไม่สำเร็จ"); }
    finally { setBusy(null); }
  };
  return <AppChrome title={kind === "followers" ? "ผู้ติดตาม" : "กำลังติดตาม"} userId={viewerId} backHref={`/profile/${profileId}`} showBottomNav={false}>{loading ? <LoadingState /> : !people.length ? <EmptyState>{error || (kind === "followers" ? "ยังไม่มีผู้ติดตาม" : "ยังไม่ได้ติดตามใคร")}</EmptyState> : <div className="follow-list-route">{people.map((person) => <div className="follow-list-row" key={person.id}><a className="follow-list-person" href={`/profile/${person.id}`}><WynosAvatar src={person.avatar_url} label={person.username} size={44} /><span><strong>{person.display_name?.trim() || person.username}{person.is_verified ? <b className="route-verified">✓</b> : null}</strong><small>@{person.username}</small></span></a>{person.id !== viewerId ? <WynosPillButton muted={person.following || person.requested} disabled={busy === person.id} onClick={() => void follow(person)}>{person.following ? "กำลังติดตาม" : person.requested ? "ขอติดตามแล้ว" : "ติดตาม"}</WynosPillButton> : null}</div>)}{error ? <p className="route-error follow-list-error">{error}</p> : null}</div>}</AppChrome>;
}

export function ProfileFollowListRoute({ profileId, kind }: { profileId: string; kind: Kind }) {
  return <DeveloperRouteGate>{({ client, userId }) => <FollowListInner client={client} viewerId={userId} profileId={profileId} kind={kind} />}</DeveloperRouteGate>;
}
