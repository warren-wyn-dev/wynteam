"use client";

import { Check, LockKeyhole, Mail, UtensilsCrossed } from "lucide-react";
import Link from "next/link";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import {
  EmailAlreadyRegisteredError,
  SignupPasswordTooShortError,
  signInWithEmail,
  signUpWithEmail,
} from "@/lib/auth-repository";
import { registerCurrentAccount } from "@/lib/account-registry";
import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

function FoodAuthBrand() {
  return (
    <div className="wf-auth-brand" aria-label="WYNOS Food">
      <span className="wf-auth-mark"><UtensilsCrossed size={25} strokeWidth={1.8} /></span>
      <span><strong>WYNOS</strong><b>Food</b></span>
    </div>
  );
}

function FoodAuthShell({ children }: { children: ReactNode }) {
  return <main className="wf-auth-shell"><section className="wf-auth-card">{children}</section></main>;
}

function FoodAuthLoading() {
  return (
    <FoodAuthShell>
      <div className="wf-auth-loading"><span className="wf-loader" /><strong>กำลังตรวจสอบบัญชี…</strong></div>
    </FoodAuthShell>
  );
}

export function FoodLoginScreen() {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [checking, setChecking] = useState(() => Boolean(client));
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    if (!client) return;
    void client.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;
      if (!error && data.session) {
        window.location.replace("/food");
        return;
      }
      setChecking(false);
    }).catch(() => {
      if (mounted) setChecking(false);
    });
    return () => { mounted = false; };
  }, [client]);

  async function submit() {
    if (loading) return;
    setMessage("");
    const normalized = email.trim();
    if (!normalized || !password) {
      setMessage("กรุณากรอกอีเมลและรหัสผ่าน");
      return;
    }
    if (!client) {
      setMessage("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS Food");
      return;
    }

    setLoading(true);
    try {
      await signInWithEmail(client, normalized, password);
      await registerCurrentAccount(client).catch(() => false);
      window.location.replace("/food");
    } catch (error) {
      const code = (error as { code?: string })?.code;
      setMessage(code === "email_not_confirmed"
        ? "บัญชีนี้ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ"
        : "อีเมลหรือรหัสผ่านไม่ถูกต้อง");
    } finally {
      setLoading(false);
    }
  }

  if (!hasSupabaseBrowserConfig()) {
    return <FoodAuthShell><div className="wf-auth-state"><FoodAuthBrand /><h1>ยังไม่ได้ตั้งค่าการเชื่อมต่อ</h1><p>WYNOS Food ยังเชื่อมต่อระบบบัญชีไม่ได้</p></div></FoodAuthShell>;
  }
  if (checking) return <FoodAuthLoading />;

  return (
    <FoodAuthShell>
      <FoodAuthBrand />
      <div className="wf-auth-hero">
        <h1>เข้าสู่ระบบ WYNOS Food</h1>
        <p>สั่งอาหารและติดตามออเดอร์ด้วย WYNOS Account ของคุณ</p>
      </div>
      <div className="wf-auth-form">
        <label><span><Mail size={16} /> อีเมล</span><input type="email" autoComplete="email" autoCapitalize="none" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" /></label>
        <label><span><LockKeyhole size={16} /> รหัสผ่าน</span><input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="รหัสผ่านของคุณ" /></label>
        {message ? <p className="wf-auth-error" role="alert">{message}</p> : null}
        <button className="wf-auth-primary" type="button" disabled={loading} onClick={() => void submit()}>{loading ? "กำลังเข้าสู่ระบบ…" : "เข้าสู่ระบบ"}</button>
      </div>
      <p className="wf-auth-switch">ยังไม่มีบัญชี? <Link href="/food/signup">สมัคร WYNOS Food</Link></p>
      <div className="wf-auth-note">
        <Check size={17} />
        <p><strong>ใช้ Food อย่างเดียวได้</strong><span>ไม่จำเป็นต้องมี username, โพสต์ หรือโปรไฟล์ Social</span></p>
      </div>
    </FoodAuthShell>
  );
}

export function FoodSignupScreen() {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [checking, setChecking] = useState(() => Boolean(client));
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [awaitingConfirmation, setAwaitingConfirmation] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    if (!client) return;
    void client.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;
      if (!error && data.session) {
        window.location.replace("/food");
        return;
      }
      setChecking(false);
    }).catch(() => {
      if (mounted) setChecking(false);
    });
    return () => { mounted = false; };
  }, [client]);

  async function submit() {
    if (loading) return;
    setMessage("");
    const normalized = email.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)) {
      setMessage("กรุณากรอกอีเมลให้ถูกต้อง");
      return;
    }
    if (password.length < MIN_SIGNUP_PASSWORD_LENGTH) {
      setMessage(`รหัสผ่านต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`);
      return;
    }
    if (password !== confirmPassword) {
      setMessage("รหัสผ่านไม่ตรงกัน");
      return;
    }
    if (!client) {
      setMessage("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS Food");
      return;
    }

    setLoading(true);
    try {
      const result = await signUpWithEmail(client, normalized, password, "/food");
      setPassword("");
      setConfirmPassword("");
      if (!result.session) {
        setAwaitingConfirmation(normalized);
        return;
      }
      await registerCurrentAccount(client).catch(() => false);
      window.location.replace("/food");
    } catch (error) {
      if (error instanceof SignupPasswordTooShortError) {
        setMessage(`รหัสผ่านต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`);
      } else if (error instanceof EmailAlreadyRegisteredError) {
        setMessage("อีเมลนี้มีบัญชีอยู่แล้ว กรุณาเข้าสู่ระบบแทน");
      } else {
        setMessage("สมัคร WYNOS Food ไม่สำเร็จ กรุณาลองใหม่");
      }
    } finally {
      setLoading(false);
    }
  }

  if (!hasSupabaseBrowserConfig()) {
    return <FoodAuthShell><div className="wf-auth-state"><FoodAuthBrand /><h1>ยังไม่ได้ตั้งค่าการเชื่อมต่อ</h1><p>WYNOS Food ยังเชื่อมต่อระบบบัญชีไม่ได้</p></div></FoodAuthShell>;
  }
  if (checking) return <FoodAuthLoading />;

  if (awaitingConfirmation) {
    return (
      <FoodAuthShell>
        <FoodAuthBrand />
        <div className="wf-auth-confirm">
          <span><Mail size={27} /></span>
          <h1>ตรวจสอบอีเมลของคุณ</h1>
          <p>เราได้ส่งลิงก์ยืนยันไปที่ <strong>{awaitingConfirmation}</strong> แล้ว กดลิงก์เพื่อยืนยันบัญชีและกลับเข้า WYNOS Food</p>
          <Link className="wf-auth-primary wf-auth-link" href="/food/login">ไปหน้าเข้าสู่ระบบ</Link>
        </div>
      </FoodAuthShell>
    );
  }

  return (
    <FoodAuthShell>
      <FoodAuthBrand />
      <div className="wf-auth-hero">
        <h1>สมัคร WYNOS Food</h1>
        <p>สร้าง WYNOS Account เพื่อสั่งอาหารได้เลย โดยไม่ต้องเปิดใช้ Social</p>
      </div>
      <div className="wf-auth-benefits">
        <span><Check size={17} />ไม่ต้องตั้ง @username</span>
        <span><Check size={17} />ไม่ต้องสร้างโปรไฟล์ Social</span>
        <span><Check size={17} />เปิด WYNOS Social ภายหลังได้ด้วยบัญชีเดิม</span>
      </div>
      <div className="wf-auth-form">
        <label><span><Mail size={16} /> อีเมล</span><input type="email" autoComplete="email" autoCapitalize="none" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" /></label>
        <label><span><LockKeyhole size={16} /> รหัสผ่าน</span><input type="password" autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder={`อย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`} /></label>
        <label><span><LockKeyhole size={16} /> ยืนยันรหัสผ่าน</span><input type="password" autoComplete="new-password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} placeholder="พิมพ์รหัสผ่านอีกครั้ง" /></label>
        {message ? <p className="wf-auth-error" role="alert">{message}</p> : null}
        <button className="wf-auth-primary" type="button" disabled={loading} onClick={() => void submit()}>{loading ? "กำลังสร้างบัญชี…" : "สมัคร WYNOS Food"}</button>
      </div>
      <p className="wf-auth-switch">มี WYNOS Account อยู่แล้ว? <Link href="/food/login">เข้าสู่ระบบ</Link></p>
      <p className="wf-auth-terms">การสร้างบัญชีถือว่ายอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัวของ WYNOS</p>
    </FoodAuthShell>
  );
}
