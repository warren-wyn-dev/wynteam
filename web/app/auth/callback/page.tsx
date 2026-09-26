"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { getPendingAddAccountClient, getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { claimPendingAddAccountSlot, getPendingAddAccountSlot, validAddAccountSlot } from "@/lib/pending-account-add";
import { hasProfileRow } from "@/lib/auth-repository";
import { announceGooglePwaCompletion, consumeGooglePwaPopupMarker } from "@/lib/google-pwa-oauth";

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
  const [popupComplete, setPopupComplete] = useState(false);
  const [externalConfirmation, setExternalConfirmation] = useState(false);

  useEffect(() => {
    // Avoid exchanging a one-time PKCE code twice under React Strict Mode.
    if (started.current) return;
    started.current = true;

    void (async () => {
      const params = new URLSearchParams(window.location.search);
      const code = params.get("code");
      const addSlot = params.get("slot");
      // A forged/stale link must never fall through to A's active client.
      const pendingSlot = getPendingAddAccountSlot();

      try {
        if (params.has("error")) throw new Error("Email confirmation failed");
        if (addSlot && !validAddAccountSlot(addSlot)) throw new Error("Invalid account slot");
        if (addSlot && !pendingSlot) {
          // iOS Mail opens a different Safari storage partition from an
          // installed WYNOS PWA. We cannot exchange the original PKCE verifier
          // here. Supabase may already have confirmed the email server-side:
          // tell the user to return to the *installed app* and sign in there.
          // Never open this link using A's active session in Safari.
          window.history.replaceState(null, "", "/auth/callback");
          setExternalConfirmation(true);
          return;
        }
        if (addSlot && addSlot !== pendingSlot) throw new Error("Invalid add-account callback slot");
        const client = addSlot ? getPendingAddAccountClient(addSlot) : getSupabaseBrowserClient();
        if (!client) throw new Error("Supabase browser client unavailable");

        // For Add Account, the isolated client deliberately disables automatic
        // callback detection. Always exchange this link's one-time code first:
        // getSession() could otherwise return a previous *pending* identity and
        // incorrectly confirm the wrong account. Normal auth retains its SDK
        // initialization/possible auto-exchange behavior.
        let session;
        if (addSlot && code) {
          const exchanged = await client.auth.exchangeCodeForSession(code);
          if (exchanged.error) throw exchanged.error;
          session = exchanged.data.session;
        } else {
          const existing = await client.auth.getSession();
          if (existing.error) throw existing.error;
          session = existing.data.session;
          if (!session && code) {
            const exchanged = await client.auth.exchangeCodeForSession(code);
            if (exchanged.error) throw exchanged.error;
            session = exchanged.data.session;
          }
        }
        if (!session) throw new Error("No authenticated session after callback");

        const confirmed = await client.auth.getUser();
        if (confirmed.error || !confirmed.data.user) {
          throw confirmed.error ?? new Error("Unable to confirm session");
        }
        // The email may open in a new tab with the same localStorage but a
        // separate sessionStorage. Only the verified callback can let that tab
        // continue signup with the pending account's isolated session.
        if (addSlot && !claimPendingAddAccountSlot(addSlot)) {
          throw new Error("Unable to claim confirmed account slot");
        }

        // Remove the one-time code from the address bar before navigating,
        // messaging the opener, or recording any subsequent app interaction.
        window.history.replaceState(null, "", "/auth/callback");
        const isAddAccountPopup = Boolean(addSlot && addSlot === pendingSlot && params.get("popupAdd") === "1");
        if (consumeGooglePwaPopupMarker()) {
          if (isAddAccountPopup) {
            // The waiting Add Account screen finalizes the slot, not the popup.
            announceGooglePwaCompletion();
            setPopupComplete(true);
            // If the opener was severed by iOS/COOP, BroadcastChannel (or
            // returning focus to WYNOS) still lets the parent finish safely.
            window.setTimeout(() => {
              try { window.close(); } catch { /* Browser can decline. */ }
            }, 600);
            return;
          }
          let destination = "/";
          try {
            const existingProfile = await hasProfileRow(client, confirmed.data.user.id);
            destination = existingProfile ? "/" : "/signup/step-1";
          } catch {
            // Google authentication already succeeded; an unrelated profile
            // lookup outage must not send the user back through OAuth again.
          }
          announceGooglePwaCompletion();
          // A script-opened window may close itself; if iOS declines, the
          // authenticated popup still offers a working Home/onboarding path.
          if (window.opener && !window.opener.closed) {
            window.setTimeout(() => window.close(), 600);
          }
          router.replace(destination);
          return;
        }

        if (isAddAccountPopup) {
          router.replace(`/account/add?slot=${encodeURIComponent(addSlot!)}&oauth=1`);
          return;
        }

        // The email-confirmation callback's original onboarding flow remains
        // unchanged. Signup draft fields survive in sessionStorage.
        router.replace("/signup/step-1");
      } catch {
        window.history.replaceState(null, "", "/auth/callback");
        setError("เข้าสู่ระบบหรือยืนยันอีเมลไม่สำเร็จ กรุณาลองใหม่");
      }
    })();
  }, [router]);

  return (
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
      <section style={{ width: "100%", maxWidth: 420, textAlign: "center" }}>
        {externalConfirmation ? (
          <>
            <h1 style={{ fontSize: 24, fontWeight: 700 }}>กลับไปที่แอป WYNOS</h1>
            <p role="status" style={{ margin: "16px 0", lineHeight: 1.6 }}>
              หากคุณเปิดอีเมลจากนอกแอป กรุณากลับไปที่ WYNOS ที่ติดตั้งไว้
              แล้วเลือก “เพิ่มบัญชี” → “เข้าสู่ระบบ” ด้วยอีเมลที่เพิ่งยืนยัน
              โดยบัญชีเดิมจะยังอยู่ หากยังเข้าสู่ระบบไม่ได้ให้ขอลิงก์ยืนยันใหม่
            </p>
          </>
        ) : error ? (
          <>
            <h1 style={{ fontSize: 24, fontWeight: 700 }}>ยืนยันตัวตนไม่สำเร็จ</h1>
            <p role="alert" style={{ margin: "16px 0", lineHeight: 1.6 }}>{error}</p>
            <button type="button" onClick={() => router.replace("/login")}>ไปหน้าเข้าสู่ระบบ</button>
          </>
        ) : (
          <p role="status">{popupComplete ? "เข้าสู่ระบบ Google สำเร็จ กลับไปที่ WYNOS ได้เลย" : "กำลังยืนยันตัวตนและนำคุณกลับไปยัง WYNOS…"}</p>
        )}
      </section>
    </main>
  );
}
