/* eslint-disable @next/next/no-img-element -- short-lived signed slip URLs, not optimisable */
import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { BillingSettingsForm, BillingSlipReview, BillingWaive } from "@/components/admin/billing-actions";
import { NoAccess } from "@/components/admin/no-access";
import { BILLING_STATUS_LABEL, fetchAdminBillingOverview, formatBillingDay } from "@/lib/admin-billing";
import { formatBaht, formatThaiDate, signAdminFoodEvidence } from "@/lib/admin-food";
import { adminCan, requireAdminRole } from "@/lib/auth";

/**
 * ZOKY-BILLING-001: fixed monthly store fee, paid by transfer + slip.
 * Admin sets the fee, trial and ZOKY's account, confirms slips (receipt) and
 * sees overdue stores. The system never suspends a store: suspend from the
 * store page when needed.
 */
export default async function MerchantBillingPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "merchant")) return <NoAccess what=" Merchant" />;
  const canEdit = adminCan(ctx, "merchant", "edit");
  const overview = await fetchAdminBillingOverview();
  const slips = await Promise.all(overview.pending.map((invoice) => signAdminFoodEvidence(invoice.slip_path)));
  const settings = overview.settings;

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-col gap-1">
        <h2 className="text-xl font-semibold">ค่าบริการร้าน</h2>
        <p className="text-sm text-muted-foreground">
          ค่าบริการรายเดือนคงที่ ร้านโอนแล้วแนบสลิป · รอบบิลนับจากวันที่ร้านเปิดขาย (หลังหมดช่วงทดลองใช้) · ครบกำหนด 7 วันหลังออกใบ เตือนก่อน 3 วัน วันครบกำหนด และหลังเลยกำหนด 3 และ 7 วัน · ระบบไม่ระงับร้านเอง
        </p>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="text-sm font-semibold">ตั้งค่า</h3>
          <Badge variant={settings.billing_enabled ? "ink-solid" : "outline"}>{settings.billing_enabled ? "เปิดอยู่" : "ปิดอยู่"}</Badge>
          {settings.launched_on ? <span className="text-xs text-muted-foreground">{`เปิดระบบครั้งแรก ${formatBillingDay(settings.launched_on)}`}</span> : null}
          <span className="text-xs text-muted-foreground">{`ร้านในช่วงทดลองใช้ ${overview.stores.in_trial} · ร้านที่เริ่มเก็บแล้ว ${overview.stores.billed}`}</span>
        </div>
        <BillingSettingsForm settings={settings} canEdit={canEdit} />
        {overview.price_history.length > 0 ? (
          <details className="rounded-xl border p-4 text-sm">
            <summary className="cursor-pointer font-medium">ประวัติราคาและวันทดลองใช้</summary>
            <ul className="mt-2 flex flex-col gap-1 text-muted-foreground">
              {overview.price_history.map((row) => (
                <li key={row.set_at}>{`${formatThaiDate(row.set_at)} · ${row.monthly_fee == null ? "ยังไม่ตั้งราคา" : formatBaht(row.monthly_fee)} · ทดลองใช้ ${row.trial_days ?? "—"} วัน`}</li>
              ))}
            </ul>
          </details>
        ) : null}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold">{`สลิปรอตรวจ (${overview.pending.length})`}</h3>
        {overview.pending.length === 0 ? (
          <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ไม่มีสลิปรอตรวจ</p>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {overview.pending.map((invoice, index) => {
              const slip = slips[index];
              return (
                <div key={invoice.id} className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex items-center gap-3">
                    {slip.status === "ready" ? (
                      <a href={slip.url} target="_blank" rel="noreferrer"><img src={slip.url} alt={`สลิปค่าบริการของ ${invoice.store_name}`} className="h-24 w-20 rounded-md border object-cover" /></a>
                    ) : <span className="text-xs text-destructive">โหลดสลิปไม่สำเร็จ</span>}
                    <div className="text-sm">
                      <p className="font-medium">{invoice.store_name}</p>
                      <p className="text-lg font-semibold">{formatBaht(invoice.amount)}</p>
                      <p className="text-muted-foreground">{`รอบ ${formatBillingDay(invoice.period_start)} – ${formatBillingDay(invoice.period_end)} · แนบ ${formatThaiDate(invoice.submitted_at)}`}</p>
                    </div>
                  </div>
                  {canEdit ? (
                    <div className="flex flex-col items-end gap-2">
                      <BillingSlipReview invoiceId={invoice.id} storeName={invoice.store_name} amount={formatBaht(invoice.amount)} />
                      <BillingWaive invoiceId={invoice.id} storeName={invoice.store_name} amount={formatBaht(invoice.amount)} />
                    </div>
                  ) : null}
                </div>
              );
            })}
          </div>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold">{`ร้านค้างจ่าย (${overview.overdue.length})`}</h3>
        {overview.overdue.length === 0 ? (
          <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ไม่มีร้านค้างจ่าย</p>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {overview.overdue.map((invoice) => (
              <div key={invoice.id} className="flex flex-col gap-2 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0 text-sm">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-medium">{invoice.store_name}</p>
                    <Badge variant="destructive">{`เลยกำหนด ${invoice.overdue_days} วัน`}</Badge>
                    {invoice.status === "rejected" ? <Badge variant="outline">สลิปไม่ผ่าน</Badge> : null}
                    {invoice.suspended ? <Badge variant="outline">ระงับร้านอยู่</Badge> : null}
                  </div>
                  <p className="text-muted-foreground">{`${formatBaht(invoice.amount)} · ครบกำหนด ${formatBillingDay(invoice.due_on)}`}</p>
                  {invoice.note ? <p className="text-muted-foreground">{`เหตุผลที่สลิปไม่ผ่าน: ${invoice.note}`}</p> : null}
                </div>
                <div className="flex gap-2">
                  <Link href={`/merchant/stores/${invoice.store_id}`} className="inline-flex min-h-9 items-center rounded-md border px-3 text-sm">หน้าร้าน (ระงับร้าน)</Link>
                  {canEdit ? <BillingWaive invoiceId={invoice.id} storeName={invoice.store_name} amount={formatBaht(invoice.amount)} /> : null}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold">ใบแจ้งหนี้ล่าสุด</h3>
        {overview.recent.length === 0 ? (
          <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ยังไม่มีใบแจ้งหนี้</p>
        ) : (
          <div className="overflow-x-auto rounded-xl border">
            <table className="w-full min-w-[640px] text-sm">
              <thead className="bg-muted/40 text-left text-muted-foreground">
                <tr><th className="p-3 font-medium">ร้าน</th><th className="p-3 font-medium">รอบ</th><th className="p-3 font-medium">ยอด</th><th className="p-3 font-medium">ครบกำหนด</th><th className="p-3 font-medium">สถานะ</th><th className="p-3 font-medium">ใบเสร็จ</th></tr>
              </thead>
              <tbody className="divide-y">
                {overview.recent.map((invoice) => (
                  <tr key={invoice.id}>
                    <td className="p-3">{invoice.store_name}</td>
                    <td className="p-3">{formatBillingDay(invoice.period_start)}</td>
                    <td className="p-3">{formatBaht(invoice.amount)}</td>
                    <td className="p-3">{formatBillingDay(invoice.due_on)}</td>
                    <td className="p-3" title={invoice.note ?? undefined}>{BILLING_STATUS_LABEL[invoice.status]}</td>
                    <td className="p-3">{invoice.receipt_no ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
