import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const source = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");

test("all person-avatar renderers use the same gray silhouette while Club keeps its own fallback", () => {
  const avatar = source("components/ui/default-profile-avatar.tsx");
  const phase3 = source("components/phase3-ui.tsx");
  const golden = source("components/golden-drop-card.tsx");
  const quote = source("components/quote-feed-card.tsx");
  const ui = source("components/ui/avatar.tsx");

  expect(avatar).toContain('backgroundColor: "#f2f2f2"');
  expect(avatar).toContain('color: "#9c9c9c"');
  expect(avatar).toContain('role="img"');
  expect(avatar).toContain('<svg viewBox="0 0 40 40"');
  for (const renderer of [phase3, golden, quote, ui]) {
    expect(renderer).toContain("<DefaultProfileAvatar");
  }
  // A changed/uploaded image must show immediately even after the previous
  // image URL failed; a stale boolean "failed" state would suppress it.
  for (const renderer of [phase3, golden, quote]) {
    expect(renderer).toContain("failedSrc === src");
    expect(renderer).toContain("setFailedSrc(src)");
  }
  expect(ui).toContain('variant === "person" && !src');
  expect(ui).toContain("fallback?.slice(0, 2).toUpperCase()");
});

test("missing Home photos render a gray person icon, not username initials, at mobile size", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });

  const avatars = page.locator(".wyn-post-avatar > .wyn-default-profile-avatar");
  await expect(avatars).toHaveCount(4);
  for (const avatar of await avatars.all()) {
    await expect(avatar).toHaveCSS("background-color", "rgb(242, 242, 242)");
    await expect(avatar).toHaveCSS("color", "rgb(156, 156, 156)");
    await expect(avatar.locator("svg")).toHaveCount(1);
    expect((await avatar.textContent())?.trim()).toBe("");
    await expect(avatar).toHaveAttribute("role", "img");
  }

  await expect(avatars.first()).toHaveAttribute("aria-label", "รูปโปรไฟล์ของ warren");
  const box = await avatars.first().boundingBox();
  expect(box?.width).toBe(40);
  expect(box?.height).toBe(40);
});
