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
  await expect(follow).toHaveCSS("height", "26px");
  await expect(caption).toHaveCSS("font-size", "16px");
  await expect(post.locator(".wyn-post-author-name")).toHaveCSS("font-size", "15px");
  await expect(post.locator(".wyn-post-timestamp")).toHaveCSS("font-size", "14px");
  await expect(redrop).toHaveCSS("font-size", "14px");
  await expect(redrop).toHaveCSS("color", "rgb(115, 115, 120)");
  await expect(redrop.locator("svg")).toHaveCSS("width", "16px");
  await expect(actions).toHaveCSS("min-height", "30px");
  await expect(actions.getByRole("button", { name: "รีโพสต์" }).locator("svg")).toHaveCSS("width", "22px");
  const shareIcon = actions.getByRole("button", { name: "แชร์" }).locator(".wyn-share-icon");
  await expect(shareIcon).toHaveCSS("width", "22px");
  await expect(shareIcon).toHaveCSS("height", "22px");
  // Beta1 approved reference: one continuous SVG path, separate up arrow
  // and an open-top U-shaped tray rather than the previous house-like box.
  await expect(shareIcon.locator("path")).toHaveCount(1);
  await expect(shareIcon.locator("path")).toHaveAttribute("d", /M4\.75 11\.75v7\.1/);
  await expect(actions.locator(".wyn-action-button").nth(1)).toHaveCSS("color", "rgb(115, 119, 127)");
  // This Thai fixture is shorter than 190 displayed graphemes. The updated
  // truncation rule must not show a redundant "ดูเพิ่มเติม" control.
  await expect(moreText).toHaveCount(0);
  await expect(tags).toContainText("#WYNOS");
  await expect(tags).not.toContainText("◌");
  // The fixture is untruncated under grapheme-aware counting, so its final
  // hashtag block stays on its own line rather than inline after an ellipsis.
  await expect(tags).toHaveCSS("display", "block");

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
  await expect(nav).toHaveCSS("height", "50px");
  await expect(links).toHaveCount(5);
  for (const label of ["หน้าหลัก", "คลับ", "โพสต์", "แชท", "โปรไฟล์"]) {
    await expect(nav.getByText(label, { exact: true })).toBeVisible();
  }

  const glyph = nav.locator(".route-nav-glyph").first();
  await expect(glyph).toHaveCSS("width", "28px");
  await expect(glyph).toHaveCSS("height", "28px");
});

test("follow control is absent for authors already followed", async ({ page }) => {
  const followedPost = page.locator(".wyn-post").nth(1);
  await expect(followedPost.getByRole("button", { name: "ติดตาม", exact: true })).toHaveCount(0);
  await expect(followedPost.getByRole("button", { name: "กำลังติดตาม", exact: true })).toHaveCount(0);
});

test("action buttons keep a shared baseline while zero-count actions stay compact", async ({ page }) => {
  const post = page.locator(".wyn-post").nth(3);
  const actions = post.locator(".wyn-post-actions");
  const buttons = actions.locator(".wyn-action-button");
  await expect(buttons).toHaveCount(5);

  const boxes = await Promise.all(Array.from({ length: 5 }, (_, index) => buttons.nth(index).boundingBox()));
  for (const box of boxes) expect(box).not.toBeNull();
  const centers = boxes.map((box) => (box!.y + box!.height / 2));
  expect(Math.max(...centers) - Math.min(...centers)).toBeLessThanOrEqual(1);

  const firstFour = boxes.slice(0, 4) as NonNullable<(typeof boxes)[number]>[];
  const clusterWidth = (firstFour[3].x + firstFour[3].width) - firstFour[0].x;
  expect(clusterWidth).toBeLessThan(170);
  expect((boxes[4]!.x - (firstFour[3].x + firstFour[3].width))).toBeGreaterThan(80);
});

test("bookmark remains a direct action after the visual compaction", async ({ page }) => {
  const post = page.locator(".wyn-post").first();
  const save = post.getByRole("button", { name: "บันทึก", exact: true });
  await expect(save).toHaveAttribute("aria-pressed", "false");
  await save.click();
  const unsave = post.getByRole("button", { name: "ยกเลิกบันทึก", exact: true });
  await expect(unsave).toHaveAttribute("aria-pressed", "true");
});

// WYN-168 (2026-09-19): .wyn-post-follow-pill used to hardcode #f1f1f3/#6b6b6b
// instead of var(--wyn-surface)/var(--wyn-text-secondary), so it never adapted
// to dark mode — white text on a near-white background computed to 1.13:1
// (WCAG AA needs 4.5:1), effectively unreadable. Fixed by switching both to
// existing dark-mode-aware tokens from the 2026-09-16 dark mode pass; this
// asserts the actual rendered contrast clears AA in both pill states.
test.describe("dark mode", () => {
  test.use({ colorScheme: "dark" });

  test("follow pill text clears WCAG AA contrast in both states", async ({ page }) => {
    await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

    const contrastOf = (bg: string, fg: string) => {
      const parse = (s: string) => s.match(/\d+/g)!.slice(0, 3).map(Number) as [number, number, number];
      const luminance = ([r, g, b]: [number, number, number]) => {
        const c = (v: number) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
        return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b);
      };
      const l1 = luminance(parse(bg));
      const l2 = luminance(parse(fg));
      const [hi, lo] = l1 > l2 ? [l1, l2] : [l2, l1];
      return (hi + 0.05) / (lo + 0.05);
    };

    const defaultStyles = await page.locator(".wyn-post-follow-pill").first().evaluate((el) => {
      const cs = getComputedStyle(el);
      return { bg: cs.backgroundColor, color: cs.color };
    });
    expect(contrastOf(defaultStyles.bg, defaultStyles.color)).toBeGreaterThanOrEqual(4.5);

    const requestedStyles = await page.locator(".wyn-post-follow-pill").first().evaluate((el) => {
      el.classList.add("is-requested");
      const cs = getComputedStyle(el);
      const result = { bg: cs.backgroundColor, color: cs.color };
      el.classList.remove("is-requested");
      return result;
    });
    expect(contrastOf(requestedStyles.bg, requestedStyles.color)).toBeGreaterThanOrEqual(4.5);
  });
});
