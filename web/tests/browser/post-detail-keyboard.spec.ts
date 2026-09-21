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
  await page.mouse.wheel(0, 400);
  const after = await page.locator("#post-context").boundingBox();
  expect(before).not.toBeNull();
  expect(after).not.toBeNull();
  expect(after!.y).toBeLessThan(before!.y);
});
