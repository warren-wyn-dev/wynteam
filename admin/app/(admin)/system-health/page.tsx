import Link from "next/link";
import { Activity, CircleHelp, CircleCheck, TriangleAlert, RefreshCcw } from "lucide-react";

import { requireAdminRole } from "@/lib/auth";
import { fetchAdminHealthObservations, type HealthState } from "@/lib/admin-system-health";

const STATUS_LABEL: Record<HealthState, string> = {
  reachable: "ตอบสนองได้",
  degraded: "ตอบสนองผิดปกติ",
  unknown: "ยังตรวจสอบไม่ได้",
};

function CheckedDate({ value }: { value: string }) {
  return <time dateTime={value}>{new Date(value).toLocaleString("th-TH", {
    timeZone: "Asia/Bangkok", dateStyle: "medium", timeStyle: "short",
  })}</time>;
}

export default async function AdminSystemHealthPage() {
  await requireAdminRole();
  const rows = await fetchAdminHealthObservations();

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-2">
          <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">WYNOS Admin · System Health</p>
          <h1 className="text-2xl font-semibold tracking-tight">สถานะการเข้าถึงบริการ</h1>
          <p className="max-w-3xl text-sm leading-relaxed text-muted-foreground">
            ข้อมูลนี้ตรวจเฉพาะการตอบสนอง HTTP และการอ่านข้อมูล Admin เบื้องต้น
            ไม่ใช่การรับรองว่า Login, ออเดอร์, การชำระเงิน หรือทุกบริการทำงานครบ
          </p>
        </div>
        <Link href="/system-health" className="inline-flex min-h-11 items-center gap-2 rounded-lg border bg-background px-3 text-sm font-medium hover:bg-accent">
          <RefreshCcw aria-hidden="true" className="size-4" /> ตรวจอีกครั้ง
        </Link>
      </header>
      <section aria-label="ผลตรวจสถานะบริการ" className="grid gap-3 lg:grid-cols-2">
        {rows.map((row) => {
          const Icon = row.status === "reachable" ? CircleCheck
            : row.status === "degraded" ? TriangleAlert : CircleHelp;
          return (
            <article key={row.id} className="flex min-w-0 flex-col gap-3 rounded-xl border bg-background p-4 sm:p-5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h2 className="flex items-center gap-2 font-semibold">
                  <Activity aria-hidden="true" className="size-4 text-muted-foreground" />
                  {row.label}
                </h2>
                <span className="inline-flex items-center gap-1.5 rounded-full bg-muted px-2.5 py-1 text-xs font-medium">
                  <Icon aria-hidden="true" className="size-3.5" />
                  {STATUS_LABEL[row.status]}
                </span>
              </div>
              <p className="text-sm text-muted-foreground">{row.detail}</p>
              <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t pt-3 text-xs text-muted-foreground">
                <span>{row.source}</span>
                <span>ตรวจเมื่อ <CheckedDate value={row.checkedAt} /></span>
              </div>
            </article>
          );
        })}
      </section>
      <section aria-label="สถานะระบบแจ้งเหตุ" className="space-y-2 rounded-xl border bg-background p-4 sm:p-5">
        <h2 className="font-semibold">เหตุการณ์ผิดปกติล่าสุด</h2>
        <p className="text-sm text-muted-foreground">
          ยังไม่มีแหล่งข้อมูลเหตุขัดข้องที่เชื่อมต่อและตรวจรับสำหรับ Admin
          จึงยังไม่สามารถยืนยันได้ว่าไม่มีเหตุการณ์ผิดปกติ
        </p>
        <p className="text-xs text-muted-foreground">
          ในเฟสต่อไปสามารถเชื่อมข้อมูล Runtime Error ที่ผ่านการตัดข้อมูลส่วนตัว และอนุมัติสิทธิ์แล้วได้
          โดยไม่เปิดสิทธิ์ Deploy, Database หรือ Cron จากหน้านี้
        </p>
      </section>
      <p className="text-xs text-muted-foreground">
        ข้อความ “ตอบสนองได้” หมายถึงการตรวจชนิดนั้นสำเร็จ ไม่ใช่ Uptime หรือ SLA
        หากปลายทางจำกัดการเข้าถึง ผลจะแสดง “ยังตรวจสอบไม่ได้” แทนการสรุปว่าปกติ
      </p>
    </div>
  );
}
