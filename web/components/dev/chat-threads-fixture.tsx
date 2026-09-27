"use client";

import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

import { ConversationThread } from "@/components/chat/conversation-thread";
import type { MessageRow, ProfileRow } from "@/lib/phase3-data";

const ME = "00000000-0000-4000-8000-000000000001";
const OTHER: ProfileRow = { id: "00000000-0000-4000-8000-000000000002", username: "mind_coffee", display_name: "มายด์", avatar_url: null } as ProfileRow;

function at(minutes: number, seconds = 0): string {
  return new Date(Date.UTC(2026, 8, 26, 3, minutes, seconds)).toISOString();
}

const MESSAGES: MessageRow[] = [
  { id: "m1", conversation_id: "c", sender_id: OTHER.id, text: "เพิ่งลองร้านกาแฟใหม่แถวบ้าน", created_at: at(1, 0) },
  { id: "m2", conversation_id: "c", sender_id: OTHER.id, text: "รสชาติดีเกินคาด", created_at: at(1, 12) },
  { id: "m3", conversation_id: "c", sender_id: OTHER.id, text: "แนะนำเลยถ้าผ่านแถวนั้น ☕️", created_at: at(1, 30) },
  { id: "m4", conversation_id: "c", sender_id: ME, text: "อยู่ตรงไหนอ่ะ อยากไปลองมั่ง 😍", created_at: at(4, 0) },
  { id: "m5", conversation_id: "c", sender_id: OTHER.id, text: "อยู่แถวทองหล่อเลย ซอย 5 นะ", created_at: at(6, 0) },
  { id: "m6", conversation_id: "c", sender_id: ME, text: "โอเค เดี๋ยวเสาร์นี้ไป", created_at: at(9, 0) },
  { id: "m7", conversation_id: "c", sender_id: ME, text: "ขอบคุณมากนะ 🙏", created_at: at(9, 20) },
];

/** Dev-only preview of WYN-159: Web Beta1 thread vs the Beta2 Threads-style thread, same messages. */
function Fixture() {
  const params = useSearchParams();
  const threads = params.get("threads") === "1";
  const [revealed, setRevealed] = useState<string | null>(null);
  return (
    <main className="route-main">
      <div className="conversation-page conversation-modern">
        <div className="message-list conversation-thread" data-testid="chat-threads-fixture">
          <ConversationThread
            messages={MESSAGES}
            userId={ME}
            other={OTHER}
            otherLastReadAt={at(9, 10)}
            threads={threads}
            revealedMessageId={revealed}
            onToggleReveal={(id) => setRevealed((current) => current === id ? null : id)}
            onDelete={() => undefined}
            renderImage={() => null}
          />
        </div>
      </div>
    </main>
  );
}

export function ChatThreadsFixture() {
  return <Suspense><Fixture /></Suspense>;
}
