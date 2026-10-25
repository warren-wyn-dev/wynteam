/* eslint-disable @next/next/no-img-element -- short-lived signed slip URLs, not optimisable */
import { Badge } from "@/components/ui/badge";
import { AdAccountToggle, AdSettingsForm, AdTopupReview } from "@/components/admin/ad-actions";
import { fetchAdminAdOverview } from "@/lib/admin-ads";
import { formatBaht, formatThaiDate, signAdminFoodEvidence } from "@/lib/admin-food";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { NoAccess } from "@/components/admin/no-access";

/**
 * WYN-207: WYNOS Food ads, pay per click. Admin sets the price and WYNOS's
 * PromptPay, checks top-up slips (approving adds credit), and can stop a
 * store's ads. Money, so admin only.
 */
export default async function FoodAdsPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what=" WYNOS Food" />;
  const canEditFood = adminCan(ctx, "food", "edit");
  if (!canEditFood) {
    return (
      <div className="p-6">
        <p className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">ระบบโฆษณาเกี่ยวกับเงิน จัดการได้เฉพาะ Admin</p>
      </div>
    );
  }
  const overview = await fetchAdminAdOverview();
  const slips = await Promise.all(overview.pending_topups.map((topup) => signAdminFoodEvidence(topup.slip_path)));

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-col gap-1">
        <h2 className="text-xl font-semibold">โฆษณา WYNOS Food</h2>
        <p className="text-sm text-muted-foreground">ร้านจ่ายต่อคลิก เติมเครดิตด้วยการโอน PromptPay ให้ WYNOS แล้วแนบสลิป · คนเดิมคลิกร้านเดิมซ้ำในวันเดียวกันคิดครั้งเดียว</p>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <h3 className="text-sm font-semibold">ตั้งค่า</h3>
          <Badge variant={overview.settings.ads_enabled ? "ink-solid" : "outline"}>{overview.settings.ads_enabled ? "เปิดอยู่" : "ปิดอยู่"}</Badge>
        </div>
        <AdSettingsForm settings={overview.settings} />
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold">{`สลิปรอตรวจ (${overview.pending_topups.length})`}</h3>
        {overview.pending_topups.length === 0 ? (
          <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ไม่มีสลิปรอตรวจ</p>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {overview.pending_topups.map((topup, index) => {
              const slip = slips[index];
              return (
                <div key={topup.id} className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex items-center gap-3">
                    {slip.status === "ready" ? (
                      <a href={slip.url} target="_blank" rel="noreferrer"><img src={slip.url} alt={`สลิปของ ${topup.store_name}`} className="h-24 w-20 rounded-md border object-cover" /></a>
                    ) : <span className="text-xs text-destructive">โหลดสลิปไม่สำเร็จ</span>}
                    <div className="text-sm">
                      <p className="font-medium">{topup.store_name}</p>
                      <p className="text-lg font-semibold">{formatBaht(topup.amount)}</p>
                      <p className="text-muted-foreground">{formatThaiDate(topup.created_at)}</p>
                    </div>
                  </div>
                  <AdTopupReview topupId={topup.id} storeName={topup.store_name} amount={formatBaht(topup.amount)} />
                </div>
              );
            })}
          </div>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold">ร้านที่มีบัญชีโฆษณา</h3>
        {overview.accounts.length === 0 ? (
          <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ยังไม่มีร้านลงโฆษณา</p>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {overview.accounts.map((account) => (
              <div key={account.store_id} className="flex flex-col gap-2 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0 text-sm">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-medium">{account.store_name}</p>
                    {account.status === "stopped" ? <Badge variant="destructive">หยุดโดย WYNOS</Badge> : account.live ? <Badge variant="ink-solid">กำลังแสดง</Badge> : <Badge variant="outline">{account.status === "paused" ? "ร้านหยุดไว้" : "ไม่แสดง"}</Badge>}
                  </div>
                  <p className="text-muted-foreground">{`เครดิต ${formatBaht(account.balance)} · ใช้ไปทั้งหมด ${formatBaht(account.total_spent)} · 7 วัน ${account.clicks_7d} คลิก (${formatBaht(account.spend_7d)})`}</p>
                  {account.stop_reason ? <p className="text-muted-foreground">{`เหตุผล: ${account.stop_reason}`}</p> : null}
                </div>
                <AdAccountToggle storeId={account.store_id} storeName={account.store_name} stopped={account.status === "stopped"} />
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
