"use client";

import {
  AlertTriangle,
  BellRing,
  CheckCircle2,
  Clock3,
  History,
  Plus,
  ShieldCheck,
  UserRoundCog,
  Users,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";

import { MerchantNotificationTest } from "@/components/merchant/merchant-notification-test";
import type { FoodOrder, FoodStore } from "@/lib/food-merchant";
import {
  addMerchantStaff,
  fetchMerchantActivity,
  fetchMerchantNotifications,
  fetchMerchantStaff,
  fetchStoreReadiness,
  markAllMerchantNotificationsRead,
  markMerchantNotificationRead,
  setMerchantRefundStatus,
  updateMerchantStaff,
  type MerchantActivity,
  type MerchantNotification,
  type MerchantStaffMember,
  type MerchantStaffRole,
  type MerchantStoreReadiness,
} from "@/lib/merchant-core";

const READINESS_LABELS: Record<string, string> = {
  name: "ชื่อร้าน",
  phone: "เบอร์ร้าน",
  address: "ที่อยู่ร้าน",
  business_hours: "เวลาเปิด–ปิด",
  delivery_area: "พื้นที่จัดส่ง",
  payment: "ช่องทางรับเงิน",
  menu: "เมนูที่เปิดขาย",
};

const ROLE_LABELS: Record<MerchantStaffRole, string> = {
  owner: "Owner",
  admin: "Admin",
  manager: "Manager",
  orders: "Orders",
  support: "Support",
  delivery: "Delivery",
};

const ACTION_LABELS: Record<string, string> = {
  staff_added: "เพิ่มทีมงาน",
  staff_updated: "แก้ไขทีมงาน",
  staff_disabled: "ปิดสิทธิ์ทีมงาน",
  store_publish_changed: "เปลี่ยนสถานะเผยแพร่ร้าน",
  store_open_changed: "เปลี่ยนสถานะเปิดร้าน",
  store_updated: "แก้ไขข้อมูลร้าน",
  menu_created: "เพิ่มเมนู",
  menu_deleted: "ลบเมนู",
  menu_updated: "แก้ไขเมนู",
  menu_price_changed: "เปลี่ยนราคาเมนู",
  menu_availability_changed: "เปลี่ยนสถานะขายเมนู",
  order_status_changed: "เปลี่ยนสถานะออเดอร์",
  payment_status_changed: "เปลี่ยนสถานะการชำระเงิน",
  refund_status_changed: "เปลี่ยนสถานะคืนเงิน",
  campaign_created: "สร้างแคมเปญ",
  campaign_updated: "แก้ไขแคมเปญ",
  campaign_active_changed: "เปลี่ยนสถานะแคมเปญ",
  campaign_deleted: "ลบแคมเปญ",
};

const STAFF_ROLES: Array<Exclude<MerchantStaffRole, "owner">> = [
  "admin",
  "manager",
  "orders",
  "support",
  "delivery",
];

function shortDate(value: string) {
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

function activityDetail(item: MerchantActivity) {
  const detail = item.detail ?? {};
  const order = typeof detail.order_number === "string" ? `#${detail.order_number}` : "";
  const name = typeof detail.name === "string" ? detail.name : "";
  const from = detail.from;
  const to = detail.to;
  if (from !== undefined && to !== undefined) return [order || name, `${String(from)} → ${String(to)}`].filter(Boolean).join(" · ");
  if (name) return name;
  if (typeof detail.username === "string") return `@${detail.username} · ${String(detail.role ?? "")}`;
  return order;
}

export function MerchantStoreTools({
  client,
  store,
  userId,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  userId: string;
  onMessage: (message: string) => void;
}) {
  const [readiness, setReadiness] = useState<MerchantStoreReadiness | null>(null);
  const [staff, setStaff] = useState<MerchantStaffMember[]>([]);
  const [notifications, setNotifications] = useState<MerchantNotification[]>([]);
  const [activity, setActivity] = useState<MerchantActivity[]>([]);
  const [username, setUsername] = useState("");
  const [role, setRole] = useState<Exclude<MerchantStaffRole, "owner">>("orders");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const [nextReadiness, nextStaff, nextNotifications, nextActivity] = await Promise.all([
        fetchStoreReadiness(client, store.id),
        fetchMerchantStaff(client, store.id),
        store.merchant_account_id
          ? fetchMerchantNotifications(client, store.merchant_account_id, 20)
          : Promise.resolve([]),
        store.merchant_account_id
          ? fetchMerchantActivity(client, store.merchant_account_id, 20)
          : Promise.resolve([]),
      ]);
      setReadiness(nextReadiness);
      setStaff(nextStaff);
      setNotifications(nextNotifications);
      setActivity(nextActivity);
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "โหลดข้อมูล Merchant เพิ่มเติมไม่สำเร็จ");
    }
  }, [client, onMessage, store.id, store.merchant_account_id]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  const currentMember = staff.find((item) => item.user_id === userId && item.active);
  const canManageStaff = currentMember?.role === "owner" || currentMember?.role === "admin";
  const unread = useMemo(() => notifications.filter((item) => !item.read_at).length, [notifications]);

  const addStaff = async () => {
    setBusy(true);
    try {
      await addMerchantStaff(client, store.id, username, role);
      setUsername("");
      onMessage("เพิ่มทีมงานแล้ว");
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "เพิ่มทีมงานไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  const updateStaff = async (
    member: MerchantStaffMember,
    nextRole: Exclude<MerchantStaffRole, "owner">,
    active: boolean,
  ) => {
    setBusy(true);
    try {
      await updateMerchantStaff(client, store.id, member.user_id, nextRole, active);
      onMessage(active ? "อัปเดตสิทธิ์ทีมงานแล้ว" : "ปิดสิทธิ์ทีมงานแล้ว");
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "อัปเดตทีมงานไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  const readNotification = async (item: MerchantNotification) => {
    if (item.read_at) return;
    try {
      await markMerchantNotificationRead(client, item.id);
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "อัปเดตการแจ้งเตือนไม่สำเร็จ");
    }
  };

  const markAllRead = async () => {
    if (!store.merchant_account_id || !unread) return;
    try {
      await markAllMerchantNotificationsRead(client, store.merchant_account_id);
      await load();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "อัปเดตการแจ้งเตือนไม่สำเร็จ");
    }
  };

  return (
    <div className="wm-core-tools">
      <section className={`wm-readiness-card ${readiness?.ready ? "is-ready" : ""}`}>
        <div className="wm-core-heading">
          <span className="wm-core-icon">{readiness?.ready ? <ShieldCheck size={21} /> : <AlertTriangle size={21} />}</span>
          <span>
            <strong>ความพร้อมของร้าน</strong>
            <small>{readiness?.ready ? "พร้อมเผยแพร่และรับออเดอร์" : "เติมข้อมูลที่จำเป็นก่อนเผยแพร่ร้าน"}</small>
          </span>
        </div>
        {readiness && !readiness.ready ? (
          <div className="wm-readiness-missing">
            {readiness.missing.map((key) => <span key={key}>{READINESS_LABELS[key] ?? key}</span>)}
          </div>
        ) : null}
      </section>

      <section className="wm-core-section">
        <div className="wm-core-section-head">
          <div><Users size={20} /><span><strong>ทีมงาน</strong><small>{staff.filter((item) => item.active).length} คนที่ใช้งานอยู่</small></span></div>
        </div>

        {canManageStaff ? (
          <div className="wm-staff-add">
            <label>
              <span>บัญชี WYNOS</span>
              <input value={username} onChange={(event) => setUsername(event.target.value)} placeholder="@username" />
            </label>
            <label>
              <span>สิทธิ์</span>
              <select value={role} onChange={(event) => setRole(event.target.value as Exclude<MerchantStaffRole, "owner">)}>
                {STAFF_ROLES.map((item) => <option key={item} value={item}>{ROLE_LABELS[item]}</option>)}
              </select>
            </label>
            <button className="wm-small-primary" type="button" disabled={busy || !username.trim()} onClick={() => void addStaff()}>
              <Plus size={16} /> เพิ่ม
            </button>
          </div>
        ) : null}

        <div className="wm-staff-list">
          {staff.map((member) => {
            const immutable = member.role === "owner" || !canManageStaff;
            return (
              <div className={`wm-staff-row ${member.active ? "" : "is-disabled"}`} key={member.user_id}>
                <span className="wm-staff-avatar"><UserRoundCog size={18} /></span>
                <span className="wm-staff-copy">
                  <strong>{member.display_name || member.username || "WYNOS User"}</strong>
                  <small>{member.username ? `@${member.username}` : ""}</small>
                </span>
                {immutable ? (
                  <span className="wm-role-pill">{ROLE_LABELS[member.role]}</span>
                ) : (
                  <>
                    <select
                      value={member.role}
                      disabled={busy}
                      onChange={(event) => void updateStaff(
                        member,
                        event.target.value as Exclude<MerchantStaffRole, "owner">,
                        member.active,
                      )}
                    >
                      {STAFF_ROLES.map((item) => <option key={item} value={item}>{ROLE_LABELS[item]}</option>)}
                    </select>
                    <button
                      className="wm-text-button"
                      type="button"
                      disabled={busy}
                      onClick={() => void updateStaff(
                        member,
                        member.role as Exclude<MerchantStaffRole, "owner">,
                        !member.active,
                      )}
                    >
                      {member.active ? "ปิดสิทธิ์" : "เปิดสิทธิ์"}
                    </button>
                  </>
                )}
              </div>
            );
          })}
        </div>
      </section>

      <section className="wm-core-section">
        <div className="wm-core-section-head">
          <div><BellRing size={20} /><span><strong>การแจ้งเตือน Merchant</strong><small>{unread ? `${unread} รายการยังไม่ได้อ่าน` : "อ่านครบแล้ว"}</small></span></div>
          {unread ? <button type="button" onClick={() => void markAllRead()}>อ่านทั้งหมด</button> : null}
        </div>
        <div className="wm-core-feed">
          {notifications.length ? notifications.slice(0, 8).map((item) => (
            <button className={item.read_at ? "" : "is-unread"} type="button" key={item.id} onClick={() => void readNotification(item)}>
              <span className="wm-feed-dot" />
              <span><strong>{item.reason}</strong><small>{shortDate(item.created_at)}</small></span>
            </button>
          )) : <p className="wm-core-empty">ยังไม่มีการแจ้งเตือน Merchant</p>}
        </div>
      </section>

      <MerchantNotificationTest
        client={client}
        store={store}
        userId={userId}
        onMessage={onMessage}
        onReload={load}
      />

      <section className="wm-core-section">
        <div className="wm-core-section-head">
          <div><History size={20} /><span><strong>Activity Log</strong><small>กิจกรรมล่าสุดของร้านและทีมงาน</small></span></div>
        </div>
        <div className="wm-activity-list">
          {activity.length ? activity.slice(0, 10).map((item) => (
            <div key={item.id}>
              <span className="wm-activity-icon"><Clock3 size={15} /></span>
              <span>
                <strong>{ACTION_LABELS[item.action] ?? item.action}</strong>
                <small>{activityDetail(item) || "WYNOS Merchant"} · {item.actor_username_snapshot ? `@${item.actor_username_snapshot}` : "ระบบ"} · {shortDate(item.created_at)}</small>
              </span>
            </div>
          )) : <p className="wm-core-empty">ยังไม่มีกิจกรรมที่บันทึกไว้</p>}
        </div>
      </section>
    </div>
  );
}

export function RefundControls({
  client,
  order,
  onMessage,
  onReload,
}: {
  client: SupabaseClient;
  order: FoodOrder;
  onMessage: (message: string) => void;
  onReload: () => void;
}) {
  const [note, setNote] = useState(order.refund_note ?? "");
  const [busy, setBusy] = useState(false);
  const status = order.refund_status ?? "none";
  const eligible = order.status === "cancelled"
    && (order.payment_status === "paid" || order.payment_status === "refunded" || status !== "none");

  if (!eligible) return null;

  const run = async (next: "pending" | "refunded" | "failed", success: string) => {
    setBusy(true);
    try {
      await setMerchantRefundStatus(client, order.id, next, note);
      onMessage(success);
      onReload();
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "อัปเดตการคืนเงินไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="wm-detail-section wm-refund-box">
      <div className="wm-refund-title">
        <div>
          {status === "refunded" ? <CheckCircle2 size={22} /> : <AlertTriangle size={22} />}
          <span><strong>การคืนเงิน</strong><small>ออเดอร์นี้ชำระเงินแล้วและถูกยกเลิก</small></span>
        </div>
        <b className={`wm-refund-status is-${status}`}>
          {status === "pending" ? "รอคืนเงิน" : status === "refunded" ? "คืนเงินแล้ว" : status === "failed" ? "มีปัญหา" : "ยังไม่เริ่ม"}
        </b>
      </div>

      {order.refund_requested_at ? <p>เริ่มกระบวนการ: {shortDate(order.refund_requested_at)}</p> : null}
      {order.refunded_at ? <p>คืนเงินสำเร็จ: {shortDate(order.refunded_at)}</p> : null}

      {status !== "refunded" ? (
        <>
          <label>
            หมายเหตุการคืนเงิน
            <textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="เช่น คืนผ่าน PromptPay / เลขอ้างอิง" />
          </label>
          <div className="wm-two-actions">
            {status !== "pending" ? (
              <button className="wm-secondary" type="button" disabled={busy} onClick={() => void run("pending", "ตั้งสถานะรอคืนเงินแล้ว")}>
                รอคืนเงิน
              </button>
            ) : (
              <button className="wm-secondary" type="button" disabled={busy} onClick={() => void run("failed", "บันทึกปัญหาการคืนเงินแล้ว")}>
                คืนเงินมีปัญหา
              </button>
            )}
            <button className="wm-primary" type="button" disabled={busy} onClick={() => void run("refunded", "ยืนยันคืนเงินแล้ว")}>
              ยืนยันคืนเงินแล้ว
            </button>
          </div>
        </>
      ) : order.refund_note ? <p>{order.refund_note}</p> : null}
    </section>
  );
}
