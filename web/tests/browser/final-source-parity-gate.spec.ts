import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("final WYNOS Beta4 source parity contract remains locked", () => {
  const postActions = read("components/home/post-actions.tsx");
  const detail = read("components/post-detail-route.tsx");
  const composer = read("components/beta4-composer.tsx");
  const profile = read("components/profile-route.tsx");
  const publication = read("lib/drop-publication.ts");
  const css = read("app/system-parity-final.css");
  const interactionCss = read("app/interaction-parity-final.css");
  const layout = read("app/layout.tsx");

  expect(postActions).toContain("wyn-action-share");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
  expect(detail).toContain('size={isReply ? 32 : 36}');
  expect(detail).toContain('placeholder="แสดงความคิดเห็น..."');
  // Current Beta1 Profile has icon-only Edit/Share actions and user-selected
  // cover images; protect the current baseline, not the superseded text-only mock.
  expect(profile).toContain('aria-label="แก้ไขโปรไฟล์" title="แก้ไขโปรไฟล์"');
  expect(profile).toContain('aria-label="แชร์โปรไฟล์" title="แชร์โปรไฟล์"');
  expect(profile).toContain('profile.cover_url');
  expect(profile).toContain('<WynosShareIcon size={22} />');

  expect(composer).toContain('type AspectRatioChoice = "original" | "1:1" | "4:5" | "16:9";');
  expect(composer).toContain("beta4-composer-header");
  expect(composer).toContain("beta4-bottom-bar");
  expect(composer).not.toContain("เช็คอิน");
  expect(composer).not.toContain("Check-in");
  expect(composer).not.toContain("สถานที่");
  expect(publication).toContain("p_image_aspect_ratio: input.imageAspectRatio ?? null");

  expect(css).toContain("WYN-158 exact Post Detail + Composer closure");
  expect(css).toContain("height: calc(70px + env(safe-area-inset-top))");
  expect(css).toContain("font-size: 22px");
  expect(css).toContain("color: var(--wyn-like)");
  expect(css).toContain("height: 46px");
  expect(css).toContain("WYN-158 pixel closure from direct Flutter source audit");
  expect(css).toContain("min-height: 72px");
  expect(css).toContain("min-height: 44px");
  expect(css).toContain("grid-template-columns: minmax(0,1fr) 48px");
  expect(composer).toContain("ตัวเลือกที่");
  expect(detail).not.toContain("📍");

  // Founder later approved a real audience picker (feat: "make post audience
  // selectable") — the earlier "no audience/privacy selector" cut is no
  // longer the rule; drafts (WYN-036 parity), mention autocomplete, and a
  // poll-duration picker are still out of scope.
  expect(composer).toContain("SelectedAudienceIcon");
  expect(composer).not.toContain('client.rpc("fetch_mutual_follows"');
  expect(composer).not.toContain('client.from("close_friends")');
  expect(composer).not.toContain("excludedFriendIds: [...excludedFriendIds]");
  expect(composer).not.toContain("mentionedUserIds: new Set");
  expect(composer).not.toContain("searchProfiles");
  expect(composer).not.toContain('client.from("drop_drafts")');
  expect(composer).not.toContain("beta4-drafts");
  expect(composer).not.toContain("beta4-duration");
  expect(composer).toContain("beta4-upload-progress");
  expect(composer).toContain("POLL_DURATION_DAYS = 1");
  expect(composer).toContain('useState<AudienceChoice>("everyone")');
  expect(publication).toContain("p_mentioned_user_ids: input.mentionedUserIds ?? []");
  expect(publication).toContain('input.audience === "friends_except"');
  expect(publication).toContain("input.onImageUploaded?.(index + 1, files.length)");

  expect(detail).not.toContain("window.prompt");
  expect(detail).not.toContain("window.confirm");
  expect(detail).toContain("detail-confirm-dialog");
  expect(detail).toContain("detail-dialog");
  expect(interactionCss).toContain(".detail-dialog-backdrop");
  expect(interactionCss).toContain(".wynos-confirm-dialog");
  expect(interactionCss).toContain("safe-area-inset-bottom");
  expect(layout.lastIndexOf('import "./interaction-parity-final.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./system-parity-final.css";'),
  );
});
