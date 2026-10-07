"use client";

import { CalendarDays, ChevronLeft, ChevronRight, CircleDollarSign, Download, X } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useRef, useState } from "react";

import { MerchantIcon3D } from "@/components/merchant/merchant-3d-icons";
import { money, type FoodStore } from "@/lib/food-merchant";
import { fetchMerchantStripeFinance, type MerchantStripeFinance } from "@/lib/merchant-core";
import {
  addDays,
  bangkokToday,
  changePercent,
  daysBetween,
  fetchFinanceSummary,
  financeCsv,
  financeError,
  periodRange,
  rangeLabel,
  thaiDay,
  type DateRange,
  type FinancePeriod,
  type FinanceSummary,
} from "@/lib/merchant-finance";

const PERIODS: { id: Exclude<FinancePeriod, "custom">; label: string }[] = [
  { id: "today", label: "วันนี้" },
  { id: "yesterday", label: "เมื่อวาน" },
  { id: "week", label: "สัปดาห์นี้" },
  { id: "month", label: "เดือนนี้" },
];
const MAX_DAYS = 366;

/**
 * WYN-210: the store's money for today, yesterday, this week, this month or
 * any range picked on a calendar. Two headline numbers — net sales and store
 * income — each with the lines that make it up, plus the money things that
 * need a look (slips waiting, money WYNOS still has to transfer).
 */
export function MerchantFinance({
  client,
  store,
  refreshKey,
  onEditStore,
  onOpenTab,
}: {
  client: SupabaseClient;
  store: FoodStore;
  /** Changes when the app reloads orders (pull to refresh, live updates), so the numbers follow. */
  refreshKey: unknown;
  onEditStore: () => void;
  onOpenTab: (tab: "orders" | "campaigns") => void;
}) {
  const [period, setPeriod] = useState<FinancePeriod>("today");
  const [range, setRange] = useState<DateRange>(() => periodRange("today"));
  const [summary, setSummary] = useState<FinanceSummary | null>(null);
  const [error, setError] = useState("");
  const [picking, setPicking] = useState(false);
  const [paymentStatus, setPaymentStatus] = useState<MerchantStripeFinance | null>(null);
  const [todaySummary, setTodaySummary] = useState<FinanceSummary | null>(null);

  useEffect(() => {
    let live = true;
    void fetchFinanceSummary(client, store.id, range)
      .then((next) => { if (live) { setSummary(next); setError(""); } })
      .catch((reason) => { if (live) setError(financeError(reason)); });
    return () => { live = false; };
  }, [client, store.id, range, refreshKey]);

  useEffect(() => {
    let live = true;
    void Promise.all([
      fetchMerchantStripeFinance(client, store.id),
      fetchFinanceSummary(client, store.id, periodRange("today")),
    ]).then(([stripe, today]) => {
      if (!live) return;
      setPaymentStatus(stripe);
      setTodaySummary(today);
    }).catch(() => {
      if (live) setPaymentStatus(null);
    });
    return () => { live = false; };
  }, [client, store.id, refreshKey]);

  const choose = (next: Exclude<FinancePeriod, "custom">) => {
    setPeriod(next);
    setSummary(null);
    setRange(periodRange(next));
  };

  // Only show numbers that belong to the range on screen.
  const current = summary && summary.from === range.from && summary.to === range.to ? summary : null;
  const paid = current ? current.food + current.delivery - current.discounts : 0;
  const change = current ? changePercent(current.sales_net, current.prev_sales_net) : null;

  const download = () => {
    if (!current) return;
    const url = URL.createObjectURL(new Blob([financeCsv(current)], { type: "text/csv;charset=utf-8" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `wynos-finance-${current.from}_${current.to}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <>
      <div className="wm-page-heading"><div><small>เงินเข้าร้าน</small><h1>การเงิน</h1></div></div>

      {paymentStatus?.connected ? (
        <section className="wm-fin-payout-overview" aria-label="สรุปการรับเงิน">
          <div><small>ยอดขายวันนี้</small><strong>{money(todaySummary?.sales_net ?? 0)}</strong></div>
          <div><small>กำลังดำเนินการ</small><strong>{money(paymentStatus.pending)}</strong></div>
          <div><small>พร้อมโอน</small><strong>{money(paymentStatus.available)}</strong></div>
          <div><small>โอนเข้าธนาคารแล้ววันนี้</small><strong>{money(paymentStatus.paid_today)}</strong></div>
          <div><small>คืนเงิน</small><strong>{money(todaySummary?.refunds ?? 0)}</strong></div>
        </section>
      ) : null}

      <div className="wm-fin-periods" role="radiogroup" aria-label="ช่วงเวลา">
        {PERIODS.map((item) => (
          <button key={item.id} type="button" role="radio" aria-checked={period === item.id} className={period === item.id ? "is-active" : ""} onClick={() => choose(item.id)}>{item.label}</button>
        ))}
        <button type="button" role="radio" aria-checked={period === "custom"} className={period === "custom" ? "is-active" : ""} onClick={() => setPicking(true)}>
          <CalendarDays size={15} />เลือกวัน
        </button>
      </div>
      <p className="wm-fin-range">{current ? `${rangeLabel(range)} · ${current.orders} ออเดอร์` : rangeLabel(range)}</p>

      {error ? (
        <div className="wm-empty wm-empty--compact"><MerchantIcon3D name="finance" size={64} /><strong>{error}</strong></div>
      ) : !current ? (
        <div className="wm-empty wm-empty--compact"><span className="wm-mini-loader" aria-label="กำลังโหลด" /></div>
      ) : (
        <>
          <div className="wm-fin-kpis">
            <div className="wm-fin-kpi is-sales"><small>ยอดขายสุทธิ</small><strong>{money(current.sales_net)}</strong><span>ที่ลูกค้าจ่าย หลังส่วนลดและเงินคืน</span></div>
            <div className="wm-fin-kpi is-income"><small>รายได้ร้าน</small><strong>{money(current.income)}</strong><span>เงินที่ร้านได้จริง</span></div>
          </div>

          <section className="wm-fin-card">
            <h2>จากยอดขายสุทธิ เป็นรายได้</h2>
            <FinanceLine label="ยอดขายสุทธิ" value={current.sales_net} />
            <FinanceLine label="หักค่าโฆษณา" value={-current.ad_spend} />
            {current.platform_funded > 0 ? <FinanceLine label="WYNOS ช่วยจ่ายส่วนลด" value={current.platform_funded} positive /> : null}
            <FinanceLine label="รายได้ร้าน" value={current.income} total />
          </section>

          <section className="wm-fin-card">
            <h2>ยอดขายสุทธิมาจาก</h2>
            <FinanceLine label="ค่าอาหาร" value={current.food} />
            <FinanceLine label="ค่าส่ง" value={current.delivery} />
            <FinanceLine label="ส่วนลดโปรโมชั่น" value={-current.discounts} />
            <FinanceLine label="คืนเงินลูกค้า" value={-current.refunds} />
          </section>

          <div className="wm-fin-mini">
            <span><small>ออเดอร์</small><b>{current.orders}</b></span>
            <span><small>เฉลี่ย/ออเดอร์</small><b>{current.orders ? money(paid / current.orders) : "–"}</b></span>
            <span>
              <small>เทียบช่วงก่อน</small>
              <b className={change === null ? "" : change >= 0 ? "is-up" : "is-down"}>{change === null ? "–" : `${change >= 0 ? "▲" : "▼"}${Math.abs(change)}%`}</b>
            </span>
          </div>

          {current.pending_slip_count > 0 || current.platform_owed > 0 ? (
            <section className="wm-section">
              <div className="wm-section-title"><h2>เรื่องเงินที่ต้องดู</h2></div>
              <div className="wm-fin-todo">
                {current.pending_slip_count > 0 ? (
                  <button type="button" className="is-warning" onClick={() => onOpenTab("orders")}>
                    <span><strong>รอตรวจสลิป</strong><small>{`${current.pending_slip_count} ออเดอร์`}</small></span>
                    <b>{money(current.pending_slip_total)}</b><ChevronRight size={16} />
                  </button>
                ) : null}
                {current.platform_owed > 0 ? (
                  <button type="button" onClick={() => onOpenTab("campaigns")}>
                    <span><strong>เงินที่ WYNOS จะโอนให้ร้าน</strong><small>ส่วนลดแคมเปญที่ WYNOS ช่วยออก</small></span>
                    <b>{money(current.platform_owed)}</b><ChevronRight size={16} />
                  </button>
                ) : null}
              </div>
            </section>
          ) : null}

          <button className="wm-secondary wm-full wm-fin-download" type="button" onClick={download}>
            <Download size={17} />ดาวน์โหลดช่วงนี้ (CSV)
          </button>
        </>
      )}

      <PaymentChannels paymentStatus={paymentStatus} onEditStore={onEditStore} />

      {picking ? (
        <RangePicker
          initial={period === "custom" ? range : null}
          onClose={() => setPicking(false)}
          onPick={(next) => { setPicking(false); setPeriod("custom"); setSummary(null); setRange(next); }}
        />
      ) : null}
    </>
  );
}

const AMOUNT = new Intl.NumberFormat("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function FinanceLine({ label, value, positive, total }: { label: string; value: number; positive?: boolean; total?: boolean }) {
  const text = `${value < 0 ? "−" : positive ? "+" : ""}${AMOUNT.format(Math.abs(value))}`;
  return (
    <div className={total ? "wm-fin-line is-total" : "wm-fin-line"}>
      <span>{label}</span>
      <b className={value < 0 ? "is-minus" : positive || total ? "is-plus" : ""}>{text}</b>
    </div>
  );
}

function PaymentChannels({ paymentStatus, onEditStore }: { paymentStatus: MerchantStripeFinance | null; onEditStore: () => void }) {
  const payoutSchedule = paymentStatus?.payout_interval === "daily"
    ? "อัตโนมัติ · ทุกวัน"
    : paymentStatus?.payout_interval === "weekly"
      ? "อัตโนมัติ · รายสัปดาห์"
      : paymentStatus?.payout_interval === "monthly"
        ? "อัตโนมัติ · รายเดือน"
        : "เงินจะถูกโอนเข้าบัญชีตามรอบของผู้ให้บริการ";

  if (paymentStatus?.connected) {
    return (
      <section className="wm-section">
        <div className="wm-section-title"><h2>บัญชีรับเงิน</h2><button type="button" onClick={onEditStore}>จัดการ <ChevronRight size={15} /></button></div>
        <div className="wm-payment-summary">
          <div>
            <span>บัญชีธนาคาร</span>
            <strong>{paymentStatus.bank_ready
              ? `${paymentStatus.bank_name || "บัญชีธนาคาร"} ${paymentStatus.bank_last4 ? `•••• ${paymentStatus.bank_last4}` : ""}`.trim()
              : "กำลังยืนยันบัญชีรับเงิน"}</strong>
            <small>{paymentStatus.bank_ready ? "พร้อมรับเงิน" : "อาจต้องยืนยันข้อมูลเพิ่มเติม"}</small>
          </div>
          <div>
            <span>รอบโอนเงิน</span>
            <strong>{payoutSchedule}</strong>
            <small>ระบบจะแสดงรอบจริงของบัญชี และไม่สมมติว่าโอนทุกวัน</small>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="wm-section">
      <div className="wm-section-title"><h2>บัญชีรับเงิน</h2><button type="button" onClick={onEditStore}>ตั้งค่า <ChevronRight size={15} /></button></div>
      <button className="wm-setup-banner" type="button" onClick={onEditStore}><CircleDollarSign size={22} /><span><strong>ยังไม่ได้เปิดรับชำระเงิน</strong><small>เปิดใช้งานครั้งเดียว แล้วระบบจะจัดการการรับเงินและโอนเข้าบัญชีให้</small></span></button>
    </section>
  );
}

const WEEKDAYS = ["จ", "อ", "พ", "พฤ", "ศ", "ส", "อา"];
const MONTH = new Intl.DateTimeFormat("th-TH", { month: "long", year: "numeric", timeZone: "UTC" });

/** Calendar sheet: tap the first day, then the last day (or the same day twice). */
function RangePicker({ initial, onClose, onPick }: { initial: DateRange | null; onClose: () => void; onPick: (range: DateRange) => void }) {
  const today = bangkokToday();
  const [start, setStart] = useState<string | null>(initial?.from ?? null);
  const [end, setEnd] = useState<string | null>(initial?.to ?? null);
  const [month, setMonth] = useState(() => `${(initial?.to ?? today).slice(0, 7)}-01`);
  const sheetRef = useRef<HTMLElement>(null);
  const closeRef = useRef(onClose);
  useEffect(() => { closeRef.current = onClose; }, [onClose]);

  // Same focus handling as the app's Sheet: focus moves in on open and goes
  // back to "เลือกวัน" on close; Escape closes and Tab stays inside.
  useEffect(() => {
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    sheetRef.current?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") { event.preventDefault(); closeRef.current(); return; }
      if (event.key !== "Tab" || !sheetRef.current) return;
      const items = [...sheetRef.current.querySelectorAll<HTMLElement>("button:not(:disabled)")];
      if (!items.length) return;
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && (document.activeElement === first || document.activeElement === sheetRef.current)) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      if (opener?.isConnected) opener.focus();
    };
  }, []);

  const lead = (new Date(`${month}T12:00:00Z`).getUTCDay() + 6) % 7;
  // Days in the month: from the 1st to the day before next month's 1st.
  const length = daysBetween(month, addDays(`${addDays(month, 31).slice(0, 7)}-01`, -1));
  const cells = [...Array.from({ length: lead }, () => null), ...Array.from({ length }, (_, index) => addDays(month, index))];
  const shiftMonth = (amount: number) => {
    const date = new Date(`${month}T12:00:00Z`);
    date.setUTCMonth(date.getUTCMonth() + amount);
    setMonth(`${date.toISOString().slice(0, 7)}-01`);
  };
  const last = end ?? start;
  const tooLong = start && last ? daysBetween(start, last) > MAX_DAYS : false;

  const tap = (day: string) => {
    if (!start || end) { setStart(day); setEnd(null); return; }
    if (day < start) { setStart(day); return; }
    setEnd(day);
  };

  return (
    <div className="wm-sheet-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section ref={sheetRef} tabIndex={-1} className="wm-sheet" role="dialog" aria-modal="true" aria-label="เลือกช่วงวันที่">
        <header><span /><h2>เลือกช่วงวันที่</h2><button type="button" aria-label="ปิด" onClick={onClose}><X size={20} /></button></header>
        <div className="wm-sheet-body wm-fin-picker">
          <div className="wm-fin-month">
            <button type="button" aria-label="เดือนก่อน" onClick={() => shiftMonth(-1)}><ChevronLeft size={18} /></button>
            <strong>{MONTH.format(new Date(`${month}T12:00:00Z`))}</strong>
            <button type="button" aria-label="เดือนถัดไป" disabled={month >= `${today.slice(0, 7)}-01`} onClick={() => shiftMonth(1)}><ChevronRight size={18} /></button>
          </div>
          <div className="wm-fin-calendar">
            {WEEKDAYS.map((day) => <span key={day} className="is-head">{day}</span>)}
            {cells.map((day, index) => {
              if (!day) return <span key={`blank-${index}`} />;
              const edge = day === start || day === last;
              const inside = start && last && day > start && day < last;
              return (
                <button
                  key={day}
                  type="button"
                  disabled={day > today}
                  aria-pressed={Boolean(edge || inside)}
                  className={edge ? "is-edge" : inside ? "is-inside" : ""}
                  onClick={() => tap(day)}
                >
                  {Number(day.slice(8))}
                </button>
              );
            })}
          </div>
          <p className="wm-fin-range">
            {tooLong ? "เลือกได้ไม่เกิน 1 ปี" : start && last ? `${rangeLabel({ from: start, to: last })} (${daysBetween(start, last)} วัน)` : "แตะวันแรก แล้วแตะวันสุดท้าย"}
          </p>
          <button className="wm-primary wm-full" type="button" disabled={!start || !last || tooLong} onClick={() => start && last && onPick({ from: start, to: last })}>
            ดูช่วงนี้
          </button>
          <p className="wm-money-note">{`ข้อมูลถึงวันนี้ (${thaiDay(today)})`}</p>
        </div>
      </section>
    </div>
  );
}
