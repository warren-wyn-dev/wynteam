"use client";

import { useQuery } from "@tanstack/react-query";
import { ChevronLeft, Pencil, X } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState, ProfileRowView } from "@/components/phase3-ui";
import { ChatListSkeleton } from "@/components/ui/skeleton";
import { relativeTimeTh } from "@/lib/feed";
import {
  acceptMessageRequest,
  chatAllowed,
  deleteMessageRequest,
  fetchInbox,
  fetchMessageRequests,
  getOrCreateConversation,
  searchProfiles,
  subscribeMyMessages,
  type ConversationRow,
  type ProfileRow,
} from "@/lib/phase3-data";

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

type ChatInboxData = { allowed: boolean; rows: ConversationRow[]; requests: ConversationRow[] };

async function fetchChatInboxData(client: SupabaseClient): Promise<ChatInboxData> {
  const canChat = await chatAllowed(client);
  if (!canChat) return { allowed: false, rows: [], requests: [] };
  const [inbox, pending] = await Promise.all([
    fetchInbox(client, 0),
    fetchMessageRequests(client, 0),
  ]);
  return { allowed: true, rows: inbox, requests: pending as ConversationRow[] };
}

function ChatInboxParityInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const { data, isLoading: loading, error: loadError, refetch } = useQuery({
    queryKey: ["chat-inbox", userId] as const,
    queryFn: () => fetchChatInboxData(client),
  });
  const allowed = data?.allowed ?? null;
  const rows = data?.rows ?? [];
  const requests = data?.requests ?? [];

  // Mirrors Flutter's ChatInboxScreen: any new message across any of this
  // user's conversations should update the list/preview/unread badge right
  // away, not just on next mount/refocus. Gated on `allowed` the same way
  // Flutter's _init() never subscribes for a locked-out account.
  useEffect(() => {
    if (allowed !== true) return;
    const channel: RealtimeChannel = subscribeMyMessages(client, userId, () => void refetch());
    return () => { void client.removeChannel(channel); };
  }, [client, userId, allowed, refetch]);

  const [tab, setTab] = useState<"all" | "unread">("all");
  const [requestsOpen, setRequestsOpen] = useState(false);
  const [newOpen, setNewOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [people, setPeople] = useState<ProfileRow[]>([]);
  const [finding, setFinding] = useState(false);
  const [actionError, setActionError] = useState("");
  const error = actionError || (loadError instanceof Error ? loadError.message : "");
  const setError = setActionError;

  const load = async () => { await refetch(); };

  const findPeople = async () => {
    const value = query.trim();
    if (value.length < 2) {
      setPeople([]);
      return;
    }
    setFinding(true);
    try {
      setPeople((await searchProfiles(client, value, 0)).filter((profile) => profile.id !== userId));
    } finally {
      setFinding(false);
    }
  };

  const start = async (profile: ProfileRow) => {
    setFinding(true);
    setError("");
    try {
      if (!(await chatAllowed(client, profile.id))) {
        throw new Error("ยังไม่สามารถส่งข้อความถึงบัญชีนี้ได้");
      }
      const id = await getOrCreateConversation(client, profile.id);
      router.push(`/chat/${id}?user=${encodeURIComponent(profile.id)}`);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "เริ่มแชทไม่สำเร็จ");
    } finally {
      setFinding(false);
    }
  };

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
      if (requests.length <= 1) setRequestsOpen(false);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "อัปเดตคำขอไม่สำเร็จ");
    }
  };

  const visibleRows = tab === "unread" ? rows.filter((row) => isUnread(row, userId)) : rows;
  const requestLabel = requests.length > 0 ? `คำขอ (${requests.length})` : "คำขอ";

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}>
      <section className="flutter-chat-inbox" aria-label="ข้อความ">
        <header className="flutter-chat-header">
          <Link className="flutter-chat-header-action" href="/" aria-label="ย้อนกลับ">
            <ChevronLeft size={26} strokeWidth={1.8} />
          </Link>
          <h1>ข้อความ</h1>
          <button
            className="flutter-chat-compose-action"
            type="button"
            aria-label="เขียนข้อความใหม่"
            onClick={() => setNewOpen(true)}
          >
            <Pencil size={18} strokeWidth={1.8} />
          </button>
        </header>

        {loading ? (
          <ChatListSkeleton />
        ) : allowed === false ? (
          <div className="chat-locked-state">
            <strong>ระบบแชทปิดปรับปรุงชั่วคราว</strong>
            <small>จะเปิดให้ใช้งานได้เร็ว ๆ นี้</small>
          </div>
        ) : (
          <>
            <div className="flutter-chat-pill-tabs" role="tablist" aria-label="ตัวกรองข้อความ">
              <button
                className={tab === "all" ? "active" : ""}
                type="button"
                role="tab"
                aria-selected={tab === "all"}
                onClick={() => setTab("all")}
              >
                ทั้งหมด
              </button>
              <button
                className={tab === "unread" ? "active" : ""}
                type="button"
                role="tab"
                aria-selected={tab === "unread"}
                onClick={() => setTab("unread")}
              >
                ยังไม่อ่าน
              </button>
              <button
                type="button"
                role="tab"
                aria-selected="false"
                onClick={() => setRequestsOpen(true)}
              >
                {requestLabel}
              </button>
            </div>

            {error ? <p className="route-error route-pad">{error}</p> : null}
            {visibleRows.length ? (
              <div className="chat-list flutter-chat-list">
                {visibleRows.map((row) => (
                  <Link
                    className={`chat-row ${isUnread(row, userId) ? "unread" : ""}`}
                    href={`/chat/${row.conversation_id}?user=${encodeURIComponent(row.other_user_id)}`}
                    key={row.conversation_id}
                  >
                    <Avatar src={row.other_avatar_url} label={row.other_username} size={48} />
                    <span className="chat-row-copy">
                      <strong>{row.other_display_name?.trim() || row.other_username}</strong>
                      <small>
                        {conversationPreview(row)}
                        {isUnread(row, userId) ? <i className="chat-inline-unread" /> : null}
                      </small>
                    </span>
                    <time>{row.last_message_at ? relativeTimeTh(row.last_message_at) : ""}</time>
                  </Link>
                ))}
              </div>
            ) : (
              <EmptyState>{tab === "unread" ? "ไม่มีบทสนทนาที่ยังไม่อ่าน" : "ยังไม่มีข้อความ"}</EmptyState>
            )}
          </>
        )}
      </section>

      {requestsOpen ? (
        <div className="route-modal-backdrop" role="presentation" onClick={() => setRequestsOpen(false)}>
          <section className="route-modal requests-modal" role="dialog" aria-modal="true" aria-label="คำขอข้อความ" onClick={(event) => event.stopPropagation()}>
            <header>
              <strong>คำขอข้อความ</strong>
              <button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setRequestsOpen(false)}><X size={20} /></button>
            </header>
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
          </section>
        </div>
      ) : null}

      {newOpen ? (
        <div className="route-modal-backdrop" onClick={() => setNewOpen(false)} role="presentation">
          <section className="route-modal chat-new-message-modal" role="dialog" aria-modal="true" aria-label="ข้อความใหม่" onClick={(event) => event.stopPropagation()}>
            <header>
              <strong>ข้อความใหม่</strong>
              <button className="route-icon-button" type="button" aria-label="ปิด" onClick={() => setNewOpen(false)}><X size={20} /></button>
            </header>
            <form className="search-route-form compact" onSubmit={(event) => { event.preventDefault(); void findPeople(); }}>
              <input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหา username" />
              <button className="route-pill" type="submit">ค้นหา</button>
            </form>
            {finding && !people.length ? <LoadingState /> : (
              <div className="route-list">
                {people.map((profile) => (
                  <ProfileRowView
                    profile={profile}
                    key={profile.id}
                    trailing={<button className="route-pill" type="button" disabled={finding} onClick={() => void start(profile)}>ส่งข้อความ</button>}
                  />
                ))}
              </div>
            )}
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
