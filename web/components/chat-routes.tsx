"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState, ProfileRowView } from "@/components/phase3-ui";
import { Toast, useToast } from "@/components/ui/toast";
import { followButtonLabel } from "@/components/ui/follow-button-label";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { WyniiConversationHeader } from "@/components/wynii-chat";
import { relativeTimeTh } from "@/lib/feed";
import { predictFollowState, toggleAuthorFollow } from "@/lib/home-actions";
import { haptic } from "@/lib/haptics";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import {
  acceptMessageRequest,
  chatAllowed,
  deleteMessage,
  deleteMessageRequest,
  fetchConversationMeta,
  fetchInbox,
  fetchMessageRequests,
  fetchMessages,
  fetchProfileSummary,
  findExistingConversationId,
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
  type ProfileSummary,
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

function chatDayKey(value: string): string {
  const date = new Date(value);
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

function chatDateLabel(value: string): string {
  return new Intl.DateTimeFormat("th-TH-u-ca-gregory", { day: "numeric", month: "long", year: "numeric" }).format(new Date(value));
}

function chatTimeLabel(value: string): string {
  return new Intl.DateTimeFormat("th-TH", { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(value));
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
      // WYN-185 item 10: open the composer first -- getOrCreateConversation()
      // (which is what actually creates the conversation row/Message
      // Request) now only runs from inside the composer's own submit(),
      // triggered by an actual first send, not by tapping a person here.
      if (!(await chatAllowed(client, profile.id))) throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้");
      router.push(`/chat/new?user=${encodeURIComponent(profile.id)}`);
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
      actions={<button className="route-icon-button" type="button" aria-label="ข้อความใหม่" onClick={() => setNewOpen(true)}><WynosIcon name="messageSquarePlus" size={22} strokeWidth={2} /></button>}
    >
      {loading ? <LoadingState /> : allowed === false ? <EmptyState>Chat ยังไม่เปิดใช้งานสำหรับบัญชีนี้</EmptyState> : (
        <>
          <div className="chat-tabs flutter-chat-tabs"><button className={tab === "all" ? "active" : ""} type="button" onClick={() => setTab("all")}>ทั้งหมด</button><button className={tab === "unread" ? "active" : ""} type="button" onClick={() => setTab("unread")}>ยังไม่อ่าน</button></div>
          {requests.length ? <button className="message-requests-banner" type="button" onClick={() => setRequestsOpen(true)}><span><strong>คำขอข้อความ</strong><small>ข้อความจากคนที่ยังไม่ได้เชื่อมต่อกับคุณ</small></span><b>{requests.length}</b></button> : null}
          {error ? <p className="route-error route-pad">{error}</p> : null}
          {visibleRows.length ? <div className="chat-list">{visibleRows.map((row) => <Link className={`chat-row ${isUnread(row, userId) ? "unread" : ""}`} href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`} key={row.conversation_id}><Avatar src={row.other_avatar_url} label={row.other_username} size={48} /><span className="chat-row-copy"><strong>{row.other_display_name?.trim() || row.other_username}</strong><small>{conversationPreview(row)}{isUnread(row, userId) ? <i className="chat-inline-unread" /> : null}</small></span><time>{row.last_message_at ? relativeTimeTh(row.last_message_at) : ""}</time></Link>)}</div> : <EmptyState>{tab === "unread" ? "ไม่มีข้อความที่ยังไม่อ่าน" : "ยังไม่มีบทสนทนา"}</EmptyState>}
        </>
      )}

      {requestsOpen ? <div className="route-modal-backdrop" role="presentation" onClick={() => setRequestsOpen(false)}><section className="route-modal requests-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>คำขอข้อความ</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setRequestsOpen(false)}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header>{requests.length ? <div className="chat-list">{requests.map((row) => <div className="request-row" key={row.conversation_id}><Link className="chat-row request-main" href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`}><Avatar src={row.other_avatar_url} label={row.other_username} size={48} /><span className="chat-row-copy"><strong>{row.other_display_name?.trim() || row.other_username}</strong><small>{conversationPreview(row)}</small></span></Link><div className="request-actions"><button className="route-primary small" type="button" onClick={() => void decide(row, true)}>ยอมรับ</button><button className="route-secondary small" type="button" onClick={() => void decide(row, false)}>ลบ</button></div></div>)}</div> : <EmptyState>ไม่มีคำขอข้อความ</EmptyState>}</section></div> : null}

      {newOpen ? <div className="route-modal-backdrop" onClick={() => setNewOpen(false)} role="presentation"><section className="route-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>ข้อความใหม่</strong><button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setNewOpen(false)}><WynosIcon name="close" size={24} strokeWidth={2} /></button></header><form className="search-route-form compact" onSubmit={(e) => { e.preventDefault(); void findPeople(); }}><input autoFocus value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหา username" /><button className="route-pill" type="submit">ค้นหา</button></form>{finding && !people.length ? <LoadingState /> : <div className="route-list">{people.map((profile) => <ProfileRowView profile={profile} key={profile.id} trailing={<button className="route-pill" type="button" disabled={finding} onClick={() => void start(profile)}>ส่งข้อความ</button>} />)}</div>}</section></div> : null}
    </AppChrome>
  );
}

function MessageImage({ client, path }: { client: SupabaseClient; path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => { let live = true; void signedChatImage(client, path).then((value) => { if (live) setUrl(value); }); return () => { live = false; }; }, [client, path]);
  if (!url) return <span className="message-image-placeholder">กำลังโหลดรูป…</span>;
  return <Image className="message-image" src={url} alt="" width={280} height={330} sizes="280px" />;
}

type ConversationSnapshot = { other: ProfileRow | null; messages: MessageRow[]; meta: ConversationMeta | null; hasMore: boolean };

function ConversationInner({ client, userId, conversationId }: { client: SupabaseClient; userId: string; conversationId: string }) {
  const router = useRouter();
  const params = useSearchParams();
  const userFromUrl = params.get("user") || "";
  // WYN-185 item 10: /chat/new?user=<id> is a compose-only screen -- no
  // conversation/message request exists yet. One is only ever created
  // (via getOrCreateConversation, inside submit() below) the moment the
  // user actually sends their first message, not the moment they open the
  // composer.
  const isComposeMode = conversationId === "new";
  const cacheKey = `conversation:${userId}:${conversationId}`;
  const cached = getMountCache<ConversationSnapshot>(cacheKey);
  const [otherId, setOtherId] = useState(userFromUrl);
  const [other, setOther] = useState<ProfileRow | null>(cached?.other ?? null);
  const [otherSummary, setOtherSummary] = useState<ProfileSummary | null>(null);
  const [messages, setMessages] = useState<MessageRow[]>(cached?.messages ?? []);
  const [meta, setMeta] = useState<ConversationMeta | null>(cached?.meta ?? null);
  const [loading, setLoading] = useState(!cached);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [draft, setDraft] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [sending, setSending] = useState(false);
  const [followBusy, setFollowBusy] = useState(false);
  const [error, setError] = useState("");
  const [revealedMessageId, setRevealedMessageId] = useState<string | null>(null);
  const channelRef = useRef<RealtimeChannel | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const composerRef = useRef<HTMLFormElement | null>(null);
  const [composerHeight, setComposerHeight] = useState(58);
  const { toastMessage, showToast } = useToast();

  useEffect(() => {
    setMountCache(cacheKey, { other, messages, meta, hasMore });
  }, [cacheKey, other, messages, meta, hasMore]);

  // The composer is a multi-line textarea (WYN-031's spec: minLines 1,
  // maxLines ~6, capped by CSS max-height + overflow-y after that) instead
  // of a single-line input, so it grows with the draft's content — this
  // keeps the message list's bottom padding in sync so a tall composer
  // never covers the last bubble.
  useLayoutEffect(() => {
    const textarea = textareaRef.current;
    if (textarea) {
      textarea.style.height = "auto";
      textarea.style.height = `${textarea.scrollHeight}px`;
    }
    if (composerRef.current) setComposerHeight(composerRef.current.offsetHeight);
  }, [draft]);

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
        if (isComposeMode) {
          const id = await resolveOther();
          if (!id) throw new Error("ไม่พบผู้ใช้ที่จะเริ่มบทสนทนาด้วย");
          if (!(await chatAllowed(client, id))) throw new Error("ไม่สามารถเปิดบทสนทนานี้ได้");
          // Redirect straight into the real conversation if one already
          // exists (active, or a pending request either direction) instead
          // of showing a stale "start fresh" compose screen for it.
          const existingId = await findExistingConversationId(client, id);
          if (existingId) { if (live) router.replace(`/chat/${existingId}?user=${encodeURIComponent(id)}`); return; }
          const summary = await fetchProfileSummary(client, userId, id);
          if (live) { setOtherSummary(summary); setOther(summary?.profile ?? null); }
          return;
        }
        const id = await resolveOther();
        if (id) {
          if (!(await chatAllowed(client, id))) throw new Error("ไม่สามารถเปิดบทสนทนานี้ได้");
          const summary = await fetchProfileSummary(client, userId, id);
          if (live) {
            setOtherSummary(summary);
            setOther(summary?.profile ?? null);
          }
        }
        await refresh();
      } catch (e) { if (live) setError(e instanceof Error ? e.message : "โหลดบทสนทนาไม่สำเร็จ"); }
      finally { if (live) setLoading(false); }
    })();
    if (isComposeMode) return () => { live = false; };
    const channel = subscribeConversationMessages(client, conversationId, () => { void refresh(); });
    channelRef.current = channel;
    return () => { live = false; if (channelRef.current) void client.removeChannel(channelRef.current); };
  }, [client, conversationId, isComposeMode, refresh, resolveOther, router, userId]);

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
    if (isComposeMode && !otherId) return;
    const text = draft.trim();
    const attachedFile = file;
    const localPreviewUrl = attachedFile ? URL.createObjectURL(attachedFile) : null;
    const tempId = `pending-${Date.now()}`;
    const optimisticMessage: MessageRow = {
      id: tempId,
      conversation_id: conversationId,
      sender_id: userId,
      text: text || null,
      image_url: null,
      created_at: new Date().toISOString(),
      pending: true,
      localPreviewUrl,
    };
    setMessages((current) => [optimisticMessage, ...current]);
    setDraft(""); setFile(null); setSending(true); setError("");
    haptic();
    try {
      // WYN-185 item 10: the conversation (and, if the recipient doesn't
      // already follow the sender, the pending Message Request) is only
      // ever created here, at the moment of an actual first send -- never
      // just from opening the composer.
      const realConversationId = isComposeMode ? await getOrCreateConversation(client, otherId) : conversationId;
      const created = await sendMessage(client, userId, realConversationId, { text, file: attachedFile });
      if (isComposeMode) {
        // A full navigation (not just a state update) so the destination
        // mounts fresh against the real conversation id -- realtime
        // subscription, pagination, and the pending-request banner all
        // depend on that id being real.
        router.replace(`/chat/${realConversationId}?user=${encodeURIComponent(otherId)}`);
        return;
      }
      setMessages((current) => {
        const withoutTemp = current.filter((item) => item.id !== tempId);
        return withoutTemp.some((item) => item.id === created.id) ? withoutTemp : [created, ...withoutTemp];
      });
      await markConversationRead(client, realConversationId);
    } catch (e) {
      setMessages((current) => current.filter((item) => item.id !== tempId));
      setDraft(text); setFile(attachedFile);
      setError(e instanceof Error ? e.message : "ส่งข้อความไม่สำเร็จ");
      showToast("ส่งข้อความไม่สำเร็จ กู้คืนข้อความในกล่องข้อความแล้ว");
    } finally {
      setSending(false);
      if (localPreviewUrl) URL.revokeObjectURL(localPreviewUrl);
    }
  };

  const remove = async (message: MessageRow) => {
    if (message.sender_id !== userId || !window.confirm("ลบข้อความนี้?")) return;
    try { await deleteMessage(client, message); setMessages((current) => current.map((item) => item.id === message.id ? { ...item, text: null, image_url: null, deleted_at: new Date().toISOString() } : item)); }
    catch { setError("ลบข้อความไม่สำเร็จ"); }
  };

  const toggleFollow = async () => {
    if (!other || !otherSummary || followBusy) return;
    const wasFollowing = otherSummary.following;
    const wasRequested = otherSummary.requested;
    if (wasRequested && other.is_private && !window.confirm(`ยกเลิกคำขอติดตาม @${other.username}?`)) return;
    const next = predictFollowState({ currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate: other.is_private });
    if (!wasFollowing) haptic();
    setFollowBusy(true);
    setOtherSummary((current) => current ? { ...current, following: next === "following", requested: next === "requested" } : current);
    try {
      await toggleAuthorFollow(client, userId, other.id, { currentlyFollowing: wasFollowing, pendingRequest: wasRequested, isPrivate: other.is_private });
    } catch (e) {
      setOtherSummary((current) => current ? { ...current, following: wasFollowing, requested: wasRequested } : current);
      showToast(e instanceof Error ? e.message : "ติดตามไม่สำเร็จ");
    } finally {
      setFollowBusy(false);
    }
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

  const displayName = other?.display_name?.trim() || other?.username || "ข้อความ";
  const followLabel = followButtonLabel({ busy: followBusy, following: otherSummary?.following ?? false, requested: otherSummary?.requested ?? false });

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}>
      {loading && !messages.length && !other ? <LoadingState /> : (
        <div className="conversation-page conversation-modern">
          <header className="conversation-modern-header">
            <Link className="conversation-modern-back" href="/chat" aria-label="ย้อนกลับ"><WynosIcon name="back" size={30} strokeWidth={1.8} /></Link>
            {other && !isComposeMode ? <WyniiConversationHeader client={client} userId={userId} conversationId={conversationId} other={other} displayName={displayName} canStart={meta?.status === "active"} onOpenProfile={() => router.push(`/profile/${other.id}`)} /> : other ? (
              <><div className="conversation-modern-header-person"><Link href={`/profile/${other.id}`} aria-label={`ดูโปรไฟล์ ${displayName}`}><Avatar src={other.avatar_url} label={other.username} size={44} /></Link><span><Link href={`/profile/${other.id}`}><strong>{displayName}</strong></Link><small>@{other.username}</small></span></div><span /></>
            ) : <><span /><span /></>}
          </header>

          {/* Matches Instagram/LINE-style DM: the full profile-intro card
              (large avatar, "View Profile" + follow actions) is only for a
              brand-new, empty conversation. Once real messages exist, the
              sticky header's small avatar+name is enough -- keeping the
              hero around too just duplicates it and pushes the thread down. */}
          {other && !messages.length ? <section className="conversation-profile-hero">
            <Link className="conversation-profile-identity" href={`/profile/${other.id}`}>
              <Avatar src={other.avatar_url} label={other.username} size={112} />
              <strong>{displayName}</strong>
              <small>@{other.username}</small>
            </Link>
            <div className="conversation-profile-actions">
              <Link className="conversation-profile-button profile" href={`/profile/${other.id}`}><WynosIcon name="profile" size={24} strokeWidth={1.8} /><span>ดูโปรไฟล์</span></Link>
              {/* Already following: no button at all, same pattern as the
                  Home feed's follow pill (post-author-row.tsx) -- a
                  "following" state has nothing left to invite the viewer to
                  do here, and keeping a stale "+" icon next to "ติดตามแล้ว"
                  read as an unfinished action instead of a completed one. */}
              {!otherSummary?.following ? (
                <button
                  className={`conversation-profile-button follow ${otherSummary?.requested ? "soft" : ""}`}
                  type="button"
                  aria-pressed={Boolean(otherSummary?.requested)}
                  disabled={followBusy || !otherSummary}
                  onClick={() => void toggleFollow()}
                >
                  <WynosIcon name="circlePlus" size={24} strokeWidth={1.8} /><span>{followLabel}</span>
                </button>
              ) : null}
            </div>
          </section> : null}

          {hasMore ? <button className="route-more" type="button" disabled={loadingMore} onClick={() => void loadOlder()}>{loadingMore ? "กำลังโหลด…" : "ดูข้อความก่อนหน้า"}</button> : null}
          <div className="message-list conversation-thread" style={{ paddingBottom: composerHeight + 30 }}>
            {ordered.map((message, index) => {
              const mine = message.sender_id === userId;
              const canDelete = mine && !message.deleted_at && !message.pending;
              const revealed = canDelete && revealedMessageId === message.id;
              const previous = index > 0 ? ordered[index - 1] : null;
              const showDate = !previous || chatDayKey(previous.created_at) !== chatDayKey(message.created_at);
              const read = mine && Boolean(meta?.other_user_last_read_at && new Date(message.created_at) <= new Date(meta.other_user_last_read_at));
              return <div className="message-entry" key={message.id}>
                {showDate ? <div className="conversation-date-separator"><span>{chatDateLabel(message.created_at)}</span></div> : null}
                <div className={`message-row ${mine ? "mine" : "theirs"} ${message.pending ? "is-pending" : ""}`}>
                  {!mine && other ? <Avatar src={other.avatar_url} label={other.username} size={34} /> : null}
                  <div className="message-stack">
                    <div
                      className="message-bubble"
                      role={canDelete ? "button" : undefined}
                      tabIndex={canDelete ? 0 : undefined}
                      onClick={canDelete ? () => setRevealedMessageId((current) => current === message.id ? null : message.id) : undefined}
                    >
                      {message.deleted_at ? <i>ลบข้อความแล้ว</i> : <>
                        {message.reply_to_message_id && message.reply_to ? <div className="reply-preview">{message.reply_to.deleted_at ? "ข้อความถูกลบ" : message.reply_to.text || (message.reply_to.image_url ? "รูปภาพ" : "ข้อความ")}</div> : null}
                        {message.text ? <p>{message.text}</p> : null}
                        {message.localPreviewUrl ? <img className="message-image" src={message.localPreviewUrl} alt="" /> : message.image_url ? <MessageImage client={client} path={message.image_url} /> : null}
                      </>}
                    </div>
                    <div className="message-meta">
                      <time>{message.pending ? "กำลังส่ง…" : chatTimeLabel(message.created_at)}{message.edited_at ? " · แก้ไขแล้ว" : ""}</time>
                      {mine && !message.pending ? (
                        // WhatsApp/LINE-style receipt: single check = sent,
                        // double check in the accent color = read. The
                        // previous version rendered the identical glyph
                        // ("✓" either way) so sent vs read never actually
                        // differed on screen, only in the aria-label.
                        <span className={`message-read-status ${read ? "read" : ""}`} aria-label={read ? "อ่านแล้ว" : "ส่งแล้ว"}>
                          <WynosIcon name={read ? "checkCheck" : "check"} size={14} strokeWidth={2.4} />
                        </span>
                      ) : null}
                    </div>
                  </div>
                  {revealed ? <button className="message-delete" type="button" aria-label="ลบข้อความ" onClick={() => void remove(message)}><WynosIcon name="trash" size={13} strokeWidth={2} /></button> : null}
                </div>
              </div>;
            })}
          </div>
          {error ? <p className="route-error route-pad">{error}</p> : null}
          {recipientPending ? <div className="conversation-request-bar"><p>ยอมรับคำขอข้อความเพื่อสนทนาต่อ</p><div><button className="route-primary" type="button" onClick={() => void accept()}>ยอมรับ</button><button className="route-secondary" type="button" onClick={() => void decline()}>ลบ</button></div></div> : requesterPending ? <div className="conversation-request-bar"><p>ส่งคำขอข้อความแล้ว · รออีกฝ่ายตอบรับ</p></div> : (
            <form className="message-composer" ref={composerRef} onSubmit={(e) => { e.preventDefault(); void submit(); }}><label className="message-image-picker" aria-label="แนบรูปภาพ"><WynosIcon name="imagePlus" size={23} strokeWidth={2} /><input type="file" accept="image/*" hidden tabIndex={-1} disabled={sending} onChange={(e) => setFile(e.target.files?.[0] ?? null)} /></label><div className="message-input-group"><textarea ref={textareaRef} rows={1} value={draft} disabled={sending} onChange={(e) => setDraft(e.target.value)} placeholder={file ? `รูป: ${file.name}` : "พิมพ์ข้อความ..."} /><button type="submit" aria-label="ส่ง" disabled={sending || (!draft.trim() && !file)}><WynosIcon name="send" size={18} strokeWidth={2} /></button></div>{file ? <button className="message-clear-file" type="button" aria-label="ยกเลิกรูป" onClick={() => setFile(null)}><WynosIcon name="close" size={15} strokeWidth={2} /></button> : null}</form>
          )}
        </div>
      )}
      <Toast message={toastMessage} />
    </AppChrome>
  );
}

export function ChatRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <ChatInboxInner client={client} userId={userId} />}</DeveloperRouteGate>;
}

export function ConversationRoute({ conversationId }: { conversationId: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ConversationInner client={client} userId={userId} conversationId={conversationId} />}</DeveloperRouteGate>;
}
