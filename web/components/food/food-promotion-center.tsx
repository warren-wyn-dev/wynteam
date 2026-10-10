"use client";

import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { subscribeToPushNotifications, pushReasonDescription } from "@/lib/push-notifications";
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
    if (push && !pushMarketing) {
      const device = await subscribeToPushNotifications(client,userId);
      if (!device.ok) {
        setNotice(pushReasonDescription(device.reason));
        setBusy(false);
        return;
      }
    }
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

  return <section className="fx-promo-center" aria-label="โปรโมชัน WYNOS Food">
    <button type="button" className="fx-promo-center-toggle" onClick={() => setOpen(p => !p)} aria-expanded={open}>
      {unread ? <BellRing size={20} /> : <Bell size={20} />}
      <span>โปรโมชันและข่าวสาร</span>
      {unread > 0 ? <i aria-label={`${unread} ข้อความใหม่`}>{unread}</i> : null}
      <small>{open ? "ปิด" : "ดูทั้งหมด"}</small>
    </button>
    {open && <div className="fx-promo-center-body">
      {rows.length === 0 ? <p className="fx-empty-line">ยังไม่มีข้อความโปรโมชัน</p> :
        rows.map(row => <article key={row.id} className="fx-promo-item">
          <button type="button" onClick={() => void markRead(row)}>
            <strong>{!row.read_at ? <i aria-label="ยังไม่อ่าน" /> : null}{row.title}</strong>
            <p>{row.body}</p>
            <small>{new Date(row.created_at).toLocaleDateString("th-TH")}</small>
          </button>
          {row.coupon_code && <button type="button" className="fx-btn fx-btn--outline fx-btn--sm"
            onClick={() => void applyPromoCode(row)}><Copy size={14}/>{row.coupon_code} · ใช้โค้ดนี้</button>}
        </article>)}
      <div className="fx-promo-settings">
        <strong>ตั้งค่าการรับโปรโมชัน</strong>
        <label>
          ข่าวสารภายใน WYNOS Food
          <input type="checkbox" disabled={busy} checked={inAppMarketing}
            onChange={e => void preferences(pushMarketing,e.target.checked)} />
        </label>
        <label>
          Push โปรโมชั่น (ไม่รวมแจ้งเตือนออเดอร์)
          <input type="checkbox" disabled={busy} checked={pushMarketing}
            onChange={e => void preferences(e.target.checked,inAppMarketing)} />
        </label>
        <p>การปิดโปรโมชันไม่กระทบการแจ้งเตือนคำสั่งซื้อของร้านค้า</p>
      </div>
      {notice && <p role="status" className="fx-promo-notice"><Check size={14}/>{notice}</p>}
    </div>}
  </section>;
}
