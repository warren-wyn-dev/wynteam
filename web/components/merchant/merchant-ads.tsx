"use client";

import { ImagePlus } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useState } from "react";

import { MerchantIcon3D } from "@/components/merchant/merchant-3d-icons";
import { money, type FoodStore } from "@/lib/food-merchant";
import {
  fetchMerchantAdAccount,
  merchantAdError,
  requestAdTopup,
  setAdActive,
  type MerchantAdAccount,
} from "@/lib/merchant-ads";

const TOPUP_STATUS: Record<string, string> = { pending: "รอตรวจ", approved: "เติมแล้ว", rejected: "ไม่อนุมัติ" };

/**
 * WYN-207: pay-per-click ads. The store sees its credit, clicks and spend,
 * tops up by PromptPay transfer + slip (WYNOS Admin approves), and can pause
 * or resume its ads. Charging happens on the server, once per customer per day.
 */
export function MerchantAds({ client, store, onMessage }: { client: SupabaseClient; store: FoodStore; onMessage: (message: string) => void }) {
  const [account, setAccount] = useState<MerchantAdAccount | null>(null);
  const [loadError, setLoadError] = useState("");
  const [amount, setAmount] = useState("");
  const [slip, setSlip] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setAccount(await fetchMerchantAdAccount(client, store.id));
      setLoadError("");
    } catch (error) {
      setLoadError(merchantAdError(error));
    }
  }, [client, store.id]);

  useEffect(() => {
    let live = true;
    void fetchMerchantAdAccount(client, store.id)
      .then((next) => { if (live) { setAccount(next); setLoadError(""); } })
      .catch((error) => { if (live) setLoadError(merchantAdError(error)); });
    return () => { live = false; };
  }, [client, store.id]);

  if (loadError) return <div className="wm-empty wm-empty--compact"><MerchantIcon3D name="ads" size={64} /><strong>{loadError}</strong></div>;
  if (!account) return <div className="wm-empty wm-empty--compact"><span className="wm-mini-loader" aria-label="กำลังโหลด" /></div>;

  const cpc = Number(account.cost_per_click);
  const min = Number(account.min_topup);
  const clicksLeft = cpc > 0 ? Math.floor(Number(account.balance) / cpc) : 0;
  const statusLabel = account.status === "stopped" ? "WYNOS หยุดไว้" : account.live ? "กำลังแสดง" : account.status === "paused" ? "หยุดชั่วคราว" : Number(account.balance) < cpc ? "เครดิตไม่พอ" : "ยังไม่เริ่ม";

  const submitTopup = async () => {
    const value = Number(amount);
    if (!Number.isFinite(value) || value < min) { onMessage(`เติมขั้นต่ำ ${money(min)}`); return; }
    if (!slip) { onMessage("แนบสลิปการโอนก่อน"); return; }
    setBusy(true);
    try {
      await requestAdTopup(client, store.id, value, slip);
      setAmount("");
      setSlip(null);
      onMessage("ส่งสลิปแล้ว รอทีม WYNOS ตรวจ");
      await load();
    } catch (error) {
      onMessage(merchantAdError(error));
    } finally {
      setBusy(false);
    }
  };

  const toggle = async () => {
    setBusy(true);
    try {
      await setAdActive(client, store.id, account.status !== "active");
      await load();
    } catch (error) {
      onMessage(merchantAdError(error));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <section className="wm-pc-owed">
        <small>เครดิตโฆษณา</small>
        <strong>{money(account.balance)}</strong>
        <span>{`พอสำหรับประมาณ ${clicksLeft} คลิก · คลิกละ ${money(cpc)}`}</span>
      </section>

      {account.status === "stopped" ? (
        <div className="wm-setup-banner wm-suspended-banner" role="alert">
          <MerchantIcon3D name="ads" size={28} />
          <span><strong>ทีม WYNOS หยุดโฆษณาของร้านไว้</strong><small>{account.stop_reason ? `เหตุผล: ${account.stop_reason}` : "ติดต่อทีม WYNOS"}</small></span>
        </div>
      ) : null}

      <div className="wm-pc-stats wm-ads-stats">
        <span><small>สถานะ</small><strong>{statusLabel}</strong></span>
        <span><small>คลิกวันนี้</small><strong>{account.clicks_today}</strong></span>
        <span><small>7 วัน</small><strong>{`${account.clicks_7d} คลิก`}</strong></span>
      </div>

      {account.can_manage && account.status !== "none" && account.status !== "stopped" ? (
        <button className={account.status === "active" ? "wm-secondary wm-full" : "wm-primary wm-full"} type="button" disabled={busy} onClick={() => void toggle()}>
          {account.status === "active" ? "หยุดโฆษณาชั่วคราว" : "เริ่มแสดงโฆษณา"}
        </button>
      ) : null}

      <section className="wm-section">
        <div className="wm-section-title"><h2>โฆษณาแสดงที่ไหน</h2></div>
        <ul className="wm-ads-where">
          <li>ร้านแนะนำบนหน้าแรก WYNOS Food</li>
          <li>อันดับบนสุดตอนลูกค้าค้นหาร้าน</li>
          <li>ทุกที่มีป้าย “โฆษณา” · คิดเงินเมื่อลูกค้ากดเข้าร้าน คนเดิมกดซ้ำในวันเดียวกันคิดครั้งเดียว</li>
        </ul>
      </section>

      {account.can_manage ? (
        <section className="wm-section">
          <div className="wm-section-title"><h2>เติมเครดิต</h2></div>
          {account.ads_enabled && account.wynos_promptpay_id ? (
            <div className="wm-ads-topup">
              <p>{`โอนเข้า PromptPay ของ WYNOS ${account.wynos_promptpay_name ?? ""}`.trim()}</p>
              <strong className="wm-ads-promptpay">{account.wynos_promptpay_id}</strong>
              <label className="wm-field"><span>{`จำนวนเงิน (ขั้นต่ำ ${money(min)})`}</span>
                <input inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value.replace(/[^0-9.]/g, ""))} placeholder={String(min)} />
              </label>
              <label className="wm-secondary wm-full wm-ads-slip">
                <ImagePlus size={18} />{slip ? slip.name : "แนบสลิปการโอน"}
                <input type="file" accept="image/*" hidden onChange={(event) => setSlip(event.target.files?.[0] ?? null)} />
              </label>
              <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void submitTopup()}>{busy ? "กำลังส่ง…" : "ส่งสลิปให้ WYNOS ตรวจ"}</button>
            </div>
          ) : (
            <p className="wm-money-note">ระบบโฆษณายังไม่เปิดรับเติมเครดิต</p>
          )}
        </section>
      ) : null}

      {account.topups.length ? (
        <section className="wm-section">
          <div className="wm-section-title"><h2>ประวัติการเติม</h2></div>
          <div className="wm-money-list">
            {account.topups.map((topup) => (
              <div key={topup.id} className={topup.status === "rejected" ? "is-failed" : topup.status === "pending" ? "is-waiting" : ""}>
                <span><strong>{TOPUP_STATUS[topup.status] ?? topup.status}</strong><small>{topup.note ?? new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(topup.created_at))}</small></span>
                <b>{money(topup.amount)}</b>
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </>
  );
}
