import { expect, test } from "@playwright/test";

/**
 * Home regression coverage for the Founder-approved WYNOS mockup.
 *
 * The old suite compared Home against Flutter-era PNG goldens. Home now has
 * an explicitly approved Web-App visual direction, so this suite locks the
 * intended geometry and interaction states directly. That keeps the tests
 * useful across WebKit, Chromium Android and desktop without treating the
 * superseded screenshots as product requirements.
 */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await page.locator(".wyn-post-media-item").first().evaluate((img) => {
    const image = img as HTMLImageElement;
    if (image.complete) return;
    return new Promise((resolve) => {
      image.addEventListener("load", resolve, { once: true });
      image.addEventListener("error", resolve, { once: true });
    });
  });
});

test("Home header and three feed tabs use the approved 56 + 52 chrome", async ({ page }) => {
  const home = page.locator(".wyn-home");
  const header = page.locator(".wyn-home-header");
  const tabs = page.locator(".wyn-home-tabs");
  const activeTab = page.getByRole("tab", { name: "สำหรับคุณ" });
  const indicator = activeTab.locator(".wyn-home-tab-indicator");

  await expect(home).toBeVisible();
  await expect(header).toHaveCSS("height", "56px");
  await expect(tabs).toHaveCSS("height", "52px");
  await expect(activeTab).toHaveAttribute("aria-selected", "true");

  const homeBox = await home.boundingBox();
  const indicatorBox = await indicator.boundingBox();
  expect(homeBox).not.toBeNull();
  expect(indicatorBox).not.toBeNull();
  expect(Math.abs((homeBox?.height ?? 0) - 108)).toBeLessThanOrEqual(1);
  expect(Math.abs((indicatorBox?.height ?? 0) - 2)).toBeLessThanOrEqual(0.5);
  expect(indicatorBox?.width ?? 0).toBeGreaterThan(70);

  const activeIndicatorColor = await indicator.evaluate((node) => getComputedStyle(node).backgroundColor);
  expect(activeIndicatorColor).not.toBe("rgba(0, 0, 0, 0)");

  await page.getByRole("tab", { name: "กำลังติดตาม" }).click();
  await expect(page.getByRole("tab", { name: "กำลังติดตาม" })).toHaveAttribute("aria-selected", "true");
  await expect(page.getByRole("tab", { name: "สำหรับคุณ" })).toHaveAttribute("aria-selected", "false");
});

test("first Home post preserves the approved compact author and follow layout", async ({ page }) => {
  const post = page.locator(".wyn-post").first();
  const avatar = post.locator(".wyn-post-avatar");
  const body = post.locator(".wyn-post-body");
  const caption = post.locator(".wyn-post-caption");
  const follow = post.getByRole("button", { name: "ติดตาม", exact: true });

  await expect(post).toBeVisible();
  await expect(follow).toBeVisible();
  await expect(follow).toHaveCSS("height", "28px");
  await expect(post.locator(".wyn-post-author-row")).not.toContainText("@");

  const [postMetrics, avatarBox, bodyBox, captionBox] = await Promise.all([
    post.evaluate((node) => ({ clientWidth: node.clientWidth, scrollWidth: node.scrollWidth })),
    avatar.boundingBox(),
    body.boundingBox(),
    caption.boundingBox(),
  ]);

  expect(postMetrics.scrollWidth).toBeLessThanOrEqual(postMetrics.clientWidth + 1);
  expect(avatarBox).not.toBeNull();
  expect(bodyBox).not.toBeNull();
  expect(captionBox).not.toBeNull();
  expect(Math.abs((avatarBox?.width ?? 0) - 44)).toBeLessThanOrEqual(1);
  expect((bodyBox?.x ?? 0) - (avatarBox?.x ?? 0)).toBeGreaterThanOrEqual(53);
  expect(Math.abs((captionBox?.x ?? 0) - (bodyBox?.x ?? 0))).toBeLessThanOrEqual(1);

  const followBackground = await follow.evaluate((node) => getComputedStyle(node).backgroundColor);
  expect(followBackground).not.toBe("rgba(0, 0, 0, 0)");
});

test("followed-style pending state remains visible as a white bordered control", async ({ page }) => {
  const secondPost = page.locator(".wyn-post").nth(1);
  const pending = secondPost.getByRole("button", { name: "ขอติดตามแล้ว", exact: true });

  await expect(pending).toBeVisible();
  await expect(pending).toHaveAttribute("aria-pressed", "true");

  const state = await pending.evaluate((node) => {
    const css = getComputedStyle(node);
    return {
      background: css.backgroundColor,
      borderWidth: css.borderTopWidth,
      borderStyle: css.borderTopStyle,
    };
  });
  expect(state.borderWidth).toBe("1px");
  expect(state.borderStyle).toBe("solid");
  expect(state.background).not.toBe("rgba(0, 0, 0, 0)");
});

test("bottom navigation keeps all five WYNOS destinations without a selected tile", async ({ page }) => {
  const nav = page.locator(".route-bottom-nav");
  const links = nav.locator(".route-nav-link");

  await expect(nav).toBeVisible();
  await expect(nav).toHaveCSS("position", "fixed");
  await expect(links).toHaveCount(5);
  for (const label of ["หน้าหลัก", "คลับ", "โพสต์", "แชท", "โปรไฟล์"]) {
    await expect(nav.getByText(label, { exact: true })).toBeVisible();
  }

  const navMetrics = await nav.evaluate((node) => ({
    clientWidth: node.clientWidth,
    scrollWidth: node.scrollWidth,
  }));
  expect(navMetrics.scrollWidth).toBeLessThanOrEqual(navMetrics.clientWidth + 1);

  const homeLink = nav.getByRole("link", { name: "หน้าหลัก" });
  await expect(homeLink).toHaveClass(/active/);
  const pseudoContent = await homeLink.evaluate((node) => getComputedStyle(node, "::before").content);
  expect(["none", "normal", "\"\""]).toContain(pseudoContent);
});

test("long caption remains dense and never creates horizontal overflow", async ({ page }) => {
  const post = page.locator(".wyn-post").nth(1);
  const caption = post.locator(".wyn-post-caption");
  const actions = post.locator(".wyn-post-actions");

  const [captionBox, actionsBox, metrics] = await Promise.all([
    caption.boundingBox(),
    actions.boundingBox(),
    post.evaluate((node) => ({ clientWidth: node.clientWidth, scrollWidth: node.scrollWidth })),
  ]);

  expect(captionBox).not.toBeNull();
  expect(actionsBox).not.toBeNull();
  expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.clientWidth + 1);

  const blankGap = (actionsBox?.y ?? 0) - ((captionBox?.y ?? 0) + (captionBox?.height ?? 0));
  expect(blankGap).toBeGreaterThanOrEqual(0);
  expect(blankGap).toBeLessThanOrEqual(12);
});
