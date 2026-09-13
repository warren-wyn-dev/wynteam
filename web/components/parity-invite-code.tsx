"use client";

import { ArrowLeft } from "lucide-react";
import { useMemo, useState } from "react";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

export const PENDING_REFERRAL_KEY = "wynos.pending-referral-code";

export function ParityInviteCode({
  onBack,
  onValidated,
}: {
  onBack: () => void;
  onValidated: () => void;
}) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function submit() {
    const value = code.trim();
    if (!value) {
      setError("กรุณากรอกโค้ดเชิญ");
      return;
    }
    if (!supabase) {
      setError("เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง");
      return;
    }

    setLoading(true);
    setError("");
    try {
      const result = await supabase.rpc("validate_referral_code", { p_code: value });
      if (result.error) throw result.error;
      if (result.data !== true) {
        setError("โค้ดเชิญไม่ถูกต้อง");
        return;
      }
      window.sessionStorage.setItem(PENDING_REFERRAL_KEY, value);
      onValidated();
    } catch {
      setError("เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="parity-auth parity-form-screen">
      <header className="parity-auth-appbar">
        <button className="parity-back" type="button" onClick={onBack} aria-label="ย้อนกลับ">
          <ArrowLeft aria-hidden="true" strokeWidth={1.8} />
        </button>
      </header>
      <section className="parity-auth-content parity-invite-content">
        <h1>กรอกโค้ดเชิญ</h1>
        <p>ตอนนี้ WYNOS เปิดให้เข้าใช้งานเฉพาะผู้ที่มีโค้ดเชิญจากเพื่อนเท่านั้น</p>
        <label className="parity-field">
          <span>โค้ดเชิญ</span>
          <input
            value={code}
            onChange={(event) => {
              setCode(event.target.value.toUpperCase());
              if (error) setError("");
            }}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !loading) void submit();
            }}
            autoCapitalize="characters"
            autoComplete="off"
          />
        </label>
        <button className="parity-primary" type="button" disabled={loading} onClick={() => void submit()}>
          {loading ? "กำลังตรวจสอบ…" : "ดำเนินการต่อ"}
        </button>
        {error ? <p className="parity-auth-error" role="alert">{error}</p> : null}
      </section>
    </main>
  );
}
