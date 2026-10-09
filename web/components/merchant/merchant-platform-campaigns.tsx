"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useState } from "react";

import { MerchantIcon3D } from "@/components/merchant/merchant-3d-icons";
import { money, type FoodStore } from "@/lib/food-merchant";
import {
  fetchPlatformCampaigns,
  joinPlatformCampaign,
  leavePlatformCampaign,
  platformCampaignError,
  platformCampaignTerms,
  type PlatformCampaign,
  type PlatformCampaignsSnapshot,
} from "@/lib/merchant-platform-campaigns";

function shortDate(value: string | null) {
  if (!value) return "";
  return new Intl.DateTimeFormat("th-TH", { day: "numeric", month: "short", timeZone: "Asia/Bangkok" }).format(new Date(value));
}

function period(campaign: PlatformCampaign) {
  return campaign.ends_at ? `${shortDate(campaign.starts_at)} – ${shortDate(campaign.ends_at)}` : `เริ่ม ${shortDate(campaign.starts_at)} · ไม่มีวันจบ`;
}

/**
 * WYN-206: WYNOS campaigns. WYNOS Admin designs them and decides how much of
 * each discount WYNOS pays; the store chooses to join and sees, before
 * joining, exactly who pays what. WYNOS's part is owed back to the store.
 */
export function MerchantPlatformCampaigns({
  client,
  store,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  onMessage: (message: string) => void;
}) {
  const [snapshot, setSnapshot] = useState<PlatformCampaignsSnapshot | null>(null);
  const [loadError, setLoadError] = useState("");
  const [confirming, setConfirming] = useState<PlatformCampaign | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setSnapshot(await fetchPlatformCampaigns(client, store.id));
      setLoadError("");
    } catch (error) {
      setLoadError(platformCampaignError(error));
    }
  }, [client, store.id]);

  useEffect(() => {
    let live = true;
    void fetchPlatformCampaigns(client, store.id)
      .then((next) => { if (live) { setSnapshot(next); setLoadError(""); } })
      .catch((error) => { if (live) setLoadError(platformCampaignError(error)); });
    return () => { live = false; };
  }, [client, store.id]);

  const act = async (campaign: PlatformCampaign, join: boolean) => {
    setBusyId(campaign.id);
    try {
      if (join) await joinPlatformCampaign(client, store.id, campaign.id);
      else await leavePlatformCampaign(client, store.id, campaign.id);
      onMessage(join ? `เข้าร่วม “${campaign.name}” แล้ว` : `ออกจาก “${campaign.name}” แล้ว`);
      setConfirming(null);
      await load();
    } catch (error) {
      onMessage(platformCampaignError(error));
    } finally {
      setBusyId(null);
    }
  };

  if (loadError) {
    return <div className="wm-empty wm-empty--compact"><MerchantIcon3D name="campaign" size={64} /><strong>{loadError}</strong></div>;
  }
  if (!snapshot) return <div className="wm-empty wm-empty--compact"><span className="wm-mini-loader" aria-label="กำลังโหลด" /></div>;

  const owed = Number(snapshot.owed);
  return (
    <>
      <section className="wm-pc-owed">
        <small>WYNOS จะโอนคืนร้าน</small>
        <strong>{money(owed)}</strong>
        <span>{owed > 0 ? `ส่วนลดที่ WYNOS ออกให้ ${snapshot.owed_orders} ออเดอร์ที่ส่งสำเร็จ` : "ยังไม่มียอดค้างโอน"}</span>
      </section>

      <section className="wm-section">
        <div className="wm-section-title"><h2>แคมเปญจาก WYNOS</h2></div>
        {snapshot.campaigns.length ? (
          <div className="wm-pc-list">
            {snapshot.campaigns.map((campaign) => {
              const wynos = Number(campaign.platform_share_percent);
              return (
                <article key={campaign.id} className={`wm-pc-card ${campaign.joined ? "is-joined" : ""}`}>
                  <div className="wm-pc-head">
                    <MerchantIcon3D name="campaign" size={44} />
                    <div>
                      <strong>{campaign.name}</strong>
                      <small>{period(campaign)}</small>
                    </div>
                    {campaign.joined ? <b className="wm-pc-chip">เข้าร่วมแล้ว</b> : null}
                  </div>
                  <p className="wm-pc-terms">{platformCampaignTerms(campaign)}</p>
                  {campaign.first_order_only ? (
                    <p className="wm-pc-desc">เฉพาะการสั่งอาหารครั้งแรกทั่ว WYNOS Food · ร้านรับผิดชอบส่วนลด ฿20 เต็มจำนวน · ไม่ต้องใช้โค้ด</p>
                  ) : null}
                  {campaign.description ? <p className="wm-pc-desc">{campaign.description}</p> : null}
                  <div className="wm-pc-split" aria-label={`WYNOS ออก ${wynos}% ร้านออก ${100 - wynos}%`}>
                    <span className="wm-pc-bar"><i style={{ width: `${wynos}%` }} /></span>
                    <span><b>{`WYNOS ออก ${wynos}%`}</b> · {`ร้านออก ${100 - wynos}%`}</span>
                  </div>
                  {campaign.joined ? (
                    <div className="wm-pc-stats">
                      <span><small>ออเดอร์สำเร็จ</small><strong>{campaign.delivered_orders}</strong></span>
                      <span><small>ส่วนลดรวม</small><strong>{money(campaign.discount_total)}</strong></span>
                      <span><small>WYNOS ออกให้</small><strong>{money(campaign.platform_funded_total)}</strong></span>
                      <span><small>ร้านรับผิดชอบ</small><strong>{money(Math.max(0, Number(campaign.discount_total) - Number(campaign.platform_funded_total)))}</strong></span>
                    </div>
                  ) : null}
                  {snapshot.can_manage ? (
                    campaign.joined ? (
                      <button className="wm-secondary" type="button" disabled={busyId === campaign.id} onClick={() => void act(campaign, false)}>ออกจากแคมเปญ</button>
                    ) : (
                      <button className="wm-primary" type="button" disabled={busyId === campaign.id} onClick={() => setConfirming(campaign)}>เข้าร่วมแคมเปญ</button>
                    )
                  ) : null}
                </article>
              );
            })}
          </div>
        ) : (
          <div className="wm-empty wm-empty--compact"><MerchantIcon3D name="campaign" size={64} /><strong>ยังไม่มีแคมเปญจาก WYNOS ตอนนี้</strong><p>เมื่อทีม WYNOS เปิดแคมเปญใหม่ จะขึ้นที่หน้านี้ให้ร้านเลือกเข้าร่วม</p></div>
        )}
      </section>

      {snapshot.settlements.length ? (
        <section className="wm-section">
          <div className="wm-section-title"><h2>WYNOS โอนคืนแล้ว</h2></div>
          <div className="wm-money-list">
            {snapshot.settlements.map((settlement) => (
              <div key={settlement.id}>
                <span><strong>{settlement.reference}</strong><small>{`${settlement.order_count} ออเดอร์ · ${shortDate(settlement.created_at)}`}</small></span>
                <b>{money(settlement.amount)}</b>
              </div>
            ))}
          </div>
        </section>
      ) : null}

      {confirming ? (
        <div className="wm-sheet-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setConfirming(null); }}>
          <section className="wm-sheet" role="dialog" aria-modal="true" aria-label="เข้าร่วมแคมเปญ">
            <header><span /><h2>เข้าร่วมแคมเปญ</h2><span /></header>
            <div className="wm-sheet-body wm-pc-confirm">
              <strong>{confirming.name}</strong>
              <p>{platformCampaignTerms(confirming)}</p>
              <ul>
                <li>{`ทุกออเดอร์ที่ใช้แคมเปญนี้ WYNOS ออกส่วนลดให้ ${Number(confirming.platform_share_percent)}% ร้านออก ${100 - Number(confirming.platform_share_percent)}%`}</li>
                <li>ลูกค้าโอนเงินที่ลดแล้วเข้าร้านโดยตรง ส่วนที่ WYNOS ออก WYNOS จะโอนคืนร้านหลังส่งอาหารสำเร็จ</li>
                {confirming.first_order_only ? <li>ใช้ได้เฉพาะคำสั่งซื้อครั้งแรกของลูกค้าทั่ว WYNOS Food ยอดอาหารขั้นต่ำ ฿120 ลด ฿20</li> : null}
                <li>ใช้ได้ 1 ส่วนลดต่อออเดอร์ ระบบเลือกส่วนลดที่ลูกค้าประหยัดที่สุดให้อัตโนมัติ</li>
                <li>ออกจากแคมเปญได้ทุกเมื่อ</li>
              </ul>
              <button className="wm-primary wm-full" type="button" disabled={busyId === confirming.id} onClick={() => void act(confirming, true)}>
                {busyId === confirming.id ? "กำลังเข้าร่วม…" : "ยืนยันเข้าร่วม"}
              </button>
              <button className="wm-secondary wm-full" type="button" onClick={() => setConfirming(null)}>ยกเลิก</button>
            </div>
          </section>
        </div>
      ) : null}
    </>
  );
}
