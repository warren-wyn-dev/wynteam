import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import { formatBaht, formatThaiDate } from "@/lib/admin-food";
import {
  FINANCE_MAX_DAYS,
  FINANCE_PRESETS,
  PAYOUT_INTERVAL_LABEL,
  PAYOUT_STATUS_LABEL,
  STRIPE_STATUS_LABEL,
  fetchMerchantFinanceOverview,
  formatSatang,
  resolveFinanceRange,
  type MerchantFinanceOverview,
} from "@/lib/admin-merchant-finance";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { fetchGpHistory, fetchGpSettings, type GpSettings } from "@/lib/admin-gp";
import { formatGpRate, gpRowLabel } from "@/lib/admin-gp-format";
import { GpCancelButton, GpRateDialog } from "@/components/admin/gp-rate-dialog";
import { cn } from "@/lib/utils";

const VIEWS = [
  { value: "overview", label: "ภาพรวมการเงิน" },
  { value: "stores", label: "รายได้ร้านค้า" },
  { value: "owed", label: "ยอดค้างจ่าย" },
  { value: "payouts", label: "การจ่ายเงินให้ร้านค้า" },
  { value: "history", label: "ประวัติการโอน" },
  { value: "gp", label: "ตั้งค่า GP รายร้าน" },
] as const;
type View = (typeof VIEWS)[number]["value"];

/**
 * WYNOS Merchant -> การเงินร้านค้า. GP rates are set on the GP tab (super
 * admin only, admin_set_gp_rate); everything else is read only: numbers come from
 * admin_merchant_finance_overview (merchant:view), which uses the same lines
 * as each store's own finance page. Money only moves through the existing
 * flows (Stripe Connect automatic payouts; WYNOS campaign settlements on
 * /food/campaigns) -- nothing here pays, refunds or changes a rate.
 */
export default async function MerchantFinancePage({
  searchParams,
}: {
  searchParams: Promise<{ view?: string; range?: string; from?: string; to?: string; gp_before?: string; gp_before_id?: string }>;
}) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "merchant")) return <NoAccess what=" WYNOS Merchant" />;

  // Store pages need food access; merchant-only staff see plain names.
  const canOpenStores = adminCan(ctx, "food");
  const params = await searchParams;
  const view: View = VIEWS.some((item) => item.value === params.view) ? (params.view as View) : "overview";
  const range = resolveFinanceRange(params);

  const href = (next: { view?: View; range?: string; from?: string; to?: string }) => {
    const merged = {
      view: view === "overview" ? undefined : view,
      range: range.preset === "7d" ? undefined : range.preset,
      from: range.preset === "custom" ? range.from : undefined,
      to: range.preset === "custom" ? range.to : undefined,
      ...next,
    };
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(merged)) if (value && !(key === "view" && value === "overview")) query.set(key, value);
    const text = query.toString();
    return text ? `/merchant/finance?${text}` : "/merchant/finance";
  };

  let data: MerchantFinanceOverview | null = null;
  let loadError: "missing" | "failed" | null = null;
  if (view !== "gp") {
    try {
      data = await fetchMerchantFinanceOverview(range);
    } catch (error) {
      const code = (error as { code?: string } | null)?.code;
      loadError = code === "PGRST202" || code === "42883" ? "missing" : "failed";
    }
  }

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <section className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <p className="text-xs text-muted-foreground">WYNOS Merchant</p>
          <h2 className="text-xl font-semibold">การเงินร้านค้า</h2>
          <p className="text-sm text-muted-foreground">
            ยอดขาย รายได้ การจ่ายเงิน และ GP ของทุกร้าน · ตัวเลขชุดเดียวกับหน้าการเงินของร้านใน merchant.wynos.online
          </p>
        </div>
        <RefreshButton />
        <Link href="/merchant/finance/operations" className="text-sm underline">ตรวจยอด คืนเงิน และปรับยอด</Link>
      </section>

      <nav aria-label="เมนูการเงินร้านค้า" className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
        <ul className="flex w-max gap-1 border-b">
          {VIEWS.map((item) => (
            <li key={item.value}>
              <Link
                href={href({ view: item.value })}
                aria-current={view === item.value ? "page" : undefined}
                className={cn(
                  "-mb-px inline-flex min-h-11 items-center whitespace-nowrap border-b-2 px-3 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                  view === item.value
                    ? "border-foreground font-semibold text-foreground"
                    : "border-transparent text-muted-foreground hover:text-foreground",
                )}
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>

      {view === "gp" ? (
        <GpSection
          before={
            params.gp_before && !Number.isNaN(Date.parse(params.gp_before)) && /^[0-9a-f-]{36}$/i.test(params.gp_before_id ?? "")
              ? { at: params.gp_before, id: params.gp_before_id! }
              : null
          }
        />
      ) : (
        <>
          <RangeBar range={range} href={href} view={view} />
          {loadError ? (
            <p role="alert" className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
              {loadError === "missing"
                ? "ระบบการเงินร้านค้าใน Admin ยังไม่ได้ติดตั้งบนฐานข้อมูลนี้ (รอ Founder อนุมัติ apply migration)"
                : "โหลดข้อมูลการเงินไม่สำเร็จ ลองกดรีเฟรชอีกครั้ง"}
            </p>
          ) : data ? (
            <>
              {view === "overview" ? <Overview data={data} href={href} /> : null}
              {view === "stores" ? <StoresTable data={data} canOpenStores={canOpenStores} /> : null}
              {view === "owed" ? <Owed data={data} canOpenStores={canOpenStores} /> : null}
              {view === "payouts" ? <Payouts data={data} canOpenStores={canOpenStores} /> : null}
              {view === "history" ? <History data={data} canOpenStores={canOpenStores} /> : null}
            </>
          ) : null}
        </>
      )}
    </div>
  );
}

function RangeBar({
  range,
  href,
  view,
}: {
  range: ReturnType<typeof resolveFinanceRange>;
  href: (next: { range?: string; from?: string; to?: string }) => string;
  view: View;
}) {
  return (
    <section className="flex flex-col gap-3 rounded-xl border bg-background p-4">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm font-medium">ช่วงเวลา</span>
        {FINANCE_PRESETS.map((preset) => (
          <Link
            key={preset.value}
            href={href({ range: preset.value, from: undefined, to: undefined })}
            aria-current={range.preset === preset.value ? "true" : undefined}
            className={cn(
              "inline-flex min-h-9 items-center rounded-full border px-3 text-sm",
              range.preset === preset.value ? "bg-foreground text-background" : "hover:bg-accent",
            )}
          >
            {preset.label}
          </Link>
        ))}
        <span className="text-xs text-muted-foreground">
          {range.from === range.to ? range.from : `${range.from} – ${range.to}`} (เวลาไทย)
        </span>
      </div>
      {/* Plain GET form: works without JavaScript and keeps the URL shareable. */}
      <form action="/merchant/finance" className="flex flex-wrap items-end gap-2">
        <input type="hidden" name="range" value="custom" />
        {view !== "overview" ? <input type="hidden" name="view" value={view} /> : null}
        <label className="flex flex-col gap-1 text-xs text-muted-foreground">
          ตั้งแต่
          <input type="date" name="from" required defaultValue={range.from} className="h-10 rounded-md border bg-background px-2 text-sm text-foreground" />
        </label>
        <label className="flex flex-col gap-1 text-xs text-muted-foreground">
          ถึง
          <input type="date" name="to" required defaultValue={range.to} className="h-10 rounded-md border bg-background px-2 text-sm text-foreground" />
        </label>
        <button type="submit" className="h-10 rounded-md border px-3 text-sm font-medium hover:bg-accent">กำหนดเอง</button>
      </form>
      {range.fallback ? (
        <p role="status" className="text-xs text-destructive">
          ช่วงวันที่ไม่ถูกต้องหรือยาวเกิน {FINANCE_MAX_DAYS} วัน จึงแสดง 7 วันล่าสุดแทน
        </p>
      ) : null}
    </section>
  );
}

function Figure({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-xl border bg-background p-4">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-lg font-semibold tabular-nums">{value}</p>
      <p className="mt-1 text-[11px] leading-snug text-muted-foreground">{hint}</p>
    </div>
  );
}

function Overview({ data, href }: { data: MerchantFinanceOverview; href: (next: { view?: View }) => string }) {
  const t = data.totals;
  const failed = data.payout_status_counts.failed ?? 0;
  return (
    <>
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Figure label="ยอดขายสุทธิ" value={formatBaht(t.sales_net)} hint="ยอดที่ลูกค้าจ่ายในช่วงนี้ หักยอดคืนเงิน" />
        <Figure label="รายได้ร้านรวม" value={formatBaht(t.income)} hint="ยอดขายสุทธิ − ค่าโฆษณา + ส่วนแบ่งแคมเปญ WYNOS" />
        <Figure label="ออเดอร์ที่ชำระแล้ว" value={t.orders.toLocaleString("th-TH")} hint={`จาก ${t.stores_with_sales.toLocaleString("th-TH")} ร้านที่มียอดขาย`} />
        <Figure label="คืนเงิน" value={formatBaht(t.refunds)} hint={`${t.refund_count.toLocaleString("th-TH")} ออเดอร์ (ตามวันที่คืนเงิน)`} />
        <Figure label="ค่าโฆษณาที่ร้านจ่าย" value={formatBaht(t.ad_spend)} hint="คลิกโฆษณาที่คิดเงินในช่วงนี้" />
        <Figure label="ส่วนแบ่งแคมเปญ WYNOS" value={formatBaht(t.platform_funded)} hint="ส่วนลดที่ WYNOS ออกให้ร้าน (ออเดอร์ส่งสำเร็จ)" />
        <Figure label="WYNOS ค้างโอนให้ร้าน (ปัจจุบัน)" value={formatBaht(t.platform_owed)} hint="ไม่ขึ้นกับช่วงเวลา · โอนจากหน้า Campaigns" />
        <Figure label="รายได้ GP ของแพลตฟอร์ม" value={formatBaht(t.gp ?? 0)} hint={`เก็บผ่าน Stripe แล้ว${Number(t.gp_uncollected ?? 0) > 0 ? ` · เก็บไม่ได้ (จ่ายสลิป) ${formatBaht(t.gp_uncollected)}` : ""}`} />
      </section>

      <section className="grid gap-3 sm:grid-cols-3">
        <Figure label="ร้านที่พร้อมรับเงิน (Stripe)" value={`${t.stores_payout_ready.toLocaleString("th-TH")} / ${t.stores.toLocaleString("th-TH")}`} hint="เปิดการโอนเงินอัตโนมัติแล้ว" />
        <Figure label="ร้านที่ยังไม่มีบัญชี Stripe" value={t.stores_without_stripe.toLocaleString("th-TH")} hint="ยังรับชำระออนไลน์ผ่าน Stripe ไม่ได้" />
        <Figure label="การโอนที่ไม่สำเร็จ" value={failed.toLocaleString("th-TH")} hint="Stripe payout สถานะ failed ในช่วงนี้" />
      </section>

      <section className="rounded-xl border bg-background p-4 text-sm">
        <p className="font-medium">วิธีคำนวณ</p>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-muted-foreground">
          <li>นับตามวันในเวลาไทย (Asia/Bangkok): ยอดขายตามเวลาที่ชำระเงิน, คืนเงินตามเวลาที่คืนเงิน</li>
          <li>ส่วนลด = ค่าอาหาร + ค่าส่ง − ยอดที่ลูกค้าจ่าย</li>
          <li>รายได้ร้าน = ยอดขายสุทธิ − ค่าโฆษณา + ส่วนแบ่งแคมเปญ WYNOS − GP ที่เก็บแล้ว (สูตรเดียวกับหน้าการเงินของร้าน)</li>
          <li>GP = อัตราที่บันทึกไว้กับออเดอร์ตอนสั่ง × ค่าอาหารหลังส่วนลดของร้าน (ไม่รวมค่าส่ง) ปัดเศษครึ่งขึ้นเป็นสตางค์ · เก็บเป็น Stripe application fee และคืนให้ร้านเมื่อคืนเงิน</li>
          <li>เงินค่าอาหารที่ลูกค้าจ่ายผ่าน Stripe เข้าบัญชีร้านโดยตรง และ Stripe โอนเข้าธนาคารของร้านอัตโนมัติ</li>
        </ul>
        <Link href={href({ view: "gp" })} className="mt-3 inline-block text-sm underline">ตั้งค่า GP รายร้าน</Link>
      </section>
    </>
  );
}

function StoreLink({ id, name, linkable }: { id: string; name: string; linkable: boolean }) {
  if (!linkable) return <span className="font-medium">{name}</span>;
  return (
    <Link href={`/food/stores/${id}?tab=finance`} className="font-medium hover:underline">
      {name}
    </Link>
  );
}

function StoresTable({ data, canOpenStores }: { data: MerchantFinanceOverview; canOpenStores: boolean }) {
  if (data.stores.length === 0) return <Empty text="ยังไม่มีร้านค้า" />;
  return (
    <section className="overflow-x-auto rounded-xl border bg-background">
      <table className="w-full min-w-[960px] text-sm">
        <caption className="sr-only">รายได้แต่ละร้านในช่วงเวลาที่เลือก</caption>
        <thead className="border-b text-left text-xs text-muted-foreground">
          <tr>
            <th scope="col" className="px-4 py-3 font-medium">ร้าน</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ออเดอร์</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ยอดขายสุทธิ</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">คืนเงิน</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ค่าโฆษณา</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ส่วนแบ่ง WYNOS</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">GP</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">รายได้ร้าน</th>
            <th scope="col" className="px-4 py-3 font-medium">การรับเงิน (Stripe)</th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {data.stores.map((store) => (
            <tr key={store.store_id}>
              <td className="px-4 py-3">
                <div className="flex flex-wrap items-center gap-2">
                  <StoreLink id={store.store_id} name={store.store_name} linkable={canOpenStores} />
                  {store.suspended ? <Badge variant="destructive">ระงับ</Badge> : !store.is_published ? <Badge variant="outline">ยังไม่เผยแพร่</Badge> : null}
                </div>
              </td>
              <td className="px-3 py-3 text-right tabular-nums">{store.orders.toLocaleString("th-TH")}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.sales_net)}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.refunds)}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.ad_spend)}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.platform_funded)}</td>
              <td className="px-3 py-3 text-right tabular-nums">
                {formatBaht(store.gp ?? 0)}
                <span className="block text-[11px] text-muted-foreground">{formatGpRate(store.gp_rate_bp ?? 0)}</span>
              </td>
              <td className="px-3 py-3 text-right font-medium tabular-nums">{formatBaht(store.income)}</td>
              <td className="px-4 py-3"><StripeCell store={store} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function StripeCell({ store }: { store: MerchantFinanceOverview["stores"][number] }) {
  if (!store.stripe_status) return <span className="text-muted-foreground">ยังไม่มีบัญชี</span>;
  return (
    <div className="flex flex-col gap-0.5">
      <span className="flex flex-wrap items-center gap-1.5">
        <Badge variant={store.stripe_status === "restricted" ? "destructive" : store.stripe_payouts_enabled ? "ink-solid" : "outline"}>
          {STRIPE_STATUS_LABEL[store.stripe_status]}
        </Badge>
        {store.stripe_livemode === false ? <Badge variant="outline">Test mode</Badge> : null}
      </span>
      <span className="text-xs text-muted-foreground">
        {store.stripe_bank_last4 ? `บัญชีลงท้าย ••${store.stripe_bank_last4}` : "ยังไม่มีบัญชีธนาคาร"}
        {store.stripe_payout_interval ? ` · โอน${PAYOUT_INTERVAL_LABEL[store.stripe_payout_interval] ?? store.stripe_payout_interval}` : ""}
      </span>
    </div>
  );
}

function Owed({ data, canOpenStores }: { data: MerchantFinanceOverview; canOpenStores: boolean }) {
  const owed = data.stores.filter((store) => Number(store.platform_owed) > 0);
  return (
    <section className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">
        ส่วนแบ่งแคมเปญที่ WYNOS ยังค้างโอนให้ร้าน ณ ตอนนี้ (ไม่ขึ้นกับช่วงเวลา) · การบันทึกการโอนทำได้ที่{" "}
        <Link href="/food/campaigns" className="underline">Campaigns</Link> ซึ่งตรวจยอดซ้ำและป้องกันการโอนซ้ำฝั่งฐานข้อมูล
      </p>
      {owed.length === 0 ? (
        <Empty text="ไม่มียอดค้างโอน" />
      ) : (
        <ul className="flex flex-col divide-y rounded-xl border bg-background">
          {owed.map((store) => (
            <li key={store.store_id} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
              <div className="min-w-0">
                <StoreLink id={store.store_id} name={store.store_name} linkable={canOpenStores} />
                <p className="text-xs text-muted-foreground">โอนล่าสุด {formatThaiDate(store.last_settled_at)}</p>
              </div>
              <p className="font-semibold tabular-nums">{formatBaht(store.platform_owed)}</p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function Payouts({ data, canOpenStores }: { data: MerchantFinanceOverview; canOpenStores: boolean }) {
  return (
    <section className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">
        Stripe โอนเงินเข้าบัญชีธนาคารของร้านอัตโนมัติ — หน้านี้แสดงสถานะที่ได้จาก Stripe webhook เท่านั้น ไม่มีปุ่มจ่ายเงิน (แสดงสูงสุด 200 รายการ)
      </p>
      <div className="flex flex-wrap gap-2">
        {(Object.keys(PAYOUT_STATUS_LABEL) as Array<keyof typeof PAYOUT_STATUS_LABEL>).map((status) => (
          <Badge key={status} variant={status === "failed" && data.payout_status_counts.failed ? "destructive" : "outline"}>
            {PAYOUT_STATUS_LABEL[status]} {(data.payout_status_counts[status] ?? 0).toLocaleString("th-TH")}
          </Badge>
        ))}
      </div>
      {data.payouts.length === 0 ? (
        <Empty text="ไม่มีการโอนในช่วงนี้" />
      ) : (
        <ul className="flex flex-col divide-y rounded-xl border bg-background">
          {data.payouts.map((payout) => (
            <li key={payout.payout_id} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
              <div className="min-w-0">
                <StoreLink id={payout.store_id} name={payout.store_name} linkable={canOpenStores} />
                <p className="text-xs text-muted-foreground">
                  สร้าง {formatThaiDate(payout.stripe_created_at)}
                  {payout.arrival_date ? ` · ถึงบัญชี ${payout.arrival_date}` : ""}
                  {payout.failure_code ? ` · ${payout.failure_code}` : ""}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant={payout.status === "failed" ? "destructive" : payout.status === "paid" ? "ink-solid" : "outline"}>
                  {PAYOUT_STATUS_LABEL[payout.status] ?? payout.status}
                </Badge>
                <span className="font-semibold tabular-nums">{formatSatang(payout.amount_satang)}</span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function History({ data, canOpenStores }: { data: MerchantFinanceOverview; canOpenStores: boolean }) {
  return (
    <section className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">การโอนส่วนแบ่งแคมเปญที่ WYNOS บันทึกไว้ในช่วงนี้ (แสดงสูงสุด 200 รายการ)</p>
      {data.settlements.length === 0 ? (
        <Empty text="ไม่มีประวัติการโอนในช่วงนี้" />
      ) : (
        <ul className="flex flex-col divide-y rounded-xl border bg-background">
          {data.settlements.map((row) => (
            <li key={row.id} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
              <div className="min-w-0">
                <StoreLink id={row.store_id} name={row.store_name} linkable={canOpenStores} />
                <p className="text-xs text-muted-foreground">
                  {formatThaiDate(row.created_at)} · {row.order_count.toLocaleString("th-TH")} ออเดอร์ · อ้างอิง {row.reference}
                  {row.settled_by_username ? ` · โดย @${row.settled_by_username}` : ""}
                </p>
              </div>
              <p className="font-semibold tabular-nums">{formatBaht(row.amount)}</p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

async function GpSection({ before }: { before: { at: string; id: string } | null }) {
  let gp: GpSettings;
  let history: Awaited<ReturnType<typeof fetchGpHistory>>;
  try {
    [gp, history] = await Promise.all([fetchGpSettings(), fetchGpHistory(before)]);
  } catch {
    return <Empty text="ระบบ GP ยังไม่ได้ติดตั้งบนฐานข้อมูลนี้ หรือโหลดไม่สำเร็จ" />;
  }
  const own = gp.stores.filter((store) => store.source === "store" || store.next);
  const when = (iso: string) => formatThaiDate(iso);
  const nextLabel = (next: NonNullable<GpSettings["default"]["next"]>) =>
    next.kind === "expiry"
      ? `อัตราชั่วคราวหมด ${when(next.effective_from)} → ${formatGpRate(next.rate_bp)}`
      : next.kind === "default_change"
        ? `GP เริ่มต้นเปลี่ยน ${when(next.effective_from)} → ${formatGpRate(next.rate_bp)}`
        : `ตั้งไว้: ${formatGpRate(next.rate_bp)} ตั้งแต่ ${when(next.effective_from)}`;

  return (
    <section className="flex flex-col gap-4">
      <div className="rounded-xl border bg-background p-4 text-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-xs text-muted-foreground">GP เริ่มต้น (ทุกร้านที่ไม่มีอัตราเฉพาะ)</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">{formatGpRate(gp.default.rate_bp)}</p>
            {gp.default.next ? (
              <p className="mt-1 text-xs text-muted-foreground">
                {nextLabel(gp.default.next)}
              </p>
            ) : null}
          </div>
          {gp.can_edit ? (
            <div className="flex flex-wrap gap-2">
              <GpRateDialog storeId={null} storeName="GP เริ่มต้นทุกร้าน" currentRateBp={gp.default.rate_bp} triggerLabel="แก้ GP เริ่มต้น" />
              {gp.default.next?.id ? <GpCancelButton rateId={gp.default.next.id} label={`GP เริ่มต้น ${gpRowLabel(gp.default.next.rate_bp)}`} /> : null}
            </div>
          ) : null}
        </div>
        <p className="mt-3 text-xs text-muted-foreground">
          คิดจากค่าอาหารหลังส่วนลดของร้าน ไม่รวมค่าส่ง · เก็บเป็น Stripe application fee · แต่ละออเดอร์บันทึกอัตรา ณ เวลาสั่ง การแก้ภายหลังไม่เปลี่ยนยอดย้อนหลัง ·
          {gp.can_edit ? " คุณแก้ไขได้ (super admin)" : " แก้ไขได้เฉพาะ super admin"}
        </p>
      </div>

      <div className="overflow-x-auto rounded-xl border bg-background">
        <table className="w-full min-w-[640px] text-sm">
          <caption className="sr-only">GP รายร้าน</caption>
          <thead className="border-b text-left text-xs text-muted-foreground">
            <tr>
              <th scope="col" className="px-4 py-3 font-medium">ร้าน</th>
              <th scope="col" className="px-3 py-3 text-right font-medium">GP ปัจจุบัน</th>
              <th scope="col" className="px-3 py-3 font-medium">ที่มา</th>
              <th scope="col" className="px-3 py-3 font-medium">ตั้งเวลาไว้</th>
              {gp.can_edit ? <th scope="col" className="px-4 py-3 text-right font-medium">จัดการ</th> : null}
            </tr>
          </thead>
          <tbody className="divide-y">
            {gp.stores.map((store) => (
              <tr key={store.store_id}>
                <td className="px-4 py-3 font-medium">{store.store_name}</td>
                <td className="px-3 py-3 text-right font-semibold tabular-nums">{formatGpRate(store.rate_bp)}</td>
                <td className="px-3 py-3">
                  <Badge variant={store.source === "store" ? "ink-solid" : "outline"}>
                    {store.source === "store" ? "เฉพาะร้าน" : store.source === "default" ? "ค่าเริ่มต้น" : "ไม่มี GP"}
                  </Badge>
                </td>
                <td className="px-3 py-3 text-xs text-muted-foreground">
                  {store.next ? nextLabel(store.next) : "—"}
                </td>
                {gp.can_edit ? (
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap justify-end gap-2">
                      <GpRateDialog storeId={store.store_id} storeName={store.store_name} currentRateBp={store.rate_bp} hasOwnRate={store.source === "store"} />
                      {store.next?.id ? <GpCancelButton rateId={store.next.id} label={`${store.store_name} ${gpRowLabel(store.next.rate_bp)}`} /> : null}
                    </div>
                  </td>
                ) : null}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {own.length === 0 ? <p className="text-xs text-muted-foreground">ยังไม่มีร้านที่ตั้ง GP เฉพาะ</p> : null}

      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-base font-semibold">ประวัติการเปลี่ยนแปลง GP{before ? " (เก่ากว่า)" : ""}</h3>
          {before ? <Link href="/merchant/finance?view=gp" className="text-sm underline">กลับไปล่าสุด</Link> : null}
        </div>
        {history.rows.length === 0 ? (
          <Empty text="ยังไม่เคยตั้ง GP" />
        ) : (
          <ul className="flex flex-col divide-y rounded-xl border bg-background">
            {history.rows.map((row) => (
              <li key={row.id} className="flex flex-col gap-0.5 px-4 py-3 text-sm">
                <p className="font-medium">
                  {row.store_name ?? "GP เริ่มต้นทุกร้าน"} → {gpRowLabel(row.rate_bp)}
                  {row.cancelled_at ? <Badge variant="outline" className="ml-2">ยกเลิกแล้ว</Badge> : null}
                </p>
                <p className="text-xs text-muted-foreground">
                  มีผล {when(row.effective_from)}{row.effective_to ? ` ถึง ${when(row.effective_to)}` : ""} · ตั้งเมื่อ {when(row.created_at)}
                  {row.created_by_username ? ` โดย @${row.created_by_username}` : ""} · เหตุผล: {row.reason}
                </p>
                {gp.can_edit && row.cancellable ? (
                  <div className="pt-1">
                    <GpCancelButton rateId={row.id} label={`${row.store_name ?? "GP เริ่มต้นทุกร้าน"} ${gpRowLabel(row.rate_bp)} ตั้งแต่ ${when(row.effective_from)}`} />
                  </div>
                ) : null}
                {row.cancelled_at ? (
                  <p className="text-xs text-muted-foreground">
                    ยกเลิก {when(row.cancelled_at)}{row.cancelled_by_username ? ` โดย @${row.cancelled_by_username}` : ""} · {row.cancel_reason}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
        {history.has_more && history.rows.length > 0 ? (
          <Link
            href={`/merchant/finance?view=gp&gp_before=${encodeURIComponent(history.rows[history.rows.length - 1].created_at)}&gp_before_id=${history.rows[history.rows.length - 1].id}`}
            className="w-fit text-sm underline"
          >
            ดูประวัติเก่ากว่านี้
          </Link>
        ) : null}
      </div>
    </section>
  );
}

function Empty({ text }: { text: string }) {
  return <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">{text}</p>;
}
