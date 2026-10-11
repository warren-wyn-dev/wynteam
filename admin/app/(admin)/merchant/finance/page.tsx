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
import { cn } from "@/lib/utils";

const VIEWS = [
  { value: "overview", label: "ภาพรวมการเงิน" },
  { value: "stores", label: "รายได้ร้านค้า" },
  { value: "owed", label: "ยอดค้างจ่าย" },
  { value: "payouts", label: "การจ่ายเงินให้ร้านค้า" },
  { value: "history", label: "ประวัติการโอน" },
  { value: "gp", label: "GP / ค่าคอมมิชชัน" },
] as const;
type View = (typeof VIEWS)[number]["value"];

/**
 * WYNOS Merchant -> การเงินร้านค้า. Read only: numbers come from
 * admin_merchant_finance_overview (merchant:view), which uses the same lines
 * as each store's own finance page. Money only moves through the existing
 * flows (Stripe Connect automatic payouts; WYNOS campaign settlements on
 * /food/campaigns) -- nothing here pays, refunds or changes a rate.
 */
export default async function MerchantFinancePage({
  searchParams,
}: {
  searchParams: Promise<{ view?: string; range?: string; from?: string; to?: string }>;
}) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "merchant")) return <NoAccess what=" WYNOS Merchant" />;

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
            ยอดขาย รายได้ และการจ่ายเงินของทุกร้าน (อ่านอย่างเดียว) · ตัวเลขชุดเดียวกับหน้าการเงินของร้านใน merchant.wynos.online
          </p>
        </div>
        <RefreshButton />
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
        <GpPending />
      ) : (
        <>
          <RangeBar range={range} href={href} />
          {loadError ? (
            <p role="alert" className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
              {loadError === "missing"
                ? "ระบบการเงินร้านค้าใน Admin ยังไม่ได้ติดตั้งบนฐานข้อมูลนี้ (รอ Founder อนุมัติ apply migration)"
                : "โหลดข้อมูลการเงินไม่สำเร็จ ลองกดรีเฟรชอีกครั้ง"}
            </p>
          ) : data ? (
            <>
              {view === "overview" ? <Overview data={data} href={href} /> : null}
              {view === "stores" ? <StoresTable data={data} /> : null}
              {view === "owed" ? <Owed data={data} /> : null}
              {view === "payouts" ? <Payouts data={data} /> : null}
              {view === "history" ? <History data={data} /> : null}
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
}: {
  range: ReturnType<typeof resolveFinanceRange>;
  href: (next: { range?: string; from?: string; to?: string }) => string;
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
        <Figure label="รายได้ GP ของแพลตฟอร์ม" value="—" hint="ยังไม่มี GP ในระบบ (รอการตัดสินใจทางธุรกิจ)" />
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
          <li>รายได้ร้าน = ยอดขายสุทธิ − ค่าโฆษณา + ส่วนแบ่งแคมเปญ WYNOS (สูตรเดียวกับหน้าการเงินของร้าน)</li>
          <li>เงินค่าอาหารที่ลูกค้าจ่ายผ่าน Stripe เข้าบัญชีร้านโดยตรง และ Stripe โอนเข้าธนาคารของร้านอัตโนมัติ</li>
        </ul>
        <Link href={href({ view: "gp" })} className="mt-3 inline-block text-sm underline">ทำไมยังไม่มี GP?</Link>
      </section>
    </>
  );
}

function StoreLink({ id, name }: { id: string; name: string }) {
  return (
    <Link href={`/food/stores/${id}?tab=finance`} className="font-medium hover:underline">
      {name}
    </Link>
  );
}

function StoresTable({ data }: { data: MerchantFinanceOverview }) {
  if (data.stores.length === 0) return <Empty text="ยังไม่มีร้านค้า" />;
  return (
    <section className="overflow-x-auto rounded-xl border bg-background">
      <table className="w-full min-w-[880px] text-sm">
        <caption className="sr-only">รายได้แต่ละร้านในช่วงเวลาที่เลือก</caption>
        <thead className="border-b text-left text-xs text-muted-foreground">
          <tr>
            <th scope="col" className="px-4 py-3 font-medium">ร้าน</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ออเดอร์</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ยอดขายสุทธิ</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">คืนเงิน</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ค่าโฆษณา</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">ส่วนแบ่ง WYNOS</th>
            <th scope="col" className="px-3 py-3 text-right font-medium">รายได้ร้าน</th>
            <th scope="col" className="px-4 py-3 font-medium">การรับเงิน (Stripe)</th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {data.stores.map((store) => (
            <tr key={store.store_id}>
              <td className="px-4 py-3">
                <div className="flex flex-wrap items-center gap-2">
                  <StoreLink id={store.store_id} name={store.store_name} />
                  {store.suspended ? <Badge variant="destructive">ระงับ</Badge> : !store.is_published ? <Badge variant="outline">ยังไม่เผยแพร่</Badge> : null}
                </div>
              </td>
              <td className="px-3 py-3 text-right tabular-nums">{store.orders.toLocaleString("th-TH")}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.sales_net)}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.refunds)}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.ad_spend)}</td>
              <td className="px-3 py-3 text-right tabular-nums">{formatBaht(store.platform_funded)}</td>
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

function Owed({ data }: { data: MerchantFinanceOverview }) {
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
                <StoreLink id={store.store_id} name={store.store_name} />
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

function Payouts({ data }: { data: MerchantFinanceOverview }) {
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
                <StoreLink id={payout.store_id} name={payout.store_name} />
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

function History({ data }: { data: MerchantFinanceOverview }) {
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
                <StoreLink id={row.store_id} name={row.store_name} />
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

const GP_DECISIONS = [
  "WYNOS จะเริ่มเก็บ GP หรือไม่ และเริ่มเมื่อไร (วันนี้ร้านได้รับเงินเต็มจำนวนผ่าน Stripe)",
  "อัตรา GP เริ่มต้น และใครมีสิทธิ์ตั้ง GP เฉพาะร้าน / ใครอนุมัติ",
  "ฐานคำนวณ GP: ค่าอาหารก่อนหรือหลังส่วนลดร้าน / ส่วนลดแพลตฟอร์ม, รวมค่าส่งหรือไม่",
  "วิธีเก็บเงิน: Stripe application fee ต่อออเดอร์ หรือหักตอนสรุปยอด (กระทบสัญญากับร้านและ Stripe)",
  "ภาษี (VAT / ภาษีหัก ณ ที่จ่าย) และการออกใบกำกับภาษีค่า GP",
  "การปัดเศษ (สตางค์) และการคืน GP เมื่อคืนเงินเต็มจำนวน / บางส่วน / ยกเลิก",
  "รอบสรุปยอดและการจ่ายเงินร้าน หากไม่ใช้ Stripe automatic payout",
];

function GpPending() {
  return (
    <section className="flex flex-col gap-4">
      <div className="rounded-xl border border-dashed bg-background p-5 text-sm">
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-semibold">ตั้งค่า GP รายร้าน · ค่าคอมมิชชัน · รายการปรับปรุงยอด</p>
          <Badge variant="outline">รอการตัดสินใจทางธุรกิจ</Badge>
        </div>
        <p className="mt-2 text-muted-foreground">
          ตอนนี้ WYNOS ยังไม่มี GP หรือค่าคอมมิชชันในระบบจริง: เงินที่ลูกค้าจ่ายเข้าบัญชี Stripe ของร้านโดยตรง
          และรายได้ร้านในหน้าการเงินของร้านไม่ได้หัก GP — การเปิดหน้าตั้งค่า GP ตอนนี้จะเป็นปุ่มที่ไม่มีผลจริง จึงยังไม่เปิดให้ใช้
        </p>
        <p className="mt-3 font-medium">ต้องให้ Founder ตัดสินใจก่อนพัฒนา:</p>
        <ol className="mt-2 list-decimal space-y-1 pl-5 text-muted-foreground">
          {GP_DECISIONS.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ol>
        <p className="mt-3 text-muted-foreground">
          เมื่ออนุมัติแล้ว GP จะเก็บเป็นประวัติแบบมีวันเริ่มมีผล, เหตุผล, ผู้แก้ไข และขั้นอนุมัติ และแต่ละออเดอร์จะบันทึกอัตราที่ใช้ ณ เวลานั้น
          เพื่อไม่ให้การแก้ GP ภายหลังเปลี่ยนยอดย้อนหลัง
        </p>
      </div>
    </section>
  );
}

function Empty({ text }: { text: string }) {
  return <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">{text}</p>;
}
