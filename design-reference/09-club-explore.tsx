import React, { useState } from "react";
import { ChevronLeft, Search as SearchIcon, Plus } from "lucide-react";

/*
  WYNOS — Explore Club.

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — headline · Inter — everything else

  What changed vs. the reference screenshot, and why:
  - Category chips ("ทั้งหมด / Technology / Gaming / Education") are gone
    entirely, matching the decision to drop category from Create Club and
    the Club detail page — there's no longer a concept of category
    anywhere else in the app, so filtering by one here would be a dead end.
  - The bright cyan glow icon badge and cyan "+ สร้าง Club" button are
    replaced with the same sapphire system used everywhere: a plain
    Fraunces headline (with the one emphasis word in sapphire, not a
    whole different color family), and a sapphire-filled button matching
    Drop/Create-Club/Edit-Profile's primary action style.
  - Without categories, "กำลังนิยม" and "ใหม่ล่าสุด" no longer need
    "ยังไม่มี Club ในหมวดนี้" (empty because of a filter) — instead they
    show real Club rows using the same avatar-ring + name + member-count +
    join-button pattern already used for suggested accounts on Search, so
    browsing Clubs feels like the same interaction as finding people.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function Avatar({ bg, letter, size = 44 }) {
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

const trendingClubs = [
  { id: 1, name: "WYNOS Feedback", members: "2 สมาชิก", bg: "#1B3A6B" },
];

const newestClubs = [
  { id: 2, name: "งานฝีมือไทย", members: "1 สมาชิก", bg: "#8A6D3A" },
];

function ClubRow({ club }) {
  const [joined, setJoined] = useState(false);
  return (
    <div className="flex items-center justify-between px-6 py-3">
      <div className="flex items-center gap-3">
        <Avatar bg={club.bg} letter="W" />
        <div>
          <div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
            {club.name}
          </div>
          <div className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
            {club.members}
          </div>
        </div>
      </div>
      <button
        onClick={() => setJoined((v) => !v)}
        className="px-4 py-1.5 rounded-full text-[12.5px]"
        style={
          joined
            ? { background: "#F1EFE9", color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 }
            : { border: "1px solid #1B3A6B", color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }
        }
      >
        {joined ? "เข้าร่วมแล้ว" : "เข้าร่วม"}
      </button>
    </div>
  );
}

function EmptySection({ text }) {
  return (
    <div className="px-6 pb-2">
      <p className="text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
        {text}
      </p>
    </div>
  );
}

function SectionLabel({ children }) {
  return (
    <div className="px-6 pt-6 pb-2">
      <span
        className="text-[11px] uppercase"
        style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}
      >
        {children}
      </span>
    </div>
  );
}

export default function WynosExploreClub() {
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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:47</span>
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
            สำรวจ Club
          </span>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 44 }}>
          {/* hero */}
          <div className="px-6 pt-6">
            <p style={{ fontFamily: FONT_SERIF, fontSize: 21, fontWeight: 500, color: "#12120F", lineHeight: 1.3 }}>
              เจอคอมมูนิตี้ที่ใช่<span style={{ color: "#1B3A6B" }}>สำหรับคุณ</span>
            </p>
            <p className="text-[13px] mt-1.5 leading-relaxed" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
              ร่วมคอมมูนิตี้ที่คุณสนใจ เชื่อมต่อกับคนที่คิดเหมือนกัน
            </p>

            <button
              className="w-full flex items-center justify-center gap-2 mt-4 py-3 rounded-full"
              style={{ background: "#1B3A6B" }}
            >
              <Plus size={16} strokeWidth={2} color="#FAF9F6" />
              <span className="text-[14px]" style={{ color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}>
                สร้าง Club
              </span>
            </button>
          </div>

          {/* search */}
          <div className="px-6 pt-5">
            <div
              className="flex items-center gap-2 px-4 rounded-full"
              style={{ height: 42, background: "#F1EFE9", border: "1px solid #E8E6E0" }}
            >
              <SearchIcon size={15} strokeWidth={1.6} color="#B7B4AC" />
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="ค้นหา Club"
                className="bg-transparent outline-none flex-1 text-[13.5px]"
                style={{ color: "#12120F", fontFamily: FONT_SANS }}
              />
            </div>
          </div>

          {/* trending */}
          <SectionLabel>กำลังนิยม</SectionLabel>
          {trendingClubs.length > 0 ? (
            trendingClubs.map((c) => <ClubRow key={c.id} club={c} />)
          ) : (
            <EmptySection text="ยังไม่มี Club กำลังนิยมตอนนี้" />
          )}

          {/* newest */}
          <SectionLabel>ใหม่ล่าสุด</SectionLabel>
          {newestClubs.length > 0 ? (
            newestClubs.map((c) => <ClubRow key={c.id} club={c} />)
          ) : (
            <EmptySection text="ยังไม่มี Club ใหม่ตอนนี้" />
          )}
        </div>
      </div>
    </div>
  );
}
