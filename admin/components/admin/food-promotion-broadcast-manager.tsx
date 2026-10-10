"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export type CouponChoice = { id: string; code: string; is_active: boolean; campaign_name: string };
export type BroadcastRow = {
  id: string; title: string; body: string; audience: string; scheduled_at: string;
  state: string; coupon_code: string | null; coupon_id: string | null;
  inbox_count: number; push_sent: number; push_failed: number;
};
const field = "w-full rounded-lg border bg-background px-3 py-2 text-sm";

export function FoodPromotionBroadcastManager({ canManage, coupons, initialRows, schedulerState }: {
  canManage: boolean; coupons: CouponChoice[]; initialRows: BroadcastRow[];
  schedulerState: "active" | "paused" | "unknown";
}) {
  const router = useRouter();
  const [pending, begin] = useTransition();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [couponId, setCouponId] = useState("");
  const [audience, setAudience] = useState<"all" | "returning">("all");
  const [scheduleAt, setScheduleAt] = useState("");
  const [rows, setRows] = useState(initialRows);
  const [feedback, setFeedback] = useState("");
  const schedulerActive = schedulerState === "active";

  const refresh = async () => {
    const { data, error } = await createClient().rpc("admin_food_promo_list");
    if (error) throw error;
    setRows(Array.isArray(data) ? data as BroadcastRow[] : []);
    router.refresh();
  };

  const schedule = () => begin(async () => {
    setFeedback("");
    if (!schedulerActive) {
      setFeedback("ระบบส่งโปรโมชันอัตโนมัติยังไม่พร้อม กรุณาตรวจ Scheduler ก่อนตั้งคิว");
      return;
    }
    try {
      const { error } = await createClient().rpc("admin_food_promo_schedule", {
        p_title: title.trim(), p_body: body.trim(), p_coupon_id: couponId || null,
        p_audience: audience,
        p_scheduled_at: scheduleAt ? new Date(scheduleAt).toISOString() : null,
      });
      if (error) throw error;
      await refresh();
      setTitle(""); setBody(""); setCouponId(""); setScheduleAt("");
      setFeedback("บันทึกเข้าคิวแล้ว โดย Scheduler ที่เปิดอยู่จะรับไปประมวลผลตามเวลา");
    } catch (e) {
      const message = e instanceof Error ? e.message : "สร้างแคมเปญไม่สำเร็จ";
      setFeedback(message.includes("food_promo_scheduler_disabled")
        ? "Scheduler ถูกปิดระหว่างบันทึก จึงไม่มีการเพิ่มข้อความเข้าคิว กรุณารีเฟรชหน้า"
        : message);
    }
  });
  const cancel = (id: string) => begin(async () => {
    setFeedback("");
    try {
      const { error } = await createClient().rpc("admin_food_promo_cancel", { p_broadcast_id: id });
      if (error) throw error;
      await refresh();
    } catch (e) { setFeedback(e instanceof Error ? e.message : "ยกเลิกไม่สำเร็จ"); }
  });

  return <div className="flex flex-col gap-5">
    <div className="rounded-lg border p-4 text-sm" role="status">
      <p className="font-semibold">
        สถานะ Scheduler: {schedulerState === "active" ? "เปิดใช้งาน" : schedulerState === "paused" ? "ปิดอยู่" : "ยังตรวจสอบไม่ได้"}
      </p>
      {!schedulerActive && <p className="mt-1 text-muted-foreground">
        ไม่สามารถตั้งคิวแจ้งเตือนโปรโมชันใหม่ได้จนกว่า Scheduler จะเปิดและตรวจสอบสถานะสำเร็จ
        รายการที่อยู่ในคิวเดิมจะยังไม่ถูกส่งอัตโนมัติเมื่อ Scheduler ปิด
      </p>}
    </div>
    {canManage && <section className="rounded-xl border p-4">
      <h2 className="font-semibold">สร้างข้อความโปรโมชัน</h2>
      <p className="my-2 text-sm text-muted-foreground">
        แนะนำให้ทดสอบกับบัญชีที่อนุญาตรับ Push การตลาดก่อนส่งวงกว้าง ระบบจำกัดความถี่ 3 ครั้ง/7 วัน
      </p>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="text-sm sm:col-span-2">หัวข้อ (3–90 ตัวอักษร)
          <input className={field} value={title} maxLength={90} onChange={e => setTitle(e.target.value)}
            placeholder="🎉 โปรโมชัน WYNOS Food" />
        </label>
        <label className="text-sm sm:col-span-2">รายละเอียด (5–260 ตัวอักษร)
          <textarea className={field} rows={3} value={body} maxLength={260}
            onChange={e => setBody(e.target.value)} placeholder="ใช้โค้ดส่วนลดวันนี้" />
        </label>
        <label className="text-sm">โค้ดส่วนลดแนบ (ไม่บังคับ)
          <select className={field} value={couponId} onChange={e => setCouponId(e.target.value)}>
            <option value="">ประกาศทั่วไป</option>
            {coupons.map(c => <option key={c.id} value={c.id}>{c.code} · {c.campaign_name}</option>)}
          </select>
        </label>
        <label className="text-sm">กลุ่มผู้รับ
          <select className={field} value={audience} onChange={e => setAudience(e.target.value as "all" | "returning")}>
            <option value="all">ลูกค้า Food ที่รู้จัก</option>
            <option value="returning">ลูกค้าที่เคยมีออเดอร์</option>
          </select>
        </label>
        <label className="text-sm sm:col-span-2">กำหนดเวลาส่ง (ไม่เลือก = เข้าคิวทันที)
          <input className={field} type="datetime-local" value={scheduleAt}
            onChange={e => setScheduleAt(e.target.value)} />
        </label>
      </div>
      <div className="mt-3 rounded-lg bg-muted p-4">
        <div className="text-xs text-muted-foreground">ตัวอย่างข้อความที่จะได้รับ</div>
        <p className="mt-1 font-semibold">{title || "โปรโมชัน WYNOS Food"}</p>
        <p className="text-sm">{body || "รายละเอียดโปรโมชัน"}</p>
        <p className="mt-2 text-xs">เป้าหมาย Push: Food เท่านั้น · ไม่มี Email</p>
      </div>
      <button className="mt-4 rounded-lg bg-foreground px-4 py-2 text-background disabled:opacity-40"
        disabled={!schedulerActive || pending || title.trim().length < 3 || body.trim().length < 5}
        type="button" onClick={schedule}>บันทึกและเข้าคิวส่ง</button>
    </section>}
    {feedback && <p role="status" className="rounded-lg border p-3 text-sm">{feedback}</p>}
    <section className="rounded-xl border p-4">
      <h2 className="font-semibold">ประวัติการส่ง</h2>
      {rows.length === 0 && <p className="mt-3 text-sm text-muted-foreground">ยังไม่มีแคมเปญแจ้งเตือน</p>}
      <div className="divide-y">
        {rows.map(row => <div className="flex flex-wrap items-center justify-between gap-3 py-3" key={row.id}>
          <div className="max-w-lg">
            <strong>{row.title}</strong>
            <p className="text-sm text-muted-foreground">{row.body}</p>
            <p className="text-xs text-muted-foreground">
              {row.coupon_code ? `โค้ด ${row.coupon_code} · ` : ""}
              {row.state} · In-App {row.inbox_count} · Push {row.push_sent} · ผิดพลาด {row.push_failed}
            </p>
          </div>
          {canManage && row.state === "queued" &&
            <button type="button" disabled={pending} className="rounded-lg border px-3 py-2 text-sm"
              onClick={() => cancel(row.id)}>ยกเลิกก่อนส่ง</button>}
        </div>)}
      </div>
    </section>
  </div>;
}
