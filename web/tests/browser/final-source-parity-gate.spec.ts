import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("final WYNOS Beta4 source parity contract remains locked", () => {
  const home = read("components/parity-home-final.tsx");
  const detail = read("components/post-detail-route.tsx");
  const composer = read("components/beta4-composer.tsx");
  const profile = read("components/profile-route.tsx");
  const publication = read("lib/drop-publication.ts");
  const css = read("app/system-parity-final.css");

  expect(home).toContain("audit-share-action");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
  expect(detail).toContain('size={isReply ? 32 : 36}');
  expect(detail).toContain('placeholder="แสดงความคิดเห็น..."');
  expect(profile).toContain('<Pencil size={20} />แก้ไขโปรไฟล์');

  expect(composer).toContain('type AspectRatioChoice = "original" | "1:1" | "4:5" | "16:9";');
  expect(composer).toContain('className="beta4-composer-header"');
  expect(composer).toContain('className="beta4-toolbar"');
  expect(composer).not.toContain("เช็คอิน");
  expect(composer).not.toContain("Check-in");
  expect(composer).not.toContain("สถานที่");
  expect(publication).toContain("p_image_aspect_ratio: input.imageAspectRatio ?? null");

  expect(css).toContain("WYN-158 exact Post Detail + Composer closure");
  expect(css).toContain("height: calc(70px + env(safe-area-inset-top))");
  expect(css).toContain("font-size: 22px");
  expect(css).toContain("color: #f44336");
  expect(css).toContain("height: 46px");
});
