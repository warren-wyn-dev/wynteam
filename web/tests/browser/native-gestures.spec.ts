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
    // WebKit on CI exposes Touch but refuses direct construction.
    // Dispatch events with the same touch-list shape our gesture handler
    // actually consumes; this tests the dialog exclusion on every engine.
    const dispatchTouch = (
      type: string,
      touches: Array<{ identifier: number; clientX: number; clientY: number }>,
      changedTouches = touches,
    ) => {
      const event = new Event(type, { bubbles: true, cancelable: true });
      Object.defineProperties(event, {
        touches: { value: touches },
        changedTouches: { value: changedTouches },
        targetTouches: { value: touches },
      });
      dialog.dispatchEvent(event);
    };
    dispatchTouch("touchstart", [{ identifier: 1, clientX: 8, clientY: 180 }]);
    dispatchTouch("touchend", [], [{ identifier: 1, clientX: 115, clientY: 182 }]);
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
  expect(swipe).toContain('new URLSearchParams(window.location.search).get("from") === "tab"');
  expect(pull).toContain("touch.identifier !== start.id");
  expect(pull).toContain(".catch(() =>");
});
