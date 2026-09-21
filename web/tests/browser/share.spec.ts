import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 5: every "แชร์" button must use navigator.share()
 * when available, fall back to a clipboard copy otherwise, show a
 * "คัดลอกลิงก์แล้ว" toast on a successful copy, and never fail silently.
 * Drives web/lib/share.ts's shareOrCopyLink() directly via the
 * /dev/share-fixture page (see share-fixture.tsx) by stubbing
 * navigator.share / navigator.clipboard.writeText before each scenario.
 */
test.use({ viewport: { width: 390, height: 844 } });

test("no navigator.share -> copies the link and shows a toast", async ({ page }) => {
  await page.addInitScript(() => {
    // @ts-expect-error test stub
    delete window.navigator.share;
    Object.defineProperty(window.navigator, "clipboard", {
      value: { writeText: async () => undefined },
      configurable: true,
    });
  });
  await page.goto("/dev/share-fixture", { waitUntil: "networkidle" });
  await page.locator("#share-button").click();
  await expect(page.locator(".wyn-toast")).toContainText("คัดลอกลิงก์แล้ว");
});

test("no navigator.share and clipboard fails -> shows an error, not silence", async ({ page }) => {
  await page.addInitScript(() => {
    // @ts-expect-error test stub
    delete window.navigator.share;
    Object.defineProperty(window.navigator, "clipboard", {
      value: { writeText: async () => { throw new Error("denied"); } },
      configurable: true,
    });
  });
  await page.goto("/dev/share-fixture", { waitUntil: "networkidle" });
  await page.locator("#share-button").click();
  await expect(page.locator(".wyn-toast")).toContainText("แชร์ไม่สำเร็จ");
});

test("navigator.share succeeds -> no fallback toast (native share sheet handled it)", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(window.navigator, "share", {
      value: async () => undefined,
      configurable: true,
    });
  });
  await page.goto("/dev/share-fixture", { waitUntil: "networkidle" });
  await page.locator("#share-button").click();
  await page.waitForTimeout(200);
  await expect(page.locator(".wyn-toast")).toHaveCount(0);
});

test("navigator.share aborts (cancel or no target) -> falls back to clipboard copy", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(window.navigator, "share", {
      value: async () => { throw new DOMException("cancelled", "AbortError"); },
      configurable: true,
    });
    Object.defineProperty(window.navigator, "clipboard", {
      value: { writeText: async () => undefined },
      configurable: true,
    });
  });
  await page.goto("/dev/share-fixture", { waitUntil: "networkidle" });
  await page.locator("#share-button").click();
  await expect(page.locator(".wyn-toast")).toContainText("คัดลอกลิงก์แล้ว");
});

test("navigator.share fails for a real reason -> shows an error, no silent failure", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(window.navigator, "share", {
      value: async () => { throw new Error("NotAllowedError"); },
      configurable: true,
    });
  });
  await page.goto("/dev/share-fixture", { waitUntil: "networkidle" });
  await page.locator("#share-button").click();
  await expect(page.locator(".wyn-toast")).toContainText("แชร์ไม่สำเร็จ");
});
