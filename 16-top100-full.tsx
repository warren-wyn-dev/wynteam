import React from "react";
import { ChevronLeft } from "lucide-react";

/*
  WYNOS — Top 100 (full ranked list).
  Reached from "ดูอันดับทั้งหมด (Top 100)" at the bottom of Search.
  Same RankRow pattern as the preview on Search, just the complete list
  instead of the first handful — nothing new to design, this screen is
  Search's list continued.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const baseTags = ["#WYNOS", "#SocialCommerce", "#nevergiveup", "#WYNOSThailand", "#ตลาดนัดงานฝีมือ", "#ลงมือทำ", "#ล้มแล้วลุก", "#believeinyourself", "#keepgoing", "#พัฒนาตัวเอง"];
const list = Array.from({ length: 20 }, (_, i) => ({ rank: i + 1, tag: baseTags[i % baseTags.length], posts: 214 - i * 8 }));

export default function WynosTop100Full() {
  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:15</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
          </div>
        </div>
        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>Top 100</span>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />
        <div className="overflow-y-auto" style={{ height: 844 - 40 - 44 }}>
          {list.map((item, i) => (
            <div key={item.rank} className={`flex items-center gap-3.5 px-6 py-3.5 ${i !== list.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
              <span className="w-7 text-right shrink-0" style={{ fontFamily: FONT_SERIF, fontSize: 17, fontWeight: 500, color: item.rank <= 3 ? "#1B3A6B" : "#C7C4BC" }}>{item.rank}</span>
              <div className="flex-1 min-w-0">
                <p className="text-[14.5px] truncate" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 700 }}>{item.tag}</p>
                <p className="text-[12px] mt-0.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>{item.posts} โพสต์ · กำลังนิยมใน ไทย</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
