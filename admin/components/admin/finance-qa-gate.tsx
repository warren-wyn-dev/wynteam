"use client";
import { useEffect, useState, type FormEvent } from "react";
import { createClient } from "@/lib/supabase/client";
import { FinanceOperationsPanel } from "./finance-operations-panel";
type Access = { user_id: string; can_view: boolean; can_edit: boolean };
export function FinanceQaGate() {
  const [client] = useState(createClient); const [access, setAccess] = useState<Access | null>(null);
  const [email, setEmail] = useState(""); const [password, setPassword] = useState("");
  const [message, setMessage] = useState(""); const [busy, setBusy] = useState(false);
  const check = async () => { const user = await client.auth.getUser(); if (!user.data.user) return;
    const result = await client.rpc("food_finance_admin_access");
    if (result.error || result.data?.can_view !== true) setMessage("บัญชีนี้ยังไม่มีสิทธิ์ผู้ดูแลการเงิน Sandbox");
    else { setAccess(result.data); setMessage(""); }
  };
  useEffect(() => { let live = true; void client.auth.getUser().then(async ({ data }) => {
    if (!live || !data.user) return; const result = await client.rpc("food_finance_admin_access");
    if (!live) return; if (!result.error && result.data?.can_view === true) setAccess(result.data);
    else setMessage("บัญชีนี้ยังไม่มีสิทธิ์ผู้ดูแลการเงิน Sandbox");
  }); return () => { live = false; }; }, [client]);
  useEffect(() => { const { data } = client.auth.onAuthStateChange((event) => {
    if (event === "SIGNED_OUT" || event === "SIGNED_IN") setAccess(null);
  }); return () => data.subscription.unsubscribe(); }, [client]);
  const login = async (event: FormEvent) => { event.preventDefault(); setBusy(true); try {
    const result = await client.auth.signInWithPassword({ email: email.trim(), password });
    if (result.error) { setMessage("เข้าสู่ระบบไม่สำเร็จ ตรวจอีเมลและรหัสผ่าน"); return; }
    setPassword(""); await check();
  } finally { setBusy(false); } };
  return access ? <><button type="button" onClick={async () => { await client.auth.signOut(); setAccess(null); }}>ออกจากบัญชีผู้ดูแล</button><FinanceOperationsPanel userId={access.user_id} canEdit={access.can_edit} /></>
    : <form onSubmit={(e) => void login(e)} className="max-w-md space-y-4"><p>ใช้บัญชีทดสอบที่ได้รับสิทธิ์ผู้ดูแลการเงินเท่านั้น การปรับยอดต้องมีผู้ตรวจคนละบัญชี</p><label className="block">อีเมล<input className="block w-full border p-2" type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} /></label><label className="block">รหัสผ่าน<input className="block w-full border p-2" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} /></label><button type="submit" disabled={busy}>เข้าสู่ระบบ Sandbox</button><p role="status">{message}</p></form>;
}
