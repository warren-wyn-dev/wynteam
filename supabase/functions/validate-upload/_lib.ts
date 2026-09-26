// WEB-B1-QA-04: server-side content validation for image uploads.
//
// Bucket allow-lists (migrations_web_beta1_storage_upload_limits.sql) only
// check the MIME type the client *claims*. A direct Storage API call can
// label any bytes `image/jpeg`, or use the `application/octet-stream`
// fallback the Flutter app needs. This function runs from a Database
// Webhook on storage.objects: it reads the first bytes of every new or
// replaced object in the image buckets and deletes the object when those
// bytes are not a raster image. Real images are never touched; on any
// read error it leaves the object alone (fail-open, logged).

export const IMAGE_BUCKETS = new Set([
  "avatars",
  "drop-images",
  "chat-media",
  "club-media",
]);

/** Bytes needed to recognise every supported format (ISO-BMFF brands included). */
export const SNIFF_BYTES = 64;

const ISO_BMFF_IMAGE_BRANDS = new Set([
  "heic", "heix", "hevc", "hevx", "heim", "heis", "hevm", "hevs",
  "mif1", "msf1", "avif", "avis",
]);

function ascii(bytes: Uint8Array, start: number, end: number): string {
  return String.fromCharCode(...bytes.subarray(start, end));
}

export type ImageKind = "jpeg" | "png" | "gif" | "webp" | "heif";

/** Identify a raster image from its leading bytes, or null if it is not one. */
export function sniffImage(bytes: Uint8Array): ImageKind | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "jpeg";
  }
  if (
    bytes.length >= 8 &&
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((b, i) => bytes[i] === b)
  ) {
    return "png";
  }
  if (bytes.length >= 6 && (ascii(bytes, 0, 6) === "GIF87a" || ascii(bytes, 0, 6) === "GIF89a")) {
    return "gif";
  }
  if (bytes.length >= 12 && ascii(bytes, 0, 4) === "RIFF" && ascii(bytes, 8, 12) === "WEBP") {
    return "webp";
  }
  // HEIC/HEIF/AVIF: an ISO-BMFF `ftyp` box whose major or a compatible brand
  // is an image brand. Box layout: size(4) 'ftyp'(4) major(4) minor(4) brands(4n).
  if (bytes.length >= 12 && ascii(bytes, 4, 8) === "ftyp") {
    const size = ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) >>> 0;
    const end = Math.min(bytes.length, size >= 16 ? size : 16);
    if (ISO_BMFF_IMAGE_BRANDS.has(ascii(bytes, 8, 12))) return "heif";
    for (let offset = 16; offset + 4 <= end; offset += 4) {
      if (ISO_BMFF_IMAGE_BRANDS.has(ascii(bytes, offset, offset + 4))) return "heif";
    }
  }
  return null;
}

export type StorageObjectRecord = { id?: unknown; bucket_id?: unknown; name?: unknown };
export type WebhookPayload = {
  type?: unknown;
  schema?: unknown;
  table?: unknown;
  record?: StorageObjectRecord | null;
};

export type Target = { bucket: string; name: string; id: string | null };

/** Only objects in the image buckets, with a sane path, are ever inspected. */
export function targetFromPayload(payload: WebhookPayload): Target | null {
  if (payload?.schema !== "storage" || payload?.table !== "objects") return null;
  if (payload.type !== "INSERT" && payload.type !== "UPDATE") return null;
  const record = payload.record;
  const bucket = record?.bucket_id;
  const name = record?.name;
  if (typeof bucket !== "string" || !IMAGE_BUCKETS.has(bucket)) return null;
  if (typeof name !== "string" || name.length === 0 || name.length > 1024) return null;
  if (name.startsWith("/") || name.split("/").some((part) => part === "..")) return null;
  // Created by the Dashboard's "New folder"; not user content.
  if (name === ".emptyFolderPlaceholder" || name.endsWith("/.emptyFolderPlaceholder")) return null;
  return { bucket, name, id: typeof record?.id === "string" ? record.id : null };
}

export function objectUrl(supabaseUrl: string, bucket: string, name: string): string {
  const path = name.split("/").map(encodeURIComponent).join("/");
  return `${supabaseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/${path}`;
}

export type ReadResult =
  | { status: "ok"; bytes: Uint8Array }
  | { status: "missing" }
  | { status: "error"; httpStatus?: number };

export type Deps = {
  readHead: (target: Target) => Promise<ReadResult>;
  remove: (target: Target) => Promise<boolean>;
  sleep: (ms: number) => Promise<void>;
  log: (entry: Record<string, unknown>) => void;
};

export type Outcome =
  | "ignored"
  | "image"
  | "removed"
  | "remove_failed"
  | "missing"
  | "read_error";

/**
 * Inspect one webhook event. The object row can land a moment before its
 * bytes are readable, so a missing object is retried briefly before giving up.
 */
export async function validateUpload(payload: WebhookPayload, deps: Deps): Promise<Outcome> {
  const target = targetFromPayload(payload);
  if (!target) return "ignored";

  let read: ReadResult = { status: "missing" };
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) await deps.sleep(1000 * attempt);
    read = await deps.readHead(target);
    if (read.status !== "missing") break;
  }

  if (read.status === "missing") return "missing";
  if (read.status === "error") {
    deps.log({ outcome: "read_error", bucket: target.bucket, object_id: target.id, http_status: read.httpStatus ?? null });
    return "read_error";
  }
  if (sniffImage(read.bytes)) return "image";

  const removed = await deps.remove(target);
  deps.log({ outcome: removed ? "removed" : "remove_failed", bucket: target.bucket, object_id: target.id, reason: "not_an_image" });
  return removed ? "removed" : "remove_failed";
}
