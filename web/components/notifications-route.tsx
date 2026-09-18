"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { relativeTimeTh } from "@/lib/feed";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { markNotificationsRead } from "@/lib/notification-count";
import { fetchNotifications, markAllNotificationsRead, type NotificationRow } from "@/lib/phase3-data";

type NotificationsSnapshot = { rows: NotificationRow[]; unreadSnapshot: Set<string>; page: number; hasMore: boolean };

function actorLabel(row: NotificationRow): string {
  return row.actor_display_name?.trim() || (row.actor_username ? `@${row.actor_username}` : "WYNOS");
}

function messageFor(row: NotificationRow): string {
  const actor = actorLabel(row);
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

function TypeBadge({ type }: { type: string }) {
  if (type.includes("like")) return <span className="notification-type-icon like"><WynosIcon name="like" size={10} fill="currentColor" strokeWidth={0} /></span>;
  if (type === "redrop") return <span className="notification-type-icon repost"><WynosIcon name="repost" size={10} strokeWidth={2} /></span>;
  if (type === "follow" || type === "follow_request_accepted") return <span className="notification-type-icon follow"><WynosIcon name="userPlus" size={10} strokeWidth={2} /></span>;
  if (type.includes("comment")) return <span className="notification-type-icon comment"><WynosIcon name="comment" size={10} fill="currentColor" strokeWidth={2} /></span>;
  return null;
}

function isMention(row: NotificationRow) {
  return row.type === "mention_drop" || row.type === "mention_club_post";
}

type DayBucket = "today" | "yesterday" | "older";
type NotificationGroup = { head: NotificationRow; items: NotificationRow[]; extraActorCount: number };

const groupableTypes = new Set(["like_drop", "like_pop", "comment_drop", "comment_pop", "redrop", "follow"]);

function bucketFor(iso: string, now: Date): DayBucket {
  const created = new Date(iso);
  const day = new Date(created.getFullYear(), created.getMonth(), created.getDate());
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff = Math.floor((today.getTime() - day.getTime()) / 86_400_000);
  if (diff <= 0) return "today";
  if (diff === 1) return "yesterday";
  return "older";
}

function groupKey(row: NotificationRow): string | null {
  if (!groupableTypes.has(row.type)) return null;
  return `${row.type}:${row.drop_id ?? row.pop_id ?? ""}`;
}

function groupWithinDay(items: NotificationRow[]): NotificationGroup[] {
  const groups: Array<{ head: NotificationRow; items: NotificationRow[] }> = [];
  const indexByKey = new Map<string, number>();
  for (const row of items) {
    const key = groupKey(row);
    if (!key) {
      groups.push({ head: row, items: [row] });
      continue;
    }
    const existing = indexByKey.get(key);
    if (existing == null) {
      indexByKey.set(key, groups.length);
      groups.push({ head: row, items: [row] });
    } else {
      groups[existing].items.push(row);
    }
  }
  return groups.map((group) => ({
    ...group,
    extraActorCount: new Set(group.items.slice(1).map((row) => row.actor_id).filter(Boolean)).size,
  }));
}

function buildSections(items: NotificationRow[]) {
  const now = new Date();
  const order: DayBucket[] = ["today", "yesterday", "older"];
  const labels: Record<DayBucket, string> = { today: "วันนี้", yesterday: "เมื่อวานนี้", older: "ก่อนหน้านี้" };
  return order.flatMap((bucket) => {
    const bucketRows = items.filter((row) => bucketFor(row.created_at, now) === bucket);
    return bucketRows.length ? [{ label: labels[bucket], groups: groupWithinDay(bucketRows) }] : [];
  });
}

function NotificationMessage({ row, extraActorCount }: { row: NotificationRow; extraActorCount: number }) {
  const message = messageFor(row);
  const actor = actorLabel(row);
  const actorVisible = Boolean(row.actor_id) && message.startsWith(actor);
  return (
    <span className="notification-message">
      {actorVisible ? <><b>{actor}</b>{message.slice(actor.length)}</> : message}
      {extraActorCount > 0 ? <em> และอีก {extraActorCount} คน</em> : null}
    </span>
  );
}

function NotificationsInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const cacheKey = `notifications:${userId}`;
  const cached = getMountCache<NotificationsSnapshot>(cacheKey);
  const [rows, setRows] = useState<NotificationRow[]>(cached?.rows ?? []);
  const [unreadSnapshot, setUnreadSnapshot] = useState<Set<string>>(cached?.unreadSnapshot ?? new Set());
  const [page, setPage] = useState(cached?.page ?? 0);
  const [hasMore, setHasMore] = useState(cached?.hasMore ?? false);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"all" | "mentions">("all");

  useEffect(() => {
    setMountCache(cacheKey, { rows, unreadSnapshot, page, hasMore });
  }, [cacheKey, rows, unreadSnapshot, page, hasMore]);

  const load = useCallback(async (nextPage: number, append: boolean) => {
    setLoading(true);
    try {
      const next = await fetchNotifications(client, nextPage);
      const nextUnread = next.filter((row) => !row.is_read).map((row) => row.id);
      setUnreadSnapshot((current) => append ? new Set([...current, ...nextUnread]) : new Set(nextUnread));
      setRows((current) => append ? [...current, ...next] : next);
      setPage(nextPage);
      setHasMore(next.length === 30);
      if (!append) {
        markNotificationsRead(userId);
        void markAllNotificationsRead(client, userId).catch(() => undefined);
      }
    } finally {
      setLoading(false);
    }
  }, [client, userId]);

  useEffect(() => {
    void load(0, false);
  }, [load]);

  const closeNotifications = () => {
    if (window.history.length > 1) {
      router.back();
      return;
    }
    router.push("/");
  };

  const open = (row: NotificationRow) => {
    if (row.conversation_id) { router.push(`/chat/${row.conversation_id}${row.actor_id ? `?user=${encodeURIComponent(row.actor_id)}` : ""}`); return; }
    if (row.drop_id) { router.push(`/drop/${row.drop_id}`); return; }
    if (row.club_post_id) { router.push(`/club-post/${row.club_post_id}`); return; }
    if (row.club_id) { router.push(`/club/${row.club_id}`); return; }
    if (row.actor_id) router.push(`/profile/${row.actor_id}`);
  };

  const visible = tab === "mentions" ? rows.filter(isMention) : rows;
  const sections = useMemo(() => buildSections(visible), [visible]);

  return (
    <AppChrome title="" userId={userId} headerMode="hidden">
      <header className="notification-root-header">
        <button type="button" aria-label="ออกจากการแจ้งเตือน" onClick={closeNotifications}><WynosIcon name="close" size={22} strokeWidth={2} /></button>
        <strong>การแจ้งเตือน</strong>
        <span aria-hidden="true" />
      </header>
      <div className="flutter-notification-tabs">
        <button className={tab === "all" ? "active" : ""} type="button" onClick={() => setTab("all")}>ทั้งหมด</button>
        <button className={tab === "mentions" ? "active" : ""} type="button" onClick={() => setTab("mentions")}>การกล่าวถึง</button>
      </div>

      {loading && !rows.length ? <LoadingState /> : !visible.length ? (
        <EmptyState>{tab === "mentions" ? "ยังไม่มีใครกล่าวถึงคุณ" : "ยังไม่มีการแจ้งเตือน"}</EmptyState>
      ) : (
        <div className="notification-list">
          {sections.map((section) => (
            <section className="notification-day-section" key={section.label}>
              <h2 className="notification-group-label">{section.label}</h2>
              {section.groups.map((group) => {
                const row = group.head;
                const wasUnread = group.items.some((item) => unreadSnapshot.has(item.id));
                return (
                  <button className={`notification-row ${wasUnread ? "unread" : ""}`} type="button" onClick={() => open(row)} key={row.id}>
                    <span className="notification-avatar-wrap">
                      <Avatar src={row.actor_avatar_url} label={row.actor_username || "WYNOS"} size={40} />
                      <TypeBadge type={row.type} />
                    </span>
                    <span className="notification-copy">
                      <NotificationMessage row={row} extraActorCount={group.extraActorCount} />
                      {row.content_preview ? <small className="notification-preview">“{row.content_preview}”</small> : null}
                      <small>{relativeTimeTh(row.created_at)}</small>
                    </span>
                    {wasUnread ? <i className="notification-dot" /> : null}
                  </button>
                );
              })}
            </section>
          ))}
          {tab === "all" && hasMore ? (
            <button className="route-more" type="button" disabled={loading} onClick={() => void load(page + 1, true)}>ดูเพิ่มเติม</button>
          ) : tab === "all" ? (
            <p className="notification-end">ไม่มีการแจ้งเตือนเพิ่มเติมแล้ว</p>
          ) : null}
        </div>
      )}
    </AppChrome>
  );
}

export function NotificationsRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <NotificationsInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
