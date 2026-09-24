import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

// Source contracts complement authenticated UI and visual QA.
test("own root profile hides back but content-opened profiles keep it", async () => {
  const root = process.cwd();
  const [nav, page, parity, profile] = await Promise.all([
    readFile(path.join(root, "components/bottom-navigation.tsx"), "utf8"),
    readFile(path.join(root, "app/profile/[id]/page.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-parity-route.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
  ]);
  expect(nav).toContain("href={profileTabHref}");
  expect(nav).toContain('window.location.search !== "?from=tab"');
  expect(page).toContain('fromTab={query.from === "tab"}');
  expect(parity).toContain("fromTab={fromTab}");
  expect(profile).toContain("const showBack = !own || !fromTab;");
  expect(profile).toContain('className="wyn-profile-topbar-back-spacer"');
});

test("rendered @mentions match #hashtag blue and open profile routes", async () => {
  const root = process.cwd();
  const [text, css, profile, resolver] = await Promise.all([
    readFile(path.join(root, "components/rich-post-text.tsx"), "utf8"),
    readFile(path.join(root, "app/founder-parity-lock.css"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "app/[profileSlug]/page.tsx"), "utf8"),
  ]);
  expect(text).toContain("encodeURIComponent(part.slice(1))");
  expect(text).toContain('className="rich-post-link mention"');
  expect(css).toContain(".rich-post-link.hashtag:visited {\n  color: #1d9bf0;");
  expect(css).toContain(".rich-post-link.mention:visited {\n  color: #1d9bf0;");
  expect(css).toContain(".flutter-detail-post .detail-caption .rich-post-link.mention {\n  color: #1d9bf0;");
  expect(profile).toContain('<RichPostText className="wyn-profile-bio" value={profile.bio} />');
  expect(resolver).toContain('profileSlug.startsWith("@")');
});
