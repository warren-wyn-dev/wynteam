import React, { useState } from "react";
import { Search as SearchIcon, ChevronRight, MoreHorizontal } from "lucide-react";

/*
  WYNOS — Search screen, simplified to two sections only.

  Token system (same as Home / Notifications):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — display/rank numerals · Inter — everything else

  Brief: "Top 100" is the one signature feature of this screen. Trending
  photos, the standalone hashtag-pill list, and "กำลังเติบโต" (growing
  accounts) sections from the original screenshot are removed entirely —
  Top 100 now IS the trending surface, ranked by hashtag activity right now,
  instead of competing with a separate trending-photo shelf.

  Top 100, redesigned after the X (Twitter) "กำลังได้รับความนิยม" reference:
  - A branded hero card up top ("Top 100" + subtitle + "สำรวจทั้งหมด" button).
    The reference uses a stock Earth photo; ours uses an original abstract
    radial-glow treatment in ink + sapphire instead, so there's no
    photography to license or attribute.
  - Below it, a plain numbered vertical list — rank numeral (Fraunces,
    quiet faint-gray, not competing with the tag text), the hashtag in bold,
    and a one-line meta ("214 โพสต์ · กำลังนิยมใน ไทย") underneath, with a
    "···" overflow icon on the right. Hairline divider between rows, no
    divider after the last one. This mirrors the reference's scan-a-list
    rhythm much more closely than the earlier card-carousel version did.
  - "ดูอันดับทั้งหมด (Top 100)" sits as a single centered link below the
    visible rows, leading to the full ranked list.

  "แนะนำให้ติดตาม" keeps the same avatar-ring + outline-follow-button
  pattern used everywhere else in the app.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const top100 = [
  { rank: 1, tag: "#WYNOS", posts: 214 },
  { rank: 2, tag: "#SocialCommerce", posts: 168 },
  { rank: 3, tag: "#nevergiveup", posts: 142 },
  { rank: 4, tag: "#WYNOSThailand", posts: 97 },
  { rank: 5, tag: "#ตลาดนัดงานฝีมือ", posts: 81 },
  { rank: 6, tag: "#ลงมือทำ", posts: 63 },
];

const suggested = [
  { name: "@zzz", handle: "@zzz", bg: "#1B3A6B" },
  { name: "TYN", handle: "@tyn", bg: "#8A6D3A" },
  { name: "@abc", handle: "@abc", bg: "#3A5A40" },
  { name: "@1234589", handle: "@1234589", bg: "#6B4A6B" },
  { name: "@bubble", handle: "@bubble", bg: "#1B3A6B" },
];

function Avatar({ bg, letter, size = 40 }) {
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

function SectionLabel({ children, action }) {
  return (
    <div className="flex items-center justify-between px-6 mb-3">
      <span
        className="text-[11px] uppercase"
        style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}
      >
        {children}
      </span>
      {action}
    </div>
  );
}

/* ---------- ranked list, X-style ---------- */

function RankRow({ item, isLast }) {
  return (
    <div className={`flex items-center gap-3.5 px-6 py-3.5 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <span
        className="shrink-0 text-right"
        style={{ width: 22, fontFamily: FONT_SERIF, fontSize: 17, fontWeight: 500, color: "#C7C4BC" }}
      >
        {item.rank}
      </span>
      <div className="flex-1 min-w-0">
        <p className="text-[14.5px] truncate" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 700 }}>
          {item.tag}
        </p>
        <p className="text-[12px] mt-0.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
          {item.posts} โพสต์ · กำลังนิยมใน ไทย
        </p>
      </div>
      <button className="shrink-0 px-1">
        <MoreHorizontal size={16} strokeWidth={1.6} color="#C7C4BC" />
      </button>
    </div>
  );
}

function Top100Section() {
  return (
    <div className="pb-2 pt-1">
      <SectionLabel>แฮชแท็กกำลังนิยม</SectionLabel>
      <div>
        {top100.map((item, i) => (
          <RankRow key={item.rank} item={item} isLast={i === top100.length - 1} />
        ))}
      </div>
      <button className="w-full flex items-center justify-center gap-1 py-4">
        <span className="text-[13px]" style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}>
          ดูอันดับทั้งหมด (Top 100)
        </span>
        <ChevronRight size={14} strokeWidth={2.2} color="#1B3A6B" />
      </button>
    </div>
  );
}

/* ---------- suggested to follow ---------- */

function SuggestedSection() {
  return (
    <div className="pb-8">
      <SectionLabel>แนะนำให้ติดตาม</SectionLabel>
      <div className="space-y-4 px-6">
        {suggested.map((s) => (
          <div key={s.handle} className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Avatar bg={s.bg} letter={s.name[1] || s.name[0]} size={38} />
              <div>
                <div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
                  {s.name}
                </div>
                <div className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
                  {s.handle}
                </div>
              </div>
            </div>
            <button
              className="px-4 py-1.5 rounded-full text-[12.5px]"
              style={{ border: "1px solid #1B3A6B", color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}
            >
              ติดตาม
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function WynosSearch() {
  const [query, setQuery] = useState("");

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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:06</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* search bar */}
        <div className="px-6 pt-3 pb-4">
          <div
            className="flex items-center gap-2 px-4 rounded-full"
            style={{ height: 42, background: "#F1EFE9", border: "1px solid #E8E6E0" }}
          >
            <SearchIcon size={16} strokeWidth={1.6} color="#B7B4AC" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="ค้นหา username, Drop, Pop, Club"
              className="bg-transparent outline-none flex-1 text-[13.5px]"
              style={{ color: "#12120F", fontFamily: FONT_SANS }}
            />
          </div>
        </div>

        <div className="overflow-y-auto pt-1" style={{ height: 844 - 40 - 78 }}>
          <Top100Section />
          <SuggestedSection />
        </div>
      </div>
    </div>
  );
}
