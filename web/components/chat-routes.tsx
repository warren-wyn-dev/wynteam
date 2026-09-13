"use client";

import { ImagePlus, MessageSquarePlus, Send, Trash2, X } from "lucide-react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState, ProfileRowView } from "@/components/phase3-ui";
import { relativeTimeTh } from "@/lib/feed";
import {
  acceptMessageRequest,
  chatAllowed,
  deleteMessage,
  deleteMessageRequest,
  fetchConversationMeta,
  fetchInbox,
  fetchMessageRequests,
  fetchMessages,
  fetchProfile,
  getOrCreateConversation,
  markConversationRead,
  searchProfiles,
  sendMessage,
  signedChatImage,
  subscribeConversationMessages,
  type ConversationMeta,
  type ConversationRow,
  type MessageRow,
  type ProfileRow,
} from "@/lib/phase3-data";

function conversationPreview(row: ConversationRow): string {
  if (row.last_message_deleted_at) return "ลบข้อความแล้ว";
  if (row.last_message_text?.trim()) return row.last_message_text;
  if (row.last_message_image_url) return "ส่งรูปภาพ";
  return row.status === "pending" ? "รอการตอบรับ" : "เริ่มบทสนทนา";
}

function isUnread(row: ConversationRow, userId: string): boolean {
  return Boolean(row.last_message_sender_id !== userId && row.last_message_at && (!row.my_last_read_at || new Date(row.last_message_at) > new Date(row.my_last_read_at)));
}

function ChatInboxInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [rows, setRows] = useState<ConversationRow[]>([]);
  const [requests, setRequests] = useState<ConversationRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"all" | "unread">("all");
  const [requestsOpen, setRequestsOpen] = useState(false);
  const [newOpen, setNewOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [people, setPeople] = useState<ProfileRow[]>([]);
  const [finding, setFinding] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const canChat = await chatAllowed(client);
      setAllowed(canChat);
      if (!canChat) { setRows([]); setRequests([]); return; }
      const [inbox, pending] = await Promise.all([fetchInbox(client, 0), fetchMessageRequests(client, 0)]);
      setRows(inbox);
      setRequests(pending as ConversationRow[]);
    } catch (e) { setError(e instanceof Error ? e.message : "โหลด Chat ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client]);
  useEffect(() => { void load(); }, [load]);

  const findPeople = async () => {
    const value = query.trim();
    if (value.length < 2) { setPeople([]); return; }
    setFinding(true);
    try { setPeople((await searchProfiles(client, value, 0)).filter((profile) => profile.id !== userId)); }
    finally { setFinding(false); }
  };

  const start = async (profile: ProfileRow) => {
    setFinding(true); setError("");
    try {
      if (!(await chatAllowed(client, profile.id))) throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้");
      const id = await getOrCreateConversation(client, profile.id);
      router.push(`/chat/${id}?user=${encodeURIComponent(profile.id)}`);
    } catch (e) { setError(e instanceof Error ? e.message : "เริ่มแชทไม่สำเร็จ"); }
    finally { setFinding(false); }
  };

  const decide = async (row: ConversationRow, accept: boolean) => {
    try {
      if (accept) await acceptMessageRequest(client, row.conversation_id);
      else if (window.confirm("ลบคำขอข้อความนี้?")) await deleteMessageRequest(client, row.conversation_id);
      else return;
      await load();
      if (requests.length <= 1) setRequestsOpen(false);
    } catch (e) { setError(e instanceof Error ? e.message : "อัปเดตคำขอไม่สำเร็จ"); }
  };

  const visibleRows = tab === "unread" ? rows.filter((row) => isUnread(row, userId)) : rows;

  return (
    <AppChrome
      title="Chat"
      userId={userId}
      backHref="/"
      showBottomNav={false}
      actions={<button className="route-icon-button" type="button" aria-label="ข้อความใหม่" onClick={() => setNewOpen(true)}><MessageSquarePlus size={22} /></button>}
    >
      {loading ? <LoadingState /> : allowed === false ? <EmptyState>Chat ยังไม่เปิดใช้งานสำหรับบัญชีนี้</EmptyState> : (
        <>
          <div className="chat-tabs flutter-chat-tabs"><button className={tab === "all" ? "active" : ""} type="button" onClick={() => setTab("all")}>ทั้งหมด</button><button className={tab === "unread" ? "active" : ""} type="button" onClick={() => setTab("unread")}>ยังไม่อ่าน</button></div>
          {requests.length ? <button className="message-requests-banner" type="button" onClick={() => setRequestsOpen(true)}><span><strong>คำขอข้อความ</strong><small>ข้อความจากคนที่ยังไม่ได้เชื่อมต่อกับคุณ</small></span><b>{requests.length}</b></button> : null}
          {error ? <p className="route-error route-pad">{error}</p> : null}
          {visibleRows.length ? <div className="chat-list">{visibleRows.map((row) => <Link className={`chat-row ${isUnread(row, userId) ? "unread" : ""}`} href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`} key={row.conversation_id}><Avatar src={row.other_avatar_url} label={row.other_username} size={48} /><span className="chat-row-copy"><strong>{row.other_display_name?.trim() || row.other_username}</strong><small>{conversationPreview(row)}{isUnread(row, userId) ? <i className="chat-inline-unread" /> : null}</small></span><time>{row.last_message_at ? relativeTimeTh(row.last_message_at) : ""}</time></Link>)}</div> : <EmptyState>{tab === "unread" ? "ไม่มีข้อความที่ยังไม่อ่าน" : "ยังไม่มีบทสนทนา"}</EmptyState>}
        </>
      )}

      {requestsOpen ? <div className="route-modal-backdrop" role="presentation" onClick={() => setRequestsOpen(false)}><section className="route-modal requests-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>คำขอข้อความ</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setRequestsOpen(false)}><X size={20} /></button></header>{requests.length ? <div className="chat-list">{requests.map((row) => <div className="request-row" key={row.conversation_id}><Link className="chat-row request-main" href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`}><Avatar src={row.other_avatar_url} label={row.other_username} size={48} /><span className="chat-row-copy"><strong>{row.other_display_name?.trim() || row.other_username}</strong><small>{conversationPreview(row)}</small></span></Link><div className="request-actions"><button className="route-primary small" type="button" onClick={() => void decide(row, true)}>ยอมรับ</button><button className="route-secondary small" type="button" onClick={() => void decide(row, false)}>ลบ</button></div></div>)}</div> : <EmptyState>ไม่มีคำขอข้อความ</EmptyState>}</section></div> : null}

      {newOpen ? <div className="route-modal-backdrop" onClick={() => setNewOpen(false)} role="presentation"><section className="route-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>ข้อความใหม่</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setNewOpen(false)}><X /></button></header><form className="search-route-form compact" onSubmit={(e) => { e.preventDefault(); void findPeople(); }}><input autoFocus value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหา username" /><button className="route-pill" type="submit">ค้นหา</button></form>{finding && !people.length ? <LoadingState /> : <div className="route-list">{people.map((profile) => <ProfileRowView profile={profile} key={profile.id} trailing={<button className="route-pill" type="button" disabled={finding} onClick={() => void start(profile)}>ส่งข้อความ</button>} />)}</div>}</section></div> : null}
    </AppChrome>
  );
}

function MessageImage({ client, path }: { client: SupabaseClient; path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => { let live = true; void signedChatImage(client, path).then((value) => { if (live) setUrl(value); }); return () => { live = false; }; }, [client, path]);
  if (!url) return <span className="message-image-placeholder">กำลังโหลดรูป…</span>;
  return <img className="message-image" src={url} alt="" />;
}

function ConversationInner({ client, userId, conversationId }: { client: SupabaseClient; userId: string; conversationId: string }) {
  const router = useRouter();
  const params = useSearchParams();
  const userFromUrl = params.get("user") || "";
  const [otherId, setOtherId] = useState(userFromUrl);
  const [other, setOther] = useState<ProfileRow | null>(null);
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [meta, setMeta] = useState<ConversationMeta | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [draft, setDraft] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const channelRef = useRef<RealtimeChannel | null>(null);

  const resolveOther = useCallback(async (): Promise<string> => {
    if (otherId) return otherId;
    const result = await client.from("chat_inbox").select("other_user_id").eq("conversation_id", conversationId).maybeSingle();
    if (result.error) throw result.error;
    const id = result.data?.other_user_id ? String(result.data.other_user_id) : "";
    setOtherId(id);
    return id;
  }, [client, conversationId, otherId]);

  const refresh = useCallback(async () => {
    const [nextMessages, nextMeta] = await Promise.all([
      fetchMessages(client, conversationId),
      fetchConversationMeta(client, userId, conversationId),
    ]);
    setMessages(nextMessages);
    setMeta(nextMeta);
    setHasMore(nextMessages.length === 30);
    await markConversationRead(client, conversationId);
  }, [client, conversationId, userId]);

  useEffect(() => {
    let live = true;
    setLoading(true);
    void (async () => {
      try {
        const id = await resolveOther();
        if (id) {
          if (!(await chatAllowed(client, id))) throw new Error("ไม่สามารถเปิดบทสนทนานี้ได้");
          const profile = await fetchProfile(client, id);
          if (live) setOther(profile);
        }
        await refresh();
      } catch (e) { if (live) setError(e instanceof Error ? e.message : "โหลดบทสนทนาไม่สำเร็จ"); }
      finally { if (live) setLoading(false); }
    })();
    const channel = subscribeConversationMessages(client, conversationId, () => { void refresh(); });
    channelRef.current = channel;
    return () => { live = false; if (channelRef.current) void client.removeChannel(channelRef.current); };
  }, [client, conversationId, refresh, resolveOther]);

  const loadOlder = async () => {
    const oldest = messages[messages.length - 1];
    if (!oldest || loadingMore) return;
    setLoadingMore(true);
    try {
      const older = await fetchMessages(client, conversationId, oldest.created_at);
      setMessages((current) => [...current, ...older.filter((item) => !current.some((existing) => existing.id === item.id))]);
      setHasMore(older.length === 30);
    } finally { setLoadingMore(false); }
  };

  const submit = async () => {
    if (sending || (!draft.trim() && !file)) return;
    setSending(true); setError("");
    try {
      const created = await sendMessage(client, userId, conversationId, { text: draft, file });
      setMessages((current) => current.some((item) => item.id === created.id) ? current : [created, ...current]);
      setDraft(""); setFile(null);
      await markConversationRead(client, conversationId);
    } catch (e) { setError(e instanceof Error ? e.message : "ส่งข้อความไม่สำเร็จ"); }
    finally { setSending(false); }
  };

  const remove = async (message: MessageRow) => {
    if (message.sender_id !== userId || !window.confirm("ลบข้อความนี้?")) return;
    try { await deleteMessage(client, message); setMessages((current) => current.map((item) => item.id === message.id ? { ...item, text: null, image_url: null, deleted_at: new Date().toISOString() } : item)); }
    catch { setError("ลบข้อความไม่สำเร็จ"); }
  };

  const recipientPending = meta?.status === "pending" && meta.requested_by !== userId;
  const requesterPending = meta?.status === "pending" && meta.requested_by === userId;
  const ordered = useMemo(() => [...messages].reverse(), [messages]);

  const accept = async () => {
    try { await acceptMessageRequest(client, conversationId); await refresh(); }
    catch { setError("ยอมรับคำขอไม่สำเร็จ"); }
  };
  const decline = async () => {
    if (!window.confirm("ลบคำขอข้อความนี้?")) return;
    try { await deleteMessageRequest(client, conversationId); router.replace("/chat"); }
    catch { setError("ลบคำขอไม่สำเร็จ"); }
  };

  return (
    <AppChrome title={other?.display_name?.trim() || other?.username || "ข้อความ"} userId={userId} backHref="/chat" showBottomNav={false}>
      {loading ? <LoadingState /> : (
        <div className="conversation-page">
          {other ? <Link className="conversation-person" href={`/profile/${other.id}`}><Avatar src={other.avatar_url} label={other.username} /><span><strong>{other.display_name?.trim() || other.username}</strong><small>@{other.username}</small></span></Link> : null}
          {hasMore ? <button className="route-more" type="button" disabled={loadingMore} onClick={() => void loadOlder()}>{loadingMore ? "กำลังโหลด…" : "ดูข้อความก่อนหน้า"}</button> : null}
          <div className="message-list">
            {ordered.map((message) => {
              const mine = message.sender_id === userId;
              return <div className={`message-row ${mine ? "mine" : "theirs"}`} key={message.id}><div className="message-bubble">{message.deleted_at ? <i>ลบข้อความแล้ว</i> : <>{message.reply_to_message_id && message.reply_to ? <div className="reply-preview">{message.reply_to.deleted_at ? "ข้อความถูกลบ" : message.reply_to.text || (message.reply_to.image_url ? "รูปภาพ" : "ข้อความ")}</div> : null}{message.text ? <p>{message.text}</p> : null}{message.image_url ? <MessageImage client={client} path={message.image_url} /> : null}</>}<time>{relativeTimeTh(message.created_at)}{message.edited_at ? " · แก้ไขแล้ว" : ""}</time></div>{mine && !message.deleted_at ? <button className="message-delete" type="button" aria-label="ลบข้อความ" onClick={() => void remove(message)}><Trash2 size={13} /></button> : null}</div>;
            })}
          </div>
          {error ? <p className="route-error route-pad">{error}</p> : null}
          {recipientPending ? <div className="conversation-request-bar"><p>ยอมรับคำขอข้อความเพื่อสนทนาต่อ</p><div><button className="route-primary" type="button" onClick={() => void accept()}>ยอมรับ</button><button className="route-secondary" type="button" onClick={() => void decline()}>ลบ</button></div></div> : requesterPending ? <div className="conversation-request-bar"><p>ส่งคำขอข้อความแล้ว · รออีกฝ่ายตอบรับ</p></div> : (
            <form className="message-composer" onSubmit={(e) => { e.preventDefault(); void submit(); }}><label className="message-image-picker"><ImagePlus size={21} /><input type="file" accept="image/*" hidden disabled={sending} onChange={(e) => setFile(e.target.files?.[0] ?? null)} /></label><input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={file ? `รูป: ${file.name}` : "ข้อความ…"} /><button type="submit" aria-label="ส่ง" disabled={sending || (!draft.trim() && !file)}><Send size={20} /></button>{file ? <button className="message-clear-file" type="button" aria-label="ยกเลิกรูป" onClick={() => setFile(null)}><X size={15} /></button> : null}</form>
          )}
        </div>
      )}
    </AppChrome>
  );
}

export function ChatRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <ChatInboxInner client={client} userId={userId} />}</DeveloperRouteGate>;
}

export function ConversationRoute({ conversationId }: { conversationId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ConversationInner client={client} userId={userId} conversationId={conversationId} />}</DeveloperRouteGate>;
}
