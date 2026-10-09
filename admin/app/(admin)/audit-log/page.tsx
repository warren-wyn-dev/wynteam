import Link from "next/link";
import { Suspense } from "react";

import type { AuditLogFilters } from "@/lib/admin-audit-log";
import { AUDIT_EVENT_LABELS } from "@/lib/audit-log-labels";
import { AUDIT_EVENT_TYPES, parseAuditFilters } from "@/lib/audit-log-filters.mjs";
import { requireAdminRole } from "@/lib/auth";

import { AuditLogResults } from "./results";

type AuditLogSearchParams = {
  event_type?: string | string[];
  actor_id?: string | string[];
  from?: string | string[];
  to?: string | string[];
  cursor?: string | string[];
};

const EMPTY: AuditLogFilters = {
  eventType: "", actorId: "", from: "", to: "", cursor: null,
};

export default async function AuditLogPage({
  searchParams,
}: {
  searchParams: Promise<AuditLogSearchParams>;
}) {
  await requireAdminRole();

  let filters: AuditLogFilters | null = null;
  let filterError = "";
  try {
    filters = parseAuditFilters(await searchParams) as AuditLogFilters;
  } catch {
    filterError = "ตัวกรองไม่ถูกต้อง กรุณาตรวจสอบวันที่ ประเภทเหตุการณ์ และรหัสเจ้าหน้าที่";
  }
  const current = filters ?? EMPTY;

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="space-y-1">
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">WYNOS Admin · ระบบส่วนกลาง</p>
        <h1 className="text-2xl font-semibold tracking-tight">ประวัติการดำเนินงาน</h1>
        <p className="text-sm text-muted-foreground">ค้นหากิจกรรมจริงของเจ้าหน้าที่ตามสิทธิ์ที่ได้รับ ไม่เปลี่ยนหรือส่งออกข้อมูล</p>
      </header>
      <form action="/audit-log" method="get" role="search" className="grid gap-3 rounded-xl border bg-background p-4 sm:grid-cols-2 lg:grid-cols-4">
        <label className="flex min-w-0 flex-col gap-1 text-xs font-medium">
          ประเภทเหตุการณ์
          <select name="event_type" defaultValue={current.eventType || "all"} className="min-h-11 w-full rounded-lg border bg-background px-3 text-sm">
            <option value="all">ทุกประเภท</option>
            {AUDIT_EVENT_TYPES.map((kind: string) => (
              <option value={kind} key={kind}>{AUDIT_EVENT_LABELS[kind as keyof typeof AUDIT_EVENT_LABELS]}</option>
            ))}
          </select>
        </label>
        <label className="flex min-w-0 flex-col gap-1 text-xs font-medium">
          รหัสเจ้าหน้าที่ (UUID)
          <input name="actor_id" type="text" defaultValue={current.actorId} maxLength={36} placeholder="กรอกเมื่อจำเป็น" autoComplete="off" className="min-h-11 w-full min-w-0 rounded-lg border bg-background px-3 text-sm" />
        </label>
        <label className="flex min-w-0 flex-col gap-1 text-xs font-medium">
          ตั้งแต่วันที่
          <input name="from" type="date" defaultValue={current.from} className="min-h-11 w-full min-w-0 rounded-lg border bg-background px-3 text-sm" />
        </label>
        <label className="flex min-w-0 flex-col gap-1 text-xs font-medium">
          ถึงวันที่
          <input name="to" type="date" defaultValue={current.to} className="min-h-11 w-full min-w-0 rounded-lg border bg-background px-3 text-sm" />
        </label>
        <div className="flex flex-wrap items-center gap-3 sm:col-span-2 lg:col-span-4">
          <button type="submit" className="min-h-11 rounded-lg bg-foreground px-4 text-sm font-medium text-background hover:opacity-90">ค้นหา</button>
          <Link href="/audit-log" className="inline-flex min-h-11 items-center rounded-lg border px-4 text-sm hover:bg-accent">ล้างตัวกรอง</Link>
          <p className="text-xs text-muted-foreground">ใช้วันตามเวลาไทย · แสดง 50 รายการต่อหน้า</p>
        </div>
      </form>
      {filterError || !filters ? (
        <p role="alert" className="rounded-xl border bg-background p-4 text-sm text-muted-foreground">{filterError}</p>
      ) : (
        <Suspense
          key={JSON.stringify(filters)}
          fallback={<div role="status" className="space-y-2">{Array.from({ length: 5 }).map((_, i) => <div key={i} className="h-14 animate-pulse rounded-lg border bg-muted/40" />)}</div>}
        >
          <AuditLogResults filters={filters} />
        </Suspense>
      )}
    </div>
  );
}
