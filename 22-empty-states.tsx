import React, { useState } from "react";
import { Bell, MessageCircle } from "lucide-react";

/*
  WYNOS — Empty states for Notifications and Chat inbox.
  Both were designed only in their populated state so far. A brand-new
  account hits these empty states before ever seeing a real notification
  or message, so they need real treatment, not a blank screen.
  Same icon-in-tint-circle + Fraunces headline + supportive line pattern
  as the empty state already established on Home (new-user follow
  suggestions) and Bookmarks.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function EmptyBlock({ icon: Icon, title, subtitle }) {
  return (
    <div className="flex-1 flex flex-col items-center justify-center px-10 -mt-10">
      <div className="w-16 h-16 rounded-full flex items-center justify-center" style={{ background: "#F1EFE9" }}>
        <Icon size={26} strokeWidth={1.4} color="#1B3A6B" />
      </div>
      <p className="mt-4 text-center" style={{ fontFamily: FONT_SERIF, fontSize: 18, fontWeight: 500, color: "#12120F" }}>{title}</p>
      <p className="text-[13px] mt-1.5 text-center leading-relaxed" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>{subtitle}</p>
    </div>
  );
}

function Phone({ title, children }) {
  return (
    <div className="relative w-full overflow-hidden flex flex-col" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
      <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
        <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:24</span>
        <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
          <span>5G</span>
          <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
        </div>
      </div>
      <div className="px-6 pt-2 pb-3">
        <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 18, color: "#12120F" }}>{title}</span>
      </div>
      <div className="h-px" style={{ background: "#E8E6E0" }} />
      {children}
    </div>
  );
}

export default function WynosEmptyStates() {
  const [screen, setScreen] = useState("notifications");
  return (
    <div className="w-full min-h-screen flex flex-col items-center justify-center py-10 gap-5" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>

      {screen === "notifications" ? (
        <Phone title="การแจ้งเตือน">
          <EmptyBlock icon={Bell} title="ยังไม่มีการแจ้งเตือน" subtitle="เมื่อมีคนถูกใจ คอมเมนต์ หรือติดตามคุณ จะขึ้นตรงนี้" />
        </Phone>
      ) : (
        <Phone title="ข้อความ">
          <EmptyBlock icon={MessageCircle} title="ยังไม่มีข้อความ" subtitle="เริ่มแชทกับคนที่คุณติดตาม กดไอคอนดินสอด้านบนได้เลย" />
        </Phone>
      )}

      <div className="flex gap-2">
        <button onClick={() => setScreen("notifications")} className="px-4 py-2 rounded-full text-[13px]" style={{ fontFamily: FONT_SANS, fontWeight: 600, background: screen === "notifications" ? "#12120F" : "#FAF9F6", color: screen === "notifications" ? "#FAF9F6" : "#12120F", border: "1px solid #D9D6CE" }}>การแจ้งเตือน</button>
        <button onClick={() => setScreen("chat")} className="px-4 py-2 rounded-full text-[13px]" style={{ fontFamily: FONT_SANS, fontWeight: 600, background: screen === "chat" ? "#12120F" : "#FAF9F6", color: screen === "chat" ? "#FAF9F6" : "#12120F", border: "1px solid #D9D6CE" }}>ข้อความ</button>
      </div>
    </div>
  );
}
