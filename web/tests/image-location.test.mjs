import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compiled = ts.transpileModule(read("../lib/image-location.ts"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, Uint8Array, DataView, Error, Array, Blob });
const { stripJpegLocation, withoutLocation, ImageLocationError } = mod.exports;

/** A JPEG whose EXIF has Orientation = 6 and a GPS IFD (N, 13°45'30"), plus an XMP packet with a position. */
function phoneJpeg(little) {
  const tiff = new Uint8Array(200);
  const view = new DataView(tiff.buffer);
  const u16 = (at, v) => view.setUint16(at, v, little);
  const u32 = (at, v) => view.setUint32(at, v, little);
  tiff.set(little ? [0x49, 0x49] : [0x4d, 0x4d]);
  u16(2, 42); u32(4, 8);
  // IFD0: Orientation, GPS pointer.
  u16(8, 2);
  u16(10, 0x0112); u16(12, 3); u32(14, 1); u16(18, 6);
  u16(22, 0x8825); u16(24, 4); u32(26, 1); u32(30, 50);
  u32(34, 0);
  // GPS IFD at 50: LatitudeRef "N", Latitude 3 rationals at 100.
  u16(50, 2);
  u16(52, 1); u16(54, 2); u32(56, 2); tiff.set([0x4e, 0], 60);
  u16(64, 2); u16(66, 5); u32(68, 3); u32(72, 100);
  u32(76, 0);
  [13, 1, 45, 1, 30, 1].forEach((v, i) => u32(100 + i * 4, v));
  const exif = [...Buffer.from("Exif\0\0"), ...tiff];
  const xmp = [...Buffer.from("http://ns.adobe.com/xap/1.0/\0"), ...Buffer.from('<x exif:GPSLatitude="13,45.5N"/>')];
  const segment = (marker, payload) => [0xff, marker, (payload.length + 2) >> 8, (payload.length + 2) & 0xff, ...payload];
  return {
    bytes: new Uint8Array([0xff, 0xd8, ...segment(0xe0, [...Buffer.from("JFIF\0"), 1, 1, 0, 0, 1, 0, 1, 0, 0]), ...segment(0xe1, exif), ...segment(0xe1, xmp), ...segment(0xda, [1, 2, 3]), 9, 8, 7, 0xff, 0xd9]),
    tiffAt: 2 + 18 + 4 + 6,
  };
}

for (const little of [true, false]) {
  test(`GPS is blanked and XMP dropped, orientation and image data kept (${little ? "II" : "MM"})`, () => {
    const { bytes, tiffAt } = phoneJpeg(little);
    const out = stripJpegLocation(bytes);
    const view = new DataView(out.buffer, out.byteOffset + tiffAt, 200);
    assert.equal(view.getUint16(18, little), 6, "orientation stays");
    assert.equal(view.getUint16(50, little), 0, "GPS IFD has no entries");
    assert.ok(out.subarray(tiffAt + 50, tiffAt + 124).every((b) => b === 0), "GPS values are gone");
    assert.equal(Buffer.from(out).includes("GPSLatitude"), false, "XMP packet removed");
    assert.equal(Buffer.from(out).includes("ns.adobe.com"), false);
    assert.deepEqual([...out.subarray(-12)], [0xff, 0xda, 0, 5, 1, 2, 3, 9, 8, 7, 0xff, 0xd9], "scan data untouched");
    assert.equal(out.length, bytes.length - (4 + 29 + 32), "only the XMP segment is removed");
    assert.deepEqual([...stripJpegLocation(out)], [...out], "idempotent");
  });
}

test("a JPEG without metadata is unchanged", () => {
  const plain = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0, 3, 1, 0xff, 0xda, 0, 2, 5, 0xff, 0xd9]);
  assert.deepEqual([...stripJpegLocation(plain)], [...plain]);
});

test("unreadable or lying files are refused rather than uploaded with a location", () => {
  assert.throws(() => stripJpegLocation(new Uint8Array([0x89, 0x50, 0x4e, 0x47])), ImageLocationError);
  assert.throws(() => stripJpegLocation(new Uint8Array([0xff, 0xd8, 0xff, 0xe1, 0x40, 0])), ImageLocationError);
  const { bytes, tiffAt } = phoneJpeg(true);
  new DataView(bytes.buffer).setUint32(tiffAt + 30, 5000, true); // GPS pointer outside the block
  assert.throws(() => stripJpegLocation(bytes), ImageLocationError);
});

test("only JPEG uploads are rewritten", async () => {
  const png = new Blob([new Uint8Array([1, 2, 3])], { type: "image/png" });
  assert.equal(await withoutLocation(png, "image/png"), png);
  const { bytes } = phoneJpeg(true);
  const jpeg = new Blob([bytes], { type: "image/jpeg" });
  const cleaned = await withoutLocation(jpeg, "image/jpeg");
  assert.equal(cleaned.type, "image/jpeg");
  assert.equal(Buffer.from(await cleaned.arrayBuffer()).includes("GPSLatitude"), false);
});
