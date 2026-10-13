import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useRef, useState } from "react";

import { createOrderRecovery } from "@/lib/order-recovery";

export type OrderModificationItem = {
  order_item_id: string;
  item_name: string;
  original_quantity: number;
  quantity: number;
};

export type OrderModificationStatus = "pending_customer" | "accepted_pending_execution" | "rejected" | "withdrawn";

export type OrderModification = {
  id: string;
  order_id: string;
  reason: string;
  proposed_items: OrderModificationItem[];
  status: OrderModificationStatus;
  created_at: string;
};

export type ModificationOrderItem = { id: string; item_name: string; quantity: number };
export type ModificationDraftItem = { order_item_id: string; quantity: number };
export type OrderModificationFeatures = { enabled: boolean; canManageOrders: boolean };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STATUSES = new Set<OrderModificationStatus>(["pending_customer", "accepted_pending_execution", "rejected", "withdrawn"]);

export const MODIFICATION_EXECUTION_NOTICE = "บันทึกความยินยอมเท่านั้น รายการอาหารและยอดเงินยังไม่เปลี่ยน ระบบยังไม่รองรับการคิดราคาใหม่ เรียกเก็บเพิ่ม หรือคืนเงินจากคำขอนี้";

export function modificationStatusLabel(status: OrderModificationStatus): string {
  switch (status) {
    case "pending_customer": return "รอลูกค้ายืนยัน";
    case "accepted_pending_execution": return "ยืนยันคำขอแล้ว รอร้านดำเนินการ";
    case "rejected": return "ลูกค้าไม่ยินยอม รายการเดิมไม่เปลี่ยน";
    case "withdrawn": return "ถอนคำขอแล้ว";
  }
}

/** Client validation improves the editor UX; the RPC validates the same boundary. */
export function buildModificationItems(
  orderItems: ModificationOrderItem[],
  quantities: Record<string, string>,
): ModificationDraftItem[] {
  if (!orderItems.length || orderItems.length > 100) throw new Error("จำนวนรายการอาหารไม่ถูกต้อง");
  const changed: ModificationDraftItem[] = [];
  for (const item of orderItems) {
    const input = quantities[item.id] ?? String(item.quantity);
    if (!/^(0|[1-9][0-9]?)$/.test(input) || !Number.isInteger(item.quantity) || item.quantity < 1) {
      throw new Error("ระบุจำนวนเต็มตั้งแต่ 0 ถึงจำนวนเดิมของแต่ละรายการ");
    }
    const quantity = Number(input);
    if (quantity > item.quantity) throw new Error("คำขอนี้รองรับเฉพาะลดจำนวนหรือนำรายการออก");
    if (quantity < item.quantity) changed.push({ order_item_id: item.id, quantity });
  }
  if (!changed.length) throw new Error("เลือกรายการที่ต้องการลดจำนวนหรือนำออกก่อนส่งคำขอ");
  return changed;
}

export function parseOrderModifications(value: unknown, orderId: string): OrderModification[] {
  if (!Array.isArray(value)) throw new Error("โหลดคำขอแก้ไขรายการไม่สำเร็จ");
  return value.map((row: unknown) => {
    if (!row || typeof row !== "object") throw new Error("ข้อมูลคำขอแก้ไขรายการไม่ถูกต้อง");
    const request = row as Record<string, unknown>;
    if (typeof request.id !== "string" || !UUID.test(request.id) || request.order_id !== orderId
      || typeof request.reason !== "string" || !request.reason.trim() || request.reason.length > 800
      || !STATUSES.has(request.status as OrderModificationStatus)
      || typeof request.created_at !== "string" || !Number.isFinite(Date.parse(request.created_at))
      || !Array.isArray(request.proposed_items) || !request.proposed_items.length || request.proposed_items.length > 100) {
      throw new Error("ข้อมูลคำขอแก้ไขรายการไม่ถูกต้อง");
    }
    const items = request.proposed_items.map((value: unknown): OrderModificationItem => {
      if (!value || typeof value !== "object") throw new Error("ข้อมูลรายการที่ขอแก้ไขไม่ถูกต้อง");
      const item = value as Record<string, unknown>;
      if (typeof item.order_item_id !== "string" || !UUID.test(item.order_item_id)
        || typeof item.item_name !== "string" || !item.item_name.trim()
        || !Number.isInteger(item.original_quantity) || Number(item.original_quantity) < 1
        || !Number.isInteger(item.quantity) || Number(item.quantity) < 0
        || Number(item.quantity) > Number(item.original_quantity)) {
        throw new Error("ข้อมูลรายการที่ขอแก้ไขไม่ถูกต้อง");
      }
      return { order_item_id: item.order_item_id, item_name: item.item_name,
        original_quantity: Number(item.original_quantity), quantity: Number(item.quantity) };
    });
    if (new Set(items.map((item) => item.order_item_id)).size !== items.length) {
      throw new Error("ข้อมูลรายการที่ขอแก้ไขไม่ถูกต้อง");
    }
    const changed = items.filter((item) => item.quantity < item.original_quantity);
    if (!changed.length) throw new Error("คำขอต้องมีรายการที่เปลี่ยนแปลง");
    return { id: request.id, order_id: orderId, reason: request.reason,
      proposed_items: changed, status: request.status as OrderModificationStatus, created_at: request.created_at };
  });
}

/** Missing, malformed or unavailable flags never enable a new behavior. */
export async function fetchOrderModificationFeatures(client: SupabaseClient, storeId?: string): Promise<OrderModificationFeatures> {
  if (storeId && !UUID.test(storeId)) return { enabled: false, canManageOrders: false };
  try {
    const { data, error } = await client.rpc("food_order_operations_features", storeId ? { p_store_id: storeId } : undefined);
    return { enabled: !error && data?.order_modifications === true,
      canManageOrders: !error && Boolean(storeId) && data?.can_manage_orders === true };
  } catch {
    return { enabled: false, canManageOrders: false };
  }
}

export async function orderModificationsEnabled(client: SupabaseClient): Promise<boolean> {
  return (await fetchOrderModificationFeatures(client)).enabled;
}

export async function fetchOrderModifications(client: SupabaseClient, orderId: string, storeId?: string) {
  if (!UUID.test(orderId)) throw new Error("ออเดอร์ไม่ถูกต้อง");
  const features = await fetchOrderModificationFeatures(client, storeId);
  if (!features.enabled) return { ...features, requests: [] as OrderModification[] };
  const { data, error } = await client.from("food_order_modifications")
    .select("id,order_id,reason,proposed_items,status,created_at")
    .eq("order_id", orderId).order("created_at", { ascending: false }).limit(30);
  if (error) throw new Error("โหลดคำขอแก้ไขรายการไม่สำเร็จ กรุณาลองใหม่");
  return { ...features, requests: parseOrderModifications(data ?? [], orderId) };
}

export async function proposeOrderModification(client: SupabaseClient, input: {
  orderId: string; storeId: string; requestKey: string; reason: string; items: ModificationDraftItem[];
}): Promise<string> {
  const reason = input.reason.trim();
  if (!UUID.test(input.orderId) || !UUID.test(input.storeId) || !UUID.test(input.requestKey) || !reason || reason.length > 800
    || !input.items.length || input.items.length > 100
    || input.items.some((item) => !UUID.test(item.order_item_id) || !Number.isInteger(item.quantity)
      || item.quantity < 0 || item.quantity > 99)
    || new Set(input.items.map((item) => item.order_item_id)).size !== input.items.length) {
    throw new Error("ระบุเหตุผลและจำนวนอาหารให้ถูกต้องก่อนส่งคำขอ");
  }
  const features = await fetchOrderModificationFeatures(client, input.storeId);
  if (!features.enabled || !features.canManageOrders) throw new Error("ยังไม่เปิดใช้คำขอแก้ไขรายการหรือไม่มีสิทธิ์จัดการออเดอร์");
  const { data, error } = await client.rpc("merchant_propose_food_order_modification", {
    p_order_id: input.orderId, p_request_key: input.requestKey, p_reason: reason, p_items: input.items,
  });
  if (error || typeof data !== "string" || !UUID.test(data)) {
    throw new Error("ส่งคำขอไม่สำเร็จ กรุณาโหลดข้อมูลล่าสุดแล้วลองใหม่");
  }
  return data;
}

export async function respondOrderModification(client: SupabaseClient, modificationId: string, accept: boolean) {
  if (!UUID.test(modificationId) || typeof accept !== "boolean") throw new Error("คำตอบไม่ถูกต้อง");
  if (!await orderModificationsEnabled(client)) throw new Error("ยังไม่เปิดใช้คำขอแก้ไขรายการ");
  const { data, error } = await client.rpc("food_respond_order_modification", {
    p_modification_id: modificationId, p_accept: accept,
  });
  const expected: OrderModificationStatus = accept ? "accepted_pending_execution" : "rejected";
  if (error || data !== expected) throw new Error("บันทึกคำตอบไม่สำเร็จ กรุณาโหลดข้อมูลล่าสุดแล้วลองใหม่");
  return expected;
}

export function subscribeOrderModificationEvents(
  client: SupabaseClient, orderId: string, onChange: () => void, onStatus: (status: string) => void,
) {
  if (!UUID.test(orderId)) throw new Error("ออเดอร์ไม่ถูกต้อง");
  return client.channel(`food-order-modification:${orderId}`)
    .on("postgres_changes", { event: "INSERT", schema: "public", table: "food_order_events", filter: `order_id=eq.${orderId}` }, onChange)
    .subscribe(onStatus);
}

/** Both participants recover authoritative consent state after missed events. */
export function useOrderModifications(client: SupabaseClient, orderId: string, storeId?: string) {
  const [state, setState] = useState({ scope: orderId, enabled: false,
    canManageOrders: false, requests: [] as OrderModification[], loading: true, error: "" });
  const generation = useRef(0);
  const active = useRef(false);
  const reload = useCallback(async () => {
    const current = ++generation.current;
    try {
      const next = await fetchOrderModifications(client, orderId, storeId);
      if (active.current && current === generation.current) {
        setState({ scope: orderId, ...next, loading: false, error: "" });
      }
    } catch {
      if (active.current && current === generation.current) {
        setState({ scope: orderId, enabled: false, canManageOrders: false, requests: [], loading: false,
          error: "โหลดคำขอแก้ไขรายการไม่สำเร็จ กรุณาลองใหม่" });
      }
    }
  }, [client, orderId, storeId]);

  useEffect(() => {
    active.current = true;
    return () => {
      active.current = false;
      generation.current += 1;
    };
  }, [client, orderId, reload]);

  const enabled = state.scope === orderId && state.enabled;
  useEffect(() => {
    const recovery = createOrderRecovery(reload, { document, window });
    recovery.request();
    const channel = enabled
      ? subscribeOrderModificationEvents(client, orderId, recovery.request, recovery.onSubscriptionStatus) : null;
    return () => {
      recovery.dispose();
      if (channel) void client.removeChannel(channel);
    };
  }, [client, orderId, enabled, reload]);

  return state.scope === orderId ? { ...state, reload }
    : { enabled: false, canManageOrders: false, requests: [], loading: true, error: "", reload };
}
