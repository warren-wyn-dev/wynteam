"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Campaign = { id: string; name: string; starts_at: string; ends_at: string | null; joined_stores: number; delivered_orders: number };
export type FoodCouponRow = {
  id: string; code: string; campaign_id: string; campaign_name: string; is_active: boolean;
  starts_at: string; ends_at: string | null; max_total_uses: number | null;
  max_uses_per_user: number; used: number;
};

const inputStyle = "w-full rounded-lg border bg-background px-3 py-2 text-sm";

export function FoodCouponManager({ canManage, campaigns, initialCoupons }: {
  canManage: boolean; campaigns: Campaign[]; initialCoupons: FoodCouponRow[];
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [campaign, setCampaign] = useState(campaigns[0]?.id ?? "");
  const [code, setCode] = useState("");
  const [totalLimit, setTotalLimit] = useState("");
  const [perUser, setPerUser] = useState("1");
  const [feedback, setFeedback] = useState("");
  const [rows, setRows] = useState(initialCoupons);

  const readRows = async () => {
    const { data, error } = await createClient().rpc("admin_food_coupon_list");
    if (error) throw error;
    setRows(Array.isArray(data) ? data as FoodCouponRow[] : []);
  };

  const issue = () => start(async () => {
    setFeedback("");
    const chosen = campaigns.find(c => c.id === campaign);
    if (!chosen) { setFeedback("กรุณาเลือกแคมเปญ"); return; }
    try {
      const { error } = await createClient().rpc("admin_food_issue_coupon", {
        p_campaign_id: campaign, p_code: code.trim().toUpperCase(),
        p_max_total_uses: totalLimit ? Number(totalLimit) : null,
        p_max_uses_per_user: Number(perUser),
        p_starts_at: chosen.starts_at,
        p_ends_at: chosen.ends_at,
      });
      if (error) throw error;
      await readRows();
      setCode("");
      setFeedback("ออกโค้ดสำเร็จ ข้อกำหนด Coupon-only จะมีผลกับแคมเปญนี้ทันที");
      router.refresh();
    } catch (e) {
      setFeedback(e instanceof Error ? e.message : "บันทึกโค้ดไม่สำเร็จ");
    }
  });

  const toggle = (row: FoodCouponRow) => start(async () => {
    setFeedback("");
    try {
      const { error } = await createClient().rpc("admin_food_coupon_set_active", {
        p_coupon_id: row.id, p_active: !row.is_active,
      });
      if (error) throw error;
      await readRows();
    } catch (e) { setFeedback(e instanceof Error ? e.message : "เปลี่ยนสถานะไม่สำเร็จ"); }
  });

  return <div className="flex flex-col gap-5">
    {canManage && <section className="rounded-xl border p-4">
      <h2 className="font-semibold">ออกโค้ดใหม่</h2>
      <p className="my-2 text-sm text-muted-foreground">
        แนะนำสร้างแคมเปญใหม่ที่ยังไม่มีออเดอร์ใช้งาน และกำหนดวันเริ่มในอนาคตก่อนออกโค้ด
        เพื่อป้องกันเปลี่ยนโปรโมชันเดิมที่ลูกค้าเคยได้รับ
      </p>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="text-sm">แคมเปญ WYNOS
          <select className={inputStyle} value={campaign} onChange={e => setCampaign(e.target.value)}>
            {campaigns.map(c => <option key={c.id} value={c.id}>{c.name} ({c.joined_stores} ร้าน)</option>)}
          </select>
        </label>
        <label className="text-sm">รหัสส่วนลด (4–24 ตัวอักษร)
          <input className={inputStyle} value={code} placeholder="FOOD50"
            maxLength={24} onChange={e => setCode(e.target.value.toUpperCase())} />
        </label>
        <label className="text-sm">จำนวนสิทธิ์รวม (ว่าง = ไม่จำกัด)
          <input className={inputStyle} type="number" min="1" value={totalLimit}
            onChange={e => setTotalLimit(e.target.value)} />
        </label>
        <label className="text-sm">สิทธิ์ต่อบัญชี
          <input className={inputStyle} type="number" min="1" max="20" value={perUser}
            onChange={e => setPerUser(e.target.value)} />
        </label>
      </div>
      <button type="button" onClick={issue} disabled={pending || !code.trim() || !campaign}
        className="mt-4 rounded-lg bg-foreground px-4 py-2 text-background disabled:opacity-40">ออกโค้ดส่วนลด</button>
    </section>}
    {feedback && <p role="status" className="rounded-lg border px-4 py-3 text-sm">{feedback}</p>}
    <section className="rounded-xl border p-4">
      <h2 className="font-semibold">โค้ดส่วนลดทั้งหมด</h2>
      <div className="mt-3 flex flex-col divide-y">
        {rows.length === 0 && <p className="py-3 text-sm text-muted-foreground">ยังไม่มีโค้ดส่วนลด</p>}
        {rows.map(row => <div key={row.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
          <div>
            <strong className="font-mono">{row.code}</strong>
            <p className="text-sm text-muted-foreground">{row.campaign_name}</p>
            <p className="text-xs text-muted-foreground">
              ใช้แล้ว {row.used} / {row.max_total_uses ?? "ไม่จำกัด"} · ต่อบัญชี {row.max_uses_per_user} ครั้ง
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span className={row.is_active ? "text-xs text-green-700" : "text-xs text-muted-foreground"}>
              {row.is_active ? "เปิดใช้งาน" : "หยุด"}
            </span>
            {canManage && <button type="button" disabled={pending} onClick={() => toggle(row)}
              className="rounded-lg border px-3 py-2 text-sm disabled:opacity-40">
              {row.is_active ? "หยุดโค้ด" : "เปิดโค้ด"}
            </button>}
          </div>
        </div>)}
      </div>
    </section>
  </div>;
}
