import React, { useState, useRef } from "react";
import { Globe, ChevronDown, Image as ImageIcon, Camera, BarChart2, MapPin, X } from "lucide-react";

/*
  WYNOS — Drop (create post) screen, v2.

  Rebuilt around the compose pattern shown in the X / Threads reference
  screenshots instead of the earlier "toggle mode, then fill a form" layout:
  text input is the main event, front and center, and attachments (photo,
  poll, location) are optional tools reached through a toolbar — not a
  structural choice you make before you've even started typing.

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — nowhere on this screen, deliberately: compose is a writing
  surface, not a branding moment, so it's Inter top to bottom.

  What was taken from the references, and what changed:
  - Header: "ยกเลิก" (Cancel) as plain text top-left, primary action as a
    filled pill top-right — same bones as X's compose bar. The pill uses
    sapphire instead of X's light blue, and is disabled (faint, flat) until
    there's something to post, which neither reference actually shows but
    is worth keeping from the previous version of this screen.
  - Avatar + audience selector chip ("ทุกคน ⌄") sits directly under the
    header, exactly like both references — this is a pattern worth keeping
    as-is, it's a solved problem.
  - The caption is now a large, borderless, autofocus text area at 20px
    (not 14.5px) — compose screens read at a larger size than feed posts
    everywhere, because you're looking at 1-2 lines up close while typing,
    not scanning a dense feed.
  - Selected photos appear as a thumbnail strip directly under the text,
    each with its own remove button — same behavior as v1, just relocated
    since the dashed picker box is gone as a default empty state.
  - A single reply-permission row ("ทุกคนสามารถตอบกลับ") with a globe icon
    sits above the toolbar, matching the reference's pattern of surfacing
    who-can-reply as a tappable row rather than a buried setting.
  - Bottom toolbar: photo, camera, poll, location — the four attachment
    types that make sense for WYNOS today. Left deliberately shorter than
    X's toolbar (no GIF/live/music) since those aren't part of this
    product's scope right now; add icons here later rather than padding
    the row with placeholders.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";
const MAX_CHARS = 500;

function Avatar({ bg = "#1B3A6B", letter = "W", size = 40 }) {
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

function AudienceChip({ value, onClick }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-1 px-3 py-1 rounded-full mt-1"
      style={{ border: "1px solid #E8E6E0", background: "#F1EFE9" }}
    >
      <span className="text-[12.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
        {value}
      </span>
      <ChevronDown size={13} strokeWidth={2} color="#8A8880" />
    </button>
  );
}

function ImageStrip({ images, onRemove }) {
  if (images.length === 0) return null;
  return (
    <div className="flex gap-2 mt-3 overflow-x-auto -mr-6 pr-6" style={{ scrollbarWidth: "none" }}>
      {images.map((bg, i) => (
        <div key={i} className="relative shrink-0 rounded-2xl overflow-hidden" style={{ width: 128, height: 160, background: bg }}>
          <button
            onClick={() => onRemove(i)}
            className="absolute top-2 right-2 w-6 h-6 rounded-full flex items-center justify-center"
            style={{ background: "#12120FCC" }}
          >
            <X size={13} strokeWidth={2} color="#FAF9F6" />
          </button>
        </div>
      ))}
    </div>
  );
}

function ReplyPermissionRow({ value }) {
  return (
    <button className="flex items-center gap-1.5 py-2.5">
      <Globe size={14} strokeWidth={1.7} color="#1B3A6B" />
      <span className="text-[12.5px]" style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}>
        {value}
      </span>
    </button>
  );
}

function Toolbar({ onAddImage }) {
  const items = [
    { icon: ImageIcon, onClick: onAddImage },
    { icon: Camera, onClick: () => {} },
    { icon: BarChart2, onClick: () => {} },
    { icon: MapPin, onClick: () => {} },
  ];
  return (
    <div className="flex items-center gap-5 px-6 py-3" style={{ borderTop: "1px solid #E8E6E0" }}>
      {items.map(({ icon: Icon, onClick }, i) => (
        <button key={i} onClick={onClick}>
          <Icon size={19} strokeWidth={1.5} color="#1B3A6B" />
        </button>
      ))}
    </div>
  );
}

export default function WynosDrop() {
  const [caption, setCaption] = useState("");
  const [images, setImages] = useState([]);
  const textareaRef = useRef(null);

  const sampleColors = ["#B98F6B", "#2B2A26", "#7C8B6E", "#6B4A6B", "#8A6D3A"];
  const addImage = () => setImages((prev) => [...prev, sampleColors[prev.length % sampleColors.length]]);
  const removeImage = (i) => setImages((prev) => prev.filter((_, idx) => idx !== i));

  const hasContent = caption.trim().length > 0 || images.length > 0;

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
        textarea::placeholder { color: #C7C4BC; }
      `}</style>

      <div
        className="relative w-full overflow-hidden flex flex-col"
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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:22</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="flex items-center justify-between px-6 pt-2 pb-3">
          <button>
            <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS }}>
              ยกเลิก
            </span>
          </button>
          <button
            disabled={!hasContent}
            className="px-5 py-1.5 rounded-full"
            style={{ background: hasContent ? "#1B3A6B" : "#E8E6E0" }}
          >
            <span
              className="text-[13.5px]"
              style={{ color: hasContent ? "#FAF9F6" : "#B7B4AC", fontFamily: FONT_SANS, fontWeight: 700 }}
            >
              โพสต์
            </span>
          </button>
        </div>

        <div className="h-px" style={{ background: "#E8E6E0" }} />

        {/* compose body */}
        <div className="flex-1 overflow-y-auto px-6 pt-4">
          <div className="flex gap-3.5">
            <Avatar />
            <div className="flex-1 min-w-0">
              <AudienceChip value="ทุกคน" onClick={() => {}} />

              <textarea
                ref={textareaRef}
                value={caption}
                maxLength={MAX_CHARS}
                onChange={(e) => setCaption(e.target.value)}
                placeholder="มีอะไรเกิดขึ้นบ้าง"
                autoFocus
                className="w-full resize-none outline-none bg-transparent mt-3"
                style={{ color: "#12120F", fontFamily: FONT_SANS, fontSize: 20, lineHeight: 1.4, minHeight: 120 }}
              />

              <ImageStrip images={images} onRemove={removeImage} />

              <div className="flex items-center justify-between">
                <ReplyPermissionRow value="ทุกคนสามารถตอบกลับ" />
                {caption.length > MAX_CHARS * 0.8 && (
                  <span className="text-[11.5px] tabular-nums" style={{ color: "#1B3A6B", fontFamily: FONT_SANS }}>
                    {MAX_CHARS - caption.length}
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        <Toolbar onAddImage={addImage} />
      </div>
    </div>
  );
}
