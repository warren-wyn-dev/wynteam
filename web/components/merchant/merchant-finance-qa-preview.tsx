"use client";

// Read-only Finance v2 sandbox preview. NEVER display on a real Supabase project.
// All amounts are from immutable simulation-only QA projection RPCs.
import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

type Bucket = {
  local_period_start: string;
  projection_count: number;
  refund_event_count: number;
  projected_customer_paid_satang: number;
  estimated_platform_gp_satang: number;
  simulated_customer_refund_satang: number;
  simulated_gp_reversal_satang: number;
  period_merchant_food_projection_less_reversals_satang: number;
};
type BucketsResult = {
  mode: "simulation_only";
  timezone: "Asia/Bangkok";
  granularity: "day" | "month";
  selected_store_id: string;
  stripe_fee_status: "unknown";
  merchant_payout_status: "not_reconciled";
  merchant_net_payout_satang: null;
  buckets: Bucket[];
};
type OrderResult = {
  status: "not_projected" | "projected";
  mode: "simulation_only";
  order_number?: string;
  frozen_gp_rate_bps?: number;
  simulated_customer_refunded_satang?: number;
  simulated_gp_reversal_satang?: number;
  refund_event_count?: number;
};
const QA_PROJECT_URL = "https://pcatuxtenluqzjzzwsvl.supabase.co";
const baht = (satang: number) =>
  new Intl.NumberFormat("th-TH", { style: "currency", currency: "THB" }).format(satang / 100);
const todayBangkok = () =>
  new Date().toLocaleDateString("sv-SE", { timeZone: "Asia/Bangkok" });
const daysEarlier = (date: string, days: number) =>
  new Date(Date.parse(date + "T00:00:00Z") - days * 86400000).toISOString().slice(0, 10);
const isUUID = (value: string) =>
  /^[a-f\d]{8}-[a-f\d]{4}-[1-8][a-f\d]{3}-[89ab][a-f\d]{3}-[a-f\d]{12}$/i.test(value);

/** This component must remain gated both by the environment flag and the EXACT QA URL. */
export function MerchantFinanceQaPreview({ client, storeId }: {
  client: SupabaseClient;
  storeId: string;
}) {
  const qaEnabled = process.env.NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW === "true"
    && client.supabaseUrl === QA_PROJECT_URL;
  const [from, setFrom] = useState(() => daysEarlier(todayBangkok(), 6));
  const [to, setTo] = useState(() => todayBangkok());
  const [granularity, setGranularity] = useState<"day" | "month">("day");
  const [report, setReport] = useState<BucketsResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [orderId, setOrderId] = useState("");
  const [order, setOrder] = useState<OrderResult | null>(null);
  const [orderError, setOrderError] = useState("");
  if (!qaEnabled) return null;
  // The backend RPC independently authorizes the active merchant OWNER.
  return (
    <FinanceQaReport
      client={client} storeId={storeId}
      from={from} to={to} setFrom={setFrom} setTo={setTo}
      granularity={granularity} setGranularity={setGranularity}
      report={report} setReport={setReport} loading={loading}
      setLoading={setLoading} error={error} setError={setError}
      orderId={orderId} setOrderId={setOrderId} order={order}
      setOrder={setOrder} orderError={orderError} setOrderError={setOrderError}
    />
  );
}

type Props = {
  client: SupabaseClient;storeId: string;
  from: string;to: string;
  setFrom:(value:string)=>void;setTo:(value:string)=>void;
  granularity:"day"|"month";setGranularity:(value:"day"|"month")=>void;
  report:BucketsResult|null;setReport:(value:BucketsResult|null)=>void;
  loading:boolean;setLoading:(value:boolean)=>void;
  error:string;setError:(value:string)=>void;
  orderId:string;setOrderId:(value:string)=>void;
  order:OrderResult|null;setOrder:(value:OrderResult|null)=>void;
  orderError:string;setOrderError:(value:string)=>void;
};
function FinanceQaReport({
  client,storeId,from,to,setFrom,setTo,granularity,setGranularity,
  report,setReport,loading,setLoading,error,setError,
  orderId,setOrderId,order,setOrder,orderError,setOrderError,
}:Props){
  useEffect(()=>{
    let active=true;
    setReport(null);
    setError("");
    if(!from || !to || from>to
      || Date.parse(to+"T00:00:00Z")-Date.parse(from+"T00:00:00Z")>365*86400000){
      setError("เลือกช่วงวันที่ไม่เกิน 366 วัน");
      return ()=>{active=false;};
    }
    const fromIso=new Date(from+"T00:00:00+07:00").toISOString();
    const toIso=new Date(Date.parse(to+"T00:00:00+07:00")+86400000).toISOString();
    setLoading(true);
    void client.rpc("merchant_food_finance_buckets_v2_qa",{
      p_store_id:storeId,p_from:fromIso,p_to:toIso,p_granularity:granularity,
    }).then(({data,error:rpcError})=>{
      if(!active)return;
      if(rpcError)throw rpcError;
      const parsed=data as BucketsResult;
      if(parsed?.mode!=="simulation_only" || parsed.timezone!=="Asia/Bangkok"
        || parsed.selected_store_id!==storeId || !Array.isArray(parsed.buckets)
        || parsed.merchant_net_payout_satang!==null){
        throw new Error("ผลรายงานไม่ตรงกับสถานะ Simulation QA");
      }
      setReport(parsed);
      setLoading(false);
    }).catch(()=>{
      if(active){setError("ไม่สามารถอ่านรายงาน QA ได้ กรุณาตรวจสอบสิทธิ์เจ้าของร้าน");setLoading(false);}
    });
    return ()=>{active=false;};
  },[client,storeId,from,to,granularity,setReport,setError,setLoading]);

  const sum=(field:keyof Bucket)=>report?.buckets.reduce((total,b)=>{
    const n=b[field];return total+(typeof n==="number"?n:0);
  },0)??0;
  const showOrder=async()=>{
    setOrder(null);setOrderError("");
    if(!isUUID(orderId)){setOrderError("กรุณากรอก UUID ออเดอร์ QA ที่ถูกต้อง");return;}
    try{
      const {data,error:rpcError}=await client.rpc("merchant_food_finance_order_details_v2_qa",{
        p_store_id:storeId,p_order_id:orderId
      });
      if(rpcError)throw rpcError;
      const value=data as OrderResult;
      if(value?.mode!=="simulation_only" || !["projected","not_projected"].includes(value.status))
        throw new Error("Unexpected QA response");
      setOrder(value);
    }catch{setOrderError("อ่านรายละเอียดไม่ได้ หรือไม่มีสิทธิ์");}
  };
  return (
    <section className="wm-fin-card" aria-label="พรีวิวรายงานการเงิน QA">
      <h2>Finance v2 · QA Preview</h2>
      <p><strong>ข้อมูลจำลองเท่านั้น</strong> — ไม่ใช่รายได้จริง ยอดโอน หรือยอดคืนเงินที่ทำรายการแล้ว</p>
      <div style={{display:"flex",flexWrap:"wrap",gap:8,marginBlock:12}}>
        <label>เริ่มต้น <input type="date" value={from} onChange={e=>setFrom(e.target.value)} /></label>
        <label>สิ้นสุด <input type="date" value={to} onChange={e=>setTo(e.target.value)} /></label>
        <label>แสดงผล <select value={granularity}
          onChange={e=>setGranularity(e.target.value as "day"|"month")}>
          <option value="day">รายวัน</option><option value="month">รายเดือน</option>
        </select></label>
      </div>
      {loading?<p role="status">กำลังอ่าน Finance QA...</p>:null}
      {error?<p role="alert">{error}</p>:null}
      {report?<>
        <div className="wm-fin-mini">
          <span><small>ยอดชำระจำลอง</small><b>{baht(sum("projected_customer_paid_satang"))}</b></span>
          <span><small>GP จำลอง</small><b>{baht(sum("estimated_platform_gp_satang"))}</b></span>
          <span><small>Refund จำลอง</small><b>{baht(sum("simulated_customer_refund_satang"))}</b></span>
          <span><small>GP Reversal จำลอง</small><b>{baht(sum("simulated_gp_reversal_satang"))}</b></span>
        </div>
        <div style={{overflowX:"auto"}}>
          <table style={{width:"100%",marginTop:12}}>
            <thead><tr><th>วันที่ (ไทย)</th><th>ออเดอร์</th><th>คืนเงิน</th><th>GP จำลอง</th><th>ส่วนแบ่งร้านจำลอง</th></tr></thead>
            <tbody>{report.buckets.map(b=><tr key={b.local_period_start}>
              <td>{b.local_period_start}</td>
              <td>{b.projection_count}</td><td>{b.refund_event_count}</td>
              <td>{baht(b.estimated_platform_gp_satang-b.simulated_gp_reversal_satang)}</td>
              <td>{baht(b.period_merchant_food_projection_less_reversals_satang)}</td>
            </tr>)}</tbody>
          </table>
        </div>
        <p>ค่าธรรมเนียม Stripe: ไม่ทราบ · ยอดโอนสุทธิ: ยังไม่ได้กระทบยอด</p>
      </>:null}
      <div style={{display:"flex",flexWrap:"wrap",gap:8,marginTop:16}}>
        <label>ตรวจออเดอร์จำลอง
          <input aria-label="UUID ออเดอร์ QA" value={orderId}
            onChange={e=>setOrderId(e.target.value)} placeholder="UUID ออเดอร์ QA" />
        </label>
        <button className="wm-secondary" type="button" onClick={()=>void showOrder()}>ตรวจออเดอร์</button>
      </div>
      {orderError?<p role="alert">{orderError}</p>:null}
      {order?.status==="not_projected"?<p>ออเดอร์นี้ยังไม่มี Finance Projection ใน QA</p>:null}
      {order?.status==="projected"?<p>
        ออเดอร์ {order.order_number} · GP {order.frozen_gp_rate_bps} bps ·
        Refund จำลอง {baht(order.simulated_customer_refunded_satang??0)} ·
        GP Reversal {baht(order.simulated_gp_reversal_satang??0)} ·
        {order.refund_event_count??0} รายการ
      </p>:null}
    </section>
  );
}
