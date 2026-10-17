export const MENU_IMAGE_SOURCE_LIMIT = 8 * 1024 * 1024;
export const MENU_IMAGE_UPLOAD_LIMIT = 4 * 1024 * 1024;
export const MENU_IMAGE_LONGEST_SIDE = 1600;
export const MENU_IMAGE_TIMEOUT_MS = 30_000;
const sourceHeaderLimit = 256 * 1024;

const uuidPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
const storePattern = new RegExp(`^${uuidPattern}$`, "i");
const sourceTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

export class MenuImageUploadError extends Error {
  constructor(public readonly code: string) {
    super(code);
    this.name = "MenuImageUploadError";
  }
}

export function menuImageUploadErrorMessage(error: unknown): string {
  const code = error instanceof MenuImageUploadError ? error.code : "unknown";
  switch (code) {
    case "source_size": return "รูปต้องมีขนาดไม่เกิน 8 MB และไม่ใช่ไฟล์ว่าง";
    case "type": return "เลือกรูป JPEG, PNG หรือ WebP เท่านั้น";
    case "image": return "เปิดรูปนี้ไม่ได้ กรุณาเลือกรูป JPEG, PNG หรือ WebP ที่สมบูรณ์";
    case "prepared_size": return "รูปหลังปรับขนาดยังใหญ่เกิน 4 MB กรุณาเลือกรูปที่เล็กลง";
    case "resolution": return "รูปมีความละเอียดสูงเกินไป กรุณาย่อรูปให้ไม่เกิน 32 ล้านพิกเซล และด้านละ 12,000 พิกเซล";
    case "401": return "เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้งก่อนอัปโหลด";
    case "403": return "ไม่มีสิทธิ์อัปโหลดรูปเมนูของร้านนี้";
    case "404": return "ไม่พบร้านนี้ กรุณาโหลดข้อมูลล่าสุดก่อนลองอีกครั้ง";
    case "413": return "รูปมีขนาดเกินที่ระบบรับได้ กรุณาเลือกรูปที่เล็กลง";
    case "415":
    case "422": return "ระบบไม่สามารถอ่านรูปนี้ได้ กรุณาเลือกรูปอื่น";
    case "429": return "อัปโหลดถี่เกินไป กรุณารอสักครู่แล้วลองอีกครั้ง";
    case "timeout": return "อัปโหลดไม่เสร็จภายใน 30 วินาที กรุณาตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง";
    case "aborted": return "ยกเลิกการอัปโหลดแล้ว รูปที่เลือกในเมนูยังคงเดิม";
    case "response": return "ยังยืนยันรูปที่อัปโหลดไม่ได้ รูปเดิมยังคงอยู่ กรุณาลองอีกครั้ง";
    case "configuration": return "ระบบอัปโหลดรูปยังไม่พร้อม กรุณาลองใหม่ภายหลัง";
    default: return "อัปโหลดรูปไม่สำเร็จ รูปเดิมยังคงอยู่ กรุณาตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง";
  }
}

/** Stop waiting immediately on cancellation, and dispose resources that arrive later. */
export function waitForMenuImageTask<T>(task: Promise<T>, signal: AbortSignal, disposeLate?: (value: T) => void): Promise<T> {
  return new Promise((resolve, reject) => {
    let cancelled = signal.aborted;
    const abort = () => {
      cancelled = true;
      reject(new MenuImageUploadError("aborted"));
    };
    if (cancelled) abort();
    else signal.addEventListener("abort", abort, { once: true });
    task.then(value => {
      signal.removeEventListener("abort", abort);
      if (cancelled) disposeLate?.(value);
      else resolve(value);
    }, error => {
      signal.removeEventListener("abort", abort);
      if (!cancelled) reject(error);
    });
  });
}

function assertNotAborted(signal: AbortSignal) {
  if (signal.aborted) throw new MenuImageUploadError("aborted");
}

/** Read dimensions before allocating a decoded raster. Full image validity is still checked by the decoder. */
function checkSourceDimensions(bytes: Uint8Array) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const text = (offset: number) => String.fromCharCode(...bytes.subarray(offset, offset + 4));
  let width = 0, height = 0;
  if (bytes.length >= 24 && [137, 80, 78, 71, 13, 10, 26, 10].every((value, index) => bytes[index] === value)
    && view.getUint32(8) === 13 && text(12) === "IHDR") {
    width = view.getUint32(16); height = view.getUint32(20);
  } else if (bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset + 1 < bytes.length) {
      if (bytes[offset++] !== 0xff) break;
      while (bytes[offset] === 0xff) offset++;
      const marker = bytes[offset++];
      if (marker === 0xd9 || marker === 0xda) break;
      if (marker === 0x01 || marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset + 2 > bytes.length) break;
      const length = view.getUint16(offset);
      if (length < 2) break;
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        if (length < 7 || offset + 7 > bytes.length) break;
        height = view.getUint16(offset + 3); width = view.getUint16(offset + 5); break;
      }
      offset += length;
    }
  } else if (bytes.length >= 12 && text(0) === "RIFF" && text(8) === "WEBP") {
    let offset = 12;
    while (offset + 8 <= bytes.length) {
      const kind = text(offset), length = view.getUint32(offset + 4, true), data = offset + 8;
      if (kind === "VP8X" && length >= 10 && data + 10 <= bytes.length) {
        width = 1 + bytes[data + 4] + (bytes[data + 5] << 8) + (bytes[data + 6] << 16);
        height = 1 + bytes[data + 7] + (bytes[data + 8] << 8) + (bytes[data + 9] << 16); break;
      }
      if (kind === "VP8 " && length >= 10 && data + 10 <= bytes.length
        && bytes[data + 3] === 0x9d && bytes[data + 4] === 0x01 && bytes[data + 5] === 0x2a) {
        width = view.getUint16(data + 6, true) & 0x3fff; height = view.getUint16(data + 8, true) & 0x3fff; break;
      }
      if (kind === "VP8L" && length >= 5 && data + 5 <= bytes.length && bytes[data] === 0x2f) {
        const packed = view.getUint32(data + 1, true);
        width = 1 + (packed & 0x3fff); height = 1 + ((packed >>> 14) & 0x3fff); break;
      }
      offset = data + length + (length % 2);
    }
  }
  if (!width || !height) throw new MenuImageUploadError("image");
  if (width > 12_000 || height > 12_000 || width * height > 32_000_000) throw new MenuImageUploadError("resolution");
}

async function decodeMenuImage(file: File, signal: AbortSignal): Promise<{ source: CanvasImageSource; width: number; height: number; close: () => void }> {
  if (typeof createImageBitmap === "function") {
    const bitmap = await waitForMenuImageTask(createImageBitmap(file), signal, value => value.close());
    return { source: bitmap, width: bitmap.width, height: bitmap.height, close: () => bitmap.close() };
  }
  // Older browsers can still decode through an image element. The object URL is never sent to the server.
  const url = URL.createObjectURL(file);
  const image = new Image();
  try {
    await new Promise<void>((resolve, reject) => {
      const cleanup = () => {
        signal.removeEventListener("abort", abort);
        image.onload = null;
        image.onerror = null;
      };
      const abort = () => { cleanup(); image.src = ""; reject(new MenuImageUploadError("aborted")); };
      image.onload = () => { cleanup(); resolve(); };
      image.onerror = () => { cleanup(); reject(new MenuImageUploadError("image")); };
      signal.addEventListener("abort", abort, { once: true });
      image.src = url;
      if (signal.aborted) abort();
    });
    return { source: image, width: image.naturalWidth, height: image.naturalHeight, close: () => { image.src = ""; } };
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** Decode and redraw rather than forwarding source bytes or metadata. Edge validates again. */
export async function prepareMerchantMenuImage(file: File, signal: AbortSignal): Promise<Blob> {
  assertNotAborted(signal);
  if (!sourceTypes.has(file.type.toLowerCase())) throw new MenuImageUploadError("type");
  if (file.size <= 0 || file.size > MENU_IMAGE_SOURCE_LIMIT) throw new MenuImageUploadError("source_size");
  let decoded: Awaited<ReturnType<typeof decodeMenuImage>>;
  try {
    const header = await waitForMenuImageTask(file.slice(0, sourceHeaderLimit).arrayBuffer(), signal);
    checkSourceDimensions(new Uint8Array(header));
    assertNotAborted(signal);
    decoded = await decodeMenuImage(file, signal);
  } catch (error) {
    if (error instanceof MenuImageUploadError) throw error;
    throw new MenuImageUploadError("image");
  }
  try {
    assertNotAborted(signal);
    if (!Number.isFinite(decoded.width) || !Number.isFinite(decoded.height) || decoded.width <= 0 || decoded.height <= 0) {
      throw new MenuImageUploadError("image");
    }
    const scale = Math.min(1, MENU_IMAGE_LONGEST_SIDE / Math.max(decoded.width, decoded.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(decoded.width * scale));
    canvas.height = Math.max(1, Math.round(decoded.height * scale));
    const context = canvas.getContext("2d");
    if (!context) throw new MenuImageUploadError("image");
    // JPEG has no transparency; use white instead of an implicit black background.
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(decoded.source, 0, 0, canvas.width, canvas.height);
    const prepared = await waitForMenuImageTask(new Promise<Blob>((resolve, reject) => {
      canvas.toBlob(blob => blob ? resolve(blob) : reject(new MenuImageUploadError("image")), "image/jpeg", 0.85);
    }), signal);
    assertNotAborted(signal);
    if (prepared.type !== "image/jpeg" || prepared.size === 0) throw new MenuImageUploadError("image");
    if (prepared.size > MENU_IMAGE_UPLOAD_LIMIT) throw new MenuImageUploadError("prepared_size");
    return prepared;
  } catch (error) {
    if (error instanceof MenuImageUploadError) throw error;
    throw new MenuImageUploadError("image");
  } finally {
    decoded.close();
  }
}

export function uploadMerchantMenuImage({ supabaseUrl, publishableKey, accessToken, storeId, image, signal, onProgress, onProcessing }: {
  supabaseUrl: string; publishableKey: string; accessToken: string; storeId: string; image: Blob; signal: AbortSignal;
  onProgress: (percent: number) => void; onProcessing: () => void;
}): Promise<string> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) { reject(new MenuImageUploadError("aborted")); return; }
    if (!storePattern.test(storeId) || !supabaseUrl || !publishableKey || !accessToken) {
      reject(new MenuImageUploadError("configuration")); return;
    }
    if (!sourceTypes.has(image.type) || image.size === 0 || image.size > MENU_IMAGE_UPLOAD_LIMIT) {
      reject(new MenuImageUploadError("prepared_size")); return;
    }
    const xhr = new XMLHttpRequest();
    let settled = false;
    const cleanup = () => {
      signal.removeEventListener("abort", abort);
      xhr.onload = null; xhr.onerror = null; xhr.onabort = null; xhr.ontimeout = null;
      xhr.upload.onprogress = null; xhr.upload.onload = null;
    };
    const fail = (code: string) => {
      if (settled) return;
      settled = true; cleanup(); reject(new MenuImageUploadError(code));
    };
    const abort = () => { fail("aborted"); xhr.abort(); };
    xhr.onerror = () => fail("network");
    xhr.onabort = () => fail("aborted");
    xhr.ontimeout = () => fail("timeout");
    xhr.upload.onprogress = event => {
      if (!settled && event.lengthComputable && event.total > 0) onProgress(Math.min(100, Math.max(0, Math.round(event.loaded / event.total * 100))));
    };
    xhr.upload.onload = () => { if (!settled) { onProgress(100); onProcessing(); } };
    xhr.onload = () => {
      if (xhr.status < 200 || xhr.status >= 300) { fail(String(xhr.status)); return; }
      let response: unknown = xhr.response;
      try { if (typeof response === "string") response = JSON.parse(response); }
      catch { fail("response"); return; }
      const path = response && typeof response === "object" && "path" in response ? response.path : null;
      const expectedPath = new RegExp(`^admin-menu/${storeId.toLowerCase()}/${uuidPattern}\\.webp$`);
      if (typeof path !== "string" || !expectedPath.test(path)) { fail("response"); return; }
      settled = true; cleanup(); resolve(path);
    };
    signal.addEventListener("abort", abort, { once: true });
    try {
      const endpoint = new URL(`${supabaseUrl.replace(/\/+$/, "")}/functions/v1/admin-merchant-menu-image`);
      endpoint.searchParams.set("store_id", storeId);
      xhr.open("POST", endpoint.toString());
      xhr.responseType = "json";
      xhr.timeout = MENU_IMAGE_TIMEOUT_MS;
      xhr.withCredentials = false;
      xhr.setRequestHeader("Authorization", `Bearer ${accessToken}`);
      xhr.setRequestHeader("apikey", publishableKey);
      xhr.setRequestHeader("Content-Type", image.type);
      xhr.send(image);
    } catch { fail("network"); }
  });
}
