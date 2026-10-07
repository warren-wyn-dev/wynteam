import Link from "next/link";
import { redirect } from "next/navigation";
import {
  BadgeDollarSign,
  Bike,
  CreditCard,
  Flag,
  Landmark,
  Percent,
  ReceiptText,
  Settings2,
  ShieldCheck,
  Store,
  Tags,
  Truck,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { requireAdminRole } from "@/lib/auth";
import {
  fetchFinanceControlSnapshot,
  fetchFinanceDashboard,
  fetchFinanceOperations,
  fetchRiderFinance,
  formatFinanceDate,
  formatSatang,
  percentFromBps,
} from "@/lib/admin-finance";
import {
  addRiderAdjustmentAction,
  createMerchantSettlementAction,
  createRiderPayoutAction,
  createTemporaryGpAction,
  markMerchantSettlementPaidAction,
  markRiderPayoutPaidAction,
  requestAdminRefundAction,
  setDeliveryZonePricingAction,
  setFeatureFlagAction,
  setRiderStatusAction,
  setStoreFinanceAction,
  updateCustomerFeesAction,
  updateDefaultGpAction,
  updateDeliveryPricingAction,
  updatePaymentPolicyAction,
  updateRiderEarningsAction,
  updateTaxAction,
} from "./actions";

const inputClass="h-11 w-full rounded-md border bg-background px-3 text-sm";
const selectClass=inputClass;
const sectionClass="rounded-2xl border bg-background p-5 shadow-sm";
const descriptionClass="text-sm leading-6 text-muted-foreground";

function baht(value: unknown) { return (Number(value ?? 0)/100).toFixed(2); }
function km(value: unknown) { return (Number(value ?? 0)/1000).toFixed(2); }
function bool(value: unknown) { return value === true ? "true" : "false"; }
function localInput(value?: string | null) {
  if (!value) return "";
  const d=new Date(value);
  const shifted=new Date(d.getTime()+7*60*60*1000);
  return shifted.toISOString().slice(0,16);
}
function rangeFor(search: { range?:string; from?:string; to?:string }) {
  const now=new Date();
  const bkk=new Date(now.getTime()+7*60*60*1000);
  const today=bkk.toISOString().slice(0,10);
  const month=today.slice(0,7)+"-01";
  const nextDay=(date:string,days:number)=>{
    const d=new Date(date+"T00:00:00Z");
    d.setUTCDate(d.getUTCDate()+days);
    return d.toISOString().slice(0,10);
  };
  const range=search.range ?? "today";
  if (range==="custom" && search.from && search.to) {
    return { range, from:`${search.from}T00:00:00+07:00`, to:`${nextDay(search.to,1)}T00:00:00+07:00` };
  }
  if (range==="7d") return { range, from:`${nextDay(today,-6)}T00:00:00+07:00`, to:`${nextDay(today,1)}T00:00:00+07:00` };
  if (range==="30d") return { range, from:`${nextDay(today,-29)}T00:00:00+07:00`, to:`${nextDay(today,1)}T00:00:00+07:00` };
  if (range==="month") return { range, from:`${month}T00:00:00+07:00`, to:`${nextDay(today,1)}T00:00:00+07:00` };
  return { range:"today", from:`${today}T00:00:00+07:00`, to:`${nextDay(today,1)}T00:00:00+07:00` };
}
function Field({label,children,help}:{label:string;children:React.ReactNode;help?:string}) {
  return <div className="space-y-2"><Label>{label}</Label>{children}{help?<p className="text-xs text-muted-foreground">{help}</p>:null}</div>;
}
function SaveReason({effective=true}:{effective?:boolean}) {
  return <div className="grid gap-3 md:grid-cols-2">
    {effective?<Field label="มีผลตั้งแต่"><Input name="effective_from" type="datetime-local" /></Field>:null}
    <Field label="เหตุผล (จำเป็น)"><Input name="reason" required maxLength={500} placeholder="เช่น New pricing policy" /></Field>
  </div>;
}
function MoneyCard({label,value,detail}:{label:string;value:unknown;detail?:string}) {
  return <div className="rounded-xl border p-4">
    <p className="text-xs text-muted-foreground">{label}</p>
    <p className="mt-1 text-xl font-semibold tabular-nums">{formatSatang(value as number)}</p>
    {detail?<p className="mt-1 text-xs text-muted-foreground">{detail}</p>:null}
  </div>;
}

export default async function FinanceControlPage({
  searchParams,
}:{
  searchParams:Promise<{range?:string;from?:string;to?:string}>;
}) {
  const auth=await requireAdminRole();
  if(auth.role!=="admin") redirect("/");
  const search=await searchParams;
  const period=rangeFor(search);
  const [snapshot,dashboard,operations,riders]=await Promise.all([
    fetchFinanceControlSnapshot(),
    fetchFinanceDashboard(period.from,period.to),
    fetchFinanceOperations(100),
    fetchRiderFinance(),
  ]);
  const c=snapshot.config;
  const flags=snapshot.flags;
  const pendingSettlements=operations.merchant_settlements.filter((row)=>row.status==="pending");
  const pendingRiderPayouts=operations.rider_payouts.filter((row)=>row.status==="pending");

  return <div className="flex flex-col gap-6 p-6">
    <header className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
      <div>
        <div className="flex items-center gap-2">
          <BadgeDollarSign className="size-6" />
          <h1 className="text-2xl font-semibold tracking-tight">Finance / Platform Control</h1>
        </div>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-muted-foreground">
          ศูนย์ควบคุม GP, Delivery, Rider, Payment, Promotion, Settlement, Refund, Tax และ Feature Flags
          ค่าใหม่มีผลตาม effective time และออเดอร์ใหม่เท่านั้น ออเดอร์เดิมใช้ financial snapshot ของตัวเอง
        </p>
      </div>
      <div className="flex flex-wrap gap-2">
        <Button asChild variant="outline"><Link href="/food/orders">ดูออเดอร์ทั้งหมด</Link></Button>
        <Button asChild variant="outline"><Link href="/audit-log">Audit Log</Link></Button>
      </div>
    </header>

    <section className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><ReceiptText className="size-5"/><h2 className="font-semibold">Finance Dashboard</h2></div>
      <form className="mb-4 flex flex-wrap items-end gap-2" action="/finance">
        <Field label="ช่วงเวลา">
          <select name="range" defaultValue={period.range} className={selectClass}>
            <option value="today">วันนี้</option><option value="7d">7 วัน</option><option value="30d">30 วัน</option>
            <option value="month">เดือนนี้</option><option value="custom">กำหนดเอง</option>
          </select>
        </Field>
        <Field label="จาก"><Input name="from" type="date" defaultValue={search.from}/></Field>
        <Field label="ถึง"><Input name="to" type="date" defaultValue={search.to}/></Field>
        <Button type="submit">ดูข้อมูล</Button>
      </form>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <MoneyCard label="Gross Order Value" value={dashboard.gross_order_value_satang}/>
        <div className="rounded-xl border p-4"><p className="text-xs text-muted-foreground">Orders</p><p className="mt-1 text-xl font-semibold">{dashboard.orders.toLocaleString("th-TH")}</p></div>
        <MoneyCard label="WYNOS GP Revenue" value={dashboard.gp_revenue_satang}/>
        <MoneyCard label="Delivery Revenue" value={dashboard.delivery_revenue_satang}/>
        <MoneyCard label="Stripe Fees" value={dashboard.stripe_fees_satang}/>
        <MoneyCard label="Merchant Net" value={dashboard.merchant_net_satang}/>
        <MoneyCard label="Rider Earnings" value={dashboard.rider_earnings_satang}/>
        <MoneyCard label="Refunds" value={dashboard.refunds_satang}/>
        <MoneyCard label="Promotion Cost" value={dashboard.promotion_cost_satang}/>
        <MoneyCard label="Net Platform Revenue" value={dashboard.net_platform_revenue_satang}/>
      </div>
      {dashboard.legacy_orders_without_snapshot>0?<p className="mt-3 text-xs text-muted-foreground">
        มีออเดอร์เก่า {dashboard.legacy_orders_without_snapshot} รายการในช่วงนี้ที่เกิดก่อน Financial Snapshot — แสดงแบบ legacy fallback และไม่ถูกคำนวณย้อนหลัง
      </p>:null}
    </section>

    <section id="pricing" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Percent className="size-5"/><h2 className="font-semibold">Pricing · GP / Commission</h2></div>
      <p className={descriptionClass}>ลำดับ GP: Temporary Promotion → Custom Store GP → Default Platform GP ทุกออเดอร์ snapshot GP ตอนสร้างทันที</p>
      <form action={updateDefaultGpAction} className="mt-4 grid gap-4">
        <Field label="Default Platform GP (%)" help="ค่าเริ่มต้นปัจจุบัน 10% และไม่เปลี่ยนออเดอร์ย้อนหลัง">
          <Input name="default_gp_percent" type="number" min="0" max="100" step="0.01" required defaultValue={percentFromBps(c.default_gp_bps)}/>
        </Field>
        <SaveReason/><Button className="w-fit" type="submit">บันทึก Default GP</Button>
      </form>
    </section>

    <section id="delivery" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Truck className="size-5"/><h2 className="font-semibold">Delivery Pricing</h2></div>
      <p className={descriptionClass}>สูตรทั้งหมดอยู่ฝั่ง server และใช้สตางค์เป็นหน่วยคำนวณ ร้านเดิมถูก preserve ค่าเดิมด้วย store override ตอน migration</p>
      <form action={updateDeliveryPricingAction} className="mt-4 grid gap-4">
        <div className="grid gap-3 md:grid-cols-3">
          <Field label="Base fee (บาท)"><Input name="base_fee" type="number" step="0.01" min="0" required defaultValue={baht(c.delivery_base_fee_satang)}/></Field>
          <Field label="ระยะเริ่มต้น (กม.)"><Input name="base_distance_km" type="number" step="0.1" min="0" required defaultValue={km(c.delivery_base_distance_m)}/></Field>
          <Field label="เพิ่มต่อกม. (บาท)"><Input name="per_km" type="number" step="0.01" min="0" required defaultValue={baht(c.delivery_per_km_satang)}/></Field>
          <Field label="Minimum fee (บาท)"><Input name="min_fee" type="number" step="0.01" min="0" required defaultValue={baht(c.delivery_min_fee_satang)}/></Field>
          <Field label="Maximum fee (บาท)"><Input name="max_fee" type="number" step="0.01" min="0" defaultValue={c.delivery_max_fee_satang==null?"":baht(c.delivery_max_fee_satang)}/></Field>
          <Field label="Distance rounding (กม.)"><Input name="rounding_km" type="number" step="0.1" min="0.1" required defaultValue={km(c.delivery_rounding_m)}/></Field>
          <Field label="Free delivery threshold (บาท)"><Input name="free_delivery_threshold" type="number" step="0.01" min="0" defaultValue={c.free_delivery_threshold_satang==null?"":baht(c.free_delivery_threshold_satang)}/></Field>
          <Field label="Long distance เริ่มที่ (กม.)"><Input name="long_distance_km" type="number" step="0.1" min="0" defaultValue={c.long_distance_threshold_m==null?"":km(c.long_distance_threshold_m)}/></Field>
          <Field label="Long distance surcharge (บาท)"><Input name="long_distance_surcharge" type="number" step="0.01" min="0" required defaultValue={baht(c.long_distance_surcharge_satang)}/></Field>
          <Field label="Peak surcharge (บาท)"><Input name="peak_surcharge" type="number" step="0.01" min="0" required defaultValue={baht(c.peak_surcharge_satang)}/></Field>
          <Field label="Rain surcharge (บาท)"><Input name="rain_surcharge" type="number" step="0.01" min="0" required defaultValue={baht(c.rain_surcharge_satang)}/></Field>
        </div>
        <SaveReason/><Button className="w-fit" type="submit">บันทึก Delivery Pricing</Button>
      </form>

      <div className="my-6 border-t"/>
      <h3 className="font-medium">Zone / Province Pricing</h3>
      <p className={descriptionClass}>Store override มี priority สูงสุด ตามด้วย Service Area แล้ว Province และสุดท้าย Platform Default</p>
      <form action={setDeliveryZonePricingAction} className="mt-4 grid gap-4">
        <div className="grid gap-3 md:grid-cols-4">
          <Field label="Service Area code"><Input name="service_area_code" placeholder="เช่น maha_sarakham"/></Field>
          <Field label="Province"><Input name="province" placeholder="เช่น มหาสารคาม"/></Field>
          <Field label="Priority"><Input name="priority" type="number" defaultValue="100" required/></Field>
          <Field label="Base fee (บาท)"><Input name="base_fee" type="number" step="0.01" min="0"/></Field>
          <Field label="Base distance (กม.)"><Input name="base_distance_km" type="number" step="0.1" min="0"/></Field>
          <Field label="Per km (บาท)"><Input name="per_km" type="number" step="0.01" min="0"/></Field>
          <Field label="Min fee"><Input name="min_fee" type="number" step="0.01" min="0"/></Field>
          <Field label="Max fee"><Input name="max_fee" type="number" step="0.01" min="0"/></Field>
          <Field label="Rounding km"><Input name="rounding_km" type="number" step="0.1" min="0.1"/></Field>
          <Field label="Free delivery threshold"><Input name="free_delivery_threshold" type="number" step="0.01" min="0"/></Field>
          <Field label="เริ่ม"><Input name="effective_from" type="datetime-local"/></Field>
          <Field label="สิ้นสุด"><Input name="effective_to" type="datetime-local"/></Field>
        </div>
        <Field label="เหตุผล"><Input name="reason" required maxLength={500}/></Field>
        <Button className="w-fit" type="submit">เพิ่ม Zone / Province Rule</Button>
      </form>
    </section>

    <section id="payments" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><CreditCard className="size-5"/><h2 className="font-semibold">Payments</h2></div>
      <p className={descriptionClass}>Production เริ่ม PromptPay-only ผ่าน Stripe Connected Account หากร้านยังไม่พร้อม PromptPay ระบบหยุดชำระและไม่ fallback ไป Card</p>
      <form action={updatePaymentPolicyAction} className="mt-4 grid gap-4">
        <div className="grid gap-3 md:grid-cols-4">
          {[
            ["promptpay_enabled","PromptPay"],["card_enabled","Card"],["apple_pay_enabled","Apple Pay"],["google_pay_enabled","Google Pay"],
          ].map(([key,label])=><Field key={key} label={label}>
            <select className={selectClass} name={key} defaultValue={bool(flags[key])}><option value="true">ON</option><option value="false">OFF</option></select>
          </Field>)}
          <Field label="Stripe Fee ผู้รับภาระ">
            <select name="stripe_fee_payer" className={selectClass} defaultValue={c.stripe_fee_payer}>
              <option value="wynos">WYNOS</option><option value="merchant">Merchant</option><option value="shared">Shared</option>
            </select>
          </Field>
          <Field label="Merchant share เมื่อ Shared (%)"><Input name="stripe_shared_merchant_percent" type="number" min="0" max="100" step="0.01" required defaultValue={percentFromBps(c.stripe_shared_merchant_bps)}/></Field>
        </div>
        <SaveReason/><Button className="w-fit" type="submit">บันทึก Payment Policy</Button>
      </form>
    </section>

    <section id="customer-fees" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Tags className="size-5"/><h2 className="font-semibold">Customer Fees</h2></div>
      <p className={descriptionClass}>Service Fee, Small Order Fee และ Surge ปิดเป็นค่าเริ่มต้น เปิดภายหลังได้โดยไม่แก้ frontend</p>
      <form action={updateCustomerFeesAction} className="mt-4 grid gap-4">
        <div className="grid gap-3 md:grid-cols-4">
          <Field label="Service Fee"><select name="service_fee_enabled" className={selectClass} defaultValue={bool(flags.service_fee_enabled)}><option value="false">OFF</option><option value="true">ON</option></select></Field>
          <Field label="Service mode"><select name="service_fee_mode" className={selectClass} defaultValue={c.service_fee_mode}><option value="fixed">บาท</option><option value="percent">%</option></select></Field>
          <Field label="Service value"><Input name="service_fee_value" type="number" step="0.01" min="0" required defaultValue={c.service_fee_mode==="percent"?percentFromBps(c.service_fee_value):baht(c.service_fee_value)}/></Field>
          <Field label="Service min (บาท)"><Input name="service_fee_min" type="number" step="0.01" min="0" required defaultValue={baht(c.service_fee_min_satang)}/></Field>
          <Field label="Service max (บาท)"><Input name="service_fee_max" type="number" step="0.01" min="0" defaultValue={c.service_fee_max_satang==null?"":baht(c.service_fee_max_satang)}/></Field>

          <Field label="Small Order Fee"><select name="small_order_fee_enabled" className={selectClass} defaultValue={bool(flags.small_order_fee_enabled)}><option value="false">OFF</option><option value="true">ON</option></select></Field>
          <Field label="Small order threshold (บาท)"><Input name="small_order_threshold" type="number" step="0.01" min="0" required defaultValue={baht(c.small_order_threshold_satang)}/></Field>
          <Field label="Small order mode"><select name="small_order_fee_mode" className={selectClass} defaultValue={c.small_order_fee_mode}><option value="fixed">บาท</option><option value="percent">%</option></select></Field>
          <Field label="Small order value"><Input name="small_order_fee_value" type="number" step="0.01" min="0" required defaultValue={c.small_order_fee_mode==="percent"?percentFromBps(c.small_order_fee_value):baht(c.small_order_fee_value)}/></Field>
          <Field label="Small order max (บาท)"><Input name="small_order_fee_max" type="number" step="0.01" min="0" defaultValue={c.small_order_fee_max_satang==null?"":baht(c.small_order_fee_max_satang)}/></Field>

          <Field label="Surge Fee"><select name="surge_pricing_enabled" className={selectClass} defaultValue={bool(flags.surge_pricing_enabled)}><option value="false">OFF</option><option value="true">ON</option></select></Field>
          <Field label="Surge mode"><select name="surge_fee_mode" className={selectClass} defaultValue={c.surge_fee_mode}><option value="fixed">บาท</option><option value="percent">%</option></select></Field>
          <Field label="Surge value"><Input name="surge_fee_value" type="number" step="0.01" min="0" required defaultValue={c.surge_fee_mode==="percent"?percentFromBps(c.surge_fee_value):baht(c.surge_fee_value)}/></Field>
          <Field label="Surge max (บาท)"><Input name="surge_fee_max" type="number" step="0.01" min="0" defaultValue={c.surge_fee_max_satang==null?"":baht(c.surge_fee_max_satang)}/></Field>
        </div>
        <SaveReason/><Button className="w-fit" type="submit">บันทึก Customer Fees</Button>
      </form>
    </section>

    <section id="merchant-controls" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Store className="size-5"/><h2 className="font-semibold">Merchant Controls / GP</h2></div>
      <p className={descriptionClass}>ตั้ง Custom GP, Payment, Payout hold, Promotion eligibility และ Delivery override ต่อร้าน ค่าที่เปลี่ยนมีผลกับออเดอร์ใหม่เท่านั้น</p>
      <div className="mt-4 space-y-4">
        {snapshot.stores.map((store)=><div key={store.id} className="rounded-xl border p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <div><p className="font-medium">{store.name}</p><p className="text-xs text-muted-foreground">{store.slug}</p></div>
            <div className="flex gap-2"><Badge>{percentFromBps(store.gp_bps)}% GP</Badge><Badge variant="outline">{store.gp_source}</Badge>{store.payment_ready?<Badge>Stripe ready</Badge>:<Badge variant="outline">Stripe not ready</Badge>}</div>
          </div>
          <form action={setStoreFinanceAction} className="grid gap-3">
            <input type="hidden" name="store_id" value={store.id}/>
            <div className="grid gap-3 md:grid-cols-4">
              <Field label="Custom GP (%)"><Input name="custom_gp_percent" type="number" min="0" max="100" step="0.01" placeholder="ว่าง = ใช้ Default"/></Field>
              <Field label="Payment"><select name="payment_enabled" className={selectClass} defaultValue={bool(store.payment_enabled)}><option value="true">ON</option><option value="false">OFF</option></select></Field>
              <Field label="Payout"><select name="payout_suspended" className={selectClass} defaultValue={bool(store.payout_suspended)}><option value="false">Active</option><option value="true">Suspended</option></select></Field>
              <Field label="Promotion"><select name="promotion_eligible" className={selectClass} defaultValue={bool(store.promotion_eligible)}><option value="true">Eligible</option><option value="false">Not eligible</option></select></Field>
              <Field label="Delivery base (บาท)"><Input name="delivery_base_fee" type="number" step="0.01" min="0" placeholder="ว่าง = inherit"/></Field>
              <Field label="Base distance (กม.)"><Input name="delivery_base_distance_km" type="number" step="0.1" min="0" placeholder="inherit"/></Field>
              <Field label="Per km (บาท)"><Input name="delivery_per_km" type="number" step="0.01" min="0" placeholder="inherit"/></Field>
              <Field label="Delivery min"><Input name="delivery_min_fee" type="number" step="0.01" min="0" placeholder="inherit"/></Field>
              <Field label="Delivery max"><Input name="delivery_max_fee" type="number" step="0.01" min="0" placeholder="inherit"/></Field>
              <Field label="Rounding km"><Input name="delivery_rounding_km" type="number" step="0.1" min="0.1" placeholder="inherit"/></Field>
              <Field label="Free delivery threshold"><Input name="free_delivery_threshold" type="number" step="0.01" min="0" placeholder="inherit"/></Field>
            </div>
            <SaveReason/><Button type="submit" variant="outline" className="w-fit">บันทึกค่าร้าน</Button>
          </form>
          <form action={createTemporaryGpAction} className="mt-4 grid gap-3 border-t pt-4">
            <input type="hidden" name="store_id" value={store.id}/>
            <p className="text-sm font-medium">Temporary GP / ร้านใหม่ 0%</p>
            <div className="grid gap-3 md:grid-cols-4">
              <Field label="GP (%)"><Input name="gp_percent" type="number" min="0" max="100" step="0.01" required/></Field>
              <Field label="เริ่ม"><Input name="starts_at" type="datetime-local" required/></Field>
              <Field label="สิ้นสุด"><Input name="ends_at" type="datetime-local" required/></Field>
              <Field label="เหตุผล"><Input name="reason" required maxLength={500}/></Field>
            </div>
            <Button type="submit" variant="outline" className="w-fit">เพิ่ม Temporary GP</Button>
          </form>
        </div>)}
      </div>
    </section>

    <section id="riders" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Bike className="size-5"/><h2 className="font-semibold">Riders</h2></div>
      <div className="mb-3 flex items-center gap-2"><Badge variant={flags.rider_enabled?"ink-solid":"outline"}>Rider {flags.rider_enabled?"ON":"OFF"}</Badge><span className="text-xs text-muted-foreground">Default OFF จนกว่า Production QA ผ่าน</span></div>
      <form action={updateRiderEarningsAction} className="grid gap-4">
        <div className="grid gap-3 md:grid-cols-4">
          <Field label="Base rider pay (บาท)"><Input name="base_pay" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_base_pay_satang)}/></Field>
          <Field label="Pay per km (บาท)"><Input name="per_km" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_pay_per_km_satang)}/></Field>
          <Field label="Minimum earning (บาท)"><Input name="min_earning" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_min_earning_satang)}/></Field>
          <Field label="Long distance (กม.)"><Input name="long_distance_km" type="number" step="0.1" min="0" defaultValue={c.rider_long_distance_threshold_m==null?"":km(c.rider_long_distance_threshold_m)}/></Field>
          <Field label="Long distance bonus"><Input name="long_distance_bonus" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_long_distance_bonus_satang)}/></Field>
          <Field label="Peak bonus"><Input name="peak_bonus" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_peak_bonus_satang)}/></Field>
          <Field label="Rain bonus"><Input name="rain_bonus" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_rain_bonus_satang)}/></Field>
          <Field label="Incentive จำนวนงาน"><Input name="incentive_order_count" type="number" min="1" defaultValue={c.rider_incentive_order_count??""}/></Field>
          <Field label="Incentive bonus"><Input name="incentive_bonus" type="number" step="0.01" min="0" required defaultValue={baht(c.rider_incentive_bonus_satang)}/></Field>
          <Field label="Rider platform fee (%)"><Input name="platform_fee_percent" type="number" min="0" max="100" step="0.01" required defaultValue={percentFromBps(c.rider_platform_fee_bps)}/></Field>
        </div>
        <SaveReason/><Button type="submit" className="w-fit">บันทึก Rider Earnings</Button>
      </form>
      <div className="mt-6 space-y-3">
        {riders.length===0?<p className="rounded-xl border border-dashed p-5 text-sm text-muted-foreground">ยังไม่มี Rider ในระบบ</p>:riders.map((r)=><div key={r.rider_id} className="rounded-xl border p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div><p className="font-medium">@{r.username??r.user_id}</p><p className="text-xs text-muted-foreground">{r.status} · {r.jobs} งาน</p></div>
            <div className="flex flex-wrap gap-2"><Badge variant="outline">Gross {formatSatang(r.gross_earnings_satang)}</Badge><Badge variant="outline">Paid {formatSatang(r.paid_satang)}</Badge><Badge>Pending {formatSatang(r.pending_payout_satang)}</Badge></div>
          </div>
          <form action={setRiderStatusAction} className="mt-3 grid gap-3 md:grid-cols-6">
            <input type="hidden" name="user_id" value={r.user_id}/>
            <Field label="Status"><select name="status" className={selectClass} defaultValue={r.status}><option value="pending">Pending</option><option value="approved">Approved</option><option value="suspended">Suspended</option><option value="inactive">Inactive</option></select></Field>
            <Field label="Active"><select name="active" className={selectClass} defaultValue={bool(r.active)}><option value="true">Active</option><option value="false">Inactive</option></select></Field>
            <Field label="พื้นที่"><Input name="service_area_code" defaultValue={r.service_area_code??""}/></Field>
            <Field label="Payout"><select name="payout_suspended" className={selectClass} defaultValue={bool(r.payout_suspended)}><option value="false">Active</option><option value="true">Suspended</option></select></Field>
            <Field label="เหตุผล"><Input name="reason" required/></Field>
            <div className="flex items-end"><Button type="submit" variant="outline">บันทึก Rider</Button></div>
          </form>
          <div className="mt-3 grid gap-3 border-t pt-3 lg:grid-cols-2">
            <form action={addRiderAdjustmentAction} className="grid gap-2">
              <input type="hidden" name="rider_id" value={r.rider_id}/>
              <p className="text-sm font-medium">Adjustment</p>
              <div className="grid grid-cols-3 gap-2"><Input name="order_id" placeholder="Order ID (optional)"/><Input name="amount_baht" type="number" step="0.01" required placeholder="+/- บาท"/><Input name="reason" required placeholder="เหตุผล"/></div>
              <Button type="submit" variant="outline" className="w-fit">เพิ่ม Adjustment</Button>
            </form>
            <form action={createRiderPayoutAction} className="grid gap-2">
              <input type="hidden" name="rider_id" value={r.rider_id}/>
              <p className="text-sm font-medium">สร้าง Rider Payout</p>
              <div className="grid grid-cols-3 gap-2"><Input name="period_from" type="datetime-local" required/><Input name="period_to" type="datetime-local" required/><Input name="reason" required placeholder="เหตุผล"/></div>
              <Button type="submit" variant="outline" className="w-fit" disabled={!flags.rider_enabled}>สร้าง Payout</Button>
            </form>
          </div>
        </div>)}
      </div>
    </section>

    <section id="tax" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Landmark className="size-5"/><h2 className="font-semibold">Tax / VAT</h2></div>
      <p className={descriptionClass}>VAT Mode ปิดอยู่ จนกว่า Admin เปิดอย่างชัดเจน โครงสร้าง VAT ของร้านและ VAT ค่าบริการ WYNOS แยกจากกันใน settlement layer</p>
      <form action={updateTaxAction} className="mt-4 grid gap-4">
        <div className="grid gap-3 md:grid-cols-3">
          <Field label="Tax enabled"><select name="tax_enabled" className={selectClass} defaultValue={bool(c.tax_enabled)}><option value="false">OFF</option><option value="true">ON</option></select></Field>
          <Field label="WYNOS VAT registered"><select name="vat_registered" className={selectClass} defaultValue={bool(c.vat_registered)}><option value="false">NO</option><option value="true">YES</option></select></Field>
          <Field label="VAT (%)"><Input name="vat_percent" type="number" min="0" max="100" step="0.01" required defaultValue={percentFromBps(c.vat_percent_bps)}/></Field>
        </div>
        <SaveReason/><Button type="submit" className="w-fit">บันทึก Tax Configuration</Button>
      </form>
    </section>

    <section id="features" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Flag className="size-5"/><h2 className="font-semibold">Platform Feature Flags</h2></div>
      <p className={descriptionClass}>Food, Merchant, Admin และ payment backend อ่านจาก source กลางเดียวกัน ไม่สร้าง flag แยกในแต่ละ app</p>
      <div className="mt-4 grid gap-3 md:grid-cols-2">
        {Object.entries(flags).sort(([a],[b])=>a.localeCompare(b)).map(([key,enabled])=><form action={setFeatureFlagAction} key={key} className="flex flex-wrap items-end gap-2 rounded-xl border p-3">
          <input type="hidden" name="flag_key" value={key}/>
          <div className="min-w-56 flex-1"><p className="text-sm font-medium">{key}</p><p className="text-xs text-muted-foreground">{enabled?"ON":"OFF"}</p></div>
          <select name="enabled" className="h-11 rounded-md border bg-background px-3 text-sm" defaultValue={bool(enabled)}><option value="true">ON</option><option value="false">OFF</option></select>
          <Input name="reason" required placeholder="เหตุผล" className="max-w-64"/>
          <Button type="submit" variant="outline">บันทึก</Button>
        </form>)}
      </div>
    </section>

    <section id="operations" className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><Settings2 className="size-5"/><h2 className="font-semibold">Settlement / Refund Operations</h2></div>
      <div className="grid gap-5 xl:grid-cols-2">
        <form action={createMerchantSettlementAction} className="rounded-xl border p-4">
          <h3 className="font-medium">สร้าง Merchant Settlement</h3>
          <p className={descriptionClass}>ระบบ preview และ re-check ยอดบน server ก่อนสร้าง พร้อมป้องกัน order ซ้ำ</p>
          <div className="mt-3 grid gap-3">
            <Field label="ร้าน"><select name="store_id" className={selectClass} required>{snapshot.stores.map(s=><option key={s.id} value={s.id}>{s.name}</option>)}</select></Field>
            <div className="grid grid-cols-2 gap-3"><Field label="จาก"><Input name="period_from" type="datetime-local" required/></Field><Field label="ถึง"><Input name="period_to" type="datetime-local" required/></Field></div>
            <Field label="Note"><Input name="note"/></Field><Field label="เหตุผล"><Input name="reason" required/></Field>
            <Button type="submit">สร้าง Settlement</Button>
          </div>
        </form>
        <form action={requestAdminRefundAction} className="rounded-xl border p-4">
          <h3 className="font-medium">Refund</h3>
          <p className={descriptionClass}>รองรับ Full/Partial และใช้ Stripe account จาก payment ต้นฉบับเท่านั้น Preview environment ถูกบล็อกไม่ให้ทำ live refund</p>
          <input type="hidden" name="request_id" value={crypto.randomUUID()}/>
          <div className="mt-3 grid gap-3">
            <Field label="Order ID"><Input name="order_id" required/></Field>
            <Field label="จำนวนคืน (บาท)" help="เว้นว่าง = คืนยอดที่เหลือทั้งหมด"><Input name="amount_baht" type="number" min="0.01" step="0.01"/></Field>
            <Field label="ผู้รับผิดชอบ"><select name="liability" className={selectClass}><option value="wynos">WYNOS</option><option value="merchant">Merchant</option><option value="shared">Shared</option></select></Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="คืน GP"><select name="refund_gp" className={selectClass} defaultValue="false"><option value="false">ไม่คืน</option><option value="true">คืน</option></select></Field>
              <Field label="คืนค่าส่ง"><select name="refund_delivery" className={selectClass} defaultValue="false"><option value="false">ไม่คืน</option><option value="true">คืน</option></select></Field>
            </div>
            <Field label="เหตุผล"><Input name="reason" required maxLength={500}/></Field>
            <Button type="submit" variant="destructive">ยืนยัน Refund</Button>
          </div>
        </form>
      </div>

      {pendingSettlements.length?<div className="mt-5">
        <h3 className="mb-2 font-medium">Settlement รอจ่าย</h3>
        <div className="space-y-2">{pendingSettlements.map((s)=><form key={String(s.id)} action={markMerchantSettlementPaidAction} className="flex flex-wrap items-center gap-2 rounded-xl border p-3">
          <input type="hidden" name="settlement_id" value={String(s.id)}/>
          <div className="min-w-52 flex-1"><p className="text-sm font-medium">{String(s.store_name)}</p><p className="text-xs text-muted-foreground">{formatSatang(s.net_satang as number)} · {Number(s.order_count)} ออเดอร์</p></div>
          <Input name="reference" required placeholder="Payout reference" className="max-w-52"/>
          <Input name="reason" required placeholder="เหตุผล" className="max-w-52"/>
          <Button type="submit">Mark paid</Button>
        </form>)}</div>
      </div>:null}

      {pendingRiderPayouts.length?<div className="mt-5">
        <h3 className="mb-2 font-medium">Rider Payout รอจ่าย</h3>
        <div className="space-y-2">{pendingRiderPayouts.map((p)=><form key={String(p.id)} action={markRiderPayoutPaidAction} className="flex flex-wrap items-center gap-2 rounded-xl border p-3">
          <input type="hidden" name="payout_id" value={String(p.id)}/>
          <div className="min-w-52 flex-1"><p className="text-sm font-medium">@{String(p.username??"rider")}</p><p className="text-xs text-muted-foreground">{formatSatang(p.amount_satang as number)}</p></div>
          <Input name="reference" required placeholder="Payout reference" className="max-w-52"/>
          <Input name="reason" required placeholder="เหตุผล" className="max-w-52"/>
          <Button type="submit">Mark paid</Button>
        </form>)}</div>
      </div>:null}
    </section>

    <section className={sectionClass}>
      <div className="mb-4 flex items-center gap-2"><ShieldCheck className="size-5"/><h2 className="font-semibold">Security / Audit</h2></div>
      <p className={descriptionClass}>Config และ ledger tables เป็น deny-by-default RLS การเปลี่ยนค่าทางการเงินตรวจ role ฝั่ง server และบันทึกเหตุผล + metadata ใน Audit Log รายการ finance audit ถูกป้องกันการแก้/ลบผ่าน API role ปกติ</p>
      <Button asChild variant="outline" className="mt-3"><Link href="/audit-log">เปิด Audit Log</Link></Button>
    </section>

    <section className={sectionClass}>
      <h2 className="font-semibold">Recent Payment / Refund</h2>
      <div className="mt-3 overflow-x-auto">
        <table className="w-full min-w-[760px] text-sm">
          <thead className="text-left text-xs text-muted-foreground"><tr><th className="py-2">Order</th><th>Store</th><th>Status</th><th>Gross</th><th>Stripe fee</th><th>Merchant net</th><th>Paid</th></tr></thead>
          <tbody>{operations.payments.slice(0,20).map((p)=><tr key={String(p.order_id)} className="border-t">
            <td className="py-3"><Link className="font-medium hover:underline" href={`/food/orders/${String(p.order_id)}`}>#{String(p.order_number)}</Link></td>
            <td>{String(p.store_name)}</td><td>{String(p.status)}</td><td>{formatSatang(p.gross_amount_satang as number)}</td><td>{formatSatang(p.stripe_fee_satang as number)}</td><td>{formatSatang(p.merchant_net_satang as number)}</td><td>{formatFinanceDate(p.paid_at)}</td>
          </tr>)}</tbody>
        </table>
      </div>
      <div className="mt-5 overflow-x-auto">
        <table className="w-full min-w-[760px] text-sm">
          <thead className="text-left text-xs text-muted-foreground"><tr><th className="py-2">Refund</th><th>Order</th><th>Status</th><th>Amount</th><th>Liability</th><th>Stripe refund fee</th><th>Created</th></tr></thead>
          <tbody>{operations.refunds.slice(0,20).map((r)=><tr key={String(r.id)} className="border-t">
            <td className="py-3 font-mono text-xs">{String(r.id).slice(0,8)}</td><td>#{String(r.order_number)}</td><td>{String(r.status)}</td><td>{formatSatang(r.amount_satang as number)}</td><td>{String(r.liability)}</td><td>{formatSatang(r.stripe_refund_fee_satang as number)}</td><td>{formatFinanceDate(r.created_at)}</td>
          </tr>)}</tbody>
        </table>
      </div>
    </section>
  </div>;
}
