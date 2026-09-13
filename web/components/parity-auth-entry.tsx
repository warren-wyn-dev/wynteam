"use client";

import type { Session } from "@supabase/supabase-js";
import { ArrowLeft, LoaderCircle } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { HomeMigrationPreview } from "@/components/home-migration-preview";
import { ParityEmailAuth } from "@/components/parity-email-auth";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

type View = "welcome" | "methods" | "email";

export function ParityAuthEntry() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [booting, setBooting] = useState(true);
  const [view, setView] = useState<View>("welcome");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!supabase) { setBooting(false); return; }
    let mounted = true;
    void supabase.auth.getSession().then(({ data }) => { if (mounted) { setSession(data.session); setBooting(false); } });
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => { if (mounted) { setSession(nextSession); setBooting(false); } });
    return () => { mounted = false; data.subscription.unsubscribe(); };
  }, [supabase]);

  async function google() {
    if (!supabase || loading) return;
    setLoading(true);
    setError("");
    const result = await supabase.auth.signInWithOAuth({ provider: "google", options: { redirectTo: `${window.location.origin}/` } });
    if (result.error) { setError("เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง"); setLoading(false); }
  }

  if (!hasSupabaseBrowserConfig() || !supabase) return <main className="parity-auth parity-auth-loading">ยังไม่ได้ตั้งค่า Supabase สำหรับเว็บ</main>;
  if (booting) return <main className="parity-auth parity-auth-loading"><LoaderCircle className="parity-spinner" /></main>;
  if (session) return <HomeMigrationPreview />;
  if (view === "email") return <ParityEmailAuth onBack={() => setView("methods")} />;

  if (view === "welcome") return (
    <main className="parity-auth parity-welcome">
      <div className="parity-welcome-brand">
        <div className="parity-wordmark-line"><h1>WYNOS</h1><span className="parity-beta">BETA</span></div>
        <p>เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง</p>
      </div>
      <button className="parity-primary parity-welcome-cta" type="button" onClick={() => setView("methods")}>เริ่มต้นใช้งาน</button>
    </main>
  );

  return (
    <main className="parity-auth parity-form-screen">
      <header className="parity-auth-appbar">
        <button className="parity-back" type="button" onClick={() => setView("welcome")} aria-label="ย้อนกลับ"><ArrowLeft aria-hidden="true" strokeWidth={1.8} /></button>
      </header>
      <section className="parity-auth-content parity-method-content">
        <h1>เข้าสู่ระบบ WYNOS</h1>
        <div className="parity-method-actions">
          <button className="parity-primary parity-google" type="button" disabled={loading} onClick={() => void google()}><span className="parity-google-mark" aria-hidden="true">G</span>เข้าสู่ระบบด้วย Google</button>
          <button className="parity-outline" type="button" disabled={loading} onClick={() => setView("email")}>เข้าสู่ระบบด้วยอีเมล</button>
        </div>
        {loading ? <LoaderCircle className="parity-spinner parity-inline-spinner" /> : null}
        {error ? <p className="parity-auth-error" role="alert">{error}</p> : null}
      </section>
    </main>
  );
}
