import React, { useState } from "react";
import { ChevronLeft, PenLine, BadgeCheck } from "lucide-react";

/*
  WYNOS — Chat inbox.

  Where this lives: replaces the search icon in Home's top-right header.
  Home's header previously had ☰ (menu) — WYNOS — 🔍 (search), but the
  bottom nav already has a dedicated "ค้นหา" tab, so that top-right icon
  was a duplicate entry point. Chat takes that spot instead: a paper-plane
  icon, top-right of Home, pushes this inbox screen — the same "push over
  the current tab" pattern already used for Post Detail and Settings.

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — screen title · Inter — everything else

  Design notes:
  - Conversation rows follow the same avatar-ring + name pattern as every
    other list in the app (Search's suggested accounts, Club's member
    rows) — a conversation is fundamentally "a person," styled the same
    way a person is styled anywhere else.
  - Unread conversations: name weight 700 + a small sapphire dot, instead
    of a bold background fill — consistent with how "unread" is expressed
    everywhere else (Notifications uses the same quiet-dot approach).
  - Last-message preview truncates to one line; timestamp sits top-right
    of the row, muted, same position/weight as post timestamps elsewhere.
  - Compose icon (pencil) top-right opens a new-message flow — not built
    out here, but reserved as a real, tappable affordance rather than
    omitted.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const conversations = [
  { id: 1, name: "WARREN", verified: false, avatarBg: "#1B3A6B", lastMessage: "โอเคครับ เดี๋ยวส่งไฟล์ให้ดูอีกที", time: "2 นาที", unread: true },
  { id: 2, name: "ZEN", verified: false, avatarBg: "#8A6D3A", lastMessage: "น่ารักมาก เป็นกำลังใจให้นะ 🌿", time: "1 ชั่วโมง", unread: true },
  { id: 3, name: "WYNOS", verified: true, avatarBg: "#3A5A40", lastMessage: "ขอบคุณที่เข้าร่วม Club ของเรา!", time: "เมื่อวาน", unread: false },
  { id: 4, name: "wor._.aa", verified: false, avatarBg: "#6B4A6B", lastMessage: "รอใช้งานอยู่เลยครับ 😄", time: "2 วัน", unread: false },
];

function Avatar({ bg, letter, size = 48 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1px solid #1B3A6B33" }} />
      <div
        className="flex items-center justify-center rounded-full text-white"
        style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}
      >
        {letter}
      </div>
    </div>
  );
}

function ConversationRow({ c, isLast }) {
  return (
    <button className={`w-full flex items-center gap-3.5 px-6 py-3.5 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <Avatar bg={c.avatarBg} letter={c.name[0]} />
      <div className="flex-1 min-w-0 text-left">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1">
            <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: c.unread ? 700 : 600 }}>
              {c.name}
            </span>
            {c.verified && <BadgeCheck size={13} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
          </div>
          <span className="text-[11.5px] shrink-0 ml-2" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
            {c.time}
          </span>
        </div>
        <div className="flex items-center gap-1.5 mt-0.5">
          {c.unread && <div className="rounded-full shrink-0" style={{ width: 6, height: 6, background: "#1B3A6B" }} />}
          <p
            className="text-[13px] truncate"
            style={{ color: c.unread ? "#12120F" : "#8A8880", fontFamily: FONT_SANS, fontWeight: c.unread ? 500 : 400 }}
          >
            {c.lastMessage}
          </p>
        </div>
      </div>
    </button>
  );
}

export default function WynosChat() {
  const [tab, setTab] = useState("ทั้งหมด");

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
      `}</style>

      <div
        className="relative w-full overflow-hidden"
        style={{
          maxWidth: 390,
          height: 844,
          background: "#FAF9F6",
          borderRadius: 44,
          boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)",
        }}
      >
        {/* status bar */}
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:05</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>
            ข้อความ
          </span>
          <button className="justify-self-end p-2 -mr-2"><PenLine size={19} strokeWidth={1.5} color="#12120F" /></button>
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />

        {/* tabs */}
        <div className="flex px-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
          {["ทั้งหมด", "ยังไม่อ่าน"].map((t) => (
            <button key={t} onClick={() => setTab(t)} className="relative py-3 mr-6">
              <span className="text-[13.5px]" style={{ fontFamily: FONT_SANS, fontWeight: tab === t ? 600 : 400, color: tab === t ? "#12120F" : "#B7B4AC" }}>
                {t}
              </span>
              {tab === t && <div className="absolute left-0 right-0 -bottom-[1px] rounded-full" style={{ height: 2, background: "#1B3A6B" }} />}
            </button>
          ))}
        </div>

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 44 - 44 }}>
          {(tab === "ยังไม่อ่าน" ? conversations.filter((c) => c.unread) : conversations).map((c, i, arr) => (
            <ConversationRow key={c.id} c={c} isLast={i === arr.length - 1} />
          ))}
        </div>
      </div>
    </div>
  );
}
