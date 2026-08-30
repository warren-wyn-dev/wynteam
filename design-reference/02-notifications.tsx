import React, { useState } from "react";
import {
  Search as SearchIcon,
  Menu,
  Heart,
  MessageCircle,
  Repeat2,
  UserPlus,
  BadgeCheck,
} from "lucide-react";

/*
  WYNOS — Notifications screen.

  Token system (same as Home):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — headline only · Inter — everything else

  What changed vs. the original screenshot, and why:
  - The original repeats "WARREN ถูกใจ Drop ของคุณ" seven times as identical,
    undifferentiated rows — no grouping, no visual distinction between a like,
    a follow, or anything else. That reads as noise, not information.
  - Grouped by recency (วันนี้ / เมื่อวานนี้ / เก่ากว่านี้) instead of one
    unbroken list, so the eye has natural stopping points while scanning.
  - Same-type notifications from the same person on the same post collapse
    into a single row instead of repeating — this is the single biggest
    fix versus the screenshot.
  - Each notification carries a small type-icon badge (heart / comment /
    repost / follow) anchored on the avatar, so you can tell what happened
    at a glance without reading the sentence first.
  - Unread notifications get a quiet sapphire dot, not a loud background
    color fill — read/unread is a state, not an alarm.
  - Added an empty state and a lightweight two-tab split (All / Mentions),
    since a notifications screen with only one possible view eventually
    looks broken once real variety of activity exists.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const TYPE_META = {
  like: { icon: Heart, bg: "#1B3A6B", fill: true },
  comment: { icon: MessageCircle, bg: "#3A5A40", fill: false },
  repost: { icon: Repeat2, bg: "#8A6D3A", fill: false },
  follow: { icon: UserPlus, bg: "#1B3A6B", fill: false },
};

const groups = [
  {
    label: "วันนี้",
    items: [
      {
        id: 1,
        type: "like",
        unread: true,
        name: "WARREN",
        verified: false,
        avatarBg: "#1B3A6B",
        text: "ถูกใจ Drop ของคุณ",
        extra: "และอีก 2 คน",
        preview: "“WYNOS เริ่มจากคำถามง่าย ๆ ว่า...”",
        time: "10 ชั่วโมงที่แล้ว",
      },
      {
        id: 2,
        type: "comment",
        unread: true,
        name: "ZEN",
        verified: false,
        avatarBg: "#8A6D3A",
        text: "แสดงความคิดเห็นบน Drop ของคุณ",
        preview: "“น่ารักมาก เป็นกำลังใจให้นะ”",
        time: "11 ชั่วโมงที่แล้ว",
      },
      {
        id: 3,
        type: "repost",
        unread: false,
        name: "WYNOS",
        verified: true,
        avatarBg: "#3A5A40",
        text: "ReDrop โพสต์ของคุณ",
        preview: null,
        time: "13 ชั่วโมงที่แล้ว",
      },
    ],
  },
  {
    label: "เมื่อวานนี้",
    items: [
      {
        id: 4,
        type: "like",
        unread: false,
        name: "WARREN",
        verified: false,
        avatarBg: "#1B3A6B",
        text: "ถูกใจ Drop ของคุณ",
        extra: null,
        preview: "“สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้”",
        time: "22 ชั่วโมงที่แล้ว",
      },
      {
        id: 5,
        type: "follow",
        unread: false,
        name: "WARREN",
        verified: false,
        avatarBg: "#1B3A6B",
        text: "เริ่มติดตามคุณ",
        extra: null,
        preview: null,
        time: "1 วันที่แล้ว",
      },
    ],
  },
];

function Avatar({ bg, letter, size = 42 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0" style={{ width: outer, height: outer }}>
      <div
        className="absolute inset-0 rounded-full flex items-center justify-center"
        style={{ border: "1px solid #1B3A6B33" }}
      >
        <div
          className="flex items-center justify-center rounded-full text-white"
          style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}
        >
          {letter}
        </div>
      </div>
    </div>
  );
}

function TypeBadge({ type }) {
  const meta = TYPE_META[type];
  const Icon = meta.icon;
  return (
    <div
      className="absolute -bottom-0.5 -right-0.5 flex items-center justify-center rounded-full"
      style={{ width: 18, height: 18, background: meta.bg, border: "1.5px solid #FAF9F6" }}
    >
      <Icon size={10} strokeWidth={2} color="#FAF9F6" fill={meta.fill ? "#FAF9F6" : "none"} />
    </div>
  );
}

function NotificationRow({ item }) {
  return (
    <div className="flex gap-3 px-6 py-3.5">
      <div className="relative shrink-0">
        <Avatar bg={item.avatarBg} letter={item.name[0]} size={40} />
        <TypeBadge type={item.type} />
      </div>

      <div className="flex-1 min-w-0">
        <p className="text-[13.5px] leading-snug" style={{ fontFamily: FONT_SANS, color: "#2B2A26" }}>
          <span style={{ fontWeight: 600, color: "#12120F" }}>{item.name}</span>
          {item.verified && (
            <BadgeCheck size={12} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} style={{ display: "inline", marginLeft: 3, marginBottom: -1 }} />
          )}{" "}
          {item.text}
          {item.extra && <span style={{ color: "#8A8880" }}> {item.extra}</span>}
        </p>

        {item.preview && (
          <p className="text-[12.5px] mt-1 truncate" style={{ fontFamily: FONT_SANS, color: "#8A8880" }}>
            {item.preview}
          </p>
        )}

        <p className="text-[11.5px] mt-1" style={{ fontFamily: FONT_SANS, color: "#C7C4BC" }}>
          {item.time}
        </p>
      </div>

      {item.unread && (
        <div className="shrink-0 mt-1.5">
          <div className="rounded-full" style={{ width: 7, height: 7, background: "#1B3A6B" }} />
        </div>
      )}
    </div>
  );
}

function GroupLabel({ label }) {
  return (
    <div className="px-6 pt-5 pb-1.5">
      <span
        className="text-[11px] uppercase"
        style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.12em", fontWeight: 600 }}
      >
        {label}
      </span>
    </div>
  );
}

function Tabs({ active, setActive }) {
  const tabs = ["ทั้งหมด", "การกล่าวถึง"];
  return (
    <div className="flex px-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
      {tabs.map((t) => (
        <button key={t} onClick={() => setActive(t)} className="relative py-3 mr-6">
          <span
            className="text-[13.5px]"
            style={{ fontFamily: FONT_SANS, fontWeight: active === t ? 600 : 400, color: active === t ? "#12120F" : "#B7B4AC" }}
          >
            {t}
          </span>
          {active === t && (
            <div className="absolute left-0 right-0 -bottom-[1px] rounded-full" style={{ height: 2, background: "#1B3A6B" }} />
          )}
        </button>
      ))}
    </div>
  );
}

function EmptyMentions() {
  return (
    <div className="px-6 pt-16 text-center">
      <p style={{ fontFamily: FONT_SERIF, fontSize: 18, color: "#12120F", fontWeight: 500 }}>
        ยังไม่มีใครกล่าวถึงคุณ
      </p>
      <p className="text-[13px] mt-1.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
        เวลามีคนพูดถึงคุณในโพสต์ จะขึ้นตรงนี้
      </p>
    </div>
  );
}

export default function WynosNotifications() {
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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:31</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="flex items-center justify-between px-6 pt-2 pb-1">
          <Menu size={20} strokeWidth={1.4} color="#12120F" />
          <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 19, letterSpacing: "0.02em", color: "#12120F" }}>
            การแจ้งเตือน
          </span>
          <SearchIcon size={19} strokeWidth={1.4} color="#12120F" />
        </div>

        <div className="mt-1">
          <Tabs active={tab} setActive={setTab} />
        </div>

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 40 - 50 }}>
          {tab === "การกล่าวถึง" ? (
            <EmptyMentions />
          ) : (
            <>
              {groups.map((g) => (
                <div key={g.label}>
                  <GroupLabel label={g.label} />
                  <div>
                    {g.items.map((item) => (
                      <NotificationRow key={item.id} item={item} />
                    ))}
                  </div>
                </div>
              ))}
              <div className="px-6 py-8 text-center text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
                ไม่มีการแจ้งเตือนเพิ่มเติมแล้ว
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
