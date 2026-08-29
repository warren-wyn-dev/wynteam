import React, { useState } from "react";
import { X, Search as SearchIcon } from "lucide-react";

/*
  WYNOS — New message.
  Reached by tapping the pencil icon on the Chat inbox header. A person
  picker, not a full compose screen — selecting someone pushes straight
  into a Chat Thread with them (empty thread, ready to type), matching
  how Drop's "ยกเลิก / primary action" header pattern is reused here too.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const people = [
  { name: "WARREN", handle: "@warren", bg: "#1B3A6B" },
  { name: "ZEN", handle: "@sky_blue", bg: "#8A6D3A" },
  { name: "TYN", handle: "@tyn", bg: "#6B4A6B" },
  { name: "wor._.aa", handle: "@wor._.aa", bg: "#3A5A40" },
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

export default function WynosNewMessage() {
  const [query, setQuery] = useState("");
  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:16</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
          </div>
        </div>
        <div className="flex items-center justify-between px-6 pt-2 pb-2">
          <button><X size={20} strokeWidth={1.5} color="#12120F" /></button>
          <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>ข้อความใหม่</span>
          <span style={{ width: 20 }} />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />
        <div className="px-6 pt-3 pb-2">
          <div className="flex items-center gap-2 px-4 rounded-full" style={{ height: 42, background: "#F1EFE9", border: "1px solid #E8E6E0" }}>
            <SearchIcon size={15} strokeWidth={1.6} color="#B7B4AC" />
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหาผู้ใช้" className="bg-transparent outline-none flex-1 text-[13.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS }} />
          </div>
        </div>
        <div className="px-6 pt-4 pb-2">
          <span className="text-[11px] uppercase" style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}>ติดตามอยู่</span>
        </div>
        <div className="overflow-y-auto">
          {people.map((p) => (
            <button key={p.handle} className="w-full flex items-center gap-3 px-6 py-3">
              <Avatar bg={p.bg} letter={p.name[0]} />
              <div className="text-left">
                <div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{p.name}</div>
                <div className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{p.handle}</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
