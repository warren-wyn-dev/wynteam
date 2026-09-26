import type { SupabaseClient } from "@supabase/supabase-js";

import { imageUploadType } from "@/lib/upload-image";

export type DraftRow = {
  id: string;
  image_url: string | null;
  caption: string | null;
  poll_options: string[] | null;
  poll_duration_days: number | null;
  updated_at: string;
};

export async function fetchDrafts(client: SupabaseClient, userId: string): Promise<DraftRow[]> {
  const result = await client
    .from("drop_drafts")
    .select("id,image_url,caption,poll_options,poll_duration_days,updated_at")
    .eq("author_id", userId)
    .order("updated_at", { ascending: false });
  if (result.error) throw result.error;
  return (result.data ?? []) as DraftRow[];
}

export async function fetchDraft(client: SupabaseClient, draftId: string): Promise<DraftRow | null> {
  const result = await client
    .from("drop_drafts")
    .select("id,image_url,caption,poll_options,poll_duration_days,updated_at")
    .eq("id", draftId)
    .maybeSingle();
  if (result.error) throw result.error;
  return (result.data ?? null) as DraftRow | null;
}

/** Mirrors Flutter's `DropRepository.saveDraft()` (WYN-036): insert when
 * `draftId` is absent, update in place otherwise. `drop_drafts.image_url`
 * is a single column (not an array like a published Drop's images), so
 * only the first picked file is ever carried into a draft — the same
 * limitation the Flutter draft already has. */
export async function saveDraft(
  client: SupabaseClient,
  userId: string,
  input: {
    draftId?: string | null;
    file?: File | null;
    existingImageUrl?: string | null;
    caption: string;
    pollOptions?: string[] | null;
    pollDurationDays?: number | null;
  },
): Promise<string> {
  const id = input.draftId ?? crypto.randomUUID();
  let imageUrl = input.existingImageUrl ?? null;
  if (input.file) {
    const { contentType, extension } = imageUploadType(input.file);
    const path = `${userId}/drafts/${id}.${extension}`;
    const uploaded = await client.storage.from("drop-images").upload(path, input.file, {
      cacheControl: "60",
      contentType,
      upsert: true,
    });
    if (uploaded.error) throw uploaded.error;
    const url = new URL(client.storage.from("drop-images").getPublicUrl(path).data.publicUrl);
    url.searchParams.set("v", crypto.randomUUID());
    imageUrl = url.toString();
  }

  const row = {
    author_id: userId,
    image_url: imageUrl,
    caption: input.caption.trim() || null,
    poll_options: input.pollOptions && input.pollOptions.length ? input.pollOptions : null,
    poll_duration_days: input.pollDurationDays ?? null,
    updated_at: new Date().toISOString(),
  };

  if (input.draftId) {
    const result = await client.from("drop_drafts").update(row).eq("id", id).select("id").single();
    if (result.error) throw result.error;
    return String(result.data.id);
  }
  const result = await client.from("drop_drafts").insert({ id, ...row }).select("id").single();
  if (result.error) throw result.error;
  return String(result.data.id);
}

/** Restore a saved draft image for publishing without fetching arbitrary URLs. */
export async function loadDraftImageFile(
  client: SupabaseClient,
  userId: string,
  imageUrl: string,
): Promise<File> {
  const bucket = client.storage.from("drop-images");
  const folder = `${userId}/drafts/`;
  const base = new URL(bucket.getPublicUrl(folder).data.publicUrl);
  const candidate = new URL(imageUrl);
  if (candidate.origin !== base.origin || !candidate.pathname.startsWith(base.pathname)) {
    throw new Error("รูปภาพฉบับร่างไม่อยู่ในพื้นที่จัดเก็บของบัญชีนี้");
  }
  const name = decodeURIComponent(candidate.pathname.slice(base.pathname.length));
  if (!/^[A-Za-z0-9_-]+\.(?:jpe?g|png|webp|gif|heic|heif)$/i.test(name)) {
    throw new Error("พาธรูปภาพฉบับร่างไม่ถูกต้อง");
  }
  const downloaded = await bucket.download(`${folder}${name}`);
  if (downloaded.error || !downloaded.data) {
    throw downloaded.error ?? new Error("โหลดรูปภาพจากฉบับร่างไม่สำเร็จ");
  }
  const ext = name.split(".").pop()?.toLowerCase() ?? "jpg";
  const contentType = downloaded.data.type && downloaded.data.type !== "application/octet-stream"
    ? downloaded.data.type
    : ext === "png" ? "image/png" : ext === "webp" ? "image/webp" : ext === "heic" ? "image/heic" : "image/jpeg";
  return new File([downloaded.data], name, { type: contentType });
}

export async function deleteDraft(client: SupabaseClient, draftId: string): Promise<void> {
  const result = await client.from("drop_drafts").delete().eq("id", draftId);
  if (result.error) throw result.error;
}
