"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";

type MerchantStoreChoice = { id: string; name: string };
function MerchantLineConnectForm({ client, userId }: { client: SupabaseClient; userId: string }) {
  const [token, setToken] = useState("");
  const [stores, setStores] = useState<MerchantStoreChoice[]>([]);
  const [storeId, setStoreId] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [connected, setConnected] = useState<boolean | null>(null);

  useEffect(() => {
    let mounted = true;
    void (async () => {
      try {
        const currentUrl = new URL(window.location.href);
        const tokenInUrl = currentUrl.searchParams.get("linkToken") ?? "";
        // Remove the one-time LINE token from history and shared URLs immediately.
        currentUrl.searchParams.delete("linkToken");
        window.history.replaceState(window.history.state, "", currentUrl.pathname + currentUrl.search + currentUrl.hash);
        if (mounted) setToken(/^[A-Za-z0-9_-]{16,255}$/.test(tokenInUrl) ? tokenInUrl : "");
        // Fetch only grants for the signed-in account. Store membership is
        // rechecked inside the server Edge Function before saving nonce.
        const [memberships, staff] = await Promise.all([
          client.from("merchant_memberships").select("merchant_account_id")
            .eq("user_id", userId).eq("active", true),
          client.from("food_staff").select("store_id")
            .eq("user_id", userId).eq("active", true),
        ]);
        if (memberships.error || staff.error) throw new Error("merchant_grants_unavailable");
        const accounts = [...new Set((memberships.data ?? []).map((m) => m.merchant_account_id).filter(Boolean))];
        const directStoreIds = [...new Set((staff.data ?? []).map((s) => s.store_id).filter(Boolean))];
        const tasks: PromiseLike<{data: MerchantStoreChoice[] | null; error: unknown}>[] = [];
        if (accounts.length) tasks.push(client.from("food_stores").select("id,name").in("merchant_account_id",accounts) as never);
        if (directStoreIds.length) tasks.push(client.from("food_stores").select("id,name").in("id",directStoreIds) as never);
        const rows = await Promise.all(tasks);
        if (!mounted) return;
        if (rows.some((row) => row.error)) throw new Error("store_read_failed");
        const found = new Map<string, MerchantStoreChoice>();
        rows.forEach((row) => (row.data ?? []).forEach((store) => found.set(store.id, store)));
        const allowedStores = [...found.values()].sort((a,b) => a.name.localeCompare(b.name, "th"));
        setStores(allowedStores);
        setStoreId(allowedStores[0]?.id ?? "");
      } catch {
        if (mounted) setNotice("โหลดรายชื่อร้านไม่ได้ กรุณาเข้าสู่ระบบร้านค้าอีกครั้ง");
      } finally {
        if (mounted) setLoaded(true);
      }
    })();
    return () => { mounted = false; };
  }, [client, userId]);

  useEffect(() => {
    let active = true;
    if (!storeId) return;
    void client.functions.invoke("zoky-line-account", {
      body: { action: "status", storeId },
    }).then(({ data, error }) => {
      if (active) setConnected(!error && typeof data?.connected === "boolean" ? data.connected : null);
    }).catch(() => { if (active) setConnected(null); });
    return () => { active = false; };
  }, [client, storeId]);

  async function unlink() {
    if (!storeId || !connected || busy || !window.confirm("ยกเลิกการเชื่อมบัญชี LINE ของร้านนี้?")) return;
    setBusy(true);
    setNotice("");
    try {
      const { data, error } = await client.functions.invoke("zoky-line-account", {
        body: { action: "unlink", storeId },
      });
      if (error || data?.ok !== true) throw new Error("unlink_failed");
      setConnected(false);
      setNotice("ยกเลิกการเชื่อมบัญชี LINE แล้ว");
    } catch {
      setNotice("ยกเลิกการเชื่อม LINE ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
    } finally {
      setBusy(false);
    }
  }

  async function beginLink() {
    if (!storeId || !token || busy) return;
    setBusy(true);
    setNotice("");
    try {
      const { data, error } = await client.functions.invoke("zoky-line-account", {
        body: { action: "begin", storeId, linkToken: token },
      });
      if (error || typeof data?.redirectUrl !== "string") throw new Error("link_failed");
      const redirect = new URL(data.redirectUrl);
      if (redirect.origin !== "https://access.line.me" || redirect.pathname !== "/dialog/bot/accountLink") throw new Error("unsafe_redirect");
      window.location.assign(redirect.toString());
    } catch {
      setNotice("ยังเชื่อมต่อไม่ได้ กรุณาตรวจสอบสิทธิ์ร้านค้าและลิงก์ LINE หรือขอลิงก์ใหม่จาก LINE OA");
      setBusy(false);
    }
  }

  return (
    <main style={{ minHeight: "100dvh", background: "#fff", color: "#242424", padding: "24px 20px", fontFamily: "system-ui,sans-serif" }}>
      <section style={{ maxWidth: 460, margin: "35px auto" }}>
        <Link href="/merchant" style={{ color: "#444" }}>‹ กลับไปยัง Zoky Merchant</Link>
        <h1 style={{ fontSize: 26, marginTop: 32 }}>เชื่อมบัญชี LINE</h1>
        <p style={{ lineHeight: 1.7, color: "#666" }}>เลือกบัญชีร้านค้าที่ต้องการรับแจ้งเตือนออเดอร์ผ่าน LINE ของคุณ</p>
        {!token ? <p role="alert">ไม่พบลิงก์เชื่อมบัญชีที่ถูกต้อง โปรดพิมพ์ “เชื่อมบัญชี” ในแชต Zoky Merchant OA เพื่อรับลิงก์ใหม่</p> : null}
        <label style={{ display: "block", marginTop: 28, fontWeight: 600 }} htmlFor="zoky-line-store">บัญชีร้านค้า</label>
        <select id="zoky-line-store" value={storeId} onChange={(event) => setStoreId(event.target.value)}
          disabled={!loaded || busy} style={{ width: "100%", marginTop: 10, padding: 14, border: "1px solid #ddd", borderRadius: 12, background: "#fff", color: "#222" }}>
          {stores.length ? stores.map((store) => <option key={store.id} value={store.id}>{store.name}</option>) : <option value="">ไม่มีร้านค้าที่ได้รับสิทธิ์</option>}
        </select>
        <p style={{ fontSize: 13, lineHeight: 1.7, color: "#666" }}>บัญชี LINE จะใช้รับการแจ้งเตือนออเดอร์ของร้านนี้ คุณสามารถยกเลิกการเชื่อมได้ทุกเมื่อใน Zoky Merchant</p>
        <p role="status" style={{ fontSize: 14, color: connected === true ? "#067647" : "#666" }}>
          {connected === true ? "เชื่อมต่อ LINE แล้ว" : connected === false ? "ยังไม่ได้เชื่อม LINE" : "กำลังตรวจสอบการเชื่อมต่อ"}
        </p>
        {connected === true ? <button type="button" disabled={busy} onClick={() => void unlink()}
          style={{ background: "#fff", color: "#C62828", width: "100%", padding: 13, marginBottom: 12, border: "1px solid #ddd", borderRadius: 12 }}>
          ยกเลิกการเชื่อม LINE
        </button> : null}
        <button type="button" disabled={!token || !storeId || !loaded || busy} onClick={() => void beginLink()}
          style={{ background: "#F93384", color: "#fff", width: "100%", padding: 15, border: 0, borderRadius: 12, fontWeight: 650, opacity: !token || !storeId || !loaded || busy ? 0.5 : 1 }}>
          {busy ? "กำลังเชื่อมต่อ…" : "ยืนยันและเชื่อมต่อ LINE"}
        </button>
        {notice ? <p role="alert" style={{ marginTop: 18, color: "#C62828" }}>{notice}</p> : null}
      </section>
    </main>
  );
}
export default function MerchantLineConnectPage() {
  return (
    <DeveloperRouteGate signedOutPath="/merchant/login">
      {({ client, userId }) => <MerchantLineConnectForm client={client} userId={userId} />}
    </DeveloperRouteGate>
  );
}
