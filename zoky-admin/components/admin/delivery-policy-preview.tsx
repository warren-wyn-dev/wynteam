"use client";

import { useState } from "react";

/** Read-only simulation of the agreed FUTURE WYNOS Rider pricing rules.
 * It does not read or mutate production delivery settings.
 */
export function DeliveryPolicyPreview() {
  const [distance, setDistance] = useState(2.45);
  const [foodSubtotal, setFoodSubtotal] = useState(55);
  const extra100m = Math.max(0, Math.ceil((distance - 2) * 10 - 1e-9));
  const shipping = Math.ceil(10 + extra100m * 0.5);
  const smallOrderFee = foodSubtotal < 60 ? 15 : 0;
  return (
    <section className="rounded-2xl border bg-background p-5">
      <div className="space-y-1">
        <h2 className="text-base font-semibold">ทดลองสูตรค่าจัดส่ง (ไม่บันทึกค่า)</h2>
        <p className="text-xs leading-relaxed text-muted-foreground">
          สูตรตามแผน WYNOS Rider ในอนาคต: 2 กม. แรก 10 บาท ส่วนเกิน 0.50 บาทต่อ 100 เมตร ปัดระยะส่วนเกินขึ้น แล้วปัดค่าส่งขึ้นเป็นบาทเต็ม
          ร้านจัดส่งเองในระยะแรกยังใช้เงื่อนไขของร้าน ไม่ใช้สูตรนี้อัตโนมัติ
        </p>
      </div>
      <div className="mt-5 grid gap-4 sm:grid-cols-2">
        <label className="flex flex-col gap-2 text-sm font-medium">
          ระยะทาง (กม.) <span className="font-normal text-muted-foreground">0–15</span>
          <input type="number" min="0" max="15" step="0.05" value={distance} onChange={(e) => {
            const next = Number(e.target.value);
            if (Number.isFinite(next)) setDistance(Math.max(0, Math.min(15, next)));
          }} className="h-11 w-full rounded-lg border bg-background px-3 tabular-nums" />
        </label>
        <label className="flex flex-col gap-2 text-sm font-medium">
          ยอดอาหารก่อนส่วนลด (บาท)
          <input type="number" min="0" step="1" value={foodSubtotal} onChange={(e) => {
            const next = Number(e.target.value);
            if (Number.isFinite(next)) setFoodSubtotal(Math.max(0, next));
          }} className="h-11 w-full rounded-lg border bg-background px-3 tabular-nums" />
        </label>
      </div>
      <div className="mt-4 grid gap-3 sm:grid-cols-3">
        <Metric label="ค่าส่ง Rider จำลอง" value={shipping} />
        <Metric label="ค่าธรรมเนียมออเดอร์เล็ก" value={smallOrderFee} />
        <Metric label="ค่าจัดส่ง + ค่าธรรมเนียม" value={shipping + smallOrderFee} />
      </div>
      <p className="mt-3 text-xs text-muted-foreground">
        คิดจากตัวเลขที่ป้อน ไม่ได้วัดเส้นทางถนนจริง ไม่รวมราคาอาหารและส่วนลด และไม่ได้แก้ฐานข้อมูลหรือค่าส่งที่ลูกค้าใช้อยู่
      </p>
    </section>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-xl bg-muted/50 p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-xl font-semibold tabular-nums">{value.toLocaleString("th-TH")} ฿</p>
    </div>
  );
}
