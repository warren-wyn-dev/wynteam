"use client";

import {
  CalendarDays,
  ChevronDown,
  ChevronUp,
  Megaphone,
  Pencil,
  Plus,
  Tag,
  Trash2,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";

import type { FoodMenuItem, FoodStore } from "@/lib/food-merchant";
import { money } from "@/lib/food-merchant";
import {
  deleteMerchantCampaign,
  fetchMerchantCampaigns,
  saveMerchantCampaign,
  setMerchantCampaignActive,
  type MerchantCampaign,
  type MerchantCampaignDraft,
  type MerchantCampaignType,
} from "@/lib/merchant-campaigns";

function toLocalInput(value?: string | null) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) return "";
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

function blankDraft(): MerchantCampaignDraft {
  return {
    name: "",
    campaignType: "percentage",
    scope: "store",
    discountValue: "10",
    minSubtotal: "0",
    maxDiscount: "",
    startsAt: toLocalInput(),
    endsAt: "",
    usageLimit: "",
    itemIds: [],
  };
}

function campaignDraft(campaign: MerchantCampaign): MerchantCampaignDraft {
  return {
    id: campaign.id,
    name: campaign.name,
    campaignType: campaign.campaign_type,
    scope: campaign.scope,
    discountValue: String(campaign.discount_value ?? ""),
    minSubtotal: String(campaign.min_subtotal ?? 0),
    maxDiscount: campaign.max_discount == null ? "" : String(campaign.max_discount),
    startsAt: toLocalInput(campaign.starts_at),
    endsAt: campaign.ends_at ? toLocalInput(campaign.ends_at) : "",
    usageLimit: campaign.usage_limit == null ? "" : String(campaign.usage_limit),
    itemIds: campaign.item_ids,
  };
}

function campaignStatus(campaign: MerchantCampaign) {
  const now = new Date().getTime();
  const start = new Date(campaign.starts_at).getTime();
  const end = campaign.ends_at ? new Date(campaign.ends_at).getTime() : null;
  if (!campaign.is_active) return { key: "paused", label: "หยุดอยู่" };
  if (campaign.usage_limit != null && campaign.usage_count >= campaign.usage_limit) {
    return { key: "ended", label: "สิทธิ์ครบแล้ว" };
  }
  if (start > now) return { key: "scheduled", label: "ตั้งเวลาไว้" };
  if (end != null && end <= now) return { key: "ended", label: "จบแล้ว" };
  return { key: "active", label: "กำลังใช้งาน" };
}

function campaignOffer(campaign: MerchantCampaign) {
  if (campaign.campaign_type === "free_delivery") return "ส่งฟรี";
  if (campaign.campaign_type === "fixed") return "ลด " + money(campaign.discount_value);
  const max = campaign.max_discount ? " · สูงสุด " + money(campaign.max_discount) : "";
  return "ลด " + Number(campaign.discount_value) + "%" + max;
}

function dateText(value: string | null) {
  if (!value) return "ไม่กำหนด";
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export function MerchantCampaignCenter({
  client,
  store,
  menu,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  menu: FoodMenuItem[];
  onMessage: (message: string) => void;
}) {
  const [campaigns, setCampaigns] = useState<MerchantCampaign[]>([]);
  const [canManage, setCanManage] = useState(false);
  const [draft, setDraft] = useState<MerchantCampaignDraft | null>(null);
  const [busy, setBusy] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const load = useCallback(async () => {
    try {
      const result = await fetchMerchantCampaigns(client, store.id);
      setCampaigns(result.campaigns);
      setCanManage(result.can_manage);
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "โหลดโปรโมชั่นไม่สำเร็จ");
    }
  }, [client, onMessage, store.id]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  const activeCount = useMemo(
    () => campaigns.filter((campaign) => campaignStatus(campaign).key === "active").length,
    [campaigns],
  );

  const save = async () => {
    if (!draft) return;
    if (!draft.name.trim()) {
      onMessage("กรุณาตั้งชื่อโปรโมชั่น");
      return;
    }
    if (draft.scope === "items" && draft.campaignType !== "free_delivery" && !draft.itemIds.length) {
      onMessage("กรุณาเลือกอย่างน้อย 1 เมนู");
      return;
    }
    setBusy(true);
    try {
      await saveMerchantCampaign(client, store.id, draft);
      onMessage(draft.id ? "อัปเดตโปรโมชั่นแล้ว" : "สร้างโปรโมชั่นแล้ว");
      setDraft(null);
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "บันทึกโปรโมชั่นไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  const toggle = async (campaign: MerchantCampaign) => {
    setBusy(true);
    try {
      await setMerchantCampaignActive(client, store.id, campaign.id, !campaign.is_active);
      onMessage(campaign.is_active ? "หยุดโปรโมชั่นแล้ว" : "เปิดโปรโมชั่นแล้ว");
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "เปลี่ยนสถานะโปรโมชั่นไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  const remove = async (campaign: MerchantCampaign) => {
    if (!window.confirm(`ลบโปรโมชั่น “${campaign.name}”?`)) return;
    setBusy(true);
    try {
      await deleteMerchantCampaign(client, store.id, campaign.id);
      onMessage("ลบโปรโมชั่นแล้ว");
      if (draft?.id === campaign.id) setDraft(null);
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "ลบโปรโมชั่นไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  const toggleItem = (id: string) => {
    if (!draft) return;
    setDraft({
      ...draft,
      itemIds: draft.itemIds.includes(id)
        ? draft.itemIds.filter((item) => item !== id)
        : [...draft.itemIds, id],
    });
  };

  return (
    <section className="wm-campaign-center">
      <div className="wm-campaign-head">
        <div>
          <span className="wm-campaign-icon"><Megaphone size={21} /></span>
          <span>
            <strong>โปรโมชั่นของร้าน</strong>
            <small>{activeCount ? `${activeCount} โปรโมชั่นกำลังใช้งาน` : "ลดราคาเองเพื่อดึงลูกค้าบน WYNOS Food"}</small>
          </span>
        </div>
        <div className="wm-campaign-head-actions">
          {canManage ? (
            <button className="wm-small-primary" type="button" onClick={() => setDraft(blankDraft())}>
              <Plus size={16} /> สร้างโปรโมชั่น
            </button>
          ) : null}
          <button className="wm-campaign-collapse" type="button" aria-label={expanded ? "ย่อโปรโมชั่น" : "ขยายโปรโมชั่น"} onClick={() => setExpanded((value) => !value)}>
            {expanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
          </button>
        </div>
      </div>

      {expanded ? (
        <>
          <p className="wm-campaign-note">
            WYNOS Food จะเลือกโปรโมชั่นที่ลูกค้าประหยัดได้มากที่สุดให้อัตโนมัติ 1 โปรโมชั่นต่อออเดอร์ และไม่ซ้อนส่วนลด
          </p>

          {draft ? (
            <div className="wm-campaign-editor">
              <div className="wm-campaign-editor-title">
                <strong>{draft.id ? "แก้ไขโปรโมชั่น" : "สร้างโปรโมชั่นใหม่"}</strong>
                <button type="button" onClick={() => setDraft(null)}>ยกเลิก</button>
              </div>

              <label className="wm-campaign-field">
                <span>ชื่อโปรโมชั่น</span>
                <input value={draft.name} maxLength={80} onChange={(event) => setDraft({ ...draft, name: event.target.value })} placeholder="เช่น ลดมื้อเย็น 15%" />
              </label>

              <div className="wm-campaign-form-grid">
                <label className="wm-campaign-field">
                  <span>ประเภทโปร</span>
                  <select value={draft.campaignType} onChange={(event) => {
                    const campaignType = event.target.value as MerchantCampaignType;
                    setDraft({
                      ...draft,
                      campaignType,
                      scope: campaignType === "free_delivery" ? "store" : draft.scope,
                      discountValue: campaignType === "free_delivery" ? "0" : draft.discountValue || "10",
                    });
                  }}>
                    <option value="percentage">ลดเป็นเปอร์เซ็นต์</option>
                    <option value="fixed">ลดเป็นจำนวนเงิน</option>
                    <option value="free_delivery">ส่งฟรี</option>
                  </select>
                </label>

                {draft.campaignType !== "free_delivery" ? (
                  <label className="wm-campaign-field">
                    <span>{draft.campaignType === "percentage" ? "ส่วนลด (%)" : "ส่วนลด (บาท)"}</span>
                    <input type="number" min="0" step="1" inputMode="decimal" value={draft.discountValue} onChange={(event) => setDraft({ ...draft, discountValue: event.target.value })} />
                  </label>
                ) : (
                  <div className="wm-campaign-field is-readonly"><span>ส่วนลด</span><strong>ค่าส่งทั้งหมด</strong></div>
                )}

                <label className="wm-campaign-field">
                  <span>ยอดขั้นต่ำ</span>
                  <input type="number" min="0" step="1" inputMode="decimal" value={draft.minSubtotal} onChange={(event) => setDraft({ ...draft, minSubtotal: event.target.value })} />
                </label>

                {draft.campaignType === "percentage" ? (
                  <label className="wm-campaign-field">
                    <span>ลดสูงสุด (ไม่บังคับ)</span>
                    <input type="number" min="0" step="1" inputMode="decimal" value={draft.maxDiscount} onChange={(event) => setDraft({ ...draft, maxDiscount: event.target.value })} placeholder="ไม่จำกัด" />
                  </label>
                ) : null}

                {draft.campaignType !== "free_delivery" ? (
                  <label className="wm-campaign-field">
                    <span>ใช้กับ</span>
                    <select value={draft.scope} onChange={(event) => setDraft({ ...draft, scope: event.target.value === "items" ? "items" : "store" })}>
                      <option value="store">ทั้งร้าน</option>
                      <option value="items">เฉพาะบางเมนู</option>
                    </select>
                  </label>
                ) : null}

                <label className="wm-campaign-field">
                  <span>จำนวนสิทธิ์ (ไม่บังคับ)</span>
                  <input type="number" min="1" step="1" inputMode="numeric" value={draft.usageLimit} onChange={(event) => setDraft({ ...draft, usageLimit: event.target.value })} placeholder="ไม่จำกัด" />
                </label>

                <label className="wm-campaign-field">
                  <span>เริ่ม</span>
                  <input type="datetime-local" value={draft.startsAt} onChange={(event) => setDraft({ ...draft, startsAt: event.target.value })} />
                </label>

                <label className="wm-campaign-field">
                  <span>สิ้นสุด (ไม่บังคับ)</span>
                  <input type="datetime-local" value={draft.endsAt} onChange={(event) => setDraft({ ...draft, endsAt: event.target.value })} />
                </label>
              </div>

              {draft.scope === "items" && draft.campaignType !== "free_delivery" ? (
                <div className="wm-campaign-menu-picker">
                  <strong>เลือกเมนูที่ร่วมรายการ</strong>
                  <div>
                    {menu.map((item) => (
                      <label key={item.id}>
                        <input type="checkbox" checked={draft.itemIds.includes(item.id)} onChange={() => toggleItem(item.id)} />
                        <span>{item.name}<small>{money(item.price)}{item.is_available ? "" : " · ปิดขายอยู่"}</small></span>
                      </label>
                    ))}
                  </div>
                </div>
              ) : null}

              <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void save()}>
                {busy ? "กำลังบันทึก…" : draft.id ? "บันทึกการแก้ไข" : "เปิดโปรโมชั่น"}
              </button>
            </div>
          ) : null}

          <div className="wm-campaign-list">
            {campaigns.length ? campaigns.map((campaign) => {
              const status = campaignStatus(campaign);
              return (
                <article className="wm-campaign-card" key={campaign.id}>
                  <div className="wm-campaign-card-top">
                    <span className="wm-campaign-card-icon"><Tag size={18} /></span>
                    <span className="wm-campaign-card-copy">
                      <strong>{campaign.name}</strong>
                      <small>{campaignOffer(campaign)} · {campaign.scope === "items" ? String(campaign.item_ids.length) + " เมนู" : "ทั้งร้าน"}</small>
                    </span>
                    <span className={"wm-campaign-status is-" + status.key}>{status.label}</span>
                  </div>

                  <div className="wm-campaign-schedule">
                    <CalendarDays size={15} />
                    <span>{dateText(campaign.starts_at)} → {dateText(campaign.ends_at)}</span>
                  </div>

                  <div className="wm-campaign-metrics">
                    <span><small>ใช้แล้ว</small><strong>{campaign.redeemed_count}{campaign.usage_limit ? " / " + campaign.usage_limit : ""}</strong></span>
                    <span><small>ออเดอร์สำเร็จ</small><strong>{campaign.delivered_orders}</strong></span>
                    <span><small>ยอดขายจากโปร</small><strong>{money(campaign.sales_total)}</strong></span>
                    <span><small>ส่วนลดรวม</small><strong>{money(campaign.discount_total)}</strong></span>
                  </div>

                  {Number(campaign.min_subtotal) > 0 ? <p className="wm-campaign-rule">เมื่อสั่งขั้นต่ำ {money(campaign.min_subtotal)}</p> : null}

                  {canManage ? (
                    <div className="wm-campaign-actions">
                      <button type="button" disabled={busy} onClick={() => setDraft(campaignDraft(campaign))}><Pencil size={15} /> แก้ไข</button>
                      <button type="button" disabled={busy} onClick={() => void toggle(campaign)}>{campaign.is_active ? "หยุดชั่วคราว" : "เปิดใช้งาน"}</button>
                      <button className="is-danger" type="button" disabled={busy} onClick={() => void remove(campaign)}><Trash2 size={15} /> ลบ</button>
                    </div>
                  ) : null}
                </article>
              );
            }) : (
              <div className="wm-campaign-empty">
                <Megaphone size={28} strokeWidth={1.5} />
                <strong>ยังไม่มีโปรโมชั่น</strong>
                <p>สร้างส่วนลด ส่งฟรี หรือโปรเฉพาะเมนูได้จากที่นี่</p>
              </div>
            )}
          </div>
        </>
      ) : null}
    </section>
  );
}
