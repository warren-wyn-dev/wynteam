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

async function decode(file: File): Promise<ImageBitmap | HTMLImageElement> {
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
