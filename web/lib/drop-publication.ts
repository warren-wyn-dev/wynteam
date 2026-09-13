import type { SupabaseClient } from "@supabase/supabase-js";

export class DropPublicationStateUnknownError extends Error {
  constructor(public readonly operationId: string) {
    super("สถานะการเผยแพร่ยังไม่แน่นอน กรุณาลองอีกครั้งโดยไม่เปลี่ยนโพสต์");
    this.name = "DropPublicationStateUnknownError";
  }
}

type ImageMetadata = {
  image_url: string;
  position: number;
  image_width: number;
  image_height: number;
};

type PublishInput = {
  caption: string;
  files: File[];
  operationId?: string | null;
};

export type PublishDropResult = {
  dropId: string;
  operationId: string;
};

function extensionFor(file: File): string {
  const fromName = file.name.split(".").pop()?.toLowerCase().replace(/[^a-z0-9]/g, "") ?? "";
  if (fromName) return fromName;
  if (file.type === "image/png") return "png";
  if (file.type === "image/webp") return "webp";
  if (file.type === "image/heic" || file.type === "image/heif") return "heic";
  return "jpg";
}

function isConflict(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const candidate = error as { statusCode?: string | number; status?: string | number; message?: string };
  return String(candidate.statusCode ?? candidate.status ?? "") === "409" ||
    (candidate.message ?? "").toLowerCase().includes("already exists");
}

async function imageDimensions(file: File): Promise<{ width: number; height: number }> {
  const url = URL.createObjectURL(file);
  try {
    const image = new Image();
    const loaded = new Promise<void>((resolve, reject) => {
      image.onload = () => resolve();
      image.onerror = () => reject(new Error("อ่านขนาดรูปไม่สำเร็จ"));
    });
    image.src = url;
    await loaded;
    return { width: image.naturalWidth || 1, height: image.naturalHeight || 1 };
  } finally {
    URL.revokeObjectURL(url);
  }
}

async function removeBestEffort(client: SupabaseClient, paths: string[]): Promise<void> {
  if (!paths.length) return;
  try {
    await client.storage.from("drop-images").remove(paths);
  } catch {
    // Cleanup must never hide the original publication failure.
  }
}

async function reconcilePublication(
  client: SupabaseClient,
  operationId: string,
): Promise<{ resolved: boolean; dropId: string | null }> {
  try {
    const result = await client.rpc("drop_id_for_publication", {
      p_operation_id: operationId,
    });
    if (result.error) return { resolved: false, dropId: null };
    return {
      resolved: true,
      dropId: result.data == null ? null : String(result.data),
    };
  } catch {
    return { resolved: false, dropId: null };
  }
}

/**
 * Browser counterpart of Flutter DropRepository.createDrop/_publishDrop.
 *
 * The operation id and storage paths are deterministic. If a transport
 * response is lost after the database committed, retrying with the same
 * operation id returns the existing Drop instead of publishing a duplicate.
 * Existing 409 objects from an earlier ambiguous attempt are retained and
 * reused; only files uploaded by the current, definitely-failed attempt are
 * eligible for cleanup.
 */
export async function publishDropSafely(
  client: SupabaseClient,
  userId: string,
  input: PublishInput,
): Promise<PublishDropResult> {
  const caption = input.caption.trim();
  const files = input.files.slice(0, 9);
  if (!caption && !files.length) throw new Error("Drop ต้องมีข้อความหรือรูปภาพ");
  if (caption.length > 500) throw new Error("ข้อความยาวเกิน 500 ตัวอักษร");

  const operationId = input.operationId || crypto.randomUUID();
  const newlyUploadedPaths: string[] = [];
  const metadata: ImageMetadata[] = [];

  try {
    for (let index = 0; index < files.length; index += 1) {
      const file = files[index];
      const path = `${userId}/publications/${operationId}/${index}.${extensionFor(file)}`;
      const dimensions = await imageDimensions(file);
      const uploaded = await client.storage.from("drop-images").upload(path, file, {
        cacheControl: "31536000",
        contentType: file.type || undefined,
        upsert: false,
      });

      if (uploaded.error && !isConflict(uploaded.error)) throw uploaded.error;
      if (!uploaded.error) newlyUploadedPaths.push(path);

      const { data } = client.storage.from("drop-images").getPublicUrl(path);
      metadata.push({
        image_url: data.publicUrl,
        position: index,
        image_width: dimensions.width,
        image_height: dimensions.height,
      });
    }
  } catch (error) {
    await removeBestEffort(client, newlyUploadedPaths);
    throw error instanceof Error ? error : new Error("อัปโหลดรูปไม่สำเร็จ");
  }

  const primary = metadata[0];
  try {
    const result = await client.rpc("publish_drop", {
      p_operation_id: operationId,
      p_image_url: primary?.image_url ?? null,
      p_caption: caption || null,
      p_audience: "everyone",
      p_excluded_friend_ids: [],
      p_images: metadata,
      p_mentioned_user_ids: [],
      p_location: null,
      p_location_lat: null,
      p_location_lon: null,
      p_location_place_id: null,
      p_image_width: primary?.image_width ?? null,
      p_image_height: primary?.image_height ?? null,
      p_image_aspect_ratio: null,
    });

    // A concrete PostgREST error means the transaction rejected the write.
    if (result.error) {
      await removeBestEffort(client, newlyUploadedPaths);
      throw new Error(result.error.message || "เผยแพร่ Drop ไม่สำเร็จ");
    }

    return { dropId: String(result.data), operationId };
  } catch (error) {
    // Do not assume a thrown transport error means the RPC failed: the server
    // may have committed before the response disappeared. Reconcile by the
    // same operation id before deciding whether current uploads can be removed.
    if (error instanceof Error && !error.message.includes("Failed to fetch") && !(error instanceof TypeError)) {
      throw error;
    }

    const reconciled = await reconcilePublication(client, operationId);
    if (reconciled.resolved && reconciled.dropId) {
      return { dropId: reconciled.dropId, operationId };
    }
    if (reconciled.resolved && !reconciled.dropId) {
      await removeBestEffort(client, newlyUploadedPaths);
      throw error instanceof Error ? error : new Error("เผยแพร่ Drop ไม่สำเร็จ");
    }

    // Reconciliation itself could not establish the state. Preserve all
    // deterministic uploads so a retry with this operation id can recover.
    throw new DropPublicationStateUnknownError(operationId);
  }
}
