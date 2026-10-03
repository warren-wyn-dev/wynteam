// WEB-B1-QA-04: unit tests for the upload content validator. No network.
import { assertEquals } from "jsr:@std/assert@1";

import {
  type Deps,
  objectUrl,
  type ReadResult,
  sniffImage,
  targetFromPayload,
  validateUpload,
  type WebhookPayload,
} from "./_lib.ts";

const bytes = (...values: (number | string)[]) =>
  new Uint8Array(values.flatMap((v) => typeof v === "string" ? [...v].map((c) => c.charCodeAt(0)) : [v]));

const JPEG = bytes(0xff, 0xd8, 0xff, 0xe0, 0, 0x10, "JFIF");
const PNG = bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d);
const GIF = bytes("GIF89a", 1, 0, 1, 0);
const WEBP = bytes("RIFF", 0x24, 0, 0, 0, "WEBPVP8 ");
const HEIC = bytes(0, 0, 0, 0x18, "ftyp", "heic", 0, 0, 0, 0, "mif1", "heic");
const HEIF_COMPAT = bytes(0, 0, 0, 0x1c, "ftyp", "iso8", 0, 0, 0, 0, "iso8", "mif1", "miaf");
const AVIF = bytes(0, 0, 0, 0x20, "ftyp", "avif", 0, 0, 0, 0, "avif", "mif1", "miaf", "MA1B");

Deno.test("real images of every allowed type are recognised", () => {
  assertEquals(sniffImage(JPEG), "jpeg");
  assertEquals(sniffImage(PNG), "png");
  assertEquals(sniffImage(GIF), "gif");
  assertEquals(sniffImage(WEBP), "webp");
  assertEquals(sniffImage(HEIC), "heif");
  assertEquals(sniffImage(HEIF_COMPAT), "heif");
  assertEquals(sniffImage(AVIF), "heif");
});

Deno.test("non-images are rejected even when they look close", () => {
  for (
    const sample of [
      new Uint8Array(),
      bytes("<!doctype html><script>alert(1)</script>"),
      bytes('<svg xmlns="http://www.w3.org/2000/svg">'),
      bytes("%PDF-1.7"),
      bytes("PK", 3, 4), // zip
      bytes(0x7f, "ELF"),
      bytes(0, 0, 0, 0x18, "ftyp", "isom", 0, 0, 0, 0, "isom", "mp42"), // mp4 video
      bytes("RIFF", 0x24, 0, 0, 0, "WAVE"),
      bytes(0xff, 0xd8), // truncated jpeg marker
      bytes("GIF90a"),
    ]
  ) {
    assertEquals(sniffImage(sample), null, new TextDecoder().decode(sample));
  }
});

const event = (overrides: Partial<WebhookPayload> & { record?: Record<string, unknown> | null } = {}) => ({
  type: "INSERT",
  schema: "storage",
  table: "objects",
  record: { id: "obj-1", bucket_id: "drop-images", name: "u1/publications/op/0.jpg" },
  ...overrides,
}) as WebhookPayload;

Deno.test("only image-bucket objects with sane paths are inspected", () => {
  assertEquals(targetFromPayload(event()), { bucket: "drop-images", name: "u1/publications/op/0.jpg", id: "obj-1" });
  assertEquals(targetFromPayload(event({ type: "UPDATE" }))?.bucket, "drop-images");
  for (const bucket of ["avatars", "chat-media", "club-media", "food-private", "food-public"]) {
    assertEquals(targetFromPayload(event({ record: { bucket_id: bucket, name: "a/b.png" } }))?.bucket, bucket);
  }
  const ignored: WebhookPayload[] = [
    event({ type: "DELETE" }),
    event({ schema: "public" }),
    event({ table: "notifications" }),
    event({ record: null }),
    event({ record: { bucket_id: "pop-videos", name: "u1/v.mp4" } }),
    event({ record: { bucket_id: "appeal-evidence", name: "u1/e.pdf" } }),
    event({ record: { bucket_id: "drop-images", name: "" } }),
    event({ record: { bucket_id: "drop-images", name: "/abs.jpg" } }),
    event({ record: { bucket_id: "drop-images", name: "u1/../u2/x.jpg" } }),
    event({ record: { bucket_id: "drop-images", name: "u1/.emptyFolderPlaceholder" } }),
    event({ record: { bucket_id: "drop-images", name: 42 } }),
  ];
  for (const payload of ignored) assertEquals(targetFromPayload(payload), null, JSON.stringify(payload));
});

Deno.test("object URLs encode each path segment but keep the slashes", () => {
  assertEquals(
    objectUrl("https://x.supabase.co", "drop-images", "u1/รูป #1.jpg"),
    "https://x.supabase.co/storage/v1/object/drop-images/u1/%E0%B8%A3%E0%B8%B9%E0%B8%9B%20%231.jpg",
  );
});

function fakeDeps(reads: ReadResult[], removeOk = true) {
  const calls = { reads: 0, removes: 0, sleeps: [] as number[], logs: [] as Record<string, unknown>[] };
  const deps: Deps = {
    readHead: () => Promise.resolve(reads[Math.min(calls.reads++, reads.length - 1)]),
    remove: () => {
      calls.removes++;
      return Promise.resolve(removeOk);
    },
    sleep: (ms) => {
      calls.sleeps.push(ms);
      return Promise.resolve();
    },
    log: (entry) => calls.logs.push(entry),
  };
  return { deps, calls };
}

Deno.test("a real image is kept", async () => {
  const { deps, calls } = fakeDeps([{ status: "ok", bytes: PNG }]);
  assertEquals(await validateUpload(event(), deps), "image");
  assertEquals(calls.removes, 0);
});

Deno.test("spoofed MIME: non-image bytes uploaded as image/jpeg are removed", async () => {
  const { deps, calls } = fakeDeps([{ status: "ok", bytes: bytes("<html>not a jpeg</html>") }]);
  assertEquals(await validateUpload(event(), deps), "removed");
  assertEquals(calls.removes, 1);
  assertEquals(calls.logs, [{ outcome: "removed", bucket: "drop-images", object_id: "obj-1", reason: "not_an_image" }]);
});

Deno.test("an empty object is removed", async () => {
  const { deps } = fakeDeps([{ status: "ok", bytes: new Uint8Array() }]);
  assertEquals(await validateUpload(event(), deps), "removed");
});

Deno.test("a failed delete is reported, not hidden", async () => {
  const { deps, calls } = fakeDeps([{ status: "ok", bytes: bytes("MZ") }], false);
  assertEquals(await validateUpload(event(), deps), "remove_failed");
  assertEquals(calls.logs[0].outcome, "remove_failed");
});

Deno.test("a not-yet-readable object is retried, then read", async () => {
  const { deps, calls } = fakeDeps([{ status: "missing" }, { status: "missing" }, { status: "ok", bytes: bytes("text") }]);
  assertEquals(await validateUpload(event(), deps), "removed");
  assertEquals(calls.reads, 3);
  assertEquals(calls.sleeps, [1000, 2000]);
});

Deno.test("an object that stays missing is left alone", async () => {
  const { deps, calls } = fakeDeps([{ status: "missing" }]);
  assertEquals(await validateUpload(event(), deps), "missing");
  assertEquals(calls.reads, 3);
  assertEquals(calls.removes, 0);
});

Deno.test("a read error never deletes anything (fail-open, logged)", async () => {
  const { deps, calls } = fakeDeps([{ status: "error", httpStatus: 500 }]);
  assertEquals(await validateUpload(event(), deps), "read_error");
  assertEquals(calls.reads, 1);
  assertEquals(calls.removes, 0);
  assertEquals(calls.logs[0].outcome, "read_error");
});

Deno.test("ignored events never touch storage", async () => {
  const { deps, calls } = fakeDeps([{ status: "ok", bytes: bytes("x") }]);
  assertEquals(await validateUpload(event({ record: { bucket_id: "pop-videos", name: "u/v.mp4" } }), deps), "ignored");
  assertEquals(calls.reads, 0);
  assertEquals(calls.removes, 0);
});
