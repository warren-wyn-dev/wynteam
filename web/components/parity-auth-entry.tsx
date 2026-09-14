"use client";

import type { Session } from "@supabase/supabase-js";
import { ArrowLeft, LoaderCircle } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { HomeScreen } from "@/components/home/home-screen";
import { ParityEmailAuth } from "@/components/parity-email-auth";
import { ParityInviteCode } from "@/components/parity-invite-code";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

type View = "welcome" | "methods" | "email" | "invite";
type InviteStatus = "idle" | "checking" | "blocked" | "open";

export function ParityAuthEntry() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [booting, setBooting] = useState(() => Boolean(supabase));
  const [view, setView] = useState<View>("welcome");
  const [inviteStatus, setInviteStatus] = useState<InviteStatus>("idle");
  const [inviteValidated, setInviteValidated] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!supabase) return;
    let mounted = true;
    void supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return;
      setSession(data.session);
      setBooting(false);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!mounted) return;
      setSession(nextSession);
      setBooting(false);
    });
    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [supabase]);

  async function openMethods() {
    setView("methods");
    setError("");
    if (inviteValidated) {
      setInviteStatus("open");
      return;
    }
    if (!supabase) {
      setInviteStatus("open");
      return;
    }

    setInviteStatus("checking");
    try {
      const result = await supabase.rpc("is_invite_gate_enabled");
      if (result.error) throw result.error;
      setInviteStatus(result.data === true ? "blocked" : "open");
    } catch {
      setInviteStatus("open");
    }
  }

  async function google() {
    if (loading) return;
    if (!supabase) {
      setError("ยังไม่ได้ตั้งค่าการเข้าสู่ระบบสำหรับเว็บ");
      return;
    }
    setLoading(true);
    setError("");
    const result = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/`,
        queryParams: { prompt: "select_account" },
      },
    });
    if (result.error) {
      setError("เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง");
      setLoading(false);
    }
  }

  if (booting) return <main className="parity-auth parity-auth-loading"><LoaderCircle className="parity-spinner" /></main>;
  if (session) return <HomeScreen session={session} />;
  if (view === "email") return <ParityEmailAuth onBack={() => setView("methods")} />;
  if (view === "invite") {
    return <ParityInviteCode onBack={() => setView("methods")} onValidated={() => { setInviteValidated(true); setInviteStatus("open"); setView("methods"); }} />;
  }

  if (view === "welcome") {
    return <main className="parity-auth parity-welcome"><div className="parity-welcome-brand"><div className="parity-wordmark-line"><h1>WYNOS</h1><span className="parity-beta">BETA</span></div><p>เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง</p></div><button className="parity-primary parity-welcome-cta" type="button" onClick={() => void openMethods()}>เริ่มต้นใช้งาน</button></main>;
  }

  return <main className="parity-auth parity-form-screen"><header className="parity-auth-appbar"><button className="parity-back" type="button" onClick={() => setView("welcome")} aria-label="ย้อนกลับ"><ArrowLeft aria-hidden="true" strokeWidth={1.8} /></button></header><section className="parity-auth-content parity-method-content"><h1>เข้าสู่ระบบ WYNOS</h1><div className="parity-method-actions">{inviteStatus === "checking" || inviteStatus === "idle" ? <LoaderCircle className="parity-spinner parity-method-spinner" aria-label="กำลังตรวจสอบสิทธิ์เข้าใช้งาน" /> : inviteStatus === "blocked" ? <><p className="parity-invite-message">ตอนนี้ WYNOS เปิดให้เข้าใช้งานเฉพาะผู้ที่มีโค้ดเชิญจากเพื่อนเท่านั้น</p><button className="parity-primary" type="button" onClick={() => setView("invite")}>กรอกโค้ดเชิญ</button></> : <><button className="parity-primary parity-google" type="button" disabled={loading} onClick={() => void google()}><span className="parity-google-mark" aria-hidden="true">G</span>เข้าสู่ระบบด้วย Google</button><button className="parity-outline" type="button" disabled={loading} onClick={() => setView("email")}>เข้าสู่ระบบด้วยอีเมล</button></>}</div>{loading ? <LoaderCircle className="parity-spinner parity-inline-spinner" /> : null}{error ? <p className="parity-auth-error" role="alert">{error}</p> : null}</section></main>;
}
