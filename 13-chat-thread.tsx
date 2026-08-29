import React, { useState } from "react";
import { ChevronLeft, Send, Image as ImageIcon, BadgeCheck } from "lucide-react";

/*
  WYNOS — Chat thread (one conversation).

  Reached by tapping a row in the Chat inbox (12-chat.jsx). Back returns
  to the inbox list, same push/pop pattern as every other pushed screen
  in the app (Post Detail, Settings, Chat inbox itself).

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — nowhere here, deliberately: like Drop, a message thread is a
  writing/reading surface, not a branding moment — Inter throughout.

  Design notes:
  - Sent (your own) messages: sapphire-filled bubble, white text, aligned
    right, no avatar (it's obviously you).
  - Received messages: soft tinted bubble (#F1EFE9, same tint used for
    input fields and pills elsewhere), ink text, aligned left, with a
    small avatar next to the first bubble in each consecutive run from
    that person — not repeated on every single bubble, so a multi-message
    burst doesn't repeat the same avatar three times in a row.
  - Timestamps are not shown per-bubble by default (that's how every
    reference messaging app avoids visual noise) — a centered, muted
    timestamp divider appears only when there's a meaningful time gap
    between message groups.
  - Composer at the bottom matches the same shape/tone as Post Detail's
    comment composer and Drop's text input: quiet, borderless input field
    inside a bordered container, sapphire send icon that activates only
    once there's text.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function Avatar({ bg, letter, size = 30 }) {
  const outer = size + 4;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1px solid #1B3A6B33" }} />
      <div
        className="flex items-center justify-center rounded-full text-white"
        style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.42, fontWeight: 500 }}
      >
        {letter}
      </div>
    </div>
  );
}

const person = { name: "WARREN", verified: false, avatarBg: "#1B3A6B" };

const thread = [
  { type: "divider", label: "วันนี้ 18:40" },
  { from: "them", text: "เฮ้ พรุ่งนี้ยังโอเคกับเวลาประชุมเดิมไหมครับ" },
  { from: "them", text: "10 โมงเช้า ที่ร้านกาแฟเดิม" },
  { from: "me", text: "โอเคครับ สะดวกเลย" },
  { from: "me", text: "เดี๋ยวผมส่ง draft ให้ดูก่อนคืนนี้นะ" },
  { from: "them", text: "โอเคครับ เดี๋ยวส่งไฟล์ให้ดูอีกที" },
];

function Bubble({ from, text, showAvatar }) {
  const isMe = from === "me";
  return (
    <div className={`flex items-end gap-2 ${isMe ? "justify-end" : "justify-start"}`}>
      {!isMe && (
        <div style={{ width: 34 }}>
          {showAvatar && <Avatar bg={person.avatarBg} letter={person.name[0]} />}
        </div>
      )}
      <div
        className="px-4 py-2.5 rounded-2xl max-w-[72%]"
        style={{
          background: isMe ? "#1B3A6B" : "#F1EFE9",
          borderBottomRightRadius: isMe ? 6 : 18,
          borderBottomLeftRadius: isMe ? 18 : 6,
        }}
      >
        <p className="text-[14px] leading-relaxed" style={{ color: isMe ? "#FAF9F6" : "#12120F", fontFamily: FONT_SANS }}>
          {text}
        </p>
      </div>
    </div>
  );
}

function TimeDivider({ label }) {
  return (
    <div className="flex justify-center py-1">
      <span className="text-[11px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>{label}</span>
    </div>
  );
}

export default function WynosChatThread() {
  const [message, setMessage] = useState("");

  // group consecutive "them" messages so the avatar only shows once per run
  let lastFrom = null;

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
      `}</style>

      <div
        className="relative w-full overflow-hidden flex flex-col"
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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:06</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header — person identity, not a generic title */}
        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <button className="flex items-center gap-2 justify-self-center">
            <Avatar bg={person.avatarBg} letter={person.name[0]} size={28} />
            <span className="flex items-center gap-1">
              <span style={{ fontFamily: FONT_SANS, fontWeight: 700, fontSize: 14.5, color: "#12120F" }}>{person.name}</span>
              {person.verified && <BadgeCheck size={12} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
            </span>
          </button>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />

        {/* thread */}
        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-2">
          {thread.map((item, i) => {
            if (item.type === "divider") return <TimeDivider key={i} label={item.label} />;
            const showAvatar = item.from === "them" && lastFrom !== "them";
            lastFrom = item.from;
            return <Bubble key={i} from={item.from} text={item.text} showAvatar={showAvatar} />;
          })}
        </div>

        {/* composer */}
        <div className="flex items-center gap-2.5 px-4 py-3" style={{ borderTop: "1px solid #E8E6E0" }}>
          <button className="shrink-0 p-1.5">
            <ImageIcon size={20} strokeWidth={1.5} color="#8A8880" />
          </button>
          <div
            className="flex-1 flex items-center px-4 py-2.5 rounded-full"
            style={{ background: "#F1EFE9", border: "1px solid #E8E6E0" }}
          >
            <input
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="พิมพ์ข้อความ..."
              className="flex-1 bg-transparent outline-none text-[13.5px]"
              style={{ color: "#12120F", fontFamily: FONT_SANS }}
            />
          </div>
          <button className="shrink-0 w-9 h-9 rounded-full flex items-center justify-center" style={{ background: message.trim() ? "#1B3A6B" : "#E8E6E0" }}>
            <Send size={15} strokeWidth={2} color={message.trim() ? "#FAF9F6" : "#B7B4AC"} />
          </button>
        </div>
      </div>
    </div>
  );
}
