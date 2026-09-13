"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";

import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

type GateState = "loading" | "missing-config" | "signed-out" | "regular" | "developer" | "error";

export type DeveloperRouteContext = {
  client: SupabaseClient;
  session: Session;
  userId: string;
  signOut: () => Promise<void>;
};

export function DeveloperRouteGate({
  children,
}: {
  children: (context: DeveloperRouteContext) => React.ReactNode;
}) {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [gate, setGate] = useState<GateState>(() =>
    hasSupabaseBrowserConfig() ? "loading" : "missing-config",
  );
  const [session, setSession] = useState<Session | null>(null);
  const [message, setMessage] = useState("");

  const checkSession = useCallback(async (nextSession: Session | null) => {
    setSession(nextSession);
    setMessage("");
    if (!hasSupabaseBrowserConfig() || !client) {
      setGate("missing-config");
      return;
    }
    if (!nextSession) {
      setGate("signed-out");
      return;
    }
    setGate("loading");
    try {
      const result = await client.rpc("is_developer_account");
      setGate(!result.error && result.data === true ? "developer" : "regular");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "เปิด Web รุ่นใหม่ไม่สำเร็จ");
      setGate("error");
    }
  }, [client]);

  useEffect(() => {
    if (!client) return;
    let mounted = true;
    void client.auth.getSession().then(({ data }) => {
      if (mounted) void checkSession(data.session);
    });
    const { data } = client.auth.onAuthStateChange((_event, nextSession) => {
      if (mounted) void checkSession(nextSession);
    });
    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [checkSession, client]);

  const signIn = useCallback(async () => {
    if (!client) return;
    const result = await client.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.href },
    });
    if (result.error) {
      setMessage("เริ่มเข้าสู่ระบบไม่สำเร็จ");
      setGate("error");
    }
  }, [client]);

  const signOut = useCallback(async () => {
    if (client) await client.auth.signOut();
  }, [client]);

  if (gate === "loading") {
    return <main className="route-state"><h1>WYNOS</h1><p>กำลังโหลด…</p></main>;
  }
  if (gate === "missing-config") {
    return <main className="route-state"><h1>WYNOS</h1><p>ยังไม่ได้ตั้งค่า Supabase สำหรับ Web รุ่นใหม่</p></main>;
  }
  if (gate === "signed-out") {
    return (
      <main className="route-state">
        <h1>WYNOS</h1>
        <p>เข้าสู่ระบบเพื่อใช้งาน Web รุ่นใหม่</p>
        <button className="route-primary" type="button" onClick={() => void signIn()}>เข้าสู่ระบบด้วย Google</button>
      </main>
    );
  }
  if (gate === "regular") {
    return (
      <main className="route-state">
        <h1>WYNOS</h1>
        <p>Web รุ่นใหม่นี้ยังเปิดเฉพาะบัญชีนักพัฒนาในช่วงย้ายระบบ</p>
        <button className="route-secondary" type="button" onClick={() => void signOut()}>ออกจากระบบ</button>
      </main>
    );
  }
  if (gate === "error" || !client || !session) {
    return (
      <main className="route-state">
        <h1>WYNOS</h1>
        <p>{message || "เกิดข้อผิดพลาด"}</p>
        <button className="route-primary" type="button" onClick={() => void checkSession(session)}>ลองใหม่</button>
      </main>
    );
  }

  return <>{children({ client, session, userId: session.user.id, signOut })}</>;
}
