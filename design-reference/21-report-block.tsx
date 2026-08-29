import React, { useState } from "react";
import { X, Flag, UserX, ChevronRight, AlertTriangle } from "lucide-react";

/*
  WYNOS — Report / Block.
  Reached from the "..." menu on a post, a comment, or someone's profile.
  Presented as a bottom sheet (slides up over a dimmed background), not a
  full pushed screen — this is a quick, occasional utility action, not a
  destination anyone navigates to on purpose.

  Two steps: pick "report" or "block" from the sheet, then (for report
  only) pick a reason. Block has an inline confirm step since it's
  reversible but still consequential; report reasons lead straight to a
  confirmation toast in a real app.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

const reasons = ["สแปมหรือหลอกลวง", "เนื้อหาไม่เหมาะสม", "การคุกคามหรือกลั่นแกล้ง", "ข้อมูลเท็จ", "อื่น ๆ"];

function Sheet({ children, onClose }) {
  return (
    <div className="absolute inset-0 flex items-end z-30">
      <div className="absolute inset-0" style={{ background: "#12120F55" }} onClick={onClose} />
      <div className="relative w-full rounded-t-3xl pb-8 pt-3" style={{ background: "#FAF9F6" }}>
        <div className="flex justify-center mb-2">
          <div className="rounded-full" style={{ width: 36, height: 4, background: "#E8E6E0" }} />
        </div>
        {children}
      </div>
    </div>
  );
}

function MainSheet({ onClose, onReport, onBlock }) {
  return (
    <Sheet onClose={onClose}>
      <button onClick={onReport} className="w-full flex items-center gap-3.5 px-6 py-4">
        <Flag size={18} strokeWidth={1.6} color="#12120F" />
        <span className="flex-1 text-left text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>รายงานโพสต์นี้</span>
        <ChevronRight size={16} strokeWidth={1.8} color="#C7C4BC" />
      </button>
      <div className="h-px mx-6" style={{ background: "#E8E6E0" }} />
      <button onClick={onBlock} className="w-full flex items-center gap-3.5 px-6 py-4">
        <UserX size={18} strokeWidth={1.6} color="#12120F" />
        <span className="flex-1 text-left text-[14.5px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>บล็อกผู้ใช้นี้</span>
        <ChevronRight size={16} strokeWidth={1.8} color="#C7C4BC" />
      </button>
    </Sheet>
  );
}

function ReportSheet({ onClose, onBack }) {
  const [selected, setSelected] = useState(null);
  return (
    <Sheet onClose={onClose}>
      <div className="px-6 pb-2">
        <span style={{ fontFamily: FONT_SERIF, fontSize: 16, fontWeight: 500, color: "#12120F" }}>ทำไมคุณถึงรายงานโพสต์นี้</span>
      </div>
      {reasons.map((r, i) => (
        <button key={r} onClick={() => setSelected(r)} className="w-full flex items-center justify-between px-6 py-3.5" style={{ borderTop: i === 0 ? "1px solid #E8E6E0" : "none", borderBottom: i !== reasons.length - 1 ? "1px solid #E8E6E0" : "none" }}>
          <span className="text-[14px]" style={{ color: "#12120F", fontFamily: FONT_SANS }}>{r}</span>
          <div className="rounded-full" style={{ width: 16, height: 16, border: `1.5px solid ${selected === r ? "#1B3A6B" : "#C7C4BC"}`, background: selected === r ? "#1B3A6B" : "transparent" }} />
        </button>
      ))}
      <div className="px-6 pt-4">
        <button disabled={!selected} className="w-full py-3 rounded-full text-[13.5px]" style={{ background: selected ? "#1B3A6B" : "#E8E6E0", color: selected ? "#FAF9F6" : "#B7B4AC", fontFamily: FONT_SANS, fontWeight: 700 }}>
          ส่งรายงาน
        </button>
      </div>
    </Sheet>
  );
}

function BlockConfirmSheet({ onClose, onBack }) {
  return (
    <Sheet onClose={onClose}>
      <div className="px-6 pb-4 flex flex-col items-center text-center">
        <AlertTriangle size={28} strokeWidth={1.5} color="#1B3A6B" />
        <p className="mt-3" style={{ fontFamily: FONT_SERIF, fontSize: 17, fontWeight: 500, color: "#12120F" }}>บล็อก @warren?</p>
        <p className="text-[13px] mt-1.5 leading-relaxed" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
          @warren จะไม่สามารถติดตามหรือส่งข้อความหาคุณได้ และคุณจะไม่เห็นโพสต์ของเขาอีก
        </p>
      </div>
      <div className="px-6 space-y-2.5">
        <button className="w-full py-3 rounded-full text-[13.5px]" style={{ background: "#1B3A6B", color: "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}>บล็อก</button>
        <button onClick={onBack} className="w-full py-3 rounded-full text-[13.5px]" style={{ border: "1px solid #E8E6E0", color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>ยกเลิก</button>
      </div>
    </Sheet>
  );
}

export default function WynosReportBlock() {
  const [step, setStep] = useState("main");
  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:22</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
          </div>
        </div>
        {/* underlying post, just for context */}
        <div className="px-6 pt-6">
          <p className="text-[13px]" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>เนื้อหาของโพสต์อยู่ด้านหลังชีทนี้...</p>
        </div>

        {step === "main" && <MainSheet onClose={() => {}} onReport={() => setStep("report")} onBlock={() => setStep("block")} />}
        {step === "report" && <ReportSheet onClose={() => setStep("main")} onBack={() => setStep("main")} />}
        {step === "block" && <BlockConfirmSheet onClose={() => setStep("main")} onBack={() => setStep("main")} />}
      </div>
    </div>
  );
}
