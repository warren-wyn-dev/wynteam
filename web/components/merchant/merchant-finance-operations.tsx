"use client";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useRef, useState } from "react";
import { fetchFinanceOperations, operationsCsv, saveFinanceFile, satang, statementHtml, type FinanceOperations, type FinanceOrderLine } from "@/lib/merchant-finance-operations";

export function MerchantFinanceOperations({ client, storeId, from, to, refreshKey }: { client: SupabaseClient; storeId: string; from: string; to: string; refreshKey: unknown }) {
  const [data, setData] = useState<FinanceOperations | null>(null);
  const [message, setMessage] = useState(""); const [busy, setBusy] = useState(false);
  const [version, setVersion] = useState(0);
  useEffect(() => { let live = true;
    void fetchFinanceOperations(client, storeId, from, to).then((d) => { if (live) { setData(d); setMessage(""); } }).catch((e) => { if (live) setMessage(e.message); });
    return () => { live = false; };
  }, [client, storeId, from, to, refreshKey, version]);
  const document = async () => { setBusy(true); try {
    const { data: statement, error } = await client.rpc("merchant_finance_document", { p_store_id: storeId, p_from: from, p_to: to });
    if (error) throw Error("สร้างเอกสารไม่สำเร็จ กรุณาตรวจข้อมูลผู้ออกเอกสารหรือลองใหม่");
    saveFinanceFile(statementHtml(statement), `${statement.document_number}.html`, "text/html;charset=utf-8");
  } catch (e) { setMessage(e instanceof Error ? e.message : "สร้างเอกสารไม่สำเร็จ"); } finally { setBusy(false); } };
  return <section className="wm-fin-card"><h2>รายละเอียดเงินและเอกสาร</h2>
    <p>ตัดยอด 00:00 · เริ่มโอนยอดที่พร้อม 08:00 เวลาไทย เงินเข้าจริงขึ้นกับธนาคาร</p>
    <p role="status">{message}</p>
    <div className="wm-two-actions"><button type="button" className="wm-secondary" disabled={!data || busy} onClick={() => data && saveFinanceFile(operationsCsv(data), `zoky-orders-${from}-${to}.csv`, "text/csv;charset=utf-8")}>ดาวน์โหลดรายออเดอร์ CSV</button><button type="button" className="wm-secondary" disabled={!data || busy} onClick={() => void document()}>ใบสรุปยอด / ค่าบริการ</button></div>
    {!data && !message ? <p>กำลังโหลดรายละเอียด…</p> : null}
    {data?.orders.map((order) => <details key={order.id}><summary>{order.order_number} · รับชำระ {satang(order.paid_satang)}</summary>
      <dl><dt>ค่าอาหาร</dt><dd>{satang(order.food_satang)}</dd><dt>ค่าส่ง</dt><dd>{satang(order.delivery_satang)}</dd><dt>ส่วนลด</dt><dd>{satang(order.discount_satang)}</dd><dt>GP {order.gp_rate_bp / 100}%</dt><dd>{satang(order.gp_satang)}</dd><dt>ค่ารับชำระตามจริง</dt><dd>{satang(order.processor_fee_satang)}</dd><dt>คืนเงินลูกค้า / คืน GP</dt><dd>{satang(order.refunded_satang)} / {satang(order.gp_refunded_satang)}</dd><dt>สุทธิหลังค่ารับชำระ</dt><dd>{satang(order.net_satang)}</dd></dl>
      {order.reconciliation !== "matched" ? <p>กำลังตรวจยอดกับผู้ให้บริการ</p> : null}
      {order.payment_status === "paid" ? <ItemRefund client={client} order={order} onDone={() => setVersion((v) => v + 1)} /> : null}
    </details>)}
    {data?.orders.length === 0 ? <p>ไม่มีรายการรับชำระในช่วงนี้</p> : null}
    <h3>รอบโอนเงิน</h3>{data?.payouts.length === 0 ? <p>ยังไม่มีรอบโอนที่ดำเนินการโดยระบบนี้ ดูยอดโอนจาก Stripe ในสรุปด้านบน</p> : null}
    {data?.payouts.map((p) => <p key={p.id}>{p.business_day} · {satang(p.amount_satang)} · {({ awaiting_funds: "รอเงินพร้อมโอน", requires_configuration: "รอตั้งค่ารอบโอน", processing: "กำลังดำเนินการ", submitted: "ส่งคำขอโอนแล้ว", paid: "โอนสำเร็จ", failed: "โอนไม่สำเร็จ" } as Record<string, string>)[p.state] ?? "รอตรวจสอบ"}</p>)}
    <h3>คำขอคืนบางรายการ</h3>{data?.refunds.map((r) => <p key={r.id}>{satang(r.food_satang + r.delivery_satang)} · {({ queued: "เข้าคิว", processing: "กำลังดำเนินการ", pending: "รอผู้ให้บริการ", succeeded: "คืนสำเร็จ", needs_review: "รอตรวจสอบ" } as Record<string, string>)[r.state]}</p>)}
    <h3>รายการปรับยอด</h3>{data?.adjustments.map((a) => <p key={a.id}>{satang(a.amount_satang)} · {a.reason} · {a.state === "approved" ? "อนุมัติแล้ว รอดำเนินการตามรอบ" : a.state === "rejected" ? "ไม่อนุมัติ" : "รอผู้ตรวจคนที่สอง"}</p>)}
  </section>;
}
function ItemRefund({ client, order, onDone }: { client: SupabaseClient; order: FinanceOrderLine; onDone: () => void }) {
  const [quantities, setQuantities] = useState<Record<string, number>>({}); const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState("");
  const request = useRef({ fingerprint: "", key: "" });
  const submit = async () => { setBusy(true); setMessage(""); try {
    const items = Object.entries(quantities).filter(([, quantity]) => quantity > 0).map(([item_id, quantity]) => ({ item_id, quantity }));
    const fingerprint = JSON.stringify([items, reason]); if (request.current.fingerprint !== fingerprint) request.current = { fingerprint, key: crypto.randomUUID() };
    const { error } = await client.rpc("merchant_request_item_refund", { p_order_id: order.id, p_items: items, p_reason: reason.trim(), p_request_key: request.current.key });
    if (error) throw Error(error.message.includes("delivered") ? "ออเดอร์ส่งแล้ว ต้องให้แอดมินตรวจสอบก่อนคืนเงิน" : "ขอคืนไม่สำเร็จ กรุณาตรวจจำนวน รายการที่คืนไปแล้ว และสิทธิ์ผู้จัดการ");
    setMessage("รับคำขอแล้ว ระบบจะคืนเงินและ GP ตามรายการที่ยืนยัน"); onDone();
  } catch (e) { setMessage(e instanceof Error ? e.message : "ขอคืนไม่สำเร็จ"); } finally { setBusy(false); } };
  return <details><summary>อาหารขาด / ผิดเมนู ขอคืนบางรายการ</summary><p>ยืนยันเฉพาะรายการที่ตรวจสอบแล้ว ระบบคำนวณส่วนลดและ GP ให้ ค่าส่งจะไม่ถูกคืนในคำขอนี้</p>
    {order.items?.map((item) => <label key={item.id}>{item.name}<select aria-label={`จำนวนคืน ${item.name}`} value={quantities[item.id] ?? 0} disabled={busy} onChange={(e) => setQuantities((v) => ({ ...v, [item.id]: Number(e.target.value) }))}>{Array.from({ length: item.quantity + 1 }, (_, i) => <option key={i} value={i}>{i}</option>)}</select></label>)}
    <label>เหตุผล<textarea value={reason} maxLength={500} disabled={busy} onChange={(e) => setReason(e.target.value)} /></label>
    <button className="wm-primary" type="button" disabled={busy || reason.trim().length < 3 || !Object.values(quantities).some((v) => v > 0)} onClick={() => void submit()}>ยืนยันรายการและขอคืนเงิน</button><p role="status">{message}</p></details>;
}
