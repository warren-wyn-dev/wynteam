"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { hasProfileRow } from "@/lib/auth-repository";
import { announceGooglePwaCompletion, consumeGooglePwaPopupMarker } from "@/lib/google-pwa-oauth";
import { isSafeReturnPath } from "@/lib/return-to";

/**
 * Email confirmation and installed-iOS Google popup both exchange their
 * one-time PKCE code in the SAME browser storage partition that started
 * authentication. A Google popup announces success to the waiting PWA.
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
      const requestedNext = params.get("next");

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

        // Remove the one-time code from the address bar before navigating,
        // messaging the opener, or recording any subsequent app interaction.
        window.history.replaceState(null, "", "/auth/callback");
        const legacyFoodReturn = requestedNext === "/food";
        if (consumeGooglePwaPopupMarker()) {
          const safeProductDestination = requestedNext && isSafeReturnPath(requestedNext)
            ? requestedNext
            : null;
          let destination = safeProductDestination ?? "/";
          if (!safeProductDestination) {
            try {
              const existingProfile = await hasProfileRow(client, confirmed.data.user.id);
              destination = existingProfile ? "/" : "/signup/step-1";
            } catch {
              // Google authentication already succeeded; an unrelated profile
              // lookup outage must not send the user back through OAuth again.
            }
          }
          announceGooglePwaCompletion();
          // Legacy Food clients may still have started OAuth from the Social
          // origin. Never let that successful sign-in fall into Social.
          if (legacyFoodReturn) {
            if (window.opener && !window.opener.closed) {
              window.setTimeout(() => {
                try { window.close(); } catch { /* iOS may keep the popup open. */ }
                window.setTimeout(() => {
                  if (!window.closed) window.location.replace("https://food.wynos.online/");
                }, 250);
              }, 250);
              return;
            }
            window.location.replace("https://food.wynos.online/");
            return;
          }
          // A script-opened window may close itself; if iOS declines, the
          // authenticated popup still offers a working Home/onboarding path.
          if (window.opener && !window.opener.closed) {
            window.setTimeout(() => window.close(), 600);
          }
          router.replace(destination);
          return;
        }

        // Product-specific signup can return to its own surface without
        // forcing Social onboarding. Only same-origin, non-auth paths are allowed.
        // The ordinary Social signup still falls back to its existing onboarding.
        const destination = requestedNext && isSafeReturnPath(requestedNext)
          ? requestedNext
          : "/signup/step-1";
        if (destination === "/food") {
          window.location.replace("https://food.wynos.online/");
          return;
        }
        router.replace(destination);
      } catch {
        window.history.replaceState(null, "", "/auth/callback");
        setError("เข้าสู่ระบบหรือยืนยันอีเมลไม่สำเร็จ กรุณาลองใหม่");
      }
    })();
  }, [router]);

  return (
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
      <section style={{ width: "100%", maxWidth: 420, textAlign: "center" }}>
        {error ? (
          <>
            <h1 style={{ fontSize: 24, fontWeight: 700 }}>ยืนยันตัวตนไม่สำเร็จ</h1>
            <p role="alert" style={{ margin: "16px 0", lineHeight: 1.6 }}>{error}</p>
            <button type="button" onClick={() => router.replace("/login")}>ไปหน้าเข้าสู่ระบบ</button>
          </>
        ) : (
          <p role="status">กำลังยืนยันตัวตนและนำคุณกลับไปยัง WYNOS…</p>
        )}
      </section>
    </main>
  );
}
