import { readFile } from "node:fs/promises";
import path from "node:path";

import { expect, test } from "@playwright/test";

// Signed-in image uploads depend on the user's Supabase account and native
// iOS picker; CI verifies the new edit-profile source contracts without
// modifying production accounts or their existing cover photos.
test("edit profile keeps one bottom save and camera-only photo controls", async () => {
  const root = process.cwd();
  const [route, css, data] = await Promise.all([
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "app/profile-web-beta1.css"), "utf8"),
    readFile(path.join(root, "lib/phase3-data.ts"), "utf8"),
  ]);

  const start = route.indexOf("function EditProfile(");
  const end = route.indexOf("\nfunction ProfileInner(", start);
  expect(start).toBeGreaterThan(0);
  expect(end).toBeGreaterThan(start);
  const edit = route.slice(start, end);

  // No duplicate Save in the header and no separate avatar edit/delete row.
  expect(edit).toContain("wyn-profile-edit-footer");
  expect(edit).toContain("wyn-profile-edit-cover-camera");
  expect(edit).toContain("wyn-profile-edit-avatar-camera");
  expect(edit).not.toContain("wyn-profile-edit-avatar-actions");
  expect(edit).not.toContain("wyn-profile-edit-cover-button");
  expect(route).toContain('title="แก้ไขโปรไฟล์"');
  expect(route).toContain("showBottomNav={false}");

  // Both camera badges open the same sheet and offer three native pickers.
  for (const option of ["คลังรูปภาพ", "ถ่ายภาพ", "ไฟล์ภาพ"]) {
    expect(edit).toContain(option);
  }
  expect(edit).toContain('capture="environment"');
  expect(edit).toContain('onClick={() => setPhotoMenu("avatar")}');
  expect(edit).toContain('onClick={() => setPhotoMenu("cover")}');
  expect(edit).toContain("removeProfileImage(client, userId, kind)");
  expect(edit).toContain("ลบรูปโปรไฟล์");
  expect(edit).toContain("ลบรูปหน้าปก");
  expect(data).toContain('kind: "avatar" | "cover" = "avatar"');
  expect(data).toContain("uploadProfileImage(");

  // Preserve profile-edit fields and original 300-character bio allowance.
  expect(edit).toContain("ชื่อที่แสดง");
  expect(edit).toContain("ชื่อผู้ใช้");
  expect(edit).toContain("คำอธิบายตัวเอง");
  expect(edit).toContain("เว็บไซต์ภายนอก");
  expect(edit).toContain("maxLength={300}");
  expect(css).toContain(".wyn-profile-edit-v2 .wyn-profile-edit-cover > img");
  expect(css).toContain("z-index: 0");
  expect(css).toContain(".wyn-profile-photo-sheet");
  expect(css).toContain("env(safe-area-inset-bottom, 0px)");
});
