"use client";

import { Camera, MessageCircle, MoreHorizontal } from "lucide-react";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, DropPreviewCard, EmptyState, LoadingState, SettingsLink } from "@/components/phase3-ui";
import { toggleAuthorFollow } from "@/lib/home-actions";
import type { HomeFeedRow } from "@/lib/feed";
import {
  canViewProfileLikes,
  chatAllowed,
  fetchProfileDrops,
  fetchProfileLikedDrops,
  fetchProfileSummary,
  getOrCreateConversation,
  profileLabel,
  updateProfileBasics,
  updateUsername,
  uploadProfileImage,
  type ProfileSummary,
} from "@/lib/phase3-data";

async function fetchRedrops(client: SupabaseClient, userId: string, page: number): Promise<HomeFeedRow[]> {
  const from = page * 10;
  const result = await client
    .from("home_feed")
    .select("*")
    .eq("redropper_id", userId)
    .neq("content_type", "pop")
    .order("created_at", { ascending: false })
    .range(from, from + 9);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as HomeFeedRow[];
}

function ProfileFeed({
  client,
  profileId,
  kind,
}: {
  client: SupabaseClient;
  profileId: string;
  kind: "posts" | "redrops" | "likes";
}) {
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [allowed, setAllowed] = useState(true);

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      let next: HomeFeedRow[];
      if (kind === "posts") next = await fetchProfileDrops(client, profileId, nextPage);
      else if (kind === "redrops") next = await fetchRedrops(client, profileId, nextPage);
      else next = await fetchProfileLikedDrops(client, profileId, nextPage);
      if (kind === "likes" && nextPage === 0 && !next.length) setAllowed(await canViewProfileLikes(client, profileId));
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === (kind === "redrops" ? 10 : 21));
    } catch {
      setRows([]);
    } finally { setLoading(false); }
  }, [client, kind, profileId]);

  useEffect(() => { setAllowed(true); void load(0, false); }, [load]);
  if (loading && !rows.length) return <LoadingState />;
  if (!allowed) return <EmptyState>เจ้าของบัญชีจำกัดผู้ที่เห็นรายการที่ถูกใจ</EmptyState>;
  if (!rows.length) return <EmptyState>{kind === "posts" ? "ยังไม่มีโพสต์" : kind === "redrops" ? "ยังไม่มีรีโพสต์" : "ยังไม่มีรายการที่ถูกใจ"}</EmptyState>;
  return <div>{rows.map((row) => <DropPreviewCard row={row} key={`${row.id}:${row.redrop_id ?? "plain"}`} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

function EditProfile({
  client,
  userId,
  summary,
  onDone,
}: {
  client: SupabaseClient;
  userId: string;
  summary: ProfileSummary;
  onDone: () => void;
}) {
  const profile = summary.profile;
  const [displayName, setDisplayName] = useState(profile.display_name ?? "");
  const [username, setUsername] = useState(profile.username);
  const [bio, setBio] = useState(profile.bio ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [avatar, setAvatar] = useState(profile.avatar_url);
  const [cover, setCover] = useState(profile.cover_url);

  const image = async (kind: "avatar" | "cover", file?: File) => {
    if (!file) return;
    setSaving(true); setError("");
    try {
      const url = await uploadProfileImage(client, userId, kind, file);
      if (kind === "avatar") setAvatar(url); else setCover(url);
    } catch (e) { setError(e instanceof Error ? e.message : "อัปโหลดรูปไม่สำเร็จ"); }
    finally { setSaving(false); }
  };

  const save = async () => {
    if (!displayName.trim() && !profile.display_name) {
      setError("กรุณาใส่ชื่อที่แสดง"); return;
    }
    setSaving(true); setError("");
    try {
      if (username.trim() !== profile.username) await updateUsername(client, userId, username);
      await updateProfileBasics(client, userId, { displayName, bio });
      onDone();
    } catch (e) { setError(e instanceof Error ? e.message : "บันทึกไม่สำเร็จ"); }
    finally { setSaving(false); }
  };

  return (
    <div className="profile-edit">
      <div className="profile-cover edit-cover">{cover ? <img src={cover} alt="" /> : null}<label><Camera size={18} /> เปลี่ยนรูปหน้าปก<input type="file" accept="image/*" hidden disabled={saving} onChange={(e) => void image("cover", e.target.files?.[0])} /></label></div>
      <div className="profile-edit-avatar"><Avatar src={avatar} label={username} size={84} /><label><Camera size={16} /> รูปโปรไฟล์<input type="file" accept="image/*" hidden disabled={saving} onChange={(e) => void image("avatar", e.target.files?.[0])} /></label></div>
      <label className="route-field"><span>ชื่อที่แสดง</span><input value={displayName} maxLength={50} onChange={(e) => setDisplayName(e.target.value)} /></label>
      <label className="route-field"><span>Username</span><input value={username} autoCapitalize="none" maxLength={30} onChange={(e) => setUsername(e.target.value.replace(/[^a-zA-Z0-9_.]/g, ""))} /></label>
      <label className="route-field"><span>Bio</span><textarea value={bio} maxLength={300} onChange={(e) => setBio(e.target.value)} /></label>
      {error ? <p className="route-error">{error}</p> : null}
      <div className="route-action-row"><button className="route-secondary" type="button" disabled={saving} onClick={onDone}>ยกเลิก</button><button className="route-primary" type="button" disabled={saving} onClick={() => void save()}>{saving ? "กำลังบันทึก…" : "บันทึก"}</button></div>
    </div>
  );
}

function ProfileInner({
  client,
  userId,
  profileId,
}: {
  client: SupabaseClient;
  userId: string;
  profileId: string;
}) {
  const router = useRouter();
  const [summary, setSummary] = useState<ProfileSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [action, setAction] = useState(false);
  const [editing, setEditing] = useState(false);
  const [tab, setTab] = useState<"posts" | "redrops" | "likes">("posts");
  const [error, setError] = useState("");
  const own = profileId === userId;

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try { setSummary(await fetchProfileSummary(client, userId, profileId)); }
    catch (e) { setError(e instanceof Error ? e.message : "โหลดโปรไฟล์ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, profileId, userId]);
  useEffect(() => { void load(); }, [load]);

  if (loading) return <AppChrome title="โปรไฟล์" userId={userId} backHref="/"><LoadingState /></AppChrome>;
  if (!summary) return <AppChrome title="โปรไฟล์" userId={userId} backHref="/"><EmptyState>{error || "ไม่พบโปรไฟล์"}</EmptyState></AppChrome>;
  const profile = summary.profile;
  const name = profileLabel(profile);

  const follow = async () => {
    if (own || action) return;
    if (summary.requested && profile.is_private && !window.confirm(`ยกเลิกคำขอติดตาม @${profile.username}?`)) return;
    setAction(true); setError("");
    try {
      await toggleAuthorFollow(client, userId, profile.id, {
        currentlyFollowing: summary.following,
        pendingRequest: summary.requested,
        isPrivate: profile.is_private,
      });
      await load();
    } catch (e) { setError(e instanceof Error ? e.message : "ติดตามไม่สำเร็จ"); }
    finally { setAction(false); }
  };

  const startChat = async () => {
    if (action) return;
    setAction(true); setError("");
    try {
      if (!(await chatAllowed(client, profile.id))) throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้");
      const id = await getOrCreateConversation(client, profile.id);
      router.push(`/chat/${id}?user=${encodeURIComponent(profile.id)}`);
    } catch (e) { setError(e instanceof Error ? e.message : "เปิด Chat ไม่สำเร็จ"); }
    finally { setAction(false); }
  };

  const block = async () => {
    if (!window.confirm(`บล็อก @${profile.username}?`)) return;
    setAction(true);
    try { const result = await client.rpc("block_user", { p_target_user_id: profile.id }); if (result.error) throw result.error; await load(); }
    catch { setError("บล็อกไม่สำเร็จ"); } finally { setAction(false); }
  };
  const unblock = async () => {
    setAction(true);
    try { const result = await client.rpc("unblock_user", { p_target_user_id: profile.id }); if (result.error) throw result.error; await load(); }
    catch { setError("ปลดบล็อกไม่สำเร็จ"); } finally { setAction(false); }
  };
  const toggleMute = async () => {
    setAction(true);
    try {
      const result = summary.muted
        ? await client.from("mutes").delete().eq("muter_id", userId).eq("muted_id", profile.id)
        : await client.from("mutes").insert({ muter_id: userId, muted_id: profile.id });
      if (result.error) throw result.error;
      await load();
    } catch { setError("อัปเดตการปิดเสียงไม่สำเร็จ"); } finally { setAction(false); }
  };

  if (editing && own) {
    return <AppChrome title="แก้ไขโปรไฟล์" userId={userId} backHref={`/profile/${userId}`}><EditProfile client={client} userId={userId} summary={summary} onDone={() => { setEditing(false); void load(); }} /></AppChrome>;
  }

  return (
    <AppChrome title={own ? "โปรไฟล์ของฉัน" : `@${profile.username}`} userId={userId} backHref={own ? "/" : "/search"} actions={own ? <SettingsLink /> : <MoreHorizontal size={22} />}>
      <section className="profile-route">
        <div className="profile-cover">{profile.cover_url ? <img src={profile.cover_url} alt="" /> : null}</div>
        <div className="profile-header-row"><Avatar src={profile.avatar_url} label={profile.username} size={88} /><div className="profile-actions">{own ? <button className="route-pill soft" type="button" onClick={() => setEditing(true)}>แก้ไขโปรไฟล์</button> : summary.blocked ? <button className="route-pill soft" disabled={action} type="button" onClick={() => void unblock()}>ปลดบล็อก</button> : <><button className={`route-pill ${summary.following || summary.requested ? "soft" : ""}`} disabled={action || summary.blockedBy} type="button" onClick={() => void follow()}>{summary.following ? "กำลังติดตาม" : summary.requested ? "ขอติดตามแล้ว" : "ติดตาม"}</button><button className="route-square-button" disabled={action || summary.blockedBy} type="button" aria-label="ส่งข้อความ" onClick={() => void startChat()}><MessageCircle size={19} /></button></>}</div></div>
        <div className="profile-copy"><h2>{name}{profile.is_verified ? <span className="route-verified">✓</span> : null}</h2><p className="profile-username">@{profile.username}</p>{profile.bio ? <p>{profile.bio}</p> : null}</div>
        <div className="profile-stats"><span><b>{summary.followingCount.toLocaleString("th-TH")}</b> กำลังติดตาม</span><span><b>{summary.followerCount.toLocaleString("th-TH")}</b> ผู้ติดตาม</span></div>
        {!own && !summary.blocked && !summary.blockedBy ? <div className="profile-secondary-actions"><button type="button" disabled={action} onClick={() => void toggleMute()}>{summary.muted ? "เปิดเสียง" : "ปิดเสียง"}</button><button type="button" disabled={action} onClick={() => void block()}>บล็อก</button></div> : null}
        {summary.blockedBy ? <p className="route-notice">คุณไม่สามารถดูบัญชีนี้ได้</p> : null}
        {!summary.blockedBy && profile.is_private && !own && !summary.following ? <p className="route-notice">บัญชีนี้เป็นส่วนตัว ติดตามเพื่อดูโพสต์ของบัญชีนี้</p> : null}
        {error ? <p className="route-error">{error}</p> : null}
      </section>
      {!summary.blockedBy ? <><div className="route-tabs profile-tabs"><button type="button" className={tab === "posts" ? "active" : ""} onClick={() => setTab("posts")}>โพสต์</button><button type="button" className={tab === "redrops" ? "active" : ""} onClick={() => setTab("redrops")}>รีโพสต์</button><button type="button" className={tab === "likes" ? "active" : ""} onClick={() => setTab("likes")}>ถูกใจ</button></div><ProfileFeed client={client} profileId={profileId} kind={tab} /></> : null}
    </AppChrome>
  );
}

export function ProfileRoute({ profileId }: { profileId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ProfileInner client={client} userId={userId} profileId={profileId} />}</DeveloperRouteGate>;
}

export function ProfileSlugRoute({ username }: { username: string }) {
  const router = useRouter();
  const [message, setMessage] = useState("กำลังเปิดโปรไฟล์…");
  return (
    <DeveloperRouteGate>{({ client, userId }) => {
      void client.from("profiles").select("id").eq("username", username).maybeSingle().then(({ data, error }) => {
        if (error || !data) setMessage("ไม่พบโปรไฟล์");
        else router.replace(`/profile/${data.id}`);
      });
      return <AppChrome title={`@${username}`} userId={userId} backHref="/"><EmptyState>{message}</EmptyState></AppChrome>;
    }}</DeveloperRouteGate>
  );
}
