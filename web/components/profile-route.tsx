"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, DropPreviewCard, EmptyState } from "@/components/phase3-ui";
import { ProfileRecommendations } from "@/components/profile-recommendations";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { FeedSkeleton, ProfileSkeleton } from "@/components/ui/skeleton";
import { Toast, useToast } from "@/components/ui/toast";
import {
  MAX_SAVED_ACCOUNTS,
  activateSavedAccount,
  listSavedAccounts,
  registerCurrentAccount,
  removeSavedAccount,
  type SavedAccount,
} from "@/lib/account-registry";
import { predictFollowState, toggleAuthorFollow } from "@/lib/home-actions";
import type { HomeFeedRow } from "@/lib/feed";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { useRouteRefreshListener } from "@/components/route-refresh-runtime";
import {
  canViewProfileLikes,
  chatAllowed,
  fetchProfileDrops,
  fetchProfileLikedDrops,
  fetchProfileSummary,
  getOrCreateConversation,
  profileLabel,
  removeProfileImage,
  updateProfileBasics,
  updateUsername,
  uploadProfileImage,
  type ProfileSummary,
} from "@/lib/phase3-data";

async function fetchRedrops(client: SupabaseClient, userId: string, page: number): Promise<HomeFeedRow[]> {
  const from = page * 10;
  const result = await client.from("home_feed").select("*").eq("redropper_id", userId).neq("content_type", "pop").order("created_at", { ascending: false }).range(from, from + 9);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as HomeFeedRow[];
}

type ProfileFeedSnapshot = { rows: HomeFeedRow[]; page: number; hasMore: boolean; allowed: boolean };

function ProfileFeed({ client, profileId, kind }: { client: SupabaseClient; profileId: string; kind: "posts" | "redrops" | "likes" }) {
  const cacheKey = `profile-feed:${profileId}:${kind}`;
  const cached = getMountCache<ProfileFeedSnapshot>(cacheKey);
  const [rows, setRows] = useState<HomeFeedRow[]>(cached?.rows ?? []);
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(!cached);
  const [allowed, setAllowed] = useState(cached?.allowed ?? true);
  const allowedRef = useRef(allowed);
  useEffect(() => { allowedRef.current = allowed; }, [allowed]);
  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      let next: HomeFeedRow[];
      if (kind === "posts") next = await fetchProfileDrops(client, profileId, nextPage);
      else if (kind === "redrops") next = await fetchRedrops(client, profileId, nextPage);
      else next = await fetchProfileLikedDrops(client, profileId, nextPage);
      if (kind === "likes" && nextPage === 0 && !next.length) { allowedRef.current = await canViewProfileLikes(client, profileId); setAllowed(allowedRef.current); }
      const nextHasMore = next.length === (kind === "redrops" ? 10 : 21);
      setRows((current) => {
        const combined = append ? [...current, ...next] : next;
        setMountCache(cacheKey, { rows: combined, page: nextPage, hasMore: nextHasMore, allowed: allowedRef.current });
        return combined;
      });
      setPage(nextPage);
      setHasMore(nextHasMore);
    } catch { setRows([]); }
    finally { setLoading(false); }
  }, [client, kind, profileId, cacheKey]);
  useEffect(() => { setAllowed(true); void load(0, false); }, [load]);
  useRouteRefreshListener(useCallback(() => { void load(0, false); }, [load]));
  if (loading && !rows.length) return <FeedSkeleton items={2} />;
  if (!allowed) return <EmptyState>เจ้าของบัญชีจำกัดผู้ที่เห็นรายการที่ถูกใจ</EmptyState>;
  if (!rows.length) return <EmptyState>{kind === "posts" ? "ยังไม่มี Post เลย" : kind === "redrops" ? "ยังไม่มีรีโพสต์" : "ยังไม่มีสิ่งที่ถูกใจ"}</EmptyState>;
  return <div className="profile-feed-list">{rows.map((row) => <DropPreviewCard row={row} homeParity key={`${row.id}:${row.redrop_id ?? "plain"}`} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

function EditProfile({ client, userId, summary, onDone }: { client: SupabaseClient; userId: string; summary: ProfileSummary; onDone: () => void }) {
  const profile = summary.profile;
  const [displayName, setDisplayName] = useState(profile.display_name ?? "");
  const [username, setUsername] = useState(profile.username);
  const [bio, setBio] = useState(profile.bio ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [avatar, setAvatar] = useState(profile.avatar_url);
  const image = async (file?: File) => {
    if (!file) return;
    setSaving(true); setError("");
    try { setAvatar(await uploadProfileImage(client, userId, "avatar", file)); }
    catch (e) { setError(e instanceof Error ? e.message : "อัปโหลดรูปไม่สำเร็จ"); }
    finally { setSaving(false); }
  };
  const removeImage = async () => {
    setSaving(true); setError("");
    try { await removeProfileImage(client, userId); setAvatar(null); }
    catch (e) { setError(e instanceof Error ? e.message : "ลบรูปโปรไฟล์ไม่สำเร็จ"); }
    finally { setSaving(false); }
  };
  const save = async () => {
    if (!displayName.trim() && !profile.display_name) { setError("กรุณาใส่ชื่อที่แสดง"); return; }
    setSaving(true); setError("");
    try { if (username.trim() !== profile.username) await updateUsername(client, userId, username); await updateProfileBasics(client, userId, { displayName, bio }); onDone(); }
    catch (e) { setError(e instanceof Error ? e.message : "บันทึกไม่สำเร็จ"); }
    finally { setSaving(false); }
  };
  return (
    <div className="wyn-profile-edit">
      <div className="wyn-profile-edit-avatar">
        <Avatar src={avatar} label={username} size={84} />
        <div className="wyn-profile-edit-avatar-actions">
          <label><WynosIcon name="camera" size={16} strokeWidth={2} /> รูปโปรไฟล์<input type="file" accept="image/*" hidden disabled={saving} onChange={(e) => void image(e.target.files?.[0])} /></label>
          {avatar ? <button type="button" className="wyn-profile-edit-avatar-remove" disabled={saving} onClick={() => void removeImage()}>ลบรูปโปรไฟล์</button> : null}
        </div>
      </div>
      <label className="route-field"><span>ชื่อที่แสดง</span><input value={displayName} maxLength={50} onChange={(e) => setDisplayName(e.target.value)} /></label>
      <label className="route-field"><span>ชื่อผู้ใช้</span><input value={`@${username}`} autoCapitalize="none" maxLength={31} onChange={(e) => setUsername(e.target.value.replace(/^@+/, "").replace(/[^a-zA-Z0-9_.]/g, ""))} /></label>
      <label className="route-field"><span>คำอธิบายตัวเอง</span><textarea value={bio} maxLength={300} onChange={(e) => setBio(e.target.value)} /></label>
      {error ? <p className="route-error">{error}</p> : null}
      <div className="route-action-row"><button className="route-secondary" type="button" disabled={saving} onClick={onDone}>ยกเลิก</button><button className="route-primary" type="button" disabled={saving} onClick={() => void save()}>{saving ? "กำลังบันทึก…" : "บันทึก"}</button></div>
    </div>
  );
}

function ProfileInner({ client, userId, profileId }: { client: SupabaseClient; userId: string; profileId: string }) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const profileQueryKey = ["profile-summary", profileId, userId] as const;
  const { data: summary, isLoading: loading, error: loadError, refetch } = useQuery({
    queryKey: profileQueryKey,
    queryFn: () => fetchProfileSummary(client, userId, profileId),
  });
  const [action, setAction] = useState(false);
  const [editing, setEditing] = useState(false);
  const [tab, setTab] = useState<"posts" | "redrops" | "likes">("posts");
  const [error, setError] = useState("");
  const [moreOpen, setMoreOpen] = useState(false);
  const [accountSwitcherOpen, setAccountSwitcherOpen] = useState(false);
  const [savedAccounts, setSavedAccounts] = useState<SavedAccount[]>([]);
  const [managingAccounts, setManagingAccounts] = useState(false);
  const [accountSwitcherError, setAccountSwitcherError] = useState("");
  const own = profileId === userId;
  const { toastMessage, showToast } = useToast();
  const load = useCallback(async () => { await refetch(); }, [refetch]);
  if (loading) return <AppChrome title="โปรไฟล์" userId={userId} backHref="/"><ProfileSkeleton /></AppChrome>;
  if (!summary) return <AppChrome title="โปรไฟล์" userId={userId} backHref="/"><EmptyState>{loadError instanceof Error ? loadError.message : "ไม่พบโปรไฟล์"}</EmptyState></AppChrome>;
  const profile = summary.profile;
  const name = profileLabel(profile);
  const patchSummary = (updater: (current: ProfileSummary) => ProfileSummary) => queryClient.setQueryData<ProfileSummary | null>(
    profileQueryKey,
    (current) => current ? updater(current) : current,
  );
  const follow = async () => {
    if (own || action) return;
    if (summary.requested && profile.is_private && !window.confirm(`ยกเลิกคำขอติดตาม @${profile.username}?`)) return;
    const wasFollowing = summary.following;
    const wasRequested = summary.requested;
    const optimisticNext = predictFollowState({ currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate: profile.is_private });
    setAction(true); setError("");
    patchSummary((current) => ({
      ...current,
      following: optimisticNext === "following",
      requested: optimisticNext === "requested",
      followerCount: Math.max(0, current.followerCount + (optimisticNext === "following" ? 1 : 0) - (wasFollowing ? 1 : 0)),
    }));
    try { await toggleAuthorFollow(client, userId, profile.id, { currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate: profile.is_private }); }
    catch (e) {
      patchSummary((current) => ({ ...current, following: wasFollowing, requested: wasRequested }));
      setError(e instanceof Error ? e.message : "ติดตามไม่สำเร็จ");
      showToast("ติดตามไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
    finally { setAction(false); }
  };
  const startChat = async () => {
    if (action) return;
    setAction(true); setError("");
    try { if (!(await chatAllowed(client, profile.id))) throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้"); const id = await getOrCreateConversation(client, profile.id); router.push(`/chat/${id}?user=${encodeURIComponent(profile.id)}`); }
    catch (e) { setError(e instanceof Error ? e.message : "เปิด Chat ไม่สำเร็จ"); }
    finally { setAction(false); }
  };
  const block = async () => {
    if (!window.confirm(`บล็อก @${profile.username}?`)) return;
    setAction(true);
    try { const result = await client.rpc("block_user", { p_target_user_id: profile.id }); if (result.error) throw result.error; setMoreOpen(false); await load(); }
    catch { setError("บล็อกไม่สำเร็จ"); } finally { setAction(false); }
  };
  const unblock = async () => { setAction(true); try { const result = await client.rpc("unblock_user", { p_target_user_id: profile.id }); if (result.error) throw result.error; setMoreOpen(false); await load(); } catch { setError("ปลดบล็อกไม่สำเร็จ"); } finally { setAction(false); } };
  const toggleMute = async () => {
    setAction(true);
    try { const result = summary.muted ? await client.from("mutes").delete().eq("muter_id", userId).eq("muted_id", profile.id) : await client.from("mutes").insert({ muter_id: userId, muted_id: profile.id }); if (result.error) throw result.error; setMoreOpen(false); await load(); }
    catch { setError("อัปเดตการปิดเสียงไม่สำเร็จ"); } finally { setAction(false); }
  };
  const share = async () => {
    const url = `${window.location.origin}/@${profile.username}`;
    try { if (navigator.share) await navigator.share({ title: name, text: `@${profile.username}`, url }); else await navigator.clipboard.writeText(url); }
    catch (e) { if (e instanceof DOMException && e.name === "AbortError") return; showToast("แชร์ไม่สำเร็จ"); }
  };
  const openAccountSwitcher = () => {
    setManagingAccounts(false);
    setAccountSwitcherError("");
    setSavedAccounts(listSavedAccounts());
    setAccountSwitcherOpen(true);
    void registerCurrentAccount(client).then(() => setSavedAccounts(listSavedAccounts()));
  };
  const switchToAccount = (account: SavedAccount) => {
    if (action || account.userId === userId) { setAccountSwitcherOpen(false); return; }
    setAction(true);
    setAccountSwitcherError("");
    if (!activateSavedAccount(account.userId)) {
      setAction(false);
      setAccountSwitcherError("สลับบัญชีไม่สำเร็จ");
      return;
    }
    window.location.assign("/");
  };
  const addAnotherAccount = async () => {
    if (action) return;
    setAccountSwitcherError("");
    await registerCurrentAccount(client);
    const accounts = listSavedAccounts();
    setSavedAccounts(accounts);
    if (accounts.length >= MAX_SAVED_ACCOUNTS) {
      setAccountSwitcherError(`บันทึกได้สูงสุด ${MAX_SAVED_ACCOUNTS} บัญชีบนอุปกรณ์นี้`);
      return;
    }
    setAccountSwitcherOpen(false);
    router.push("/account/add");
  };
  const removeAccountFromSwitcher = (account: SavedAccount) => {
    if (account.userId === userId) return;
    removeSavedAccount(account.userId);
    setSavedAccounts(listSavedAccounts());
  };
  if (editing && own) {
    const closeEditing = () => { setEditing(false); void load(); };
    // onBack, not backHref: editing is a local view toggle, not a route
    // change — the URL never leaves /profile/{userId}, so a backHref equal
    // to the current pathname would hit AppChrome's same-URL fallback and
    // hard-reload the page instead of just closing the form.
    return <AppChrome title="แก้ไขโปรไฟล์" userId={userId} onBack={closeEditing} showBottomNav={false}><EditProfile client={client} userId={userId} summary={summary} onDone={closeEditing} /></AppChrome>;
  }

  return <AppChrome title="" userId={userId} headerMode="hidden">
    <header className="wyn-profile-topbar">
      <button type="button" aria-label="ย้อนกลับ" onClick={() => router.back()}><WynosIcon name="back" size={24} strokeWidth={2} /></button>
      {own ? (
        <button className="wyn-profile-account-switcher" type="button" aria-label="สลับบัญชี" onClick={openAccountSwitcher}>
          <span>@{profile.username}</span><WynosIcon name="chevronDown" size={18} strokeWidth={2} />
        </button>
      ) : <strong>@{profile.username}</strong>}
      {own
        ? <button type="button" aria-label="ตั้งค่า" onClick={() => router.push("/settings")}><WynosIcon name="settings" size={22} strokeWidth={2} /></button>
        : <button type="button" aria-label="เพิ่มเติม" onClick={() => setMoreOpen(true)}><WynosIcon name="moreVertical" size={22} strokeWidth={2} /></button>}
    </header>
    <section className="wyn-profile-header">
      <div className="wyn-profile-intro">
        <Avatar src={profile.avatar_url} label={profile.username} size={64} />
        <div className="wyn-profile-copy">
          <div className="wyn-profile-name">{name}{profile.is_verified ? <span className="route-verified">✓</span> : null}</div>
          {profile.bio ? <p className="wyn-profile-bio">{profile.bio}</p> : null}
        </div>
      </div>
      {!summary.blockedBy ? (
        <div className="wyn-profile-stats">
          <button type="button"><b>{summary.followingCount.toLocaleString("th-TH")}</b> กำลังติดตาม</button>
          <button type="button"><b>{summary.followerCount.toLocaleString("th-TH")}</b> ผู้ติดตาม</button>
        </div>
      ) : null}
      {own ? (
        <div className="wyn-profile-actions is-own">
          <button className="wyn-profile-action-primary" type="button" onClick={() => setEditing(true)}>แก้ไขโปรไฟล์</button>
          <button className="wyn-profile-action-secondary" type="button" onClick={() => void share()}>แชร์โปรไฟล์</button>
        </div>
      ) : summary.blocked ? (
        <div className="wyn-profile-actions"><button className="wyn-profile-action-primary soft" disabled={action} type="button" onClick={() => void unblock()}>ปลดบล็อก</button></div>
      ) : (
        <div className="wyn-profile-actions">
          <button className={`wyn-profile-action-primary ${summary.following || summary.requested ? "soft" : ""}`} disabled={action || summary.blockedBy} type="button" onClick={() => void follow()}>{summary.following ? "กำลังติดตาม" : summary.requested ? "ขอติดตามแล้ว" : "ติดตาม"}</button>
          <button className="wyn-profile-action-secondary" disabled={action || summary.blockedBy} type="button" onClick={() => void startChat()}><WynosIcon name="send" size={18} strokeWidth={2} /> ส่งข้อความ</button>
        </div>
      )}
      {summary.blockedBy ? <p className="route-notice">ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้</p> : null}
      {!summary.blockedBy && profile.is_private && !own && !summary.following ? <p className="route-notice">บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู {name}</p> : null}
      {error ? <p className="route-error">{error}</p> : null}
    </section>
    {!own && !summary.blockedBy ? <ProfileRecommendations client={client} userId={userId} viewedProfileId={profileId} /> : null}
    {!summary.blockedBy ? <><div className="route-tabs wyn-profile-tabs"><button type="button" className={tab === "posts" ? "active" : ""} onClick={() => setTab("posts")}><WynosIcon name="image" size={20} strokeWidth={2} />สื่อ</button><button type="button" className={tab === "redrops" ? "active" : ""} onClick={() => setTab("redrops")}><WynosIcon name="repost" size={20} strokeWidth={2} />รีโพสต์</button><button type="button" className={tab === "likes" ? "active" : ""} onClick={() => setTab("likes")}><WynosIcon name="like" size={20} strokeWidth={2} />ถูกใจ</button></div><ProfileFeed client={client} profileId={profileId} kind={tab} /></> : null}
    {accountSwitcherOpen ? <div className="route-modal-backdrop profile-account-switcher-backdrop" role="presentation" onClick={() => setAccountSwitcherOpen(false)}><section className="route-modal profile-account-switcher-sheet" role="dialog" aria-modal="true" aria-label="สลับบัญชี" onClick={(e) => e.stopPropagation()}><header><div><strong>สลับบัญชี</strong><small>{savedAccounts.length}/{MAX_SAVED_ACCOUNTS} บัญชี</small></div><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setAccountSwitcherOpen(false)}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header><div className="profile-account-list">{savedAccounts.map((account) => <div className={`profile-account-row ${account.userId === userId ? "is-current" : ""}`} key={account.userId}><button className="profile-account-select" type="button" disabled={action || managingAccounts} onClick={() => switchToAccount(account)}><Avatar src={account.avatarUrl} label={account.username} size={44} /><span><strong>{account.displayName?.trim() || account.username}</strong><small>@{account.username}</small></span></button>{account.userId === userId ? <WynosIcon name="checkCircle" size={21} strokeWidth={2} /> : managingAccounts ? <button className="profile-account-remove" type="button" onClick={() => removeAccountFromSwitcher(account)}>นำออก</button> : null}</div>)}</div>{accountSwitcherError ? <p className="profile-account-error">{accountSwitcherError}</p> : null}<div className="profile-account-switcher-actions"><button className="profile-account-use-other" type="button" disabled={action} onClick={() => void addAnotherAccount()}>เข้าสู่ระบบบัญชีอื่น</button><button className="profile-account-manage" type="button" disabled={savedAccounts.length <= 1} onClick={() => setManagingAccounts((value) => !value)}>{managingAccounts ? "เสร็จ" : "จัดการบัญชี"}</button></div></section></div> : null}
    {moreOpen ? <div className="route-modal-backdrop" role="presentation" onClick={() => setMoreOpen(false)}><section className="route-modal profile-more-sheet" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>ตัวเลือกโปรไฟล์</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setMoreOpen(false)}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header><button type="button" onClick={() => void share()}>แชร์โปรไฟล์</button>{!summary.blocked && !summary.blockedBy ? <button type="button" disabled={action} onClick={() => void toggleMute()}>{summary.muted ? "เปิดเสียง" : "ปิดเสียง"}</button> : null}{summary.blocked ? <button type="button" disabled={action} onClick={() => void unblock()}>ปลดบล็อก</button> : !summary.blockedBy ? <button className="danger" type="button" disabled={action} onClick={() => void block()}>บล็อก</button> : null}</section></div> : null}
    <Toast message={toastMessage} />
  </AppChrome>;
}

export function ProfileRoute({ profileId }: { profileId: string }) { return <DeveloperRouteGate>{({ client, userId }) => <ProfileInner client={client} userId={userId} profileId={profileId} />}</DeveloperRouteGate>; }
