import React from "react";
import {
  X,
  User,
  Users,
  Bookmark,
  BadgeCheck,
  ChevronRight,
} from "lucide-react";

/*
  WYNOS — Side menu (revealed by the ☰ icon on Home).

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — name in the identity block · Inter — everything else

  Design notes:
  - Slides in from the left as a drawer over a dimmed Home feed, rather than
    replacing the whole screen — the menu is a supplement to Home, not a
    separate destination, so keeping Home dimly visible behind it keeps
    that relationship legible.
  - Identity block at the top (avatar, name, handle, follow counts) is
    tappable through to Profile — the same information already exists on
    the Profile screen, so it's shown here only as an entry point, not a
    duplicate profile.
  - "ออกจากระบบ" (log out) no longer lives here — it moved to the bottom
    of the Settings screen (reached via the gear icon on Profile), since
    it's a settings-category action, not something to browse alongside
    everyday navigation items.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const menuItems = [
  { icon: User, label: "โปรไฟล์" },
  { icon: Users, label: "Club ของฉัน" },
  { icon: Bookmark, label: "บันทึกไว้" },
];

function Avatar({ bg, letter, size = 52 }) {
  const outer = size + 6;
  return (
    <div className="relative shrink-0 flex items-center justify-center" style={{ width: outer, height: outer }}>
      <div className="absolute inset-0 rounded-full" style={{ border: "1.5px solid #1B3A6B33" }} />
      <div
        className="flex items-center justify-center rounded-full text-white"
        style={{ width: size, height: size, background: bg, fontFamily: FONT_SERIF, fontSize: size * 0.4, fontWeight: 500 }}
      >
        {letter}
      </div>
    </div>
  );
}

function MenuRow({ icon: Icon, label }) {
  return (
    <button className="w-full flex items-center gap-3.5 px-6 py-3.5">
      <Icon size={19} strokeWidth={1.5} color="#12120F" />
      <span className="text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>
        {label}
      </span>
    </button>
  );
}

export default function WynosSideMenu() {
  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
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
        {/* dimmed Home feed peeking on the right, to show this is a drawer over Home */}
        <div className="absolute inset-0" style={{ background: "#12120F0F" }}>
          <div className="absolute right-0 top-0 bottom-0" style={{ width: "22%", background: "#EDEBE5" }} />
        </div>

        {/* drawer */}
        <div
          className="absolute left-0 top-0 bottom-0 flex flex-col"
          style={{ width: "78%", background: "#FAF9F6", boxShadow: "8px 0 30px rgba(18,18,15,0.12)" }}
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

          <div className="flex items-center justify-between px-6 pt-2">
            <span />
            <button className="p-2 -mr-2"><X size={20} strokeWidth={1.6} color="#8A8880" /></button>
          </div>

          {/* identity block — tappable through to Profile */}
          <button className="flex items-start gap-3.5 px-6 pt-4 text-left">
            <Avatar bg="#1B3A6B" letter="W" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5">
                <span className="text-[16px]" style={{ fontFamily: FONT_SANS, fontWeight: 700, color: "#12120F" }}>
                  WARREN
                </span>
                <BadgeCheck size={14} fill="#1B3A6B" color="#FAF9F6" strokeWidth={0} />
              </div>
              <span className="text-[12.5px]" style={{ color: "#B7B4AC", fontFamily: FONT_SANS }}>
                @warren
              </span>
              <div className="flex items-center gap-3 mt-1.5">
                <span className="text-[12px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
                  <span style={{ color: "#12120F", fontWeight: 700 }}>4</span> ผู้ติดตาม
                </span>
                <span className="text-[12px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
                  <span style={{ color: "#12120F", fontWeight: 700 }}>1</span> กำลังติดตาม
                </span>
              </div>
            </div>
            <ChevronRight size={16} strokeWidth={1.8} color="#C7C4BC" className="mt-1" />
          </button>

          <div className="h-px mt-4" style={{ background: "#E8E6E0" }} />

          {/* nav items */}
          <div className="flex-1 overflow-y-auto pt-2">
            {menuItems.map((item) => (
              <MenuRow key={item.label} icon={item.icon} label={item.label} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
