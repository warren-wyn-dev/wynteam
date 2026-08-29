import React, { useState } from "react";
import {
  ChevronLeft,
  Image as ImageIcon,
  Share2,
  MoreHorizontal,
  Heart,
  MessageCircle,
  Bookmark,
  Plus,
  FileText,
  Users,
  Info,
  Check,
} from "lucide-react";

/*
  WYNOS — Club screens (Create Club + Club detail).

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — headings only · Inter — everything else

  What changed vs. the two reference screenshots, and why:

  CREATE CLUB
  - Cover picker becomes a rounded-2xl dashed box in the paper/canvas
    palette instead of flat gray, matching the same empty-state picker
    pattern already used in Drop's image picker — one visual language for
    "tap to add media" everywhere in the app, not a special case here.
  - Text field labels move to a proper floating-label pattern (small label
    above, hairline underline) instead of a label sitting directly above a
    full-width divider with no visual grouping — same field, tighter unit.
  - "สร้าง Club" button uses the same disabled/enabled sapphire-vs-faint
    pattern as the "แชร์"/"โพสต์" buttons on Drop, so button states read
    the same way across the whole app.

  CLUB DETAIL
  - The reference banner is a composited marketing screenshot (app UI
    mockups, a mascot illustration, several nested screenshots-of-
    screenshots). That's exactly the kind of busy, stock-feeling asset
    the rest of this app has been moving away from, and it's not
    something to recreate pixel-for-pixel (it reads as a specific
    marketing artifact, not a reusable UI pattern). Replaced with an
    original ink+sapphire abstract banner carrying just the Club name in
    Fraunces — quieter, and unambiguously ours.
  - Avatar moves from overlapping the banner (which forces a fixed banner
    height and clips awkwardly on smaller screens) to sitting inline in
    the header block below the banner, same layout idea as the Profile
    screen's identity block, for consistency.
  - Tabs get the same thin sapphire-underline treatment used everywhere
    else (Home, Notifications, Search, Profile) instead of a filled-icon
    active state that doesn't match any other tab bar in the app.
  - Club posts reuse the same row pattern as Home/Profile posts (name,
    time, text, action bar) rather than a bespoke smaller-scale card.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

/* ============================= CREATE CLUB ============================= */

function Field({ label, value, onChange, placeholder, maxLength, multiline, dense }) {
  const Tag = multiline ? "textarea" : "input";
  return (
    <div className={dense ? "pt-4" : "px-6 pt-4"}>
      <label className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>
        {label}
      </label>
      <Tag
        value={value}
        onChange={(e) => onChange(e.target.value)}
        maxLength={maxLength}
        rows={multiline ? 3 : undefined}
        placeholder={placeholder}
        className="w-full bg-transparent outline-none mt-2 text-[14.5px] resize-none"
        style={{ color: "#12120F", fontFamily: FONT_SANS, borderBottom: "1px solid #E8E6E0", paddingBottom: 10 }}
      />
      <div className="flex justify-between mt-1.5">
        <span className="text-[11.5px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
          {multiline ? "อธิบาย Club นี้สั้น ๆ (ไม่บังคับ)" : `1-${maxLength} ตัวอักษร`}
        </span>
        <span className="text-[11.5px] tabular-nums" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
          {value.length}/{maxLength}
        </span>
      </div>
    </div>
  );
}

/*
  CreateClubScreen — single-card layout (chosen from three variants).
  Cover picker, name, description, and privacy all sit inside one bordered
  card instead of being loose full-width sections down the page. The card
  is what gives this screen its "contained, tidy" feel — the form no
  longer needs to stretch edge-to-edge to look complete; it just needs to
  fill the card.
*/

function CreateClubScreen() {
  const [name, setName] = useState("");
  const [desc, setDesc] = useState("");
  const [privacy, setPrivacy] = useState("สาธารณะ");
  const canCreate = name.trim().length > 0;

  return (
    <div className="h-full flex flex-col">
      <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
        <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
        <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>
          สร้าง Club
        </span>
        <span />
      </div>
      <div className="h-px" style={{ background: "#E8E6E0" }} />

      <div className="flex-1 overflow-y-auto pb-6 px-6">
        <div className="rounded-2xl mt-5 overflow-hidden" style={{ border: "1px solid #E8E6E0" }}>
          <button
            className="w-full flex flex-col items-center justify-center gap-2"
            style={{ height: 110, background: "#F1EFE9" }}
          >
            <div className="w-9 h-9 rounded-full flex items-center justify-center" style={{ background: "#E8F0FA" }}>
              <ImageIcon size={16} strokeWidth={1.6} color="#1B3A6B" />
            </div>
            <span className="text-[12.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
              แตะเพื่อเลือกรูปปก
            </span>
          </button>

          <div className="px-5">
            <Field dense label="ชื่อ Club" value={name} onChange={setName} placeholder="ตั้งชื่อ Club ของคุณ" maxLength={50} />
            <div className="h-px mt-4" style={{ background: "#E8E6E0" }} />
            <Field dense label="คำอธิบาย" value={desc} onChange={setDesc} placeholder="" maxLength={500} multiline />
          </div>

          <div className="h-px mt-1" style={{ background: "#E8E6E0" }} />

          <div className="px-5 py-4" style={{ background: "#FBFAF8" }}>
            <span className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>
              ความเป็นส่วนตัว
            </span>
            <div className="flex rounded-full p-1 mt-2.5" style={{ background: "#F1EFE9", border: "1px solid #E8E6E0" }}>
              {["สาธารณะ", "ส่วนตัว"].map((p) => (
                <button
                  key={p}
                  onClick={() => setPrivacy(p)}
                  className="flex-1 py-2.5 rounded-full text-[13.5px] transition-all"
                  style={{
                    background: privacy === p ? "#FAF9F6" : "transparent",
                    boxShadow: privacy === p ? "0 1px 6px rgba(18,18,15,0.10)" : "none",
                    color: privacy === p ? "#12120F" : "#8A8880",
                    fontFamily: FONT_SANS,
                    fontWeight: privacy === p ? 600 : 400,
                  }}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="pt-6">
          <button
            disabled={!canCreate}
            className="w-full py-3.5 rounded-full text-[14px]"
            style={{ background: canCreate ? "#1B3A6B" : "#E8E6E0", color: canCreate ? "#FAF9F6" : "#B7B4AC", fontFamily: FONT_SANS, fontWeight: 700 }}
          >
            สร้าง Club
          </button>
        </div>
      </div>
    </div>
  );
}

/* ============================= CLUB DETAIL ============================= */

const clubPosts = [
  { id: 1, name: "ZEN", avatarBg: "#8A6D3A", time: "4 วันที่แล้ว", text: "Hey 👋", likes: 0, comments: 0 },
  {
    id: 2,
    name: "WARREN",
    avatarBg: "#1B3A6B",
    time: "3 วันที่แล้ว",
    text: "ยินดีต้อนรับทุกคนเข้าสู่ Club นี้ครับ มีอะไรอยากให้ปรับ คอมเมนต์ไว้ได้เลย",
    likes: 6,
    comments: 2,
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

function ClubBanner() {
  return (
    <div className="relative w-full overflow-hidden" style={{ height: 140, background: "#12120F" }}>
      <div
        className="absolute"
        style={{
          width: 260, height: 260, right: -80, top: -100, borderRadius: "50%",
          background: "radial-gradient(circle, #1B3A6B 0%, rgba(27,58,107,0) 70%)", opacity: 0.9,
        }}
      />
      <div className="relative h-full flex flex-col justify-center px-6">
        <span className="text-[11px] uppercase" style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}>
          Club
        </span>
        <span className="mt-1" style={{ fontFamily: FONT_SERIF, fontSize: 22, fontWeight: 500, color: "#FAF9F6" }}>
          WYNOS Feedback
        </span>
      </div>
    </div>
  );
}

function ClubHeader() {
  const [joined, setJoined] = useState(true);

  return (
    <div className="px-6 pt-4">
      <div className="flex items-start justify-between">
        <span style={{ fontFamily: FONT_SANS, fontWeight: 700, fontSize: 17, color: "#12120F" }}>
          WYNOS Feedback
        </span>
        <div className="flex items-center gap-1.5">
          <button className="w-9 h-9 flex items-center justify-center rounded-full" style={{ border: "1px solid #E8E6E0" }}>
            <Share2 size={14} strokeWidth={1.5} color="#12120F" />
          </button>
          <button className="w-9 h-9 flex items-center justify-center rounded-full" style={{ border: "1px solid #E8E6E0" }}>
            <MoreHorizontal size={16} strokeWidth={1.6} color="#12120F" />
          </button>
        </div>
      </div>

      <div className="flex items-center gap-2 mt-1.5 flex-wrap">
        <span className="text-[12.5px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>2 สมาชิก</span>
        {joined && (
          <button
            onClick={() => setJoined(false)}
            className="flex items-center gap-1 px-2.5 py-1 rounded-full"
            style={{ background: "#F1EFE9" }}
          >
            <Check size={11} strokeWidth={2.4} color="#8A8880" />
            <span className="text-[11px]" style={{ color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 600 }}>
              เข้าร่วมแล้ว
            </span>
          </button>
        )}
      </div>

      <p className="text-[13.5px] leading-relaxed mt-3.5" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
        พื้นที่สำหรับผู้ใช้ WYNOS ร่วมกันเสนอไอเดีย แจ้งปัญหา และช่วยพัฒนา WYNOS
      </p>

      {!joined && (
        <button
          onClick={() => setJoined(true)}
          className="w-full mt-4 py-2.5 rounded-full text-[13.5px]"
          style={{ background: "#1B3A6B", color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}
        >
          เข้าร่วม
        </button>
      )}
    </div>
  );
}

function ClubTabs({ active, setActive }) {
  const tabs = [
    { key: "โพสต์", icon: FileText },
    { key: "สมาชิก", icon: Users },
    { key: "เกี่ยวกับ", icon: Info },
  ];
  return (
    <div className="flex px-2 mt-5" style={{ borderBottom: "1px solid #E8E6E0" }}>
      {tabs.map(({ key, icon: Icon }) => (
        <button key={key} onClick={() => setActive(key)} className="relative flex-1 flex flex-col items-center gap-1 py-3">
          <Icon size={16} strokeWidth={1.6} color={active === key ? "#1B3A6B" : "#B7B4AC"} />
          <span className="text-[11.5px]" style={{ fontFamily: FONT_SANS, fontWeight: active === key ? 600 : 400, color: active === key ? "#12120F" : "#B7B4AC" }}>
            {key}
          </span>
          {active === key && (
            <div className="absolute left-1/2 -translate-x-1/2 -bottom-[1px] rounded-full" style={{ width: 22, height: 2, background: "#1B3A6B" }} />
          )}
        </button>
      ))}
    </div>
  );
}

function ClubPostRow({ post, isLast }) {
  return (
    <div className={`px-6 pt-4 pb-4 ${!isLast ? "border-b" : ""}`} style={{ borderColor: "#E8E6E0" }}>
      <div className="flex gap-3">
        <Avatar bg={post.avatarBg} letter={post.name[0]} size={38} />
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-2">
            <span className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>{post.name}</span>
            <span className="text-[12px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>{post.time}</span>
          </div>
          <p className="text-[14px] mt-1.5 leading-relaxed" style={{ color: "#2B2A26", fontFamily: FONT_SANS }}>
            {post.text}
          </p>
          <div className="flex items-center gap-5 mt-3">
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
              <Heart size={16} strokeWidth={1.4} />
              <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.likes}</span>
            </div>
            <div className="flex items-center gap-1.5" style={{ color: "#8A8880" }}>
              <MessageCircle size={16} strokeWidth={1.4} />
              <span className="text-[12px] tabular-nums" style={{ fontFamily: FONT_SANS }}>{post.comments}</span>
            </div>
            <div className="ml-auto">
              <Bookmark size={15} strokeWidth={1.4} color="#C7C4BC" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function ClubDetailScreen() {
  const [tab, setTab] = useState("โพสต์");

  return (
    <div className="h-full flex flex-col relative">
      <div className="flex items-center px-4 pt-2 pb-1 absolute top-0 left-0 right-0 z-10">
        <button className="p-2 rounded-full" style={{ background: "#FAF9F6CC" }}>
          <ChevronLeft size={20} strokeWidth={1.8} color="#12120F" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto">
        <ClubBanner />
        <ClubHeader />
        <ClubTabs active={tab} setActive={setTab} />

        <div>
          {clubPosts.map((p, i) => (
            <ClubPostRow key={p.id} post={p} isLast={i === clubPosts.length - 1} />
          ))}
          <div className="px-6 py-8 text-center text-[13px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
            ไม่มีโพสต์เพิ่มเติมแล้ว
          </div>
        </div>
      </div>

      <button
        className="absolute bottom-6 right-6 w-14 h-14 rounded-full flex items-center justify-center"
        style={{ background: "#1B3A6B", boxShadow: "0 8px 24px rgba(27,58,107,0.35)" }}
      >
        <Plus size={22} strokeWidth={1.8} color="#FAF9F6" />
      </button>
    </div>
  );
}

/* ============================= SHELL ============================= */

export default function WynosClub() {
  const [screen, setScreen] = useState("detail");

  return (
    <div className="w-full min-h-screen flex flex-col items-center justify-center py-10 gap-5" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
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
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F", position: "relative", zIndex: 20 }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:45</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        <div style={{ height: 844 - 40 }}>
          {screen === "create" ? <CreateClubScreen /> : <ClubDetailScreen />}
        </div>
      </div>

      <div className="flex gap-2">
        {[
          { key: "create", label: "สร้าง Club" },
          { key: "detail", label: "หน้า Club" },
        ].map((s) => (
          <button
            key={s.key}
            onClick={() => setScreen(s.key)}
            className="px-4 py-2 rounded-full text-[13px]"
            style={{
              fontFamily: FONT_SANS,
              fontWeight: 600,
              background: screen === s.key ? "#12120F" : "#FAF9F6",
              color: screen === s.key ? "#FAF9F6" : "#12120F",
              border: "1px solid #D9D6CE",
            }}
          >
            {s.label}
          </button>
        ))}
      </div>
    </div>
  );
}
