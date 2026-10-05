import type { SupabaseClient } from "@supabase/supabase-js";

// WYNOS Maps saved places (Home, Work, Favorites). Owner-only on the server:
// supabase/migrations_wynos_maps_saved_places_v1.sql.

export type SavedPlaceKind = "home" | "work" | "favorite";

export type SavedPlace = {
  id: string;
  kind: SavedPlaceKind;
  label: string;
  placeId: string | null;
  name: string;
  address: string | null;
  latitude: number;
  longitude: number;
};

export type SavedPlacesState =
  | { status: "ready"; places: SavedPlace[] }
  | { status: "signed-out" }
  // The migration is not installed yet; the UI hides saved places entirely.
  | { status: "unavailable" };

type RpcError = { code?: string; message?: string } | null;

function missingRpc(error: RpcError) {
  return error?.code === "PGRST202" || error?.code === "42883";
}

function signedOut(error: RpcError) {
  return Boolean(error?.message?.includes("authentication required"));
}

function parseSavedPlace(row: unknown): SavedPlace | null {
  if (!row || typeof row !== "object") return null;
  const value = row as Record<string, unknown>;
  const kind = value.kind === "home" || value.kind === "work" || value.kind === "favorite" ? value.kind : null;
  const latitude = Number(value.latitude);
  const longitude = Number(value.longitude);
  if (!kind || typeof value.id !== "string" || typeof value.name !== "string") return null;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  return {
    id: value.id,
    kind,
    label: typeof value.label === "string" ? value.label : value.name,
    placeId: typeof value.place_id === "string" ? value.place_id : null,
    name: value.name,
    address: typeof value.address === "string" ? value.address : null,
    latitude,
    longitude,
  };
}

export async function loadSavedPlaces(client: SupabaseClient): Promise<SavedPlacesState> {
  const { data: session } = await client.auth.getSession();
  if (!session.session) return { status: "signed-out" };
  const { data, error } = await client.rpc("wynos_saved_places_list");
  if (missingRpc(error)) return { status: "unavailable" };
  if (signedOut(error)) return { status: "signed-out" };
  if (error) throw new Error("โหลดสถานที่ที่บันทึกไว้ไม่สำเร็จ");
  const places = (Array.isArray(data) ? data : []).flatMap((row) => {
    const place = parseSavedPlace(row);
    return place ? [place] : [];
  });
  return { status: "ready", places };
}

export async function saveMapPlace(
  client: SupabaseClient,
  input: {
    kind: SavedPlaceKind;
    name: string;
    address?: string | null;
    placeId?: string | null;
    latitude: number;
    longitude: number;
  },
) {
  const { error } = await client.rpc("wynos_save_place", {
    p_kind: input.kind,
    p_label: "",
    p_place_id: input.placeId ?? null,
    p_name: input.name.slice(0, 160),
    p_address: input.address?.slice(0, 300) ?? null,
    p_latitude: input.latitude,
    p_longitude: input.longitude,
  });
  if (!error) return;
  if (signedOut(error)) throw new Error("เข้าสู่ระบบ WYNOS ก่อน จึงจะบันทึกสถานที่ได้");
  if (error.message?.includes("saved place limit reached")) throw new Error("บันทึกรายการโปรดได้สูงสุด 50 แห่ง");
  throw new Error("บันทึกสถานที่ไม่สำเร็จ");
}

export async function deleteSavedPlace(client: SupabaseClient, id: string) {
  const { error } = await client.rpc("wynos_delete_saved_place", { p_id: id });
  if (error) throw new Error("ลบสถานที่ไม่สำเร็จ");
}
