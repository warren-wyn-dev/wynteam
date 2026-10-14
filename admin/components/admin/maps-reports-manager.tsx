"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import type { AdminMapReport, MapReportEvent, MapReportStatus } from "@/lib/admin-maps-reports";
import { createClient } from "@/lib/supabase/client";

const statuses: Record<MapReportStatus, string> = { open: "รอรับเรื่อง", reviewing: "กำลังตรวจสอบ", resolved: "ตรวจสอบเสร็จแล้ว", dismissed: "ปิดเรื่องโดยไม่ดำเนินการ" };
const kinds: Record<AdminMapReport["kind"], string> = { wrong_info: "ข้อมูลไม่ถูกต้อง", closed: "สถานที่ปิดแล้ว", duplicate: "สถานที่ซ้ำ", unsafe: "ข้อกังวลด้านความปลอดภัย", other: "อื่น ๆ" };
function errorCopy(error: { message?: string } | null) {
  if (error?.message?.includes("Report changed")) return "มีเจ้าหน้าที่อัปเดตรายงานนี้แล้ว กรุณาโหลดข้อมูลล่าสุด";
  if (error?.message?.includes("Not authorized")) return "บัญชีไม่มีสิทธิ์ดำเนินการกับรายงานนี้";
  if (error?.message?.includes("Invalid report transition")) return "เปลี่ยนสถานะนี้ไม่ได้ กรุณาโหลดข้อมูลล่าสุด";
  return "ดำเนินการไม่สำเร็จ กรุณาลองใหม่หรือตรวจสอบการติดตั้ง API";
}

export function MapsReportsManager({ initial, canEdit }: { initial: AdminMapReport[]; canEdit: boolean }) {
  const [items, setItems] = useState(initial);
  const [filter, setFilter] = useState<MapReportStatus | "">("open");
  const [selected, setSelected] = useState<AdminMapReport | null>(null);
  const [history, setHistory] = useState<MapReportEvent[]>([]);
  const [historyLoaded, setHistoryLoaded] = useState(false);
  const [nextStatus, setNextStatus] = useState<MapReportStatus>("reviewing");
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loadFailed, setLoadFailed] = useState(false);
  const [busy, startTransition] = useTransition();
  function reload(status = filter) {
    setError(""); setSuccess(""); setSelected(null); setHistory([]); setHistoryLoaded(false);
    startTransition(async () => {
      try {
        const { data, error: failure } = await createClient().rpc("admin_wynos_map_reports", { p_status: status || null, p_limit: 100 }).abortSignal(AbortSignal.timeout(10_000));
        if (failure || !Array.isArray(data)) { setLoadFailed(true); setError(errorCopy(failure)); return; }
        setItems(data as AdminMapReport[]); setLoadFailed(false);
      } catch { setLoadFailed(true); setError(errorCopy(null)); }
    });
  }
  function open(report: AdminMapReport) {
    setSelected(report); setReason(""); setHistory([]); setHistoryLoaded(false); setError(""); setSuccess("");
    setNextStatus(report.status === "open" ? "reviewing" : "resolved");
    startTransition(async () => {
      try {
        const { data, error: failure } = await createClient().rpc("admin_wynos_map_report_history", { p_report_id: report.id }).abortSignal(AbortSignal.timeout(10_000));
        if (failure || !Array.isArray(data)) { setError(errorCopy(failure)); return; }
        setHistory(data as MapReportEvent[]); setHistoryLoaded(true);
      } catch { setError(errorCopy(null)); }
    });
  }
  function save() {
    if (!selected || busy || !canEdit || reason.trim().length < 5) return;
    const current = selected;
    setError(""); setSuccess("");
    startTransition(async () => {
      try {
        const { data, error: failure } = await createClient().rpc("admin_update_wynos_map_report", {
          p_report_id: current.id, p_expected_version: current.version, p_status: nextStatus, p_reason: reason.trim(),
        }).abortSignal(AbortSignal.timeout(15_000));
        if (failure || typeof data !== "number") { setError(errorCopy(failure)); return; }
        const updated = { ...current, status: nextStatus, version: data, updated_at: new Date().toISOString() };
        setSelected(updated); setItems(previous => previous.map(report => report.id === current.id ? updated : report));
        setReason(""); setHistory([]); setHistoryLoaded(false); setNextStatus("resolved");
        setSuccess("บันทึกสถานะและประวัติแล้ว เลือกรายงานอีกครั้งเพื่อดูประวัติล่าสุด");
      } catch { setError(errorCopy(null)); }
    });
  }
  const editable = canEdit && selected && (selected.status === "open" || selected.status === "reviewing");
  return <section className="space-y-4 rounded-2xl border bg-background p-4 sm:p-6" aria-label="คิวรายงานสถานที่">
    <div className="flex flex-wrap items-center gap-3"><label className="text-sm">สถานะรายงาน<select value={filter} disabled={busy} onChange={event => {
      const value = event.target.value as MapReportStatus | ""; setFilter(value); reload(value);
    }} className="ml-2 min-h-11 rounded-lg border bg-background px-3"><option value="">ทุกสถานะ</option>
      {Object.entries(statuses).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
    </select></label><button type="button" disabled={busy} onClick={() => reload()} className="min-h-11 rounded-lg border px-4 text-sm">{busy ? "กำลังดำเนินการ…" : "โหลดข้อมูลล่าสุด"}</button></div>
    <div className="grid gap-4 lg:grid-cols-[minmax(240px,1fr)_minmax(0,1.5fr)]">
      <div className="max-h-[680px] overflow-y-auto rounded-xl border" aria-label="รายการรายงานล่าสุด">
        {items.filter(report => !filter || report.status === filter).map(report => <button key={report.id} type="button" disabled={busy} aria-pressed={selected?.id === report.id} onClick={() => open(report)} className={`block min-h-11 w-full border-b p-4 text-left last:border-0 hover:bg-accent ${selected?.id === report.id ? "bg-muted" : ""}`}>
          <strong className="block break-words text-sm">{report.place_name}</strong><span className="mt-1 block text-xs">{kinds[report.kind]} · {statuses[report.status]}</span>
        </button>)}
        {!loadFailed && !items.some(report => !filter || report.status === filter) && <p className="p-5 text-sm text-muted-foreground">ไม่มีรายงานในสถานะนี้</p>}
      </div>
      {selected ? <article className="min-w-0 space-y-4 rounded-xl border p-4">
        <h2 className="break-words font-semibold">{selected.place_name}</h2><p className="text-xs text-muted-foreground">{kinds[selected.kind]} · {statuses[selected.status]} · v{selected.version}</p>
        <p className="whitespace-pre-wrap break-words text-sm">{selected.note}</p>
        {selected.place_id && <Link href={`/maps/places?q=${encodeURIComponent(selected.place_name)}`} className="inline-block text-sm underline">เปิดการจัดการสถานที่</Link>}
        {editable ? <form className="space-y-3" onSubmit={event => { event.preventDefault(); save(); }}>
          <label className="block text-sm">สถานะหลังตรวจสอบ<select disabled={busy} value={nextStatus} onChange={event => setNextStatus(event.target.value as MapReportStatus)} className="ml-2 min-h-11 rounded-lg border bg-background px-3">
            {selected.status === "open" ? <option value="reviewing">กำลังตรวจสอบ</option> : <><option value="resolved">ตรวจสอบเสร็จแล้ว</option><option value="dismissed">ปิดเรื่องโดยไม่ดำเนินการ</option></>}
          </select></label>
          <label className="block text-sm">เหตุผลสำหรับประวัติตรวจสอบ (5–300 ตัวอักษร)<textarea rows={3} minLength={5} maxLength={300} required disabled={busy} value={reason} onChange={event => setReason(event.target.value)} className="mt-1 w-full rounded-lg border bg-background p-3" placeholder="บันทึกผลตรวจสอบ โดยไม่ใส่ข้อมูลส่วนบุคคล" /></label>
          <button disabled={busy || reason.trim().length < 5} type="submit" className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">{busy ? "กำลังบันทึก…" : "บันทึกสถานะ"}</button>
        </form> : <p className="text-sm text-muted-foreground">{canEdit ? "รายงานนี้ปิดแล้ว" : "ต้องมี maps:edit เพื่อเปลี่ยนสถานะ"}</p>}
        <details className="text-xs text-muted-foreground"><summary className="cursor-pointer py-2">ประวัติการตรวจสอบ</summary>
          {historyLoaded ? <ol className="space-y-3">{history.map(event => <li key={event.version}>
            <p>v{event.version} · {event.before_status ? `${statuses[event.before_status]} → ` : ""}{statuses[event.after_status]}</p>
            <p className="whitespace-pre-wrap break-words">{event.reason}</p>
          </li>)}</ol> : <p>เลือกรายงานเพื่อโหลดประวัติล่าสุด</p>}
        </details>
      </article> : <p className="p-4 text-sm text-muted-foreground">เลือกรายงานเพื่ออ่านรายละเอียดและตรวจสอบ</p>}
    </div>
    {error && <p role="alert" className="text-sm text-red-600">{error}</p>}{success && <p role="status" className="text-sm">{success}</p>}
    <p className="text-xs text-muted-foreground">แสดงเก่าสุด 100 เรื่องตามตัวกรอง · ปิดบังข้อมูลติดต่อและไม่แสดงตัวตนผู้รายงาน · การเปลี่ยนสถานะไม่แก้ข้อมูลสถานที่และไม่ดำเนินการลงโทษอัตโนมัติ</p>
  </section>;
}
