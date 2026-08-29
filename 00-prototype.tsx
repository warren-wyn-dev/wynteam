import React, { useState, useRef } from "react";
import {
  Menu, Search as SearchIcon, Heart, MessageCircle, Repeat2, Share2, Eye, Bookmark,
  MoreHorizontal, X, BadgeCheck, ChevronLeft, ChevronRight, Plus, User, Users,
  Settings, LogOut, PenLine, Lock, Bell, Moon, HelpCircle, FileText, Send,
  Flag, UserX, AlertTriangle, Eye as EyeIcon, EyeOff,
} from "lucide-react";

/*
  WYNOS — fully connected prototype (v2).

  Every screen designed so far is now wired into one navigation graph:

  Onboarding (Welcome/Sign up/Log in) gates the whole app until "submitted"
    → then the main app loads on the Home tab.

  Bottom nav: Home / Search / Drop / Notifications / Profile
    (Drop pushes over the current tab; it isn't a tab you stay on)

  Home
    → tap ☰                        → Side Menu overlay
    → tap chat icon (top right)    → Chat inbox
    → tap a post's avatar/name     → that person's profile (own → Profile
                                      tab, someone else's → Other Profile)
    → tap a post's body            → Post Detail
    → tap a post's image           → full-screen Image Viewer
    → tap a post's "···"           → Report/Block sheet

  Side Menu
    → "โปรไฟล์"                    → Profile tab
    → "Club ของฉัน"                → toast (not built yet)
    → "บันทึกไว้"                  → Bookmarks

  Post Detail
    → author avatar/name           → their profile (same logic as Home)
    → "···"                        → Report/Block sheet
    → images                       → Image Viewer

  Chat inbox
    → pencil icon                  → New Message (pick a person)
    → a conversation row           → Chat Thread
  New Message → pick a person      → Chat Thread (skips back through
                                      New Message; back from thread goes
                                      straight to the inbox)

  Search
    → "ดูอันดับทั้งหมด"            → Top 100 (full list)
    → a suggested account row      → that person's Other Profile

  Profile (own)
    → gear icon                    → Settings
    → follower / following counts  → Followers/Following list

  Settings → "ออกจากระบบ" is present but inert in this prototype (no real
  auth to tear down) — it's here for completeness of the screen, not as a
  functioning action.

  Navigation model: a single `stack` array of pushed screens. Pushing adds
  to the end, back pops the end, and whatever's on top of the stack always
  hides the bottom nav (same as native stack navigation) — this replaced
  the earlier single `pushed` object from v1, which couldn't represent
  navigating two levels deep (e.g. Post Detail → Other Profile).
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";
const ME = { name: "ZEN", avatarBg: "#8A6D3A" };

/* ---------------------------------- data ---------------------------------- */

const posts = [
  {
    id: 1,
    author: { name: "WARREN", avatarBg: "#1B3A6B", verified: false, handle: "@warren" },
    redropBy: "@sky_blue",
    time: "4 ชั่วโมงที่แล้ว",
    lines: ["WYNOS เริ่มจากคำถามง่าย ๆ ว่า...", "“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”", "ดู → แชร์ → พูดคุย → ค้นพบ → ซื้อ"],
    hashtags: ["#WYNOS", "#SocialCommerce", "#Startup"],
    images: null,
    likes: 352, comments: 5, reposts: 13, views: 1,
  },
  {
    id: 2,
    author: { name: "ZEN", avatarBg: "#8A6D3A", verified: false, handle: "@sky_blue" },
    time: "6 ชั่วโมงที่แล้ว",
    lines: ["สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้"],
    hashtags: [],
    images: null,
    likes: 128, comments: 2, reposts: 4, views: 340,
  },
  {
    id: 3,
    author: { name: "WYNOS", avatarBg: "#3A5A40", verified: true, handle: "@wynosthailand" },
    time: "8 ชั่วโมงที่แล้ว",
    lines: ["บรรยากาศตลาดนัดงานฝีมือสุดสัปดาห์นี้ 🌿"],
    hashtags: [],
    images: ["#B98F6B", "#2B2A26", "#7C8B6E"],
    likes: 64, comments: 3, reposts: 0, views: 210,
  },
];

const comments = [
  { id: 1, name: "otphichay", avatarBg: "#8A6D3A", time: "3 ชั่วโมงที่แล้ว", text: "น่ารักมาก เป็นกำลังใจให้นะ 🌿", likes: 12,
    reply: { name: "WARREN", avatarBg: "#1B3A6B", time: "2 ชั่วโมงที่แล้ว", text: "ขอบคุณมากครับ 🙏", likes: 4 } },
  { id: 2, name: "wor._.aa", avatarBg: "#3A5A40", time: "2 ชั่วโมงที่แล้ว", text: "รอใช้งานอยู่เลยครับ", likes: 6, reply: null },
];

const conversations = [
  { id: 1, name: "WARREN", avatarBg: "#1B3A6B", lastMessage: "โอเคครับ เดี๋ยวส่งไฟล์ให้ดูอีกที", time: "2 นาที", unread: true },
  { id: 2, name: "ZEN", avatarBg: "#8A6D3A", lastMessage: "น่ารักมาก เป็นกำลังใจให้นะ 🌿", time: "1 ชั่วโมง", unread: true },
  { id: 3, name: "WYNOS", avatarBg: "#3A5A40", lastMessage: "ขอบคุณที่เข้าร่วม Club ของเรา!", time: "เมื่อวาน", unread: false },
];

const followList = [
  { name: "WARREN", handle: "@warren", bg: "#1B3A6B", following: true },
  { name: "TYN", handle: "@tyn", bg: "#6B4A6B", following: true },
  { name: "@bubble", handle: "@bubble", bg: "#3A5A40", following: false },
];

const suggested = [
  { name: "WARREN", avatarBg: "#1B3A6B", verified: false, handle: "@warren" },
  { name: "TYN", avatarBg: "#6B4A6B", verified: false, handle: "@tyn" },
];

const top100 = Array.from({ length: 12 }, (_, i) => ({
  rank: i + 1,
  tag: ["#WYNOS", "#SocialCommerce", "#nevergiveup", "#WYNOSThailand", "#ตลาดนัดงานฝีมือ", "#ลงมือทำ"][i % 6],
  posts: 214 - i * 8,
}));

/* ---------------------------------- shared ---------------------------------- */

function Avatar({ bg, letter, size = 40, ring = true }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      {ring && <div className="absolute inset-0 rounded-full" style={{ border: "1px solid #1B3A6B33" }} />}
      <div className="flex items-center justify-center rounded-full text-white" style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}>{letter}</div>
    </div>
  );
}

function StatusBar({ time = "19:00" }) {
  return (
    <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
      <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>{time}</span>
      <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
        <span>5G</span>
        <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
      </div>
    </div>
  );
}

function PushHeader({ title, onBack, right }) {
  return (
    <>
      <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
        <button onClick={onBack} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
        <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>{title}</span>
        <span className="justify-self-end">{right}</span>
      </div>
      <div className="h-px" style={{ background: "#E8E6E0" }} />
    </>
  );
}

/* ---------------------------------- HOME ---------------------------------- */

function FilterTabs({ active, setActive }) {
  const tabs = ["สำหรับคุณ", "ติดตาม", "ล่าสุด", "จาก Club"];
  return (
    <div className="flex px-6" style={{ background: "#FAF9F6", borderBottom: "1px solid #E8E6E0" }}>
      {tabs.map((t) => (
        <button key={t} onClick={() => setActive(t)} className="relative py-3 mr-6">
          <span className="text-[13.5px] whitespace-nowrap" style={{ fontFamily: FONT_SANS, fontWeight: active === t ? 600 : 400, color: active === t ? "#12120F" : "#B7B4AC" }}>{t}</span>
          {active === t && <div className="absolute left-0 right-0 -bottom-[1px] rounded-full" style={{ height: 2, background: "#1B3A6B" }} />}
        </button>
      ))}
    </div>
  );
}

function HomePost({ post, isLast, onOpenPost, onOpenProfile, onOpenImages, onOpenReport }) {
  return (
    <div className={`px-6 pt-4 pb-4 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      {post.redropBy && (
        <div className="flex items-center gap-1.5 mb-2.5 ml-1">
          <Repeat2 size={12} strokeWidth={1.8} color="#B7B4AC" />
          <span className="text-[11.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>ReDrop โดย {post.redropBy}</span>
        </div>
      )}
      <div className="flex gap-3.5">
        <button onClick={() => onOpenProfile(post.author)}><Avatar bg={post.author.avatarBg} letter={post.author.name[0]} /></button>
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between">
            <button onClick={() => onOpenProfile(post.author)} className="flex items-baseline gap-1.5">
              <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{post.author.name}</span>
              {post.author.verified && <BadgeCheck size={13} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
              <span className="text-[12px] ml-0.5" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{post.time}</span>
            </button>
            <button onClick={() => onOpenReport(post)}><MoreHorizontal size={16} strokeWidth={1.6} color="#C7C4BC" /></button>
          </div>
          <button onClick={() => onOpenPost(post)} className="block text-left mt-1.5 space-y-2">
            {post.lines.map((line, i) => <p key={i} className="text-[14.5px] leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>{line}</p>)}
          </button>
          {post.hashtags.length > 0 && (
            <p className="mt-2 text-[13.5px]">{post.hashtags.map((h) => <span key={h} style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 500 }}>{h} </span>)}</p>
          )}
          {post.images && (
            <div className="flex gap-2 mt-2 overflow-x-auto -mr-6 pr-6" style={{ scrollbarWidth: "none" }}>
              {post.images.map((bg, i) => (
                <button key={i} onClick={() => onOpenImages(post.images)} className="shrink-0 rounded-2xl" style={{ width: "82%", aspectRatio: "4 / 5", background: bg }} />
              ))}
            </div>
          )}
          <div className="flex items-center gap-5 mt-3.5">
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><Heart size={17} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.likes}</span></div>
            <button onClick={() => onOpenPost(post)} className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><MessageCircle size={17} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.comments}</span></button>
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}><Repeat2 size={17} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.reposts}</span></div>
            <div className="flex items-center gap-1.5" style={{ color: "#C7C4BC" }}><Eye size={16} strokeWidth={1.4} /><span className="text-[12px]" style={{ fontFamily: FONT_SANS }}>{post.views}</span></div>
          </div>
        </div>
      </div>
    </div>
  );
}

function HomeScreen({ onOpenMenu, onOpenChat, onOpenPost, onOpenProfile, onOpenImages, onOpenReport }) {
  const [tab, setTab] = useState("สำหรับคุณ");
  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center justify-between px-6 pt-2 pb-1">
        <button onClick={onOpenMenu}><Menu size={20} strokeWidth={1.4} color="#12120F" /></button>
        <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 19, letterSpacing: "0.06em", color: "#12120F" }}>WYNOS</span>
        <button onClick={onOpenChat}><Send size={18} strokeWidth={1.5} color="#12120F" /></button>
      </div>
      <div className="flex-1 overflow-y-auto">
        <FilterTabs active={tab} setActive={setTab} />
        {posts.map((p, i) => (
          <HomePost key={p.id} post={p} isLast={i === posts.length - 1} onOpenPost={onOpenPost} onOpenProfile={onOpenProfile} onOpenImages={onOpenImages} onOpenReport={onOpenReport} />
        ))}
        <div className="px-6 py-8 text-center text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>คุณตามทันหมดแล้ว</div>
      </div>
    </div>
  );
}

/* ------------------------------- POST DETAIL ------------------------------- */

function PostDetailScreen({ post, onBack, onOpenProfile, onOpenImages, onOpenReport }) {
  const [liked, setLiked] = useState(false);
  return (
    <div className="h-full flex flex-col">
      <PushHeader title="โพสต์" onBack={onBack} />
      <div className="flex-1 overflow-y-auto">
        <div className="px-6 pt-4 pb-4">
          <div className="flex items-center gap-3">
            <button onClick={() => onOpenProfile(post.author)}><Avatar bg={post.author.avatarBg} letter={post.author.name[0]} size={44} /></button>
            <button onClick={() => onOpenProfile(post.author)} className="text-left">
              <div className="flex items-center gap-1">
                <span style={{ fontSize: 15, fontFamily: FONT_SANS, fontWeight: 600, color: "#12120F" }}>{post.author.name}</span>
                {post.author.verified && <BadgeCheck size={13} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}
              </div>
              <div className="text-[12.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{post.time}</div>
            </button>
            <button onClick={() => onOpenReport(post)} className="ml-auto"><MoreHorizontal size={18} strokeWidth={1.6} color="#C7C4BC" /></button>
          </div>
          <div className="mt-4 space-y-2.5">
            {post.lines.map((line, i) => <p key={i} className="text-[16px] leading-relaxed" style={{ color: "#12120F", fontFamily: FONT_SANS }}>{line}</p>)}
          </div>
          {post.hashtags.length > 0 && (
            <p className="mt-2.5 text-[14.5px]">{post.hashtags.map((h) => <span key={h} style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 500 }}>{h} </span>)}</p>
          )}
          {post.images && (
            <div className="flex gap-2 mt-3 overflow-x-auto -mr-6 pr-6" style={{ scrollbarWidth: "none" }}>
              {post.images.map((bg, i) => (
                <button key={i} onClick={() => onOpenImages(post.images)} className="shrink-0 rounded-2xl" style={{ width: "82%", aspectRatio: "4 / 5", background: bg }} />
              ))}
            </div>
          )}
          <div className="flex items-center gap-1.5 mt-3.5 text-[12.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
            <span><span style={{ color: "#12120F", fontWeight: 700 }}>{post.likes}</span> ถูกใจ</span><span>·</span>
            <span><span style={{ color: "#12120F", fontWeight: 700 }}>{post.reposts}</span> ReDrop</span><span>·</span>
            <span><span style={{ color: "#12120F", fontWeight: 700 }}>{post.views}</span> การเข้าชม</span>
          </div>
        </div>

        <div className="flex items-center justify-between px-6 py-1" style={{ borderTop: "1px solid #E8E6E0", borderBottom: "1px solid #E8E6E0" }}>
          <button onClick={() => setLiked((v) => !v)} className="flex items-center justify-center flex-1 py-2.5"><Heart size={19} strokeWidth={1.4} color={liked ? "#1B3A6B" : "#8A8880"} fill={liked ? "#1B3A6B" : "none"} /></button>
          <button className="flex items-center justify-center flex-1 py-2.5"><MessageCircle size={19} strokeWidth={1.4} color="#8A8880" /></button>
          <button className="flex items-center justify-center flex-1 py-2.5"><Repeat2 size={19} strokeWidth={1.4} color="#8A8880" /></button>
          <button className="flex items-center justify-center flex-1 py-2.5"><Share2 size={18} strokeWidth={1.4} color="#8A8880" /></button>
          <button className="flex items-center justify-center flex-1 py-2.5"><Bookmark size={18} strokeWidth={1.4} color="#8A8880" /></button>
        </div>

        {comments.map((c, i) => (
          <div key={c.id} className={`px-6 py-4 ${i !== comments.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
            <div className="flex gap-3">
              <Avatar bg={c.avatarBg} letter={c.name[0]} size={36} />
              <div className="flex-1 min-w-0">
                <div className="flex items-baseline gap-1.5"><span className="text-[13.5px]" style={{ fontFamily: FONT_SANS, fontWeight: 600, color: "#12120F" }}>{c.name}</span><span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{c.time}</span></div>
                <p className="text-[14px] mt-1 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>{c.text}</p>
              </div>
            </div>
            {c.reply && (
              <div className="flex gap-3 mt-3.5 pl-2">
                <div className="w-8 flex justify-center"><div className="w-px h-full" style={{ background: "#E8E6E0" }} /></div>
                <div className="flex-1 -ml-8 flex gap-3">
                  <Avatar bg={c.reply.avatarBg} letter={c.reply.name[0]} size={36} />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-baseline gap-1.5"><span className="text-[13.5px]" style={{ fontFamily: FONT_SANS, fontWeight: 600, color: "#12120F" }}>{c.reply.name}</span><span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{c.reply.time}</span></div>
                    <p className="text-[14px] mt-1 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>{c.reply.text}</p>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
      <div className="flex items-center gap-3 px-6 py-3" style={{ borderTop: "1px solid #E8E6E0" }}>
        <Avatar bg={ME.avatarBg} letter={ME.name[0]} size={32} />
        <input placeholder="แสดงความคิดเห็น..." className="flex-1 bg-transparent outline-none text-[13.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS }} />
        <Send size={18} strokeWidth={1.6} color="#C7C4BC" />
      </div>
    </div>
  );
}

/* ---------------------------------- CHAT ---------------------------------- */

function ChatScreen({ onBack, onOpenThread, onNewMessage }) {
  return (
    <div className="h-full flex flex-col">
      <PushHeader title="ข้อความ" onBack={onBack} right={<button onClick={onNewMessage}><PenLine size={18} strokeWidth={1.5} color="#12120F" /></button>} />
      <div className="flex-1 overflow-y-auto">
        {conversations.map((c, i) => (
          <button key={c.id} onClick={() => onOpenThread({ name: c.name, avatarBg: c.avatarBg })} className={`w-full flex items-center gap-3.5 px-6 py-3.5 ${i !== conversations.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
            <Avatar bg={c.avatarBg} letter={c.name[0]} size={44} />
            <div className="flex-1 min-w-0 text-left">
              <div className="flex items-center justify-between">
                <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: c.unread ? 700 : 600 }}>{c.name}</span>
                <span className="text-[11.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{c.time}</span>
              </div>
              <div className="flex items-center gap-1.5 mt-0.5">
                {c.unread && <div className="rounded-full shrink-0" style={{ width: 6, height: 6, background: "#1B3A6B" }} />}
                <p className="text-[13px] truncate" style={{ color: c.unread ? "#12120F" : "#8A8880", fontFamily: FONT_SANS }}>{c.lastMessage}</p>
              </div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}

function NewMessageScreen({ onBack, onPick }) {
  const [query, setQuery] = useState("");
  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center justify-between px-6 pt-2 pb-2">
        <button onClick={onBack}><X size={20} strokeWidth={1.5} color="#12120F" /></button>
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
      <div className="overflow-y-auto">
        {conversations.map((p) => (
          <button key={p.name} onClick={() => onPick({ name: p.name, avatarBg: p.avatarBg })} className="w-full flex items-center gap-3 px-6 py-3">
            <Avatar bg={p.avatarBg} letter={p.name[0]} />
            <span className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{p.name}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

const threadMessages = [
  { type: "divider", label: "วันนี้ 18:40" },
  { from: "them", text: "เฮ้ พรุ่งนี้ยังโอเคกับเวลาประชุมเดิมไหมครับ" },
  { from: "them", text: "10 โมงเช้า ที่ร้านกาแฟเดิม" },
  { from: "me", text: "โอเคครับ สะดวกเลย" },
];

function ChatBubble({ from, text, person, showAvatar }) {
  const isMe = from === "me";
  return (
    <div className={`flex items-end gap-2 ${isMe ? "justify-end" : "justify-start"}`}>
      {!isMe && <div style={{ width: 34 }}>{showAvatar && <Avatar bg={person.avatarBg} letter={person.name[0]} size={30} />}</div>}
      <div className="px-4 py-2.5 rounded-2xl max-w-[72%]" style={{ background: isMe ? "#1B3A6B" : "#F1EFE9", borderBottomRightRadius: isMe ? 6 : 18, borderBottomLeftRadius: isMe ? 18 : 6 }}>
        <p className="text-[14px] leading-relaxed" style={{ color: isMe ? "#FAF9F6" : "#12120F", fontFamily: FONT_SANS }}>{text}</p>
      </div>
    </div>
  );
}

function ChatThreadScreen({ person, onBack }) {
  const [message, setMessage] = useState("");
  let lastFrom = null;
  return (
    <div className="h-full flex flex-col">
      <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
        <button onClick={onBack} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
        <div className="flex items-center gap-2 justify-self-center"><Avatar bg={person.avatarBg} letter={person.name[0]} size={28} /><span style={{ fontFamily: FONT_SANS, fontWeight: 700, fontSize: 14.5, color: "#12120F" }}>{person.name}</span></div>
        <span />
      </div>
      <div className="h-px" style={{ background: "#E8E6E0" }} />
      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-2">
        {threadMessages.map((item, i) => {
          if (item.type === "divider") return <div key={i} className="flex justify-center py-1"><span className="text-[11px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>{item.label}</span></div>;
          const showAvatar = item.from === "them" && lastFrom !== "them";
          lastFrom = item.from;
          return <ChatBubble key={i} from={item.from} text={item.text} person={person} showAvatar={showAvatar} />;
        })}
      </div>
      <div className="flex items-center gap-2.5 px-4 py-3" style={{ borderTop: "1px solid #E8E6E0" }}>
        <div className="flex-1 flex items-center px-4 py-2.5 rounded-full" style={{ background: "#F1EFE9", border: "1px solid #E8E6E0" }}>
          <input value={message} onChange={(e) => setMessage(e.target.value)} placeholder="พิมพ์ข้อความ..." className="flex-1 bg-transparent outline-none text-[13.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS }} />
        </div>
        <button className="shrink-0 w-9 h-9 rounded-full flex items-center justify-center" style={{ background: message.trim() ? "#1B3A6B" : "#E8E6E0" }}><Send size={15} strokeWidth={2} color={message.trim() ? "#FAF9F6" : "#B7B4AC"} /></button>
      </div>
    </div>
  );
}

/* --------------------------------- SEARCH --------------------------------- */

function SearchScreen({ onOpenTop100, onOpenProfile }) {
  return (
    <div className="h-full flex flex-col">
      <div className="px-6 pt-3 pb-4">
        <div className="flex items-center gap-2 px-4 rounded-full" style={{ height: 42, background: "#F1EFE9", border: "1px solid #E8E6E0" }}>
          <SearchIcon size={16} strokeWidth={1.6} color="#B7B4AC" />
          <span className="text-[13.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>ค้นหา username, Drop, Pop, Club</span>
        </div>
      </div>
      <div className="flex-1 overflow-y-auto">
        <div className="px-6 pb-2"><span className="text-[11px] uppercase" style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}>แฮชแท็กกำลังนิยม</span></div>
        {top100.slice(0, 3).map((item, i) => (
          <div key={item.rank} className="flex items-center gap-3.5 px-6 py-3.5 border-b" style={{ borderColor: "#E8E6E0" }}>
            <span className="w-6 text-right" style={{ fontFamily: FONT_SERIF, fontSize: 17, fontWeight: 500, color: "#C7C4BC" }}>{item.rank}</span>
            <div><p className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 700 }}>{item.tag}</p><p className="text-[12px] mt-0.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>{item.posts} โพสต์ · กำลังนิยมใน ไทย</p></div>
          </div>
        ))}
        <button onClick={onOpenTop100} className="w-full flex items-center justify-center gap-1 py-4">
          <span className="text-[13px]" style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}>ดูอันดับทั้งหมด (Top 100)</span>
          <ChevronRight size={14} strokeWidth={2.2} color="#1B3A6B" />
        </button>

        <div className="px-6 pt-4 pb-2"><span className="text-[11px] uppercase" style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}>แนะนำให้ติดตาม</span></div>
        {suggested.map((p) => (
          <button key={p.handle} onClick={() => onOpenProfile(p)} className="w-full flex items-center gap-3 px-6 py-3">
            <Avatar bg={p.avatarBg} letter={p.name[0]} size={38} />
            <div className="text-left"><div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{p.name}</div><div className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{p.handle}</div></div>
          </button>
        ))}
      </div>
    </div>
  );
}

function Top100FullScreen({ onBack }) {
  return (
    <div className="h-full flex flex-col">
      <PushHeader title="Top 100" onBack={onBack} />
      <div className="flex-1 overflow-y-auto">
        {top100.map((item, i) => (
          <div key={item.rank} className={`flex items-center gap-3.5 px-6 py-3.5 ${i !== top100.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
            <span className="w-7 text-right shrink-0" style={{ fontFamily: FONT_SERIF, fontSize: 17, fontWeight: 500, color: item.rank <= 3 ? "#1B3A6B" : "#C7C4BC" }}>{item.rank}</span>
            <div className="flex-1 min-w-0"><p className="text-[14.5px] truncate" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 700 }}>{item.tag}</p><p className="text-[12px] mt-0.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>{item.posts} โพสต์ · กำลังนิยมใน ไทย</p></div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ----------------------------------- DROP ----------------------------------- */

function DropScreen({ onClose }) {
  const [caption, setCaption] = useState("");
  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center justify-between px-6 pt-2 pb-3">
        <button onClick={onClose}><span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS }}>ยกเลิก</span></button>
        <button disabled={!caption.trim()} className="px-5 py-1.5 rounded-full" style={{ background: caption.trim() ? "#1B3A6B" : "#E8E6E0" }}>
          <span className="text-[13.5px]" style={{ color: caption.trim() ? "#FAF9F6" : "#B7B4AC", fontFamily: FONT_SANS, fontWeight: 700 }}>โพสต์</span>
        </button>
      </div>
      <div className="h-px" style={{ background: "#E8E6E0" }} />
      <div className="flex-1 px-6 pt-4">
        <div className="flex gap-3.5">
          <Avatar bg={ME.avatarBg} letter={ME.name[0]} />
          <div className="flex-1">
            <div className="px-3 py-1 rounded-full inline-block mt-1" style={{ border: "1px solid #E8E6E0", background: "#F1EFE9" }}><span className="text-[12.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>ทุกคน</span></div>
            <textarea value={caption} onChange={(e) => setCaption(e.target.value)} placeholder="มีอะไรเกิดขึ้นบ้าง" autoFocus className="w-full resize-none outline-none bg-transparent mt-3" style={{ color: "#12120F", fontFamily: FONT_SANS, fontSize: 20, lineHeight: 1.4, minHeight: 140 }} />
          </div>
        </div>
      </div>
    </div>
  );
}

/* ------------------------------- NOTIFICATIONS ------------------------------- */

function NotificationsScreen() {
  const items = [
    { text: "WARREN ถูกใจ Drop ของคุณ", time: "10 ชั่วโมงที่แล้ว" },
    { text: "ZEN แสดงความคิดเห็นบน Drop ของคุณ", time: "11 ชั่วโมงที่แล้ว" },
    { text: "WARREN เริ่มติดตามคุณ", time: "1 วันที่แล้ว" },
  ];
  return (
    <div className="h-full flex flex-col">
      <div className="px-6 pt-2 pb-3"><span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 18, color: "#12120F" }}>การแจ้งเตือน</span></div>
      <div className="h-px" style={{ background: "#E8E6E0" }} />
      <div className="flex-1 overflow-y-auto">
        {items.map((n, i) => (
          <div key={i} className={`flex items-center gap-3.5 px-6 py-4 ${i !== items.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
            <Avatar bg="#1B3A6B" letter="W" size={38} />
            <div><div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>{n.text}</div><div className="text-[12px] mt-0.5" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{n.time}</div></div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* --------------------------------- PROFILE --------------------------------- */

function ProfileScreen({ onOpenSettings, onOpenFollowers }) {
  const [ptab, setPtab] = useState("โพสต์");
  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center justify-between px-6 pt-2 pb-1">
        <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 18, color: "#12120F" }}>โปรไฟล์</span>
        <button onClick={onOpenSettings}><Settings size={18} strokeWidth={1.4} color="#12120F" /></button>
      </div>
      <div className="flex-1 overflow-y-auto">
        <div className="flex flex-col items-center px-6 pt-5">
          <Avatar bg={ME.avatarBg} letter={ME.name[0]} size={76} />
          <div className="flex items-center gap-1.5 mt-3"><span className="text-[17px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>{ME.name}</span><BadgeCheck size={15} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} /></div>
          <span className="text-[13px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>@sky_blue</span>
          <p className="text-[13px] text-center mt-3 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>เขียนสิ่งที่เชื่อ แชร์สิ่งที่ค้นพบ 🌿</p>

          <div className="flex items-center justify-center gap-8 mt-6">
            <button onClick={() => onOpenFollowers("ผู้ติดตาม")} className="text-center"><div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>1</div><div className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>ผู้ติดตาม</div></button>
            <div className="w-px h-8" style={{ background: "#E8E6E0" }} />
            <button onClick={() => onOpenFollowers("กำลังติดตาม")} className="text-center"><div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>4</div><div className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>กำลังติดตาม</div></button>
            <div className="w-px h-8" style={{ background: "#E8E6E0" }} />
            <div className="text-center"><div className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>6</div><div className="text-[11.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>โพสต์</div></div>
          </div>

          <div className="flex items-center justify-center gap-5 mt-5">
            <button className="px-6 py-2 rounded-full text-[13px]" style={{ border: "1px solid #E8E6E0", color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>แก้ไขโปรไฟล์</button>
            <button><Bookmark size={17} strokeWidth={1.4} color="#8A8880" /></button>
            <button><PenLine size={17} strokeWidth={1.4} color="#8A8880" /></button>
          </div>
        </div>

        <div className="flex px-2 mt-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
          {["โพสต์", "ReDrop", "ถูกใจ"].map((t) => (
            <button key={t} onClick={() => setPtab(t)} className="relative flex-1 py-3">
              <span className="text-[12px]" style={{ fontFamily: FONT_SANS, fontWeight: ptab === t ? 600 : 400, color: ptab === t ? "#12120F" : "#B7B4AC" }}>{t}</span>
              {ptab === t && <div className="absolute left-1/2 -translate-x-1/2 -bottom-[1px] rounded-full" style={{ width: 22, height: 2, background: "#1B3A6B" }} />}
            </button>
          ))}
        </div>

        <div className="px-6 pt-4 pb-4">
          <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>6 ชั่วโมงที่แล้ว</span>
          <p className="text-[14.5px] mt-1.5 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>สักวันหนึ่งคุณจะขอบคุณตัวเองในวันนี้</p>
        </div>
      </div>
    </div>
  );
}

function FollowersScreen({ initialTab, onBack }) {
  const [tab, setTab] = useState(initialTab || "ผู้ติดตาม");
  return (
    <div className="h-full flex flex-col">
      <PushHeader title="ZEN" onBack={onBack} />
      <div className="flex px-6" style={{ borderBottom: "1px solid #E8E6E0" }}>
        {["ผู้ติดตาม", "กำลังติดตาม"].map((t) => (
          <button key={t} onClick={() => setTab(t)} className="relative flex-1 py-3">
            <span className="text-[13.5px]" style={{ fontFamily: FONT_SANS, fontWeight: tab === t ? 600 : 400, color: tab === t ? "#12120F" : "#B7B4AC" }}>{t}</span>
            {tab === t && <div className="absolute left-1/2 -translate-x-1/2 -bottom-[1px] rounded-full" style={{ width: 30, height: 2, background: "#1B3A6B" }} />}
          </button>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto">
        {followList.map((p) => (
          <div key={p.handle} className="flex items-center justify-between px-6 py-3">
            <div className="flex items-center gap-3"><Avatar bg={p.bg} letter={p.name[1] || p.name[0]} /><div><div className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{p.name}</div><div className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{p.handle}</div></div></div>
            <button className="px-4 py-1.5 rounded-full text-[12.5px]" style={p.following ? { background: "#F1EFE9", color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 } : { border: "1px solid #1B3A6B", color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}>{p.following ? "กำลังติดตาม" : "ติดตาม"}</button>
          </div>
        ))}
      </div>
    </div>
  );
}

function OtherProfileScreen({ person, onBack, onOpenReport }) {
  const [following, setFollowing] = useState(false);
  return (
    <div className="h-full flex flex-col">
      <div className="grid items-center px-2 pt-2 pb-1" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
        <button onClick={onBack} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
        <span className="justify-self-center" style={{ fontFamily: FONT_SANS, fontWeight: 700, fontSize: 15, color: "#12120F" }}>{person.handle || "@" + person.name.toLowerCase()}</span>
        <button onClick={() => onOpenReport({ author: person })} className="p-2 justify-self-end"><MoreHorizontal size={19} strokeWidth={1.6} color="#12120F" /></button>
      </div>
      <div className="flex-1 overflow-y-auto px-6 pt-4">
        <div className="flex flex-col items-center">
          <Avatar bg={person.avatarBg} letter={person.name[0]} size={76} />
          <div className="flex items-center gap-1.5 mt-3"><span className="text-[17px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>{person.name}</span>{person.verified && <BadgeCheck size={15} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />}</div>
          <span className="text-[13px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{person.handle}</span>

          <div className="flex items-center justify-center gap-2.5 mt-5 w-full">
            <button onClick={() => setFollowing((v) => !v)} className="flex-1 max-w-[180px] py-2.5 rounded-full text-[13.5px]" style={following ? { background: "#F1EFE9", color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 } : { background: "#1B3A6B", color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}>
              {following ? "กำลังติดตาม" : "ติดตาม"}
            </button>
            <button className="w-10 h-10 flex items-center justify-center rounded-full shrink-0" style={{ border: "1px solid #E8E6E0" }}><Send size={16} strokeWidth={1.5} color="#12120F" /></button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* --------------------------------- SETTINGS --------------------------------- */

function SettingsRow({ icon: Icon, label, isLast }) {
  return (
    <button className={`w-full flex items-center gap-3.5 px-6 py-3.5 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <Icon size={18} strokeWidth={1.5} color="#12120F" />
      <span className="flex-1 text-left text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>{label}</span>
      <ChevronRight size={15} strokeWidth={1.8} color="#C7C4BC" />
    </button>
  );
}
function SettingsGroupLabel({ children }) {
  return <div className="px-6 pt-6 pb-2"><span className="text-[11px] uppercase" style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}>{children}</span></div>;
}
function SettingsScreen({ onBack }) {
  return (
    <div className="h-full flex flex-col">
      <PushHeader title="ตั้งค่า" onBack={onBack} />
      <div className="flex-1 overflow-y-auto">
        <SettingsGroupLabel>บัญชี</SettingsGroupLabel>
        <SettingsRow icon={User} label="บัญชี" /><SettingsRow icon={Lock} label="ความเป็นส่วนตัว" isLast />
        <SettingsGroupLabel>การตั้งค่าแอป</SettingsGroupLabel>
        <SettingsRow icon={Bell} label="การแจ้งเตือน" /><SettingsRow icon={Moon} label="ธีมเข้ม" isLast />
        <SettingsGroupLabel>ช่วยเหลือ</SettingsGroupLabel>
        <SettingsRow icon={HelpCircle} label="ช่วยเหลือ" /><SettingsRow icon={FileText} label="ข้อกำหนดและความเป็นส่วนตัว" isLast />
        <div className="pt-8 pb-8">
          <div className="h-px mb-2" style={{ background: "#E8E6E0" }} />
          <button className="w-full flex items-center gap-3.5 px-6 py-3.5"><LogOut size={18} strokeWidth={1.5} color="#8A8880" /><span className="text-[14px]" style={{ color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 500 }}>ออกจากระบบ</span></button>
        </div>
      </div>
    </div>
  );
}

/* --------------------------------- BOOKMARKS --------------------------------- */

function BookmarksScreen({ onBack }) {
  const saved = posts.slice(0, 2);
  return (
    <div className="h-full flex flex-col">
      <PushHeader title="บันทึกไว้" onBack={onBack} />
      <div className="flex-1 overflow-y-auto">
        {saved.map((post, i) => (
          <div key={post.id} className={`px-6 pt-4 pb-4 ${i !== saved.length - 1 ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
            <div className="flex gap-3.5">
              <Avatar bg={post.author.avatarBg} letter={post.author.name[0]} />
              <div className="flex-1 min-w-0">
                <div className="flex items-baseline gap-2"><span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{post.author.name}</span><span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{post.time}</span></div>
                <p className="text-[14.5px] mt-1.5 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>{post.lines[0]}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* --------------------------------- SIDE MENU --------------------------------- */

function SideMenu({ onClose, onGoProfile, onOpenBookmarks, onToast }) {
  const items = [
    { icon: User, label: "โปรไฟล์", action: onGoProfile },
    { icon: Users, label: "Club ของฉัน", action: () => onToast("Club ของฉัน ยังไม่พร้อมใช้งานในตัวอย่างนี้") },
    { icon: Bookmark, label: "บันทึกไว้", action: onOpenBookmarks },
  ];
  return (
    <div className="absolute inset-0 z-30">
      <div className="absolute inset-0" style={{ background: "#12120F55" }} onClick={onClose} />
      <div className="absolute left-0 top-0 bottom-0 flex flex-col" style={{ width: "78%", background: "#FAF9F6", boxShadow: "8px 0 30px rgba(18,18,15,0.2)" }}>
        <StatusBar />
        <div className="flex items-center justify-between px-6 pt-2"><span /><button onClick={onClose} className="p-2 -mr-2"><X size={20} strokeWidth={1.6} color="#8A8880" /></button></div>
        <button onClick={onGoProfile} className="flex items-start gap-3.5 px-6 pt-4 text-left">
          <Avatar bg={ME.avatarBg} letter={ME.name[0]} size={52} />
          <div className="flex-1 min-w-0"><div className="flex items-center gap-1.5"><span className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>{ME.name}</span><BadgeCheck size={14} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} /></div><span className="text-[12.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>@sky_blue</span></div>
          <ChevronRight size={16} strokeWidth={1.8} color="#C7C4BC" className="mt-1" />
        </button>
        <div className="h-px mt-4" style={{ background: "#E8E6E0" }} />
        <div className="flex-1 overflow-y-auto pt-2">
          {items.map((item) => (
            <button key={item.label} onClick={item.action} className="w-full flex items-center gap-3.5 px-6 py-3.5"><item.icon size={19} strokeWidth={1.5} color="#12120F" /><span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>{item.label}</span></button>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ------------------------------- IMAGE VIEWER ------------------------------- */

function ImageViewerScreen({ images, onClose }) {
  const [index, setIndex] = useState(0);
  const [liked, setLiked] = useState(false);
  return (
    <div className="absolute inset-0 z-40 flex flex-col" style={{ background: "#12120F", borderRadius: 44, overflow: "hidden" }}>
      <div className="flex items-center justify-between px-6 pt-5 pb-2">
        <button onClick={onClose}><X size={22} strokeWidth={1.8} color="#FAF9F6" /></button>
        <span className="text-[13px]" style={{ color: "#FAF9F6CC", fontFamily: FONT_SANS }}>{index + 1} / {images.length}</span>
        <span style={{ width: 22 }} />
      </div>
      <div className="flex-1 flex overflow-x-auto snap-x snap-mandatory" style={{ scrollbarWidth: "none" }} onScroll={(e) => setIndex(Math.round(e.currentTarget.scrollLeft / e.currentTarget.clientWidth))}>
        {images.map((bg, i) => <div key={i} className="w-full h-full shrink-0 snap-start" style={{ background: bg }} />)}
      </div>
      <div className="flex justify-center gap-1.5 py-3">{images.map((_, i) => <div key={i} className="rounded-full" style={{ width: i === index ? 14 : 5, height: 5, background: i === index ? "#FAF9F6" : "#FAF9F655" }} />)}</div>
      <div className="flex items-center justify-center gap-8 px-6 pb-8">
        <button onClick={() => setLiked((v) => !v)}><Heart size={22} strokeWidth={1.6} fill={liked ? "#1B3A6B" : "none"} color={liked ? "#1B3A6B" : "#FAF9F6"} /></button>
        <button><Send size={20} strokeWidth={1.6} color="#FAF9F6" /></button>
        <button><Bookmark size={20} strokeWidth={1.6} color="#FAF9F6" /></button>
      </div>
    </div>
  );
}

/* ------------------------------- REPORT/BLOCK ------------------------------- */

function ReportBlockSheet({ target, onClose }) {
  const [step, setStep] = useState("main");
  const [selected, setSelected] = useState(null);
  const reasons = ["สแปมหรือหลอกลวง", "เนื้อหาไม่เหมาะสม", "การคุกคามหรือกลั่นแกล้ง", "อื่น ๆ"];
  const name = target?.author?.name || "ผู้ใช้นี้";

  return (
    <div className="absolute inset-0 z-30 flex items-end">
      <div className="absolute inset-0" style={{ background: "#12120F55" }} onClick={onClose} />
      <div className="relative w-full rounded-t-3xl pb-8 pt-3" style={{ background: "#FAF9F6" }}>
        <div className="flex justify-center mb-2"><div className="rounded-full" style={{ width: 36, height: 4, background: "#E8E6E0" }} /></div>

        {step === "main" && (
          <>
            <button onClick={() => setStep("report")} className="w-full flex items-center gap-3.5 px-6 py-4">
              <Flag size={18} strokeWidth={1.6} color="#12120F" /><span className="flex-1 text-left text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>รายงานโพสต์นี้</span><ChevronRight size={16} strokeWidth={1.8} color="#C7C4BC" />
            </button>
            <div className="h-px mx-6" style={{ background: "#E8E6E0" }} />
            <button onClick={() => setStep("block")} className="w-full flex items-center gap-3.5 px-6 py-4">
              <UserX size={18} strokeWidth={1.6} color="#12120F" /><span className="flex-1 text-left text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>บล็อก {name}</span><ChevronRight size={16} strokeWidth={1.8} color="#C7C4BC" />
            </button>
          </>
        )}

        {step === "report" && (
          <>
            <div className="px-6 pb-2"><span style={{ fontFamily: FONT_SERIF, fontSize: 16, fontWeight: 500, color: "#12120F" }}>ทำไมคุณถึงรายงานโพสต์นี้</span></div>
            {reasons.map((r, i) => (
              <button key={r} onClick={() => setSelected(r)} className="w-full flex items-center justify-between px-6 py-3.5" style={{ borderTop: i === 0 ? "1px solid #E8E6E0" : "none", borderBottom: "1px solid #E8E6E0" }}>
                <span className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS }}>{r}</span>
                <div className="rounded-full" style={{ width: 16, height: 16, border: `1.5px solid ${selected === r ? "#1B3A6B" : "#C7C4BC"}`, background: selected === r ? "#1B3A6B" : "transparent" }} />
              </button>
            ))}
            <div className="px-6 pt-4">
              <button onClick={onClose} disabled={!selected} className="w-full py-3 rounded-full text-[13.5px]" style={{ background: selected ? "#1B3A6B" : "#E8E6E0", color: selected ? "#FAF9F6" : "#B7B4AC", fontFamily: FONT_SANS, fontWeight: 700 }}>ส่งรายงาน</button>
            </div>
          </>
        )}

        {step === "block" && (
          <>
            <div className="px-6 pb-4 flex flex-col items-center text-center">
              <AlertTriangle size={28} strokeWidth={1.5} color="#1B3A6B" />
              <p className="mt-3" style={{ fontFamily: FONT_SERIF, fontSize: 17, fontWeight: 500, color: "#12120F" }}>บล็อก {name}?</p>
              <p className="text-[13px] mt-1.5 leading-relaxed" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>{name} จะไม่สามารถติดตามหรือส่งข้อความหาคุณได้อีก</p>
            </div>
            <div className="px-6 space-y-2.5">
              <button onClick={onClose} className="w-full py-3 rounded-full text-[13.5px]" style={{ background: "#1B3A6B", color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}>บล็อก</button>
              <button onClick={() => setStep("main")} className="w-full py-3 rounded-full text-[13.5px]" style={{ border: "1px solid #E8E6E0", color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>ยกเลิก</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* -------------------------------- ONBOARDING -------------------------------- */

function TextField({ label, value, onChange, type = "text", placeholder }) {
  const [show, setShow] = useState(false);
  const isPassword = type === "password";
  return (
    <div className="pt-4">
      <label className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>{label}</label>
      <div className="flex items-center mt-2" style={{ borderBottom: "1px solid #E8E6E0", paddingBottom: 10 }}>
        <input value={value} onChange={(e) => onChange(e.target.value)} type={isPassword && !show ? "password" : "text"} placeholder={placeholder} className="flex-1 bg-transparent outline-none text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS }} />
        {isPassword && <button onClick={() => setShow((v) => !v)}>{show ? <EyeOff size={16} strokeWidth={1.6} color="#8A8880" /> : <EyeIcon size={16} strokeWidth={1.6} color="#8A8880" />}</button>}
      </div>
    </div>
  );
}
function PrimaryButton({ children, disabled, onClick }) {
  return <button onClick={onClick} disabled={disabled} className="w-full py-3.5 rounded-full text-[14px]" style={{ background: disabled ? "#E8E6E0" : "#1B3A6B", color: disabled ? "#B7B4AC" : "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}>{children}</button>;
}

function OnboardingFlow({ onComplete }) {
  const [screen, setScreen] = useState("welcome");
  const [name, setName] = useState(""), [email, setEmail] = useState(""), [password, setPassword] = useState("");

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <div className="relative w-full overflow-hidden flex flex-col" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <StatusBar />
        {screen === "welcome" && (
          <>
            <div className="flex-1 flex flex-col justify-center px-8">
              <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 34, letterSpacing: "0.03em", color: "#12120F" }}>WYNOS</span>
              <p className="text-[14px] mt-2 leading-relaxed" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>ดู → แชร์ → ค้นพบ → ซื้อ<br />พื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น</p>
            </div>
            <div className="px-8 pb-10 space-y-3">
              <PrimaryButton onClick={() => setScreen("signup")}>สร้างบัญชีใหม่</PrimaryButton>
              <button onClick={() => setScreen("login")} className="w-full py-3.5 rounded-full text-[14px]" style={{ border: "1px solid #E8E6E0", color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>เข้าสู่ระบบ</button>
            </div>
          </>
        )}
        {screen === "signup" && (
          <>
            <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
              <button onClick={() => setScreen("welcome")} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
              <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>สร้างบัญชี</span><span />
            </div>
            <div className="flex-1 overflow-y-auto px-6 pt-2">
              <TextField label="ชื่อ" value={name} onChange={setName} placeholder="ชื่อของคุณ" />
              <TextField label="อีเมล" value={email} onChange={setEmail} placeholder="you@email.com" />
              <TextField label="รหัสผ่าน" value={password} onChange={setPassword} type="password" placeholder="อย่างน้อย 6 ตัวอักษร" />
            </div>
            <div className="px-6 pb-8 pt-4"><PrimaryButton disabled={!(name && email && password.length >= 6)} onClick={onComplete}>สร้างบัญชี</PrimaryButton></div>
          </>
        )}
        {screen === "login" && (
          <>
            <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
              <button onClick={() => setScreen("welcome")} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
              <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>เข้าสู่ระบบ</span><span />
            </div>
            <div className="flex-1 overflow-y-auto px-6 pt-2">
              <TextField label="อีเมล" value={email} onChange={setEmail} placeholder="you@email.com" />
              <TextField label="รหัสผ่าน" value={password} onChange={setPassword} type="password" placeholder="รหัสผ่านของคุณ" />
            </div>
            <div className="px-6 pb-8 pt-4"><PrimaryButton disabled={!(email && password)} onClick={onComplete}>เข้าสู่ระบบ</PrimaryButton></div>
          </>
        )}
      </div>
    </div>
  );
}

/* --------------------------------- BOTTOM NAV --------------------------------- */

function BottomNav({ tab, setTab }) {
  const items = [{ key: "home" }, { key: "search", icon: SearchIcon }, { key: "drop", icon: Plus }, { key: "notifications", icon: Heart }, { key: "profile", icon: User }];
  return (
    <div className="flex items-center" style={{ height: 62, background: "#FAF9F6", borderTop: "1px solid #E8E6E0" }}>
      {items.map((item) => {
        const active = tab === item.key;
        const Icon = item.icon;
        return (
          <button key={item.key} onClick={() => setTab(item.key)} className="relative flex-1 h-full flex items-center justify-center">
            {item.key === "home" ? <div className="rounded-full" style={{ width: 20, height: 20, border: `1.4px solid ${active ? "#12120F" : "#C7C4BC"}` }} /> : <Icon size={20} strokeWidth={1.4} color={active ? "#12120F" : "#C7C4BC"} />}
            {active && <div className="absolute bottom-1 rounded-full" style={{ width: 14, height: 2, background: "#1B3A6B" }} />}
          </button>
        );
      })}
    </div>
  );
}

/* ------------------------------------ APP ------------------------------------ */

export default function WynosPrototype() {
  const [authed, setAuthed] = useState(false);
  const [tab, setTab] = useState("home");
  const [stack, setStack] = useState([]);
  const [menuOpen, setMenuOpen] = useState(false);
  const [sheet, setSheet] = useState(null);
  const [viewerImages, setViewerImages] = useState(null);
  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);

  const push = (entry) => setStack((s) => [...s, entry]);
  const pop = () => setStack((s) => s.slice(0, -1));
  const goTab = (key) => { setStack([]); setMenuOpen(false); setTab(key); };

  const showToast = (msg) => {
    setToast(msg);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 1800);
  };

  const onOpenProfile = (person) => {
    if (person.name === ME.name) goTab("profile");
    else push({ screen: "otherProfile", person });
  };

  if (!authed) return <OnboardingFlow onComplete={() => setAuthed(true)} />;

  const current = stack[stack.length - 1];

  let body;
  if (current?.screen === "postDetail") {
    body = <PostDetailScreen post={current.post} onBack={pop} onOpenProfile={onOpenProfile} onOpenImages={setViewerImages} onOpenReport={(post) => setSheet({ target: post })} />;
  } else if (current?.screen === "settings") {
    body = <SettingsScreen onBack={pop} />;
  } else if (current?.screen === "bookmarks") {
    body = <BookmarksScreen onBack={pop} />;
  } else if (current?.screen === "followers") {
    body = <FollowersScreen initialTab={current.initialTab} onBack={pop} />;
  } else if (current?.screen === "otherProfile") {
    body = <OtherProfileScreen person={current.person} onBack={pop} onOpenReport={(t) => setSheet({ target: t })} />;
  } else if (current?.screen === "top100") {
    body = <Top100FullScreen onBack={pop} />;
  } else if (current?.screen === "newMessage") {
    body = <NewMessageScreen onBack={pop} onPick={(person) => setStack((s) => [...s.slice(0, -1), { screen: "chatThread", person }])} />;
  } else if (current?.screen === "chatThread") {
    body = <ChatThreadScreen person={current.person} onBack={() => setStack((s) => [...s.slice(0, -1), { screen: "chat" }])} />;
  } else if (current?.screen === "chat") {
    body = <ChatScreen onBack={pop} onOpenThread={(person) => push({ screen: "chatThread", person })} onNewMessage={() => push({ screen: "newMessage" })} />;
  } else if (tab === "home") {
    body = (
      <HomeScreen
        onOpenMenu={() => setMenuOpen(true)}
        onOpenChat={() => push({ screen: "chat" })}
        onOpenPost={(post) => push({ screen: "postDetail", post })}
        onOpenProfile={onOpenProfile}
        onOpenImages={setViewerImages}
        onOpenReport={(post) => setSheet({ target: post })}
      />
    );
  } else if (tab === "search") {
    body = <SearchScreen onOpenTop100={() => push({ screen: "top100" })} onOpenProfile={onOpenProfile} />;
  } else if (tab === "drop") {
    body = <DropScreen onClose={() => goTab("home")} />;
  } else if (tab === "notifications") {
    body = <NotificationsScreen />;
  } else if (tab === "profile") {
    body = <ProfileScreen onOpenSettings={() => push({ screen: "settings" })} onOpenFollowers={(t) => push({ screen: "followers", initialTab: t })} />;
  }

  const showBottomNav = stack.length === 0;

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden flex flex-col" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <StatusBar />
        <div className="flex-1 min-h-0">{body}</div>
        {showBottomNav && <BottomNav tab={tab} setTab={goTab} />}

        {menuOpen && <SideMenu onClose={() => setMenuOpen(false)} onGoProfile={() => goTab("profile")} onOpenBookmarks={() => { setMenuOpen(false); push({ screen: "bookmarks" }); }} onToast={showToast} />}
        {sheet && <ReportBlockSheet target={sheet.target} onClose={() => setSheet(null)} />}
        {viewerImages && <ImageViewerScreen images={viewerImages} onClose={() => setViewerImages(null)} />}

        {toast && (
          <div className="absolute left-1/2 -translate-x-1/2 bottom-24 px-4 py-2.5 rounded-full z-40" style={{ background: "#12120F" }}>
            <span className="text-[12.5px]" style={{ color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 600 }}>{toast}</span>
          </div>
        )}
      </div>
    </div>
  );
}
