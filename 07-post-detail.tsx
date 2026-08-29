import React, { useState } from "react";
import {
  ChevronLeft,
  MoreHorizontal,
  Heart,
  MessageCircle,
  Repeat2,
  Share2,
  Bookmark,
  BadgeCheck,
  Send,
} from "lucide-react";

/*
  WYNOS — Post detail + comments.

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — screen title + avatar initials · Inter — everything else

  How this differs from a Home feed row, and why:
  - The focused post's own text renders at 16px instead of the feed's
    14.5px. A permalink view is the one place a single post has the whole
    screen to itself — it should read like the main event, not a slightly
    bigger feed row.
  - Engagement is shown twice, deliberately, in two different shapes:
    first as a plain-language stat line ("352 ถูกใจ · 13 ReDrop · 1 การเข้าชม")
    directly under the post, then as the tappable icon row below a divider.
    The stat line is for reading; the icon row is for acting. Feed rows
    only need the icon row since you're scanning, not settling in on one
    post.
  - A comment composer is pinned as its own row directly under the action
    bar — always visible, not something you have to scroll to find at the
    bottom of a long thread.
  - Each comment gets the same avatar-ring + name treatment as a post
    author, so a comment thread doesn't feel like a demoted, lesser-styled
    version of the main feed.
  - One comment supports a single nested reply (indented, connected by a
    hairline), reusing the same visual idea as the reply-preview on Home,
    now shown in full rather than truncated to one line.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const post = {
  name: "WARREN",
  verified: false,
  handle: "@warren",
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
  comments: 5,
  reposts: 13,
  views: 1,
};

const comments = [
  {
    id: 1,
    name: "otphichay",
    verified: false,
    avatarBg: "#8A6D3A",
    time: "3 ชั่วโมงที่แล้ว",
    text: "น่ารักมาก เป็นกำลังใจให้นะ 🌿",
    likes: 12,
    reply: {
      name: "WARREN",
      avatarBg: "#1B3A6B",
      time: "2 ชั่วโมงที่แล้ว",
      text: "ขอบคุณมากครับ 🙏",
      likes: 4,
    },
  },
  {
    id: 2,
    name: "wor._.aa",
    verified: false,
    avatarBg: "#3A5A40",
    time: "2 ชั่วโมงที่แล้ว",
    text: "รอใช้งานอยู่เลย เมื่อไหร่จะเปิดตัวจริงครับ",
    likes: 6,
    reply: null,
  },
  {
    id: 3,
    name: "ZEN",
    verified: false,
    avatarBg: "#6B4A6B",
    time: "1 ชั่วโมงที่แล้ว",
    text: "แนวคิดดีมาก อยากเห็นฟีเจอร์ตอนเปิดตัวจริง ๆ",
    likes: 3,
    reply: null,
  },
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

function NameLine({ name, verified, size = 14.5 }) {
  return (
    <span className="inline-flex items-center gap-1">
      <span style={{ fontSize: size, fontFamily: FONT_SANS, fontWeight: 600, color: "#12120F" }}>{name}</span>
      {verified && <BadgeCheck size={size - 1} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
    </span>
  );
}

function FocusedPost() {
  return (
    <div className="px-6 pt-4 pb-4">
      <div className="flex items-center gap-3">
        <Avatar bg={post.avatarBg} letter={post.name[0]} size={44} />
        <div>
          <div className="flex items-baseline gap-1.5">
            <NameLine name={post.name} verified={post.verified} size={15} />
            <span className="text-[12.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
              {post.time}
            </span>
          </div>
          <div className="text-[12.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
            {post.handle}
          </div>
        </div>
        <button className="ml-auto">
          <MoreHorizontal size={18} strokeWidth={1.6} color="#C7C4BC" />
        </button>
      </div>

      <div className="mt-4 space-y-2.5">
        {post.lines.map((line, i) => (
          <p key={i} className="text-[16px] leading-relaxed" style={{ color: "#12120F", fontFamily: FONT_SANS }}>
            {line}
          </p>
        ))}
      </div>

      {post.hashtags.length > 0 && (
        <p className="mt-2.5 text-[14.5px]">
          {post.hashtags.map((h) => (
            <span key={h} style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 500 }}>
              {h}{" "}
            </span>
          ))}
        </p>
      )}

      <div className="flex items-center gap-1.5 mt-3.5 text-[12.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
        <span><span style={{ color: "#12120F", fontWeight: 700 }}>{post.likes}</span> ถูกใจ</span>
        <span>·</span>
        <span><span style={{ color: "#12120F", fontWeight: 700 }}>{post.reposts}</span> ReDrop</span>
        <span>·</span>
        <span><span style={{ color: "#12120F", fontWeight: 700 }}>{post.views}</span> การเข้าชม</span>
      </div>
    </div>
  );
}

function FocusedActionBar({ liked, onLike }) {
  return (
    <div className="flex items-center justify-between px-6 py-1" style={{ borderTop: "1px solid #E8E6E0", borderBottom: "1px solid #E8E6E0" }}>
      <button className="flex items-center justify-center flex-1 py-2.5" onClick={onLike}>
        <Heart size={19} strokeWidth={1.4} color={liked ? "#1B3A6B" : "#8A8880"} fill={liked ? "#1B3A6B" : "none"} />
      </button>
      <button className="flex items-center justify-center flex-1 py-2.5">
        <MessageCircle size={19} strokeWidth={1.4} color="#8A8880" />
      </button>
      <button className="flex items-center justify-center flex-1 py-2.5">
        <Repeat2 size={19} strokeWidth={1.4} color="#8A8880" />
      </button>
      <button className="flex items-center justify-center flex-1 py-2.5">
        <Share2 size={18} strokeWidth={1.4} color="#8A8880" />
      </button>
      <button className="flex items-center justify-center flex-1 py-2.5">
        <Bookmark size={18} strokeWidth={1.4} color="#8A8880" />
      </button>
    </div>
  );
}

function CommentReply({ reply }) {
  return (
    <div className="flex gap-3 mt-3.5 pl-2">
      <div className="w-8 flex justify-center">
        <div className="w-px h-full" style={{ background: "#E8E6E0" }} />
      </div>
      <div className="flex-1 -ml-8 flex gap-3">
        <Avatar bg={reply.avatarBg} letter={reply.name[0]} size={36} />
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-1.5">
            <NameLine name={reply.name} size={13.5} />
            <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{reply.time}</span>
          </div>
          <p className="text-[14px] mt-1 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
            {reply.text}
          </p>
          <div className="flex items-center gap-1 mt-2" style={{ color: "#8A8880" }}>
            <Heart size={14} strokeWidth={1.4} />
            <span className="text-[11.5px]" style={{ fontFamily: FONT_SANS }}>{reply.likes}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function CommentRow({ comment, isLast }) {
  const [liked, setLiked] = useState(false);
  return (
    <div className={`px-6 py-4 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <div className="flex gap-3">
        <Avatar bg={comment.avatarBg} letter={comment.name[0]} size={36} />
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-1.5">
            <NameLine name={comment.name} verified={comment.verified} size={13.5} />
            <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{comment.time}</span>
          </div>
          <p className="text-[14px] mt-1 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
            {comment.text}
          </p>
          <div className="flex items-center gap-4 mt-2">
            <button className="flex items-center gap-1.5" onClick={() => setLiked((v) => !v)} style={{ color: liked ? "#1B3A6B" : "#8A8880" }}>
              <Heart size={14} strokeWidth={1.4} fill={liked ? "#1B3A6B" : "none"} />
              <span className="text-[11.5px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{comment.likes + (liked ? 1 : 0)}</span>
            </button>
            <button className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 }}>
              ตอบกลับ
            </button>
          </div>
        </div>
      </div>
      {comment.reply && <CommentReply reply={comment.reply} />}
    </div>
  );
}

function CommentComposer() {
  const [value, setValue] = useState("");
  return (
    <div className="flex items-center gap-3 px-6 py-3" style={{ borderTop: "1px solid #E8E6E0", background: "#FAF9F6" }}>
      <Avatar bg="#8A6D3A" letter="Z" size={32} />
      <input
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="แสดงความคิดเห็น..."
        className="flex-1 bg-transparent outline-none text-[13.5px]"
        style={{ color: "#12120F", fontFamily: FONT_SANS }}
      />
      <button disabled={!value.trim()}>
        <Send size={18} strokeWidth={1.6} color={value.trim() ? "#1B3A6B" : "#C7C4BC"} />
      </button>
    </div>
  );
}

export default function WynosPostDetail() {
  const [liked, setLiked] = useState(false);

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
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
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:40</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="flex items-center px-4 pt-2 pb-1">
          <button className="p-2"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="ml-1" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>
            โพสต์
          </span>
        </div>

        <div className="h-px" style={{ background: "#E8E6E0" }} />

        <div className="flex-1 overflow-y-auto">
          <FocusedPost />
          <FocusedActionBar liked={liked} onLike={() => setLiked((v) => !v)} />

          <div>
            {comments.map((c, i) => (
              <CommentRow key={c.id} comment={c} isLast={i === comments.length - 1} />
            ))}
            <div className="px-6 py-8 text-center text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
              ไม่มีความคิดเห็นเพิ่มเติมแล้ว
            </div>
          </div>
        </div>

        <CommentComposer />
      </div>
    </div>
  );
}
