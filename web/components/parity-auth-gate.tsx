"use client";

import type { Session } from "@supabase/supabase-js";
import { ArrowLeft, LoaderCircle } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";

import { HomeMigrationPreview } from "@/components/home-migration-preview";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

type AuthView = "welcome" | "methods";

export function ParityAuthGate() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [booting, setBooting] = useState(true);
  const [view, setView] = useState<AuthView>("welcome");
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState("");

  useEffect(() => {
    if (!supabase) {
      setBooting(false);
      return;
    }
    let mounted = true;
    void supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return;
      setSession(data.session);
      setBooting(false);
    });
    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!mounted) return;
      setSession(nextSession);
      setBooting(false);
    });
    return () => {
      mounted = false;
      subscription.subscription.unsubscribe();
    };
  }, [supabase]);

  const signInWithGoogle = useCallback(async () => {
    if (!supabase || authLoading) return;
    setAuthLoading(true);
    setAuthError("");
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/` },
    });
    if (error) {
      setAuthError("เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง");
      setAuthLoading(false);
    }
  }, [authLoading, supabase]);

  if (!hasSupabaseBrowserConfig() || !supabase) {
    return <main className="parity-auth parity-auth-loading">ยังไม่ได้ตั้งค่า Supabase สำหรับเว็บ</main>;
  }
  if (booting) {
    return <main className="parity-auth parity-auth-loading"><LoaderCircle className="parity-spinner" /></main>;
  }
  if (session) return <HomeMigrationPreview />;

  if (view === "welcome") {
    return (
      <main className="parity-auth parity-welcome">
        <div className="parity-welcome-brand">
          <div className="parity-wordmark-line">
            <h1>WYNOS</h1>
            <span className="parity-beta">BETA</span>
          </div>
          <p>เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง</p>
        </div>
        <button className="parity-primary parity-welcome-cta" type="button" onClick={() => setView("methods")}>
          เริ่มต้นใช้งาน
        </button>
      </main>
    );
  }

  return (
    <main className="parity-auth parity-form-screen">
      <header className="parity-auth-appbar">
        <button className="parity-back" type="button" onClick={() => setView("welcome")} aria-label="ย้อนกลับ">
          <ArrowLeft aria-hidden="true" strokeWidth={1.8} />
        </button>
      </header>
      <section className="parity-auth-content parity-method-content">
        <h1>เข้าสู่ระบบ WYNOS</h1>
        <div className="parity-method-actions">
          <button className="parity-primary parity-google" type="button" disabled={authLoading} onClick={() => void signInWithGoogle()}>
            <span className="parity-google-mark" aria-hidden="true">G</span>
            เข้าสู่ระบบด้วย Google
          </button>
          <button className="parity-outline" type="button" disabled aria-disabled="true">
            เข้าสู่ระบบด้วยอีเมล
          </button>
        </div>
        {authLoading ? <LoaderCircle className="parity-spinner parity-inline-spinner" /> : null}
        {authError ? <p className="parity-auth-error" role="alert">{authError}</p> : null}
      </section>
    </main>
  );
}
