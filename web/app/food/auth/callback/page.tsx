"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { registerCurrentAccount } from "@/lib/account-registry";
import { announceGooglePwaCode, announceGooglePwaCompletion, consumeGooglePwaPopupMarker } from "@/lib/google-pwa-oauth";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const FOOD_PRODUCTION_ORIGIN = "https://food.wynos.online";

function foodHomeUrl() {
  const host = window.location.hostname.toLowerCase();
  if (host === "food.wynos.online" || host === "wynos.online" || host === "www.wynos.online") {
    return `${FOOD_PRODUCTION_ORIGIN}/`;
  }
  return new URL("/food", window.location.origin).href;
}

export default function FoodGoogleCallbackPage() {
  const started = useRef(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    void (async () => {
      const params = new URLSearchParams(window.location.search);
      const code = params.get("code");
      const pwaPopup = consumeGooglePwaPopupMarker();

      try {
        if (params.has("error")) throw new Error("Google authentication failed");
        const client = getSupabaseBrowserClient();
        if (!client) throw new Error("Supabase browser client unavailable");

        // The installed PWA owns the PKCE verifier. Give its waiting opener
        // the one-time code so the exchange happens in that exact storage
        // partition instead of assuming the popup shares auth storage.
        if (pwaPopup && code && announceGooglePwaCode(code)) {
          window.history.replaceState(null, "", "/food/auth/callback");
          window.setTimeout(() => {
            try { window.close(); } catch { /* iOS may keep the popup open. */ }
            window.setTimeout(() => {
              if (!window.closed) window.location.replace(foodHomeUrl());
            }, 250);
          }, 150);
          return;
        }

        const existing = await client.auth.getSession();
        if (existing.error) throw existing.error;
        let session = existing.data.session;
        if (!session && code) {
          const exchanged = await client.auth.exchangeCodeForSession(code);
          if (exchanged.error) throw exchanged.error;
          session = exchanged.data.session;
        }
        if (!session) throw new Error("No authenticated session after Google callback");

        const confirmed = await client.auth.getUser();
        if (confirmed.error || !confirmed.data.user) {
          throw confirmed.error ?? new Error("Unable to confirm Google session");
        }

        await registerCurrentAccount(client).catch(() => false);
        window.history.replaceState(null, "", "/food/auth/callback");

        if (pwaPopup) {
          announceGooglePwaCompletion();
          if (window.opener && !window.opener.closed) {
            window.setTimeout(() => {
              try { window.close(); } catch { /* iOS may keep the popup open. */ }
              window.setTimeout(() => {
                if (!window.closed) window.location.replace(foodHomeUrl());
              }, 250);
            }, 250);
            return;
          }
        }

        window.location.replace(foodHomeUrl());
      } catch {
        window.history.replaceState(null, "", "/food/auth/callback");
        setError("เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณากลับไปหน้า WYNOS Food แล้วลองใหม่");
      }
    })();
  }, []);

  return (
    <main className="wf-auth-shell">
      <section className="wf-auth-card">
        {error ? (
          <div className="wf-auth-state">
            <h1>เข้าสู่ระบบไม่สำเร็จ</h1>
            <p role="alert">{error}</p>
            <Link className="wf-auth-primary wf-auth-link" href="/food/login">กลับไปหน้าเข้าสู่ระบบ</Link>
          </div>
        ) : (
          <div className="wf-auth-loading">
            <span className="wf-loader" />
            <strong>กำลังพาคุณกลับไป WYNOS Food…</strong>
          </div>
        )}
      </section>
    </main>
  );
}
