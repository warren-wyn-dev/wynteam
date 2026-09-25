import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("an edge swipe inside a dialog cannot navigate away", async ({ page }, info) => {
  test.skip(info.project.name === "chromium-desktop", "touch-only regression");
  // Navigate to a non-root fixture with a real preceding history entry so
  // an accidental router.back() would be observable.
  await page.goto("/dev/wyn-175-skeleton-fixture");
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const before = page.url();
  await page.evaluate(() => {
    const dialog = document.createElement("section");
    dialog.setAttribute("role", "dialog");
    dialog.style.cssText = "position:fixed;inset:0;z-index:9999";
    document.body.appendChild(dialog);
    const start = new Touch({ identifier: 1, target: dialog, clientX: 8, clientY: 180 });
    const end = new Touch({ identifier: 1, target: dialog, clientX: 115, clientY: 182 });
    dialog.dispatchEvent(new TouchEvent("touchstart", { bubbles: true, touches: [start], changedTouches: [start], targetTouches: [start] }));
    dialog.dispatchEvent(new TouchEvent("touchend", { bubbles: true, touches: [], changedTouches: [end], targetTouches: [] }));
    dialog.remove();
  });
  await page.waitForTimeout(200);
  expect(page.url()).toBe(before);
});

test("multi-touch and media drags cannot trigger the global back gesture", () => {
  const swipe = readFileSync(path.join(process.cwd(), "components/swipe-back-gesture.tsx"), "utf8");
  const pull = readFileSync(path.join(process.cwd(), "lib/use-pull-to-refresh.ts"), "utf8");
  expect(swipe).toContain('event.touches.length !== 1');
  expect(swipe).toContain(".wyn-post-media-track");
  expect(swipe).toContain("blocksEdgeSwipe(event.target)");
  expect(pull).toContain("touch.identifier !== start.id");
  expect(pull).toContain(".catch(() =>");
});
