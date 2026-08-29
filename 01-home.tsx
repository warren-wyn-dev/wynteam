import React, { useState, useRef } from "react";
import {
  Search as SearchIcon,
  Menu,
  Heart,
  MessageCircle,
  Repeat2,
  Share2,
  Eye,
  Bookmark,
  MoreHorizontal,
  X,
  BadgeCheck,
  ArrowUp,
} from "lucide-react";

/*
  WYNOS — Home feed, "everything we talked about" build.

  Token system:
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — wordmark only · Inter — everything else

  Features demoed here, each behind a real interaction (not just described):
  1. First-time explainer banner — dismissible, shown once
  2. Empty state for a new account with nothing followed yet
     (toggle "ผู้ใช้ใหม่" at the bottom to see it)
  3. Sticky filter tabs while scrolling
  4. "New posts" indicator instead of a silent pull-to-refresh
  5. Double-tap to like on post images, with a heart pop animation
  6. "Liked by X and N others" with stacked avatars, not just a number
  7. One reply preview surfaced under a post
  8. Verified badge for the official WYNOS account
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const posts = [
  {
    id: 1,
    redropBy: "@sky_blue",
    name: "WARREN",
    verified: false,
    time: "4 ชั่วโมงที่แล้ว",
    avatarBg: "#1B3A6B",
    lines: [
      "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...",
      "“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”",
      "เราเห็นของที่ชอบจากโซเชียล แต่พออยากซื้อ กลับต้องไปหาในอีกแอป 😅",
      "ดู → แชร์ → พูดคุย → ค้นพบ → ซื้อ",
    ],
    hashtags: ["#WYNOS", "#SocialCommerce", "#Startup"],
    likes: 352,
    likedBy: ["WARREN", "ZEN"],
    comments: 5,
    reposts: 13,
    views: 1,
    topReply: { name: "otphichay", text: "น่ารักมาก เป็นกำลังใจให้นะ" },
  },
  {
    id: 2,
    name: "ZEN",
    verified: false,
    time: "6 ชั่วโมงที่แล้ว",
    avatarBg: "#8A6D3A",
    lines: ["สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้"],
    hashtags: [],
    likes: 128,
    likedBy: ["WARREN"],
    comments: 2,
    reposts: 4,
    views: 340,
    topReply: null,
  },
  {
    id: 3,
    name: "WYNOS",
    verified: true,
    time: "8 ชั่วโมงที่แล้ว",
    avatarBg: "#3A5A40",
    lines: ["บรรยากาศตลาดนัดงานฝีมือสุดสัปดาห์นี้ 🌿"],
    hashtags: [],
    images: ["#B98F6B", "#2B2A26", "#7C8B6E"],
    likes: 64,
    likedBy: ["ZEN", "WARREN"],
    comments: 3,
    reposts: 0,
    views: 210,
    topReply: { name: "wor._.aa", text: "อยากไปด้วยยย 🥹" },
  },
];

const suggestedToFollow = [
  { name: "WARREN", handle: "@warren", bg: "#1B3A6B" },
  { name: "ZEN", handle: "@sky_blue", bg: "#8A6D3A" },
  { name: "TYN", handle: "@tyn", bg: "#6B4A6B" },
  { name: "WYNOS", handle: "@wynosthailand", bg: "#3A5A40", verified: true },
];

/* ---------- shared bits ---------- */

function Avatar({ bg, letter, size = 40, ring = true }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      {ring && <div className="absolute inset-0 rounded-full" style={{ border: "1px solid #1B3A6B33" }} />}
      <div
        className="flex items-center justify-center rounded-full text-white"
        style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}
      >
        {letter}
      </div>
    </div>
  );
}

function MiniAvatar({ bg, letter, offset }) {
  return (
    <div
      className="absolute flex items-center justify-center rounded-full text-white"
      style={{
        width: 18,
        height: 18,
        left: offset,
        background: bg,
        border: "1.5px solid #FAF9F6",
        fontFamily: FONT_SANS,
        fontSize: 9,
        fontWeight: 700,
      }}
    >
      {letter}
    </div>
  );
}

/* ---------- 1. first-time explainer banner ---------- */

function ExplainerBanner({ onDismiss }) {
  return (
    <div className="px-6 pt-3 pb-1">
      <div
        className="relative rounded-2xl px-4 py-3.5 flex items-start gap-3"
        style={{ background: "#12120F" }}
      >
        <div className="flex-1">
          <p className="text-[13px] leading-snug" style={{ color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 600 }}>
            ดู → แชร์ → ค้นพบ → ซื้อ
          </p>
          <p className="text-[12px] mt-0.5 leading-snug" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
            WYNOS คือพื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น
          </p>
        </div>
        <button onClick={onDismiss} className="shrink-0 mt-0.5">
          <X size={15} strokeWidth={1.8} color="#8A8880" />
        </button>
      </div>
    </div>
  );
}

/* ---------- 2. empty state for a brand-new account ---------- */

function EmptyFeedState() {
  return (
    <div className="px-6 pt-10 pb-8">
      <div className="text-center mb-7">
        <p style={{ fontFamily: FONT_SERIF, fontSize: 20, color: "#12120F", fontWeight: 500 }}>
          ยังไม่มีอะไรให้ดูตรงนี้
        </p>
        <p className="text-[13px] mt-1.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
          ลองติดตามสัก 2-3 คนก่อน แล้วฟีดของคุณจะเริ่มมีเรื่องราว
        </p>
      </div>

      <div className="space-y-4">
        {suggestedToFollow.map((s) => (
          <div key={s.handle} className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Avatar bg={s.bg} letter={s.name[0]} size={38} />
              <div>
                <div className="flex items-center gap-1">
                  <span className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
                    {s.name}
                  </span>
                  {s.verified && <BadgeCheck size={13} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
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

/* ---------- 3 + 4. sticky tabs + new-posts pill ---------- */

function FilterTabs({ active, setActive }) {
  const tabs = ["สำหรับคุณ", "ติดตาม", "ล่าสุด", "จาก Club"];
  return (
    <div className="flex px-6" style={{ background: "#FAF9F6", borderBottom: "1px solid #E8E6E0" }}>
      {tabs.map((t) => (
        <button key={t} onClick={() => setActive(t)} className="relative py-3 mr-6">
          <span
            className="text-[13.5px] whitespace-nowrap"
            style={{ fontFamily: FONT_SANS, fontWeight: active === t ? 600 : 400, color: active === t ? "#12120F" : "#B7B4AC" }}
          >
            {t}
          </span>
          {active === t && (
            <div className="absolute left-0 right-0 -bottom-[1px] rounded-full" style={{ height: 2, background: "#1B3A6B" }} />
          )}
        </button>
      ))}
    </div>
  );
}

function NewPostsPill({ count, onClick }) {
  return (
    <div className="flex justify-center py-2.5" style={{ background: "#FAF9F6" }}>
      <button
        onClick={onClick}
        className="flex items-center gap-1.5 px-4 py-2 rounded-full"
        style={{ background: "#1B3A6B", boxShadow: "0 4px 14px rgba(27,58,107,0.3)" }}
      >
        <ArrowUp size={13} strokeWidth={2.2} color="#FAF9F6" />
        <span className="text-[12.5px]" style={{ color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 600 }}>
          มีโพสต์ใหม่ {count} โพสต์
        </span>
      </button>
    </div>
  );
}

/* ---------- 6. liked-by row ---------- */

function LikedByRow({ likedBy, total }) {
  if (total === 0) return null;
  const shown = likedBy.slice(0, 3);
  const extra = total - shown.length;
  return (
    <div className="flex items-center gap-2 mt-2.5">
      <div className="relative" style={{ width: shown.length * 12 + 10, height: 18 }}>
        {shown.map((n, i) => (
          <MiniAvatar key={n} bg={["#1B3A6B", "#8A6D3A", "#3A5A40"][i % 3]} letter={n[0]} offset={i * 12} />
        ))}
      </div>
      <span className="text-[12px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
        ถูกใจโดย <span style={{ color: "#12120F", fontWeight: 600 }}>{shown[0]}</span>
        {extra > 0 && <> และอีก {extra} คน</>}
      </span>
    </div>
  );
}

/* ---------- 7. reply preview ---------- */

function TopReply({ reply }) {
  if (!reply) return null;
  return (
    <div className="flex items-start gap-2 mt-3 pl-1">
      <div className="w-6 mt-0.5">
        <div className="h-full w-px mx-auto" style={{ background: "#E8E6E0" }} />
      </div>
      <div className="flex-1 -ml-6">
        <span className="text-[12.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
          {reply.name}
        </span>
        <span className="text-[12.5px] ml-1.5" style={{ color: "#5A5850", fontFamily: FONT_SANS }}>
          {reply.text}
        </span>
      </div>
    </div>
  );
}

/* ---------- action bar ---------- */

function ActionBar({ post, liked, onLike }) {
  return (
    <div className="flex items-center gap-5 mt-3.5">
      <button className="flex items-center gap-1.5" onClick={onLike} style={{ color: liked ? "#1B3A6B" : "#8A8880" }}>
        <Heart size={17} strokeWidth={1.4} fill={liked ? "#1B3A6B" : "none"} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>
          {post.likes + (liked ? 1 : 0)}
        </span>
      </button>
      <button className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
        <MessageCircle size={17} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.comments}</span>
      </button>
      <button className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
        <Repeat2 size={17} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.reposts}</span>
      </button>
      <div className="flex items-center gap-1.5" style={{ color: "#C7C4BC" }}>
        <Eye size={16} strokeWidth={1.4} />
        <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.views}</span>
      </div>
    </div>
  );
}

/* ---------- 5. image carousel with double-tap to like ---------- */

function ImageCarousel({ images, onDoubleTap }) {
  const [burst, setBurst] = useState(false);
  const lastTap = useRef(0);

  const handleTap = () => {
    const now = Date.now();
    if (now - lastTap.current < 300) {
      onDoubleTap();
      setBurst(true);
      setTimeout(() => setBurst(false), 700);
    }
    lastTap.current = now;
  };

  return (
    <div
      className="flex gap-2 mt-2 overflow-x-auto -mr-6 pr-6 relative"
      style={{ scrollSnapType: "x mandatory", scrollbarWidth: "none" }}
      onClick={handleTap}
    >
      {images.map((bg, i) => (
        <div
          key={i}
          className="shrink-0 rounded-2xl"
          style={{ width: "82%", aspectRatio: "4 / 5", background: bg, scrollSnapAlign: "start" }}
        />
      ))}
      {burst && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <Heart
            size={72}
            fill="#FAF9F6"
            color="#FAF9F6"
            strokeWidth={0}
            style={{ animation: "heartPop 0.7s ease-out forwards", filter: "drop-shadow(0 4px 16px rgba(0,0,0,0.3))" }}
          />
        </div>
      )}
    </div>
  );
}

/* ---------- post ---------- */

function Post({ post, isLast }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [liked, setLiked] = useState(false);

  return (
    <div className={`px-6 pt-4 pb-4 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      {post.redropBy && (
        <div className="flex items-center gap-1.5 mb-2.5 ml-1">
          <Repeat2 size={12} strokeWidth={1.8} color="#B7B4AC" />
          <span className="text-[11.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
            ReDrop โดย {post.redropBy}
          </span>
        </div>
      )}
      <div className="flex gap-3.5">
        <Avatar bg={post.avatarBg} letter={post.name[0]} />
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between relative">
            <div className="flex items-baseline gap-1.5">
              <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
                {post.name}
              </span>
              {post.verified && <BadgeCheck size={14} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
              <span className="text-[12px] ml-0.5" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
                {post.time}
              </span>
            </div>

            <button onClick={() => setMenuOpen((v) => !v)}>
              <MoreHorizontal size={16} strokeWidth={1.6} color="#C7C4BC" />
            </button>

            {menuOpen && (
              <div
                className="absolute right-0 top-6 z-10 rounded-xl overflow-hidden"
                style={{ background: "#FAF9F6", border: "1px solid #E8E6E0", boxShadow: "0 8px 24px rgba(18,18,15,0.12)", minWidth: 148 }}
              >
                <button className="w-full flex items-center gap-2.5 px-4 py-3" style={{ borderBottom: "1px solid #E8E6E0" }} onClick={() => setMenuOpen(false)}>
                  <Share2 size={15} strokeWidth={1.5} color="#12120F" />
                  <span className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS }}>แชร์</span>
                </button>
                <button className="w-full flex items-center gap-2.5 px-4 py-3" onClick={() => setMenuOpen(false)}>
                  <Bookmark size={15} strokeWidth={1.5} color="#12120F" />
                  <span className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS }}>บันทึก</span>
                </button>
              </div>
            )}
          </div>

          <div className="mt-1.5 space-y-2">
            {post.lines.map((line, i) => (
              <p key={i} className="text-[14.5px] leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
                {line}
              </p>
            ))}
          </div>

          {post.hashtags.length > 0 && (
            <p className="mt-2 text-[13.5px] leading-relaxed">
              {post.hashtags.map((h) => (
                <span key={h} style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 500 }}>
                  {h}{" "}
                </span>
              ))}
            </p>
          )}

          {post.images && <ImageCarousel images={post.images} onDoubleTap={() => setLiked(true)} />}

          <LikedByRow likedBy={post.likedBy} total={post.likes + (liked ? 1 : 0)} />
          <ActionBar post={post} liked={liked} onLike={() => setLiked((v) => !v)} />
          <TopReply reply={post.topReply} />
        </div>
      </div>
    </div>
  );
}

/* ---------- shell ---------- */

export default function WynosHomeFull() {
  const [tab, setTab] = useState("สำหรับคุณ");
  const [bannerDismissed, setBannerDismissed] = useState(false);
  const [showNewPosts, setShowNewPosts] = useState(true);
  const [newUserMode, setNewUserMode] = useState(false);

  return (
    <div className="w-full min-h-screen flex flex-col items-center justify-center py-10 gap-4" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
        @keyframes heartPop {
          0% { transform: scale(0.4); opacity: 0; }
          25% { transform: scale(1.15); opacity: 1; }
          40% { transform: scale(1); opacity: 1; }
          100% { transform: scale(1); opacity: 0; }
        }
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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:00</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="flex items-center justify-between px-6 pt-2 pb-1">
          <Menu size={20} strokeWidth={1.4} color="#12120F" />
          <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 19, letterSpacing: "0.06em", color: "#12120F" }}>
            WYNOS
          </span>
          <SearchIcon size={19} strokeWidth={1.4} color="#12120F" />
        </div>

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 40 }}>
          {!bannerDismissed && <ExplainerBanner onDismiss={() => setBannerDismissed(true)} />}

          <div className="sticky top-0 z-20">
            <FilterTabs active={tab} setActive={setTab} />
            {showNewPosts && !newUserMode && (
              <NewPostsPill count={3} onClick={() => setShowNewPosts(false)} />
            )}
          </div>

          {newUserMode ? (
            <EmptyFeedState />
          ) : (
            <div>
              {posts.map((p, i) => (
                <Post key={p.id} post={p} isLast={i === posts.length - 1} />
              ))}
              <div className="px-6 py-8 text-center text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
                คุณตามทันหมดแล้ว
              </div>
            </div>
          )}
        </div>
      </div>

      {/* demo toggle — not part of the app, just for reviewing this mockup */}
      <button
        onClick={() => setNewUserMode((v) => !v)}
        className="px-4 py-2 rounded-full text-[13px]"
        style={{
          fontFamily: FONT_SANS,
          fontWeight: 600,
          background: newUserMode ? "#12120F" : "#FAF9F6",
          color: newUserMode ? "#FAF9F6" : "#12120F",
          border: "1px solid #D9D6CE",
        }}
      >
        {newUserMode ? "← กลับไปดูฟีดปกติ" : "ดูตัวอย่าง: ผู้ใช้ใหม่ (empty state)"}
      </button>
    </div>
  );
}
