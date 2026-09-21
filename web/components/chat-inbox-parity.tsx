"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState, ProfileRowView } from "@/components/phase3-ui";
import { ChatListSkeleton } from "@/components/ui/skeleton";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { relativeTimeTh } from "@/lib/feed";
import { useOnlineUserIds } from "@/lib/presence";
import {
  acceptMessageRequest,
  chatAllowed,
  deleteMessageRequest,
  fetchInbox,
  fetchMessageRequests,
  searchProfiles,
  subscribeMyMessages,
  type ConversationRow,
  type ProfileRow,
} from "@/lib/phase3-data";

const NOTE_TEXT_KEY = "__wynos_note";
const NOTE_EXPIRES_KEY = "__wynos_note_expires_at";
const NOTE_MAX_LENGTH = 60;
const NOTE_LIFETIME_MS = 24 * 60 * 60 * 1000;

type ChatNoteProfile = {
  id: string;
  username: string;
  name: string;
  avatarUrl?: string | null;
  note?: string | null;
  noteExpiresAt?: string | null;
};

function conversationPreview(row: ConversationRow): string {
  if (row.last_message_deleted_at) return "ลบข้อความแล้ว";
  if (row.last_message_text?.trim()) return row.last_message_text;
  if (row.last_message_image_url) return "ส่งรูปภาพ";
  return row.status === "pending" ? "รอการตอบรับ" : "เริ่มบทสนทนา";
}

function isUnread(row: ConversationRow, userId: string): boolean {
  return Boolean(
    row.last_message_sender_id !== userId &&
      row.last_message_at &&
      (!row.my_last_read_at || new Date(row.last_message_at) > new Date(row.my_last_read_at)),
  );
}

function stringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result: Record<string, string> = {};
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if (typeof raw === "string") result[key] = raw;
  }
  return result;
}

function activeNote(links: Record<string, string>): { text: string; expiresAt: string } | null {
  const text = links[NOTE_TEXT_KEY]?.trim();
  const expiresAt = links[NOTE_EXPIRES_KEY];
  if (!text || !expiresAt) return null;
  const expires = Date.parse(expiresAt);
  if (!Number.isFinite(expires) || expires <= Date.now()) return null;
  return { text, expiresAt };
}

type ChatInboxData = {
  allowed: boolean;
  rows: ConversationRow[];
  requests: ConversationRow[];
  me: ChatNoteProfile | null;
  notes: ChatNoteProfile[];
};

async function fetchChatInboxData(client: SupabaseClient, userId: string): Promise<ChatInboxData> {
  const canChat = await chatAllowed(client);
  if (!canChat) return { allowed: false, rows: [], requests: [], me: null, notes: [] };

  const [inbox, pending] = await Promise.all([
    fetchInbox(client, 0),
    fetchMessageRequests(client, 0),
  ]);

  const ids = [...new Set([userId, ...inbox.map((row) => row.other_user_id)])];
  const profiles = ids.length
    ? await client
        .from("profiles")
        .select("id,username,display_name,avatar_url,social_links")
        .in("id", ids)
    : { data: [], error: null };

  if (profiles.error) throw new Error(profiles.error.message || "โหลดโน้ตไม่สำเร็จ");

  const mapped = (profiles.data ?? []).map((raw) => {
    const links = stringMap(raw.social_links);
    const note = activeNote(links);
    return {
      id: String(raw.id),
      username: String(raw.username ?? ""),
      name: String(raw.display_name ?? "").trim() || String(raw.username ?? "WYNOS"),
      avatarUrl: raw.avatar_url == null ? null : String(raw.avatar_url),
      note: note?.text ?? null,
      noteExpiresAt: note?.expiresAt ?? null,
    } satisfies ChatNoteProfile;
  });

  const me = mapped.find((profile) => profile.id === userId) ?? null;
  const notes = mapped.filter((profile) => profile.id !== userId && profile.note);

  return {
    allowed: true,
    rows: inbox,
    requests: pending as ConversationRow[],
    me,
    notes,
  };
}

async function writeMyNote(client: SupabaseClient, userId: string, text: string): Promise<void> {
  const current = await client.from("profiles").select("social_links").eq("id", userId).single();
  if (current.error) throw new Error(current.error.message || "โหลดโน้ตไม่สำเร็จ");

  const links = stringMap(current.data?.social_links);
  const normalized = text.trim();

  if (normalized) {
    links[NOTE_TEXT_KEY] = normalized.slice(0, NOTE_MAX_LENGTH);
    links[NOTE_EXPIRES_KEY] = new Date(Date.now() + NOTE_LIFETIME_MS).toISOString();
  } else {
    delete links[NOTE_TEXT_KEY];
    delete links[NOTE_EXPIRES_KEY];
  }

  const updated = await client.from("profiles").update({ social_links: links }).eq("id", userId);
  if (updated.error) throw new Error(updated.error.message || "บันทึกโน้ตไม่สำเร็จ");
}

function ChatInboxParityInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const onlineIds = useOnlineUserIds();
  const { data, isLoading: loading, error: loadError, refetch } = useQuery({
    queryKey: ["chat-inbox", userId] as const,
    queryFn: () => fetchChatInboxData(client, userId),
  });

  const allowed = data?.allowed ?? null;
  const rows = useMemo(() => data?.rows ?? [], [data?.rows]);
  const requests = data?.requests ?? [];
  const me = data?.me ?? null;
  const notes = data?.notes ?? [];

  useEffect(() => {
    if (allowed !== true) return;
    const channel: RealtimeChannel = subscribeMyMessages(client, userId, () => void refetch());
    return () => { void client.removeChannel(channel); };
  }, [client, userId, allowed, refetch]);

  const [activeTab, setActiveTab] = useState<"inbox" | "requests">("inbox");
  const [noteOpen, setNoteOpen] = useState(false);
  const [noteDraft, setNoteDraft] = useState("");
  const [noteSaving, setNoteSaving] = useState(false);
  const [query, setQuery] = useState("");
  const [actionError, setActionError] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const [composeOpen, setComposeOpen] = useState(false);
  const [composeQuery, setComposeQuery] = useState("");
  const [composePeople, setComposePeople] = useState<ProfileRow[]>([]);
  const [composeFinding, setComposeFinding] = useState(false);
  const error = actionError || (loadError instanceof Error ? loadError.message : "");

  const conversationByUserId = useMemo(
    () => new Map(rows.map((row) => [row.other_user_id, row] as const)),
    [rows],
  );

  const load = async () => { await refetch(); };

  const decide = async (row: ConversationRow, accept: boolean) => {
    try {
      if (accept) {
        await acceptMessageRequest(client, row.conversation_id);
      } else if (window.confirm("ลบคำขอข้อความนี้?")) {
        await deleteMessageRequest(client, row.conversation_id);
      } else {
        return;
      }
      await load();
      if (requests.length <= 1) setActiveTab("inbox");
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : "อัปเดตคำขอไม่สำเร็จ");
    }
  };

  const findComposePeople = async () => {
    const value = composeQuery.trim();
    if (value.length < 2) { setComposePeople([]); return; }
    setComposeFinding(true);
    try { setComposePeople((await searchProfiles(client, value, 0)).filter((profile) => profile.id !== userId)); }
    finally { setComposeFinding(false); }
  };

  const startConversation = async (profile: ProfileRow) => {
    setComposeFinding(true);
    setActionError("");
    try {
      if (!(await chatAllowed(client, profile.id))) throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้");
      setComposeOpen(false);
      router.push(`/chat/new?user=${encodeURIComponent(profile.id)}`);
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : "เริ่มแชทไม่สำเร็จ");
    } finally {
      setComposeFinding(false);
    }
  };

  const openMyNote = () => {
    setNoteDraft(me?.note ?? "");
    setNoteOpen(true);
    setActionError("");
  };

  const saveNote = async () => {
    const next = noteDraft.trim();
    if (!next) return;
    setNoteSaving(true);
    setActionError("");
    try {
      await writeMyNote(client, userId, next);
      setNoteOpen(false);
      await refetch();
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : "บันทึกโน้ตไม่สำเร็จ");
    } finally {
      setNoteSaving(false);
    }
  };

  const removeNote = async () => {
    setNoteSaving(true);
    setActionError("");
    try {
      await writeMyNote(client, userId, "");
      setNoteDraft("");
      setNoteOpen(false);
      await refetch();
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : "ลบโน้ตไม่สำเร็จ");
    } finally {
      setNoteSaving(false);
    }
  };

  const normalizedQuery = query.trim().toLocaleLowerCase("th-TH");
  const visibleRows = normalizedQuery
    ? rows.filter((row) => {
        const name = (row.other_display_name?.trim() || row.other_username).toLocaleLowerCase("th-TH");
        const username = row.other_username.toLocaleLowerCase("th-TH");
        const preview = conversationPreview(row).toLocaleLowerCase("th-TH");
        return name.includes(normalizedQuery) || username.includes(normalizedQuery) || preview.includes(normalizedQuery);
      })
    : rows;

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}>
      <section className="flutter-chat-inbox wyn-chat-inbox" aria-label="ข้อความ">
        <header className="flutter-chat-header">
          {/* Chat is a root bottom-nav tab (AppChrome forces the bottom nav
              visible on this route regardless of the showBottomNav prop
              above), so a persistent "back to home" control doesn't belong
              on its root screen -- matches every other root tab. Drilling
              into "คำขอข้อความ" below still gets its own back control,
              since that's a real sub-screen, not a root. */}
          {activeTab === "requests" ? (
            <button className="flutter-chat-header-action" type="button" aria-label="กลับ" onClick={() => setActiveTab("inbox")}>
              <WynosIcon name="back" size={26} strokeWidth={1.9} />
            </button>
          ) : <span />}
          <h1>{activeTab === "requests" ? "คำขอข้อความ" : "ข้อความ"}</h1>
          {activeTab === "requests" ? <span /> : (
            <div className="wyn-chat-header-actions">
              {/* Deliberately NOT .flutter-chat-header-action here (unlike
                  the back button above): pixel-parity-audit-closure.css
                  hardcodes that class to always render a back-arrow via a
                  CSS mask and hides its actual child <svg> -- a leftover
                  from when the class was exclusively the leading back
                  button. Reusing it for these two made both of them render
                  as back-arrows regardless of icon prop. */}
              <button className="wyn-chat-header-icon" type="button" aria-label="เขียนข้อความใหม่" onClick={() => setComposeOpen(true)}>
                <WynosIcon name="messageSquarePlus" size={22} strokeWidth={1.9} />
              </button>
              <div className="wyn-chat-menu-wrap">
                <button className="wyn-chat-header-icon" type="button" aria-label="เพิ่มเติม" aria-expanded={menuOpen} onClick={() => setMenuOpen((value) => !value)}>
                  <WynosIcon name="more" size={22} strokeWidth={1.9} />
                  {/* "คำขอ" moved off the persistent header (the approved
                      redesign has just two icon buttons here) and into this
                      menu -- this dot keeps it discoverable without a
                      permanent header badge. */}
                  {requests.length ? <span className="wyn-chat-menu-dot" aria-hidden="true" /> : null}
                </button>
                {menuOpen ? <>
                  <button className="wyn-chat-menu-backdrop" type="button" aria-label="ปิดเมนู" onClick={() => setMenuOpen(false)} />
                  <div className="wyn-chat-menu" role="menu">
                    <button type="button" role="menuitem" onClick={() => { setMenuOpen(false); setActiveTab("requests"); }}>
                      <WynosIcon name="messagesSquare" size={18} strokeWidth={1.9} />
                      <span>คำขอข้อความ</span>
                      {requests.length ? <b>{requests.length}</b> : null}
                    </button>
                  </div>
                </> : null}
              </div>
            </div>
          )}
        </header>

        <label className="flutter-chat-search">
          <WynosIcon name="search" size={24} strokeWidth={1.8} aria-hidden="true" />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="ค้นหาข้อความ"
            inputMode="search"
            aria-label="ค้นหาข้อความ"
          />
        </label>

        {!loading && allowed !== false && activeTab !== "requests" ? (
          <div className={`wyn-chat-notes ${notes.length ? "" : "is-solo"}`} aria-label="โน้ต">
            <button className="wyn-chat-note-card is-mine" type="button" onClick={openMyNote} aria-label={me?.note ? "แก้ไขโน้ตของคุณ" : "เพิ่มโน้ต"}>
              <span className={`wyn-chat-note-bubble ${me?.note ? "has-note" : "empty"}`}>
                {me?.note || "เพิ่มโน้ต"}
              </span>
              <span className="wyn-chat-note-avatar-wrap">
                <Avatar src={me?.avatarUrl} label={me?.username || "WYNOS"} size={62} />
                <span className="wyn-chat-note-plus"><WynosIcon name="post" size={15} strokeWidth={2.4} /></span>
              </span>
              <small>โน้ตของคุณ</small>
            </button>

            {notes.map((note) => {
              const conversation = conversationByUserId.get(note.id);
              const href = conversation
                ? `/chat/${conversation.conversation_id}?user=${encodeURIComponent(note.id)}`
                : `/profile/${note.id}`;
              return (
                <Link className="wyn-chat-note-card" href={href} key={note.id}>
                  <span className="wyn-chat-note-bubble has-note">{note.note}</span>
                  <span className="wyn-chat-note-avatar-wrap">
                    <Avatar src={note.avatarUrl} label={note.username} size={62} />
                    {onlineIds.has(note.id) ? <span className="wyn-chat-online-dot" aria-label="ออนไลน์" /> : null}
                  </span>
                  <small>{note.name}</small>
                </Link>
              );
            })}
          </div>
        ) : null}

        {loading ? (
          <ChatListSkeleton />
        ) : allowed === false ? (
          <div className="chat-locked-state">
            <strong>ระบบแชทปิดปรับปรุงชั่วคราว</strong>
            <small>จะเปิดให้ใช้งานได้เร็ว ๆ นี้</small>
          </div>
        ) : activeTab === "requests" ? (
          <>
            {error ? <p className="route-error route-pad">{error}</p> : null}
            {requests.length ? (
              <div className="chat-list">
                {requests.map((row) => (
                  <div className="request-row" key={row.conversation_id}>
                    <Link className="chat-row request-main" href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`}>
                      <Avatar src={row.other_avatar_url} label={row.other_username} size={48} />
                      <span className="chat-row-copy">
                        <strong>{row.other_display_name?.trim() || row.other_username}</strong>
                        <small>{conversationPreview(row)}</small>
                      </span>
                    </Link>
                    <div className="request-actions">
                      <button className="route-primary small" type="button" onClick={() => void decide(row, true)}>ยอมรับ</button>
                      <button className="route-secondary small" type="button" onClick={() => void decide(row, false)}>ลบ</button>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <EmptyState>ไม่มีคำขอข้อความ</EmptyState>
            )}
          </>
        ) : (
          <>
            {error ? <p className="route-error route-pad">{error}</p> : null}
            {visibleRows.length ? (
              <div className="chat-list flutter-chat-list">
                {visibleRows.map((row) => {
                  const unread = isUnread(row, userId);
                  return (
                    <Link
                      className={`chat-row ${unread ? "unread" : ""}`}
                      href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`}
                      key={row.conversation_id}
                    >
                      <span className="wyn-chat-row-avatar-wrap">
                        <Avatar src={row.other_avatar_url} label={row.other_username} size={54} />
                        {onlineIds.has(row.other_user_id) ? <span className="wyn-chat-online-dot" aria-label="ออนไลน์" /> : null}
                      </span>
                      <span className="chat-row-copy">
                        <strong>{row.other_display_name?.trim() || row.other_username}</strong>
                        <small>{conversationPreview(row)}</small>
                      </span>
                      <span className="flutter-chat-row-meta">
                        <span className="wyn-chat-meta-stack">
                          <time>{row.last_message_at ? relativeTimeTh(row.last_message_at) : ""}</time>
                          {unread ? <span className="wyn-chat-unread-dot" aria-label="ยังไม่อ่าน" /> : null}
                        </span>
                      </span>
                    </Link>
                  );
                })}
                <div className="wyn-chat-end-marker">
                  <span className="wyn-chat-end-marker-icon" aria-hidden="true">
                    <WynosIcon name="check" size={18} strokeWidth={2} />
                  </span>
                  <span>เห็นข้อความล่าสุดแล้ว</span>
                </div>
              </div>
            ) : (
              <EmptyState>{normalizedQuery ? "ไม่พบข้อความ" : "ยังไม่มีข้อความ"}</EmptyState>
            )}
          </>
        )}
      </section>

      {composeOpen ? (
        <div className="route-modal-backdrop" onClick={() => setComposeOpen(false)} role="presentation">
          <section className="route-modal" role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()}>
            <header>
              <strong>ข้อความใหม่</strong>
              <button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setComposeOpen(false)}>
                <WynosIcon name="close" size={24} strokeWidth={2} />
              </button>
            </header>
            <form className="search-route-form compact" onSubmit={(event) => { event.preventDefault(); void findComposePeople(); }}>
              <input autoFocus value={composeQuery} onChange={(event) => setComposeQuery(event.target.value)} placeholder="ค้นหา username" />
              <button className="route-pill" type="submit">ค้นหา</button>
            </form>
            {composeFinding && !composePeople.length ? <LoadingState /> : (
              <div className="route-list">
                {composePeople.map((profile) => (
                  <ProfileRowView
                    profile={profile}
                    key={profile.id}
                    trailing={<button className="route-pill" type="button" disabled={composeFinding} onClick={() => void startConversation(profile)}>ส่งข้อความ</button>}
                  />
                ))}
              </div>
            )}
          </section>
        </div>
      ) : null}

      {noteOpen ? (
        <div className="wyn-note-screen" role="presentation">
          <section className="wyn-note-composer" role="dialog" aria-modal="true" aria-label={me?.note ? "แก้ไขโน้ต" : "โน้ตใหม่"}>
            <header className="wyn-note-composer-header">
              <button className="wyn-note-close" type="button" aria-label="ปิด" onClick={() => setNoteOpen(false)}>
                <WynosIcon name="close" size={28} strokeWidth={1.9} />
              </button>
              <div className="wyn-note-title-wrap">
                <strong>{me?.note ? "แก้ไขโน้ต" : "โน้ตใหม่"}</strong>
                <small>แชร์ความคิดกับเพื่อนของคุณ</small>
              </div>
              <button
                className="wyn-note-share-top"
                type="button"
                disabled={noteSaving || !noteDraft.trim()}
                onClick={() => void saveNote()}
              >
                {noteSaving ? "กำลังแชร์…" : "แชร์"}
              </button>
            </header>

            <div className="wyn-note-stage">
              <div className="wyn-note-bubble-editor">
                <textarea
                  autoFocus
                  value={noteDraft}
                  maxLength={NOTE_MAX_LENGTH}
                  onChange={(event) => setNoteDraft(event.target.value)}
                  placeholder="บอกเลยว่าคิดอะไร..."
                  aria-label="ข้อความโน้ต"
                />
                <span className="wyn-note-counter">{noteDraft.length}/{NOTE_MAX_LENGTH}</span>
              </div>

              <div className="wyn-note-avatar-large">
                <Avatar src={me?.avatarUrl} label={me?.username || "WYNOS"} size={88} />
              </div>
            </div>

            <div className="wyn-note-info-card">
              <div className="wyn-note-info-row">
                <WynosIcon name="clock" size={19} strokeWidth={1.8} />
                <span><strong>แสดงเป็นเวลา 24 ชั่วโมง</strong><small>โน้ตของคุณจะหายไปโดยอัตโนมัติหลัง 24 ชั่วโมง</small></span>
              </div>
              <div className="wyn-note-info-row">
                <WynosIcon name="users" size={19} strokeWidth={1.8} />
                <span><strong>แสดงให้ผู้ติดตามที่คุณติดตามกลับ</strong><small>เฉพาะคนที่คุณติดตามกลับเท่านั้นที่เห็นโน้ตนี้</small></span>
              </div>
              <div className="wyn-note-info-row">
                <WynosIcon name="comment" size={19} strokeWidth={1.8} />
                <span><strong>แชร์ความรู้สึกได้สั้น ๆ</strong><small>ใช้โน้ตเพื่อบอกสถานะ ความรู้สึก หรืออะไรก็ได้</small></span>
              </div>
            </div>

            {me?.note ? (
              <button className="wyn-note-delete" type="button" disabled={noteSaving} onClick={() => void removeNote()}>
                ลบโน้ต
              </button>
            ) : null}
          </section>
        </div>
      ) : null}
    </AppChrome>
  );
}

export function ChatInboxParityRoute() {
  return (
    <DeveloperRouteGate>
      {({ client, userId }) => <ChatInboxParityInner client={client} userId={userId} />}
    </DeveloperRouteGate>
  );
}
