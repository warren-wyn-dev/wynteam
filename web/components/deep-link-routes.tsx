"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { haptic } from "@/lib/haptics";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import {
  addDropComment,
  fetchDropComments,
  loadHomeViewerState,
  toggleDropCommentLike,
  toggleDropLike,
  toggleDropRedrop,
  toggleDropSave,
  type DropCommentRow,
  type HomeViewerState,
} from "@/lib/home-actions";
import {
  fetchClub,
  fetchClubInvite,
  fetchClubPostById,
  fetchDropById,
  type ClubRow,
} from "@/lib/phase3-data";

function DropDetailInner({ client, userId, dropId }: { client: SupabaseClient; userId: string; dropId: string }) {
  const [row, setRow] = useState<HomeFeedRow | null>(null);
  const [viewer, setViewer] = useState<HomeViewerState | null>(null);
  const [comments, setComments] = useState<DropCommentRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const drop = await fetchDropById(client, dropId);
      if (!drop) { setRow(null); return; }
      const [state, firstComments] = await Promise.all([
        loadHomeViewerState(client, userId, [drop]),
        fetchDropComments(client, userId, dropId, 0),
      ]);
      setRow(drop); setViewer(state); setComments(firstComments);
    } catch (e) { setError(e instanceof Error ? e.message : "โหลดโพสต์ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, dropId, userId]);
  useEffect(() => { void load(); }, [load]);

  if (loading) return <AppChrome title="โพสต์" userId={userId} backHref="/"><LoadingState /></AppChrome>;
  if (!row || !viewer) return <AppChrome title="โพสต์" userId={userId} backHref="/"><EmptyState>{error || "ไม่พบโพสต์นี้"}</EmptyState></AppChrome>;
  const liked = viewer.likedDropIds.has(row.id);
  const saved = viewer.savedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const patchSet = (key: "likedDropIds" | "savedDropIds" | "redroppedDropIds", enabled: boolean) => setViewer((current) => {
    if (!current) return current;
    const next = new Set(current[key]);
    if (enabled) next.add(row.id); else next.delete(row.id);
    return { ...current, [key]: next };
  });
  const interact = async (kind: "like" | "save" | "redrop") => {
    try {
      if (kind === "like") { if (!liked) haptic(); patchSet("likedDropIds", !liked); await toggleDropLike(client, userId, row.id, liked); setRow({ ...row, like_count: Math.max(0, (row.like_count ?? 0) + (liked ? -1 : 1)) }); }
      if (kind === "save") { if (!saved) haptic(); patchSet("savedDropIds", !saved); await toggleDropSave(client, userId, row.id, saved); }
      if (kind === "redrop") { patchSet("redroppedDropIds", !redropped); await toggleDropRedrop(client, userId, row.id, redropped); setRow({ ...row, redrop_count: Math.max(0, (row.redrop_count ?? 0) + (redropped ? -1 : 1)) }); }
    } catch { setError("อัปเดตกิจกรรมไม่สำเร็จ"); void load(); }
  };
  const submit = async () => {
    if (!draft.trim() || sending) return;
    setSending(true);
    try { const created = await addDropComment(client, userId, row.id, draft); setComments((current) => [...current, created]); setDraft(""); setRow({ ...row, comment_count: (row.comment_count ?? 0) + 1 }); }
    catch { setError("ส่งความคิดเห็นไม่สำเร็จ"); } finally { setSending(false); }
  };
  const likeComment = async (comment: DropCommentRow) => {
    try { if (!comment.liked_by_me) haptic(); await toggleDropCommentLike(client, userId, comment.id, comment.liked_by_me); setComments((current) => current.map((item) => item.id === comment.id ? { ...item, liked_by_me: !item.liked_by_me, like_count: Math.max(0, item.like_count + (item.liked_by_me ? -1 : 1)) } : item)); }
    catch { setError("ถูกใจความคิดเห็นไม่สำเร็จ"); }
  };

  return (
    <AppChrome title="โพสต์" userId={userId} backHref="/">
      <article className="detail-post">
        <Link className="route-drop-author" href={`/profile/${row.author_id}`}><Avatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} /><span><strong>{authorLabel(row)}</strong><small>@{row.author_username || "wynos"} · {relativeTimeTh(row.created_at)}</small></span></Link>
        {row.caption ? <p className="detail-caption">{row.caption}</p> : null}
        {row.image_url ? <img className="detail-image" src={row.image_url} alt="" loading="lazy" decoding="async" /> : null}
        <div className="detail-actions"><button className={liked ? "active like" : ""} type="button" onClick={() => void interact("like")}><WynosIcon name="like" size={20} strokeWidth={2} fill={liked ? "currentColor" : "none"} /> {row.like_count ?? 0}</button><button className={redropped ? "active" : ""} type="button" onClick={() => void interact("redrop")}><WynosIcon name="repost" size={20} strokeWidth={2} /> {row.redrop_count ?? 0}</button><button className={saved ? "active" : ""} type="button" onClick={() => void interact("save")}><WynosIcon name="bookmark" size={20} strokeWidth={2} fill={saved ? "currentColor" : "none"} /></button></div>
      </article>
      {error ? <p className="route-error route-pad">{error}</p> : null}
      <section className="detail-comments"><h2>ความคิดเห็น</h2>{comments.length ? comments.map((comment) => <div className="detail-comment" key={comment.id}><Avatar src={comment.author_avatar_url} label={comment.author_username} size={34} /><div><strong>{comment.author_display_name?.trim() || comment.author_username}</strong><p>{comment.text_content}</p><small>{relativeTimeTh(comment.created_at)}</small></div><button className={comment.liked_by_me ? "active like" : ""} type="button" onClick={() => void likeComment(comment)}><WynosIcon name="like" size={15} strokeWidth={2} fill={comment.liked_by_me ? "currentColor" : "none"} />{comment.like_count || ""}</button></div>) : <EmptyState>ยังไม่มีความคิดเห็น</EmptyState>}</section>
      <form className="detail-comment-form" onSubmit={(e) => { e.preventDefault(); void submit(); }}><input value={draft} onChange={(e) => setDraft(e.target.value)} maxLength={500} placeholder="เพิ่มความคิดเห็น…" /><button type="submit" disabled={sending || !draft.trim()}><WynosIcon name="send" size={19} strokeWidth={2} /></button></form>
    </AppChrome>
  );
}

export function DropDeepLinkRoute({ dropId }: { dropId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <DropDetailInner client={client} userId={userId} dropId={dropId} />}</DeveloperRouteGate>;
}

type ClubPost = Record<string, unknown>;
function ClubPostCard({ client, post }: { client: SupabaseClient; post: ClubPost }) {
  const authorRaw = post.author;
  const author = Array.isArray(authorRaw) ? (authorRaw[0] as Record<string, unknown> | undefined) : (authorRaw as Record<string, unknown> | undefined);
  const paths = Array.isArray(post.image_urls) ? post.image_urls.map(String) : [];
  const [image, setImage] = useState<string | null>(null);
  useEffect(() => { if (!paths[0]) return; let live = true; void client.storage.from("club-media").createSignedUrl(paths[0], 3600).then(({ data }) => { if (live) setImage(data?.signedUrl ?? null); }); return () => { live = false; }; }, [client, post.id]); // eslint-disable-line react-hooks/exhaustive-deps
  return <Link className="club-post-card" href={`/club-post/${String(post.id)}`}><div className="club-post-author"><Avatar src={author?.avatar_url ? String(author.avatar_url) : null} label={String(author?.username ?? "WYNOS")} size={34} /><span><strong>{String(author?.display_name || author?.username || "WYNOS")}</strong><small>{relativeTimeTh(String(post.created_at ?? ""))}</small></span></div>{post.content ? <p>{String(post.content)}</p> : null}{image ? <img src={image} alt="" loading="lazy" decoding="async" /> : null}</Link>;
}

function ClubInner({ client, userId, clubId }: { client: SupabaseClient; userId: string; clubId: string }) {
  const [club, setClub] = useState<ClubRow | null>(null);
  const [membership, setMembership] = useState<Record<string, unknown> | null>(null);
  const [posts, setPosts] = useState<ClubPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const [nextClub, member] = await Promise.all([
        fetchClub(client, clubId),
        client.from("club_members").select("role,status").eq("club_id", clubId).eq("user_id", userId).maybeSingle(),
      ]);
      if (member.error) throw member.error;
      setClub(nextClub); setMembership(member.data);
      if (nextClub && (nextClub.privacy === "public" || member.data?.status === "approved")) {
        const result = await client.from("club_posts").select("*,author:profiles!club_posts_author_id_fkey(username,display_name,avatar_url)").eq("club_id", clubId).order("pinned", { ascending: false }).order("created_at", { ascending: false }).limit(40);
        if (result.error) throw result.error;
        setPosts((result.data ?? []) as ClubPost[]);
      } else setPosts([]);
    } catch (e) { setError(e instanceof Error ? e.message : "โหลด Club ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, clubId, userId]);
  useEffect(() => { void load(); }, [load]);
  if (loading) return <AppChrome title="Club" userId={userId} backHref="/search"><LoadingState /></AppChrome>;
  if (!club) return <AppChrome title="Club" userId={userId} backHref="/search"><EmptyState>{error || "ไม่พบ Club"}</EmptyState></AppChrome>;
  const join = async () => {
    setBusy(true); setError("");
    try {
      if (membership) {
        const result = await client.from("club_members").delete().eq("club_id", club.id).eq("user_id", userId); if (result.error) throw result.error;
      } else {
        const result = await client.from("club_members").insert({ club_id: club.id, user_id: userId, role: "member", status: club.privacy === "public" ? "approved" : "pending" }); if (result.error) throw result.error;
      }
      await load();
    } catch (e) { setError(e instanceof Error ? e.message : "อัปเดตสมาชิกไม่สำเร็จ"); } finally { setBusy(false); }
  };
  return <AppChrome title={club.name} userId={userId} backHref="/search"><section className="club-header"><div className="club-cover">{club.cover_url || club.icon_url ? <Image src={club.icon_url || club.cover_url || ""} alt="" width={76} height={76} sizes="76px" /> : null}</div><h2>{club.name}</h2>{club.description ? <p>{club.description}</p> : null}<small>{club.member_count.toLocaleString("th-TH")} สมาชิก{club.category ? ` · ${club.category}` : ""}</small><button className={`route-pill ${membership ? "soft" : ""}`} disabled={busy || membership?.role === "owner"} type="button" onClick={() => void join()}>{membership?.status === "approved" ? "เป็นสมาชิกแล้ว" : membership?.status === "pending" ? "รออนุมัติ" : "เข้าร่วม"}</button>{error ? <p className="route-error">{error}</p> : null}</section><section className="club-posts"><h2>โพสต์</h2>{posts.length ? posts.map((post) => <ClubPostCard client={client} post={post} key={String(post.id)} />) : <EmptyState>{club.privacy === "private" && membership?.status !== "approved" ? "เข้าร่วม Club เพื่อดูโพสต์" : "ยังไม่มีโพสต์"}</EmptyState>}</section></AppChrome>;
}

export function ClubRoute({ clubId }: { clubId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ClubInner client={client} userId={userId} clubId={clubId} />}</DeveloperRouteGate>;
}

type ClubPostSnapshot = { post: ClubPost; imageUrls: string[] };

function ClubPostInner({ client, userId, postId }: { client: SupabaseClient; userId: string; postId: string }) {
  const cacheKey = `club-post:${userId}:${postId}`;
  const cached = getMountCache<ClubPostSnapshot>(cacheKey);
  const [post, setPost] = useState<ClubPost | null>(cached?.post ?? null);
  const [loading, setLoading] = useState(!cached);
  const [imageUrls, setImageUrls] = useState<string[]>(cached?.imageUrls ?? []);
  useEffect(() => {
    let live = true;
    void fetchClubPostById(client, postId).then(async (value) => {
      if (!live) return;
      setPost(value);
      let urls: string[] = [];
      if (value && Array.isArray(value.image_urls)) {
        const signed = await Promise.all(value.image_urls.map(async (path) => (await client.storage.from("club-media").createSignedUrl(String(path), 3600)).data?.signedUrl ?? null));
        urls = signed.filter((url): url is string => Boolean(url));
        if (live) setImageUrls(urls);
      }
      if (live && value) setMountCache(cacheKey, { post: value, imageUrls: urls });
      setLoading(false);
    }).catch(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [client, postId, cacheKey]);
  if (loading && !post) return <AppChrome title="โพสต์ Club" userId={userId} backHref="/"><LoadingState /></AppChrome>;
  if (!post) return <AppChrome title="โพสต์ Club" userId={userId} backHref="/"><EmptyState>ไม่พบโพสต์นี้หรือคุณไม่มีสิทธิ์ดู</EmptyState></AppChrome>;
  const authorRaw = post.author; const author = Array.isArray(authorRaw) ? authorRaw[0] as Record<string, unknown> | undefined : authorRaw as Record<string, unknown> | undefined; const clubRaw = post.club; const club = Array.isArray(clubRaw) ? clubRaw[0] as Record<string, unknown> | undefined : clubRaw as Record<string, unknown> | undefined;
  return <AppChrome title={String(club?.name || "โพสต์ Club")} userId={userId} backHref={post.club_id ? `/club/${String(post.club_id)}` : "/"}><article className="club-post-detail"><div className="club-post-author"><Avatar src={author?.avatar_url ? String(author.avatar_url) : null} label={String(author?.username ?? "WYNOS")} /><span><strong>{String(author?.display_name || author?.username || "WYNOS")}</strong><small>{relativeTimeTh(String(post.created_at ?? ""))}</small></span></div>{post.content ? <p>{String(post.content)}</p> : null}{imageUrls.map((url) => <Image src={url} alt="" width={1200} height={1500} style={{ width: "100%", height: "auto" }} sizes="(max-width: 640px) 100vw, 640px" key={url} />)}</article></AppChrome>;
}

export function ClubPostRoute({ postId }: { postId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ClubPostInner client={client} userId={userId} postId={postId} />}</DeveloperRouteGate>;
}

function ClubInviteInner({ client, userId, code }: { client: SupabaseClient; userId: string; code: string }) {
  const [invite, setInvite] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  useEffect(() => { let live = true; void fetchClubInvite(client, code).then((value) => { if (live) { setInvite(value); setLoading(false); } }); return () => { live = false; }; }, [client, code]);
  const redeem = async () => { setBusy(true); setMessage(""); try { const result = await client.rpc("redeem_club_invite_link", { p_code: code }); if (result.error) throw result.error; setMessage("เข้าร่วม Club แล้ว"); } catch (e) { setMessage(e instanceof Error ? e.message : "ใช้ลิงก์เชิญไม่สำเร็จ"); } finally { setBusy(false); } };
  if (loading) return <AppChrome title="คำเชิญ Club" userId={userId} backHref="/"><LoadingState /></AppChrome>;
  if (!invite) return <AppChrome title="คำเชิญ Club" userId={userId} backHref="/"><EmptyState>ไม่พบลิงก์เชิญนี้</EmptyState></AppChrome>;
  const status = String(invite.status ?? "valid"); const clubId = String(invite.club_id ?? "");
  return <AppChrome title="คำเชิญ Club" userId={userId} backHref="/"><section className="invite-card"><h2>{String(invite.club_name ?? "Club")}</h2>{invite.club_description ? <p>{String(invite.club_description)}</p> : null}<small>สถานะ: {status}</small>{status === "valid" ? <button className="route-primary" type="button" disabled={busy} onClick={() => void redeem()}>{busy ? "กำลังเข้าร่วม…" : "เข้าร่วม Club"}</button> : <p>ลิงก์นี้ไม่สามารถใช้งานได้แล้ว</p>}{message ? <p className="route-notice">{message}</p> : null}{clubId ? <Link className="route-secondary inline" href={`/club/${clubId}`}>เปิด Club</Link> : null}</section></AppChrome>;
}

export function ClubInviteRoute({ code }: { code: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ClubInviteInner client={client} userId={userId} code={code} />}</DeveloperRouteGate>;
}

export function PopUnavailableRoute() {
  return <DeveloperRouteGate>{({ userId }) => <AppChrome title="WYNOS" userId={userId} backHref="/"><EmptyState>เนื้อหานี้ไม่พร้อมใช้งานแล้ว</EmptyState></AppChrome>}</DeveloperRouteGate>;
}
