"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

/**
 * Email confirmation finishes authentication before onboarding writes.
 * This browser callback works with the project's SSR cookie client and its
 * multi-account local-storage client (whose PKCE verifier is browser-only).
 */
export default function EmailConfirmationCallbackPage() {
  const router = useRouter();
  const started = useRef(false);
  const [error, setError] = useState("");

  useEffect(() => {
    // Avoid exchanging a one-time PKCE code twice under React Strict Mode.
    if (started.current) return;
    started.current = true;

    void (async () => {
      const params = new URLSearchParams(window.location.search);
      const code = params.get("code");

      try {
        if (params.has("error")) throw new Error("Email confirmation failed");
        const client = getSupabaseBrowserClient();
        if (!client) throw new Error("Supabase browser client unavailable");

        // Await the SDK's own URL/session initialization first. Some clients
        // consume the code automatically; other storage configurations need
        // an explicit exchange. Never exchange a successfully consumed code.
        const existing = await client.auth.getSession();
        if (existing.error) throw existing.error;
        let session = existing.data.session;
        if (!session && code) {
          const exchanged = await client.auth.exchangeCodeForSession(code);
          if (exchanged.error) throw exchanged.error;
          session = exchanged.data.session;
        }
        if (!session) throw new Error("No authenticated session after callback");

        const confirmed = await client.auth.getUser();
        if (confirmed.error || !confirmed.data.user) {
          throw confirmed.error ?? new Error("Unable to confirm session");
        }

        // Step-1 fields (not credentials) survive in sessionStorage. The
        // signed-in step-1 path now has permission to write profile + DOB.
        window.history.replaceState(null, "", "/auth/callback");
        router.replace("/signup/step-1");
      } catch {
        window.history.replaceState(null, "", "/auth/callback");
        setError("ยืนยันอีเมลไม่สำเร็จหรือลิงก์หมดอายุ กรุณาเข้าสู่ระบบหรือสมัครใหม่อีกครั้ง");
      }
    })();
  }, [router]);

  return (
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
      <section style={{ width: "100%", maxWidth: 420, textAlign: "center" }}>
        {error ? (
          <>
            <h1 style={{ fontSize: 24, fontWeight: 700 }}>ยืนยันอีเมลไม่สำเร็จ</h1>
            <p role="alert" style={{ margin: "16px 0", lineHeight: 1.6 }}>{error}</p>
            <button type="button" onClick={() => router.replace("/login")}>ไปหน้าเข้าสู่ระบบ</button>
          </>
        ) : (
          <p role="status">กำลังยืนยันอีเมลและนำคุณกลับไปตั้งค่าโปรไฟล์…</p>
        )}
      </section>
    </main>
  );
}
