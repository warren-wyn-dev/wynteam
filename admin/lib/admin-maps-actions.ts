"use client";

import { createClient } from "@/lib/supabase/client";

/** WYNOS Maps admin changes (split out of admin-food-actions.ts, ZOKY-ADMIN-001); the RPCs re-check access. */

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
