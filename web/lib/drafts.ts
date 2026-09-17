import type { SupabaseClient } from "@supabase/supabase-js";

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
  let imageUrl = input.existingImageUrl ?? null;
  if (input.file) {
    const ext = input.file.name.split(".").pop()?.toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
    const path = `${userId}/drafts/${input.draftId ?? crypto.randomUUID()}.${ext}`;
    const uploaded = await client.storage.from("drop-images").upload(path, input.file, {
      cacheControl: "31536000",
      contentType: input.file.type || undefined,
      upsert: true,
    });
    if (uploaded.error) throw uploaded.error;
    imageUrl = client.storage.from("drop-images").getPublicUrl(path).data.publicUrl;
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
    const result = await client.from("drop_drafts").update(row).eq("id", input.draftId).select("id").single();
    if (result.error) throw result.error;
    return String(result.data.id);
  }
  const result = await client.from("drop_drafts").insert(row).select("id").single();
  if (result.error) throw result.error;
  return String(result.data.id);
}

export async function deleteDraft(client: SupabaseClient, draftId: string): Promise<void> {
  const result = await client.from("drop_drafts").delete().eq("id", draftId);
  if (result.error) throw result.error;
}
