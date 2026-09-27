"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useState } from "react";

import { BottomSheet } from "@/components/club/club-sheet";
import { Avatar, EmptyState, LoadingState } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import {
  ANNOUNCEMENT_MAX_LENGTH,
  ANNOUNCEMENT_PAGE_SIZE,
  announcementPermissions,
  canPostAnnouncement,
  createClubAnnouncement,
  deleteClubAnnouncement,
  fetchClubAnnouncements,
  updateClubAnnouncement,
  type ClubAnnouncement,
} from "@/lib/club-announcements";
import { relativeTimeTh } from "@/lib/feed";

type Composer = { mode: "create" } | { mode: "edit"; announcement: ClubAnnouncement };

/**
 * WYN-137 (Beta2): the Club's "ประกาศ" tab. Club-wide, not tied to a
 * channel. Staff post; every approved member reads and is notified.
 */
export function ClubAnnouncementsTab({
  client,
  userId,
  clubId,
  role,
  approved,
  onToast,
}: {
  client: SupabaseClient;
  userId: string;
  clubId: string;
  role: string | null;
  approved: boolean;
  onToast: (message: string) => void;
}) {
  const [items, setItems] = useState<ClubAnnouncement[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [composer, setComposer] = useState<Composer | null>(null);
  const [menuFor, setMenuFor] = useState<ClubAnnouncement | null>(null);
  const staff = approved && canPostAnnouncement(role);

  const load = useCallback(async () => {
    try {
      const rows = await fetchClubAnnouncements(client, clubId);
      setItems(rows);
      setHasMore(rows.length === ANNOUNCEMENT_PAGE_SIZE);
      setFailed(false);
    } catch {
      setFailed(true);
    }
  }, [client, clubId]);

  useEffect(() => {
    if (!approved) return;
    let live = true;
    void fetchClubAnnouncements(client, clubId)
      .then((rows) => { if (live) { setItems(rows); setHasMore(rows.length === ANNOUNCEMENT_PAGE_SIZE); setFailed(false); } })
      .catch(() => { if (live) setFailed(true); });
    return () => { live = false; };
  }, [approved, client, clubId]);

  const loadMore = async () => {
    const oldest = items?.[items.length - 1]?.created_at;
    if (!oldest || loadingMore) return;
    setLoadingMore(true);
    try {
      const rows = await fetchClubAnnouncements(client, clubId, oldest);
      setItems((current) => [...(current ?? []), ...rows.filter((row) => !current?.some((item) => item.id === row.id))]);
      setHasMore(rows.length === ANNOUNCEMENT_PAGE_SIZE);
    } catch {
      onToast("โหลดประกาศเพิ่มไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setLoadingMore(false);
    }
  };

  const remove = async (announcement: ClubAnnouncement) => {
    setMenuFor(null);
    if (!window.confirm("ลบประกาศนี้?")) return;
    try {
      await deleteClubAnnouncement(client, announcement.id);
      setItems((current) => current?.filter((item) => item.id !== announcement.id) ?? current);
      onToast("ลบประกาศแล้ว");
    } catch {
      onToast("ลบประกาศไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  };

  if (!approved) return <section className="club-announcements"><EmptyState>เข้าร่วม Club เพื่อดูประกาศ</EmptyState></section>;

  return (
    <section className="club-announcements" aria-label="ประกาศ">
      {staff ? (
        <button className="club-announcement-compose" type="button" onClick={() => setComposer({ mode: "create" })}>
          <WynosIcon name="megaphone" size={18} strokeWidth={2} />
          เขียนประกาศถึงสมาชิก
        </button>
      ) : null}

      {failed && !items ? (
        <div className="club-announcements-state">
          <p className="route-error" role="alert">โหลดประกาศไม่สำเร็จ</p>
          <button className="club-announcement-retry" type="button" onClick={() => void load()}>ลองใหม่</button>
        </div>
      ) : !items ? (
        <LoadingState />
      ) : !items.length ? (
        <EmptyState>{staff ? "ยังไม่มีประกาศ เขียนประกาศแรกให้สมาชิกได้เลย" : "ยังไม่มีประกาศจาก Club นี้"}</EmptyState>
      ) : (
        <ol className="club-announcement-list">
          {items.map((item) => {
            const name = item.author_display_name || item.author_username || "สมาชิก";
            const permissions = announcementPermissions(role, userId, item.author_id);
            return (
              <li className="club-announcement-card" key={item.id}>
                <div className="club-announcement-head">
                  <span className="club-announcement-badge"><WynosIcon name="megaphone" size={13} strokeWidth={2.2} />ประกาศทางการ</span>
                  <time dateTime={item.created_at}>{relativeTimeTh(item.created_at)}</time>
                  {item.edited_at ? <span className="club-announcement-edited">แก้ไขแล้ว</span> : null}
                  {permissions.canEdit || permissions.canDelete ? (
                    <button className="club-announcement-more" type="button" aria-label="ตัวเลือกประกาศ" onClick={() => setMenuFor(item)}>
                      <WynosIcon name="more" size={18} strokeWidth={2} />
                    </button>
                  ) : null}
                </div>
                <p className="club-announcement-body" data-i18n-skip="">{item.body}</p>
                <div className="club-announcement-author">
                  <Avatar src={item.author_avatar_url} label={name} size={22} />
                  <span data-i18n-skip="">{name}</span>
                </div>
              </li>
            );
          })}
        </ol>
      )}
      {items?.length && hasMore ? (
        <button className="club-announcement-more-list" type="button" disabled={loadingMore} onClick={() => void loadMore()}>
          {loadingMore ? "กำลังโหลด…" : "ดูประกาศก่อนหน้า"}
        </button>
      ) : null}

      {menuFor ? (
        <BottomSheet label="ตัวเลือกประกาศ" onClose={() => setMenuFor(null)}>
          {announcementPermissions(role, userId, menuFor.author_id).canEdit ? (
            <button className="golden-club-sheet-row" type="button" onClick={() => { setComposer({ mode: "edit", announcement: menuFor }); setMenuFor(null); }}>
              <WynosIcon name="pencil" size={20} strokeWidth={2} />แก้ไขประกาศ
            </button>
          ) : null}
          {announcementPermissions(role, userId, menuFor.author_id).canDelete ? (
            <button className="golden-club-sheet-row danger" type="button" onClick={() => void remove(menuFor)}>
              <WynosIcon name="trash" size={20} strokeWidth={2} />ลบประกาศ
            </button>
          ) : null}
        </BottomSheet>
      ) : null}

      {composer ? (
        <AnnouncementComposer
          composer={composer}
          onClose={() => setComposer(null)}
          onSubmit={async (body) => {
            if (composer.mode === "create") {
              await createClubAnnouncement(client, clubId, body);
              onToast("ประกาศแล้ว");
            } else {
              await updateClubAnnouncement(client, composer.announcement.id, body);
              onToast("บันทึกการแก้ไขแล้ว");
            }
            setComposer(null);
            await load();
          }}
        />
      ) : null}
    </section>
  );
}

function AnnouncementComposer({
  composer,
  onClose,
  onSubmit,
}: {
  composer: Composer;
  onClose: () => void;
  onSubmit: (body: string) => Promise<void>;
}) {
  const [body, setBody] = useState(composer.mode === "edit" ? composer.announcement.body : "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const trimmed = body.trim();
  const editing = composer.mode === "edit";

  const submit = async () => {
    if (busy || !trimmed) return;
    setBusy(true);
    setError("");
    try {
      await onSubmit(trimmed);
    } catch {
      setError(editing ? "บันทึกการแก้ไขไม่สำเร็จ ลองใหม่อีกครั้ง" : "ประกาศไม่สำเร็จ ลองใหม่อีกครั้ง");
      setBusy(false);
    }
  };

  return (
    <BottomSheet label={editing ? "แก้ไขประกาศ" : "เขียนประกาศ"} onClose={() => { if (!busy) onClose(); }}>
      <div className="club-announcement-composer">
        <strong>{editing ? "แก้ไขประกาศ" : "เขียนประกาศ"}</strong>
        <small>{editing ? "สมาชิกจะเห็นว่าประกาศนี้ถูกแก้ไข" : "สมาชิกที่เปิดการแจ้งเตือน Club จะได้รับแจ้งเตือน"}</small>
        <textarea
          aria-label="ข้อความประกาศ"
          placeholder="พิมพ์ประกาศถึงสมาชิก…"
          value={body}
          maxLength={ANNOUNCEMENT_MAX_LENGTH}
          rows={6}
          autoFocus
          onChange={(event) => setBody(event.target.value)}
        />
        <div className="club-announcement-composer-foot">
          <span className="club-announcement-count">{body.length}/{ANNOUNCEMENT_MAX_LENGTH}</span>
          <button type="button" className="club-announcement-cancel" disabled={busy} onClick={onClose}>ยกเลิก</button>
          <button type="button" className="club-announcement-submit" disabled={busy || !trimmed} onClick={() => void submit()}>
            {busy ? "กำลังบันทึก…" : editing ? "บันทึก" : "ส่งประกาศ"}
          </button>
        </div>
        {error ? <p className="route-error" role="alert">{error}</p> : null}
      </div>
    </BottomSheet>
  );
}
