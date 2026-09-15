"use client";

import { useRouter } from "next/navigation";
import type { ChangeEvent, ReactNode } from "react";

import { Avatar, Button, Input, WynosIcon } from "@/components/ui";
import { useSignupDraft, type SignupDraft } from "@/components/auth-flow/signup-draft-context";

function AuthPhone({ children }: { children: ReactNode }) {
  return (
    <main className="auth-ref-viewport">
      <div className="phone" id="phone">
        {children}
      </div>
    </main>
  );
}

function BackTopbar({ href, step }: { href: string; step?: string }) {
  const router = useRouter();
  return (
    <div className="topbar">
      <button className="ic-btn" onClick={() => router.push(href)} aria-label="ย้อนกลับ">
        <WynosIcon name="back" size={16} />
      </button>
      {step ? <span style={{ fontSize: 12, color: "var(--text-muted)" }}>{step}</span> : <span />}
    </div>
  );
}

function Field({
  label,
  name,
  placeholder,
  type,
  value,
  onChange,
}: {
  label: string;
  name: string;
  placeholder: string;
  type?: string;
  value?: string;
  onChange?: (event: ChangeEvent<HTMLInputElement>) => void;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      <Input bare name={name} placeholder={placeholder} type={type} value={value} onChange={onChange} />
    </div>
  );
}

export function WelcomeScreen() {
  const router = useRouter();
  return (
    <AuthPhone>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "40px 24px 32px" }}>
        <div />
        <div style={{ textAlign: "center" }}>
          <svg height="48" style={{ margin: "0 auto 18px" }} viewBox="0 0 26 26" width="48" aria-label="Wynos">
            <path d="M2 4 L8 22 L13 9 L18 22 L24 4" fill="none" stroke="#0A0A0A" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
          </svg>
          <p style={{ fontSize: 17, fontWeight: 600, margin: "0 0 6px" }}>ทุกเรื่องราว มีจุดเริ่มต้น</p>
          <p style={{ fontSize: 14, color: "var(--text-secondary)", margin: 0 }}>Welcome to WYNOS.</p>
        </div>
        <div>
          <Button className="btn-primary" onClick={() => router.push("/signup/step-1")} style={{ marginBottom: 10 }}>สร้างบัญชีใหม่</Button>
          <Button className="btn-outline" variant="outline" onClick={() => router.push("/login")} style={{ marginBottom: 16 }}>เข้าสู่ระบบ</Button>
          <p style={{ fontSize: 11, color: "var(--text-muted)", textAlign: "center", lineHeight: 1.5, margin: 0 }}>
            การสร้างบัญชีถือว่ายอมรับ<br />
            <b style={{ color: "var(--text-primary)" }}>ข้อกำหนดการใช้งาน</b> และ <b style={{ color: "var(--text-primary)" }}>นโยบายความเป็นส่วนตัว</b>
          </p>
        </div>
      </div>
    </AuthPhone>
  );
}

export function SignupStep1Screen() {
  const router = useRouter();
  const { draft, setDraft } = useSignupDraft();
  const update = (key: keyof SignupDraft) => (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setDraft((current) => ({ ...current, [key]: value }));
  };

  return (
    <AuthPhone>
      <BackTopbar href="/welcome" step="1/2" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>สร้างบัญชี</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px" }}>มาทำความรู้จักคุณกันก่อน</p>
        <div className="field">
          <label>ชื่อผู้ใช้</label>
          <div style={{ display: "flex", alignItems: "center", height: 44, border: "1px solid var(--border-strong)", borderRadius: 10, padding: "0 14px" }}>
            <span style={{ color: "var(--text-muted)" }}>@</span>
            <Input bare name="username" placeholder="ploy_journey" value={draft.username} onChange={update("username")} style={{ border: "none", outline: "none", flex: 1, fontSize: 14 }} />
          </div>
        </div>
        <Field label="ชื่อที่แสดง" name="displayName" placeholder="เช่น พลอย เดินทาง" value={draft.displayName} onChange={update("displayName")} />
        <Field label="วันเกิด" name="birthDate" placeholder="วว / ดด / ปปปป" value={draft.birthDate} onChange={update("birthDate")} />
        <Button className="btn-primary" onClick={() => router.push("/signup/step-2")} style={{ marginTop: 10 }}>หน้าถัดไป</Button>
      </div>
    </AuthPhone>
  );
}

export function SignupStep2Screen() {
  const router = useRouter();
  const { draft, setDraft } = useSignupDraft();
  const update = (key: keyof SignupDraft) => (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setDraft((current) => ({ ...current, [key]: value }));
  };

  return (
    <AuthPhone>
      <BackTopbar href="/signup/step-1" step="2/2" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>ตั้งรหัสผ่าน</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px" }}>ใช้สำหรับเข้าสู่ระบบครั้งต่อไป</p>
        <Field label="อีเมล" name="email" placeholder="you@example.com" value={draft.email} onChange={update("email")} />
        <Field label="รหัสผ่าน" name="password" placeholder="อย่างน้อย 8 ตัวอักษร" type="password" value={draft.password} onChange={update("password")} />
        <Field label="ยืนยันรหัสผ่าน" name="confirmPassword" placeholder="พิมพ์รหัสผ่านอีกครั้ง" type="password" value={draft.confirmPassword} onChange={update("confirmPassword")} />
        <Button className="btn-primary" onClick={() => router.push("/onboarding/profile")} style={{ marginTop: 10 }}>สร้างบัญชี</Button>
        <p style={{ fontSize: 12, color: "var(--text-secondary)", textAlign: "center", marginTop: 16 }}>
          มีบัญชีอยู่แล้ว? <b onClick={() => router.push("/login")} style={{ color: "var(--text-primary)", cursor: "pointer" }}>เข้าสู่ระบบ</b>
        </p>
      </div>
    </AuthPhone>
  );
}

export function OnboardingProfileScreen() {
  const router = useRouter();
  return (
    <AuthPhone>
      <div style={{ display: "flex", justifyContent: "flex-end", padding: "16px 20px 0" }}>
        <span onClick={() => router.push("/")} style={{ fontSize: 13, color: "var(--text-secondary)", cursor: "pointer" }}>ข้าม</span>
      </div>
      <div style={{ padding: "0 20px", flex: 1 }}>
        <div style={{ textAlign: "center", marginBottom: 24 }}>
          <div style={{ fontSize: 20, fontWeight: 700 }}>เพิ่มรูปโปรไฟล์</div>
          <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "6px 0 0" }}>ให้คนอื่นรู้จักคุณมากขึ้น</p>
        </div>
        <div style={{ display: "flex", justifyContent: "center", marginBottom: 24 }}>
          <div style={{ position: "relative" }}>
            <Avatar as="div" alt="รูปโปรไฟล์" className="avatar" size={96} />
            <div style={{ position: "absolute", bottom: -4, right: -4, width: 32, height: 32, borderRadius: "50%", background: "var(--text-primary)", border: "3px solid #fff", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <WynosIcon name="camera" size={15} color="#fff" />
            </div>
          </div>
        </div>
        <div className="field">
          <label>แนะนำตัวสั้นๆ (ไม่บังคับ)</label>
          <textarea placeholder="ชอบเที่ยว ชอบถ่ายรูป..." />
        </div>
      </div>
      <div style={{ padding: "16px 20px" }}>
        <Button className="btn-primary" onClick={() => router.push("/")}>เริ่มใช้งาน Wynos</Button>
      </div>
    </AuthPhone>
  );
}

export function LoginScreen() {
  const router = useRouter();
  return (
    <AuthPhone>
      <BackTopbar href="/welcome" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ textAlign: "center", marginBottom: 28 }}>
          <svg height="36" style={{ margin: "0 auto 14px" }} viewBox="0 0 26 26" width="36" aria-label="Wynos">
            <path d="M2 4 L8 22 L13 9 L18 22 L24 4" fill="none" stroke="#0A0A0A" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
          </svg>
          <div style={{ fontSize: 20, fontWeight: 700 }}>เข้าสู่ระบบ</div>
        </div>
        <Field label="อีเมล เบอร์โทร หรือชื่อผู้ใช้" name="loginIdentifier" placeholder="you@example.com" />
        <Field label="รหัสผ่าน" name="loginPassword" placeholder="รหัสผ่านของคุณ" type="password" />
        <div style={{ textAlign: "right", marginBottom: 8 }}>
          <span onClick={() => router.push("/forgot-password")} style={{ fontSize: 13, fontWeight: 500, cursor: "pointer" }}>ลืมรหัสผ่าน?</span>
        </div>
        <Button className="btn-primary" onClick={() => router.push("/")}>เข้าสู่ระบบ</Button>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", textAlign: "center", marginTop: 16 }}>
          ยังไม่มีบัญชี? <b onClick={() => router.push("/signup/step-1")} style={{ color: "var(--text-primary)", cursor: "pointer" }}>สร้างบัญชีใหม่</b>
        </p>
      </div>
    </AuthPhone>
  );
}

export function ForgotPasswordScreen() {
  const router = useRouter();
  return (
    <AuthPhone>
      <BackTopbar href="/login" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>ลืมรหัสผ่าน?</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px", lineHeight: 1.5 }}>กรอกอีเมลที่ใช้สมัคร เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ให้</p>
        <Field label="อีเมล" name="resetEmail" placeholder="you@example.com" />
        <Button className="btn-primary" onClick={() => router.push("/login")} style={{ marginTop: 10 }}>ส่งลิงก์รีเซ็ตรหัสผ่าน</Button>
      </div>
    </AuthPhone>
  );
}
