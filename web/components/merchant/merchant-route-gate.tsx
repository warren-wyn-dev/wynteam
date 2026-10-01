"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";

import { fetchMerchantIdentity } from "@/lib/merchant-account";
import {
  getMerchantSupabaseBrowserClient,
  hasMerchantBrowserConfig,
} from "@/lib/supabase/merchant-browser";

type MerchantGateContext = {
  client: SupabaseClient;
  session: Session;
  userId: string;
  signOut: () => Promise<void>;
};

type GateState = "loading" | "ready" | "signed-out" | "invalid" | "missing-config" | "error";

export function MerchantRouteGate({
  children,
}: {
  children: (context: MerchantGateContext) => React.ReactNode;
}) {
  const client = useMemo(() => getMerchantSupabaseBrowserClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [state, setState] = useState<GateState>(() => hasMerchantBrowserConfig() ? "loading" : "missing-config");

  const validate = useCallback(async (nextSession: Session | null) => {
    if (!client || !nextSession) {
      setSession(null);
      setState("signed-out");
      return;
    }
    try {
      const identity = await fetchMerchantIdentity(client, nextSession.user.id);
      if (!identity?.active || identity.identity_mode !== "merchant") {
        await client.auth.signOut();
        setSession(null);
        setState("invalid");
        return;
      }
      setSession(nextSession);
      setState("ready");
    } catch {
      setState("error");
    }
  }, [client]);

  useEffect(() => {
    if (!client) return;
    let mounted = true;

    void client.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;
      if (error) {
        setState("error");
        return;
      }
      void validate(data.session);
    });

    const { data } = client.auth.onAuthStateChange((event, nextSession) => {
      if (!mounted || event === "INITIAL_SESSION") return;
      void validate(nextSession);
    });

    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [client, validate]);

  useEffect(() => {
    if (state === "signed-out" || state === "invalid") {
      window.location.replace("/merchant/login");
    }
  }, [state]);

  const signOut = useCallback(async () => {
    if (!client) return;
    await client.auth.signOut();
    window.location.replace("/merchant/login");
  }, [client]);

  if (state === "loading" || state === "signed-out" || state === "invalid") {
    return <main className="wm-loading"><div className="wm-loader" /><strong>WYNOS <b>Merchant</b></strong></main>;
  }
  if (state === "missing-config") {
    return <main className="wm-blocked"><h1>WYNOS Merchant</h1><p>ยังไม่ได้ตั้งค่าการเชื่อมต่อระบบ</p></main>;
  }
  if (state === "error" || !client || !session) {
    return <main className="wm-blocked"><h1>WYNOS Merchant</h1><p>ตรวจสอบบัญชี Merchant ไม่สำเร็จ กรุณาลองใหม่</p></main>;
  }

  return <>{children({ client, session, userId: session.user.id, signOut })}</>;
}
