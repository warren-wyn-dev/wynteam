"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

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
 */
export function DeveloperRouteGate({
  children,
}: {
  children: (context: DeveloperRouteContext) => React.ReactNode;
}) {
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [gate, setGate] = useState<GateState>(() =>
    hasSupabaseBrowserConfig() ? "loading" : "missing-config",
  );
  const [session, setSession] = useState<Session | null>(null);
  const [message, setMessage] = useState("");

  const acceptSession = useCallback((nextSession: Session | null) => {
    setSession(nextSession);
    setMessage("");
    if (!hasSupabaseBrowserConfig() || !client) {
      setGate("missing-config");
      return;
    }
    setGate(nextSession ? "ready" : "signed-out");
  }, [client]);

  useEffect(() => {
    if (!client) return;
    let mounted = true;
    void client.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;
      if (error) {
        setMessage("เปิด WYNOS ไม่สำเร็จ กรุณาลองใหม่");
        setGate("error");
        return;
      }
      acceptSession(data.session);
    });
    const { data } = client.auth.onAuthStateChange((_event, nextSession) => {
      if (mounted) acceptSession(nextSession);
    });
    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [acceptSession, client]);

  useEffect(() => {
    if (gate === "signed-out") router.replace("/");
  }, [gate, router]);

  const signOut = useCallback(async () => {
    if (!client) return;
    await client.auth.signOut();
    router.replace("/");
  }, [client, router]);

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
        <button className="route-primary" type="button" onClick={() => window.location.reload()}>ลองใหม่</button>
      </main>
    );
  }

  return <>{children({ client, session, userId: session.user.id, signOut })}</>;
}
