"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState, type TouchEvent } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, DropPreviewCard, EmptyState } from "@/components/phase3-ui";
import { ProfileRecommendations } from "@/components/profile-recommendations";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { followButtonLabel } from "@/components/ui/follow-button-label";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { WynosShareIcon } from "@/components/ui/wynos-share-icon";
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
import { haptic } from "@/lib/haptics";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { normalizeExternalUrl } from "@/lib/external-link";
import { shareOrCopyLink } from "@/lib/share";
import { triggerRouteRefresh, useRouteRefreshListener } from "@/components/route-refresh-runtime";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";
import {
  canViewProfileLikes,
  chatAllowed,
  fetchProfileDrops,
  fetchProfileLikedDrops,
  fetchProfileSummary,
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

// Order matches the tab buttons rendered below — swiping right/left moves
// to the previous/next entry in this array, same convention as Home's
// HOME_FEED_MODES (components/home/home-tabs.tsx).
const PROFILE_TABS = ["posts", "redrops", "likes"] as const;

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
  // Also the pull-to-refresh trigger now (see ProfileInner): that gesture's
  // touch handlers moved up to cover the whole page, not just this feed, so
  // it reaches ProfileFeed the same way the bottom-nav tap-refresh already
  // does — through this existing pub/sub instead of a local hook instance.
  useRouteRefreshListener(useCallback(() => { void load(0, false); }, [load]));

  return loading && !rows.length ? <FeedSkeleton items={2} />
    : !allowed ? <EmptyState>เจ้าของบัญชีจำกัดผู้ที่เห็นรายการที่ถูกใจ</EmptyState>
    : !rows.length ? <EmptyState>{kind === "posts" ? "ยังไม่มีโพสต์" : kind === "redrops" ? "ยังไม่มีรีโพสต์" : "ยังไม่มีสิ่งที่ถูกใจ"}</EmptyState>
    : <div className="profile-feed-list">{rows.map((row) => <DropPreviewCard row={row} homeParity key={`${row.id}:${row.redrop_id ?? "plain"}`} />)}{hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}</div>;
}

function formatWebsiteLabel(url: string): string {
  try {
    const parsed = new URL(url);
    return `${parsed.hostname}${parsed.pathname !== "/" ? parsed.pathname : ""}`.replace(/\/$/, "");
  } catch {
    return url;
  }
}

function EditProfile({ client, userId, summary, onDone }: { client: SupabaseClient; userId: string; summary: ProfileSummary; onDone: () => void }) {
  const profile = summary.profile;
  const [displayName, setDisplayName] = useState(profile.display_name ?? "");
  const [username, setUsername] = useState(profile.username);
  const [bio, setBio] = useState(profile.bio ?? "");
  const [website, setWebsite] = useState(profile.social_links?.website ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [avatar, setAvatar] = useState(profile.avatar_url);
  const [cover, setCover] = useState(profile.cover_url);
  const [photoMenu, setPhotoMenu] = useState<"avatar" | "cover" | null>(null);
  const selectedKind = useRef<"avatar" | "cover">("avatar");
  const libraryInput = useRef<HTMLInputElement>(null);
  const cameraInput = useRef<HTMLInputElement>(null);
  const filesInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!photoMenu) return;
    const dismiss = (e: KeyboardEvent) => { if (e.key === "Escape") setPhotoMenu(null); };
    document.addEventListener("keydown", dismiss);
    return () => document.removeEventListener("keydown", dismiss);
  }, [photoMenu]);

  const chooseSource = (source: "library" | "camera" | "files") => {
    if (!photoMenu || saving) return;
    selectedKind.current = photoMenu;
    setPhotoMenu(null);
    // Keep click synchronous with the user gesture for the iOS image picker.
    (source === "library" ? libraryInput : source === "camera" ? cameraInput : filesInput).current?.click();
  };
  const uploadImage = async (file?: File) => {
    if (!file || saving) return;
    if (file.size > 10 * 1024 * 1024) { setError("รูปภาพต้องมีขนาดไม่เกิน 10MB"); return; }
    if (file.type && !file.type.startsWith("image/")) { setError("กรุณาเลือกไฟล์รูปภาพ"); return; }
    const kind = selectedKind.current;
    setSaving(true); setError("");
    try {
      const url = await uploadProfileImage(client, userId, kind, file);
      if (kind === "avatar") setAvatar(url);
      else setCover(url);
    } catch (e) { setError(e instanceof Error ? e.message : "อัปโหลดรูปไม่สำเร็จ"); }
    finally { setSaving(false); }
  };
  const removeImage = async (kind: "avatar" | "cover") => {
    setPhotoMenu(null);
    if (saving || !window.confirm(kind === "avatar" ? "ลบรูปโปรไฟล์?" : "ลบรูปหน้าปก?")) return;
    setSaving(true); setError("");
    try {
      await removeProfileImage(client, userId, kind);
      if (kind === "avatar") setAvatar(null);
      else setCover(null);
    } catch (e) { setError(e instanceof Error ? e.message : "ลบรูปไม่สำเร็จ"); }
    finally { setSaving(false); }
  };
  const save = async () => {
    if (!displayName.trim() && !profile.display_name) { setError("กรุณาใส่ชื่อที่แสดง"); return; }
    const normalizedWebsite = normalizeExternalUrl(website);
    if (website.trim() && !normalizedWebsite) { setError("ลิงก์เว็บไซต์ไม่ถูกต้อง"); return; }
    setSaving(true); setError("");
    try {
      if (username.trim() !== profile.username) await updateUsername(client, userId, username);
      const nextSocialLinks = { ...(profile.social_links ?? {}) };
      if (normalizedWebsite) nextSocialLinks.website = normalizedWebsite;
      else delete nextSocialLinks.website;
      await updateProfileBasics(client, userId, { displayName, bio, socialLinks: nextSocialLinks });
      onDone();
    } catch (e) { setError(e instanceof Error ? e.message : "บันทึกไม่สำเร็จ"); }
    finally { setSaving(false); }
  };
  const pickerChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    void uploadImage(file);
  };

  return (
    <div className="wyn-profile-edit wyn-profile-edit-v2">
      <div className="wyn-profile-edit-cover">
        {cover ? <Image src={cover} alt="รูปหน้าปก" fill sizes="(max-width: 680px) 100vw, 680px" unoptimized /> : null}
        <button type="button" className="wyn-profile-edit-cover-camera" aria-label="เปลี่ยนรูปหน้าปก" title="จัดการรูปหน้าปก" disabled={saving} onClick={() => setPhotoMenu("cover")}><WynosIcon name="camera" size={21} strokeWidth={2} /></button>
      </div>
      <div className="wyn-profile-edit-avatar">
        <div className="wyn-profile-edit-avatar-frame">
          <Avatar src={avatar} label={username} size={96} />
          <button type="button" className="wyn-profile-edit-avatar-camera" aria-label="เปลี่ยนรูปโปรไฟล์" title="จัดการรูปโปรไฟล์" disabled={saving} onClick={() => setPhotoMenu("avatar")}><WynosIcon name="camera" size={18} strokeWidth={2} /></button>
        </div>
        <div className="wyn-profile-edit-avatar-copy"><strong>รูปโปรไฟล์</strong><small>รองรับไฟล์ JPG, PNG, HEIC ขนาดไม่เกิน 10MB</small></div>
      </div>
      <input ref={libraryInput} type="file" accept="image/*" aria-label="คลังรูปภาพ" hidden disabled={saving} onChange={pickerChange} />
      <input ref={cameraInput} type="file" accept="image/*" capture="environment" aria-label="ถ่ายภาพ" hidden disabled={saving} onChange={pickerChange} />
      <input ref={filesInput} type="file" accept="image/*,.heic,.heif" aria-label="ไฟล์ภาพ" hidden disabled={saving} onChange={pickerChange} />
      <section className="wyn-profile-edit-fields" aria-label="ข้อมูลโปรไฟล์">
        <h2>ข้อมูลโปรไฟล์</h2>
        <label className="route-field"><span>ชื่อที่แสดง</span><input value={displayName} maxLength={50} onChange={(e) => setDisplayName(e.target.value)} /></label>
        <label className="route-field"><span>ชื่อผู้ใช้</span><input value={"@" + username} autoCapitalize="none" maxLength={31} onChange={(e) => setUsername(e.target.value.replace(/^@+/, "").replace(/[^a-zA-Z0-9_.]/g, ""))} /></label>
        <label className="route-field wyn-profile-edit-bio"><span>คำอธิบายตัวเอง</span><textarea value={bio} maxLength={300} aria-describedby="wyn-profile-bio-counter" onChange={(e) => setBio(e.target.value)} /><small id="wyn-profile-bio-counter">{bio.length}/300</small></label>
        <label className="route-field"><span>เว็บไซต์ภายนอก</span><input type="text" inputMode="url" autoCapitalize="none" autoCorrect="off" value={website} maxLength={300} placeholder="example.com" onChange={(e) => setWebsite(e.target.value)} /></label>
      </section>
      {error ? <p className="route-error wyn-profile-edit-error" role="alert">{error}</p> : null}
      <div className="route-action-row wyn-profile-edit-footer">
        <button className="route-secondary" type="button" disabled={saving} onClick={onDone}>ยกเลิก</button>
        <button className="route-primary" type="button" disabled={saving} onClick={() => void save()}>{saving ? "กำลังบันทึก…" : "บันทึก"}</button>
      </div>
      {photoMenu ? <div className="route-modal-backdrop wyn-profile-photo-backdrop" role="presentation" onClick={() => setPhotoMenu(null)}>
        <section className="route-modal wyn-profile-photo-sheet" role="dialog" aria-modal="true" aria-label={photoMenu === "avatar" ? "จัดการรูปโปรไฟล์" : "จัดการรูปหน้าปก"} onClick={(event) => event.stopPropagation()}>
          <header><strong>{photoMenu === "avatar" ? "รูปโปรไฟล์" : "รูปหน้าปก"}</strong><button className="wyn-photo-sheet-close" type="button" aria-label="ปิด" onClick={() => setPhotoMenu(null)}><WynosIcon name="close" size={20} /></button></header>
          <button type="button" onClick={() => chooseSource("library")}><WynosIcon name="image" size={22} />คลังรูปภาพ</button>
          <button type="button" onClick={() => chooseSource("camera")}><WynosIcon name="camera" size={22} />ถ่ายภาพ</button>
          <button type="button" onClick={() => chooseSource("files")}><WynosIcon name="fileText" size={22} />ไฟล์ภาพ</button>
          {(photoMenu === "avatar" ? avatar : cover) ? <button type="button" className="wyn-photo-sheet-danger" onClick={() => void removeImage(photoMenu)}><WynosIcon name="trash" size={22} />{photoMenu === "avatar" ? "ลบรูปโปรไฟล์" : "ลบรูปหน้าปก"}</button> : null}
          <button type="button" className="wyn-photo-sheet-cancel" onClick={() => setPhotoMenu(null)}>ยกเลิก</button>
        </section>
      </div> : null}
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
  // Horizontal tab-swipe gesture between โพสต์/รีโพสต์/ถูกใจ — mirrors Home's
  // own tab-swipe (components/home/home-screen.tsx) so both feel the same.
  // Independent from the pull-to-refresh touch handlers below (lib/use-
  // pull-to-refresh.ts): that hook already no-ops for horizontal-dominant
  // drags, so layering this on a wrapper div around <ProfileFeed> (touch
  // events bubble up through it) needs no coordination.
  const swipeStart = useRef<{ x: number; y: number } | null>(null);
  const [slideStyle, setSlideStyle] = useState<{ transform: string; transition: string }>({
    transform: "translateX(0px)",
    transition: "none",
  });
  // GA (2026-09-20, Founder decision): was staged-rollout-gated to
  // developer accounts (WYN-125/WYN-182) — Founder asked to widen it to
  // everyone. Lives here (not inside ProfileFeed, its original home) and
  // its touch handlers wrap the *entire* page body below — Profile's
  // header/bio/stats/tabs are much taller than Home's compact header, so
  // scoping the gesture to just the feed area (as it originally was,
  // mirroring Home) left most of a scrolled-to-top screen unable to start
  // a pull at all. `triggerRouteRefresh()` reaches ProfileFeed's `load`
  // through the same pub/sub the bottom nav's tap-to-refresh already uses.
  const pull = usePullToRefresh({ enabled: true, onRefresh: () => triggerRouteRefresh() });
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
    const wasFollowerCount = summary.followerCount;
    const optimisticNext = predictFollowState({ currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate: profile.is_private });
    if (!wasFollowing) haptic();
    setAction(true); setError("");
    patchSummary((current) => ({
      ...current,
      following: optimisticNext === "following",
      requested: optimisticNext === "requested",
      followerCount: Math.max(0, current.followerCount + (optimisticNext === "following" ? 1 : 0) - (wasFollowing ? 1 : 0)),
    }));
    try { await toggleAuthorFollow(client, userId, profile.id, { currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate: profile.is_private }); }
    catch (e) {
      // Full rollback -- the previous version only restored
      // following/requested and left followerCount at its already-mutated
      // (wrong) value on failure.
      patchSummary((current) => ({ ...current, following: wasFollowing, requested: wasRequested, followerCount: wasFollowerCount }));
      setError(e instanceof Error ? e.message : "ติดตามไม่สำเร็จ");
      showToast("ติดตามไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
    finally { setAction(false); }
  };
  const startChat = async () => {
    if (action) return;
    setAction(true); setError("");
    // WYN-185 item 10: open the composer first -- the conversation/Message
    // Request itself is only created once the user actually sends, inside
    // the composer's own submit(), not from tapping "ส่งข้อความ" here.
    try { if (!(await chatAllowed(client, profile.id))) throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้"); router.push(`/chat/new?user=${encodeURIComponent(profile.id)}`); }
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
    await shareOrCopyLink({ title: name, text: `@${profile.username}`, url }, showToast);
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
  const onTabSwipeStart = (event: TouchEvent<HTMLDivElement>) => {
    const touch = event.changedTouches[0];
    if (touch) swipeStart.current = { x: touch.clientX, y: touch.clientY };
  };
  const onTabSwipeMove = (event: TouchEvent<HTMLDivElement>) => {
    const start = swipeStart.current;
    const touch = event.changedTouches[0];
    if (!start || !touch) return;
    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    if (Math.abs(deltaX) > 8 && Math.abs(deltaX) > Math.abs(deltaY)) {
      const index = PROFILE_TABS.indexOf(tab);
      const atStart = index === 0 && deltaX > 0;
      const atEnd = index === PROFILE_TABS.length - 1 && deltaX < 0;
      const dragX = atStart || atEnd ? deltaX * 0.35 : deltaX;
      setSlideStyle({ transform: `translateX(${dragX}px)`, transition: "none" });
    }
  };
  const onTabSwipeEnd = (event: TouchEvent<HTMLDivElement>) => {
    const start = swipeStart.current;
    const touch = event.changedTouches[0];
    swipeStart.current = null;
    if (!start || !touch) return;
    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    if (Math.abs(deltaY) >= Math.abs(deltaX) || Math.abs(deltaX) < 55) {
      setSlideStyle({ transform: "translateX(0px)", transition: "transform 200ms ease-out" });
      return;
    }
    const index = PROFILE_TABS.indexOf(tab);
    const next = deltaX < 0
      ? Math.min(PROFILE_TABS.length - 1, index + 1)
      : Math.max(0, index - 1);
    setSlideStyle({ transform: "translateX(0px)", transition: "transform 200ms ease-out" });
    setTab(PROFILE_TABS[next]);
  };
  const onTabSwipeCancel = () => {
    swipeStart.current = null;
    setSlideStyle({ transform: "translateX(0px)", transition: "transform 200ms ease-out" });
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
    <PullToRefreshIndicator pull={pull} topOffset="58px" refreshingLabel="กำลังรีเฟรชโปรไฟล์" />
    <div className="wyn-profile-beta1" onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
    <div className="wyn-profile-hero">
      <div className="wyn-profile-cover">
        {profile.cover_url && normalizeExternalUrl(profile.cover_url)
          ? <Image src={normalizeExternalUrl(profile.cover_url) ?? ""} alt="" fill priority unoptimized sizes="(max-width: 680px) 100vw, 680px" />
          : <><div className="wyn-profile-cover-planet" aria-hidden="true" /><div className="wyn-profile-cover-wordmark" aria-hidden="true"><strong>W Y N O S</strong><small>A BETTER<br />TOMORROW TOGETHER</small></div></>}
      </div>
      <header className="wyn-profile-topbar">
        <button type="button" aria-label="ย้อนกลับ" onClick={() => router.back()}><WynosIcon name="back" size={25} strokeWidth={2.4} /></button>
        <button type="button" aria-label={own ? "ตัวเลือกของฉัน" : "เพิ่มเติม"} onClick={() => setMoreOpen(true)}><WynosIcon name="more" size={26} strokeWidth={2.2} /></button>
      </header>
    </div>
    <section className="wyn-profile-header">
      <div className="wyn-profile-intro">
        <span className="wyn-profile-hero-avatar"><Avatar src={profile.avatar_url} label={profile.username} size={90} /></span>
        <div className="wyn-profile-copy">
          <div className="wyn-profile-name"><span className="wyn-profile-display-name">{name}</span>{profile.is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}</div>
          <div className="wyn-profile-handle">@{profile.username}</div>
        </div>
        {own ? <div className="wyn-profile-actions is-own">
          <button className="wyn-profile-action-primary" type="button" aria-label="แก้ไขโปรไฟล์" title="แก้ไขโปรไฟล์" onClick={() => setEditing(true)}><WynosIcon name="pencil" size={21} strokeWidth={1.9} /></button>
          <button className="wyn-profile-action-secondary" type="button" aria-label="แชร์โปรไฟล์" title="แชร์โปรไฟล์" onClick={() => void share()}><WynosShareIcon size={22} /></button>
        </div> : null}
      </div>
      <div className="wyn-profile-details">
        {profile.bio ? <p className="wyn-profile-bio">{profile.bio}</p> : null}
        {(() => {
          const safeWebsite = profile.social_links?.website ? normalizeExternalUrl(profile.social_links.website) : null;
          return safeWebsite ? <a className="wyn-profile-website" href={safeWebsite} target="_blank" rel="noopener noreferrer nofollow ugc"><WynosIcon name="link" size={19} strokeWidth={2.1} />{formatWebsiteLabel(safeWebsite)}</a> : null;
        })()}
        {!summary.blockedBy ? <div className="wyn-profile-stats">
          <button type="button"><b>{summary.followingCount.toLocaleString("th-TH")}</b> กำลังติดตาม</button>
          <button type="button"><b>{summary.followerCount.toLocaleString("th-TH")}</b> ผู้ติดตาม</button>
        </div> : null}
      </div>
      {!own && !summary.blocked && !summary.blockedBy ? <div className="wyn-profile-actions is-visitor">
        <button className={`wyn-profile-action-primary ${summary.following || summary.requested ? "soft" : ""}`} disabled={action} type="button" onClick={() => void follow()}>{followButtonLabel({ busy: action, following: summary.following, requested: summary.requested })}</button>
        <button className="wyn-profile-action-secondary" disabled={action} type="button" onClick={() => void startChat()}><WynosIcon name="send" size={18} strokeWidth={2} /> ส่งข้อความ</button>
      </div> : null}
      {!own && summary.blocked ? <div className="wyn-profile-actions is-visitor"><button className="wyn-profile-action-primary soft" disabled={action} type="button" onClick={() => void unblock()}>ปลดบล็อก</button></div> : null}
      {summary.blockedBy ? <p className="route-notice">ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้</p> : null}
      {!summary.blockedBy && profile.is_private && !own && !summary.following ? <p className="route-notice">บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู {name}</p> : null}
      {error ? <p className="route-error">{error}</p> : null}
    </section>
    {!own && !summary.blockedBy ? <ProfileRecommendations client={client} userId={userId} viewedProfileId={profileId} /> : null}
    {!summary.blockedBy ? <><div className="route-tabs wyn-profile-tabs"><button type="button" className={tab === "posts" ? "active" : ""} onClick={() => setTab("posts")}>โพสต์</button><button type="button" className={tab === "redrops" ? "active" : ""} onClick={() => setTab("redrops")}>รีโพสต์</button><button type="button" className={tab === "likes" ? "active" : ""} onClick={() => setTab("likes")}>ถูกใจ</button></div><div style={slideStyle} onTouchStart={onTabSwipeStart} onTouchMove={onTabSwipeMove} onTouchEnd={onTabSwipeEnd} onTouchCancel={onTabSwipeCancel}><ProfileFeed client={client} profileId={profileId} kind={tab} /></div></> : null}
    </div>
    {accountSwitcherOpen ? <div className="route-modal-backdrop profile-account-switcher-backdrop" role="presentation" onClick={() => setAccountSwitcherOpen(false)}><section className="route-modal profile-account-switcher-sheet" role="dialog" aria-modal="true" aria-label="สลับบัญชี" onClick={(e) => e.stopPropagation()}><header><div><strong>สลับบัญชี</strong><small>{savedAccounts.length}/{MAX_SAVED_ACCOUNTS} บัญชี</small></div><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setAccountSwitcherOpen(false)}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header><div className="profile-account-list">{savedAccounts.map((account) => <div className={`profile-account-row ${account.userId === userId ? "is-current" : ""}`} key={account.userId}><button className="profile-account-select" type="button" disabled={action || managingAccounts} onClick={() => switchToAccount(account)}><Avatar src={account.avatarUrl} label={account.username} size={44} /><span><strong>{account.displayName?.trim() || account.username}</strong><small>@{account.username}</small></span></button>{account.userId === userId ? <WynosIcon name="checkCircle" size={21} strokeWidth={2} /> : managingAccounts ? <button className="profile-account-remove" type="button" onClick={() => removeAccountFromSwitcher(account)}>นำออก</button> : null}</div>)}</div>{accountSwitcherError ? <p className="profile-account-error">{accountSwitcherError}</p> : null}<div className="profile-account-switcher-actions"><button className="profile-account-use-other" type="button" disabled={action} onClick={() => void addAnotherAccount()}>เข้าสู่ระบบบัญชีอื่น</button><button className="profile-account-manage" type="button" disabled={savedAccounts.length <= 1} onClick={() => setManagingAccounts((value) => !value)}>{managingAccounts ? "เสร็จ" : "จัดการบัญชี"}</button></div></section></div> : null}
    {moreOpen ? <div className="route-modal-backdrop" role="presentation" onClick={() => setMoreOpen(false)}><section className="route-modal profile-more-sheet" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>ตัวเลือกโปรไฟล์</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setMoreOpen(false)}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header>{own ? <><button type="button" onClick={() => { setMoreOpen(false); openAccountSwitcher(); }}>สลับบัญชี</button><button type="button" onClick={() => { setMoreOpen(false); router.push("/settings"); }}>ตั้งค่า</button></> : null}<button type="button" onClick={() => { setMoreOpen(false); void share(); }}>แชร์โปรไฟล์</button>{!summary.blocked && !summary.blockedBy ? <button type="button" disabled={action} onClick={() => void toggleMute()}>{summary.muted ? "เปิดเสียง" : "ปิดเสียง"}</button> : null}{summary.blocked ? <button type="button" disabled={action} onClick={() => void unblock()}>ปลดบล็อก</button> : !summary.blockedBy ? <button className="danger" type="button" disabled={action} onClick={() => void block()}>บล็อก</button> : null}</section></div> : null}
    <Toast message={toastMessage} />
  </AppChrome>;
}

export function ProfileRoute({ profileId }: { profileId: string }) { return <DeveloperRouteGate>{({ client, userId }) => <ProfileInner client={client} userId={userId} profileId={profileId} />}</DeveloperRouteGate>; }
