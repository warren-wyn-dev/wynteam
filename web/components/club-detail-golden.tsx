"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { relativeTimeTh } from "@/lib/feed";
import {
  deleteClubPost,
  fetchClubPostsForClub,
  toggleClubPostLike,
  toggleClubPostPin,
  toggleClubPostSave,
  voteClubPostPoll,
  type ClubHomePost,
} from "@/lib/home-parity-data";
import { haptic } from "@/lib/haptics";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { fetchClub, type ClubRow } from "@/lib/phase3-data";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";

type ClubTab = "posts" | "chat" | "about";
type AboutTab = "details" | "members" | "events" | "insights";
type Membership = { role: string; status: string } | null;
type ChannelRow = { id: string; name: string };
type MessageRow = {
  id: string;
  author_id: string;
  content?: string | null;
  image_url?: string | null;
  created_at: string;
  author_username: string;
  author_display_name?: string | null;
  author_avatar_url?: string | null;
};
type MemberRow = {
  user_id: string;
  role: string;
  username: string;
  display_name?: string | null;
  avatar_url?: string | null;
};
type EventRow = {
  id: string;
  title: string;
  description?: string | null;
  starts_at: string;
  location_type: string;
  location: string;
};
type InsightRow = Record<string, unknown>;
type ClubData = {
  club: ClubRow & { rules?: string | null; owner_id?: string | null };
  membership: Membership;
  channels: ChannelRow[];
  muted: boolean;
};
type ReportTarget = { type: "club" | "club_post" | "club_channel_message"; id: string; label: string };

const reportCategories = [
  ["spam", "สแปม (Spam)"],
  ["scam", "หลอกลวง (Scam)"],
  ["harassment", "คุกคาม/กลั่นแกล้ง (Harassment)"],
  ["hate", "ความเกลียดชัง (Hate)"],
  ["sexual_content", "เนื้อหาทางเพศ (Sexual Content)"],
  ["violence", "ความรุนแรง (Violence)"],
  ["privacy", "ละเมิดความเป็นส่วนตัว (Privacy)"],
  ["illegal_content", "ผิดกฎหมาย (Illegal Content)"],
  ["copyright", "ละเมิดลิขสิทธิ์ (Copyright)"],
  ["other", "อื่น ๆ (Other)"],
] as const;

function relation(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) return (value[0] as Record<string, unknown> | undefined) ?? {};
  return value && typeof value === "object" ? value as Record<string, unknown> : {};
}

function BottomSheet({ children, label, onClose }: { children: React.ReactNode; label: string; onClose: () => void }) {
  return (
    <div className="route-modal-backdrop golden-club-sheet-backdrop" role="presentation" onClick={onClose}>
      <section className="golden-club-sheet" role="dialog" aria-modal="true" aria-label={label} onClick={(event) => event.stopPropagation()}>
        <div className="golden-club-sheet-grip" />
        {children}
      </section>
    </div>
  );
}

function ReportSheet({ client, target, onClose }: { client: SupabaseClient; target: ReportTarget; onClose: () => void }) {
  const [category, setCategory] = useState<string>("spam");
  const [detail, setDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const submit = async () => {
    if (busy || (category === "other" && !detail.trim())) {
      if (category === "other" && !detail.trim()) setError("กรุณาระบุรายละเอียด");
      return;
    }
    setBusy(true); setError("");
    const result = await client.rpc("submit_report", {
      p_target_type: target.type,
      p_target_id: target.id,
      p_category: category,
      p_detail: category === "other" ? detail.trim() : null,
    });
    if (result.error) setError(result.error.message || "ส่งรายงานไม่สำเร็จ");
    else onClose();
    setBusy(false);
  };
  return (
    <BottomSheet label={target.label} onClose={onClose}>
      <div className="golden-club-report">
        <strong>{target.label}</strong>
        <div className="golden-club-report-list">
          {reportCategories.map(([value, label]) => (
            <label key={value}>
              <input type="radio" name="club-report" checked={category === value} onChange={() => setCategory(value)} />
              {label}
            </label>
          ))}
        </div>
        {category === "other" ? <textarea maxLength={1000} value={detail} onChange={(event) => setDetail(event.target.value)} placeholder="รายละเอียดเพิ่มเติม" /> : null}
        {error ? <p className="route-error">{error}</p> : null}
        <button className="route-primary" type="button" disabled={busy} onClick={() => void submit()}>ส่งรายงาน</button>
      </div>
    </BottomSheet>
  );
}

async function fetchClubData(client: SupabaseClient, userId: string, clubId: string): Promise<ClubData | null> {
  const [base, extra, member, channels, mute] = await Promise.all([
    fetchClub(client, clubId),
    client.from("clubs").select("rules,owner_id").eq("id", clubId).maybeSingle(),
    client.from("club_members").select("role,status").eq("club_id", clubId).eq("user_id", userId).maybeSingle(),
    client.from("club_channels").select("id,name,created_at").eq("club_id", clubId).order("created_at", { ascending: true }),
    client.from("club_notification_mutes").select("club_id").eq("club_id", clubId).eq("user_id", userId).maybeSingle(),
  ]);
  if (!base) return null;
  if (extra.error) throw extra.error;
  if (member.error) throw member.error;
  if (channels.error) throw channels.error;
  return {
    club: {
      ...base,
      rules: extra.data?.rules ? String(extra.data.rules) : null,
      owner_id: extra.data?.owner_id ? String(extra.data.owner_id) : null,
    },
    membership: member.data ? { role: String(member.data.role), status: String(member.data.status) } : null,
    channels: (channels.data ?? []).map((row) => ({ id: String(row.id), name: String(row.name ?? "ทั่วไป") })),
    muted: !mute.error && Boolean(mute.data),
  };
}

async function fetchMessages(client: SupabaseClient, channelId: string): Promise<MessageRow[]> {
  if (!channelId) return [];
  const result = await client
    .from("club_channel_messages")
    .select("id,channel_id,author_id,content,image_url,created_at,author:profiles!club_channel_messages_author_id_fkey(username,display_name,avatar_url)")
    .eq("channel_id", channelId)
    .order("created_at", { ascending: true })
    .limit(150);
  if (result.error) throw result.error;
  return Promise.all(((result.data ?? []) as unknown as Record<string, unknown>[]).map(async (raw) => {
    const author = relation(raw.author);
    let imageUrl: string | null = null;
    if (raw.image_url) {
      const signed = await client.storage.from("club-media").createSignedUrl(String(raw.image_url), 3600);
      if (!signed.error) imageUrl = signed.data.signedUrl;
    }
    return {
      id: String(raw.id),
      author_id: String(raw.author_id),
      content: raw.content ? String(raw.content) : null,
      image_url: imageUrl,
      created_at: String(raw.created_at ?? ""),
      author_username: String(author.username ?? ""),
      author_display_name: author.display_name ? String(author.display_name) : null,
      author_avatar_url: author.avatar_url ? String(author.avatar_url) : null,
    };
  }));
}

async function fetchMembers(client: SupabaseClient, clubId: string): Promise<MemberRow[]> {
  const result = await client.rpc("club_member_profiles", { p_club_id: clubId, p_status: "approved", p_limit: 200, p_offset: 0 });
  if (!result.error && Array.isArray(result.data)) {
    return (result.data as Record<string, unknown>[]).map((raw) => ({
      user_id: String(raw.user_id ?? raw.id ?? ""),
      role: String(raw.role ?? "member"),
      username: String(raw.username ?? ""),
      display_name: raw.display_name ? String(raw.display_name) : null,
      avatar_url: raw.avatar_url ? String(raw.avatar_url) : null,
    })).filter((row) => row.user_id);
  }
  const membership = await client.from("club_members").select("user_id,role").eq("club_id", clubId).eq("status", "approved").limit(200);
  if (membership.error) throw membership.error;
  const ids = (membership.data ?? []).map((row) => String(row.user_id));
  if (!ids.length) return [];
  const profiles = await client.from("profiles").select("id,username,display_name,avatar_url").in("id", ids);
  if (profiles.error) throw profiles.error;
  const byId = new Map((profiles.data ?? []).map((profile) => [String(profile.id), profile]));
  return (membership.data ?? []).map((member) => {
    const profile = byId.get(String(member.user_id));
    return {
      user_id: String(member.user_id),
      role: String(member.role),
      username: String(profile?.username ?? ""),
      display_name: profile?.display_name ? String(profile.display_name) : null,
      avatar_url: profile?.avatar_url ? String(profile.avatar_url) : null,
    };
  });
}

async function fetchEvents(client: SupabaseClient, clubId: string): Promise<EventRow[]> {
  const result = await client.from("club_events").select("id,title,description,starts_at,location_type,location").eq("club_id", clubId).order("starts_at", { ascending: true }).limit(50);
  if (result.error) throw result.error;
  return (result.data ?? []).map((row) => ({
    id: String(row.id),
    title: String(row.title),
    description: row.description ? String(row.description) : null,
    starts_at: String(row.starts_at),
    location_type: String(row.location_type),
    location: String(row.location),
  }));
}

function ClubPoll({ post, onVote }: { post: ClubHomePost; onVote: (index: number) => void }) {
  const options = post.poll_options ?? [];
  const closed = post.poll_expires_at ? Date.now() >= new Date(post.poll_expires_at).getTime() : false;
  const visible = post.poll_total_votes != null && post.poll_option_counts != null;
  const total = post.poll_total_votes ?? 0;
  const remaining = useMemo(() => {
    if (!post.poll_expires_at) return "";
    if (closed) return "โพลปิดแล้ว";
    const ms = Math.max(0, new Date(post.poll_expires_at).getTime() - Date.now());
    const days = Math.floor(ms / 86_400_000);
    if (days >= 1) return `เหลืออีก ${days} วัน`;
    const hours = Math.floor(ms / 3_600_000);
    if (hours >= 1) return `เหลืออีก ${hours} ชม.`;
    return `เหลืออีก ${Math.max(1, Math.floor(ms / 60_000))} นาที`;
  }, [closed, post.poll_expires_at]);
  return (
    <div className="golden-club-poll">
      {options.map((option, index) => {
        const count = post.poll_option_counts?.[index] ?? 0;
        const pct = visible && total > 0 ? Math.round((count / total) * 100) : 0;
        const mine = post.poll_my_vote_index === index;
        const enabled = post.author_id !== "" && !closed;
        return (
          <button className={mine ? "mine" : ""} type="button" disabled={!enabled} onClick={() => onVote(index)} key={`${post.id}:poll:${index}`}>
            {visible ? <span className="golden-club-poll-fill" style={{ width: `${pct}%` }} /> : null}
            <span className="golden-club-poll-label">{mine ? <WynosIcon name="check" size={16} strokeWidth={2} /> : null}<b>{option}</b></span>
            {visible ? <strong>{pct}%</strong> : null}
          </button>
        );
      })}
      <small>{visible ? (total ? `${total} โหวต · ${remaining}` : `ยังไม่มีใครโหวต · ${remaining}`) : remaining}</small>
    </div>
  );
}

function ClubPostCard({
  client,
  userId,
  initial,
  onChanged,
}: {
  client: SupabaseClient;
  userId: string;
  initial: ClubHomePost;
  onChanged: () => void;
}) {
  const [post, setPost] = useState(initial);
  const [menu, setMenu] = useState(false);
  const [report, setReport] = useState(false);
  const [busy, setBusy] = useState(false);
  useEffect(() => setPost(initial), [initial]);
  const own = post.author_id === userId;
  const canModerate = ["owner", "admin", "moderator"].includes(post.my_role ?? "");
  const author = post.author_display_name?.trim() || post.author_username || "WYNOS";
  const share = async () => {
    const url = `${window.location.origin}/club-post/${post.id}`;
    try {
      if (navigator.share) await navigator.share({ title: author, text: post.content || "WYNOS Club", url });
      else await navigator.clipboard.writeText(url);
    } catch { /* native share cancelled */ }
  };
  const like = async () => {
    if (busy) return;
    if (!post.liked_by_me) haptic();
    const previous = post;
    setPost({ ...post, liked_by_me: !post.liked_by_me, like_count: Math.max(0, post.like_count + (post.liked_by_me ? -1 : 1)) });
    try { await toggleClubPostLike(client, userId, post.id, post.liked_by_me); }
    catch { setPost(previous); }
  };
  const save = async () => {
    if (busy) return;
    if (!post.saved_by_me) haptic();
    const previous = post;
    setPost({ ...post, saved_by_me: !post.saved_by_me });
    try { await toggleClubPostSave(client, userId, post.id, post.saved_by_me); }
    catch { setPost(previous); }
    setMenu(false);
  };
  const pin = async () => {
    if (busy) return;
    const previous = post;
    setPost({ ...post, pinned: !post.pinned });
    try { await toggleClubPostPin(client, post.id, post.pinned); onChanged(); }
    catch { setPost(previous); }
    setMenu(false);
  };
  const remove = async () => {
    if (busy || !window.confirm("ลบโพสต์นี้? ลบแล้วไม่สามารถกู้คืนได้")) return;
    setBusy(true);
    try { await deleteClubPost(client, post.id); setMenu(false); onChanged(); }
    finally { setBusy(false); }
  };
  const vote = async (index: number) => {
    if (!post.poll_id || busy || own) return;
    setBusy(true);
    try { await voteClubPostPoll(client, userId, post.poll_id, index); onChanged(); }
    finally { setBusy(false); }
  };
  return (
    <article className="golden-club-post">
      <Link className="golden-club-post-avatar" href={`/profile/${post.author_id}`}><Avatar src={post.author_avatar_url} label={post.author_username || "W"} size={42} /></Link>
      <div className="golden-club-post-body">
        <header>
          <Link href={`/profile/${post.author_id}`}><strong>{author}</strong><small>{relativeTimeTh(post.created_at)}</small></Link>
          <button type="button" aria-label="เพิ่มเติม" onClick={() => setMenu(true)}><WynosIcon name="moreVertical" size={22} strokeWidth={2} /></button>
        </header>
        {post.pinned ? <span className="golden-club-pin"><WynosIcon name="pin" size={12} strokeWidth={2} /> ปักหมุด</span> : null}
        {post.content ? <Link className="golden-club-post-open" href={`/club-post/${post.id}`}><p>{post.content}</p></Link> : null}
        {post.image_urls.length ? (
          <Link className={`golden-club-media ${post.image_urls.length > 1 ? "multi" : "single"}`} href={`/club-post/${post.id}`}>
            {post.image_urls.map((url, index) => <Image src={url} alt="" width={1200} height={1500} style={{ width: "100%", height: "auto" }} sizes="(max-width: 640px) 100vw, 640px" loading="lazy" key={`${post.id}:image:${index}`} />)}
          </Link>
        ) : null}
        {post.poll_id ? <ClubPoll post={post} onVote={vote} /> : null}
        {post.link_url ? <a className="golden-club-link" href={post.link_url} target="_blank" rel="noreferrer"><WynosIcon name="link" size={16} strokeWidth={2} /><span>{post.link_url}</span></a> : null}
        <div className="golden-club-actions">
          <button className={post.liked_by_me ? "liked" : ""} type="button" onClick={() => void like()}><WynosIcon name="like" size={17} strokeWidth={2} fill={post.liked_by_me ? "currentColor" : "none"} />{post.like_count > 0 ? <span>{post.like_count}</span> : null}</button>
          <Link href={`/club-post/${post.id}`}><WynosIcon name="comment" size={17} strokeWidth={2} />{post.comment_count > 0 ? <span>{post.comment_count}</span> : null}</Link>
        </div>
      </div>
      {menu ? (
        <BottomSheet label="ตัวเลือกโพสต์" onClose={() => setMenu(false)}>
          <button className="golden-club-sheet-row" type="button" onClick={() => { setMenu(false); void share(); }}><WynosIcon name="share" size={20} strokeWidth={2} />แชร์</button>
          <button className="golden-club-sheet-row" type="button" onClick={() => void save()}><WynosIcon name="bookmark" size={20} strokeWidth={2} fill={post.saved_by_me ? "currentColor" : "none"} />{post.saved_by_me ? "เอาออกจากบันทึก" : "บันทึก"}</button>
          {own || canModerate ? <button className="golden-club-sheet-row danger" type="button" disabled={busy} onClick={() => void remove()}><WynosIcon name="trash" size={20} strokeWidth={2} />ลบโพสต์</button> : null}
          {!own && canModerate ? <button className="golden-club-sheet-row" type="button" disabled={busy} onClick={() => void pin()}><WynosIcon name="pin" size={20} strokeWidth={2} />{post.pinned ? "เลิกปักหมุด" : "ปักหมุด"}</button> : null}
          {!own ? <button className="golden-club-sheet-row" type="button" onClick={() => { setMenu(false); setReport(true); }}><WynosIcon name="flag" size={20} strokeWidth={2} />รายงานโพสต์</button> : null}
        </BottomSheet>
      ) : null}
      {report ? <ReportSheet client={client} target={{ type: "club_post", id: post.id, label: `รายงานโพสต์ของ ${author}` }} onClose={() => setReport(false)} /> : null}
    </article>
  );
}

function ChannelStrip({ channels, value, onChange }: { channels: ChannelRow[]; value: string; onChange: (id: string) => void }) {
  return <div className="golden-club-channels" aria-label="ห้อง Club">{channels.map((channel) => <button className={value === channel.id ? "active" : ""} type="button" onClick={() => onChange(channel.id)} key={channel.id}>#{channel.name}</button>)}</div>;
}

function ChatTab({ client, userId, clubId, membership, channels }: { client: SupabaseClient; userId: string; clubId: string; membership: Membership; channels: ChannelRow[] }) {
  const [channelId, setChannelId] = useState(channels[0]?.id ?? "");
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [draft, setDraft] = useState("");
  const [image, setImage] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [report, setReport] = useState<ReportTarget | null>(null);
  const canModerate = membership?.status === "approved" && ["owner", "admin", "moderator"].includes(membership.role);
  const reload = useCallback(async () => {
    if (!channelId) { setMessages([]); return; }
    setLoading(true); setError("");
    try {
      setMessages(await fetchMessages(client, channelId));
      await client.rpc("mark_club_channel_read", { p_channel_id: channelId });
    } catch { setError("โหลดแชทไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [channelId, client]);
  useEffect(() => { const timer = window.setTimeout(() => { void reload(); }, 0); return () => window.clearTimeout(timer); }, [reload]);
  useEffect(() => {
    if (!channelId || membership?.status !== "approved") return;
    const subscription = client.channel(`club-chat-web:${channelId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "club_channel_messages", filter: `channel_id=eq.${channelId}` }, () => { void reload(); })
      .subscribe();
    return () => { void client.removeChannel(subscription); };
  }, [channelId, client, membership?.status, reload]);
  if (membership?.status !== "approved") return <EmptyState>เข้าร่วม Club เพื่อใช้งานแชท</EmptyState>;
  const send = async () => {
    if ((!draft.trim() && !image) || sending || !channelId) return;
    setSending(true); setError("");
    try {
      let imagePath: string | null = null;
      if (image) {
        const ext = image.name.split(".").pop()?.toLowerCase() || "jpg";
        imagePath = `${clubId}/chat/${channelId}/${userId}-${Date.now()}.${ext}`;
        const upload = await client.storage.from("club-media").upload(imagePath, image, { cacheControl: "31536000", upsert: false });
        if (upload.error) throw upload.error;
      }
      const result = await client.from("club_channel_messages").insert({
        channel_id: channelId,
        author_id: userId,
        content: draft.trim() || null,
        image_url: imagePath,
      });
      if (result.error) throw result.error;
      setDraft(""); setImage(null); await reload();
    } catch { setError("ส่งข้อความไม่สำเร็จ"); }
    finally { setSending(false); }
  };
  const remove = async (id: string) => {
    if (!window.confirm("ลบข้อความนี้?")) return;
    const result = await client.from("club_channel_messages").delete().eq("id", id);
    if (result.error) setError("ลบข้อความไม่สำเร็จ"); else await reload();
  };
  return (
    <section className="golden-club-chat">
      <ChannelStrip channels={channels} value={channelId} onChange={setChannelId} />
      {loading ? <LoadingState /> : (
        <div className="golden-club-messages">
          {messages.length ? messages.map((message) => (
            <div className={`golden-club-message ${message.author_id === userId ? "mine" : ""}`} key={message.id}>
              {message.author_id !== userId ? <Avatar src={message.author_avatar_url} label={message.author_username} size={30} /> : null}
              <div className="golden-club-bubble">
                <div className="golden-club-message-head"><strong>{message.author_id === userId ? "คุณ" : message.author_display_name?.trim() || message.author_username}</strong><button type="button" aria-label="ตัวเลือกข้อความ" onClick={() => message.author_id === userId || canModerate ? void remove(message.id) : setReport({ type: "club_channel_message", id: message.id, label: "รายงานข้อความ" })}><WynosIcon name="more" size={16} strokeWidth={2} /></button></div>
                {message.content ? <p>{message.content}</p> : null}
                {message.image_url ? <Image src={message.image_url} alt="" width={280} height={330} sizes="280px" /> : null}
                <small>{relativeTimeTh(message.created_at)}</small>
              </div>
            </div>
          )) : <EmptyState>ยังไม่มีข้อความในห้องนี้</EmptyState>}
        </div>
      )}
      <form className="golden-club-composer" onSubmit={(event) => { event.preventDefault(); void send(); }}>
        <label aria-label="แนบรูป"><WynosIcon name="imagePlus" size={20} strokeWidth={2} /><input hidden type="file" accept="image/*" disabled={sending} onChange={(event) => setImage(event.target.files?.[0] ?? null)} /></label>
        <input value={draft} maxLength={2000} onChange={(event) => setDraft(event.target.value)} placeholder={image ? `แนบ ${image.name}` : "ส่งข้อความ…"} />
        <button type="submit" aria-label="ส่ง" disabled={sending || (!draft.trim() && !image)}><WynosIcon name="send" size={20} strokeWidth={2} /></button>
      </form>
      {error ? <p className="route-error golden-club-chat-error">{error}</p> : null}
      {report ? <ReportSheet client={client} target={report} onClose={() => setReport(null)} /> : null}
    </section>
  );
}

function AboutTabView({ client, clubId, club, membership }: { client: SupabaseClient; clubId: string; club: ClubData["club"]; membership: Membership }) {
  const canManage = membership?.status === "approved" && ["owner", "admin"].includes(membership.role);
  const member = membership?.status === "approved";
  const choices: { key: AboutTab; label: string }[] = [
    { key: "details", label: "รายละเอียด" },
    { key: "members", label: "สมาชิก" },
    ...(member ? [{ key: "events" as const, label: "กิจกรรม" }] : []),
    ...(canManage ? [{ key: "insights" as const, label: "Insights" }] : []),
  ];
  const [tab, setTab] = useState<AboutTab>("details");
  const [members, setMembers] = useState<MemberRow[]>([]);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [insights, setInsights] = useState<InsightRow | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    let live = true;
    if (tab === "details") return () => { live = false; };
    const timer = window.setTimeout(() => {
      if (!live) return;
      setLoading(true); setError("");
      void (async () => {
        try {
          if (tab === "members") setMembers(await fetchMembers(client, clubId));
          else if (tab === "events") setEvents(await fetchEvents(client, clubId));
          else {
            const result = await client.rpc("club_insights", { p_club_id: clubId, p_days: 30 });
            if (result.error) throw result.error;
            const value = Array.isArray(result.data) ? result.data[0] : result.data;
            setInsights((value ?? null) as InsightRow | null);
          }
        } catch { if (live) setError("โหลดข้อมูล Club ไม่สำเร็จ"); }
        finally { if (live) setLoading(false); }
      })();
    }, 0);
    return () => { live = false; window.clearTimeout(timer); };
  }, [client, clubId, tab]);
  return (
    <section className="golden-club-about">
      <div className="golden-club-about-tabs">{choices.map((choice) => <button className={tab === choice.key ? "active" : ""} type="button" onClick={() => setTab(choice.key)} key={choice.key}>{choice.label}</button>)}</div>
      {loading ? <LoadingState /> : tab === "details" ? (
        <div className="golden-club-details">
          <h3>รายละเอียด</h3><p>{club.description || "ยังไม่มีคำอธิบาย"}</p>
          <dl><div><dt>หมวดหมู่</dt><dd>{club.category || "—"}</dd></div><div><dt>ความเป็นส่วนตัว</dt><dd>{club.privacy === "private" ? "ส่วนตัว" : "สาธารณะ"}</dd></div><div><dt>สมาชิก</dt><dd>{club.member_count.toLocaleString("th-TH")}</dd></div></dl>
          <h3>กฎของ Club</h3><p>{club.rules || "ยังไม่มีกฎของ Club"}</p>
        </div>
      ) : tab === "members" ? (
        <div className="golden-club-members">{members.length ? members.map((person) => <Link href={`/profile/${person.user_id}`} key={person.user_id}><Avatar src={person.avatar_url} label={person.username} size={42} /><span><strong>{person.display_name?.trim() || person.username}</strong><small>@{person.username} · {person.role}</small></span><WynosIcon name="chevronRight" size={18} strokeWidth={2} /></Link>) : <EmptyState>ยังไม่มีสมาชิก</EmptyState>}</div>
      ) : tab === "events" ? (
        <div className="golden-club-events">{events.length ? events.map((event) => <article key={event.id}><WynosIcon name="calendarDays" size={20} strokeWidth={2} /><div><strong>{event.title}</strong><small>{new Date(event.starts_at).toLocaleString("th-TH")}</small><p>{event.location_type === "online" ? "ออนไลน์" : "สถานที่"}: {event.location}</p>{event.description ? <p>{event.description}</p> : null}</div></article>) : <EmptyState>ยังไม่มีกิจกรรม</EmptyState>}</div>
      ) : (
        <div className="golden-club-insights">{insights ? Object.entries(insights).map(([key, value]) => <div key={key}><span>{key.replaceAll("_", " ")}</span><strong>{String(value ?? 0)}</strong></div>) : <EmptyState>ยังไม่มีข้อมูล Insights</EmptyState>}</div>
      )}
      {error ? <p className="route-error">{error}</p> : null}
    </section>
  );
}

type ClubDetailSnapshot = { data: ClubData; posts: ClubHomePost[] };

function ClubDetailGoldenInner({ client, userId, clubId }: { client: SupabaseClient; userId: string; clubId: string }) {
  const router = useRouter();
  const cacheKey = `club-detail:${userId}:${clubId}`;
  const cached = getMountCache<ClubDetailSnapshot>(cacheKey);
  const [data, setData] = useState<ClubData | null>(cached?.data ?? null);
  const [posts, setPosts] = useState<ClubHomePost[]>(cached?.posts ?? []);
  const [tab, setTab] = useState<ClubTab>("posts");
  const [loading, setLoading] = useState(!cached);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [menu, setMenu] = useState(false);
  const [report, setReport] = useState(false);

  const load = useCallback(async () => {
    const next = await fetchClubData(client, userId, clubId);
    if (!next) return null;
    const canReadPosts = next.club.privacy === "public" || next.membership?.status === "approved";
    const nextPosts = canReadPosts ? await fetchClubPostsForClub(client, userId, clubId, 100) : [];
    return { next, nextPosts };
  }, [client, clubId, userId]);

  const refresh = useCallback(async () => {
    const result = await load();
    if (result) {
      setData(result.next);
      setPosts(result.nextPosts);
      setMountCache(cacheKey, { data: result.next, posts: result.nextPosts });
    }
  }, [load, cacheKey]);

  useEffect(() => {
    let live = true;
    void load().then((result) => {
      if (!live) return;
      if (result) {
        setData(result.next);
        setPosts(result.nextPosts);
        setMountCache(cacheKey, { data: result.next, posts: result.nextPosts });
      }
    }).catch(() => { if (live) setError("โหลด Club ไม่สำเร็จ"); }).finally(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [load, cacheKey]);

  // GA (2026-09-20, Founder decision): was staged-rollout-gated to
  // developer accounts (WYN-125/WYN-182) — Founder asked to widen it to
  // everyone. Still scoped to the "posts" tab only — chat has its own
  // realtime subscription, about is static, neither is the feed/list
  // pattern this gesture is for.
  const pull = usePullToRefresh({ enabled: tab === "posts", onRefresh: refresh });

  if (loading && !data) return <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}><LoadingState /></AppChrome>;
  if (!data) return <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}><EmptyState>{error || "ไม่พบ Club"}</EmptyState></AppChrome>;

  const { club, membership, channels, muted } = data;
  const approved = membership?.status === "approved";
  const pending = membership?.status === "pending";
  const owner = membership?.role === "owner";
  const canManage = approved && ["owner", "admin"].includes(membership?.role ?? "");
  const join = async () => {
    if (busy || owner) return;
    if (approved && !window.confirm("ออกจาก Club?")) return;
    if (pending && !window.confirm("ยกเลิกคำขอเข้าร่วม Club?")) return;
    setBusy(true); setError("");
    const result = membership
      ? await client.from("club_members").delete().eq("club_id", clubId).eq("user_id", userId)
      : await client.from("club_members").insert({ club_id: clubId, user_id: userId, role: "member", status: club.privacy === "private" ? "pending" : "approved" });
    if (result.error) setError("อัปเดตสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง");
    else await refresh();
    setBusy(false);
  };
  const toggleMute = async () => {
    if (!approved || busy) return;
    setBusy(true); setError("");
    const result = muted
      ? await client.from("club_notification_mutes").delete().eq("club_id", clubId).eq("user_id", userId)
      : await client.from("club_notification_mutes").insert({ club_id: clubId, user_id: userId });
    if (result.error) setError("อัปเดตการแจ้งเตือนไม่สำเร็จ"); else { setMenu(false); await refresh(); }
    setBusy(false);
  };
  const share = async () => {
    const url = `${window.location.origin}/club/${clubId}`;
    try { if (navigator.share) await navigator.share({ title: club.name, text: `แชร์ Club ${club.name}`, url }); else await navigator.clipboard.writeText(url); }
    catch { /* native share cancelled */ }
  };
  const statusLabel = owner ? "เจ้าของ Club" : approved ? "เข้าร่วมแล้ว" : pending ? "รออนุมัติ" : "เข้าร่วม";

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}>
      <main className="golden-club-page">
        <section className="golden-club-header">
          <div className="golden-club-banner">
            {club.cover_url ? <Image src={club.cover_url} alt="" fill sizes="(max-width: 640px) 100vw, 640px" /> : null}
            <div className="golden-club-banner-scrim" />
            <button className="golden-club-back" type="button" aria-label="ย้อนกลับ" onClick={() => router.back()}><WynosIcon name="back" size={28} strokeWidth={2} /></button>
            <div className="golden-club-banner-title"><small>CLUB</small><h1>{club.name}</h1></div>
          </div>
          <div className="golden-club-meta">
            <div className="golden-club-meta-main">
              <span className="golden-club-avatar">{club.icon_url ? <Image src={club.icon_url} alt="" width={36} height={36} sizes="36px" /> : <strong>{club.name.slice(0, 1)}</strong>}</span>
              <strong>{club.name}</strong>
              <button type="button" aria-label="แชร์" onClick={() => void share()}><WynosIcon name="share" size={15} strokeWidth={2} /></button>
              <button type="button" aria-label="เพิ่มเติม" onClick={() => setMenu(true)}><WynosIcon name="moreVertical" size={15} strokeWidth={2} /></button>
            </div>
            <div className="golden-club-membership-line">
              <span>{club.member_count.toLocaleString("th-TH")} สมาชิก</span>
              {club.category ? <span className="golden-club-category">{club.category}</span> : null}
              {club.privacy === "private" ? <WynosIcon name="lock" size={13} strokeWidth={2} /> : null}
              {(approved || pending || owner) ? <button className="golden-club-inline-join" type="button" disabled={busy || owner || pending} onClick={() => void join()}>{approved && !owner ? <WynosIcon name="check" size={11} strokeWidth={2} /> : null}{statusLabel}</button> : null}
            </div>
            {club.description ? <p>{club.description}</p> : null}
            {!membership ? <button className="golden-club-primary-join" type="button" disabled={busy} onClick={() => void join()}>{statusLabel}</button> : null}
            {error ? <p className="route-error">{error}</p> : null}
          </div>
        </section>

        <nav className="golden-club-tabs" aria-label="Club">
          <button className={tab === "posts" ? "active" : ""} type="button" onClick={() => setTab("posts")}><WynosIcon name="fileText" size={16} strokeWidth={2} />โพสต์</button>
          <button className={tab === "chat" ? "active" : ""} type="button" onClick={() => setTab("chat")}><WynosIcon name="messagesSquare" size={16} strokeWidth={2} />แชท</button>
          <button className={tab === "about" ? "active" : ""} type="button" onClick={() => setTab("about")}><WynosIcon name="info" size={16} strokeWidth={2} />เกี่ยวกับ</button>
        </nav>

        {tab === "posts" ? (
          <>
            {pull.pullDistance > 0 || pull.refreshing ? (
              <div
                aria-label={pull.refreshing ? "กำลังรีเฟรชโพสต์ Club" : "ลากลงเพื่อรีเฟรช"}
                aria-live="polite"
                style={{ height: 0, position: "relative", zIndex: 6, pointerEvents: "none" }}
              >
                <div
                  className="route-system-spinner tiny"
                  style={{
                    position: "absolute",
                    top: pull.refreshing ? 10 : Math.max(4, Math.min(18, pull.pullDistance * 0.2)),
                    left: "50%",
                    opacity: pull.refreshing ? 1 : Math.max(0.22, Math.min(1, pull.pullDistance / 54)),
                    transform: `translateX(-50%) scale(${pull.refreshing ? 1 : Math.max(0.78, Math.min(1, pull.pullDistance / 54))})`,
                    transition: pull.refreshing ? "top 140ms ease, opacity 140ms ease, transform 140ms ease" : "none",
                  }}
                />
              </div>
            ) : null}
            <section
              className="golden-club-posts"
              onTouchStart={pull.onTouchStart}
              onTouchMove={pull.onTouchMove}
              onTouchEnd={pull.onTouchEnd}
              onTouchCancel={pull.onTouchCancel}
            >
            {club.privacy === "private" && !approved ? <EmptyState>เข้าร่วม Club เพื่อดูโพสต์</EmptyState> : posts.length ? posts.map((post) => <ClubPostCard client={client} userId={userId} initial={post} onChanged={() => void refresh()} key={post.id} />) : <EmptyState>ยังไม่มีโพสต์ใน Club นี้</EmptyState>}
            </section>
          </>
        ) : tab === "chat" ? (
          <ChatTab client={client} userId={userId} clubId={clubId} membership={membership} channels={channels} />
        ) : (
          <AboutTabView client={client} clubId={clubId} club={club} membership={membership} />
        )}
      </main>

      {menu ? (
        <BottomSheet label="ตัวเลือก Club" onClose={() => setMenu(false)}>
          {approved ? <button className="golden-club-sheet-row" type="button" disabled={busy} onClick={() => void toggleMute()}>{muted ? <WynosIcon name="notifications" size={20} strokeWidth={2} /> : <WynosIcon name="bellOff" size={20} strokeWidth={2} />}{muted ? "เปิดการแจ้งเตือน Club นี้" : "ปิดการแจ้งเตือน Club นี้"}</button> : null}
          {canManage ? <button className="golden-club-sheet-row" type="button" onClick={() => { setMenu(false); setTab("about"); }}><WynosIcon name="info" size={20} strokeWidth={2} />จัดการข้อมูล Club</button> : null}
          {approved && !canManage ? <button className="golden-club-sheet-row danger" type="button" disabled={busy} onClick={() => { setMenu(false); void join(); }}><WynosIcon name="logOut" size={20} strokeWidth={2} />ออกจาก Club</button> : null}
          {pending ? <button className="golden-club-sheet-row" type="button" disabled={busy} onClick={() => { setMenu(false); void join(); }}><WynosIcon name="close" size={20} strokeWidth={2} />ยกเลิกคำขอ</button> : null}
          {!owner ? <button className="golden-club-sheet-row" type="button" onClick={() => { setMenu(false); setReport(true); }}><WynosIcon name="flag" size={20} strokeWidth={2} />รายงาน Club</button> : null}
        </BottomSheet>
      ) : null}
      {report ? <ReportSheet client={client} target={{ type: "club", id: clubId, label: `รายงาน Club “${club.name}”` }} onClose={() => setReport(false)} /> : null}
    </AppChrome>
  );
}

export function ClubDetailGoldenRoute({ clubId }: { clubId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ClubDetailGoldenInner client={client} userId={userId} clubId={clubId} />}</DeveloperRouteGate>;
}
