import { createClient } from "@/lib/supabase/server";

/**
 * WYNOS Maps places, suggestions and photo review for WYNOS Admin. Split out
 * of admin-food.ts when Food and Merchant moved to ZOKY Admin
 * (ZOKY-ADMIN-001); the RPCs are unchanged.
 */

export type AdminWynosPlace = {
  id: string;
  name_th: string;
  name_en: string | null;
  category: string;
  address: string | null;
  building: string | null;
  latitude: number;
  longitude: number;
  entrance_latitude: number | null;
  entrance_longitude: number | null;
  source: string;
  source_ref: string | null;
  verification_status: "unverified" | "merchant_verified" | "wynos_verified";
  merchant_store_id: string | null;
  food_store_place_id: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export async function fetchAdminWynosPlaces(params: {
  query?: string;
  category?: string;
  status?: string;
  limit?: number;
} = {}): Promise<AdminWynosPlace[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_wynos_places", {
    p_query: params.query?.trim() || null,
    p_category: params.category || null,
    p_status: params.status || null,
    p_limit: params.limit ?? 250,
  });
  if (error) throw error;
  return (data ?? []) as AdminWynosPlace[];
}

export type AdminWynosPlaceSuggestion = {
  id: string;
  user_id: string;
  name: string;
  category: string;
  address: string | null;
  note: string | null;
  latitude: number;
  longitude: number;
  status: "pending" | "approved" | "rejected";
  place_id: string | null;
  created_at: string;
};

export async function fetchAdminWynosPlaceSuggestions(
  status: "pending" | "approved" | "rejected" | "" = "pending",
): Promise<AdminWynosPlaceSuggestion[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_wynos_place_suggestions", {
    p_status: status || null,
    p_limit: 200,
  });
  if (error) throw error;
  return (data ?? []) as AdminWynosPlaceSuggestion[];
}

export type AdminWynosPlacePhoto = {
  id: string;
  place_id: string;
  place_name: string;
  user_id: string;
  storage_path: string;
  width: number | null;
  height: number | null;
  status: "pending" | "approved" | "rejected";
  created_at: string;
  url: string | null;
};

/** Pending WYNOS Maps place photos with short-lived signed URLs; empty until the migration is installed. */
export async function fetchAdminWynosPlacePhotos(): Promise<AdminWynosPlacePhoto[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_wynos_place_photos", { p_status: "pending", p_limit: 100 });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return [];
    throw error;
  }
  const rows = (data ?? []) as Omit<AdminWynosPlacePhoto, "url">[];
  if (!rows.length) return [];
  const { data: signed } = await supabase.storage
    .from("place-photos")
    .createSignedUrls(rows.map((row) => row.storage_path), 60 * 30);
  const urls = new Map((signed ?? []).flatMap((item) => (item.path && item.signedUrl ? [[item.path, item.signedUrl] as const] : [])));
  return rows.map((row) => ({ ...row, url: urls.get(row.storage_path) ?? null }));
}
