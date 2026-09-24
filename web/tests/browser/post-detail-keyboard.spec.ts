import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 1: Post Detail comment composer must sit pinned
 * above the keyboard without a page jump or dead space, and both the
 * comment field and send button must have >=44x44px hit areas.
 *
 * Real iOS keyboard show/hide can't be triggered in headless Chromium, so
 * this drives the same CSS contract useKeyboardInset() publishes
 * (--wyn-kb-inset on <html> + [data-keyboard-open]) directly against the
 * fixture at /dev/post-detail-keyboard-fixture and asserts the composer
 * responds the way the real hook would make it respond.
 */
test.use({ viewport: { width: 390, height: 844 } });

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/post-detail-keyboard-fixture", { waitUntil: "networkidle" });
});

test("composer and send button meet the 44x44 minimum hit area", async ({ page }) => {
  const input = await page.locator("#composer-input").boundingBox();
  const send = await page.locator("#composer-send").boundingBox();
  expect(input?.height).toBeGreaterThanOrEqual(44);
  expect(send?.width).toBeGreaterThanOrEqual(44);
  expect(send?.height).toBeGreaterThanOrEqual(44);
});

test("composer sits flush at the viewport bottom with no keyboard", async ({ page }) => {
  const shell = await page.locator("#composer-shell").boundingBox();
  const viewport = page.viewportSize();
  expect(shell).not.toBeNull();
  expect(viewport).not.toBeNull();
  // Bottom edge of the composer should be at (or within a couple px of) the
  // viewport's bottom edge — no dead space below it.
  expect(shell!.y + shell!.height).toBeGreaterThanOrEqual(viewport!.height - 2);
});

test("composer tracks the keyboard inset instead of leaving a gap or jumping off-screen", async ({ page }) => {
  const before = await page.locator("#composer-shell").boundingBox();
  const kbInset = 336; // a plausible iOS keyboard height at this viewport size

  await page.evaluate((inset) => {
    document.documentElement.style.setProperty("--wyn-kb-inset", `${inset}px`);
    document.documentElement.setAttribute("data-keyboard-open", "true");
  }, kbInset);
  // The shell has a short transform transition (see system-parity-final.css)
  // so the on-screen move isn't a jump; wait for it to settle before reading
  // the final position.
  await page.waitForTimeout(250);

  const after = await page.locator("#composer-shell").boundingBox();
  expect(before).not.toBeNull();
  expect(after).not.toBeNull();

  // The composer must move up by ~kbInset (it tracks the keyboard, it
  // doesn't stay pinned under it or fly off past it).
  const moved = before!.y - after!.y;
  expect(moved).toBeGreaterThan(kbInset - 4);
  expect(moved).toBeLessThan(kbInset + 4);

  // It must still be fully on-screen above the (simulated) keyboard, not
  // hidden past the top of the visible area.
  expect(after!.y).toBeGreaterThanOrEqual(0);
});

test("post context stays reachable behind the fixed composer (single scroll container)", async ({ page }) => {
  // The post body/comments are normal document flow, not a nested
  // scroll container — scrolling the page (the one main scroller) must
  // move them, proving there's no separate inner scroller fighting the
  // keyboard for space.
  const before = await page.locator("#post-context").boundingBox();
  // mouse.wheel() isn't supported in mobile WebKit emulation at all (throws
  // "Mouse wheel is not supported in mobile WebKit" every time on the
  // webkit-iphone CI project) and, separately, dispatches the event without
  // waiting for the resulting scroll to paint -- scrollBy() + waiting for
  // scrollY to actually land works uniformly across every browser project
  // and asserts the same thing: scrolling the real window moves
  // #post-context, proving it's normal document flow, not a nested scroller.
  await page.evaluate(() => window.scrollBy(0, 400));
  await page.waitForFunction(() => window.scrollY > 0);
  const after = await page.locator("#post-context").boundingBox();
  expect(before).not.toBeNull();
  expect(after).not.toBeNull();
  expect(after!.y).toBeLessThan(before!.y);
});

// The fixture is already wrapped by PageTransition in the app layout.
// Its zero-distance motion transform used to become the fixed input's
// containing block, so document scroll hid/dragged the keyboard composer.
test("composer is portaled straight to body, outside transformed PageTransition", async ({ page }) => {
  const host = await page.locator("#composer-shell").evaluate((node) => node.parentElement === document.body);
  expect(host).toBe(true);
  const transforms = await page.locator("#composer-shell").evaluate((node) => {
    const chain: string[] = [];
    for (let el = node.parentElement; el && el !== document.documentElement; el = el.parentElement) {
      chain.push(getComputedStyle(el).transform);
    }
    return chain;
  });
  expect(transforms.every((transform) => transform === "none")).toBe(true);
});

test("Thai draft remains editable and composer stays visible through three keyboard cycles", async ({ page }) => {
  const input = page.locator("#composer-input");
  const shell = page.locator("#composer-shell");
  await input.fill("ทดสอบความคิดเห็นภาษาไทย");
  for (let attempt = 0; attempt < 3; attempt++) {
    await page.evaluate(() => {
      document.documentElement.style.setProperty("--wyn-kb-inset", "316px");
      document.documentElement.setAttribute("data-keyboard-open", "true");
    });
    await expect(shell).toBeVisible();
    const lifted = await shell.boundingBox();
    expect(lifted).not.toBeNull();
    expect(lifted!.y).toBeGreaterThanOrEqual(0);
    expect(lifted!.y + lifted!.height).toBeLessThanOrEqual(844 - 316 + 2);
    await expect(input).toHaveValue("ทดสอบความคิดเห็นภาษาไทย");
    await page.evaluate(() => {
      document.documentElement.style.removeProperty("--wyn-kb-inset");
      document.documentElement.removeAttribute("data-keyboard-open");
    });
    const bottom = await shell.boundingBox();
    expect(bottom).not.toBeNull();
    expect(bottom!.y + bottom!.height).toBeGreaterThanOrEqual(842);
  }
});

test("layout-resized viewport does not apply the keyboard inset twice", async ({ page }) => {
  await page.locator("#composer-input").focus();
  await page.setViewportSize({ width: 390, height: 500 });
  await page.evaluate(() => {
    document.documentElement.style.setProperty("--wyn-kb-inset", "0px");
    document.documentElement.removeAttribute("data-keyboard-open");
  });
  const shell = await page.locator("#composer-shell").boundingBox();
  expect(shell).not.toBeNull();
  expect(shell!.y + shell!.height).toBeGreaterThanOrEqual(498);
  expect(shell!.y + shell!.height).toBeLessThanOrEqual(502);
  const fontSize = await page.locator("#composer-input").evaluate((el) => getComputedStyle(el).fontSize);
  expect(fontSize).toBe("16px");
});

test("cold post load uses content-shaped skeleton rather than a blank spinner", async ({ page }) => {
  await page.goto("/dev/post-detail-keyboard-fixture?loading=1");
  await expect(page.locator(".wyn-skeleton-detail")).toBeVisible();
  await expect(page.locator(".wyn-skeleton-detail-author")).toBeVisible();
  await expect(page.locator(".wyn-skeleton-detail-actions")).toBeVisible();
});
