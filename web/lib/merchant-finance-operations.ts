import type { SupabaseClient } from "@supabase/supabase-js";

export type FinanceOrderLine = {
  id: string; order_number: string; paid_at: string | null; payment_status: string;
  food_satang: number; delivery_satang: number; discount_satang: number; paid_satang: number;
  gp_satang: number; gp_rate_bp: number; processor_fee_satang: number | null;
  refunded_satang: number | null; gp_refunded_satang: number | null; net_satang: number | null;
  available_on: string | null; checked_at: string | null; reconciliation: string;
  items: Array<{ id: string; name: string; quantity: number; unit_satang: number }> | null;
};
export type FinanceOperations = {
  orders: FinanceOrderLine[];
  payouts: Array<{ id: string; business_day: string; state: string; amount_satang: number; arrival_date: string | null }>;
  refunds: Array<{ id: string; order_id: string; state: string; food_satang: number; delivery_satang: number; gp_satang: number }>;
  adjustments: Array<{ id: string; amount_satang: number; state: string; reason: string }>;
};
export async function fetchFinanceOperations(client: SupabaseClient, storeId: string, from: string, to: string) {
  const { data, error } = await client.rpc("merchant_finance_order_lines", { p_store_id: storeId, p_from: from, p_to: to });
  if (error) throw new Error("โหลดรายละเอียดการเงินไม่สำเร็จ กรุณาลองใหม่");
  return data as FinanceOperations;
}
export const satang = (value: number | null | undefined) => value == null ? "รอยืนยัน" : new Intl.NumberFormat("th-TH", { style: "currency", currency: "THB" }).format(value / 100);
const escapeHtml = (value: unknown) => String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
export function statementHtml(data: FinanceOperations & { issuer: { name: string; address: string }; document_number: string; store_name: string; from: string; to: string; generated_at: string }) {
  const rows = data.orders.map((r) => `<tr><td>${escapeHtml(r.order_number)}</td><td>${satang(r.paid_satang)}</td><td>${satang(r.gp_satang)}</td><td>${satang(r.processor_fee_satang)}</td><td>${satang(r.refunded_satang)}</td><td>${satang(r.gp_refunded_satang)}</td><td>${satang(r.net_satang)}</td></tr>`).join("");
  return `<!doctype html><html lang="th"><meta charset="utf-8"><title>${escapeHtml(data.document_number)}</title><style>body{font:16px sans-serif;margin:32px;color:#222}table{border-collapse:collapse;width:100%}td,th{padding:8px;border:1px solid #ccc;text-align:right}td:first-child{text-align:left}@media print{button{display:none}}</style><h1>ใบสรุปยอดและค่าบริการ ZOKY</h1><p>${escapeHtml(data.document_number)}</p><p>${escapeHtml(data.issuer.name)}<br>${escapeHtml(data.issuer.address)}</p><p>ร้าน ${escapeHtml(data.store_name)} · ${escapeHtml(data.from)} ถึง ${escapeHtml(data.to)}</p><table><thead><tr><th>ออเดอร์</th><th>รับชำระ</th><th>GP</th><th>ค่ารับชำระ</th><th>คืนลูกค้า</th><th>คืน GP</th><th>สุทธิ</th></tr></thead><tbody>${rows}</tbody></table><p>ยอดรอยืนยันยังไม่รวมเป็นยอดสุทธิ เอกสารนี้ไม่ใช่ใบกำกับภาษี VAT หรือหลักฐานว่าเงินเข้าธนาคารแล้ว</p><p>จัดทำ ณ ${escapeHtml(data.generated_at)}</p><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></html>`;
}
export function saveFinanceFile(content: string, name: string, mime: string) {
  const url = URL.createObjectURL(new Blob([content], { type: mime }));
  const link = document.createElement("a"); link.href = url; link.download = name; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export function operationsCsv(data: FinanceOperations) {
  const cell = (value: unknown) => `"${String(value ?? "รอยืนยัน").replace(/^[=+@\-\t\r]/, "'$&").replaceAll('"', '""')}"`;
  const rows = data.orders.map((r) => [r.order_number, r.paid_satang, r.gp_satang, r.processor_fee_satang, r.refunded_satang, r.gp_refunded_satang, r.net_satang]);
  return "\uFEFF" + [["ออเดอร์", "รับชำระ (สตางค์)", "GP (สตางค์)", "ค่ารับชำระ (สตางค์)", "คืนเงิน (สตางค์)", "คืน GP (สตางค์)", "สุทธิ (สตางค์)"], ...rows].map((r) => r.map(cell).join(",")).join("\r\n");
}
