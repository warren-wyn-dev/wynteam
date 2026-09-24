import { readFile } from "node:fs/promises";
import path from "node:path";

import { expect, test } from "@playwright/test";

// Source contracts complement the signed-in visual QA on physical devices:
// CI cannot access a founder's authenticated, custom-cover profile.
test("Beta1 profile polish retains typography, cover data and core actions", async () => {
  const root = process.cwd();
  const files = await Promise.all([
    "components/profile-route.tsx",
    "components/ui/wynos-icon.tsx",
    "components/ui/wynos-share-icon.tsx",
    "app/profile-web-beta1.css",
    "components/golden-drop-card.tsx",
    "app/layout.tsx",
  ].map((file) => readFile(path.join(root, file), "utf8")));
  const [profile, iconMap, shareIcon, css, post, layout] = files;

  // New iOS-style icon in both routes; no alternate arrow in the post row.
  expect(iconMap).toContain("share:Share,");
  expect(shareIcon).toContain('className={["wyn-share-icon", className].filter(Boolean).join(" ")}');
  expect(shareIcon).toContain("M12 15.5V3.5");
  expect(shareIcon).toContain("M4.75 11.75v7.1");
  expect(shareIcon).not.toContain("M8 8H5.75");
  expect(iconMap).toContain('name==="share")return <WynosShareIcon');
  expect(profile).toContain('<WynosShareIcon size={22} />');
  expect(post).toContain('<WynosShareIcon size={22} />');

  // Profile editing remains icon-only; both cover and feed data remain live.
  expect(profile).toContain('aria-label="แก้ไขโปรไฟล์" title="แก้ไขโปรไฟล์"');
  expect(profile).toContain('profile.cover_url');
  expect(profile).toContain('uploadProfileImage(client, userId, kind, file)');
  expect(profile).toContain('if (kind === "avatar") setAvatar(url);');
  expect(profile).toContain('else setCover(url);');
  expect(profile).toContain('<ProfileFeed key={`${profileId}:${tab}`} client={client} profileId={profileId} viewerId={userId} kind={tab} />');
  expect(profile).toContain("wyn-profile-display-name");

  // Profile header typography is unchanged; feed typography now inherits Home.
  for (const value of ["font-size: 17px;", "font-size: 14px;", "font-size: 16px;"]) {
    expect(css).toContain(value);
  }
  expect(css).toContain(".wyn-profile-display-name");
  expect(css).toContain("text-overflow: ellipsis;");
  expect(css).toContain("@media (display-mode: standalone)");
  expect(css).toContain("env(safe-area-inset-top, 0px)");
  expect(css).toContain("margin-left: auto !important;");

  // No changes to the user-supplied cover or the approved text sizes.
  expect(css).toContain("padding: 0 16px 4px;");
  expect(layout).toContain('statusBarStyle:"black-translucent"');
  expect(css).toContain("body:not(:has(.wyn-profile-beta1))::before");
  expect(css).toContain(".wyn-profile-cover::after");
  expect(css).not.toContain("margin-top: calc(-1 * env(safe-area-inset-top");
  expect(profile).toContain('<Image src={normalizeExternalUrl(profile.cover_url) ?? ""}');
  // The shared SVG uses the approved yellow/orange seal and white check.
  // Both Home and Profile use one cache-busted SVG through the global class.
  const globalBadgeCss = await readFile(path.join(root, "app/phase3.css"), "utf8");
  const badgeSvg = await readFile(path.join(root, "public/verified-badge-v2.svg"), "utf8");
  expect(globalBadgeCss).toContain('url("/verified-badge-v2.svg?v=4")');
  expect(badgeSvg).toContain('stroke="#FFFFFF"');
  expect(badgeSvg).not.toContain('stroke="#111111"');
  expect(badgeSvg).toContain('stop-color="#FFE82A"');
  expect(badgeSvg).toContain('stop-color="#FF7045"');
  expect(css).not.toContain(".wyn-profile-beta1 .route-verified {");
  expect(css).toContain(".wyn-profile-beta1 .wyn-profile-name .route-verified");

});
