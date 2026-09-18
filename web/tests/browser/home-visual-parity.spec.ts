import { expect, test } from "@playwright/test";

/**
 * Home regression coverage for the Founder-supplied 864 x 1536 reference.
 *
 * The reference is exactly 432 x 768 logical px at DPR 2. It is intentionally
 * denser than the older 426 x 923 lock: compact top chrome, compact post text,
 * and a shorter bottom navigation are part of the approved visual direction.
 */
test.use({ viewport: { width: 432, height: 768 }, deviceScaleFactor: 2 });

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const media = page.locator(".wyn-post-media-item").first();
  if (await media.count()) {
    await media.evaluate((img) => {
      const image = img as HTMLImageElement;
      if (image.complete) return;
      return new Promise((resolve) => {
        image.addEventListener("load", resolve, { once: true });
        image.addEventListener("error", resolve, { once: true });
      });
    });
  }
});

test("Home top chrome matches the compact 36 + 32 reference geometry", async ({ page }) => {
  const home = page.locator(".wyn-home");
  const header = page.locator(".wyn-home-header");
  const tabs = page.locator(".wyn-home-tabs");
  const activeTab = page.getByRole("tab", { name: "สำหรับคุณ" });
  const indicator = activeTab.locator(".wyn-home-tab-indicator");

  await expect(header).toHaveCSS("height", "36px");
  await expect(tabs).toHaveCSS("height", "32px");
  await expect(activeTab).toHaveAttribute("aria-selected", "true");

  const [homeBox, indicatorBox] = await Promise.all([home.boundingBox(), indicator.boundingBox()]);
  expect(homeBox).not.toBeNull();
  expect(indicatorBox).not.toBeNull();
  expect(Math.abs((homeBox?.height ?? 0) - 68)).toBeLessThanOrEqual(1);
  expect(Math.abs((indicatorBox?.width ?? 0) - 120)).toBeLessThanOrEqual(1);
  expect(Math.abs((indicatorBox?.height ?? 0) - 2)).toBeLessThanOrEqual(0.5);
});

test("first post matches compact avatar author caption and action geometry", async ({ page }) => {
  const post = page.locator(".wyn-post").first();
  const avatar = post.locator(".wyn-post-avatar");
  const body = post.locator(".wyn-post-body");
  const redrop = post.locator(".wyn-post-redrop-line");
  const follow = post.getByRole("button", { name: "ติดตาม", exact: true });
  const caption = post.locator(".wyn-post-caption-wrap");
  const moreText = post.getByText("ดูเพิ่มเติม", { exact: false });
  const tags = post.locator(".wyn-post-caption-tags");
  const actions = post.locator(".wyn-post-actions");

  await expect(redrop).toContainText("รีโพสต์โดย WYNOS");
  await expect(follow).toHaveCSS("height", "28px");
  await expect(caption).toHaveCSS("font-size", "16px");
  await expect(post.locator(".wyn-post-author-name")).toHaveCSS("font-size", "15px");
  await expect(post.locator(".wyn-post-timestamp")).toHaveCSS("font-size", "14px");
  await expect(redrop).toHaveCSS("font-size", "14px");
  await expect(redrop).toHaveCSS("color", "rgb(126, 126, 131)");
  await expect(redrop.locator("svg")).toHaveCSS("width", "16px");
  await expect(actions).toHaveCSS("min-height", "32px");
  await expect(actions.locator(".wyn-action-button").first()).toHaveCSS("color", "rgb(126, 126, 131)");
  await expect(moreText).toBeVisible();
  await expect(tags).toContainText("#WYNOS");

  const [postBox, avatarBox, bodyBox, redropBox, actionsBox] = await Promise.all([
    post.boundingBox(),
    avatar.boundingBox(),
    body.boundingBox(),
    redrop.boundingBox(),
    actions.boundingBox(),
  ]);

  expect(postBox).not.toBeNull();
  expect(avatarBox).not.toBeNull();
  expect(bodyBox).not.toBeNull();
  expect(redropBox).not.toBeNull();
  expect(actionsBox).not.toBeNull();
  expect(Math.abs((avatarBox?.width ?? 0) - 40)).toBeLessThanOrEqual(1);
  expect(Math.abs(((bodyBox?.x ?? 0) - (avatarBox?.x ?? 0)) - 50)).toBeLessThanOrEqual(1);
  expect(Math.abs((redropBox?.x ?? 0) - 37)).toBeLessThanOrEqual(2);
  expect((postBox?.height ?? 999)).toBeLessThan(365);
  expect((actionsBox?.height ?? 0)).toBeLessThanOrEqual(34);
});

test("feed density keeps short posts short instead of article-sized", async ({ page }) => {
  const first = page.locator(".wyn-post").nth(0);
  const second = page.locator(".wyn-post").nth(1);
  const third = page.locator(".wyn-post").nth(2);

  const [firstBox, secondBox, thirdBox] = await Promise.all([
    first.boundingBox(),
    second.boundingBox(),
    third.boundingBox(),
  ]);

  expect(firstBox).not.toBeNull();
  expect(secondBox).not.toBeNull();
  expect(thirdBox).not.toBeNull();
  expect(firstBox?.height ?? 999).toBeLessThan(365);
  expect(secondBox?.height ?? 999).toBeLessThan(260);
  expect(thirdBox?.height ?? 999).toBeLessThan(150);
});

test("bottom navigation stays compact and preserves all five WYNOS destinations", async ({ page }) => {
  const nav = page.locator(".route-bottom-nav");
  const links = nav.locator(".route-nav-link");

  await expect(nav).toHaveCSS("position", "fixed");
  await expect(nav).toHaveCSS("height", "44px");
  await expect(links).toHaveCount(5);
  for (const label of ["หน้าหลัก", "คลับ", "โพสต์", "แชท", "โปรไฟล์"]) {
    await expect(nav.getByText(label, { exact: true })).toBeVisible();
  }

  const glyph = nav.locator(".route-nav-glyph").first();
  await expect(glyph).toHaveCSS("width", "24px");
  await expect(glyph).toHaveCSS("height", "24px");
});

test("bookmark remains a direct action after the visual compaction", async ({ page }) => {
  const post = page.locator(".wyn-post").first();
  const save = post.getByRole("button", { name: "บันทึก", exact: true });
  await expect(save).toHaveAttribute("aria-pressed", "false");
  await save.click();
  const unsave = post.getByRole("button", { name: "ยกเลิกบันทึก", exact: true });
  await expect(unsave).toHaveAttribute("aria-pressed", "true");
});
