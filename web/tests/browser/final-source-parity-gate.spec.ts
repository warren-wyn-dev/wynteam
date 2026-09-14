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
  const interactionCss = read("app/interaction-parity-final.css");
  const layout = read("app/layout.tsx");

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
  expect(css).toContain("WYN-158 pixel closure from direct Flutter source audit");
  expect(css).toContain("min-height: 72px");
  expect(css).toContain("min-height: 44px");
  expect(css).toContain("grid-template-columns: minmax(0,1fr) 48px");
  expect(composer).toContain("ตัวเลือกที่");
  expect(composer).toContain("SelectedAudienceIcon");
  expect(detail).not.toContain("📍");

  expect(composer).toContain('client.rpc("fetch_mutual_follows"');
  expect(composer).toContain('client.from("close_friends")');
  expect(composer).toContain("excludedFriendIds");
  expect(composer).toContain("mentionedUserIds");
  expect(composer).toContain("searchProfiles(client, query, 0)");
  expect(composer).toContain("new File([blob]");
  expect(composer).toContain("beta4-upload-progress");
  expect(publication).toContain("p_mentioned_user_ids: input.mentionedUserIds ?? []");
  expect(publication).toContain('input.audience === "friends_except"');
  expect(publication).toContain("input.onImageUploaded?.(index + 1, files.length)");

  expect(detail).not.toContain("window.prompt");
  expect(detail).not.toContain("window.confirm");
  expect(detail).toContain("detail-confirm-dialog");
  expect(detail).toContain("detail-dialog");
  expect(interactionCss).toContain(".detail-dialog-backdrop");
  expect(interactionCss).toContain("safe-area-inset-bottom");
  expect(layout.lastIndexOf('import "./interaction-parity-final.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./system-parity-final.css";'),
  );
});
