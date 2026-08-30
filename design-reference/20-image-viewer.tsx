import React, { useState } from "react";
import { X, Heart, Send, Bookmark } from "lucide-react";

/*
  WYNOS — Full-screen image viewer.
  Opened by tapping an image inside a post's carousel (Home, Profile,
  Club). Background goes full ink (not paper) since photo viewing wants
  a dark, focused stage — the one screen in the app that intentionally
  breaks from the light palette, the way a lightbox does in most apps.
  Swipe dots at the bottom track position in a multi-image post.
*/

const FONT_SANS = "'Inter', sans-serif";

const images = ["#B98F6B", "#2B2A26", "#7C8B6E"];

export default function WynosImageViewer() {
  const [index, setIndex] = useState(0);
  const [liked, setLiked] = useState(false);

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden flex flex-col" style={{ maxWidth: 390, height: 844, background: "#12120F", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.35)" }}>
        <div className="flex items-center justify-between px-6 pt-5 pb-2 relative z-10">
          <button onClick={() => {}}><X size={22} strokeWidth={1.8} color="#FAF9F6" /></button>
          <span className="text-[13px]" style={{ color: "#FAF9F6CC", fontFamily: FONT_SANS }}>{index + 1} / {images.length}</span>
          <span style={{ width: 22 }} />
        </div>

        <div
          className="flex-1 flex overflow-x-auto snap-x snap-mandatory"
          style={{ scrollbarWidth: "none" }}
          onScroll={(e) => {
            const w = e.currentTarget.clientWidth;
            setIndex(Math.round(e.currentTarget.scrollLeft / w));
          }}
        >
          {images.map((bg, i) => (
            <div key={i} className="w-full h-full shrink-0 snap-start flex items-center justify-center" style={{ background: bg }} />
          ))}
        </div>

        <div className="flex justify-center gap-1.5 py-3">
          {images.map((_, i) => (
            <div key={i} className="rounded-full" style={{ width: i === index ? 14 : 5, height: 5, background: i === index ? "#FAF9F6" : "#FAF9F655", transition: "width 0.2s" }} />
          ))}
        </div>

        <div className="flex items-center justify-center gap-8 px-6 pb-8">
          <button onClick={() => setLiked((v) => !v)}><Heart size={22} strokeWidth={1.6} fill={liked ? "#1B3A6B" : "none"} color={liked ? "#1B3A6B" : "#FAF9F6"} /></button>
          <button><Send size={20} strokeWidth={1.6} color="#FAF9F6" /></button>
          <button><Bookmark size={20} strokeWidth={1.6} color="#FAF9F6" /></button>
        </div>
      </div>
    </div>
  );
}
