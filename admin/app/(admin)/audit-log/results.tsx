import Link from "next/link";

import { fetchAuditLogPage, type AuditLogFilters } from "@/lib/admin-audit-log";
import { AUDIT_EVENT_LABELS } from "@/lib/audit-log-labels";

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("th-TH", {
    timeZone: "Asia/Bangkok",
    dateStyle: "medium",
    timeStyle: "medium",
  });
}

export async function AuditLogResults({ filters }: { filters: AuditLogFilters }) {
  let data;
  try {
    data = await fetchAuditLogPage(filters);
  } catch {
    return (
      <div role="status" className="rounded-xl border bg-background p-5 text-sm text-muted-foreground">
        ไม่สามารถโหลดประวัติการดำเนินงานได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง
      </div>
    );
  }

  const { rows, nextCursor } = data;
  if (rows.length === 0) {
    return (
      <div className="rounded-xl border bg-background p-6 text-center text-sm text-muted-foreground">
        ไม่มีประวัติที่ตรงกับตัวกรองนี้
      </div>
    );
  }

  const params = new URLSearchParams();
  if (filters.eventType) params.set("event_type", filters.eventType);
  if (filters.actorId) params.set("actor_id", filters.actorId);
  if (filters.from) params.set("from", filters.from);
  if (filters.to) params.set("to", filters.to);
  if (nextCursor) params.set("cursor", nextCursor);

  return (
    <section aria-label="ผลลัพธ์ประวัติการดำเนินงาน" className="flex flex-col gap-3">
      <div className="min-w-0 overflow-x-auto rounded-xl border bg-background">
        <table className="w-full min-w-[700px] text-sm">
          <thead className="border-b bg-muted/40 text-left text-muted-foreground">
            <tr>
              <th scope="col" className="px-4 py-3 font-medium">เจ้าหน้าที่</th>
              <th scope="col" className="px-4 py-3 font-medium">เหตุการณ์</th>
              <th scope="col" className="px-4 py-3 font-medium">รหัสเป้าหมาย</th>
              <th scope="col" className="px-4 py-3 font-medium">วันที่และเวลา (ไทย)</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id} className="border-b align-top last:border-b-0 hover:bg-accent/40">
                <td className="px-4 py-3">
                  <span className="font-medium">{row.actor_username_snapshot ?? "ไม่ระบุ"}</span>
                </td>
                <td className="px-4 py-3">{AUDIT_EVENT_LABELS[row.event_type] ?? row.event_type}</td>
                <td className="max-w-48 break-all px-4 py-3 font-mono text-xs text-muted-foreground">{row.target_id ?? "—"}</td>
                <td className="whitespace-nowrap px-4 py-3 text-xs text-muted-foreground">{formatDate(row.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-muted-foreground">
          แสดง {rows.length} รายการในหน้านี้ · ไม่แสดงรายละเอียดดิบที่อาจมีข้อมูลส่วนตัว
        </p>
        {nextCursor ? (
          <Link href={`/audit-log?${params.toString()}`} className="inline-flex min-h-11 items-center rounded-lg border bg-background px-4 text-sm font-medium hover:bg-accent">
            รายการเก่ากว่า →
          </Link>
        ) : <span className="text-xs text-muted-foreground">สิ้นสุดรายการ</span>}
      </div>
    </section>
  );
}
