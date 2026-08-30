import React, { useState } from "react";
import {
  Settings,
  Bookmark,
  PenLine,
  BadgeCheck,
  Heart,
  MessageCircle,
  Repeat2,
  Eye,
} from "lucide-react";

/*
  WYNOS — Profile screen, v2.

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — name only · Inter — everything else

  Changes in this pass, per direction:

  1. Removed the "ตอบกลับ" and "มีเดีย" tabs — five tabs crowded into one
     row read as clutter; three (โพสต์ / ReDrop / ถูกใจ) covers what most
     profiles need without a squeeze.
  2. Removed the standalone logout icon from the header — logout is an
     infrequent, higher-consequence action and belongs inside the settings
     (gear) menu rather than sitting in the header with equal visual
     weight to Settings itself. Only the gear icon remains up top.
  3. Removed the "Club ของฉัน" shelf from the profile — it was adding
     visual weight right where the eye lands after the bio, competing with
     the actual point of a profile (who this is, what they post).
  4. De-emphasized "แก้ไขโปรไฟล์": it's no longer a full-width bordered
     button with two more bordered icon-buttons beside it. It's now a
     small centered pill with two plain (borderless) icon buttons next to
     it — editing your own profile is something you do occasionally, not
     the primary action of the screen, so it no longer competes with the
     identity block above it for attention.

  Carried over from v1→v2:
  - Reorganized identity block: avatar → name+badge → handle → bio, all
    centered as one visual unit, then stats, then actions, then tabs —
    consistent top spacing between each section.
  - Posts render as full-width rows (same Post pattern as Home: time,
    full text, hashtags, complete action bar) instead of a 3-column
    image-grid — WYNOS posts are text-first, and a photo-grid format
    truncates them and strips engagement down to a single icon.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const posts = [
  {
    id: 1,
    time: "6 ชั่วโมงที่แล้ว",
    lines: ["สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้"],
    hashtags: [],
    likes: 128,
    comments: 2,
    reposts: 4,
    views: 340,
  },
  {
    id: 2,
    time: "1 วันที่แล้ว",
    lines: ["ถ้าวันนี้ยังไม่มีใครเชื่อในตัวคุณ", "ลองเชื่อตัวเองก่อน"],
    hashtags: ["#believeinyourself"],
    likes: 84,
    comments: 1,
    reposts: 2,
    views: 210,
  },
  {
    id: 3,
    time: "2 วันที่แล้ว",
    lines: ["ความล้มเหลวไม่ได้แปลว่าจบ", "มันแปลว่ายังไม่ถึงเวลา"],
    hashtags: ["#ล้มแล้วลุก", "#keepgoing"],
    likes: 156,
    comments: 6,
    reposts: 9,
    views: 480,
  },
];

function Avatar({ bg, letter, size = 76 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1.5px solid #1B3A6B33" }} />
      <div
        className="flex items-center justify-center rounded-full text-white"
        style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}
      >
        {letter}
      </div>
    </div>
  );
}

function StatBlock({ value, label }) {
  return (
    <div className="text-center">
      <div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>
        {value}
      </div>
      <div className="text-[11.5px] mt-0.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
        {label}
      </div>
    </div>
  );
}

function IdentityBlock() {
  return (
    <div className="flex flex-col items-center px-6 pt-5">
      <Avatar bg="#8A6D3A" letter="Z" />
      <div className="flex items-center gap-1.5 mt-3">
        <span className="text-[17px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>
          ZEN
        </span>
        <BadgeCheck size={15} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />
      </div>
      <span className="text-[13px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
        @sky_blue
      </span>
      <p className="text-[13px] text-center mt-3 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
        เขียนสิ่งที่เชื่อ แชร์สิ่งที่ค้นพบ 🌿
      </p>
    </div>
  );
}

function StatsRow() {
  return (
    <div className="flex items-center justify-center gap-8 px-6 mt-6">
      <StatBlock value="1" label="ผู้ติดตาม" />
      <div className="w-px h-8" style={{ background: "#E8E6E0" }} />
      <StatBlock value="4" label="กำลังติดตาม" />
      <div className="w-px h-8" style={{ background: "#E8E6E0" }} />
      <StatBlock value="6" label="โพสต์" />
    </div>
  );
}

function ActionRow() {
  return (
    <div className="flex items-center justify-center gap-5 px-6 mt-5">
      <button
        className="px-6 py-2 rounded-full text-[13px]"
        style={{ border: "1px solid #E8E6E0", color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}
      >
        แก้ไขโปรไฟล์
      </button>
      <button>
        <Bookmark size={17} strokeWidth={1.4} color="#8A8880" />
      </button>
      <button>
        <PenLine size={17} strokeWidth={1.4} color="#8A8880" />
      </button>
    </div>
  );
}

function Tabs({ active, setActive }) {
  const tabs = ["โพสต์", "ReDrop", "ถูกใจ"];
  return (
    <div className="flex px-2 mt-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
      {tabs.map((t) => (
        <button key={t} onClick={() => setActive(t)} className="relative flex-1 py-3">
          <span
            className="text-[12px]"
            style={{ fontFamily: FONT_SANS, fontWeight: active === t ? 600 : 400, color: active === t ? "#12120F" : "#B7B4AC" }}
          >
            {t}
          </span>
          {active === t && (
            <div
              className="absolute left-1/2 -translate-x-1/2 -bottom-[1px] rounded-full"
              style={{ width: 22, height: 2, background: "#1B3A6B" }}
            />
          )}
        </button>
      ))}
    </div>
  );
}

function ActionBar({ post }) {
  return (
    <div className="flex items-center gap-5 mt-3">
      <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
        <Heart size={16} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.likes}</span>
      </div>
      <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
        <MessageCircle size={16} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.comments}</span>
      </div>
      <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
        <Repeat2 size={16} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.reposts}</span>
      </div>
      <div className="flex items-center gap-1.5" style={{ color: "#C7C4BC" }}>
        <Eye size={15} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.views}</span>
      </div>
    </div>
  );
}

function PostRow({ post, isLast }) {
  return (
    <div className={`px-6 pt-4 pb-4 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
        {post.time}
      </span>
      <div className="mt-1.5 space-y-1.5">
        {post.lines.map((line, i) => (
          <p key={i} className="text-[14.5px] leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
            {line}
          </p>
        ))}
      </div>
      {post.hashtags.length > 0 && (
        <p className="mt-1.5 text-[13.5px]">
          {post.hashtags.map((h) => (
            <span key={h} style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 500 }}>
              {h}{" "}
            </span>
          ))}
        </p>
      )}
      <ActionBar post={post} />
    </div>
  );
}

export default function WynosProfile() {
  const [tab, setTab] = useState("โพสต์");

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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:30</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="flex items-center justify-between px-6 pt-2 pb-1">
          <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 18, color: "#12120F" }}>
            โปรไฟล์
          </span>
          <Settings size={18} strokeWidth={1.4} color="#12120F" />
        </div>

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 40 }}>
          <IdentityBlock />
          <StatsRow />
          <ActionRow />
          <Tabs active={tab} setActive={setTab} />

          <div>
            {posts.map((p, i) => (
              <PostRow key={p.id} post={p} isLast={i === posts.length - 1} />
            ))}
            <div className="px-6 py-8 text-center text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
              ไม่มีโพสต์เพิ่มเติมแล้ว
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
