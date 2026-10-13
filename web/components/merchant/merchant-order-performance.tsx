"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useState } from "react";
import { periodRange, rangeLabel, type DateRange } from "@/lib/merchant-finance";
import {
  fetchMerchantOrderPerformance, merchantOrderPerformanceError, type MerchantOrderPerformanceSummary,
} from "@/lib/merchant-order-performance";

export function MerchantOrderPerformance({ client, storeId, range, refreshKey }: {
  client: SupabaseClient;
  storeId: string;
  range?: DateRange;
  refreshKey: unknown;
}) {
  const [result, setResult] = useState<{ request: string; summary: MerchantOrderPerformanceSummary | null; error: string } | null>(null);
  const [retry, setRetry] = useState(0);
  const requested = range ?? periodRange("today");
  const request = `${storeId}:${requested.from}:${requested.to}`;
  // Never show the previous store/date cohort while the next request is loading.
  const summary = result?.request === request ? result.summary : null;
  const error = result?.request === request ? result.error : "";

  useEffect(() => {
    let active = true;
    void fetchMerchantOrderPerformance(client, storeId, { from: requested.from, to: requested.to })
      .then((next) => { if (active) setResult({ request, summary: next, error: "" }); })
      .catch((reason: unknown) => { if (active) setResult({ request, summary: null, error: merchantOrderPerformanceError(reason) }); });
    return () => { active = false; };
  }, [client, storeId, requested.from, requested.to, request, refreshKey, retry]);

  if (error) return (
    <section className="wm-fin-card" aria-label="สถิติคำสั่งซื้อ">
      <p role="alert">{error}</p>
      <button type="button" className="wm-soft-btn" onClick={() => setRetry((value) => value + 1)}>ลองอีกครั้ง</button>
    </section>
  );
  if (!summary) return null;
  const percent = (value: number | null) => value === null ? "ยังไม่มีข้อมูล" : `${value.toLocaleString("th-TH", { maximumFractionDigits: 2 })}%`;
  return (
    <section className="wm-fin-card" aria-label="สถิติคำสั่งซื้อ">
      <h2>สถิติคำสั่งซื้อ</h2>
      <p>{rangeLabel({ from: summary.from, to: summary.to })} · ตามวันที่สร้างออเดอร์</p>
      <dl>
        <div><dt>ออเดอร์ทั้งหมด</dt><dd>{summary.totalOrders}</dd></div>
        <div><dt>ส่งสำเร็จ</dt><dd>{summary.completedOrders}</dd></div>
        <div><dt>ยกเลิก</dt><dd>{summary.cancelledOrders}</dd></div>
        <div><dt>อัตรารับออเดอร์</dt><dd>{percent(summary.acceptanceRate)} ({summary.acceptedOrders}/{summary.acceptanceEligibleOrders})</dd></div>
        <div><dt>อัตรายกเลิกโดยร้าน</dt><dd>{percent(summary.merchantCancelRate)} ({summary.merchantCancelledOrders}/{summary.acceptanceEligibleOrders})</dd></div>
        <div><dt>เวลาเตรียมอาหารเฉลี่ย</dt><dd>{summary.averagePreparationMinutes === null ? "ยังไม่มีข้อมูล" : `${summary.averagePreparationMinutes.toLocaleString("th-TH")} นาที (${summary.preparationSamples} ออเดอร์)`}</dd></div>
      </dl>
      <p>อัตรารับและยกเลิกใช้ฐานออเดอร์ที่ส่งหลักฐานชำระแล้ว ชำระสำเร็จ หรือคืนเงินแล้ว การยกเลิกโดยร้านนับเฉพาะเหตุการณ์ที่ระบุผู้ดำเนินการและตรวจสิทธิ์ร้านได้</p>
      <p>การระบุผู้ยกเลิกตรวจจากสมาชิกที่ยังมีสิทธิ์ร้านในปัจจุบัน เหตุการณ์ก่อนเปลี่ยนสิทธิ์อาจไม่รวมในอัตรายกเลิกโดยร้าน</p>
      {summary.unattributedCancelledOrders > 0 ? <p>มี {summary.unattributedCancelledOrders} ออเดอร์ยกเลิกที่ไม่รวมเป็นการยกเลิกโดยร้าน เช่น ลูกค้ายกเลิกหรือไม่มีหลักฐานผู้ดำเนินการ</p> : null}
      <h3>เมนูขายดี</h3>
      {summary.topItems.length ? (
        <ol>{summary.topItems.map((item, index) => <li key={`${item.menuItemId ?? "deleted"}-${item.itemName}-${index}`}>
          {item.itemName} · {item.quantity} รายการ จาก {item.orders} ออเดอร์
        </li>)}</ol>
      ) : <p>ยังไม่มีเมนูจากออเดอร์ที่ส่งสำเร็จและชำระเงินแล้วในช่วงนี้</p>}
      <p>ยอดขาย GP ค่าธรรมเนียม และรายได้สุทธิดูจากรายงานการเงินร้านค้า</p>
    </section>
  );
}
