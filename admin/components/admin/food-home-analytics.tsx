import Link from "next/link";

import { fetchFoodHomeAnalytics, type FoodHomeAnalyticsDays, type FoodHomeAnalyticsKind } from "@/lib/admin-food-home-analytics";

export async function FoodHomeAnalytics({ kind, days, queryParams = {} }: {
  kind: FoodHomeAnalyticsKind;
  days: FoodHomeAnalyticsDays;
  queryParams?: Record<string, string>;
}) {
  let data;
  try {
    data = await fetchFoodHomeAnalytics(kind, days);
  } catch {
    return <section className="space-y-2 rounded-xl border p-4" aria-label="สถิติการแสดงผล">
      <h2 className="font-semibold">สถิติการแสดงผล</h2>
      <p role="alert" className="text-sm text-muted-foreground">โหลดสถิติไม่สำเร็จ หรือยังไม่ได้ติดตั้งระบบวัดผล ลองรีเฟรชอีกครั้ง</p>
    </section>;
  }
  return <section className="space-y-4 rounded-xl border p-4 sm:p-5" aria-label="สถิติการแสดงผล">
    <div className="flex flex-wrap items-center justify-between gap-3">
      <h2 className="font-semibold">สถิติการแสดงผล</h2>
      <nav aria-label="ช่วงเวลาสถิติ" className="flex gap-1">
        {([7, 30, 90] as const).map((range) => <Link key={range} href={`?${new URLSearchParams({ ...queryParams, analyticsDays: String(range) })}`} scroll={false}
          aria-current={range === days ? "page" : undefined}
          className={`rounded-md border px-3 py-2 text-sm ${range === days ? "bg-muted font-semibold" : "text-muted-foreground hover:bg-muted/50"}`}>
          {range} วัน
        </Link>)}
      </nav>
    </div>
    <p className="text-xs text-muted-foreground">{data.starts_on} ถึง {data.ends_on} (UTC) · นับเฉพาะเหตุการณ์ที่บันทึกหลังติดตั้งระบบวัดผล</p>
    <dl className="grid grid-cols-1 gap-3 sm:grid-cols-3">
      {[["การแสดงผล", data.impressions.toLocaleString("th-TH")], ["การกด", data.clicks.toLocaleString("th-TH")], ["อัตราการกด (CTR)", data.ctr_pct === null ? "—" : `${data.ctr_pct.toLocaleString("th-TH")}%`]].map(([label, value]) => <div key={label} className="rounded-lg bg-muted/40 p-3">
        <dt className="text-sm text-muted-foreground">{label}</dt><dd className="mt-1 text-2xl font-semibold">{value}</dd>
      </div>)}
    </dl>
    <p className="text-xs leading-relaxed text-muted-foreground">
      แสดงผลเมื่อเห็นอย่างน้อย 50% ต่อเนื่อง 1 วินาที หรือกดรายการ นับซ้ำได้เมื่อเปิดหน้าใหม่ แต่ไม่นับการส่งซ้ำจากหน้าเดิม
      การกดผูกกับวันที่แสดงผลครั้งนั้น ตัวเลขนี้ไม่ใช่จำนวนคนและไม่ใช้คิดค่าโฆษณา ไม่มีการเก็บบัญชีผู้ใช้ IP หรือพิกัด
      ค่า 0 หมายถึงยังไม่มีเหตุการณ์ที่บันทึกในช่วงนี้
      เหตุการณ์อาจตกหล่นเมื่อการเชื่อมต่อขัดข้องหรือระบบบันทึกหนาแน่น
    </p>
    {data.last_limited_at && Date.parse(data.last_limited_at) >= Date.parse(`${data.starts_on}T00:00:00Z`) ? <p role="status" className="rounded-md border p-3 text-sm text-muted-foreground">
      มีช่วงที่การบันทึกถึงขีดจำกัดป้องกันการส่งถี่ ตัวเลขอาจต่ำกว่าการแสดงผลจริง
    </p> : null}
    {data.items.length ? <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead><tr className="border-b"><th className="min-w-40 py-2 font-medium">รายการ</th><th className="px-3 py-2 text-right font-medium">แสดงผล</th><th className="px-3 py-2 text-right font-medium">กด</th><th className="py-2 text-right font-medium">CTR</th></tr></thead>
        <tbody>{data.items.map((item) => <tr key={item.id} className="border-b last:border-0">
          <td className="max-w-72 py-3 break-words">{item.label}</td><td className="px-3 py-3 text-right">{item.impressions.toLocaleString("th-TH")}</td>
          <td className="px-3 py-3 text-right">{item.clicks.toLocaleString("th-TH")}</td><td className="py-3 text-right">{item.ctr_pct === null ? "—" : `${item.ctr_pct.toLocaleString("th-TH")}%`}</td>
        </tr>)}</tbody>
      </table>
    </div> : <p className="text-sm text-muted-foreground">ยังไม่มีรายการให้วัดผล</p>}
  </section>;
}
