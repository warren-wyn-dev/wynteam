"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useSearchParams } from "next/navigation";
import { Suspense, useMemo, useState } from "react";

import { ClubChatMessageActions, ClubChatToolbar } from "@/components/club/club-chat-actions";

type Row = { id: string; channel_id: string; author_id: string; content: string; pinned_at: string | null; created_at: string };
const ME = "00000000-0000-0000-0000-000000000001";
const OTHER = "00000000-0000-0000-0000-000000000002";

function makeClient(rows: Row[], delayFirstSearch = false): SupabaseClient {
  const query = () => {
    let channel = "";
    const chain = {
      select: () => chain,
      eq: (key: string, value: string) => { if (key === "channel_id") channel = value; return chain; },
      not: () => chain,
      order: () => chain,
      limit: async () => ({ data: rows.filter((row) => row.channel_id === channel && row.pinned_at), error: null }),
    };
    return chain;
  };
  return {
    from: query,
    rpc: async (name: string, args: Record<string, unknown>) => {
      // Deterministic out-of-order replies for the stale-search browser test.
      if (name === "search_club_channel_messages" && delayFirstSearch && args.p_query === "hello")
        await new Promise((done) => setTimeout(done, 550));
      const row = rows.find((item) => item.id === args.p_message_id);
      if (name === "edit_club_channel_message" && row) row.content = String(args.p_content);
      if (name === "set_club_channel_message_pin" && row)
        row.pinned_at = args.p_pin ? new Date().toISOString() : null;
      if (name === "search_club_channel_messages")
        return { data: rows.filter((item) => item.channel_id === args.p_channel_id
          && item.content.toLowerCase().includes(String(args.p_query).toLowerCase())), error: null };
      return { data: null, error: null };
    },
  } as unknown as SupabaseClient;
}

function Inner() {
  const params = useSearchParams();
  const role = params.get("role") ?? "owner";
  const mine = params.get("mine") !== "0";
  const rows = useMemo<Row[]>(() => [
    { id: "m1", channel_id: "channel1", author_id: ME, content: "hello club chat", pinned_at: null, created_at: "2026-09-27T12:00:00Z" },
    { id: "m2", channel_id: "channel1", author_id: OTHER, content: "please read the rules", pinned_at: null, created_at: "2026-09-27T12:01:00Z" },
    { id: "m3", channel_id: "channel2", author_id: OTHER, content: "secret second channel", pinned_at: null, created_at: "2026-09-27T12:02:00Z" },
  ], []);
  const slow = params.get("slow") === "1";
  const client = useMemo(() => makeClient(rows, slow), [rows, slow]);
  const [tick, setTick] = useState(0);
  const [chosen, setChosen] = useState<Row | null>(null);
  const [jumped, setJumped] = useState("");
  const [reported, setReported] = useState(false);
  return (
    <main className="route-main">
      <section className="golden-club-chat" aria-label="Club chat Beta2 fixture">
        <ClubChatToolbar client={client} channelId="channel1" refreshToken={tick}
          onJump={async (id) => { setJumped(id); }} />
        <div className="golden-club-messages">
          <p data-testid="content">{rows[0].content}</p>
          <p data-testid="jumped">{jumped}</p>
          {reported ? <p>รายงานแล้ว</p> : null}
          <button type="button" onClick={() => setChosen({ ...rows[mine ? 0 : 1] })}>ตัวเลือกข้อความตัวอย่าง</button>
        </div>
        {chosen ? <ClubChatMessageActions
          client={client} message={chosen} mine={mine}
          canModerate={role === "owner" || role === "admin" || role === "moderator"}
          onClose={() => setChosen(null)}
          onChanged={() => { setTick((value) => value + 1); }}
          onDelete={() => { setChosen(null); }}
          onReport={() => { setChosen(null); setReported(true); }}
        /> : null}
      </section>
    </main>
  );
}

export function ClubChatActionsFixture() {
  return <Suspense><Inner /></Suspense>;
}
