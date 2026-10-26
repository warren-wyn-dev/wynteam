import type { SupabaseClient } from "@supabase/supabase-js";
import { uploadFoodPrivateImage } from "@/lib/food-merchant";

// Cross-session contract v1. Authorization and transitions remain server-owned.
export const STRIPE_SETUP_PAUSED = true;
export class FulfillmentError extends Error {}
export function fulfillmentError(error: unknown): string {
  const message = error && typeof error === "object" && "message" in error ? String(error.message) : "";
  if (message.includes("pickup_requires_schedule")) return "pickup_requires_schedule: กรุณาตั้งเวลาเปิดร้านก่อนเปิดรับเองที่ร้าน";
  if (message.includes("at_least_one_mode")) return "at_least_one_mode: ต้องเปิดรูปแบบรับอาหารอย่างน้อยหนึ่งแบบ";
  return "บันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง";
}
async function rpc(client: SupabaseClient, name: string, args: Record<string, unknown>) {
  const { error } = await client.rpc(name, args);
  if (error) throw new FulfillmentError(fulfillmentError(error));
}
export type FulfillmentSettings = { pickup: boolean; delivery: boolean; cod: boolean; prepMinutes: number };
export async function setStoreFulfillment(client: SupabaseClient, storeId: string, settings: FulfillmentSettings) {
  if (![settings.pickup, settings.delivery, settings.cod].every(v => typeof v === "boolean") ||
      !Number.isInteger(settings.prepMinutes) || settings.prepMinutes < 5 || settings.prepMinutes > 120) throw new FulfillmentError("เวลาเตรียมอาหารต้องเป็นจำนวนเต็ม 5–120 นาที");
  await rpc(client, "food_store_set_fulfillment", { p_store_id: storeId, p_pickup: settings.pickup, p_delivery: settings.delivery, p_cod: settings.cod, p_prep_minutes: settings.prepMinutes });
}
export async function resolveCancelRequest(client: SupabaseClient, orderId: string, approve: boolean, refund: boolean, note = "") {
  await rpc(client, "food_resolve_cancel_request", { p_order_id: orderId, p_approve: approve, p_refund: approve && refund, p_note: note });
}
export async function markStoreRefunded(client: SupabaseClient, storeId: string, orderId: string, path: string, note = "") {
  if (!path.startsWith(`food-refund-slips/${storeId}/${orderId}/`) || path.includes("..")) throw new FulfillmentError("สลิปคืนเงินไม่ตรงกับออเดอร์");
  await rpc(client, "food_store_mark_refunded", { p_order_id: orderId, p_refund_slip_path: path, p_note: note });
}
export async function uploadRefundSlip(client: SupabaseClient, storeId: string, orderId: string, file: File) {
  if (!file.size || file.size > 8 * 1024 * 1024) throw new FulfillmentError("สลิปคืนเงินต้องเป็นรูป JPEG, PNG หรือ WebP ไม่เกิน 8 MB");
  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  const jpeg = file.type === "image/jpeg" && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const png = file.type === "image/png" && [137, 80, 78, 71, 13, 10, 26, 10].every((v, i) => bytes[i] === v);
  const webp = file.type === "image/webp" && [82, 73, 70, 70].every((v, i) => bytes[i] === v) && [87, 69, 66, 80].every((v, i) => bytes[i + 8] === v);
  if (!jpeg && !png && !webp) throw new FulfillmentError("สลิปคืนเงินต้องเป็นรูป JPEG, PNG หรือ WebP ไม่เกิน 8 MB");
  // Reuse the private food-private bucket and metadata-scrubbing uploader.
  // Never use a public URL or a caller-supplied folder.
  return uploadFoodPrivateImage(client, file, `food-refund-slips/${storeId}/${orderId}`);
}

export async function transitionPickupOrder(client: SupabaseClient, orderId: string, status: "ready_for_pickup" | "picked_up") {
  await rpc(client, "food_transition_order", { p_order_id: orderId, p_status: status, p_eta_minutes: null, p_note: null });
}
