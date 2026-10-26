"use client";

import { CalendarDays, ChevronRight, History, Search, ShoppingBag } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useRef, useState } from "react";
import {
  fetchMerchantOrderHistoryPage, money, paymentLabel, statusLabel,
  type FoodOrder, type FoodStore, type MerchantOrderHistoryFilter,
} from "@/lib/food-merchant";

const PAGE_SIZE = 30;

function shortDate(value: string) {
  return new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

export function MerchantOrderHistory({ client, store, onOpenOrder }: {
  client: SupabaseClient;
  store: FoodStore;
  onOpenOrder: (order: FoodOrder) => void;
}) {
  const [status, setStatus] = useState<MerchantOrderHistoryFilter>("all");
  const [period, setPeriod] = useState<"all" | "7" | "30">("all");
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [orders, setOrders] = useState<FoodOrder[]>([]);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  const generation = useRef(0);
  const sinceDays: 7 | 30 | null = period === "7" ? 7 : period === "30" ? 30 : null;

  useEffect(() => {
    const generationRef = generation;
    const current = ++generationRef.current;
    // Defer state updates to the timer callback to avoid cascading effect renders.
    const timer = window.setTimeout(() => {
      setLoading(true);
      setOrders([]);
      setHasMore(false);
      setError("");
      void fetchMerchantOrderHistoryPage(client, store.id, { status, search, sinceDays, limit: PAGE_SIZE })
        .then((result) => {
          if (current !== generationRef.current) return;
          setOrders(result.orders);
          setHasMore(result.hasMore);
        })
        .catch((reason: unknown) => {
          if (current === generationRef.current) setError(reason instanceof Error ? reason.message : "โหลดประวัติออเดอร์ไม่สำเร็จ");
        })
        .finally(() => {
          if (current === generationRef.current) setLoading(false);
        });
    }, 0);
    return () => { window.clearTimeout(timer); generationRef.current++; };
  }, [client, store.id, status, search, sinceDays, revision]);

  const loadMore = async () => {
    if (loading || loadingMore || !hasMore) return;
    const current = generation.current;
    setLoadingMore(true);
    try {
      const result = await fetchMerchantOrderHistoryPage(client, store.id, {
        status, search, sinceDays, offset: orders.length, limit: PAGE_SIZE,
      });
      if (current !== generation.current) return;
      setOrders((existing) => {
        const ids = new Set(existing.map((order) => order.id));
        return [...existing, ...result.orders.filter((order) => !ids.has(order.id))];
      });
      setHasMore(result.hasMore);
    } catch (reason) {
      if (current === generation.current) setError(reason instanceof Error ? reason.message : "โหลดออเดอร์เพิ่มเติมไม่สำเร็จ");
    } finally {
      if (current === generation.current) setLoadingMore(false);
    }
  };

  return (
    <>
      <div className="wm-page-heading"><div><small>รายการที่สิ้นสุดแล้ว ไม่ถูกลบจากระบบ</small><h1>ประวัติออเดอร์</h1></div></div>
      <section className="wm-history-controls" aria-label="ค้นหาประวัติออเดอร์">
        <form className="wm-history-search" onSubmit={(event) => { event.preventDefault(); setSearch(searchInput); }}>
          <Search size={18} aria-hidden="true" />
          <input aria-label="ค้นหาเลขออเดอร์" value={searchInput} onChange={(event) => setSearchInput(event.target.value)} placeholder="ค้นหาเลขออเดอร์ เช่น WF0032" />
          <button type="submit">ค้นหา</button>
        </form>
        <div className="wm-history-selects">
          <label>สถานะ
            <select value={status} onChange={(event) => setStatus(event.target.value as MerchantOrderHistoryFilter)}>
              <option value="all">ทั้งหมด</option>
              <option value="delivered">ส่งสำเร็จ</option>
              <option value="picked_up">ลูกค้ารับแล้ว</option>
              <option value="cancelled">ยกเลิกแล้ว</option>
            </select>
          </label>
          <label><CalendarDays size={15} /> วันที่สั่ง
            <select value={period} onChange={(event) => setPeriod(event.target.value as "all" | "7" | "30")}>
              <option value="all">ทุกช่วงเวลา</option>
              <option value="7">7 วันล่าสุด</option>
              <option value="30">30 วันล่าสุด</option>
            </select>
          </label>
        </div>
        <p>ค้นหาออเดอร์ที่ส่งสำเร็จหรือยกเลิก รวมถึงรายการที่ซ่อนจากแท็บ “เสร็จแล้ว” หลัง 24 ชั่วโมง</p>
      </section>
      {error ? <div className="wm-history-error" role="alert">{error} <button type="button" onClick={() => setRevision((n) => n + 1)}>ลองอีกครั้ง</button></div> : null}
      {loading ? <div className="wm-history-state">กำลังโหลดประวัติออเดอร์…</div> : orders.length ? (
        <div className="wm-order-list wm-order-list--page">
          {orders.map((order) => (
            <article className="wm-order-card" key={order.id}>
              <button className="wm-order-card-open" type="button" onClick={() => onOpenOrder(order)}>
                <div className="wm-order-card-top">
                  <span><strong>#{order.order_number}</strong><small>สั่งเมื่อ {shortDate(order.created_at)}</small></span>
                  <b>{money(order.total)}</b>
                </div>
                <div className="wm-order-card-customer"><span>{order.recipient_name}</span><small>{order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0} รายการ</small></div>
                <div className="wm-order-card-footer">
                  <span className={`wm-status wm-status--${order.status === "delivered" ? "done" : "muted"}`}>{statusLabel(order.status)}</span>
                  <span className="wm-status wm-status--muted">{paymentLabel(order.payment_status)}</span>
                  <ChevronRight size={18} strokeWidth={1.8} />
                </div>
              </button>
            </article>
          ))}
        </div>
      ) : !error ? (
        <div className="wm-empty"><ShoppingBag size={38} strokeWidth={1.5} /><strong>ไม่พบประวัติออเดอร์</strong><p>ลองเปลี่ยนตัวกรองหรือค้นหาเลขออเดอร์อื่น</p></div>
      ) : null}
      {!loading && hasMore ? <button className="wm-secondary wm-full wm-load-more" type="button" disabled={loadingMore} onClick={() => void loadMore()}>{loadingMore ? "กำลังโหลด…" : "โหลดประวัติเพิ่มเติม"}</button> : null}
      {!loading && orders.length ? <div className="wm-history-count"><History size={15} /> แสดง {orders.length} รายการ{hasMore ? " (ยังมีรายการเก่า)" : ""}</div> : null}
    </>
  );
}
