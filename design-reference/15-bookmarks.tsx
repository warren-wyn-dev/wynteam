import React, { useState } from "react";
import { ChevronLeft, Heart, MessageCircle, Repeat2, Bookmark } from "lucide-react";

/*
  WYNOS — Bookmarks (saved posts).
  Reached from the side menu and from the "..." menu on any post (Home,
  Post Detail). Reuses the exact post-row pattern from Home/Profile so a
  saved post looks identical to how it looked when you saved it.
  Includes both the populated state and the empty state (toggle at the
  bottom) since a new account will hit the empty state first.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function Avatar({ bg, letter, size = 40 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1px solid #1B3A6B33" }} />
      <div className="flex items-center justify-center rounded-full text-white" style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}>{letter}</div>
    </div>
  );
}

const saved = [
  { id: 1, name: "WARREN", avatarBg: "#1B3A6B", time: "4 ชั่วโมงที่แล้ว", text: "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...", likes: 352, comments: 5, reposts: 13 },
  { id: 2, name: "ZEN", avatarBg: "#8A6D3A", time: "6 ชั่วโมงที่แล้ว", text: "สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้", likes: 128, comments: 2, reposts: 4 },
];

function SavedRow({ post, isLast }) {
  const [removed, setRemoved] = useState(false);
  if (removed) return null;
  return (
    <div className={`px-6 pt-4 pb-4 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <div className="flex gap-3.5">
        <Avatar bg={post.avatarBg} letter={post.name[0]} />
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-2">
            <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{post.name}</span>
            <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{post.time}</span>
          </div>
          <p className="text-[14.5px] mt-1.5 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>{post.text}</p>
          <div className="flex items-center gap-5 mt-3">
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><Heart size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.likes}</span></div>
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><MessageCircle size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.comments}</span></div>
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><Repeat2 size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.reposts}</span></div>
            <button onClick={() => setRemoved(true)} className="ml-auto"><Bookmark size={16} strokeWidth={1.4} fill="#1B3A6B" color="#1B3A6B" /></button>
          </div>
        </div>
      </div>
    </div>
  );
}

function EmptyState() {
  return (
    <div className="px-6 pt-16 text-center">
      <p style={{ fontFamily: FONT_SERIF, fontSize: 19, color: "#12120F", fontWeight: 500 }}>ยังไม่มีโพสต์ที่บันทึกไว้</p>
      <p className="text-[13px] mt-1.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>กดไอคอนบันทึกที่โพสต์ไหนก็ได้ เพื่อเก็บไว้ดูทีหลัง</p>
    </div>
  );
}

export default function WynosBookmarks() {
  const [showEmpty, setShowEmpty] = useState(false);
  return (
    <div className="w-full min-h-screen flex flex-col items-center justify-center py-10 gap-5" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:12</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
          </div>
        </div>
        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>บันทึกไว้</span>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />
        <div className="overflow-y-auto" style={{ height: 844 - 40 - 44 }}>
          {showEmpty ? <EmptyState /> : saved.map((p, i) => <SavedRow key={p.id} post={p} isLast={i === saved.length - 1} />)}
        </div>
      </div>
      <button onClick={() => setShowEmpty((v) => !v)} className="px-4 py-2 rounded-full text-[13px]" style={{ fontFamily: FONT_SANS, fontWeight: 600, background: showEmpty ? "#12120F" : "#FAF9F6", color: showEmpty ? "#FAF9F6" : "#12120F", border: "1px solid #D9D6CE" }}>
        {showEmpty ? "← ดูตัวอย่างที่มีโพสต์" : "ดูตัวอย่าง: ยังไม่มีโพสต์บันทึกไว้"}
      </button>
    </div>
  );
}
