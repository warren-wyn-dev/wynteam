import React from "react";
import {
  ChevronLeft,
  ChevronRight,
  User,
  Lock,
  Bell,
  Moon,
  HelpCircle,
  FileText,
  LogOut,
} from "lucide-react";

/*
  WYNOS — Settings (reached via the gear icon on Profile).

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — screen title · Inter — everything else

  This is the destination the logout button was moved to, first off the
  Profile header, then out of the side-menu feature hub — it belongs in a
  settings context, grouped with account-level actions, not sitting next
  to everyday navigation items.

  Grouped list pattern (same idea as Create Club's grouped fields):
  account-level items first, then app preferences, then support, then
  logout — separated, muted red-free (still just graphite text), with
  extra spacing above it so it doesn't blend into the list above it.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function GroupLabel({ children }) {
  return (
    <div className="px-6 pt-6 pb-2">
      <span
        className="text-[11px] uppercase"
        style={{ color: "#B7B4AC", fontFamily: FONT_SANS, letterSpacing: "0.14em", fontWeight: 600 }}
      >
        {children}
      </span>
    </div>
  );
}

function Row({ icon: Icon, label, isLast }) {
  return (
    <button
      className={`w-full flex items-center gap-3.5 px-6 py-3.5 ${!isLast ? "border-b" : ""}`}
      style={{ borderColor: "#E8E6E0" }}
    >
      <Icon size={18} strokeWidth={1.5} color="#12120F" />
      <span className="flex-1 text-left text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>
        {label}
      </span>
      <ChevronRight size={15} strokeWidth={1.8} color="#C7C4BC" />
    </button>
  );
}

const accountItems = [
  { icon: User, label: "บัญชี" },
  { icon: Lock, label: "ความเป็นส่วนตัว" },
];

const preferenceItems = [
  { icon: Bell, label: "การแจ้งเตือน" },
  { icon: Moon, label: "ธีมเข้ม" },
];

const supportItems = [
  { icon: HelpCircle, label: "ช่วยเหลือ" },
  { icon: FileText, label: "ข้อกำหนดและความเป็นส่วนตัว" },
];

export default function WynosSettings() {
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
        {/* status bar */}
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:50</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>
            ตั้งค่า
          </span>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />

        <div className="overflow-y-auto" style={{ height: 844 - 40 - 44 }}>
          <GroupLabel>บัญชี</GroupLabel>
          <div>
            {accountItems.map((item, i) => (
              <Row key={item.label} icon={item.icon} label={item.label} isLast={i === accountItems.length - 1} />
            ))}
          </div>

          <GroupLabel>การตั้งค่าแอป</GroupLabel>
          <div>
            {preferenceItems.map((item, i) => (
              <Row key={item.label} icon={item.icon} label={item.label} isLast={i === preferenceItems.length - 1} />
            ))}
          </div>

          <GroupLabel>ช่วยเหลือ</GroupLabel>
          <div>
            {supportItems.map((item, i) => (
              <Row key={item.label} icon={item.icon} label={item.label} isLast={i === supportItems.length - 1} />
            ))}
          </div>

          {/* logout — separated, quieter, extra breathing room above it */}
          <div className="pt-8 pb-8">
            <div className="h-px mb-2" style={{ background: "#E8E6E0" }} />
            <button className="w-full flex items-center gap-3.5 px-6 py-3.5">
              <LogOut size={18} strokeWidth={1.5} color="#8A8880" />
              <span className="text-[14px]" style={{ color: "#8A8880", fontFamily: FONT_SANS, fontWeight: 500 }}>
                ออกจากระบบ
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
