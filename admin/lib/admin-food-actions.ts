"use client";

import { createClient } from "@/lib/supabase/client";

/** WYN-203: admin-only changes; the RPCs re-check the role and write the audit log. */
export async function setFoodStoreSuspension(params: {
  storeId: string;
  suspend: boolean;
  reason?: string;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_food_store_suspension", {
    p_store_id: params.storeId,
    p_suspend: params.suspend,
    p_reason: params.reason?.trim() || null,
  });
  if (error) throw error;
}

export async function setFoodStoreMemberActive(params: {
  storeId: string;
  userId: string;
  active: boolean;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_food_store_member_active", {
    p_store_id: params.storeId,
    p_user_id: params.userId,
    p_active: params.active,
  });
  if (error) throw error;
}

export function adminFoodError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("suspension reason is required")) return "กรุณาใส่เหตุผลการระงับ";
  if (message.includes("cannot deactivate the only owner")) return "ปิดสิทธิ์เจ้าของคนเดียวของร้านไม่ได้";
  if (message.includes("Only admins")) return "เฉพาะ Admin เท่านั้นที่ทำรายการนี้ได้";
  return message || fallback;
}

/** WYN-206: create or edit a WYNOS campaign (admin only; the RPC re-checks). */
export type PlatformCampaignInput = {
  id: string | null;
  name: string;
  description: string;
  campaignType: "percentage" | "fixed" | "free_delivery";
  discountValue: number;
  minSubtotal: number;
  maxDiscount: number | null;
  startsAt: string;
  endsAt: string | null;
  usageLimitPerStore: number | null;
  platformSharePercent: number;
  joinOpen: boolean;
  isActive: boolean;
};

export async function savePlatformCampaign(input: PlatformCampaignInput): Promise<string> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_upsert_platform_campaign", {
    p_campaign_id: input.id,
    p_name: input.name,
    p_description: input.description,
    p_campaign_type: input.campaignType,
    p_discount_value: input.discountValue,
    p_min_subtotal: input.minSubtotal,
    p_max_discount: input.maxDiscount,
    p_starts_at: input.startsAt,
    p_ends_at: input.endsAt,
    p_usage_limit_per_store: input.usageLimitPerStore,
    p_platform_share_percent: input.platformSharePercent,
    p_join_open: input.joinOpen,
    p_is_active: input.isActive,
  });
  if (error) throw error;
  return data as string;
}

/** Merchant-funded preset: Admin activates it, each store opts in separately. */
export async function setFirstOrderFoodCampaignActive(active: boolean): Promise<string> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_food_first_order_set_active", { p_active: active });
  if (error) throw error;
  return data as string;
}

/** WYN-206: record that WYNOS transferred what it owes a store. */
export async function settlePlatformStore(params: {
  storeId: string;
  reference: string;
  note?: string;
  /** WYN-213: what the admin saw and transferred; the server refuses if it changed. */
  expectedAmount: number;
  expectedCount: number;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_settle_platform_store", {
    p_store_id: params.storeId,
    p_reference: params.reference.trim(),
    p_expected_amount: params.expectedAmount,
    p_expected_count: params.expectedCount,
    p_note: params.note?.trim() || null,
  });
  if (error) throw error;
}

export function platformCampaignError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? error ?? "");
  if (message.includes("food_platform_campaigns_name_length")) return "ชื่อแคมเปญต้องยาว 2–80 ตัวอักษร";
  if (message.includes("food_platform_campaigns_discount_check")) return "ส่วนลดไม่ถูกต้อง (เปอร์เซ็นต์ 1–100 หรือจำนวนเงินมากกว่า 0)";
  if (message.includes("food_platform_campaigns_dates_check")) return "วันจบต้องอยู่หลังวันเริ่ม";
  if (message.includes("food_platform_campaigns_share_check")) return "สัดส่วนที่ WYNOS ออกต้องอยู่ระหว่าง 0–100%";
  if (message.includes("transfer reference is required")) return "กรุณาใส่เลขอ้างอิงการโอน";
  if (message.includes("nothing to settle")) return "ไม่มียอดค้างโอนแล้ว";
  if (message.includes("owed amount changed")) return "ยอดค้างเปลี่ยนระหว่างเปิดหน้านี้ กรุณารีเฟรชแล้วตรวจยอดก่อนโอนใหม่";
  if (message.includes("Only admins")) return "เฉพาะ Admin เท่านั้นที่ทำรายการนี้ได้";
  return message || fallback;
}

/** WYN-207: ad settings, top-up review and stopping a store's ads (admin only). */
export async function saveAdSettings(params: { costPerClick: number; minTopup: number; promptpayName: string; promptpayId: string; enabled: boolean }) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_update_ad_settings", {
    p_cost_per_click: params.costPerClick,
    p_min_topup: params.minTopup,
    p_wynos_promptpay_name: params.promptpayName,
    p_wynos_promptpay_id: params.promptpayId,
    p_ads_enabled: params.enabled,
  });
  if (error) throw error;
}

export async function reviewAdTopup(params: { topupId: string; approve: boolean; note?: string }) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_review_ad_topup", { p_topup_id: params.topupId, p_approve: params.approve, p_note: params.note?.trim() || null });
  if (error) throw error;
}

export async function setAdAccountStatus(params: { storeId: string; stop: boolean; reason?: string }) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_ad_account_status", { p_store_id: params.storeId, p_stop: params.stop, p_reason: params.reason?.trim() || null });
  if (error) throw error;
}

export function adminAdError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? error ?? "");
  if (message.includes("set the WYNOS PromptPay before turning ads on")) return "ใส่ PromptPay ของ WYNOS ก่อนเปิดระบบโฆษณา";
  if (message.includes("food_ad_settings_promptpay_check")) return "เลข PromptPay ต้องเป็นตัวเลข 10–20 หลัก";
  if (message.includes("food_ad_settings_cpc_check")) return "ราคาต่อคลิกต้องมากกว่า 0 และไม่เกิน 1,000 บาท";
  if (message.includes("food_ad_settings_min_topup_check")) return "ยอดเติมขั้นต่ำต้องมากกว่า 0";
  if (message.includes("a reason is required")) return "กรุณาใส่เหตุผล";
  if (message.includes("top-up already reviewed")) return "รายการนี้ตรวจไปแล้ว";
  if (message.includes("Only admins")) return "เฉพาะ Admin เท่านั้นที่ทำรายการนี้ได้";
  return message || fallback;
}


export type WynosPlaceInput = {
  id?: string | null;
  nameTh: string;
  nameEn?: string;
  category: string;
  address?: string;
  building?: string;
  latitude: number;
  longitude: number;
  entranceLatitude?: number | null;
  entranceLongitude?: number | null;
  source: "wynos" | "osm" | "overture" | "user_report";
  sourceRef?: string;
  verificationStatus: "unverified" | "merchant_verified" | "wynos_verified";
  isActive: boolean;
};

export async function saveWynosPlace(input: WynosPlaceInput): Promise<string> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_upsert_wynos_place", {
    p_place_id: input.id ?? null,
    p_name_th: input.nameTh.trim(),
    p_name_en: input.nameEn?.trim() || null,
    p_category: input.category,
    p_address: input.address?.trim() || null,
    p_building: input.building?.trim() || null,
    p_latitude: input.latitude,
    p_longitude: input.longitude,
    p_entrance_latitude: input.entranceLatitude ?? null,
    p_entrance_longitude: input.entranceLongitude ?? null,
    p_source: input.source,
    p_source_ref: input.sourceRef?.trim() || null,
    p_verification_status: input.verificationStatus,
    p_is_active: input.isActive,
  });
  if (error) throw error;
  return String(data);
}

export async function setWynosPlaceActive(placeId: string, active: boolean) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_wynos_place_active", {
    p_place_id: placeId,
    p_active: active,
  });
  if (error) throw error;
}

export async function importWynosPlaces(payload: unknown) {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_import_wynos_places", { p_places: payload });
  if (error) throw error;
  return data as { rows: number; inserted: number; updated: number };
}

export function adminWynosPlaceError(error: unknown, fallback = "ดำเนินการ WYNOS Places ไม่สำเร็จ") {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? error ?? "");
  if (message.includes("Only admins")) return "เฉพาะ Admin เท่านั้นที่จัดการ WYNOS Places ได้";
  if (message.includes("place name is required")) return "กรุณาใส่ชื่อสถานที่";
  if (message.includes("invalid place location")) return "พิกัดสถานที่ไม่ถูกต้อง";
  if (message.includes("invalid entrance location")) return "พิกัดทางเข้าไม่ถูกต้อง";
  if (message.includes("maximum 500 places")) return "นำเข้าได้ครั้งละไม่เกิน 500 สถานที่";
  if (message.includes("places payload must be an array")) return "ไฟล์นำเข้าต้องเป็น JSON array";
  return message || fallback;
}


export async function reviewWynosPlaceSuggestion(suggestionId: string, approve: boolean) {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_review_wynos_place_suggestion", {
    p_suggestion_id: suggestionId,
    p_decision: approve ? "approve" : "reject",
  });
  if (error) throw error;
  return data as string | null;
}

/** Approve or reject a user place photo; a rejected photo's file is deleted right away. */
export async function reviewWynosPlacePhoto(photoId: string, storagePath: string, approve: boolean) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_review_wynos_place_photo", {
    p_photo_id: photoId,
    p_decision: approve ? "approve" : "reject",
  });
  if (error) throw error;
  if (!approve) {
    const { error: removeError } = await supabase.storage.from("place-photos").remove([storagePath]);
    if (removeError) throw removeError;
  }
}
