"use client";

import { useEffect, useState } from "react";

import { DeveloperRouteGate, type DeveloperRouteContext } from "@/components/developer-route-gate";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Receipt = {
  receipt_no: string;
  paid_at: string;
  amount: number;
  period_start: string;
  period_end: string;
  issuer: { name: string | null; address: string | null; tax_id: string | null } | null;
  store: { name: string; legal_name: string | null; address: string | null };
};

const baht = (value: number) => Number(value).toLocaleString("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const day = (value: string) =>
  new Intl.DateTimeFormat("th-TH", { dateStyle: "long", timeZone: "UTC" }).format(new Date(`${value}T00:00:00Z`));
const moment = (value: string) =>
  new Intl.DateTimeFormat("th-TH", { dateStyle: "long", timeZone: "Asia/Bangkok" }).format(new Date(value));

function ReceiptView({ client, invoiceId }: DeveloperRouteContext & { invoiceId: string }) {
  const [state, setState] = useState<{ receipt?: Receipt; error?: string }>({});
  const valid = UUID.test(invoiceId);

  useEffect(() => {
    if (!valid) return;
    let active = true;
    // The RPC rechecks owner/admin of the invoice's store and that it is paid.
    void client.rpc("merchant_billing_receipt", { p_invoice_id: invoiceId }).then(({ data, error }) => {
      if (!active) return;
      setState(error || !data ? { error: "เปิดใบเสร็จไม่ได้ ใบเสร็จดูได้เฉพาะเจ้าของร้านหรือแอดมินร้าน หลัง ZOKY ยืนยันการชำระ" } : { receipt: data as Receipt });
    });
    return () => { active = false; };
  }, [client, invoiceId, valid]);

  if (!valid || state.error) {
    return <main className="route-state" role="alert"><p>{valid ? state.error : "ลิงก์ใบเสร็จไม่ถูกต้อง"}</p></main>;
  }
  const receipt = state.receipt;
  if (!receipt) return <main className="route-state" role="status"><div className="route-system-spinner" /><p>กำลังโหลดใบเสร็จ…</p></main>;

  return (
    <main style={{ maxWidth: 720, margin: "0 auto", padding: "24px 16px", color: "#16161a", background: "#fff" }}>
      <style>{"@media print { .no-print { display: none !important; } }"}</style>
      <header style={{ display: "flex", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
        <div>
          <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>ใบเสร็จรับเงิน</h1>
          <p style={{ margin: "4px 0 0", color: "#6b6b76" }}>ไม่ใช่ใบกำกับภาษี</p>
        </div>
        <dl style={{ margin: 0, textAlign: "right" }}>
          <dt style={{ color: "#6b6b76" }}>เลขที่</dt><dd style={{ margin: 0, fontWeight: 600 }}>{receipt.receipt_no}</dd>
          <dt style={{ color: "#6b6b76" }}>วันที่รับเงิน</dt><dd style={{ margin: 0 }}>{moment(receipt.paid_at)}</dd>
        </dl>
      </header>
      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 14, color: "#6b6b76", margin: 0 }}>ผู้รับเงิน</h2>
        <p style={{ margin: "4px 0 0", fontWeight: 600 }}>{receipt.issuer?.name ?? "ZOKY"}</p>
        {receipt.issuer?.address ? <p style={{ margin: 0 }}>{receipt.issuer.address}</p> : null}
        {receipt.issuer?.tax_id ? <p style={{ margin: 0 }}>เลขประจำตัวผู้เสียภาษี {receipt.issuer.tax_id}</p> : null}
      </section>
      <section style={{ marginTop: 16 }}>
        <h2 style={{ fontSize: 14, color: "#6b6b76", margin: 0 }}>ได้รับเงินจาก</h2>
        <p style={{ margin: "4px 0 0", fontWeight: 600 }}>{receipt.store.legal_name || receipt.store.name}</p>
        {receipt.store.legal_name && receipt.store.legal_name !== receipt.store.name ? <p style={{ margin: 0 }}>ร้าน {receipt.store.name}</p> : null}
        {receipt.store.address ? <p style={{ margin: 0 }}>{receipt.store.address}</p> : null}
      </section>
      <table style={{ width: "100%", marginTop: 24, borderCollapse: "collapse" }}>
        <thead><tr style={{ borderBottom: "1px solid #e5e5ea", textAlign: "left" }}><th style={{ padding: "8px 0" }}>รายการ</th><th style={{ padding: "8px 0", textAlign: "right" }}>จำนวนเงิน (บาท)</th></tr></thead>
        <tbody>
          <tr style={{ borderBottom: "1px solid #e5e5ea" }}>
            <td style={{ padding: "8px 0" }}>ค่าบริการ ZOKY รายเดือน<br /><span style={{ color: "#6b6b76" }}>รอบ {day(receipt.period_start)} – {day(receipt.period_end)}</span></td>
            <td style={{ padding: "8px 0", textAlign: "right" }}>{baht(receipt.amount)}</td>
          </tr>
        </tbody>
        <tfoot><tr><td style={{ padding: "8px 0", fontWeight: 700 }}>รวมทั้งสิ้น</td><td style={{ padding: "8px 0", textAlign: "right", fontWeight: 700 }}>{baht(receipt.amount)}</td></tr></tfoot>
      </table>
      <p className="no-print" style={{ marginTop: 24 }}>
        <button type="button" className="route-primary" onClick={() => window.print()}>พิมพ์หรือบันทึกเป็น PDF</button>
      </p>
    </main>
  );
}

export function MerchantBillingReceipt({ invoiceId }: { invoiceId: string }) {
  return (
    <DeveloperRouteGate signedOutPath="/merchant/login">
      {(context) => <ReceiptView key={context.userId} {...context} invoiceId={invoiceId} />}
    </DeveloperRouteGate>
  );
}
