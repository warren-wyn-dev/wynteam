"use client";

import type { Session } from "@supabase/supabase-js";
import { LoaderCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { HomeScreen } from "@/components/home/home-screen";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

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
export function ParityAuthEntry() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const router = useRouter();
  const [session, setSession] = useState<Session | null>(null);
  const [booting, setBooting] = useState(() => Boolean(supabase));

  useEffect(() => {
    if (!supabase) {
      router.replace("/welcome");
      return;
    }
    let mounted = true;

    function route(nextSession: Session | null) {
      if (!mounted) return;
      setSession(nextSession);
      setBooting(false);
      if (!nextSession) router.replace("/welcome");
    }

    void supabase.auth.getSession().then(({ data }) => route(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => route(nextSession));
    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [supabase, router]);

  if (booting || !session) return <main className="parity-auth parity-auth-loading"><LoaderCircle className="parity-spinner" /></main>;
  return <HomeScreen session={session} />;
}
