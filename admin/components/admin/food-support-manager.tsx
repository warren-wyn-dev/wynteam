"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import type { FoodSupportCase, FoodSupportDetail, FoodSupportStatus } from "@/lib/admin-food-support";
import { createClient } from "@/lib/supabase/client";

const labels: Record<FoodSupportStatus, string> = {
  open: "รอรับเรื่อง", in_progress: "กำลังตรวจสอบ", waiting_customer: "รอข้อมูลลูกค้า", resolved: "ปิดเคสแล้ว", appealed: "อุทธรณ์",
};
const kinds: Record<string, string> = { order: "ออเดอร์", payment: "การชำระเงิน", review: "รีวิว", safety: "ความปลอดภัย", other: "อื่น ๆ" };
function errorCopy(error: unknown) {
  const message = (error as { message?: string })?.message ?? "";
  if (/abort|timeout/i.test(message)) return "ยังไม่ได้รับคำยืนยัน กรุณาโหลดเคสล่าสุดเพื่อตรวจสอบก่อนส่งอีกครั้ง";
  if (message.includes("Case changed")) return "ข้อมูลเคสเปลี่ยนแล้ว กรุณาโหลดเคสล่าสุดก่อนบันทึก";
  if (message.includes("another agent")) return "เคสนี้มีเจ้าหน้าที่อื่นรับผิดชอบแล้ว";
  if (message.includes("rate limit")) return "ส่งคำขอบ่อยเกินไป กรุณารอสักครู่";
  if (message.includes("response required")) return "กรุณาเขียนคำตอบให้ลูกค้าก่อนเปลี่ยนสถานะ";
  if (message.includes("Not authorized")) return "บัญชีไม่มีสิทธิ์สำหรับคำขอนี้";
  return "ดำเนินการไม่สำเร็จ กรุณาลองใหม่";
}

export function FoodSupportManager({ initial, canEdit }: { initial: FoodSupportCase[]; canEdit: boolean }) {
  const [items, setItems] = useState(initial);
  const [filter, setFilter] = useState("");
  const [detail, setDetail] = useState<FoodSupportDetail | null>(null);
  const [nextStatus, setNextStatus] = useState("in_progress");
  const [reply, setReply] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loadFailed, setLoadFailed] = useState(false);
  const [busy, startTransition] = useTransition();

  function reload(status = filter) {
    setError(""); setSuccess("");
    startTransition(async () => {
      const { data, error: readError } = await createClient().rpc("admin_food_support_cases", { p_status: status || null, p_limit: 100 }).abortSignal(AbortSignal.timeout(10_000));
      if (readError || !Array.isArray(data)) { setLoadFailed(true); setError(errorCopy(readError)); return; }
      setLoadFailed(false);
      setItems(data as FoodSupportCase[]);
    });
  }
  function open(id: string) {
    setError(""); setSuccess(""); setDetail(null); setReply(""); setReason("");
    startTransition(async () => {
      const { data, error: readError } = await createClient().rpc("admin_food_support_case_detail", { p_case_id: id }).abortSignal(AbortSignal.timeout(10_000));
      if (readError || !data) { setError(errorCopy(readError)); return; }
      setDetail(data as FoodSupportDetail); setNextStatus("in_progress");
    });
  }
  function save() {
    if (!detail || busy || !canEdit) return;
    if (reason.trim().length < 5 || (reply.trim() && reply.trim().length < 5)) { setError("กรุณาระบุเหตุผลและคำตอบอย่างน้อย 5 ตัวอักษร"); return; }
    const current = detail;
    setError(""); setSuccess("");
    startTransition(async () => {
      const { data, error: writeError } = await createClient().rpc("admin_update_food_support_case", {
        p_case_id: current.id, p_expected_version: current.version, p_status: nextStatus,
        p_reply: reply.trim(), p_reason: reason.trim(), p_assign_to_me: !current.assigned,
      }).abortSignal(AbortSignal.timeout(15_000));
      if (writeError || !data) { setError(errorCopy(writeError)); return; }
      const updated = data as FoodSupportDetail;
      setDetail(updated); setItems(previous => previous.map(item => item.id === updated.id ? updated : item));
      setReply(""); setReason(""); setSuccess("บันทึกเคสและประวัติสำเร็จแล้ว");
    });
  }
  const editable = canEdit && detail?.status !== "resolved" && (!detail?.assigned || detail.assigned_to_me);
  return <section className="space-y-4 rounded-2xl border bg-background p-4 sm:p-6" aria-label="คิวช่วยเหลือลูกค้า">
    <div className="flex flex-wrap items-end gap-3">
      <label className="text-sm">สถานะเคส<select value={filter} disabled={busy} onChange={event => {
        setFilter(event.target.value); setDetail(null); reload(event.target.value);
      }} className="ml-2 min-h-11 rounded-lg border bg-background px-3">
        <option value="">ทุกสถานะ</option>{Object.entries(labels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}
      </select></label>
      <button disabled={busy} onClick={() => { setDetail(null); reload(); }} type="button" className="min-h-11 rounded-lg border px-4 text-sm">{busy ? "กำลังโหลด…" : "โหลดข้อมูลล่าสุด"}</button>
    </div>
    <div className="grid gap-4 lg:grid-cols-[minmax(240px,1fr)_minmax(0,1.6fr)]">
      <div className="max-h-[680px] overflow-y-auto rounded-xl border" aria-label="รายการเคสล่าสุด">
        {items.filter(item => !filter || item.status === filter).map(item => <button disabled={busy} key={item.id} onClick={() => open(item.id)} type="button"
          aria-pressed={detail?.id === item.id} className={`block w-full border-b p-4 text-left last:border-0 hover:bg-accent disabled:opacity-50 ${detail?.id === item.id ? "bg-muted" : ""}`}>
          <span className="block text-sm font-semibold">{item.subject}</span>
          <span className="mt-1 block text-xs text-muted-foreground">{item.order_number} · {item.store_name}</span>
          <span className="mt-1 block text-xs">{labels[item.status]} · {item.assigned ? item.assigned_to_me ? "รับผิดชอบโดยคุณ" : "มีผู้รับเรื่องแล้ว" : "ยังไม่มีผู้รับเรื่อง"}</span>
        </button>)}
        {!loadFailed && !items.some(item => !filter || item.status === filter) && <p className="p-5 text-sm text-muted-foreground">ไม่มีเคสในสถานะนี้</p>}
      </div>
      {detail ? <div className="min-w-0 space-y-4 rounded-xl border p-4">
        <div><h2 className="font-semibold break-words">{detail.subject}</h2><p className="mt-1 text-xs text-muted-foreground">{detail.order_number} · {kinds[detail.kind]} · {labels[detail.status]} · v{detail.version}</p></div>
        {canEdit && <Link className="inline-block text-sm underline" href={`/food/orders/${detail.order_id}`}>ดูออเดอร์ต้นเรื่อง</Link>}
        {detail.evidence_item_name && <p className="text-sm">รายการอาหารที่อ้างอิง: {detail.evidence_item_name}</p>}
        {detail.compensation_requested && <p className="rounded-lg bg-muted p-3 text-sm">ลูกค้าขอให้พิจารณาชดเชย ต้องตรวจสอบโดยเจ้าหน้าที่ การปิดเคสไม่ดำเนินการคืนเงินหรือโอนเงิน</p>}
        <ol className="max-h-96 space-y-3 overflow-y-auto" aria-label="บทสนทนา">
          {detail.messages.map(message => <li key={message.id} className={`rounded-lg border p-3 text-sm ${message.actor_role === "support" ? "bg-muted" : ""}`}>
            <p className="text-xs font-medium">{message.actor_role === "customer" ? "ลูกค้า" : "เจ้าหน้าที่"}</p>
            <p className="mt-1 whitespace-pre-wrap break-words">{message.body}</p>
          </li>)}
        </ol>
        {editable ? <div className="space-y-3">
          <label className="block text-sm">สถานะหลังบันทึก<select value={nextStatus} onChange={event => setNextStatus(event.target.value)} disabled={busy} className="ml-2 min-h-11 rounded-lg border bg-background px-3">
            <option value="in_progress">กำลังตรวจสอบ</option><option value="waiting_customer">รอข้อมูลลูกค้า</option><option value="resolved">ปิดเคสแล้ว</option>
          </select></label>
          <label className="block text-sm">คำตอบถึงลูกค้า<textarea rows={3} maxLength={2000} value={reply} disabled={busy} onChange={event => setReply(event.target.value)} className="mt-1 w-full rounded-lg border bg-background p-3" placeholder="ไม่ใส่ข้อมูลติดต่อ รหัสผ่าน หรือข้อมูลบัตร" /></label>
          <label className="block text-sm">เหตุผลสำหรับบันทึกตรวจสอบ (5–300 ตัวอักษร)<textarea rows={2} maxLength={300} value={reason} disabled={busy} onChange={event => setReason(event.target.value)} className="mt-1 w-full rounded-lg border bg-background p-3" /></label>
          <button type="button" onClick={save} disabled={busy || reason.trim().length < 5 || ((nextStatus !== "in_progress" || detail.status === "appealed") && reply.trim().length < 5)} className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">{busy ? "กำลังบันทึก…" : detail.assigned ? "บันทึกและตอบลูกค้า" : "รับเคสและบันทึก"}</button>
        </div> : <p className="text-sm text-muted-foreground">{detail.status === "resolved" ? "ปิดเคสแล้ว ลูกค้าสามารถขออุทธรณ์ได้หนึ่งครั้ง" : !canEdit ? "ต้องมี food:edit เพื่อตอบหรือเปลี่ยนสถานะ" : "เคสนี้มีเจ้าหน้าที่อื่นรับผิดชอบ"}</p>}
        <details className="text-xs text-muted-foreground"><summary className="cursor-pointer py-2">ประวัติสถานะ {detail.history.length} รายการ</summary>
          <ol className="space-y-2">{detail.history.map((event, index) => <li key={`${event.created_at}-${index}`}>{event.before_status ? `${labels[event.before_status]} → ` : ""}{labels[event.after_status]} · {new Date(event.created_at).toLocaleString("th-TH", { timeZone: "Asia/Bangkok" })}</li>)}</ol>
        </details>
      </div> : <p className="p-4 text-sm text-muted-foreground">เลือกเคสเพื่ออ่านบทสนทนาและรับเรื่อง</p>}
    </div>
    {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
    {success && <p role="status" className="text-sm">{success}</p>}
    <p className="text-xs text-muted-foreground">แสดงล่าสุด 100 เคสตามตัวกรอง · เคสรายงานแยกจากสถานะออเดอร์และรีวิว · การแจ้งความเสี่ยงเป็นข้อมูลให้เจ้าหน้าที่ตรวจสอบ ไม่มีการลงโทษอัตโนมัติ</p>
  </section>;
}
