"use client";

import { CheckCheck, Heart, MessageCircle, Repeat2, UserPlus } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { relativeTimeTh } from "@/lib/feed";
import { fetchNotifications, markAllNotificationsRead, type NotificationRow } from "@/lib/phase3-data";

function messageFor(row: NotificationRow): string {
  const actor = row.actor_display_name?.trim() || (row.actor_username ? `@${row.actor_username}` : "WYNOS");
  switch (row.type) {
    case "like_drop": return `${actor} ถูกใจโพสต์ของคุณ`;
    case "comment_drop": return `${actor} แสดงความคิดเห็นในโพสต์ของคุณ`;
    case "follow": return `${actor} เริ่มติดตามคุณ`;
    case "follow_request": return `${actor} ส่งคำขอติดตามคุณ`;
    case "follow_request_accepted": return `${actor} ยอมรับคำขอติดตามของคุณ`;
    case "redrop": return `${actor} รีโพสต์โพสต์ของคุณ`;
    case "mention_drop": return `${actor} กล่าวถึงคุณในโพสต์`;
    case "mention_club_post": return `${actor} กล่าวถึงคุณใน Club`;
    case "club_join_request": return `${actor} ขอเข้าร่วม ${row.club_name || "Club"}`;
    case "club_join_approved": return `คำขอเข้าร่วม ${row.club_name || "Club"} ได้รับอนุมัติแล้ว`;
    case "club_post_like": return `${actor} ถูกใจโพสต์ใน ${row.club_name || "Club"}`;
    case "club_post_comment": return `${actor} แสดงความคิดเห็นใน ${row.club_name || "Club"}`;
    case "club_post_new": return `มีโพสต์ใหม่ใน ${row.club_name || "Club"}`;
    case "club_post_pinned": return `มีโพสต์ปักหมุดใหม่ใน ${row.club_name || "Club"}`;
    case "club_invite": return `${actor} เชิญคุณเข้าร่วม ${row.club_name || "Club"}`;
    case "message_request": return `${actor} ส่งคำขอข้อความถึงคุณ`;
    case "moderation_warning": return row.reason || "คุณได้รับคำเตือนจาก WYNOS";
    case "moderation_content_removed": return row.reason || "เนื้อหาของคุณถูกนำออก";
    case "appeal_approved": return "คำอุทธรณ์ของคุณได้รับการอนุมัติ";
    case "appeal_rejected": return "คำอุทธรณ์ของคุณไม่ได้รับการอนุมัติ";
    case "system": return row.reason || "ประกาศจาก WYNOS";
    default: return `${actor} มีกิจกรรมใหม่`;
  }
}

function TypeIcon({ type }: { type: string }) {
  if (type.includes("like")) return <Heart size={13} />;
  if (type === "redrop") return <Repeat2 size={13} />;
  if (type.includes("follow")) return <UserPlus size={13} />;
  return <MessageCircle size={13} />;
}

function NotificationsInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [rows, setRows] = useState<NotificationRow[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [marking, setMarking] = useState(false);

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      const next = await fetchNotifications(client, nextPage);
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 30);
    } finally { setLoading(false); }
  }, [client]);
  useEffect(() => { void load(0, false); }, [load]);

  const markAll = async () => {
    setMarking(true);
    try {
      await markAllNotificationsRead(client, userId);
      setRows((current) => current.map((row) => ({ ...row, is_read: true })));
    } finally { setMarking(false); }
  };

  const open = (row: NotificationRow) => {
    if (row.conversation_id) { router.push(`/chat/${row.conversation_id}${row.actor_id ? `?user=${encodeURIComponent(row.actor_id)}` : ""}`); return; }
    if (row.drop_id) { router.push(`/drop/${row.drop_id}`); return; }
    if (row.club_post_id) { router.push(`/club-post/${row.club_post_id}`); return; }
    if (row.club_id) { router.push(`/club/${row.club_id}`); return; }
    if (row.actor_id) router.push(`/profile/${row.actor_id}`);
  };

  return (
    <AppChrome
      title="การแจ้งเตือน"
      userId={userId}
      actions={<button className="route-icon-button" type="button" aria-label="อ่านทั้งหมด" disabled={marking || !rows.some((row) => !row.is_read)} onClick={() => void markAll()}><CheckCheck size={21} /></button>}
    >
      {loading && !rows.length ? <LoadingState /> : !rows.length ? <EmptyState>ยังไม่มีการแจ้งเตือน</EmptyState> : (
        <div className="notification-list">
          {rows.map((row) => (
            <button className={`notification-row ${row.is_read ? "" : "unread"}`} type="button" onClick={() => open(row)} key={row.id}>
              <span className="notification-avatar-wrap"><Avatar src={row.actor_avatar_url} label={row.actor_username || "WYNOS"} /><span className="notification-type-icon"><TypeIcon type={row.type} /></span></span>
              <span className="notification-copy"><strong>{messageFor(row)}</strong>{row.content_preview ? <small className="notification-preview">{row.content_preview}</small> : null}<small>{relativeTimeTh(row.created_at)}</small></span>
              {!row.is_read ? <i className="notification-dot" /> : null}
            </button>
          ))}
          {hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}
        </div>
      )}
    </AppChrome>
  );
}

export function NotificationsRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <NotificationsInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
