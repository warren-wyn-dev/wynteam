"use client";

import { ArrowLeft } from "lucide-react";
import { useMemo, useState } from "react";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getEmailConfirmationRedirectUrl } from "@/lib/auth-repository";
import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";

export function ParityEmailAuth({ onBack }: { onBack: () => void }) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [signUp, setSignUp] = useState(true);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const validEmail = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim());
  const canSubmit = Boolean(supabase && validEmail && (signUp ? password.length >= MIN_SIGNUP_PASSWORD_LENGTH : password.length > 0) && !loading);

  async function submit() {
    if (!supabase || !canSubmit) return;
    setLoading(true);
    setMessage("");
    try {
      if (signUp) {
        const result = await supabase.auth.signUp({ email: email.trim(), password, options: { emailRedirectTo: getEmailConfirmationRedirectUrl() } });
        if (result.error) {
          const exists = result.error.code === "user_already_exists" || result.error.message.toLowerCase().includes("already registered");
          if (exists) {
            setSignUp(false);
            setMessage("อีเมลนี้มีบัญชีอยู่แล้ว ลองเข้าสู่ระบบแทน");
          } else {
            setMessage("สมัครสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง");
          }
        } else if (!result.data.session) {
          setSignUp(false);
          setMessage(`ส่งอีเมลยืนยันไปที่ ${email.trim()} แล้ว กรุณากดลิงก์ในอีเมลก่อนเข้าสู่ระบบ`);
        }
      } else {
        const result = await supabase.auth.signInWithPassword({ email: email.trim(), password });
        if (result.error) {
          setMessage(result.error.code === "email_not_confirmed" ? "บัญชีนี้ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ" : "อีเมลหรือรหัสผ่านไม่ถูกต้อง");
        }
      }
    } catch {
      setMessage(signUp ? "สมัครสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง" : "อีเมลหรือรหัสผ่านไม่ถูกต้อง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="parity-auth parity-form-screen">
      <header className="parity-auth-appbar parity-auth-appbar-titled">
        <button className="parity-back" type="button" onClick={onBack} aria-label="ย้อนกลับ"><ArrowLeft aria-hidden="true" strokeWidth={1.8} /></button>
        <span>{signUp ? "สมัครสมาชิก" : "เข้าสู่ระบบ"}</span>
      </header>
      <section className="parity-auth-content parity-email-content">
        <label className="parity-field"><span>อีเมล</span><input type="email" inputMode="email" autoCapitalize="none" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} /></label>
        <label className="parity-field"><span>รหัสผ่าน</span><input type="password" autoComplete={signUp ? "new-password" : "current-password"} value={password} onChange={(event) => setPassword(event.target.value)} />{signUp ? <small>อย่างน้อย {MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร</small> : null}</label>
        <button className="parity-primary" type="button" disabled={!canSubmit} onClick={() => void submit()}>{loading ? "กำลังดำเนินการ…" : signUp ? "สมัครสมาชิก" : "เข้าสู่ระบบ"}</button>
        <button className="parity-text-button" type="button" disabled={loading} onClick={() => { setSignUp((value) => !value); setMessage(""); }}>{signUp ? "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ" : "ยังไม่มีบัญชี? สมัครสมาชิก"}</button>
        {message ? <p className="parity-auth-error" role="alert">{message}</p> : null}
      </section>
    </main>
  );
}
