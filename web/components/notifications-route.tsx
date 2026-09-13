"use client";

import { Bookmark, Compass, Heart, Menu, MessageCircle, Plus, Repeat2, Search, UserPlus, UsersRound, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
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
    case "follow_request": return `${actor} ขอติดตามคุณ`;
    case "follow_request_accepted": return `${actor} ยอมรับคำขอติดตามของคุณแล้ว`;
    case "redrop": return `${actor} รีโพสต์โพสต์ของคุณ`;
    case "mention_drop": return `${actor} กล่าวถึงคุณในโพสต์`;
    case "mention_club_post": return `${actor} กล่าวถึงคุณในโพสต์ที่ ${row.club_name || "Club"}`;
    case "club_join_request": return `${actor} ขอเข้าร่วม ${row.club_name || "Club"} ของคุณ`;
    case "club_join_approved": return `${actor} อนุมัติคำขอเข้าร่วม ${row.club_name || "Club"} ของคุณแล้ว`;
    case "club_post_like": return `${actor} ถูกใจโพสต์ของคุณใน ${row.club_name || "Club"}`;
    case "club_post_comment": return `${actor} แสดงความคิดเห็นในโพสต์ของคุณใน ${row.club_name || "Club"}`;
    case "club_post_new": return `${actor} โพสต์ใหม่ใน ${row.club_name || "Club"}`;
    case "club_post_pinned": return `${actor} ปักหมุดโพสต์ใหม่ใน ${row.club_name || "Club"}`;
    case "club_invite": return `${actor} ชวนคุณเข้าร่วม ${row.club_name || "Club"}`;
    case "message_request": return `${actor} ส่งคำขอข้อความถึงคุณ`;
    case "new_message": return `${actor} ส่งข้อความถึงคุณ`;
    case "moderation_warning": return row.reason ? `คุณได้รับคำเตือนจากทีมงาน WYN: ${row.reason}` : "คุณได้รับคำเตือนจากทีมงาน WYN";
    case "moderation_content_removed": return row.reason ? `เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN — เหตุผล: ${row.reason}` : "เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN";
    case "appeal_approved": return "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว";
    case "appeal_rejected": return row.reason ? `อุทธรณ์ของคุณถูกปฏิเสธ — เหตุผล: ${row.reason}` : "อุทธรณ์ของคุณถูกปฏิเสธ";
    case "system": return row.reason || "มีประกาศจากระบบ WYN";
    default: return `${actor} มีกิจกรรมใหม่`;
  }
}

function TypeIcon({ type }: { type: string }) {
  if (type.includes("like")) return <Heart size={13} />;
  if (type === "redrop") return <Repeat2 size={13} />;
  if (type.includes("follow")) return <UserPlus size={13} />;
  return <MessageCircle size={13} />;
}

function isMention(row: NotificationRow) {
  return row.type === "mention_drop" || row.type === "mention_club_post";
}

function NotificationsInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [rows, setRows] = useState<NotificationRow[]>([]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"all" | "mentions">("all");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const unreadSnapshot = useRef<Set<string>>(new Set());

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      const next = await fetchNotifications(client, nextPage);
      if (!append) unreadSnapshot.current = new Set(next.filter((row) => !row.is_read).map((row) => row.id));
      else for (const row of next) if (!row.is_read) unreadSnapshot.current.add(row.id);
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 30);
      if (!append) void markAllNotificationsRead(client, userId).catch(() => undefined);
    } finally { setLoading(false); }
  }, [client, userId]);
  useEffect(() => { void load(0, false); }, [load]);

  const open = (row: NotificationRow) => {
    if (row.conversation_id) { router.push(`/chat/${row.conversation_id}${row.actor_id ? `?user=${encodeURIComponent(row.actor_id)}` : ""}`); return; }
    if (row.drop_id) { router.push(`/drop/${row.drop_id}`); return; }
    if (row.club_post_id) { router.push(`/club-post/${row.club_post_id}`); return; }
    if (row.club_id) { router.push(`/club/${row.club_id}`); return; }
    if (row.actor_id) router.push(`/profile/${row.actor_id}`);
  };

  const visible = tab === "mentions" ? rows.filter(isMention) : rows;
  const menuRows = [
    ["สำรวจ Club", Compass, "/clubs"],
    ["สร้าง Club", Plus, "/clubs/new"],
    ["Club ของฉัน", UsersRound, "/clubs?mine=1"],
    ["บันทึกไว้", Bookmark, "/bookmarks"],
  ] as const;

  return (
    <AppChrome title="" userId={userId} headerMode="hidden">
      <header className="notification-root-header">
        <button type="button" aria-label="เมนู" onClick={() => setDrawerOpen(true)}><Menu size={22} /></button>
        <strong>การแจ้งเตือน</strong>
        <button type="button" aria-label="ค้นหา" onClick={() => router.push("/search")}><Search size={21} /></button>
      </header>
      <div className="flutter-notification-tabs"><button className={tab === "all" ? "active" : ""} type="button" onClick={() => setTab("all")}>ทั้งหมด</button><button className={tab === "mentions" ? "active" : ""} type="button" onClick={() => setTab("mentions")}>การกล่าวถึง</button></div>
      {loading && !rows.length ? <LoadingState /> : !visible.length ? <EmptyState>{tab === "mentions" ? "ยังไม่มีใครกล่าวถึงคุณ" : "ยังไม่มีการแจ้งเตือน"}</EmptyState> : (
        <div className="notification-list">
          {visible.map((row) => (
            <button className={`notification-row ${unreadSnapshot.current.has(row.id) ? "unread" : ""}`} type="button" onClick={() => open(row)} key={row.id}>
              <span className="notification-avatar-wrap"><Avatar src={row.actor_avatar_url} label={row.actor_username || "WYNOS"} /><span className="notification-type-icon"><TypeIcon type={row.type} /></span></span>
              <span className="notification-copy"><strong>{messageFor(row)}</strong>{row.content_preview ? <small className="notification-preview">{row.content_preview}</small> : null}<small>{relativeTimeTh(row.created_at)}</small></span>
              {unreadSnapshot.current.has(row.id) ? <i className="notification-dot" /> : null}
            </button>
          ))}
          {tab === "all" && hasMore ? <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button> : null}
        </div>
      )}
      {drawerOpen ? <div className="home-drawer-backdrop" role="presentation" onClick={() => setDrawerOpen(false)}><aside className="home-drawer" role="dialog" aria-modal="true" aria-label="เมนู" onClick={(e) => e.stopPropagation()}><div className="home-drawer-close"><button className="icon-button" type="button" aria-label="ปิด" onClick={() => setDrawerOpen(false)}><X size={22} /></button></div><button className="drawer-identity notification-drawer-identity" type="button" onClick={() => router.push(`/profile/${userId}`)}><Avatar label="WYNOS" size={56} /><span className="drawer-identity-copy"><strong>โปรไฟล์ของฉัน</strong><small>เปิดโปรไฟล์</small></span></button><div className="drawer-divider" /><div className="drawer-menu-list">{menuRows.map(([label, Icon, href]) => <button className="drawer-menu-row" type="button" onClick={() => { setDrawerOpen(false); router.push(href); }} key={label}><span className="drawer-menu-icon"><Icon size={19} /></span><span>{label}</span></button>)}</div></aside></div> : null}
    </AppChrome>
  );
}

export function NotificationsRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <NotificationsInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
