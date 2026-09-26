"use client";

import { createClient, type Session } from "@supabase/supabase-js";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { Button, Input, WynosIcon } from "@/components/ui";
import { GoogleGlyph } from "@/components/auth-flow/screens";
import {
  MAX_SAVED_ACCOUNTS,
  createAccountStorageKey,
  getActiveAccountStorageKey,
  listSavedAccounts,
  markAccountStorageActive,
  registerSessionAccount,
} from "@/lib/account-registry";
import { hasActivePushSubscription, unsubscribeFromPushNotifications } from "@/lib/push-notifications";
import { createAccountSwitchPriorClient } from "@/lib/supabase/browser";

export function AccountAddRoute() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [storageKey] = useState(() => {
    const slot = searchParams.get("slot");
    // Only WYNOS-generated account slots may be used on OAuth return.
    return slot && /^wynos\.account\.[a-zA-Z0-9-]{8,90}$/.test(slot) ? slot : createAccountStorageKey();
  });
  const finishInFlight = useRef(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [message, setMessage] = useState("");

  const client = useMemo(() => {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    if (!url || !publishableKey) return null;
    return createClient(url, publishableKey, {
      auth: {
        storageKey,
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
  }, [storageKey]);

  const finish = useCallback(async (session: Session) => {
    if (!client || finishInFlight.current) return;
    // getSession() and SIGNED_IN can both resolve on an OAuth callback.
    // Serialize the entire operation so neither path double-rotates tokens,
    // detaches Push twice, nor overwrites a newly activated account slot.
    finishInFlight.current = true;
    let navigating = false;
    try {
      // Keep the old account active until the new account is authenticated
      // and its registration succeeds. Detach the old Push token exactly
      // once, immediately before activating the new slot.
      if (typeof Notification !== "undefined" && Notification.permission === "granted") {
        const prior = createAccountSwitchPriorClient();
        const activeStorageKey = getActiveAccountStorageKey();
        const savedCurrent = listSavedAccounts().find((item) => item.storageKey === activeStorageKey);
        const priorSession = prior ? await prior.auth.getSession() : null;
        const priorId = priorSession?.data.session?.user.id;
        const differentAccount = Boolean(
          (priorId && priorId !== session.user.id) ||
          (savedCurrent && savedCurrent.userId !== session.user.id),
        );
        if (priorId && savedCurrent && savedCurrent.userId !== priorId) {
          setMessage("บัญชีเดิมไม่ตรงกับเซสชันบนอุปกรณ์ กรุณาเปิด WYNOS ใหม่");
          return;
        }
        if (differentAccount && priorId && (!prior || !(await unsubscribeFromPushNotifications(prior)))) {
          setMessage("ปิด Push ของบัญชีเดิมไม่สำเร็จ กรุณากลับไปที่บัญชีเดิมแล้วลองอีกครั้ง");
          return;
        }
        if (!priorId && (await hasActivePushSubscription()) !== false) {
          // A stale worker subscription could still receive private messages
          // for an account whose login has expired or was removed offline.
          // Without that account's session we cannot delete its server token.
          setMessage("ยังมี Push ของบัญชีเดิมอยู่ กรุณาเข้าสู่ระบบบัญชีเดิมเพื่อปิดการแจ้งเตือนก่อน");
          return;
        }
      }
      const saved = await registerSessionAccount(client, session, storageKey);
      if (!saved) {
        setMessage(`บันทึกบัญชีได้สูงสุด ${MAX_SAVED_ACCOUNTS} บัญชี`);
        return;
      }
      markAccountStorageActive(storageKey);
      window.location.replace("/");
      navigating = true;
    } catch {
      setMessage("เพิ่มบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
    } finally {
      if (!navigating) finishInFlight.current = false;
    }
  }, [client, storageKey]);

  useEffect(() => {
    if (!client || searchParams.get("oauth") !== "1") return;
    let mounted = true;
    void client.auth.getSession().then(({ data }) => {
      if (mounted && data.session) void finish(data.session);
    });
    const { data } = client.auth.onAuthStateChange((_event, session) => {
      if (mounted && session) void finish(session);
    });
    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [client, finish, searchParams]);

  async function signIn() {
    if (!client || loading) return;
    if (listSavedAccounts().length >= MAX_SAVED_ACCOUNTS) {
      setMessage(`บันทึกบัญชีได้สูงสุด ${MAX_SAVED_ACCOUNTS} บัญชี`);
      return;
    }
    if (!email.trim() || !password) {
      setMessage("กรุณากรอกอีเมลและรหัสผ่าน");
      return;
    }
    setLoading(true);
    setMessage("");
    try {
      const result = await client.auth.signInWithPassword({ email: email.trim(), password });
      if (result.error || !result.data.session) {
        setMessage(result.error?.code === "email_not_confirmed" ? "บัญชีนี้ยังไม่ได้ยืนยันอีเมล" : "อีเมลหรือรหัสผ่านไม่ถูกต้อง");
        return;
      }
      await finish(result.data.session);
    } catch {
      setMessage("เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setLoading(false);
    }
  }

  async function google() {
    if (!client || googleLoading) return;
    if (listSavedAccounts().length >= MAX_SAVED_ACCOUNTS) {
      setMessage(`บันทึกบัญชีได้สูงสุด ${MAX_SAVED_ACCOUNTS} บัญชี`);
      return;
    }
    setGoogleLoading(true);
    setMessage("");
    const redirectTo = `${window.location.origin}/account/add?slot=${encodeURIComponent(storageKey)}&oauth=1`;
    const result = await client.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo, queryParams: { prompt: "select_account" } },
    });
    if (result.error) {
      setMessage("เข้าสู่ระบบด้วย Google ไม่สำเร็จ");
      setGoogleLoading(false);
    }
  }

  return (
    <main className="auth-ref-viewport">
      <div className="phone" id="phone">
        <div className="topbar">
          <button className="ic-btn" type="button" onClick={() => router.back()} aria-label="ย้อนกลับ">
            <WynosIcon name="back" size={16} />
          </button>
          <span />
        </div>
        <div style={{ padding: "16px 20px", flex: 1 }}>
          <div style={{ textAlign: "center", marginBottom: 28 }}>
            <svg height="36" style={{ margin: "0 auto 14px" }} viewBox="0 0 26 26" width="36" aria-label="Wynos">
              <path d="M2 4 L8 22 L13 9 L18 22 L24 4" fill="none" stroke="#0A0A0A" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
            </svg>
            <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em" }}>เพิ่มบัญชี</div>
            <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "6px 0 0" }}>เข้าสู่ระบบเพื่อบันทึกบัญชีนี้ไว้สำหรับสลับภายหลัง</p>
          </div>
          <div className="field">
            <label>อีเมล</label>
            <Input bare type="email" inputMode="email" autoCapitalize="none" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" />
          </div>
          <div className="field">
            <label>รหัสผ่าน</label>
            <Input bare type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="รหัสผ่านของคุณ" />
          </div>
          <Button className="btn-primary" disabled={loading || googleLoading} onClick={() => void signIn()}>
            {loading ? "กำลังเข้าสู่ระบบ…" : "เข้าสู่ระบบและเพิ่มบัญชี"}
          </Button>
          <Button
            className="btn-outline"
            variant="outline"
            disabled={loading || googleLoading}
            onClick={() => void google()}
            leadingIcon={googleLoading ? undefined : <GoogleGlyph />}
            style={{ marginTop: 10 }}
          >
            {googleLoading ? "กำลังเชื่อมต่อ Google…" : "เข้าสู่ระบบด้วย Google"}
          </Button>
          {message ? <p style={{ color: "var(--red)", fontSize: 12, margin: "10px 0 0" }} role="alert">{message}</p> : null}
          <p style={{ color: "var(--text-muted)", fontSize: 11, lineHeight: 1.5, textAlign: "center", margin: "18px 12px 0" }}>
            WYNOS ไม่บันทึกรหัสผ่าน บัญชีที่เพิ่มจะใช้ session ของ Supabase แยกจากกันบนอุปกรณ์นี้
          </p>
        </div>
      </div>
    </main>
  );
}
