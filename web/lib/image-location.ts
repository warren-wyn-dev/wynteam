// Posts, chats and profiles are shared: never publish where a photo was taken.
// A phone's JPEG carries its GPS position in EXIF (and sometimes XMP). The
// EXIF GPS block is blanked in place, so every other offset stays valid and
// the photo's orientation and pixels are untouched; XMP packets are dropped.
// The Android app does the same (PhotoReader.stripLocation).

const EXIF = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
const XMP_PREFIXES = ["http://ns.adobe.com/xap/1.0/\0", "http://ns.adobe.com/xmp/extension/\0"];
const GPS_IFD_TAG = 0x8825;
const TYPE_SIZES: Record<number, number> = { 1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8 };

export class ImageLocationError extends Error {
  constructor() {
    super("อ่านข้อมูลรูปไม่สำเร็จ ลองเลือกรูปอื่น");
  }
}

function startsWith(bytes: Uint8Array, at: number, prefix: ArrayLike<number>) {
  if (at + prefix.length > bytes.length) return false;
  for (let i = 0; i < prefix.length; i += 1) if (bytes[at + i] !== prefix[i]) return false;
  return true;
}

function ascii(text: string) {
  return Array.from(text, (char) => char.charCodeAt(0));
}

/** Blanks the GPS IFD of the TIFF block tiff[0..length) in place. */
function clearGps(tiff: Uint8Array) {
  if (tiff.length < 8) throw new ImageLocationError();
  const little = tiff[0] === 0x49 && tiff[1] === 0x49;
  if (!little && !(tiff[0] === 0x4d && tiff[1] === 0x4d)) throw new ImageLocationError();
  const view = new DataView(tiff.buffer, tiff.byteOffset, tiff.byteLength);
  const u16 = (at: number) => view.getUint16(at, little);
  const u32 = (at: number) => view.getUint32(at, little);
  const inside = (at: number, size: number) => at >= 0 && size >= 0 && at + size <= tiff.length;
  if (u16(2) !== 42) throw new ImageLocationError();

  const ifd0 = u32(4);
  if (!inside(ifd0, 2)) throw new ImageLocationError();
  const entries = u16(ifd0);
  if (!inside(ifd0 + 2, entries * 12)) throw new ImageLocationError();
  for (let i = 0; i < entries; i += 1) {
    const entry = ifd0 + 2 + i * 12;
    if (u16(entry) !== GPS_IFD_TAG) continue;
    const gps = u32(entry + 8);
    if (!inside(gps, 2)) throw new ImageLocationError();
    const count = u16(gps);
    if (!inside(gps + 2, count * 12)) throw new ImageLocationError();
    for (let j = 0; j < count; j += 1) {
      const field = gps + 2 + j * 12;
      const size = (TYPE_SIZES[u16(field + 2)] ?? 1) * u32(field + 4);
      if (size > 4) {
        const at = u32(field + 8);
        if (!inside(at, size)) throw new ImageLocationError();
        tiff.fill(0, at, at + size);
      }
    }
    // An empty GPS IFD: no entries, and its (zeroed) values are unreachable.
    tiff.fill(0, gps + 2, gps + 2 + count * 12);
    view.setUint16(gps, 0, little);
  }
}

/**
 * The same JPEG without its location: EXIF GPS blanked, XMP removed.
 * Throws ImageLocationError when the file is not a JPEG it can read safely.
 */
export function stripJpegLocation(input: Uint8Array): Uint8Array {
  const bytes = input;
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) throw new ImageLocationError();
  const parts: Uint8Array[] = [bytes.subarray(0, 2)];
  let at = 2;
  while (at < bytes.length) {
    if (bytes[at] !== 0xff) throw new ImageLocationError();
    let markerAt = at + 1;
    while (markerAt < bytes.length && bytes[markerAt] === 0xff) markerAt += 1;
    if (markerAt >= bytes.length) throw new ImageLocationError();
    const marker = bytes[markerAt];
    // Start of scan / end of image: the rest is image data, kept as is.
    if (marker === 0xda || marker === 0xd9) {
      parts.push(bytes.subarray(at));
      break;
    }
    // Markers without a length.
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      parts.push(bytes.subarray(at, markerAt + 1));
      at = markerAt + 1;
      continue;
    }
    if (markerAt + 2 >= bytes.length) throw new ImageLocationError();
    const length = (bytes[markerAt + 1] << 8) | bytes[markerAt + 2];
    const end = markerAt + 1 + length;
    if (length < 2 || end > bytes.length) throw new ImageLocationError();
    const payload = markerAt + 3;
    if (marker === 0xe1 && XMP_PREFIXES.some((prefix) => startsWith(bytes, payload, ascii(prefix)))) {
      at = end;
      continue;
    }
    if (marker === 0xe1 && startsWith(bytes, payload, EXIF)) {
      const segment = bytes.slice(at, end);
      clearGps(segment.subarray(payload - at + EXIF.length));
      parts.push(segment);
    } else {
      parts.push(bytes.subarray(at, end));
    }
    at = end;
  }
  const output = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

/** What to upload for a validated image: JPEGs lose their location, other types are unchanged. */
export async function withoutLocation(file: File, contentType: string): Promise<Blob> {
  if (contentType !== "image/jpeg") return file;
  const cleaned = stripJpegLocation(new Uint8Array(await file.arrayBuffer()));
  return new Blob([cleaned as BlobPart], { type: contentType });
}
