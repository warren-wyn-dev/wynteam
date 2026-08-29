import React, { useState } from "react";
import { ChevronLeft, Eye, EyeOff } from "lucide-react";

/*
  WYNOS — Onboarding: Welcome, Sign up, Log in.
  The first thing a brand-new person ever sees, so it carries the
  Fraunces wordmark treatment more than any other screen — this is a
  branding moment, unlike Drop or Chat which are pure writing surfaces.

  Three screens, switchable at the bottom of the file for review:
  Welcome (choose sign up or log in) → Sign up (email/password/name) →
  Log in (email/password). Real apps would add phone/social auth options;
  left out here to keep the reference focused on layout and token usage
  rather than every possible auth method.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function TextField({ label, value, onChange, type = "text", placeholder }) {
  const [show, setShow] = useState(false);
  const isPassword = type === "password";
  return (
    <div className="pt-4">
      <label className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>{label}</label>
      <div className="flex items-center mt-2" style={{ borderBottom: "1px solid #E8E6E0", paddingBottom: 10 }}>
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          type={isPassword && !show ? "password" : "text"}
          placeholder={placeholder}
          className="flex-1 bg-transparent outline-none text-[14.5px]"
          style={{ color: "#12120F", fontFamily: FONT_SANS }}
        />
        {isPassword && (
          <button onClick={() => setShow((v) => !v)}>
            {show ? <EyeOff size={16} strokeWidth={1.6} color="#8A8880" /> : <Eye size={16} strokeWidth={1.6} color="#8A8880" />}
          </button>
        )}
      </div>
    </div>
  );
}

function PrimaryButton({ children, disabled, onClick }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="w-full py-3.5 rounded-full text-[14px]"
      style={{ background: disabled ? "#E8E6E0" : "#1B3A6B", color: disabled ? "#B7B4AC" : "#FAF9F6", fontFamily: FONT_SANS, fontWeight: 700 }}
    >
      {children}
    </button>
  );
}

function StatusBar() {
  return (
    <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
      <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>19:20</span>
      <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
        <span>5G</span>
        <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}><div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} /></div>
      </div>
    </div>
  );
}

function WelcomeScreen({ onSignUp, onLogIn }) {
  return (
    <div className="h-full flex flex-col">
      <StatusBar />
      <div className="flex-1 flex flex-col justify-center px-8">
        <span style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 34, letterSpacing: "0.03em", color: "#12120F" }}>WYNOS</span>
        <p className="text-[14px] mt-2 leading-relaxed" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
          ดู → แชร์ → ค้นพบ → ซื้อ<br />พื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น
        </p>
      </div>
      <div className="px-8 pb-10 space-y-3">
        <PrimaryButton onClick={onSignUp}>สร้างบัญชีใหม่</PrimaryButton>
        <button onClick={onLogIn} className="w-full py-3.5 rounded-full text-[14px]" style={{ border: "1px solid #E8E6E0", color: "#12120F", fontFamily: FONT_SANS, fontWeight: 600 }}>
          เข้าสู่ระบบ
        </button>
      </div>
    </div>
  );
}

function SignUpScreen({ onBack }) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const canSubmit = name.trim() && email.trim() && password.length >= 6;
  return (
    <div className="h-full flex flex-col">
      <StatusBar />
      <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
        <button onClick={onBack} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
        <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>สร้างบัญชี</span>
        <span />
      </div>
      <div className="flex-1 overflow-y-auto px-6 pt-2">
        <TextField label="ชื่อ" value={name} onChange={setName} placeholder="ชื่อของคุณ" />
        <TextField label="อีเมล" value={email} onChange={setEmail} placeholder="you@email.com" />
        <TextField label="รหัสผ่าน" value={password} onChange={setPassword} type="password" placeholder="อย่างน้อย 6 ตัวอักษร" />
        <p className="text-[11.5px] mt-3" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
          การสร้างบัญชีถือว่าคุณยอมรับข้อกำหนดและความเป็นส่วนตัวของ WYNOS
        </p>
      </div>
      <div className="px-6 pb-8 pt-4">
        <PrimaryButton disabled={!canSubmit}>สร้างบัญชี</PrimaryButton>
      </div>
    </div>
  );
}

function LogInScreen({ onBack }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const canSubmit = email.trim() && password.trim();
  return (
    <div className="h-full flex flex-col">
      <StatusBar />
      <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
        <button onClick={onBack} className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
        <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>เข้าสู่ระบบ</span>
        <span />
      </div>
      <div className="flex-1 overflow-y-auto px-6 pt-2">
        <TextField label="อีเมล" value={email} onChange={setEmail} placeholder="you@email.com" />
        <TextField label="รหัสผ่าน" value={password} onChange={setPassword} type="password" placeholder="รหัสผ่านของคุณ" />
        <button className="mt-4"><span className="text-[13px]" style={{ color: "#1B3A6B", fontFamily: FONT_SANS, fontWeight: 600 }}>ลืมรหัสผ่าน?</span></button>
      </div>
      <div className="px-6 pb-8 pt-4">
        <PrimaryButton disabled={!canSubmit}>เข้าสู่ระบบ</PrimaryButton>
      </div>
    </div>
  );
}

export default function WynosOnboarding() {
  const [screen, setScreen] = useState("welcome");
  const screens = {
    welcome: <WelcomeScreen onSignUp={() => setScreen("signup")} onLogIn={() => setScreen("login")} />,
    signup: <SignUpScreen onBack={() => setScreen("welcome")} />,
    login: <LogInScreen onBack={() => setScreen("welcome")} />,
  };
  return (
    <div className="w-full min-h-screen flex flex-col items-center justify-center py-10 gap-5" style={{ background: "#EDEBE5" }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');`}</style>
      <div className="relative w-full overflow-hidden" style={{ maxWidth: 390, height: 844, background: "#FAF9F6", borderRadius: 44, boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)" }}>
        {screens[screen]}
      </div>
      <div className="flex gap-2">
        {[{ k: "welcome", l: "Welcome" }, { k: "signup", l: "สร้างบัญชี" }, { k: "login", l: "เข้าสู่ระบบ" }].map((s) => (
          <button key={s.k} onClick={() => setScreen(s.k)} className="px-4 py-2 rounded-full text-[13px]" style={{ fontFamily: FONT_SANS, fontWeight: 600, background: screen === s.k ? "#12120F" : "#FAF9F6", color: screen === s.k ? "#FAF9F6" : "#12120F", border: "1px solid #D9D6CE" }}>
            {s.l}
          </button>
        ))}
      </div>
    </div>
  );
}
