import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("the five-tab dock is accessible before scroll and returns after immersive Feed scrolling", async ({ page }) => {
  // iPhone's shorter viewport previously failed an obsolete test that expected
  // the dock to remain visible even when the approved immersive mode hides it.
  await page.setViewportSize({ width: 390, height: 600 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

  const root = page.locator("html");
  const nav = page.locator(".route-bottom-nav");
  const fab = page.getByRole("button", { name: "สร้างโพสต์" });

  await expect(nav.getByRole("link")).toHaveCount(5);
  await expect(nav).toHaveCSS("position", "fixed");
  await expect(nav).toBeInViewport();
  await expect(fab).toBeHidden();

  // The approved Home UX deliberately hides the dock and header on a
  // meaningful downward scroll, leaving the accessible compose shortcut.
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(300);
  await expect(root).toHaveClass(/wyn-home-scroll-hidden/);
  await expect(nav).toBeHidden();
  await expect(fab).toBeVisible();

  // An upward swipe must restore the original five-tab dock without a reload.
  await page.evaluate(() => window.scrollBy(0, -80));
  await expect(root).not.toHaveClass(/wyn-home-scroll-hidden/);
  await expect(nav).toBeVisible();
  await expect(nav).toBeInViewport();
  await expect(nav).toHaveCSS("position", "fixed");
  await expect(nav.getByRole("link")).toHaveCount(5);
  await expect(fab).toBeHidden();

  // Ensure the dock stays fully inside the visual viewport after recovering.
  const placement = await nav.evaluate((el) => {
    const box = el.getBoundingClientRect();
    return { top: box.top, bottom: box.bottom, height: window.innerHeight };
  });
  expect(placement.top).toBeGreaterThanOrEqual(-1);
  expect(placement.bottom).toBeLessThanOrEqual(placement.height + 1);
});

// The other two root destinations use the same repeat-tap callback as
// Home and have registered route-local refresh listeners.
test("Club and Chat root tabs handle repeat-tap refresh without reloading", () => {
  const file = (name: string) => readFileSync(path.join(process.cwd(), "components", name), "utf8");
  expect(file("bottom-navigation.tsx")).toContain('onClick={handleActiveTabTap(clubActive, "/clubs")}');
  expect(file("bottom-navigation.tsx")).toContain('onClick={handleActiveTabTap(chatActive, "/chat")}');
  expect(file("clubs-routes.tsx")).toContain("useRouteRefreshListener(pull.refresh)");
  // /chat/page.tsx renders ChatInboxParityRoute, which already uses
  // React Query's user-keyed cache rather than the legacy ChatInboxInner.
  const root = readFileSync(path.join(process.cwd(), "app/chat/page.tsx"), "utf8");
  expect(root).toContain("ChatInboxParityRoute");
  expect(file("chat-inbox-parity.tsx")).toContain("useRouteRefreshListener(refreshInbox)");
  expect(file("chat-inbox-parity.tsx")).toContain('refetchOnMount: "always"');
  expect(file("chat-inbox-parity.tsx")).toContain("queryKey: [\"chat-inbox\", userId]");
});
