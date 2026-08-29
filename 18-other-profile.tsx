import React, { useState } from "react";
import { ChevronLeft, MoreHorizontal, Send, BadgeCheck, Heart, MessageCircle, Repeat2, Eye } from "lucide-react";

/*
  WYNOS — Someone else's profile.
  Same layout as your own Profile (05-profile.jsx), except the action row
  swaps "แก้ไขโปรไฟล์" for "ติดตาม"/"กำลังติดตาม" plus a message icon —
  editing is only ever available on your own profile; everyone else gets
  the actions you'd take *toward* them (follow, message).
  Header also gets a "..." for report/block, which your own profile
  doesn't need.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function Avatar({ bg, letter, size = 76 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1.5px solid #1B3A6B33" }} />
      <div className="flex items-center justify-center rounded-full text-white" style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}>{letter}</div>
    </div>
  );
}

const posts = [
  { id: 1, time: "4 ชั่วโมงที่แล้ว", text: "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...", likes: 352, comments: 5, reposts: 13, views: 1 },
  { id: 2, time: "1 วันที่แล้ว", text: "ดู → แชร์ → พูดคุย → ค้นพบ → ซื้อ", likes: 84, comments: 1, reposts: 2, views: 210 },
];

export default function WynosOtherProfile() {
  const [following, setFollowing] = useState(false);

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:18</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
          </div>
        </div>
        <div className="grid items-center px-2 pt-2 pb-1" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SANS, fontWeight: 700, fontSize: 15, color: "#12120F" }}>@warren</span>
          <button className="p-2 justify-self-end"><MoreHorizontal size={19} strokeWidth={1.6} color="#12120F" /></button>
        </div>

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 40 }}>
          <div className="flex flex-col items-center px-6 pt-4">
            <Avatar bg="#1B3A6B" letter="W" />
            <div className="flex items-center gap-1.5 mt-3">
              <span className="text-[17px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>WARREN</span>
              <BadgeCheck size={15} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />
            </div>
            <span className="text-[13px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>@warren</span>
            <p className="text-[13px] text-center mt-3 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
              กำลังสร้าง WYNOS อยู่ 🚀
            </p>

            <div className="flex items-center justify-center gap-8 mt-6">
              <div className="text-center"><div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>4</div><div className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>ผู้ติดตาม</div></div>
              <div className="w-px h-8" style={{ background: "#E8E6E0" }} />
              <div className="text-center"><div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>1</div><div className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>กำลังติดตาม</div></div>
              <div className="w-px h-8" style={{ background: "#E8E6E0" }} />
              <div className="text-center"><div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>2</div><div className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>โพสต์</div></div>
            </div>

            <div className="flex items-center justify-center gap-2.5 mt-5 w-full">
              <button
                onClick={() => setFollowing((v) => !v)}
                className="flex-1 max-w-[180px] py-2.5 rounded-full text-[13.5px]"
                style={following ? { background: "#F1EFE9", color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 } : { background: "#1B3A6B", color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}
              >
                {following ? "กำลังติดตาม" : "ติดตาม"}
              </button>
              <button className="w-10 h-10 flex items-center justify-center rounded-full shrink-0" style={{ border: "1px solid #E8E6E0" }}>
                <Send size={16} strokeWidth={1.5} color="#12120F" />
              </button>
            </div>
          </div>

          <div className="flex px-2 mt-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
            {["โพสต์", "ReDrop", "ถูกใจ"].map((t, i) => (
              <button key={t} className="relative flex-1 py-3">
                <span className="text-[12px]" style={{ fontFamily: FONT_SANS, fontWeight: i === 0 ? 600 : 400, color: i === 0 ? "#12120F" : "#B7B4AC" }}>{t}</span>
                {i === 0 && <div className="absolute left-1/2 -translate-x-1/2 -bottom-[1px] rounded-full" style={{ width: 22, height: 2, background: "#1B3A6B" }} />}
              </button>
            ))}
          </div>

          {posts.map((p, i) => (
            <div key={p.id} className={`px-6 pt-4 pb-4 ${i !== posts.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
              <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{p.time}</span>
              <p className="text-[14.5px] mt-1.5 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>{p.text}</p>
              <div className="flex items-center gap-5 mt-3">
                <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><Heart size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{p.likes}</span></div>
                <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><MessageCircle size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{p.comments}</span></div>
                <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><Repeat2 size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{p.reposts}</span></div>
                <div className="flex items-center gap-1.5" style={{ color: "#C7C4BC" }}><Eye size={15} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{p.views}</span></div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
