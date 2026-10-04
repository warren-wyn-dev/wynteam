import { Badge } from "@/components/ui/badge";
import { PlatformCampaignFormButton, PlatformSettleButton } from "@/components/admin/platform-campaign-actions";
import { formatBaht, formatThaiDate } from "@/lib/admin-food";
import {
  fetchAdminPlatformCampaigns,
  fetchAdminPlatformOwed,
  platformCampaignTerms,
  type AdminPlatformCampaign,
} from "@/lib/admin-platform-campaigns";
import { requireAdminRole } from "@/lib/auth";

function campaignStatus(campaign: AdminPlatformCampaign) {
  if (!campaign.is_active) return <Badge variant="outline">หยุดแล้ว</Badge>;
  if (campaign.ends_at && new Date(campaign.ends_at) <= new Date()) return <Badge variant="outline">จบแล้ว</Badge>;
  if (new Date(campaign.starts_at) > new Date()) return <Badge variant="gray-tonal">ตั้งเวลาไว้</Badge>;
  return <Badge variant="ink-solid">กำลังใช้งาน</Badge>;
}

/**
 * WYN-206: WYNOS campaigns. Admin designs each campaign and decides how much
 * of the discount WYNOS funds; stores join from Wynos Merchant. WYNOS's part
 * is owed to the store (customers pay stores directly) until Admin records
 * the transfer here. Moderators can read the campaign list only.
 */
export default async function FoodCampaignsPage() {
  const { role } = await requireAdminRole();
  const isAdmin = role === "admin";
  const [campaigns, owed] = await Promise.all([
    fetchAdminPlatformCampaigns(),
    isAdmin ? fetchAdminPlatformOwed() : Promise.resolve([]),
  ]);
  const owedTotal = owed.reduce((sum, row) => sum + Number(row.owed), 0);

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <h2 className="text-xl font-semibold">แคมเปญ WYNOS</h2>
          <p className="text-sm text-muted-foreground">ออกแบบแคมเปญให้ร้านเลือกเข้าร่วม กำหนดว่า WYNOS ออกส่วนลดกี่ % และบันทึกการโอนคืนร้าน</p>
        </div>
        {isAdmin ? <PlatformCampaignFormButton /> : null}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold">แคมเปญทั้งหมด</h3>
        {campaigns.length === 0 ? (
          <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ยังไม่มีแคมเปญ</p>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {campaigns.map((campaign) => (
              <div key={campaign.id} className="flex flex-col gap-3 p-4 lg:flex-row lg:items-center lg:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-medium">{campaign.name}</p>
                    {campaignStatus(campaign)}
                    {!campaign.join_open ? <Badge variant="outline">ปิดรับร้านใหม่</Badge> : null}
                  </div>
                  <p className="text-sm">{platformCampaignTerms(campaign)}</p>
                  <p className="text-sm text-muted-foreground">
                    {`WYNOS ออก ${Number(campaign.platform_share_percent)}% · ร้านออก ${100 - Number(campaign.platform_share_percent)}%`} · {formatThaiDate(campaign.starts_at)} – {campaign.ends_at ? formatThaiDate(campaign.ends_at) : "ไม่มีวันจบ"}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-4 text-sm">
                  <div><p className="text-muted-foreground">ร้านที่เข้าร่วม</p><p className="font-medium">{campaign.joined_stores}</p></div>
                  <div><p className="text-muted-foreground">ออเดอร์สำเร็จ</p><p className="font-medium">{campaign.delivered_orders}</p></div>
                  <div><p className="text-muted-foreground">ส่วนลดรวม</p><p className="font-medium">{formatBaht(campaign.discount_total)}</p></div>
                  <div><p className="text-muted-foreground">WYNOS ออก</p><p className="font-medium">{formatBaht(campaign.platform_funded_total)}</p></div>
                  {isAdmin ? <PlatformCampaignFormButton campaign={campaign} /> : null}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {isAdmin ? (
        <section className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-sm font-semibold">ยอดที่ WYNOS ต้องโอนคืนร้าน</h3>
            <span className="text-sm text-muted-foreground">{`รวม ${formatBaht(owedTotal)}`}</span>
          </div>
          {owed.length === 0 ? (
            <p className="rounded-xl border p-6 text-center text-sm text-muted-foreground">ไม่มียอดค้างโอน</p>
          ) : (
            <div className="flex flex-col divide-y rounded-xl border">
              {owed.map((row) => (
                <div key={row.store_id} className="flex flex-col gap-2 p-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0 text-sm">
                    <p className="font-medium">{row.store_name}</p>
                    <p className="text-muted-foreground">
                      {row.promptpay_id ? `PromptPay ${row.promptpay_name ?? ""} ${row.promptpay_id}` : row.bank_account_number ? `${row.bank_name ?? "บัญชี"} ${row.bank_account_name ?? ""} ${row.bank_account_number}` : "ร้านยังไม่ได้ตั้งช่องทางรับเงิน"}
                    </p>
                    <p className="text-muted-foreground">{`${row.owed_orders} ออเดอร์ · โอนล่าสุด ${row.last_settled_at ? formatThaiDate(row.last_settled_at) : "ยังไม่เคย"}`}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <strong className="text-lg">{formatBaht(row.owed)}</strong>
                    <PlatformSettleButton storeId={row.store_id} storeName={row.store_name} owed={formatBaht(row.owed)} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      ) : null}
    </div>
  );
}
