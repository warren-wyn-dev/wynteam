import React, { useState } from "react";
import { ChevronLeft, Search as SearchIcon } from "lucide-react";

/*
  WYNOS — Followers / Following list.
  Reached by tapping the follower/following counts on Profile.
  Same avatar-ring + name + follow-button row pattern used on Search's
  suggested accounts and Club's member rows — a person row looks the same
  everywhere in this app.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const people = [
  { name: "WARREN", handle: "@warren", bg: "#1B3A6B", following: true },
  { name: "ZEN", handle: "@sky_blue", bg: "#8A6D3A", following: false },
  { name: "TYN", handle: "@tyn", bg: "#6B4A6B", following: true },
  { name: "@bubble", handle: "@bubble", bg: "#3A5A40", following: false },
];

function Avatar({ bg, letter, size = 42 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1px solid #1B3A6B33" }} />
      <div className="flex items-center justify-center rounded-full text-white" style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}>{letter}</div>
    </div>
  );
}

function PersonRow({ p }) {
  const [following, setFollowing] = useState(p.following);
  return (
    <div className="flex items-center justify-between px-6 py-3">
      <div className="flex items-center gap-3">
        <Avatar bg={p.bg} letter={p.name[1] || p.name[0]} />
        <div>
          <div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{p.name}</div>
          <div className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{p.handle}</div>
        </div>
      </div>
      <button
        onClick={() => setFollowing((v) => !v)}
        className="px-4 py-1.5 rounded-full text-[12.5px]"
        style={following ? { background: "#F1EFE9", color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 } : { border: "1px solid #1B3A6B", color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}
      >
        {following ? "กำลังติดตาม" : "ติดตาม"}
      </button>
    </div>
  );
}

export default function WynosFollowers() {
  const [tab, setTab] = useState("ผู้ติดตาม");
  const [query, setQuery] = useState("");

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:10</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
          </div>
        </div>

        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>ZEN</span>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />

        <div className="flex px-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
          {["ผู้ติดตาม", "กำลังติดตาม"].map((t) => (
            <button key={t} onClick={() => setTab(t)} className="relative flex-1 py-3">
              <span className="text-[13.5px]" style={{ fontFamily: FONT_SANS, fontWeight: tab === t ? 600 : 400, color: tab === t ? "#12120F" : "#B7B4AC" }}>{t}</span>
              {tab === t && <div className="absolute left-1/2 -translate-x-1/2 -bottom-[1px] rounded-full" style={{ width: 30, height: 2, background: "#1B3A6B" }} />}
            </button>
          ))}
        </div>

        <div className="px-6 pt-3 pb-2">
          <div className="flex items-center gap-2 px-4 rounded-full" style={{ height: 40, background: "#F1EFE9", border: "1px solid #E8E6E0" }}>
            <SearchIcon size={14} strokeWidth={1.6} color="#B7B4AC" />
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหา" className="bg-transparent outline-none flex-1 text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS }} />
          </div>
        </div>

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 44 - 44 - 62 }}>
          {people.map((p) => <PersonRow key={p.handle} p={p} />)}
        </div>
      </div>
    </div>
  );
}
