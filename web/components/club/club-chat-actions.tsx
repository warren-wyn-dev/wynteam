"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useRef, useState, type FormEvent } from "react";

import { BottomSheet } from "@/components/club/club-sheet";
import { WynosIcon } from "@/components/ui/wynos-icon";
import {
  cleanClubChatSearch,
  editClubChatMessage,
  fetchPinnedClubChat,
  searchClubChat,
  setClubChatPin,
  type ClubChatPin,
  type ClubChatSearchHit,
} from "@/lib/club-chat-actions";

type ActionMessage = {
  id: string;
  author_id: string;
  content?: string | null;
  pinned_at?: string | null;
};

export function ClubChatToolbar({
  client, channelId, refreshToken, onJump, onPinRetry,
}: {
  client: SupabaseClient;
  channelId: string;
  refreshToken: number;
  onJump: (messageId: string) => Promise<void>;
  /** Optional instrumentation for the local-only failure/retry fixture. */
  onPinRetry?: () => void;
}) {
  const [pins, setPins] = useState<ClubChatPin[]>([]);
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<ClubChatSearchHit[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [searchError, setSearchError] = useState("");
  const [pinError, setPinError] = useState("");
  const [pinLoading, setPinLoading] = useState(false);
  const [pinRetry, setPinRetry] = useState(0);
  const pending = useRef(0);

  useEffect(() => {
    let active = true;
    void fetchPinnedClubChat(client, channelId)
      .then((items) => {
        if (active) { setPins(items); setPinError(""); }
      })
      .catch(() => { if (active) setPinError("โหลดข้อความที่ปักหมุดไม่สำเร็จ"); })
      .finally(() => { if (active) setPinLoading(false); });
    return () => { active = false; };
  }, [client, channelId, refreshToken, pinRetry]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!cleanClubChatSearch(query) || busy) return;
    const request = ++pending.current;
    setBusy(true);
    setSearchError("");
    try {
      const hits = await searchClubChat(client, channelId, query);
      if (request === pending.current) setResults(hits);
    } catch {
      if (request === pending.current) setSearchError("ค้นหาข้อความไม่สำเร็จ");
    } finally {
      if (request === pending.current) setBusy(false);
    }
  };

  return (
    <div className="golden-club-chat-tools">
      <div className="golden-club-chat-tools-title">
        <span>ข้อความที่ปักหมุด</span>
        <button type="button" aria-expanded={searchOpen} onClick={() => {
          pending.current += 1; setBusy(false);
          setSearchOpen((open) => !open); setSearchError(""); setResults(null);
        }}>
          <WynosIcon name="search" size={16} />ค้นหาข้อความ
        </button>
      </div>
      {pins.length ? (
        <div className="golden-club-pinned-list" aria-label="ข้อความที่ปักหมุด">
          {pins.map((pin) => (
            <button type="button" key={pin.id} onClick={() => void onJump(pin.id)}>
              <WynosIcon name="pin" size={14} />{pin.content ? <span data-i18n-skip="">{pin.content}</span> : <span>รูปภาพ</span>}
            </button>
          ))}
        </div>
      ) : null}
      {pinError ? (
        <div className="golden-club-pin-error" role="alert">
          <span>{pinError}</span>
          <button type="button" disabled={pinLoading} onClick={() => {
            onPinRetry?.(); // Local fixture can now make retry succeed, regardless of React Strict Mode effect replays.
            setPinLoading(true);
            setPinError("");
            setPinRetry((value) => value + 1);
          }}>ลองอีกครั้ง</button>
        </div>
      ) : null}
      {searchOpen ? (
        <div className="golden-club-search">
          <form role="search" onSubmit={(event) => void submit(event)}>
            <input type="text" inputMode="search" enterKeyHint="search" autoComplete="off"
              aria-label="ค้นหาข้อความในห้องนี้" value={query}
              maxLength={120} onChange={(event) => {
                pending.current += 1; // Invalidate an in-flight query before accepting new input.
                setBusy(false); setSearchError(""); setQuery(event.target.value); setResults(null);
              }}
              placeholder="ค้นหาในห้องนี้" />
            {query ? <button className="golden-club-search-clear" type="button" aria-label="ล้างคำค้นหา"
              onClick={() => {
                pending.current += 1; setBusy(false); setSearchError(""); setQuery(""); setResults(null);
              }}><WynosIcon name="close" size={16} /></button> : null}
            <button type="submit" disabled={!cleanClubChatSearch(query) || busy}>
              {busy ? "กำลังค้นหา…" : "ค้นหา"}
            </button>
          </form>
          {results ? (
            <div className="golden-club-search-results" aria-label="ผลการค้นหา" aria-live="polite">
              {results.length ? results.map((hit) => (
                <button key={hit.id} type="button" onClick={() => { pending.current += 1; setSearchOpen(false); void onJump(hit.id); }}>
                  <span data-i18n-skip="">{hit.content.slice(0, 180)}</span>
                  <small>{new Date(hit.created_at).toLocaleDateString()}</small>
                </button>
              )) : <p>ไม่พบข้อความในห้องนี้</p>}
            </div>
          ) : null}
        </div>
      ) : null}
      {searchError ? <p className="route-error" role="alert">{searchError}</p> : null}
    </div>
  );
}

export function ClubChatMessageActions({
  client, message, mine, canModerate, onClose, onChanged, onDelete, onReport,
}: {
  client: SupabaseClient;
  message: ActionMessage;
  mine: boolean;
  canModerate: boolean;
  onClose: () => void;
  onChanged: () => void;
  onDelete: () => void;
  onReport: () => void;
}) {
  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(message.content ?? "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const save = async () => {
    if (busy) return;
    if (!text.trim() || text.trim().length > 2000) {
      setError("ข้อความต้องมี 1–2000 ตัวอักษร");
      return;
    }
    setBusy(true); setError("");
    try {
      await editClubChatMessage(client, message.id, text);
      onChanged();
      onClose();
    } catch {
      setError("แก้ไขข้อความไม่สำเร็จ");
    } finally { setBusy(false); }
  };

  const pin = async () => {
    if (busy) return;
    setBusy(true); setError("");
    try {
      await setClubChatPin(client, message.id, !message.pinned_at);
      onChanged();
      onClose();
    } catch {
      setError("ปักหมุดไม่สำเร็จ กรุณาตรวจสอบสิทธิ์หรือจำนวนข้อความที่ปักหมุด");
    } finally { setBusy(false); }
  };

  if (editing) {
    return (
      <BottomSheet label="แก้ไขข้อความ" onClose={onClose}>
        <div className="golden-club-chat-edit">
          <strong>แก้ไขข้อความ</strong>
          <textarea aria-label="ข้อความที่แก้ไข" maxLength={2000} value={text}
            onChange={(event) => setText(event.target.value)} />
          {error ? <p className="route-error" role="alert">{error}</p> : null}
          <div className="golden-club-edit-actions">
            <button type="button" disabled={busy} onClick={onClose}>ยกเลิก</button>
            <button type="button" disabled={busy || !text.trim()} onClick={() => void save()}>บันทึก</button>
          </div>
        </div>
      </BottomSheet>
    );
  }

  return (
    <BottomSheet label="ตัวเลือกข้อความ" onClose={onClose}>
      <div className="golden-club-chat-menu">
        {mine && message.content ? (
          <button className="golden-club-sheet-row" type="button" disabled={busy} onClick={() => setEditing(true)}>
            <WynosIcon name="pencil" size={19} />แก้ไขข้อความ
          </button>
        ) : null}
        {canModerate ? (
          <button className="golden-club-sheet-row" type="button" disabled={busy} onClick={() => void pin()}>
            <WynosIcon name="pin" size={19} />{message.pinned_at ? "เลิกปักหมุด" : "ปักหมุดข้อความ"}
          </button>
        ) : null}
        {!mine ? (
          <button className="golden-club-sheet-row" type="button" disabled={busy} onClick={onReport}>
            <WynosIcon name="flag" size={19} />รายงานข้อความ
          </button>
        ) : null}
        {(mine || canModerate) ? (
          <button className="golden-club-sheet-row danger" type="button" disabled={busy} onClick={onDelete}>
            <WynosIcon name="trash" size={19} />ลบข้อความ
          </button>
        ) : null}
        {error ? <p className="route-error" role="alert">{error}</p> : null}
      </div>
    </BottomSheet>
  );
}
