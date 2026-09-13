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

const supportedImageExtensions = new Set([
  "jpg",
  "jpeg",
  "png",
  "webp",
  "heic",
  "heif",
  "gif",
  "avif",
]);

function extensionFor(file: File): string {
  const fromName = file.name.split(".").pop()?.toLowerCase().replace(/[^a-z0-9]/g, "") ?? "";
  if (fromName) return fromName;
  if (file.type === "image/png") return "png";
  if (file.type === "image/webp") return "webp";
  if (file.type === "image/heic" || file.type === "image/heif") return "heic";
  if (file.type === "image/avif") return "avif";
  if (file.type === "image/gif") return "gif";
  return "jpg";
}

function validateImageFile(file: File): void {
  const extension = extensionFor(file);
  if (!supportedImageExtensions.has(extension)) {
    throw new Error(`ไม่รองรับไฟล์รูป .${extension || "unknown"}`);
  }
  if (file.type && !file.type.startsWith("image/")) {
    throw new Error("ไฟล์ที่เลือกไม่ใช่รูปภาพ");
  }
  if (file.type === "image/svg+xml") {
    throw new Error("ยังไม่รองรับไฟล์ SVG");
  }
}

function errorFields(error: unknown): {
  code: string;
  status: string;
  message: string;
} {
  if (!error || typeof error !== "object") {
    return {
      code: "",
      status: "",
      message: error instanceof Error ? error.message : String(error ?? ""),
    };
  }
  const candidate = error as {
    code?: string | number;
    statusCode?: string | number;
    status?: string | number;
    message?: string;
  };
  return {
    code: String(candidate.code ?? ""),
    status: String(candidate.statusCode ?? candidate.status ?? ""),
    message: candidate.message ?? "",
  };
}

function isConflict(error: unknown): boolean {
  const fields = errorFields(error);
  return fields.status === "409" || fields.message.toLowerCase().includes("already exists");
}

function isTransportLikeError(error: unknown): boolean {
  if (error instanceof TypeError) return true;
  const fields = errorFields(error);
  const message = fields.message.toLowerCase();
  const looksLikeNetwork =
    message.includes("failed to fetch") ||
    message.includes("fetcherror") ||
    message.includes("networkerror") ||
    message.includes("network error") ||
    message.includes("load failed") ||
    message.includes("connection reset") ||
    message.includes("connection closed");
  return looksLikeNetwork && !fields.code && !fields.status;
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

async function resolveAmbiguousPublication(
  client: SupabaseClient,
  operationId: string,
  newlyUploadedPaths: string[],
  originalError: unknown,
): Promise<PublishDropResult> {
  const reconciled = await reconcilePublication(client, operationId);
  if (reconciled.resolved && reconciled.dropId) {
    return { dropId: reconciled.dropId, operationId };
  }
  if (reconciled.resolved && !reconciled.dropId) {
    await removeBestEffort(client, newlyUploadedPaths);
    throw originalError instanceof Error
      ? originalError
      : new Error("เผยแพร่ Drop ไม่สำเร็จ");
  }

  // Reconciliation itself could not establish the state. Preserve all
  // deterministic uploads so a retry with this operation id can recover.
  throw new DropPublicationStateUnknownError(operationId);
}

/**
 * Browser counterpart of Flutter DropRepository.createDrop/_publishDrop.
 *
 * The operation id and storage paths are deterministic. If a storage/RPC
 * response disappears, retrying with the same operation id reuses uploaded
 * objects and returns the existing Drop instead of knowingly publishing a
 * duplicate. Definite backend errors may clean up only files uploaded by the
 * current attempt; ambiguous transport failures retain assets for recovery.
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
  files.forEach(validateImageFile);

  const operationId = input.operationId || crypto.randomUUID();
  const newlyUploadedPaths: string[] = [];
  const metadata: ImageMetadata[] = [];

  for (let index = 0; index < files.length; index += 1) {
    const file = files[index];
    const path = `${userId}/publications/${operationId}/${index}.${extensionFor(file)}`;
    let dimensions: { width: number; height: number };
    try {
      dimensions = await imageDimensions(file);
    } catch (error) {
      await removeBestEffort(client, newlyUploadedPaths);
      throw error;
    }

    let uploaded: Awaited<ReturnType<ReturnType<typeof client.storage.from>["upload"]>>;
    try {
      uploaded = await client.storage.from("drop-images").upload(path, file, {
        cacheControl: "31536000",
        contentType: file.type || undefined,
        upsert: false,
      });
    } catch (error) {
      if (isTransportLikeError(error)) {
        throw new DropPublicationStateUnknownError(operationId);
      }
      await removeBestEffort(client, newlyUploadedPaths);
      throw error instanceof Error ? error : new Error("อัปโหลดรูปไม่สำเร็จ");
    }

    if (uploaded.error && !isConflict(uploaded.error)) {
      if (isTransportLikeError(uploaded.error)) {
        throw new DropPublicationStateUnknownError(operationId);
      }
      await removeBestEffort(client, newlyUploadedPaths);
      throw new Error(uploaded.error.message || "อัปโหลดรูปไม่สำเร็จ");
    }
    if (!uploaded.error) newlyUploadedPaths.push(path);

    const { data } = client.storage.from("drop-images").getPublicUrl(path);
    metadata.push({
      image_url: data.publicUrl,
      position: index,
      image_width: dimensions.width,
      image_height: dimensions.height,
    });
  }

  const primary = metadata[0];
  let result: Awaited<ReturnType<typeof client.rpc>>;
  try {
    result = await client.rpc("publish_drop", {
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
  } catch (error) {
    if (!isTransportLikeError(error)) throw error;
    return resolveAmbiguousPublication(client, operationId, newlyUploadedPaths, error);
  }

  if (result.error) {
    if (isTransportLikeError(result.error)) {
      return resolveAmbiguousPublication(client, operationId, newlyUploadedPaths, result.error);
    }
    await removeBestEffort(client, newlyUploadedPaths);
    throw new Error(result.error.message || "เผยแพร่ Drop ไม่สำเร็จ");
  }

  return { dropId: String(result.data), operationId };
}
