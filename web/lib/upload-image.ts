// Client half of WEB-B1-QA-03. Storage buckets enforce the same allow-list
// and size limit server-side (supabase/migrations_web_beta1_storage_upload_limits.sql);
// checking here too gives users a clear Thai message instead of a raw
// Storage error, and never trusts the file name for the stored extension.
const EXTENSION_BY_TYPE: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
  "image/heic": "heic",
  "image/heif": "heif",
  "image/avif": "avif",
};

// Some browsers (desktop Chrome/Windows) report "" for HEIC/HEIF files.
const TYPE_BY_EXTENSION: Record<string, string> = {
  jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp",
  gif: "image/gif", heic: "image/heic", heif: "image/heif", avif: "image/avif",
};

export const AVATAR_MAX_BYTES = 10 * 1024 * 1024;
export const IMAGE_MAX_BYTES = 20 * 1024 * 1024;

export type ImageUploadType = { contentType: string; extension: string };

export function imageUploadType(file: File, maxBytes = IMAGE_MAX_BYTES): ImageUploadType {
  const nameExtension = file.name.split(".").pop()?.toLowerCase() ?? "";
  const contentType = EXTENSION_BY_TYPE[file.type] ? file.type : !file.type ? TYPE_BY_EXTENSION[nameExtension] : undefined;
  if (!contentType) throw new Error("รองรับเฉพาะไฟล์รูปภาพ JPG, PNG, WebP, GIF หรือ HEIC");
  if (file.size > maxBytes) {
    throw new Error(`ไฟล์รูปใหญ่เกินไป (สูงสุด ${Math.round(maxBytes / 1024 / 1024)} MB)`);
  }
  return { contentType, extension: EXTENSION_BY_TYPE[contentType] };
}
