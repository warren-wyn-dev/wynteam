import Link from "next/link";
import { ArrowUpRight, ShieldCheck } from "lucide-react";

import {
  ADMIN_CONTROL_AREAS,
  summarizeAdminControlCoverage,
} from "@/lib/admin-control-catalog";
import { requireAdminRole } from "@/lib/auth";
import { canOpenAdminControl } from "@/lib/admin-control-access.mjs";

/**
 * Read-only implementation map. This does not execute administrative commands
 * or imply that a route has passed authenticated integration testing.
 */
export default async function AdminControlMapPage() {
  const { role } = await requireAdminRole();
  const coverage = summarizeAdminControlCoverage();

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <section className="space-y-3">
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          WYNOS Admin · Central Control
        </p>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">ผังการควบคุมทุกบริการ</h2>
        <p className="max-w-3xl text-sm leading-6 text-muted-foreground">
          รวมจุดจัดการทั้งหมดของ WYNOS โดยแยกหน้าที่มีในระบบออกจากงานที่ยังต้องพัฒนา
          การมีหน้าจอไม่ได้หมายความว่าการทำงานทุกอย่างผ่านการทดสอบกับบัญชีจริงแล้ว
        </p>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="rounded-xl border bg-background p-4">
            <p className="text-sm text-muted-foreground">รายการที่มีหน้าจอใน Admin แล้ว</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">{coverage.existingRoutes}</p>
            <p className="mt-1 text-xs text-muted-foreground">การใช้งานขึ้นกับสิทธิ์และ Backend ของแต่ละหน้า</p>
          </div>
          <div className="rounded-xl border bg-background p-4">
            <p className="text-sm text-muted-foreground">รายการที่รอพัฒนาต่อ</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">{coverage.planned}</p>
            <p className="mt-1 text-xs text-muted-foreground">ไม่มีปุ่มสั่งงานหรือการให้สิทธิ์ใหม่</p>
          </div>
        </div>
      </section>

      <section aria-label="รายการความสามารถแต่ละบริการ" className="grid gap-4 xl:grid-cols-2">
        {ADMIN_CONTROL_AREAS.map((area) => (
          <article key={area.id} className="min-w-0 rounded-xl border bg-background p-4 sm:p-5">
            <header className="border-b pb-4">
              <h3 className="font-semibold">{area.title}</h3>
              <p className="mt-1 text-xs text-muted-foreground">{area.subtitle}</p>
            </header>
            <ul className="divide-y">
              {area.capabilities.map((capability) => {
                const canOpen = canOpenAdminControl(role, capability);
                return (
                  <li key={capability.id} className="flex min-w-0 items-start justify-between gap-3 py-3">
                    <span className="min-w-0 flex-1 text-sm leading-6">{capability.label}</span>
                    {canOpen && capability.href ? (
                      <Link
                        href={capability.href}
                        className="inline-flex min-h-9 shrink-0 items-center gap-1 rounded-lg border px-3 py-1.5 text-xs font-medium hover:bg-muted focus-visible:outline-2"
                        aria-label={`เปิดหน้าจอ ${capability.label}`}
                      >
                        เปิดหน้าจอ <ArrowUpRight aria-hidden="true" className="size-3.5" />
                      </Link>
                    ) : (
                      <span className="shrink-0 rounded-full bg-muted px-2.5 py-1 text-xs text-muted-foreground">
                        {capability.stage === "planned" ? "กำลังพัฒนา" : "เฉพาะ Admin"}
                      </span>
                    )}
                  </li>
                );
              })}
            </ul>
          </article>
        ))}
      </section>

      <div className="flex items-start gap-2 rounded-xl border p-4 text-sm text-muted-foreground">
        <ShieldCheck aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        <p>
          สิทธิ์ในหน้านี้เป็นเพียงการนำทาง ทุกคำสั่งจริงยังต้องผ่านการตรวจสิทธิ์ฝั่งเซิร์ฟเวอร์,
          Supabase RLS/RPC, การยืนยัน และ Audit Log ตามประเภทความเสี่ยง
        </p>
      </div>
    </div>
  );
}
