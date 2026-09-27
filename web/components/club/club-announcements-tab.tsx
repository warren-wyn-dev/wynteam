"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useRef, useState } from "react";

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
 * channel. Staff post; every approved member reads (notifications come with the release).
 */
type ClubAnnouncementsProps = {
  client: SupabaseClient;
  userId: string;
  clubId: string;
  role: string | null;
  approved: boolean;
  onToast: (message: string) => void;
};

/** Remount on Club or account switch so no previous Club's rows flash on screen. */
export function ClubAnnouncementsTab(props: ClubAnnouncementsProps) {
  return <ScopedClubAnnouncementsTab key={JSON.stringify([props.clubId, props.userId])} {...props} />;
}

function ScopedClubAnnouncementsTab({
  client, userId, clubId, role, approved, onToast,
}: ClubAnnouncementsProps) {
  const [items, setItems] = useState<ClubAnnouncement[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [composer, setComposer] = useState<Composer | null>(null);
  const [menuFor, setMenuFor] = useState<ClubAnnouncement | null>(null);
  const staff = approved && canPostAnnouncement(role);
  const requestSequence = useRef(0);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; requestSequence.current += 1; };
  }, []);

  // Only the newest first-page request may replace the list. A write-triggered
  // reload must not be overwritten by an older initial request or pagination.
  const load = useCallback(async () => {
    const request = ++requestSequence.current;
    try {
      const rows = await fetchClubAnnouncements(client, clubId);
      if (!mounted.current || request !== requestSequence.current) return;
      setItems(rows);
      setHasMore(rows.length === ANNOUNCEMENT_PAGE_SIZE);
      setFailed(false);
    } catch {
      if (mounted.current && request === requestSequence.current) setFailed(true);
    }
  }, [client, clubId]);

  useEffect(() => {
    if (!approved) { requestSequence.current += 1; return; }
    void load();
    return () => { requestSequence.current += 1; };
  }, [approved, load]);

  const loadMore = async () => {
    const last = items?.[items.length - 1];
    if (!last || loadingMore) return;
    const request = requestSequence.current;
    setLoadingMore(true);
    try {
      const rows = await fetchClubAnnouncements(client, clubId, { created_at: last.created_at, id: last.id });
      if (!mounted.current || request !== requestSequence.current) return;
      setItems((current) => [...(current ?? []), ...rows.filter((row) => !current?.some((item) => item.id === row.id))]);
      setHasMore(rows.length === ANNOUNCEMENT_PAGE_SIZE);
    } catch {
      if (mounted.current && request === requestSequence.current)
        onToast("โหลดประกาศเพิ่มไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      if (mounted.current && request === requestSequence.current) setLoadingMore(false);
    }
  };

  const remove = async (announcement: ClubAnnouncement) => {
    setMenuFor(null);
    if (!window.confirm("ลบประกาศนี้?")) return;
    try {
      await deleteClubAnnouncement(client, announcement.id);
      if (!mounted.current) return;
      requestSequence.current += 1; // A slow earlier page must not restore a deleted item.
      setLoadingMore(false);
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

      {/* A reload that fails after a successful post/edit/delete: the list
          may be stale, so say so and offer a retry instead of hiding it. */}
      {failed && items ? (
        <div className="club-announcements-stale" role="alert">
          <span>รายการอาจยังไม่อัปเดต</span>
          <button className="club-announcement-retry" type="button" onClick={() => void load()}>โหลดใหม่</button>
        </div>
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
            if (!mounted.current) return;
            setComposer(null);
            setLoadingMore(false);
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
        <small>{editing ? "สมาชิกจะเห็นว่าประกาศนี้ถูกแก้ไข" : "ประกาศจะแสดงในแท็บประกาศของ Club"}</small>
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
