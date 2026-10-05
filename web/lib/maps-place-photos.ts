import type { SupabaseClient } from "@supabase/supabase-js";

import { compressPhoto } from "@/lib/compress-image";

// WYNOS Maps place photos: supabase/migrations_wynos_maps_place_photos_v1.sql.

export const PLACE_PHOTOS_BUCKET = "place-photos";

export type PlacePhoto = {
  id: string;
  url: string;
  width: number | null;
  height: number | null;
  status: "pending" | "approved";
  isMine: boolean;
};

export type PlacePhotosState =
  | { status: "ready"; photos: PlacePhoto[] }
  | { status: "unavailable" };

type RpcError = { code?: string; message?: string } | null;

const missingRpc = (error: RpcError) => error?.code === "PGRST202" || error?.code === "42883";

/** Only WYNOS Places (ids like wynos_place_<hex>) can carry photos. */
export function canHavePhotos(placeId: string | null | undefined): placeId is string {
  return typeof placeId === "string" && /^wynos_place_[0-9a-f]{32}$/.test(placeId);
}

export async function loadPlacePhotos(client: SupabaseClient, placeId: string): Promise<PlacePhotosState> {
  const { data: session } = await client.auth.getSession();
  if (!session.session) return { status: "unavailable" };
  const { data, error } = await client.rpc("wynos_place_photos", { p_place_id: placeId });
  if (missingRpc(error)) return { status: "unavailable" };
  if (error) throw new Error("โหลดรูปสถานที่ไม่สำเร็จ");
  const rows = (Array.isArray(data) ? data : []) as Array<Record<string, unknown>>;
  const paths = rows.map((row) => String(row.storage_path ?? "")).filter(Boolean);
  if (!paths.length) return { status: "ready", photos: [] };

  const { data: signed } = await client.storage.from(PLACE_PHOTOS_BUCKET).createSignedUrls(paths, 60 * 60);
  const urlByPath = new Map((signed ?? []).flatMap((item) => (item.path && item.signedUrl ? [[item.path, item.signedUrl] as const] : [])));
  const photos = rows.flatMap((row): PlacePhoto[] => {
    const url = urlByPath.get(String(row.storage_path));
    if (!url || typeof row.id !== "string") return [];
    return [{
      id: row.id,
      url,
      width: typeof row.width === "number" ? row.width : null,
      height: typeof row.height === "number" ? row.height : null,
      status: row.status === "approved" ? "approved" : "pending",
      isMine: row.is_mine === true,
    }];
  });
  return { status: "ready", photos };
}

export async function uploadPlacePhoto(client: SupabaseClient, placeId: string, file: File) {
  const { data: session } = await client.auth.getSession();
  const userId = session.session?.user.id;
  if (!userId) throw new Error("เข้าสู่ระบบ WYNOS ก่อน จึงจะเพิ่มรูปได้");

  const photo = await compressPhoto(file);
  const path = `${userId}/${crypto.randomUUID()}.jpg`;
  const bucket = client.storage.from(PLACE_PHOTOS_BUCKET);
  const { error: uploadError } = await bucket.upload(path, photo.blob, { contentType: "image/jpeg", upsert: false });
  if (uploadError) throw new Error("อัปโหลดรูปไม่สำเร็จ ลองใหม่อีกครั้ง");

  const { error } = await client.rpc("submit_wynos_place_photo", {
    p_place_id: placeId,
    p_storage_path: path,
    p_width: photo.width,
    p_height: photo.height,
  });
  if (!error) return;
  // Don't leave an orphaned upload behind when the server refuses it.
  await bucket.remove([path]).catch(() => undefined);
  if (error.message?.includes("place photo limit reached")) throw new Error("เพิ่มรูปให้สถานที่นี้ได้สูงสุด 5 รูป");
  if (error.message?.includes("daily photo limit reached")) throw new Error("วันนี้เพิ่มรูปครบ 20 รูปแล้ว ลองใหม่พรุ่งนี้");
  throw new Error("ส่งรูปไม่สำเร็จ");
}

export async function withdrawPlacePhoto(client: SupabaseClient, photoId: string) {
  const { data, error } = await client.rpc("delete_my_wynos_place_photo", { p_photo_id: photoId });
  if (error) throw new Error("ลบรูปไม่สำเร็จ");
  if (typeof data === "string" && data) {
    await client.storage.from(PLACE_PHOTOS_BUCKET).remove([data]).catch(() => undefined);
  }
}
