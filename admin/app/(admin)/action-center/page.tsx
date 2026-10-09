import Link from "next/link";
import { ArrowRight, ClipboardList, RefreshCcw } from "lucide-react";

import { fetchActionCenter } from "@/lib/admin-action-center";
import { requireAdminRole } from "@/lib/auth";

function formatCheckedAt(value: string) {
  return new Date(value).toLocaleString("th-TH", {
    timeZone: "Asia/Bangkok", dateStyle: "medium", timeStyle: "short",
  });
}

export default async function AdminActionCenterPage() {
  const { role } = await requireAdminRole();
  const sections = await fetchActionCenter(role);

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-1">
          <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">WYNOS Admin · Overview</p>
          <h1 className="text-2xl font-semibold tracking-tight">ศูนย์รวมงานรอดำเนินการ</h1>
          <p className="text-sm text-muted-foreground">
            ตรวจรายการสำคัญจากหลาย Workspace โดยไม่มีการอนุมัติหรือเปลี่ยนข้อมูลอัตโนมัติ
          </p>
        </div>
        <Link href="/action-center" className="inline-flex min-h-11 items-center gap-2 rounded-lg border bg-background px-3 text-sm font-medium hover:bg-accent">
          <RefreshCcw aria-hidden="true" className="size-4" /> ตรวจข้อมูลอีกครั้ง
        </Link>
      </header>
      <section aria-label="งานที่ได้รับอนุญาตให้เข้าถึง" className="grid items-start gap-4 lg:grid-cols-2">
        {sections.map((section) => (
          <article key={section.id} className="min-w-0 overflow-hidden rounded-xl border bg-background">
            <div className="flex items-start justify-between gap-3 border-b p-4 sm:p-5">
              <div className="min-w-0 space-y-1">
                <h2 className="font-semibold">{section.title}</h2>
                <p className="text-xs leading-relaxed text-muted-foreground">{section.description}</p>
              </div>
              <div aria-label={section.state === "ready" ? "จำนวนรายการ" : "แหล่งข้อมูลไม่พร้อม"} className="flex min-w-12 shrink-0 justify-center rounded-lg bg-muted px-2 py-2 text-lg font-semibold tabular-nums">
                {section.state === "ready" ? section.countLabel ?? "—" : "—"}
              </div>
            </div>
            <div className="space-y-3 p-4 sm:p-5">
              {section.state === "unavailable" ? (
                <p role="status" className="rounded-lg border border-dashed px-3 py-3 text-sm text-muted-foreground">
                  ตรวจสอบข้อมูลไม่ได้ในขณะนี้ ไม่ได้หมายความว่าไม่มีงานค้าง
                </p>
              ) : section.items.length > 0 ? (
                <ul className="space-y-1">
                  {section.items.map((item) => (
                    <li key={item.id}>
                      <Link href={item.href} className="flex min-h-11 items-center justify-between gap-3 rounded-md px-3 py-2 text-sm hover:bg-accent">
                        <span className="min-w-0 truncate">{item.label}</span>
                        <ArrowRight aria-hidden="true" className="size-4 shrink-0 text-muted-foreground" />
                      </Link>
                    </li>
                  ))}
                </ul>
              ) : section.countLabel === "0" ? (
                <p className="flex items-center gap-2 text-sm text-muted-foreground">
                  <ClipboardList aria-hidden="true" className="size-4" /> ไม่มีงานค้างจากแหล่งข้อมูลนี้
                </p>
              ) : (
                <p className="text-sm text-muted-foreground">
                  เปิดหน้าจัดการเพื่อดูรายการตามสิทธิ์ของคุณ
                </p>
              )}
              <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-3">
                <p className="text-xs text-muted-foreground">ตรวจล่าสุด {formatCheckedAt(section.checkedAt)}</p>
                <Link href={section.href} className="inline-flex min-h-11 items-center gap-1 text-sm font-medium underline-offset-4 hover:underline">
                  เปิดหน้าจัดการ <ArrowRight aria-hidden="true" className="size-4" />
                </Link>
              </div>
            </div>
          </article>
        ))}
      </section>
      <p className="text-xs text-muted-foreground">
        ข้อมูลแสดงตามสิทธิ์ผู้ดูแลและระบบต้นทางเท่านั้น หากบางบริการไม่พร้อม ระบบจะไม่แสดงจำนวนศูนย์แทนข้อผิดพลาด
      </p>
    </div>
  );
}
