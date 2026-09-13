"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { CalendarDays, ChevronRight, Lock, MessageCircle, Send } from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { relativeTimeTh } from "@/lib/feed";
import { fetchClub, type ClubRow } from "@/lib/phase3-data";

type ClubTab = "posts" | "chat" | "about";
type AboutTab = "details" | "members" | "events" | "insights";
type Membership = { role: string; status: string } | null;
type ChannelRow = { id: string; name: string };
type PostRow = {
  id: string;
  channel_id: string;
  author_id: string;
  content?: string | null;
  image_urls: string[];
  created_at: string;
  pinned: boolean;
  author_username: string;
  author_display_name?: string | null;
  author_avatar_url?: string | null;
  like_count: number;
  comment_count: number;
};
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
type MemberRow = { user_id: string; role: string; username: string; display_name?: string | null; avatar_url?: string | null };
type EventRow = { id: string; title: string; description?: string | null; starts_at: string; location_type: string; location: string };
type InsightRow = Record<string, unknown>;
type ClubData = { club: ClubRow & { rules?: string | null; owner_id?: string | null }; membership: Membership; channels: ChannelRow[] };

function relation(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) return (value[0] as Record<string, unknown> | undefined) ?? {};
  return value && typeof value === "object" ? value as Record<string, unknown> : {};
}

function count(value: unknown): number {
  if (!Array.isArray(value) || !value.length || typeof value[0] !== "object" || !value[0]) return 0;
  return Number((value[0] as { count?: unknown }).count ?? 0) || 0;
}

async function signClubMedia(client: SupabaseClient, path: string | null | undefined): Promise<string | null> {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path;
  const signed = await client.storage.from("club-media").createSignedUrl(path, 3600);
  return signed.error ? null : signed.data.signedUrl;
}

async function fetchClubData(client: SupabaseClient, userId: string, clubId: string): Promise<ClubData | null> {
  const [base, extra, member, channels] = await Promise.all([
    fetchClub(client, clubId),
    client.from("clubs").select("rules,owner_id").eq("id", clubId).maybeSingle(),
    client.from("club_members").select("role,status").eq("club_id", clubId).eq("user_id", userId).maybeSingle(),
    client.from("club_channels").select("id,name,created_at").eq("club_id", clubId).order("created_at", { ascending: true }),
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
  };
}

async function fetchPosts(client: SupabaseClient, clubId: string): Promise<PostRow[]> {
  const result = await client
    .from("club_posts")
    .select("id,channel_id,author_id,content,image_urls,created_at,pinned,author:profiles!club_posts_author_id_fkey(username,display_name,avatar_url),club_post_likes(count),club_post_comments(count)")
    .eq("club_id", clubId)
    .order("pinned", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(80);
  if (result.error) throw result.error;
  return Promise.all(((result.data ?? []) as unknown as Record<string, unknown>[]).map(async (raw) => {
    const author = relation(raw.author);
    const signed = await Promise.all((Array.isArray(raw.image_urls) ? raw.image_urls.map(String) : []).map((path) => signClubMedia(client, path)));
    return {
      id: String(raw.id),
      channel_id: String(raw.channel_id ?? ""),
      author_id: String(raw.author_id),
      content: raw.content ? String(raw.content) : null,
      image_urls: signed.filter((url): url is string => Boolean(url)),
      created_at: String(raw.created_at ?? ""),
      pinned: raw.pinned === true,
      author_username: String(author.username ?? ""),
      author_display_name: author.display_name ? String(author.display_name) : null,
      author_avatar_url: author.avatar_url ? String(author.avatar_url) : null,
      like_count: count(raw.club_post_likes),
      comment_count: count(raw.club_post_comments),
    };
  }));
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
    return {
      id: String(raw.id),
      author_id: String(raw.author_id),
      content: raw.content ? String(raw.content) : null,
      image_url: await signClubMedia(client, raw.image_url ? String(raw.image_url) : null),
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
    id: String(row.id), title: String(row.title), description: row.description ? String(row.description) : null,
    starts_at: String(row.starts_at), location_type: String(row.location_type), location: String(row.location),
  }));
}

function ChannelStrip({ channels, value, onChange }: { channels: ChannelRow[]; value: string; onChange: (id: string) => void }) {
  return <div className="club-detail-channels" aria-label="ห้อง Club">{channels.map((channel) => <button className={value === channel.id ? "active" : ""} type="button" onClick={() => onChange(channel.id)} key={channel.id}>#{channel.name}</button>)}</div>;
}

function PostList({ posts, empty }: { posts: PostRow[]; empty: string }) {
  return <div className="club-detail-posts">{posts.length ? posts.map((post) => <Link className="club-detail-post" href={`/club-post/${post.id}`} key={post.id}>{post.pinned ? <span className="club-pin">ปักหมุด</span> : null}<div className="club-detail-author"><Avatar src={post.author_avatar_url} label={post.author_username} size={38} /><span><strong>{post.author_display_name?.trim() || post.author_username}</strong><small>@{post.author_username} · {relativeTimeTh(post.created_at)}</small></span></div>{post.content ? <p>{post.content}</p> : null}{post.image_urls.length ? <div className={`club-detail-media ${post.image_urls.length > 1 ? "multi" : ""}`}>{post.image_urls.map((url) => <img src={url} alt="" key={url} />)}</div> : null}<footer><span>♡ {post.like_count || ""}</span><span><MessageCircle size={15} /> {post.comment_count || ""}</span></footer></Link>) : <EmptyState>{empty}</EmptyState>}</div>;
}

function ChatTab({ client, userId, membership, channels }: { client: SupabaseClient; userId: string; membership: Membership; channels: ChannelRow[] }) {
  const [channelId, setChannelId] = useState(channels[0]?.id ?? "");
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  const reload = useCallback(async () => {
    if (!channelId) { setMessages([]); return; }
    setLoading(true);
    setError("");
    try { setMessages(await fetchMessages(client, channelId)); }
    catch { setError("โหลดแชทไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, channelId]);

  useEffect(() => {
    const timer = window.setTimeout(() => { void reload(); }, 0);
    return () => window.clearTimeout(timer);
  }, [reload]);

  useEffect(() => {
    if (!channelId || membership?.status !== "approved") return;
    const subscription = client.channel(`club-chat:${channelId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "club_channel_messages", filter: `channel_id=eq.${channelId}` }, () => { void reload(); })
      .subscribe();
    return () => { void client.removeChannel(subscription); };
  }, [channelId, client, membership?.status, reload]);

  if (membership?.status !== "approved") return <EmptyState>เข้าร่วม Club เพื่อใช้งานแชท</EmptyState>;
  const send = async () => {
    if (!draft.trim() || sending || !channelId) return;
    setSending(true); setError("");
    const result = await client.from("club_channel_messages").insert({ channel_id: channelId, author_id: userId, content: draft.trim() });
    if (result.error) setError("ส่งข้อความไม่สำเร็จ");
    else { setDraft(""); await reload(); }
    setSending(false);
  };

  return <section className="club-chat-tab"><ChannelStrip channels={channels} value={channelId} onChange={setChannelId} />{loading ? <LoadingState /> : <div className="club-chat-messages">{messages.length ? messages.map((message) => <div className={`club-chat-message ${message.author_id === userId ? "mine" : ""}`} key={message.id}>{message.author_id !== userId ? <Avatar src={message.author_avatar_url} label={message.author_username} size={30} /> : null}<div><strong>{message.author_id === userId ? "คุณ" : message.author_display_name?.trim() || message.author_username}</strong>{message.content ? <p>{message.content}</p> : null}{message.image_url ? <img src={message.image_url} alt="" /> : null}<small>{relativeTimeTh(message.created_at)}</small></div></div>) : <EmptyState>ยังไม่มีข้อความในห้องนี้</EmptyState>}</div>}<form className="club-chat-composer" onSubmit={(event) => { event.preventDefault(); void send(); }}><input value={draft} maxLength={2000} onChange={(event) => setDraft(event.target.value)} placeholder="ส่งข้อความ…" /><button type="submit" aria-label="ส่ง" disabled={sending || !draft.trim()}><Send size={20} /></button></form>{error ? <p className="route-error club-chat-error">{error}</p> : null}</section>;
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

  return <section className="club-about-tab"><div className="club-about-segments">{choices.map((choice) => <button className={tab === choice.key ? "active" : ""} type="button" onClick={() => setTab(choice.key)} key={choice.key}>{choice.label}</button>)}</div>{loading ? <LoadingState /> : tab === "details" ? <div className="club-about-details"><h3>รายละเอียด</h3>{club.description ? <p>{club.description}</p> : <p className="muted">ยังไม่มีคำอธิบาย</p>}<dl><div><dt>หมวดหมู่</dt><dd>{club.category || "—"}</dd></div><div><dt>ความเป็นส่วนตัว</dt><dd>{club.privacy === "private" ? "ส่วนตัว" : "สาธารณะ"}</dd></div><div><dt>สมาชิก</dt><dd>{club.member_count.toLocaleString("th-TH")}</dd></div></dl><h3>กฎของ Club</h3><p>{club.rules || "ยังไม่มีกฎของ Club"}</p></div> : tab === "members" ? <div className="club-member-list">{members.length ? members.map((person) => <Link href={`/profile/${person.user_id}`} key={person.user_id}><Avatar src={person.avatar_url} label={person.username} size={42} /><span><strong>{person.display_name?.trim() || person.username}</strong><small>@{person.username} · {person.role}</small></span><ChevronRight size={18} /></Link>) : <EmptyState>ยังไม่มีสมาชิก</EmptyState>}</div> : tab === "events" ? <div className="club-event-list">{events.length ? events.map((event) => <article key={event.id}><CalendarDays size={20} /><div><strong>{event.title}</strong><small>{new Date(event.starts_at).toLocaleString("th-TH")}</small><p>{event.location_type === "online" ? "ออนไลน์" : "สถานที่"}: {event.location}</p>{event.description ? <p>{event.description}</p> : null}</div></article>) : <EmptyState>ยังไม่มีกิจกรรม</EmptyState>}</div> : <div className="club-insights-grid">{insights ? Object.entries(insights).map(([key, value]) => <div key={key}><span>{key.replaceAll("_", " ")}</span><strong>{String(value ?? 0)}</strong></div>) : <EmptyState>ยังไม่มีข้อมูล Insights</EmptyState>}</div>}{error ? <p className="route-error">{error}</p> : null}</section>;
}

function ClubDetailInner({ client, userId, clubId }: { client: SupabaseClient; userId: string; clubId: string }) {
  const [data, setData] = useState<ClubData | null>(null);
  const [posts, setPosts] = useState<PostRow[]>([]);
  const [tab, setTab] = useState<ClubTab>("posts");
  const [channelId, setChannelId] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    const next = await fetchClubData(client, userId, clubId);
    if (!next) return null;
    const canReadPosts = next.club.privacy === "public" || next.membership?.status === "approved";
    const nextPosts = canReadPosts ? await fetchPosts(client, clubId) : [];
    return { next, nextPosts };
  }, [client, clubId, userId]);

  useEffect(() => {
    let live = true;
    void load().then((result) => {
      if (!live) return;
      if (result) {
        setData(result.next); setPosts(result.nextPosts); setChannelId(result.next.channels[0]?.id ?? "");
      }
    }).catch(() => { if (live) setError("โหลด Club ไม่สำเร็จ"); }).finally(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [load]);

  if (loading) return <AppChrome title="Club" userId={userId} backHref="/clubs" showBottomNav={false}><LoadingState /></AppChrome>;
  if (!data) return <AppChrome title="Club" userId={userId} backHref="/clubs" showBottomNav={false}><EmptyState>{error || "ไม่พบ Club"}</EmptyState></AppChrome>;

  const { club, membership, channels } = data;
  const reload = async () => {
    setBusy(true); setError("");
    try {
      const result = await load();
      if (result) {
        setData(result.next); setPosts(result.nextPosts);
        if (!channelId || !result.next.channels.some((channel) => channel.id === channelId)) setChannelId(result.next.channels[0]?.id ?? "");
      }
    } catch { setError("อัปเดต Club ไม่สำเร็จ"); }
    finally { setBusy(false); }
  };
  const join = async () => {
    if (busy || membership?.role === "owner") return;
    if (membership?.status === "approved" && !window.confirm("ออกจาก Club?")) return;
    if (membership?.status === "pending" && !window.confirm("ยกเลิกคำขอเข้าร่วม Club?")) return;
    setBusy(true); setError("");
    const result = membership
      ? await client.from("club_members").delete().eq("club_id", clubId).eq("user_id", userId)
      : await client.from("club_members").insert({ club_id: clubId, user_id: userId, role: "member", status: club.privacy === "private" ? "pending" : "approved" });
    if (result.error) { setError("อัปเดตสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง"); setBusy(false); }
    else await reload();
  };
  const visiblePosts = channelId ? posts.filter((post) => post.channel_id === channelId) : posts;

  return <AppChrome title={club.name} userId={userId} backHref="/clubs" showBottomNav={false}><section className="club-detail-header"><div className="club-detail-cover">{club.cover_url ? <img src={club.cover_url} alt="" /> : null}</div><div className="club-detail-avatar">{club.icon_url ? <img src={club.icon_url} alt="" /> : <strong>{club.name.slice(0, 1)}</strong>}</div><div className="club-detail-copy"><h1>{club.name}</h1><p>{club.member_count.toLocaleString("th-TH")} สมาชิก{club.category ? ` · ${club.category}` : ""} {club.privacy === "private" ? <Lock size={13} /> : null}</p><button className={`club-detail-join ${membership ? "soft" : ""}`} type="button" disabled={busy || membership?.role === "owner"} onClick={() => void join()}>{membership?.role === "owner" ? "เจ้าของ Club" : membership?.status === "approved" ? "เป็นสมาชิกแล้ว" : membership?.status === "pending" ? "รออนุมัติ" : "เข้าร่วม"}</button>{error ? <p className="route-error">{error}</p> : null}</div></section><nav className="club-detail-tabs" aria-label="Club"><button className={tab === "posts" ? "active" : ""} onClick={() => setTab("posts")}>โพสต์</button><button className={tab === "chat" ? "active" : ""} onClick={() => setTab("chat")}>แชท</button><button className={tab === "about" ? "active" : ""} onClick={() => setTab("about")}>เกี่ยวกับ</button></nav>{tab === "posts" ? <section className="club-detail-body"><ChannelStrip channels={channels} value={channelId} onChange={setChannelId} /><PostList posts={visiblePosts} empty={club.privacy === "private" && membership?.status !== "approved" ? "เข้าร่วม Club เพื่อดูโพสต์" : "ยังไม่มีโพสต์ในห้องนี้"} /></section> : tab === "chat" ? <ChatTab client={client} userId={userId} membership={membership} channels={channels} /> : <AboutTabView client={client} clubId={clubId} club={club} membership={membership} />}</AppChrome>;
}

export function ClubDetailRoute({ clubId }: { clubId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ClubDetailInner client={client} userId={userId} clubId={clubId} />}</DeveloperRouteGate>;
}
