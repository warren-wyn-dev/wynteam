"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useSearchParams } from "next/navigation";
import { Suspense, useMemo, useState } from "react";

import { ClubAnnouncementsTab } from "@/components/club/club-announcements-tab";
import { Toast, useToast } from "@/components/ui/toast";
import { WynosIcon } from "@/components/ui/wynos-icon";

const ME = "00000000-0000-4000-8000-000000000001";
const MOD = "00000000-0000-4000-8000-000000000002";
const PEOPLE = [
  { id: ME, username: "warren", display_name: "Warren", avatar_url: null },
  { id: MOD, username: "mind_coffee", display_name: "มายด์ (ผู้ดูแล)", avatar_url: null },
];

// Relative to page load, so the times read "2 hours ago" / "3 days ago".
const NOW = Date.now();
const ago = (ms: number) => new Date(NOW - ms).toISOString();

type Row = { id: string; club_id: string; author_id: string; body: string; created_at: string; edited_at: string | null };

/** An in-memory stand-in for the Supabase calls the tab makes. */
function fakeClient(rows: Row[], delayFirstClubRead = false): SupabaseClient {
  let nextId = 100;
  let firstReadPending = delayFirstClubRead;
  const query = (table: string) => {
    let requestedClub: string | null = null;
    const chain = {
      select: () => chain,
      eq: (column: string, value: string) => {
        if (table === "club_announcements" && column === "club_id") requestedClub = value;
        return chain;
      },
      lt: () => chain, or: () => chain, order: () => chain,
      limit: async (limit: number) => {
        // Snapshot before delaying so a newer post cannot appear in an old response.
        const data = rows.filter((row) => !requestedClub || row.club_id === requestedClub)
          .sort((a, b) => b.created_at.localeCompare(a.created_at)).slice(0, limit);
        if (firstReadPending && requestedClub === "club") {
          firstReadPending = false;
          (window as Window & { __wynAnnouncementSlowRead?: boolean }).__wynAnnouncementSlowRead = true;
          await new Promise((resolve) => setTimeout(resolve, 450));
        }
        return { data, error: null };
      },
      in: async () => ({ data: table === "profiles" ? PEOPLE : [], error: null }),
    };
    return chain;
  };
  return {
    from: query,
    rpc: async (name: string, args: Record<string, string>) => {
      if (name === "create_club_announcement") rows.push({ id: `a${nextId++}`, club_id: "club", author_id: ME, body: args.p_body, created_at: new Date().toISOString(), edited_at: null });
      if (name === "update_club_announcement") Object.assign(rows.find((row) => row.id === args.p_announcement_id) ?? {}, { body: args.p_body, edited_at: new Date().toISOString() });
      if (name === "delete_club_announcement") rows.splice(rows.findIndex((row) => row.id === args.p_announcement_id), 1);
      return { data: null, error: null };
    },
  } as unknown as SupabaseClient;
}

function Fixture() {
  const params = useSearchParams();
  const role = params.get("role") ?? "owner";
  const empty = params.get("empty") === "1";
  const slow = params.get("slow") === "1";
  const switchable = params.get("switch") === "1";
  const [activeClub, setActiveClub] = useState("club");
  const client = useMemo(() => fakeClient(empty ? [] : [
    { id: "a1", club_id: "club", author_id: ME, body: "📣 นัดถ่ายรูปเสาร์นี้ 9 โมง ที่สวนลุมฯ ประตู 3\nใครมาได้กดตอบในแชทนะครับ", created_at: ago(2 * 3600_000), edited_at: null },
    { id: "a2", club_id: "club", author_id: MOD, body: "กติกาใหม่: โพสต์รูปต้องใส่เครดิตช่างภาพทุกครั้ง", created_at: ago(3 * 86400_000), edited_at: ago(2 * 86400_000) },
    ...(switchable ? [{ id: "b1", club_id: "club-b", author_id: MOD, body: "ประกาศจาก Club ใหม่", created_at: ago(3600_000), edited_at: null }] : []),
  ], slow || switchable), [empty, slow, switchable]);
  const { toastMessage, showToast } = useToast();
  return (
    <main className="route-main">
      <div className="golden-club-page">
        <nav className="golden-club-tabs" aria-label="Club">
          <button type="button"><WynosIcon name="fileText" size={16} strokeWidth={2} />โพสต์</button>
          <button className="active" type="button"><WynosIcon name="megaphone" size={16} strokeWidth={2} />ประกาศ</button>
          <button type="button"><WynosIcon name="messagesSquare" size={16} strokeWidth={2} />แชท</button>
          <button type="button"><WynosIcon name="info" size={16} strokeWidth={2} />เกี่ยวกับ</button>
        </nav>
        {switchable ? <button type="button" onClick={() => setActiveClub("club-b")}>เปลี่ยน Club ทดสอบ</button> : null}
        <ClubAnnouncementsTab client={client} userId={ME} clubId={activeClub} role={role} approved onToast={showToast} />
      </div>
      <Toast message={toastMessage} />
    </main>
  );
}

/** Dev-only preview of WYN-137 (Club announcements): ?role=owner|moderator|member, ?empty=1. */
export function ClubAnnouncementsFixture() {
  return <Suspense><Fixture /></Suspense>;
}
