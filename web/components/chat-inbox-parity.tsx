"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { useRouteRefreshListener } from "@/components/route-refresh-runtime";
import { AppChrome, Avatar, EmptyState } from "@/components/phase3-ui";
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
  subscribeMyMessages,
  type ConversationRow,
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

type ChatInboxData = {
  allowed: boolean;
  rows: ConversationRow[];
  requests: ConversationRow[];
};

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
  const onlineIds = useOnlineUserIds();
  const { data, isLoading: loading, error: loadError, refetch } = useQuery({
    queryKey: ["chat-inbox", userId] as const,
    queryFn: () => fetchChatInboxData(client),
    // React Query paints cached inbox immediately on tab revisit, then
    // revalidates messages/unread indicators missed while this route was offscreen.
    refetchOnMount: "always",
  });

  const allowed = data?.allowed ?? null;
  const rows = useMemo(() => data?.rows ?? [], [data?.rows]);
  const requests = data?.requests ?? [];

  const refreshInbox = useCallback(() => { void refetch(); }, [refetch]);
  useRouteRefreshListener(refreshInbox);

  useEffect(() => {
    if (allowed !== true) return;
    const channel: RealtimeChannel = subscribeMyMessages(client, userId, () => void refetch());
    return () => { void client.removeChannel(channel); };
  }, [client, userId, allowed, refetch]);

  const [activeTab, setActiveTab] = useState<"inbox" | "requests">("inbox");
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [actionError, setActionError] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const error = actionError || (loadError instanceof Error ? loadError.message : "");

  const closeSearch = () => { setSearchOpen(false); setQuery(""); };

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
                  button. Reusing it for these made them render as
                  back-arrows regardless of icon prop. */}
              <button
                className={`wyn-chat-header-icon ${searchOpen ? "is-active" : ""}`}
                type="button"
                aria-label="ค้นหาข้อความ"
                aria-pressed={searchOpen}
                onClick={() => (searchOpen ? closeSearch() : setSearchOpen(true))}
              >
                <WynosIcon name="search" size={21} strokeWidth={1.9} />
              </button>
              <div className="wyn-chat-menu-wrap">
                <button className="wyn-chat-header-icon" type="button" aria-label="เพิ่มเติม" aria-expanded={menuOpen} onClick={() => setMenuOpen((value) => !value)}>
                  <WynosIcon name="more" size={22} strokeWidth={1.9} />
                  {/* "คำขอ" moved off the persistent header (the approved
                      redesign has just icon buttons here) and into this
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

        {searchOpen && activeTab !== "requests" ? (
          <label className="flutter-chat-search">
            <WynosIcon name="search" size={24} strokeWidth={1.8} aria-hidden="true" />
            <input
              autoFocus
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="ค้นหาข้อความ"
              inputMode="search"
              aria-label="ค้นหาข้อความ"
            />
            <button className="flutter-chat-search-clear" type="button" aria-label="ปิดการค้นหา" onClick={closeSearch}>
              <WynosIcon name="close" size={16} strokeWidth={2.2} />
            </button>
          </label>
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
    </AppChrome>
  );
}

export function ChatInboxParityRoute() {
  return (
    <DeveloperRouteGate>
      {({ client, userId }) => <ChatInboxParityInner key={userId} client={client} userId={userId} />}
    </DeveloperRouteGate>
  );
}
