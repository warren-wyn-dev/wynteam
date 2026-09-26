"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { forgetSignedOutAccount, getActiveAccountStorageKey } from "@/lib/account-registry";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";
import { revokeLocalPushSubscription, unsubscribeFromPushNotifications } from "@/lib/push-notifications";
import { cacheBrowserSession, getCachedBrowserSession } from "@/lib/supabase/session-cache";
import { clearReturnPath, rememberReturnPath } from "@/lib/return-to";

type GateState = "loading" | "missing-config" | "signed-out" | "ready" | "error";

export type DeveloperRouteContext = {
  client: SupabaseClient;
  session: Session;
  userId: string;
  signOut: () => Promise<void>;
};

/**
 * Historical name kept so the Phase-3 route components do not need a risky
 * mechanical rename. WYN-158 parity recovery removes the staged developer
 * allow-list: every authenticated WYNOS account now receives the same
 * consumer routes, matching Flutter's AuthGate. No authorization contract is
 * weakened here; Supabase Auth/RLS remains authoritative for every read/write.
 *
 * The known browser session is kept in a tiny module-level cache shared with
 * Home. That lets client-side navigation paint the next screen immediately
 * instead of blanking the whole app behind an auth spinner on every route.
 * Supabase is still checked in the background and auth-state events remain the
 * source of truth.
 */
export function DeveloperRouteGate({
  children,
}: {
  children: (context: DeveloperRouteContext) => React.ReactNode;
}) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const knownSession = getCachedBrowserSession();
  const [gate, setGate] = useState<GateState>(() => {
    if (!hasSupabaseBrowserConfig()) return "missing-config";
    if (knownSession === undefined) return "loading";
    return knownSession ? "ready" : "signed-out";
  });
  const [session, setSession] = useState<Session | null>(() => knownSession ?? null);
  const [message, setMessage] = useState("");

  const acceptSession = useCallback((nextSession: Session | null) => {
    const previousSession = getCachedBrowserSession();
    if (previousSession?.user.id && previousSession.user.id !== nextSession?.user.id) {
      // Auth can also change in another tab or through OAuth callbacks.
      queryClient.clear();
    }
    cacheBrowserSession(nextSession);
    setSession(nextSession);
    setMessage("");
    if (!hasSupabaseBrowserConfig() || !client) {
      setGate("missing-config");
      return;
    }
    setGate(nextSession ? "ready" : "signed-out");
  }, [client, queryClient]);

  const verifySession = useCallback(async () => {
    if (!client) return;
    const { data, error } = await client.auth.getSession();
    if (error) {
      // A warm session is already painting the app. Do not replace the whole
      // screen with an error for a transient verification failure; the auth
      // listener will still move us to signed-out if Supabase invalidates it.
      if (getCachedBrowserSession()) return;
      setMessage("เปิด WYNOS ไม่สำเร็จ กรุณาลองใหม่");
      setGate("error");
      return;
    }
    acceptSession(data.session);
  }, [acceptSession, client]);

  useEffect(() => {
    if (!client) return;
    let mounted = true;

    // The initial SDK event is not an explicit logout. Let the persisted
    // session check settle first, especially on iOS standalone reopens.
    let newerAuthEvent = false;
    const { data } = client.auth.onAuthStateChange((event, nextSession) => {
      if (!mounted || event === "INITIAL_SESSION") return;
      newerAuthEvent = true;
      acceptSession(nextSession);
    });

    const onCheckError = () => {
      if (!mounted || newerAuthEvent || getCachedBrowserSession()) return;
      setMessage("ตรวจสอบการเข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่");
      setGate("error");
    };
    void client.auth.getSession().then(({ data: sessionData, error }) => {
      if (!mounted || newerAuthEvent) return;
      if (error) {
        onCheckError();
        return;
      }
      acceptSession(sessionData.session);
    }).catch(onCheckError);

    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [acceptSession, client]);

  useEffect(() => {
    // Straight to /welcome, not "/": routing through Home first just means
    // ParityAuthEntry immediately replaces *again* to /welcome once its own
    // session check lands — a wasted extra hop, and one more chance for that
    // second replace to race a navigation the user already started in the
    // meantime.
    if (gate === "signed-out") {
      // Keep a shared link (post, profile, club) to reopen after sign-in.
      rememberReturnPath(`${window.location.pathname}${window.location.search}`);
      router.replace("/welcome");
    }
  }, [gate, router]);

  const signOut = useCallback(async () => {
    if (!client) return;
    const signingOutUserId = session?.user.id;
    const signingOutStorageKey = getActiveAccountStorageKey();
    // Detach A's token while A's auth/RLS are still present. Keep the
    // existing best-effort local revoke if network deletion fails.
    const serverDetached = await unsubscribeFromPushNotifications(client);
    if (!serverDetached) await revokeLocalPushSubscription();
    await client.auth.signOut();
    if (signingOutUserId) {
      // A normal Login after logout must not reuse A's stale custom slot
      // or leave an invalid saved entry pretending it still belongs to A.
      forgetSignedOutAccount(signingOutUserId, signingOutStorageKey);
    }
    cacheBrowserSession(null);
    queryClient.clear();
    // A soft Next router transition preserves the module-level Supabase
    // singleton, which is still bound to the old account's storage key.
    // Rebuild it from the now-cleared active pointer before the next login.
    // A signing-out account's page must not reopen for the next login.
    clearReturnPath();
    window.location.replace("/welcome");
  }, [client, queryClient, session]);

  if (gate === "loading" || gate === "signed-out") {
    return <main className="route-state"><div className="route-system-spinner" aria-label="กำลังโหลด" /></main>;
  }
  if (gate === "missing-config") {
    return <main className="route-state"><h1>WYNOS</h1><p>ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS สำหรับเว็บ</p></main>;
  }
  if (gate === "error" || !client || !session) {
    return (
      <main className="route-state">
        <h1>WYNOS</h1>
        <p>{message || "เกิดข้อผิดพลาด"}</p>
        <button className="route-primary" type="button" onClick={() => { setGate("loading"); setMessage(""); void verifySession(); }}>ลองใหม่</button>
      </main>
    );
  }

  return <>{children({ client, session, userId: session.user.id, signOut })}</>;
}
