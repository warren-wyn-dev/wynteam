"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { LoaderCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { HomeScreen } from "@/components/home/home-screen";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { cacheBrowserSession, getCachedBrowserSession } from "@/lib/supabase/session-cache";

/// Root ("/") auth gate: shows Home for any signed-in user, otherwise
/// sends the browser to the new pixel-matched auth flow at /welcome
/// rather than rendering its own separate welcome UI.
///
/// Deliberately does NOT branch on WYN-002's `profile_private.onboarding_completed`
/// here: that flag is only meaningful for accounts created through the new
/// /signup flow (which chains straight to /onboarding/profile itself right
/// after sign-up). Every account created before this flow existed —
/// including every current wynos.online user — has no `profile_private`
/// row at all, which would read as "onboarding incomplete" and bounce a
/// real, working account away from its own Home feed. Any signed-in
/// session lands on Home, full stop; only a *missing* session goes to
/// /welcome.
export function ParityAuthEntry({ clientOverride }: { clientOverride?: SupabaseClient } = {}) {
  // Injected only by the /dev auth regression fixture; real routes always
  // use the same persisted singleton from getSupabaseBrowserClient().
  const supabase = useMemo(() => clientOverride ?? getSupabaseBrowserClient(), [clientOverride]);
  const router = useRouter();
  const knownSession = getCachedBrowserSession();
  const [session, setSession] = useState<Session | null>(() => knownSession ?? null);
  const [booting, setBooting] = useState(() => Boolean(supabase && knownSession === undefined));
  const [checkError, setCheckError] = useState(false);
  const [checkAttempt, setCheckAttempt] = useState(0);

  useEffect(() => {
    if (!supabase) {
      router.replace("/welcome");
      return;
    }
    let mounted = true;
    // INITIAL_SESSION can be null during a failed startup check. Wait for
    // getSession() to finish before deciding that this device signed out.
    // An explicit SIGNED_OUT or subsequent auth change still takes priority.
    let newerAuthEvent = false;

    function route(nextSession: Session | null) {
      if (!mounted) return;
      cacheBrowserSession(nextSession);
      setSession(nextSession);
      setBooting(false);
      setCheckError(false);
      if (!nextSession) router.replace("/welcome");
    }

    function onCheckError() {
      if (!mounted || newerAuthEvent) return;
      // Network/refresh errors are not proof of sign-out. Keep an already
      // painted Home session and offer retry on an actual cold launch.
      if (getCachedBrowserSession()) {
        setBooting(false);
        return;
      }
      setCheckError(true);
      setBooting(false);
    }

    const { data: subscription } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (event === "INITIAL_SESSION") return;
      newerAuthEvent = true;
      route(nextSession);
    });

    // Unlike a successful null session, an error must never silently send
    // an already-signed-in iPhone user back to the login form.
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!mounted || newerAuthEvent) return;
      if (error) {
        onCheckError();
        return;
      }
      route(data.session);
    }).catch(onCheckError);

    return () => {
      mounted = false;
      subscription.subscription.unsubscribe();
    };
  }, [supabase, router, checkAttempt]);

  if (checkError && !session) {
    return (
      <main className="route-state">
        <h1>WYNOS</h1>
        <p role="alert">ตรวจสอบการเข้าสู่ระบบไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่</p>
        <button className="route-primary" type="button" onClick={() => {
          setBooting(true);
          setCheckError(false);
          setCheckAttempt((attempt) => attempt + 1);
        }}>ลองใหม่</button>
      </main>
    );
  }
  if (booting || !session) return <main className="parity-auth parity-auth-loading"><LoaderCircle className="parity-spinner" /></main>;
  return <HomeScreen session={session} />;
}
