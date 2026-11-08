// Shrinks a photo in the browser before upload: longest side at most
// PHOTO_MAX_SIDE, re-encoded as JPEG. Re-encoding through a canvas writes a
// fresh file, so EXIF (including GPS position) never leaves the device.

import { IMAGE_MAX_BYTES, imageUploadType } from "@/lib/upload-image";

export const PHOTO_MAX_SIDE = 1600;
export const PHOTO_TARGET_BYTES = 900 * 1024;
const QUALITY_STEPS = [0.82, 0.72, 0.62];

export type CompressedPhoto = { blob: Blob; width: number; height: number };

/** Scales (width, height) down so the longest side fits maxSide; never upscales. */
export function fitWithin(width: number, height: number, maxSide = PHOTO_MAX_SIDE) {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
    throw new Error("อ่านขนาดรูปไม่สำเร็จ");
  }
  const scale = Math.min(1, maxSide / Math.max(width, height));
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) };
}

export async function decode(file: File): Promise<ImageBitmap | HTMLImageElement> {
  if (typeof createImageBitmap === "function") {
    try {
      return await createImageBitmap(file, { imageOrientation: "from-image" });
    } catch {
      // Fall back to <img> (Safari decodes HEIC this way).
    }
  }
  const url = URL.createObjectURL(file);
  try {
    const image = new Image();
    image.decoding = "async";
    image.src = url;
    await image.decode();
    return image;
  } catch {
    throw new Error("เปิดรูปนี้ไม่ได้ ลองเลือกรูปอื่น");
  } finally {
    URL.revokeObjectURL(url);
  }
}

function toJpeg(canvas: HTMLCanvasElement, quality: number) {
  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("บีบรูปไม่สำเร็จ"))), "image/jpeg", quality);
  });
}

export async function compressPhoto(file: File): Promise<CompressedPhoto> {
  imageUploadType(file, IMAGE_MAX_BYTES);
  const source = await decode(file);
  const sourceWidth = "naturalWidth" in source ? source.naturalWidth : source.width;
  const sourceHeight = "naturalHeight" in source ? source.naturalHeight : source.height;
  const size = fitWithin(sourceWidth, sourceHeight);

  const canvas = document.createElement("canvas");
  canvas.width = size.width;
  canvas.height = size.height;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("บีบรูปไม่สำเร็จ");
  // White under transparent PNGs, since JPEG has no alpha.
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, size.width, size.height);
  context.drawImage(source, 0, 0, size.width, size.height);
  if ("close" in source) source.close();

  let blob: Blob | null = null;
  for (const quality of QUALITY_STEPS) {
    blob = await toJpeg(canvas, quality);
    if (blob.size <= PHOTO_TARGET_BYTES) break;
  }
  if (!blob) throw new Error("บีบรูปไม่สำเร็จ");
  return { blob, width: size.width, height: size.height };
}

const FOOD_QUALITY = 0.82;
// A small file can still expand to a huge bitmap (decompression bomb); decoding
// it would spike memory, so anything above this keeps the original untouched.
export const MAX_DECODE_PIXELS = 100_000_000;

/** True for a WebP with the animation flag (VP8X) or an ANIM chunk in its header. */
export async function isAnimatedWebp(file: Blob): Promise<boolean> {
  if (typeof file.slice !== "function") return false;
  const head = new Uint8Array(await file.slice(0, 64).arrayBuffer());
  const tag = (offset: number, text: string) => [...text].every((ch, i) => head[offset + i] === ch.charCodeAt(0));
  if (!tag(0, "RIFF") || !tag(8, "WEBP")) return false;
  if (tag(12, "VP8X") && head.length > 20 && (head[20] & 0x02) !== 0) return true;
  for (let i = 12; i + 4 <= head.length; i++) if (tag(i, "ANIM")) return true;
  return false;
}

/** Reads width x height from the header without decoding the pixels; null if unknown. */
function probeDimensions(file: File): Promise<{ width: number; height: number } | null> {
  if (typeof Image === "undefined" || typeof URL === "undefined") return Promise.resolve(null);
  const url = URL.createObjectURL(file);
  return new Promise<{ width: number; height: number } | null>((resolve) => {
    const image = new Image();
    image.onload = () => resolve({ width: image.naturalWidth, height: image.naturalHeight });
    image.onerror = () => resolve(null);
    image.src = url;
  }).finally(() => URL.revokeObjectURL(url));
}

/**
 * Downscales a Food photo so its longest side is at most PHOTO_MAX_SIDE, keeping the
 * file type (PNG/WebP transparency survives). Re-encoding through a canvas writes a
 * fresh file, so EXIF/GPS is dropped. Returns null when the original should be
 * uploaded as is: already small enough, the browser cannot decode/encode this
 * type, or the result is not smaller. Never throws.
 */
export async function downscalePhoto(file: File, contentType: string): Promise<Blob | null> {
  try {
    // A canvas keeps only the first frame, so animated WebP keeps its original.
    if (await isAnimatedWebp(file)) return null;
    const probe = await probeDimensions(file);
    if (probe && probe.width * probe.height > MAX_DECODE_PIXELS) return null;
    const source = await decode(file);
    const sourceWidth = "naturalWidth" in source ? source.naturalWidth : source.width;
    const sourceHeight = "naturalHeight" in source ? source.naturalHeight : source.height;
    const size = fitWithin(sourceWidth, sourceHeight);
    if (size.width >= sourceWidth && size.height >= sourceHeight) {
      if ("close" in source) source.close();
      return null;
    }
    const canvas = document.createElement("canvas");
    canvas.width = size.width;
    canvas.height = size.height;
    const context = canvas.getContext("2d");
    if (!context) return null;
    context.drawImage(source, 0, 0, size.width, size.height);
    if ("close" in source) source.close();
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, contentType, FOOD_QUALITY));
    // Browsers that cannot encode the type (e.g. WebP) silently return PNG.
    if (!blob || blob.type !== contentType || blob.size >= file.size) return null;
    return blob;
  } catch {
    return null;
  }
}
