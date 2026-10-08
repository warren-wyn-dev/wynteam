"use client";

import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { Bell, BellRing, Copy, Check } from "lucide-react";

type Notification = {
  id: string; title: string; body: string; coupon_code: string | null;
  created_at: string; read_at: string | null;
};

export function FoodPromotionCenter({ client, userId }: { client: SupabaseClient; userId: string }) {
  const [open, setOpen] = useState(false);
  const [rows, setRows] = useState<Notification[]>([]);
  const [pushMarketing, setPushMarketing] = useState(false);
  const [inAppMarketing, setInAppMarketing] = useState(true);
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const unread = rows.filter(n => !n.read_at).length;

  useEffect(() => {
    let active = true;
    void Promise.all([
      client.from("food_notifications").select("id,title,body,coupon_code,created_at,read_at")
        .eq("recipient_id", userId).order("created_at", { ascending: false }).limit(30),
      client.from("food_marketing_preferences")
        .select("push_marketing,in_app_marketing").eq("user_id", userId).maybeSingle(),
    ]).then(([inbox, prefs]) => {
      if (!active) return;
      if (!inbox.error) setRows((inbox.data ?? []) as Notification[]);
      if (!prefs.error && prefs.data) {
        setPushMarketing(prefs.data.push_marketing === true);
        setInAppMarketing(prefs.data.in_app_marketing !== false);
      }
    }).catch(() => undefined);
    return () => { active = false; };
  }, [client, userId]);

  const markRead = async (n: Notification) => {
    if (!n.read_at) {
      const read_at = new Date().toISOString();
      const { error } = await client.from("food_notifications").update({ read_at }).eq("id", n.id).eq("recipient_id", userId);
      if (!error) setRows(current => current.map(row => row.id === n.id ? { ...row, read_at } : row));
    }
  };

  const preferences = async (push: boolean, inApp: boolean) => {
    setBusy(true); setNotice("");
    const { error } = await client.from("food_marketing_preferences").upsert({
      user_id: userId, push_marketing: push, in_app_marketing: inApp, updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    setBusy(false);
    if (error) setNotice("บันทึกการตั้งค่าไม่สำเร็จ กรุณาลองใหม่");
    else { setPushMarketing(push); setInAppMarketing(inApp); setNotice("บันทึกการตั้งค่าแล้ว"); }
  };

  const applyPromoCode = async (n: Notification) => {
    if (!n.coupon_code) return;
    const code = n.coupon_code;
    try { window.localStorage.setItem("wynos-food-promo-code-v1", code); } catch { /* private mode */ }
    try { await navigator.clipboard.writeText(code); } catch { /* clipboard may be blocked */ }
    setNotice(`บันทึกโค้ด ${code} แล้ว เปิดตะกร้าเพื่อใช้ส่วนลด`);
    await markRead(n);
  };

  return <section className="mx-3 mb-3 rounded-2xl border bg-background p-3" aria-label="โปรโมชัน WYNOS Food">
    <button type="button" className="flex w-full items-center justify-between gap-3 text-left"
      onClick={() => setOpen(p => !p)} aria-expanded={open}>
      <span className="flex items-center gap-2 font-semibold">
        {unread ? <BellRing size={19} /> : <Bell size={19} />}
        โปรโมชันและข่าวสาร {unread > 0 && <span className="rounded-full bg-red-600 px-2 py-0.5 text-xs text-white">{unread}</span>}
      </span>
      <span className="text-sm text-muted-foreground">{open ? "ปิด" : "ดูทั้งหมด"}</span>
    </button>
    {open && <div className="mt-3 space-y-3">
      {rows.length === 0 ? <p className="text-sm text-muted-foreground">ยังไม่มีข้อความโปรโมชัน</p> :
        rows.map(row => <article key={row.id} className="rounded-lg border p-3">
          <button type="button" className="w-full text-left" onClick={() => void markRead(row)}>
            <div className="flex items-center justify-between gap-2">
              <strong>{row.title}</strong>
              {!row.read_at && <span className="h-2 w-2 rounded-full bg-red-600" />}
            </div>
            <p className="mt-1 text-sm">{row.body}</p>
            <small className="text-muted-foreground">{new Date(row.created_at).toLocaleDateString("th-TH")}</small>
          </button>
          {row.coupon_code && <button type="button" className="mt-2 flex items-center gap-2 rounded-lg border px-3 py-2 text-sm"
            onClick={() => void applyPromoCode(row)}><Copy size={14}/>{row.coupon_code} · ใช้โค้ดนี้</button>}
        </article>)}
      <div className="space-y-2 rounded-lg bg-muted p-3">
        <strong className="text-sm">ตั้งค่าการรับโปรโมชัน</strong>
        <label className="flex items-center justify-between gap-2 text-sm">
          ข่าวสารภายใน WYNOS Food
          <input type="checkbox" disabled={busy} checked={inAppMarketing}
            onChange={e => void preferences(pushMarketing,e.target.checked)} />
        </label>
        <label className="flex items-center justify-between gap-2 text-sm">
          Push โปรโมชั่น (ไม่รวมแจ้งเตือนออเดอร์)
          <input type="checkbox" disabled={busy} checked={pushMarketing}
            onChange={e => void preferences(e.target.checked,inAppMarketing)} />
        </label>
        <p className="text-xs text-muted-foreground">การปิดโปรโมชันไม่กระทบการแจ้งเตือนคำสั่งซื้อของร้านค้า</p>
      </div>
      {notice && <p role="status" className="flex items-center gap-1 text-sm"><Check size={14}/>{notice}</p>}
    </div>}
  </section>;
}
